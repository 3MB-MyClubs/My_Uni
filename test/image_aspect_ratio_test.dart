import 'dart:typed_data';

import 'package:flutter_application_1/services/image_aspect_ratio.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _orientedJpeg({
  required int width,
  required int height,
  required int orientation,
}) {
  final tiff = ByteData(26)
    ..setUint8(0, 0x49)
    ..setUint8(1, 0x49)
    ..setUint16(2, 42, Endian.little)
    ..setUint32(4, 8, Endian.little)
    ..setUint16(8, 1, Endian.little)
    ..setUint16(10, 0x0112, Endian.little)
    ..setUint16(12, 3, Endian.little)
    ..setUint32(14, 1, Endian.little)
    ..setUint16(18, orientation, Endian.little);
  final exifPayload = <int>[
    0x45,
    0x78,
    0x69,
    0x66,
    0,
    0,
    ...tiff.buffer.asUint8List(),
  ];
  final exifLength = exifPayload.length + 2;
  return Uint8List.fromList([
    0xFF,
    0xD8,
    0xFF,
    0xE1,
    exifLength >> 8,
    exifLength & 0xFF,
    ...exifPayload,
    0xFF,
    0xC0,
    0x00,
    0x11,
    0x08,
    height >> 8,
    height & 0xFF,
    width >> 8,
    width & 0xFF,
    0x03,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
  ]);
}

void main() {
  test('reads portrait PNG dimensions from its header', () {
    final bytes = Uint8List(24);
    bytes.setAll(0, const [137, 80, 78, 71, 13, 10, 26, 10]);
    ByteData.sublistView(bytes)
      ..setUint32(16, 80, Endian.big)
      ..setUint32(20, 160, Endian.big);

    expect(imageAspectRatioFromBytes(bytes), 0.5);
  });

  test('reads landscape JPEG dimensions from its SOF marker', () {
    final bytes = Uint8List.fromList([
      0xFF, 0xD8, // Start of image.
      0xFF, 0xC0, // Baseline start-of-frame marker.
      0x00, 0x11, // Segment length.
      0x08, // Precision.
      0x00, 0x64, // Height: 100.
      0x00, 0xC8, // Width: 200.
      0x03, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    ]);

    expect(imageAspectRatioFromBytes(bytes), 2);
  });

  test('applies camera EXIF rotation before reporting JPEG ratio', () {
    final bytes = _orientedJpeg(width: 160, height: 90, orientation: 6);

    expect(imageAspectRatioFromBytes(bytes), 90 / 160);
  });

  test('rejects unknown or incomplete image data', () {
    expect(imageAspectRatioFromBytes(Uint8List.fromList([1, 2, 3])), isNull);
  });
}
