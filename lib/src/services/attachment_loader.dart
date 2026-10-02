import 'dart:io';

import 'package:klasflow/klasflow.dart';

import '../errors/cli_errors.dart';
import '../models/cli_models.dart';
import '../validation/input_validation.dart';

/// Loads attachments inside the caller's authenticated SDK session.
final class AttachmentLoader {
  AttachmentLoader(this.user, {this.downloadDirectory});

  final KlasUser user;
  final String? downloadDirectory;
  final List<String> warnings = [];
  Directory? _destination;

  Future<List<AttachmentView>?> load(String? attachId, String group) async {
    if (attachId == null || attachId.trim().isEmpty) return const [];
    List<KlasAttachedFile> files;
    try {
      files = await user.files.listByAttachId(attachId: attachId);
    } catch (error) {
      warnings.add(
        'Failed to list $group: ${ErrorMapper().map(error).message}',
      );
      return null;
    }
    if (files.isEmpty) {
      warnings.add(
        'No files were returned for the $group attachment reference.',
      );
    }
    final result = <AttachmentView>[];
    for (var index = 0; index < files.length; index++) {
      final file = files[index];
      String? localPath;
      if (downloadDirectory != null) {
        try {
          final payload = await file.download();
          final directory = await _groupDirectory(group);
          final name = _safeFileName(file.fileName ?? payload.fileName);
          final target = File('${directory.path}/${index + 1}-$name');
          await target.writeAsBytes(payload.bytes, flush: true);
          localPath = target.absolute.path;
        } catch (error) {
          final message = error is FileSystemException
              ? 'The attachment could not be saved to the download directory.'
              : ErrorMapper().map(error).message;
          warnings.add('Failed to download $group file ${index + 1}: $message');
        }
      }
      result.add(
        AttachmentView(
          fileName: file.fileName,
          sizeBytes: file.size,
          localPath: localPath,
        ),
      );
    }
    return result;
  }

  Future<Directory> _groupDirectory(String group) async {
    if (_destination == null) {
      final directory = Directory(
        validateNoControlChars(
          downloadDirectory!,
          fieldName: 'download directory',
        ),
      ).absolute;
      await directory.create(recursive: true);
      _destination = await directory.createTemp('klas-');
    }
    return Directory('${_destination!.path}/$group').create(recursive: true);
  }
}

String _safeFileName(String? value) {
  var name = (value ?? 'attachment.bin')
      .split(RegExp(r'[/\\]'))
      .last
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f\x7f-\x9f]'), '_')
      .replaceAll(RegExp(r'[. ]+$'), '')
      .trim();
  if (name.isEmpty) name = 'attachment.bin';
  // Number prefixes keep Windows device names and duplicate names harmless.
  if (name.length > 160) name = name.substring(name.length - 160);
  return name;
}
