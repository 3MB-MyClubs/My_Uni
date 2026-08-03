import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/services/photo_orientation.dart';

/// Builds the smallest JPEG that carries an EXIF orientation tag: SOI, an APP1
/// segment holding a one-entry IFD0, then EOI. Enough to exercise the parser
/// without checking a binary fixture into the repo.
Uint8List _jpegWithOrientation(
  int orientation, {
  Endian endian = Endian.little,
  int type = 3, // SHORT
  bool withExifHeader = true,
  int extraEntries = 0,
}) {
  final entryCount = 1 + extraEntries;
  final tiff = ByteData(8 + 2 + (12 * entryCount) + 4);
  if (endian == Endian.little) {
    tiff.setUint8(0, 0x49);
    tiff.setUint8(1, 0x49);
  } else {
    tiff.setUint8(0, 0x4D);
    tiff.setUint8(1, 0x4D);
  }
  tiff.setUint16(2, 42, endian);
  tiff.setUint32(4, 8, endian); // IFD0 sits right after the header.
  tiff.setUint16(8, entryCount, endian);

  // Filler entries with a lower tag id, so the orientation entry is not first.
  for (var index = 0; index < extraEntries; index++) {
    final entry = 10 + (index * 12);
    tiff.setUint16(entry, 0x010F, endian); // Make
    tiff.setUint16(entry + 2, 2, endian); // ASCII
    tiff.setUint32(entry + 4, 1, endian);
    tiff.setUint32(entry + 8, 0, endian);
  }

  final orientationEntry = 10 + (extraEntries * 12);
  tiff.setUint16(orientationEntry, 0x0112, endian);
  tiff.setUint16(orientationEntry + 2, type, endian);
  tiff.setUint32(orientationEntry + 4, 1, endian);
  tiff.setUint16(orientationEntry + 8, orientation, endian);
  tiff.setUint16(orientationEntry + 10, 0, endian); // Pad the 4-byte value.

  final header = withExifHeader
      ? <int>[0x45, 0x78, 0x69, 0x66, 0x00, 0x00]
      : <int>[0x4E, 0x6F, 0x70, 0x65, 0x00, 0x00];
  final payload = <int>[...header, ...tiff.buffer.asUint8List()];
  final segmentLength = payload.length + 2;

  return Uint8List.fromList([
    0xFF, 0xD8, // SOI
    0xFF, 0xE1, // APP1
    (segmentLength >> 8) & 0xFF, segmentLength & 0xFF,
    ...payload,
    0xFF, 0xD9, // EOI
  ]);
}

int _readOrientation(Uint8List bytes, {Endian endian = Endian.little}) {
  // The orientation value is the last SHORT written by the builder above.
  final data = ByteData.sublistView(bytes);
  for (var offset = 0; offset + 12 <= bytes.length; offset++) {
    if (data.getUint16(offset, endian) == 0x0112 &&
        data.getUint16(offset + 2, endian) == 3) {
      return data.getUint16(offset + 8, endian);
    }
  }
  fail('no orientation tag found');
}

void main() {
  group('unmirroredOrientation', () {
    test('drops the mirror flag but keeps the rotation', () {
      expect(unmirroredOrientation(2), 1);
      expect(unmirroredOrientation(4), 3);
      expect(unmirroredOrientation(5), 8);
      expect(unmirroredOrientation(7), 6);
    });

    test('leaves the four non-mirrored orientations alone', () {
      for (final orientation in [1, 3, 6, 8]) {
        expect(unmirroredOrientation(orientation), orientation);
      }
    });
  });

  group('stripExifMirrorFlag', () {
    test('rewrites every mirrored orientation in place', () {
      const expected = {2: 1, 4: 3, 5: 8, 7: 6};
      expected.forEach((mirrored, corrected) {
        final bytes = _jpegWithOrientation(mirrored);
        final originalLength = bytes.length;
        expect(
          stripExifMirrorFlag(bytes),
          isTrue,
          reason: 'orientation $mirrored',
        );
        expect(_readOrientation(bytes), corrected);
        // Lossless: only the tag changes, the buffer keeps its size.
        expect(bytes.length, originalLength);
      });
    });

    test('handles big-endian TIFF headers', () {
      final bytes = _jpegWithOrientation(5, endian: Endian.big);
      expect(stripExifMirrorFlag(bytes), isTrue);
      expect(_readOrientation(bytes, endian: Endian.big), 8);
    });

    test('finds the tag when it is not the first IFD entry', () {
      final bytes = _jpegWithOrientation(7, extraEntries: 3);
      expect(stripExifMirrorFlag(bytes), isTrue);
      expect(_readOrientation(bytes), 6);
    });

    test('leaves rear-camera and gallery orientations untouched', () {
      for (final orientation in [1, 3, 6, 8]) {
        final bytes = _jpegWithOrientation(orientation);
        final before = Uint8List.fromList(bytes);
        expect(stripExifMirrorFlag(bytes), isFalse);
        expect(bytes, before);
      }
    });

    test('refuses anything that is not a JPEG with EXIF', () {
      // Not a JPEG at all.
      expect(stripExifMirrorFlag(Uint8List.fromList([1, 2, 3, 4])), isFalse);
      expect(stripExifMirrorFlag(Uint8List(0)), isFalse);
      // PNG signature.
      expect(
        stripExifMirrorFlag(
          Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
        ),
        isFalse,
      );
      // APP1 that is not an EXIF block.
      expect(
        stripExifMirrorFlag(_jpegWithOrientation(5, withExifHeader: false)),
        isFalse,
      );
      // Orientation stored with an unexpected tag type.
      expect(stripExifMirrorFlag(_jpegWithOrientation(5, type: 4)), isFalse);
    });

    test('does not walk off the end of a truncated file', () {
      final full = _jpegWithOrientation(5);
      for (var length = 1; length < full.length; length++) {
        final truncated = Uint8List.sublistView(full, 0, length);
        expect(
          () => stripExifMirrorFlag(Uint8List.fromList(truncated)),
          returnsNormally,
          reason: 'truncated to $length bytes',
        );
      }
    });
  });
}
