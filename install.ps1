Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$PackageName = 'klas_cli'
$ExecutableName = 'klas'
$DartVersion = '3.11.1'
$DartChannel = 'stable'

function Write-Log {
    param([string]$Message)
    [Console]::Error.WriteLine("klas installer: $Message")
}

function Write-WarningLog {
    param([string]$Message)
    Write-Log "warning: $Message"
}

function Fail {
    param([string]$Message)
    Write-Log "error: $Message"
    exit 1
}

function Get-CommandPath {
    param([string]$Name)
    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        return $null
    }
    return $command.Source
}

function Parse-DartVersion {
    param([string]$Output)
    $match = [regex]::Match($Output, '(\d+\.\d+\.\d+)')
    if (-not $match.Success) {
        return $null
    }
    return [Version]$match.Groups[1].Value
}

function Resolve-DartExe {
    $dartSource = Get-CommandPath 'dart'
    if ($null -eq $dartSource) {
        return $null
    }

    $output = & $dartSource --version 2>&1 | Out-String
    $version = Parse-DartVersion $output
    if ($null -eq $version) {
        Write-WarningLog 'Found dart on PATH but could not parse its version. Bootstrapping Dart 3.11.1 instead.'
        return $null
    }

    if ($version -ge ([Version]$DartVersion)) {
        return $dartSource
    }

    Write-WarningLog "Found dart $version on PATH, but $DartVersion or newer is required. Bootstrapping a newer SDK."
    return $null
}

function Add-PathEntry {
    param(
        [string]$PathValue,
        [ValidateSet('Process', 'User')][string]$Target
    )

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return
    }

    $current = [Environment]::GetEnvironmentVariable('Path', $Target)
    $parts = @()
    if (-not [string]::IsNullOrWhiteSpace($current)) {
        $parts = $current -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    }

    if ($parts -contains $PathValue) {
        return
    }

    $updated = if ($parts.Count -eq 0) {
        $PathValue
    } else {
        "$PathValue;$($parts -join ';')"
    }

    [Environment]::SetEnvironmentVariable('Path', $updated, $Target)
    if ($Target -eq 'Process') {
        $env:Path = $updated
    }
}

function Install-DartSdk {
    param(
        [string]$InstallRoot,
        [string]$DartOs,
        [string]$DartArch
    )

    $archiveUrl = "https://storage.googleapis.com/dart-archive/channels/$DartChannel/release/$DartVersion/sdk/dartsdk-$DartOs-$DartArch-release.zip"
    $archivePath = Join-Path $InstallRoot "dartsdk-$DartOs-$DartArch-$DartVersion.zip"
    $extractRoot = Join-Path $InstallRoot '.extract'
    $dartRoot = Join-Path $InstallRoot 'dart-sdk'

    New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null

    Write-Log "Downloading Dart SDK $DartVersion for windows/$DartArch"
    Invoke-WebRequest -UseBasicParsing -Uri $archiveUrl -OutFile $archivePath

    if (Test-Path $extractRoot) {
        Remove-Item -Recurse -Force $extractRoot
    }
    New-Item -ItemType Directory -Force -Path $extractRoot | Out-Null

    Write-Log 'Extracting Dart SDK'
    Expand-Archive -LiteralPath $archivePath -DestinationPath $extractRoot -Force

    $extractedRoot = Join-Path $extractRoot 'dart-sdk'
    if (-not (Test-Path $extractedRoot)) {
        Fail 'Downloaded archive did not contain a dart-sdk directory.'
    }

    if (Test-Path $dartRoot) {
        Remove-Item -Recurse -Force $dartRoot
    }
    Move-Item -LiteralPath $extractedRoot -Destination $dartRoot
    Remove-Item -Recurse -Force $extractRoot
    Remove-Item -Force $archivePath

    $dartExe = Join-Path $dartRoot 'bin\dart.exe'
    if (-not (Test-Path $dartExe)) {
        Fail "Bootstrapped Dart SDK is missing $dartExe"
    }

    return $dartExe
}

function Start-Login {
    param([string]$KlasCommand)

    if (-not [string]::IsNullOrWhiteSpace($env:KLAS_ID) -and -not [string]::IsNullOrWhiteSpace($env:KLAS_PASSWORD)) {
        Write-Log 'Starting login using KLAS_ID/KLAS_PASSWORD from the environment'
        & $KlasCommand auth login
        return
    }

    if ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected -and -not [Console]::IsErrorRedirected) {
        Write-Log 'Starting interactive login'
        & $KlasCommand auth login
        return
    }

    Write-WarningLog 'Installation succeeded, but login requires an interactive terminal or KLAS_ID/KLAS_PASSWORD.'
    Write-WarningLog 'Next step: klas auth login'
}

if (-not [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)) {
    Fail 'This installer is only supported on Windows. Use install.sh on macOS or Linux.'
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
switch ($architecture) {
    'X64' { $dartArch = 'x64' }
    'Arm64' { $dartArch = 'arm64' }
    default { Fail "Unsupported CPU architecture: $architecture" }
}

$installRoot = Join-Path $env:LOCALAPPDATA 'klas-cli'
$dartBin = Join-Path $installRoot 'dart-sdk\bin'
$pubCacheRoot = if (-not [string]::IsNullOrWhiteSpace($env:PUB_CACHE)) {
    $env:PUB_CACHE
} else {
    Join-Path $env:LOCALAPPDATA 'Pub\Cache'
}
$pubCacheBin = Join-Path $pubCacheRoot 'bin'

$dartExe = Resolve-DartExe
if ($null -eq $dartExe) {
    $dartExe = Install-DartSdk -InstallRoot $installRoot -DartOs 'windows' -DartArch $dartArch
} else {
    Write-Log "Using existing Dart SDK at $dartExe"
}

Add-PathEntry -PathValue (Split-Path -Parent $dartExe) -Target Process
Add-PathEntry -PathValue $pubCacheBin -Target Process

try {
    Add-PathEntry -PathValue (Split-Path -Parent $dartExe) -Target User
    Add-PathEntry -PathValue $pubCacheBin -Target User
} catch {
    Write-WarningLog 'Installed for the current session, but failed to persist PATH for future sessions.'
    Write-WarningLog "Add these directories to PATH manually: $(Split-Path -Parent $dartExe) and $pubCacheBin"
}

New-Item -ItemType Directory -Force -Path $pubCacheBin | Out-Null

Write-Log "Activating $PackageName from pub.dev"
$previousPubCache = $env:PUB_CACHE
$env:PUB_CACHE = $pubCacheRoot
try {
    & $dartExe pub global activate $PackageName --overwrite
} finally {
    if ($null -eq $previousPubCache) {
        Remove-Item Env:PUB_CACHE -ErrorAction SilentlyContinue
    } else {
        $env:PUB_CACHE = $previousPubCache
    }
}

$klasCommand = Join-Path $pubCacheBin 'klas.bat'
if (-not (Test-Path $klasCommand)) {
    Fail "Expected installed executable at $klasCommand"
}

& $klasCommand --help | Out-Null
Write-Log 'Installation complete'

Start-Login -KlasCommand $klasCommand
