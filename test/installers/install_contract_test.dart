import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('installer contract', () {
    test(
      'unix installer bootstraps Dart, activates the pub package, and starts login',
      () {
        final script = File('install.sh').readAsStringSync();

        expect(script, contains('set -euo pipefail'));
        expect(script, contains('storage.googleapis.com/dart-archive'));
        expect(
          script,
          contains(r'pub global activate "$PACKAGE_NAME" --overwrite'),
        );
        expect(script, contains(r'dartsdk-$DART_OS-$DART_ARCH-release.zip'));
        expect(script, contains('auth login'));
        expect(script, contains('/dev/tty'));
        expect(
          script,
          contains(r'PUB_CACHE_ROOT="${PUB_CACHE:-$HOME/.pub-cache}"'),
        );
        expect(script, contains('Because this installer ran in a piped shell'));
        expect(
          script,
          contains(r'persist_path "$profile_file" "$dart_bin_dir"'),
        );
      },
    );

    test(
      'powershell installer bootstraps Dart, activates the pub package, and starts login',
      () {
        final script = File('install.ps1').readAsStringSync();

        expect(script, contains("Set-StrictMode -Version Latest"));
        expect(script, contains('storage.googleapis.com/dart-archive'));
        expect(
          script,
          contains(r'pub global activate $PackageName --overwrite'),
        );
        expect(script, contains("Expand-Archive -LiteralPath"));
        expect(script, contains(r"Join-Path $env:LOCALAPPDATA 'Pub\Cache'"));
        expect(
          script,
          contains(
            '[System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)',
          ),
        );
        expect(script, contains('auth login'));
        expect(script, contains('klas.bat'));
      },
    );

    test('readme publishes one-line installers from the main branch', () {
      final readme = File('README.md').readAsStringSync();

      expect(
        readme,
        contains(
          'curl -fsSL https://raw.githubusercontent.com/jungwuk-ryu/klas-cli/main/install.sh | bash',
        ),
      );
      expect(
        readme,
        contains(
          'iwr -useb https://raw.githubusercontent.com/jungwuk-ryu/klas-cli/main/install.ps1 | iex',
        ),
      );
    });
  });
}
