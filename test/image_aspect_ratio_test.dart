import 'dart:typed_data';

import 'package:flutter_application_1/services/image_aspect_ratio.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test('rejects unknown or incomplete image data', () {
    expect(imageAspectRatioFromBytes(Uint8List.fromList([1, 2, 3])), isNull);
  });
}
