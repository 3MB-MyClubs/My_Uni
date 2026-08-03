/// Removes the horizontal-mirror flag from a JPEG's EXIF orientation tag.
///
/// Front-facing camera captures come back mirrored: iOS hands `image_picker`
/// the untransformed sensor pixels plus an EXIF orientation that asks the
/// renderer to mirror them (that is how the selfie preview look is preserved),
/// and `image_picker` re-attaches that tag verbatim to the file it writes.
/// Flutter honours EXIF orientation when decoding, so the photo renders as a
/// mirror of the scene that was actually photographed.
///
/// Clearing the mirror bit is lossless — only the orientation tag is rewritten,
/// the compressed pixel data is never touched. Of the eight EXIF orientations
/// only 2, 4, 5 and 7 carry the mirror flag, and in practice those appear on
/// selfies, so rear-camera and gallery photos pass through untouched.
library;

import 'dart:io';
import 'dart:typed_data';

const int _markerPrefix = 0xFF;
const int _markerStartOfImage = 0xD8;
const int _markerStartOfScan = 0xDA;
const int _markerEndOfImage = 0xD9;
const int _markerApp1 = 0xE1;

const int _orientationTag = 0x0112;
const int _typeShort = 3;
const int _tiffMagic = 42;

/// The non-mirrored orientation holding the same rotation as [orientation].
///
/// Each mirrored value is a horizontal flip composed with a rotation, so
/// dropping the flip leaves the rotation alone: 2→1, 4→3, 5→8, 7→6. The four
/// non-mirrored values pass through unchanged.
int unmirroredOrientation(int orientation) => switch (orientation) {
  2 => 1,
  4 => 3,
  5 => 8,
  7 => 6,
  _ => orientation,
};

/// Rewrites [bytes] in place so its EXIF orientation no longer mirrors the
/// image, returning whether anything changed.
///
/// Returns false — leaving [bytes] untouched — for anything that is not a JPEG
/// carrying a mirrored orientation tag, including malformed input. Nothing here
/// resizes the buffer, so a caller can write it straight back over the original.
bool stripExifMirrorFlag(Uint8List bytes) {
  final exifStart = _findExifPayload(bytes);
  if (exifStart == null) return false;

  // The TIFF header the EXIF offsets are all relative to sits right after the
  // "Exif\0\0" identifier.
  final tiffStart = exifStart + 6;
  if (tiffStart + 8 > bytes.length) return false;

  final Endian endian;
  if (bytes[tiffStart] == 0x49 && bytes[tiffStart + 1] == 0x49) {
    endian = Endian.little;
  } else if (bytes[tiffStart] == 0x4D && bytes[tiffStart + 1] == 0x4D) {
    endian = Endian.big;
  } else {
    return false;
  }

  final data = ByteData.sublistView(bytes);
  if (data.getUint16(tiffStart + 2, endian) != _tiffMagic) return false;

  final ifdOffset = data.getUint32(tiffStart + 4, endian);
  if (ifdOffset > bytes.length) return false;
  final ifdStart = tiffStart + ifdOffset;
  if (ifdStart + 2 > bytes.length) return false;

  final entryCount = data.getUint16(ifdStart, endian);
  for (var index = 0; index < entryCount; index++) {
    // Every IFD entry is 12 bytes: tag, type, count, then the value (or a
    // pointer to it, but a single SHORT always fits inline).
    final entry = ifdStart + 2 + (index * 12);
    if (entry + 12 > bytes.length) return false;
    if (data.getUint16(entry, endian) != _orientationTag) continue;
    if (data.getUint16(entry + 2, endian) != _typeShort) return false;

    final valueOffset = entry + 8;
    final current = data.getUint16(valueOffset, endian);
    final corrected = unmirroredOrientation(current);
    if (corrected == current) return false;
    data.setUint16(valueOffset, corrected, endian);
    return true;
  }
  return false;
}

/// Applies [stripExifMirrorFlag] to the file at [path], rewriting it in place.
///
/// Returns whether the file was changed. Any read/write failure is swallowed —
/// an un-mirrored photo is a nicety, and it must never block sending one.
Future<bool> unmirrorPhotoFile(String path) async {
  final file = File(path);
  try {
    final bytes = await file.readAsBytes();
    if (!stripExifMirrorFlag(bytes)) return false;
    await file.writeAsBytes(bytes, flush: true);
    return true;
  } on FileSystemException {
    return false;
  }
}

/// Offset of the "Exif\0\0" identifier inside the JPEG's APP1 segment, or null
/// when [bytes] is not a JPEG or carries no EXIF block.
int? _findExifPayload(Uint8List bytes) {
  if (bytes.length < 4 ||
      bytes[0] != _markerPrefix ||
      bytes[1] != _markerStartOfImage) {
    return null;
  }
  var offset = 2;
  while (offset + 4 <= bytes.length) {
    if (bytes[offset] != _markerPrefix) return null;
    // Markers may be padded with any number of extra 0xFF fill bytes.
    while (bytes[offset + 1] == _markerPrefix && offset + 2 < bytes.length) {
      offset++;
    }
    final marker = bytes[offset + 1];
    // Entropy-coded data starts at SOS; no metadata segment follows it.
    if (marker == _markerStartOfScan || marker == _markerEndOfImage) {
      return null;
    }
    final length = (bytes[offset + 2] << 8) | bytes[offset + 3];
    if (length < 2) return null;
    final payload = offset + 4;
    final end = offset + 2 + length;
    if (end > bytes.length) return null;
    if (marker == _markerApp1 && _hasExifHeader(bytes, payload, end)) {
      return payload;
    }
    offset = end;
  }
  return null;
}

bool _hasExifHeader(Uint8List bytes, int start, int end) {
  const header = [0x45, 0x78, 0x69, 0x66, 0x00, 0x00]; // 'Exif\0\0'
  if (start + header.length > end) return false;
  for (var index = 0; index < header.length; index++) {
    if (bytes[start + index] != header[index]) return false;
  }
  return true;
}
