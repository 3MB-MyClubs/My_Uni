import 'dart:io';
import 'dart:typed_data';

const int _maxImageHeaderBytes = 256 * 1024;

/// Reads only the leading metadata area instead of pulling a multi-megabyte
/// upload into memory on the UI isolate. Unusual files whose dimension marker
/// falls later simply return null and can use the normal decoded-image path.
double? imageAspectRatioFromFile(File file) {
  RandomAccessFile? handle;
  try {
    handle = file.openSync();
    final length = handle.lengthSync().clamp(0, _maxImageHeaderBytes);
    return imageAspectRatioFromBytes(handle.readSync(length));
  } on FileSystemException {
    return null;
  } finally {
    handle?.closeSync();
  }
}

/// Reads dimensions from the lightweight headers of the image formats used by
/// post and chat uploads. Returns displayed width / height without decoding
/// the full bitmap, including camera rotation stored in JPEG EXIF metadata.
double? imageAspectRatioFromBytes(Uint8List bytes) {
  final png = _pngDimensions(bytes);
  if (png != null) return png.$1 / png.$2;

  final jpeg = _jpegDimensions(bytes);
  if (jpeg != null) {
    final orientation = _jpegExifOrientation(bytes);
    final isQuarterTurn =
        orientation == 5 ||
        orientation == 6 ||
        orientation == 7 ||
        orientation == 8;
    return isQuarterTurn ? jpeg.$2 / jpeg.$1 : jpeg.$1 / jpeg.$2;
  }

  return null;
}

(int, int)? _pngDimensions(Uint8List bytes) {
  const signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length < 24) return null;
  for (var index = 0; index < signature.length; index++) {
    if (bytes[index] != signature[index]) return null;
  }

  final data = ByteData.sublistView(bytes);
  final width = data.getUint32(16, Endian.big);
  final height = data.getUint32(20, Endian.big);
  return width > 0 && height > 0 ? (width, height) : null;
}

(int, int)? _jpegDimensions(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) return null;

  var offset = 2;
  while (offset + 4 <= bytes.length) {
    if (bytes[offset] != 0xFF) {
      offset++;
      continue;
    }
    while (offset < bytes.length && bytes[offset] == 0xFF) {
      offset++;
    }
    if (offset >= bytes.length) return null;

    final marker = bytes[offset++];
    if (marker == 0xD8 || marker == 0xD9) continue;
    if (marker == 0xDA) return null;
    if (offset + 2 > bytes.length) return null;

    final segmentLength = (bytes[offset] << 8) | bytes[offset + 1];
    if (segmentLength < 2 || offset + segmentLength > bytes.length) return null;
    if (_isJpegStartOfFrame(marker) && segmentLength >= 7) {
      final height = (bytes[offset + 3] << 8) | bytes[offset + 4];
      final width = (bytes[offset + 5] << 8) | bytes[offset + 6];
      return width > 0 && height > 0 ? (width, height) : null;
    }
    offset += segmentLength;
  }
  return null;
}

bool _isJpegStartOfFrame(int marker) => switch (marker) {
  0xC0 ||
  0xC1 ||
  0xC2 ||
  0xC3 ||
  0xC5 ||
  0xC6 ||
  0xC7 ||
  0xC9 ||
  0xCA ||
  0xCB ||
  0xCD ||
  0xCE ||
  0xCF => true,
  _ => false,
};

/// Reads the EXIF orientation so camera JPEGs whose pixels are stored sideways
/// report the same dimensions that Flutter displays after applying rotation.
int? _jpegExifOrientation(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) return null;

  var offset = 2;
  while (offset + 4 <= bytes.length) {
    if (bytes[offset] != 0xFF) {
      offset++;
      continue;
    }
    while (offset < bytes.length && bytes[offset] == 0xFF) {
      offset++;
    }
    if (offset >= bytes.length) return null;

    final marker = bytes[offset++];
    if (marker == 0xD8 || marker == 0xD9) continue;
    if (marker == 0xDA || offset + 2 > bytes.length) return null;

    final segmentLength = (bytes[offset] << 8) | bytes[offset + 1];
    if (segmentLength < 2 || offset + segmentLength > bytes.length) return null;
    if (marker == 0xE1) {
      final orientation = _orientationFromExifSegment(
        bytes,
        payloadStart: offset + 2,
        segmentEnd: offset + segmentLength,
      );
      if (orientation != null) return orientation;
    }
    offset += segmentLength;
  }
  return null;
}

int? _orientationFromExifSegment(
  Uint8List bytes, {
  required int payloadStart,
  required int segmentEnd,
}) {
  const exifHeader = <int>[0x45, 0x78, 0x69, 0x66, 0, 0];
  if (payloadStart + exifHeader.length + 8 > segmentEnd) return null;
  for (var index = 0; index < exifHeader.length; index++) {
    if (bytes[payloadStart + index] != exifHeader[index]) return null;
  }

  final tiffStart = payloadStart + exifHeader.length;
  final Endian endian;
  if (bytes[tiffStart] == 0x49 && bytes[tiffStart + 1] == 0x49) {
    endian = Endian.little;
  } else if (bytes[tiffStart] == 0x4D && bytes[tiffStart + 1] == 0x4D) {
    endian = Endian.big;
  } else {
    return null;
  }

  final data = ByteData.sublistView(bytes);
  if (data.getUint16(tiffStart + 2, endian) != 42) return null;
  final ifdOffset = data.getUint32(tiffStart + 4, endian);
  final ifdStart = tiffStart + ifdOffset;
  if (ifdStart < tiffStart || ifdStart + 2 > segmentEnd) return null;

  final entryCount = data.getUint16(ifdStart, endian);
  for (var index = 0; index < entryCount; index++) {
    final entry = ifdStart + 2 + (index * 12);
    if (entry + 12 > segmentEnd) return null;
    if (data.getUint16(entry, endian) != 0x0112) continue;
    if (data.getUint16(entry + 2, endian) != 3 ||
        data.getUint32(entry + 4, endian) != 1) {
      return null;
    }
    final orientation = data.getUint16(entry + 8, endian);
    return orientation >= 1 && orientation <= 8 ? orientation : null;
  }
  return null;
}
