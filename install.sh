#!/usr/bin/env bash

set -euo pipefail

PACKAGE_NAME="klas_cli"
EXECUTABLE_NAME="klas"
DART_VERSION="3.11.1"
DART_CHANNEL="stable"
INSTALLER_NAME="klas installer"

log() {
  printf '%s: %s\n' "$INSTALLER_NAME" "$*" >&2
}

warn() {
  log "warning: $*"
}

fail() {
  log "error: $*"
  exit 1
}

has_command() {
  command -v "$1" >/dev/null 2>&1
}

download_file() {
  local url="$1"
  local destination="$2"

  if has_command curl; then
    curl -fsSL "$url" -o "$destination"
    return
  fi

  if has_command wget; then
    wget -qO "$destination" "$url"
    return
  fi

  fail "curl or wget is required to download the Dart SDK."
}

extract_zip() {
  local archive_path="$1"
  local destination="$2"

  rm -rf "$destination"
  mkdir -p "$destination"

  if has_command unzip; then
    unzip -q "$archive_path" -d "$destination"
    return
  fi

  if has_command python3; then
    python3 - "$archive_path" "$destination" <<'PY'
import pathlib
import sys
import zipfile

archive = pathlib.Path(sys.argv[1])
destination = pathlib.Path(sys.argv[2])
with zipfile.ZipFile(archive) as bundle:
    bundle.extractall(destination)
PY
    return
  fi

  if has_command python; then
    python - "$archive_path" "$destination" <<'PY'
import pathlib
import sys
import zipfile

archive = pathlib.Path(sys.argv[1])
destination = pathlib.Path(sys.argv[2])
with zipfile.ZipFile(archive) as bundle:
    bundle.extractall(destination)
PY
    return
  fi

  if has_command bsdtar; then
    bsdtar -xf "$archive_path" -C "$destination"
    return
  fi

  if has_command ditto; then
    ditto -x -k "$archive_path" "$destination"
    return
  fi

  fail "Could not extract the Dart SDK archive. Install unzip, python3, bsdtar, or ditto and retry."
}

parse_dart_version() {
  local output
  output="$1"
  local version
  version="$(printf '%s' "$output" | sed -nE 's/.* ([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' | head -n 1)"
  if [[ -z "$version" ]]; then
    return 1
  fi
  printf '%s\n' "$version"
}

version_at_least() {
  local current="$1"
  local required="$2"
  local current_parts required_parts i

  IFS=. read -r -a current_parts <<<"$current"
  IFS=. read -r -a required_parts <<<"$required"

  for i in 0 1 2; do
    local current_value="${current_parts[i]:-0}"
    local required_value="${required_parts[i]:-0}"
    if ((10#$current_value > 10#$required_value)); then
      return 0
    fi
    if ((10#$current_value < 10#$required_value)); then
      return 1
    fi
  done

  return 0
}

detect_platform() {
  local uname_s uname_m
  uname_s="$(uname -s)"
  uname_m="$(uname -m)"

  case "$uname_s" in
    Linux)
      PLATFORM_ID="linux"
      DART_OS="linux"
      INSTALL_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/klas-cli"
      ;;
    Darwin)
      PLATFORM_ID="macos"
      DART_OS="macos"
      INSTALL_ROOT="$HOME/Library/Application Support/klas-cli"
      ;;
    *)
      fail "Unsupported operating system: $uname_s"
      ;;
  esac

  case "$uname_m" in
    x86_64|amd64)
      DART_ARCH="x64"
      ;;
    arm64|aarch64)
      DART_ARCH="arm64"
      ;;
    *)
      fail "Unsupported CPU architecture: $uname_m"
      ;;
  esac

  PUB_CACHE_ROOT="${PUB_CACHE:-$HOME/.pub-cache}"
  PUB_CACHE_BIN="$PUB_CACHE_ROOT/bin"
  DART_ROOT="$INSTALL_ROOT/dart-sdk"
  DART_BIN="$DART_ROOT/bin"
}

ensure_path_now() {
  local path_entry="$1"
  case ":${PATH}:" in
    *":${path_entry}:"*) ;;
    *) PATH="${path_entry}:$PATH" ;;
  esac
  export PATH
}

ensure_system_shell_path() {
  if [[ -d /usr/bin ]]; then
    ensure_path_now "/usr/bin"
  fi
  if [[ -d /bin ]]; then
    ensure_path_now "/bin"
  fi
}

choose_profile_file() {
  if [[ -n "${PROFILE:-}" ]]; then
    printf '%s\n' "$PROFILE"
    return
  fi

  case "${SHELL:-}" in
    */zsh)
      printf '%s\n' "$HOME/.zshrc"
      return
      ;;
    */bash)
      if [[ -f "$HOME/.bashrc" ]]; then
        printf '%s\n' "$HOME/.bashrc"
      else
        printf '%s\n' "$HOME/.bash_profile"
      fi
      return
      ;;
  esac

  if [[ -f "$HOME/.profile" ]]; then
    printf '%s\n' "$HOME/.profile"
  else
    printf '%s\n' "$HOME/.bash_profile"
  fi
}

persist_path() {
  local profile_file="$1"
  local persisted_dart_bin="$2"
  local marker_begin="# >>> klas-cli installer >>>"
  local marker_end="# <<< klas-cli installer <<<"
  local quoted_dart_bin quoted_pub_cache_bin

  mkdir -p "$(dirname "$profile_file")"
  touch "$profile_file"

  if grep -Fq "$marker_begin" "$profile_file"; then
    return
  fi

  quoted_dart_bin=$(printf "%q" "$persisted_dart_bin")
  quoted_pub_cache_bin=$(printf "%q" "$PUB_CACHE_BIN")

  cat >>"$profile_file" <<EOF

$marker_begin
klas_cli_dart_bin=$quoted_dart_bin
case ":\$PATH:" in
  *":\$klas_cli_dart_bin:"*) ;;
  *) PATH="\$klas_cli_dart_bin:\$PATH" ;;
esac
klas_cli_pub_cache_bin=$quoted_pub_cache_bin
case ":\$PATH:" in
  *":\$klas_cli_pub_cache_bin:"*) ;;
  *) PATH="\$klas_cli_pub_cache_bin:\$PATH" ;;
esac
export PATH
unset klas_cli_dart_bin klas_cli_pub_cache_bin
$marker_end
EOF
}

resolve_existing_dart() {
  if ! has_command dart; then
    return 1
  fi

  local version_output version
  version_output="$(dart --version 2>&1 || true)"
  version="$(parse_dart_version "$version_output" || true)"

  if [[ -z "$version" ]]; then
    warn "Found dart on PATH but could not parse its version. Bootstrapping Dart $DART_VERSION instead."
    return 1
  fi

  if version_at_least "$version" "$DART_VERSION"; then
    printf '%s\n' "$(command -v dart)"
    return 0
  fi

  warn "Found dart $version on PATH, but $DART_VERSION or newer is required. Bootstrapping a newer SDK."
  return 1
}

install_dart_sdk() {
  local archive_url archive_file extract_dir extracted_root
  archive_url="https://storage.googleapis.com/dart-archive/channels/$DART_CHANNEL/release/$DART_VERSION/sdk/dartsdk-$DART_OS-$DART_ARCH-release.zip"
  archive_file="$INSTALL_ROOT/dartsdk-$DART_OS-$DART_ARCH-$DART_VERSION.zip"
  extract_dir="$INSTALL_ROOT/.extract"

  mkdir -p "$INSTALL_ROOT"

  log "Downloading Dart SDK $DART_VERSION for $PLATFORM_ID/$DART_ARCH"
  download_file "$archive_url" "$archive_file"

  log "Extracting Dart SDK"
  extract_zip "$archive_file" "$extract_dir"

  extracted_root="$extract_dir/dart-sdk"
  [[ -d "$extracted_root" ]] || fail "Downloaded archive did not contain a dart-sdk directory."

  rm -rf "$DART_ROOT"
  mv "$extracted_root" "$DART_ROOT"
  rm -rf "$extract_dir"
  rm -f "$archive_file"

  local dart_executable
  dart_executable="$DART_BIN/dart"
  [[ -x "$dart_executable" ]] || fail "Bootstrapped Dart SDK is missing $dart_executable"
  printf '%s\n' "$dart_executable"
}

run_login() {
  local klas_bin="$1"

  if [[ -n "${KLAS_ID:-}" && -n "${KLAS_PASSWORD:-}" ]]; then
    log "Starting login using KLAS_ID/KLAS_PASSWORD from the environment"
    "$klas_bin" auth login
    return
  fi

  if [[ -r /dev/tty && -w /dev/tty && -t 2 ]]; then
    log "Starting interactive login"
    "$klas_bin" auth login </dev/tty
    return
  fi

  warn "Installation succeeded, but login requires an interactive terminal or KLAS_ID/KLAS_PASSWORD."
  warn "Next step: $klas_bin auth login"
}

main() {
  [[ -n "${HOME:-}" ]] || fail "HOME is not set."

  detect_platform
  ensure_system_shell_path

  local dart_executable dart_bin_dir profile_file klas_bin
  if dart_executable="$(resolve_existing_dart)"; then
    log "Using existing Dart SDK at $dart_executable"
  else
    dart_executable="$(install_dart_sdk)"
  fi

  dart_bin_dir="$(dirname "$dart_executable")"

  ensure_path_now "$dart_bin_dir"
  mkdir -p "$PUB_CACHE_BIN"

  log "Activating $PACKAGE_NAME from pub.dev"
  PUB_CACHE="$PUB_CACHE_ROOT" "$dart_executable" pub global activate "$PACKAGE_NAME" --overwrite

  klas_bin="$PUB_CACHE_BIN/$EXECUTABLE_NAME"
  [[ -f "$klas_bin" ]] || fail "Expected installed executable at $klas_bin"

  ensure_path_now "$PUB_CACHE_BIN"

  profile_file="$(choose_profile_file)"
  if ! persist_path "$profile_file" "$dart_bin_dir"; then
    warn "Installed for the current session, but failed to update $profile_file."
    warn "Add these directories to PATH manually: $dart_bin_dir and $PUB_CACHE_BIN"
  fi

  "$klas_bin" --help >/dev/null
  log "Installation complete"

  if [[ ! -t 0 ]]; then
    warn "Because this installer ran in a piped shell, your current shell may need to reload PATH before plain '$EXECUTABLE_NAME' works."
    warn "Open a new shell or run: source $profile_file"
  fi

  run_login "$klas_bin"
}

main "$@"
