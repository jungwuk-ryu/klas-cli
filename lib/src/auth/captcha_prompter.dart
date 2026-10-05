import 'dart:io';

import 'package:klasflow/klasflow.dart';

import 'terminal.dart';

typedef CaptchaImageOpener = Future<void> Function(String path);

/// Shows a short-lived captcha image and collects a human numeric answer.
final class CaptchaPrompter {
  CaptchaPrompter({
    required this.terminal,
    CaptchaImageOpener? imageOpener,
    this.temporaryRoot,
  }) : _imageOpener = imageOpener ?? _openImage;

  final Terminal terminal;
  final CaptchaImageOpener _imageOpener;
  final Directory? temporaryRoot;

  Future<String?> answer(KlasCaptchaChallenge challenge) async {
    final root = temporaryRoot ?? Directory.systemTemp;
    final directory = await root.createTemp('klas-captcha-');
    try {
      if (!Platform.isWindows) {
        await _protect(directory.path, '700');
      }
      final extension = switch (challenge.image.contentType
          ?.split(';')
          .first
          .trim()) {
        'image/jpeg' => 'jpg',
        'image/gif' => 'gif',
        _ => 'png',
      };
      final file = File('${directory.path}/captcha.$extension');
      await file.writeAsBytes(challenge.image.bytes, flush: true);
      if (!Platform.isWindows) {
        await _protect(file.path, '600');
      }
      terminal.writeErr(
        'KLAS requires a numeric captcha (${challenge.attempt}/${challenge.maxAttempts}).',
      );
      terminal.writeErr('Captcha image: ${file.path}');
      try {
        await _imageOpener(file.path);
      } catch (_) {
        terminal.writeErr(
          'Open the captcha image path above with an image viewer.',
        );
      }
      while (true) {
        final value = (await terminal.prompt(
          'Captcha digits (blank to cancel): ',
        ))?.trim();
        if (value == null || value.isEmpty) return null;
        if (RegExp(r'^[0-9]+$').hasMatch(value)) return value;
        terminal.writeErr('Enter only the digits shown in the image.');
      }
    } finally {
      try {
        await directory.delete(recursive: true);
      } on FileSystemException {
        terminal.writeErr(
          'The temporary captcha image could not be removed. Delete the image path above manually.',
        );
      }
    }
  }
}

Future<void> _protect(String path, String mode) async {
  final result = await Process.run('chmod', [mode, path]);
  if (result.exitCode != 0) {
    throw const FileSystemException('Cannot protect the captcha image.');
  }
}

Future<void> _openImage(String path) async {
  if (Platform.isWindows) {
    await Process.start('rundll32.exe', [
      'url.dll,FileProtocolHandler',
      path,
    ], mode: ProcessStartMode.detached);
    return;
  }
  final result = await Process.run(Platform.isMacOS ? 'open' : 'xdg-open', [
    path,
  ]).timeout(const Duration(seconds: 5));
  if (result.exitCode != 0) {
    throw const FileSystemException('Image viewer unavailable.');
  }
}
