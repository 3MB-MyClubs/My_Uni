import 'dart:io';
import 'dart:typed_data';

/// Reads the canonical upload as-is. Delivery renditions must never pass
/// through this upload path or replace the returned bytes.
Future<Uint8List> readCanonicalMediaBytes(File file) => file.readAsBytes();
