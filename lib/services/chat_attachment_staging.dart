import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Copies an image-picker result out of the OS cache before it enters the
/// local-first chat outbox. Image-picker files are temporary and may disappear
/// before the next authenticated sync gets a chance to upload them.
Future<String> stageChatAttachment(
  String sourcePath, {
  String? sourceName,
}) async {
  final source = File(sourcePath);
  if (!await source.exists()) {
    throw FileSystemException('Chat attachment does not exist', sourcePath);
  }

  final documents = await getApplicationDocumentsDirectory();
  final directory = Directory('${documents.path}/chat_attachments');
  await directory.create(recursive: true);

  final extension = _extension(sourceName ?? sourcePath);
  final target = File(
    '${directory.path}/chat_${DateTime.now().microsecondsSinceEpoch}$extension',
  );
  await source.copy(target.path);
  return target.path;
}

String _extension(String value) {
  final dot = value.lastIndexOf('.');
  if (dot == -1 || dot == value.length - 1) return '.jpg';
  final extension = value.substring(dot).toLowerCase();
  return const {
        '.jpg',
        '.jpeg',
        '.png',
        '.webp',
        '.gif',
        '.heic',
        '.heif',
        '.mp4',
        '.mov',
        '.m4v',
        '.avi',
        '.webm',
        '.mkv',
        '.3gp',
      }.contains(extension)
      ? extension
      : '.jpg';
}
