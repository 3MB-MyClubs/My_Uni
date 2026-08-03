import 'package:image_picker/image_picker.dart';

/// The media types the chat preview and attachment renderer understand.
enum ChatMediaType { image, video }

/// A temporary, local gallery/camera selection.
///
/// [file] is intentionally kept as an [XFile] for the lifetime of the preview
/// route. Nothing is copied or uploaded until the route returns a confirmed
/// [MediaPreviewResult].
class SelectedChatMedia {
  const SelectedChatMedia({
    required this.file,
    required this.type,
    required this.sizeBytes,
  });

  final XFile file;
  final ChatMediaType type;
  final int sizeBytes;
}

/// Valid selections plus a count of entries that could not safely be staged.
class InspectedChatMedia {
  const InspectedChatMedia({required this.items, required this.rejectedCount});

  final List<SelectedChatMedia> items;
  final int rejectedCount;
}

/// Result returned only when the user explicitly confirms the preview.
class MediaPreviewResult {
  const MediaPreviewResult({required this.items, required this.caption});

  final List<SelectedChatMedia> items;
  final String caption;
}

/// A conservative client-side ceiling that prevents a selected video from
/// being read or uploaded indefinitely on a mobile connection. Uploads are
/// streamed from disk after confirmation, so accepted files are not buffered
/// in memory.
const int maxChatMediaFileBytes = 100 * 1024 * 1024;

const Set<String> _imageExtensions = {
  'jpg',
  'jpeg',
  'png',
  'webp',
  'gif',
  'heic',
  'heif',
};

const Set<String> _videoExtensions = {
  'mp4',
  'mov',
  'm4v',
  'avi',
  'webm',
  'mkv',
  '3gp',
};

String mediaFileExtension(String value) {
  final withoutQuery = value.toLowerCase().split('?').first;
  final dot = withoutQuery.lastIndexOf('.');
  return dot == -1 ? '' : withoutQuery.substring(dot + 1);
}

bool isVideoMediaPath(String value) =>
    _videoExtensions.contains(mediaFileExtension(value));

bool isImageMediaPath(String value) =>
    _imageExtensions.contains(mediaFileExtension(value));

ChatMediaType? chatMediaTypeForFile(XFile file) {
  final mimeType = file.mimeType?.toLowerCase() ?? '';
  if (mimeType.startsWith('video/')) return ChatMediaType.video;
  if (mimeType.startsWith('image/')) return ChatMediaType.image;
  if (isVideoMediaPath(file.name) || isVideoMediaPath(file.path)) {
    return ChatMediaType.video;
  }
  if (isImageMediaPath(file.name) || isImageMediaPath(file.path)) {
    return ChatMediaType.image;
  }
  return null;
}

/// Inspects selections concurrently without reading their contents into RAM.
Future<InspectedChatMedia> inspectChatMediaFiles(
  Iterable<XFile> files, {
  int maxFileBytes = maxChatMediaFileBytes,
}) async {
  final inspected = await Future.wait(
    files.map((file) async {
      final type = chatMediaTypeForFile(file);
      if (type == null) return null;
      try {
        final size = await file.length();
        if (size <= 0 || size > maxFileBytes) return null;
        return SelectedChatMedia(file: file, type: type, sizeBytes: size);
      } catch (_) {
        return null;
      }
    }),
  );
  final items = inspected.whereType<SelectedChatMedia>().toList(
    growable: false,
  );
  return InspectedChatMedia(
    items: items,
    rejectedCount: inspected.length - items.length,
  );
}
