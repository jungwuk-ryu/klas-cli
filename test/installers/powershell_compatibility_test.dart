import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('Windows PowerShell 5.1 installer functions', () {
    test('native architecture works without RuntimeInformation', () async {
      final data = await _runFunctions(r'''
$env:PROCESSOR_ARCHITECTURE = 'AMD64'
$env:PROCESSOR_ARCHITEW6432 = ''
$native = Resolve-DartArchitecture
$env:PROCESSOR_ARCHITECTURE = 'x86'
$env:PROCESSOR_ARCHITEW6432 = 'ARM64'
$emulated = Resolve-DartArchitecture
$env:PROCESSOR_ARCHITECTURE = 'x86'
$env:PROCESSOR_ARCHITEW6432 = 'AMD64'
$wow64 = Resolve-DartArchitecture
$env:PROCESSOR_ARCHITEW6432 = ''
$unsupported = $false
try { Resolve-DartArchitecture | Out-Null } catch { $unsupported = $true }
@{ native=$native; emulated=$emulated; wow64=$wow64; unsupported=$unsupported } | ConvertTo-Json -Compress
''');
      expect(data, {
        'native': 'x64',
        'emulated': 'arm64',
        'wow64': 'x64',
        'unsupported': true,
      });
    });

    test(
      'single-entry PATH and an existing SDK path work in strict mode',
      () async {
        final data = await _runFunctions(r'''
$env:Path = 'C:\old-dart'
Add-PathEntry -PathValue 'C:\new-dart' -Target Process
$single = $env:Path
$env:Path = 'C:\old-dart;C:\new-dart;C:\tools'
Add-PathEntry -PathValue 'C:\new-dart' -Target Process
$reordered = $env:Path
Add-PathEntry -PathValue 'C:\new-dart' -Target Process
@{ single=$single; reordered=$reordered; repeated=$env:Path } | ConvertTo-Json -Compress
''');
        expect(data['single'], r'C:\new-dart;C:\old-dart');
        expect(data['reordered'], r'C:\new-dart;C:\old-dart;C:\tools');
        expect(data['repeated'], data['reordered']);
      },
    );

    test('Dart 3.10 is rejected and the CLI minimum is accepted', () async {
      final data = await _runFunctions(r'''
$script:FakeDartExe = Join-Path $TestDirectory 'fake-dart.ps1'
function Get-CommandPath { param([string]$Name) return $script:FakeDartExe }
Set-Content -LiteralPath $script:FakeDartExe -Value "'Dart SDK version: 3.10.9 (stable)'"
$old = Resolve-DartExe
Set-Content -LiteralPath $script:FakeDartExe -Value "'Dart SDK version: 3.11.1 (stable)'"
$current = Resolve-DartExe
@{ olderRejected=($null -eq $old); currentAccepted=($current -eq $script:FakeDartExe) } | ConvertTo-Json -Compress
''');
      expect(data['olderRejected'], isTrue);
      expect(data['currentAccepted'], isTrue);
    });
  }, skip: !Platform.isWindows);
}

Future<Map<String, dynamic>> _runFunctions(String body) async {
  final temp = await Directory.systemTemp.createTemp('klas_installer_ps51_');
  try {
    final harness = File('${temp.path}/test.ps1');
    await harness.writeAsString(
      r'''
param([string]$InstallerPath, [string]$TestDirectory)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($InstallerPath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw 'Installer has syntax errors.' }
foreach ($definition in $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)) {
    Invoke-Expression $definition.Extent.Text
}
$DartVersion = '3.11.1'
''' +
          body,
    );
    final shell =
        '${Platform.environment['WINDIR']}'
        r'\System32\WindowsPowerShell\v1.0\powershell.exe';
    final result = await Process.run(shell, [
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      harness.path,
      File('install.ps1').absolute.path,
      temp.path,
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}\n${result.stdout}');
    return (jsonDecode((result.stdout as String).trim()) as Map)
        .cast<String, dynamic>();
  } finally {
    final resolved = await temp.resolveSymbolicLinks();
    expect(resolved.toLowerCase(), temp.absolute.path.toLowerCase());
    await temp.delete(recursive: true);
  }
}
