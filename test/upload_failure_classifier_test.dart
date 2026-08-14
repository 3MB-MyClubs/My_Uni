import 'dart:io';

import 'package:flutter_application_1/services/upload_failure_classifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('classifies transient upload failures as retryable', () {
    expect(
      classifyUploadFailure(const StorageException('down', statusCode: '503')),
      UploadFailureKind.retryable,
    );
    expect(
      classifyUploadFailure(const SocketException('offline')),
      UploadFailureKind.retryable,
    );
  });

  test('classifies rejected uploads as permanent', () {
    for (final status in ['400', '401', '403', '413']) {
      expect(
        classifyUploadFailure(StorageException('rejected', statusCode: status)),
        UploadFailureKind.permanent,
      );
    }
    expect(
      classifyUploadFailure(StateError('file too large')),
      UploadFailureKind.permanent,
    );
  });
}
