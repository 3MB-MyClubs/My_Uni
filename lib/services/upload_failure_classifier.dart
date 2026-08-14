import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

enum UploadFailureKind { retryable, permanent }

UploadFailureKind classifyUploadFailure(Object error) {
  if (error is FileSystemException || error is FormatException) {
    return UploadFailureKind.permanent;
  }
  if (error is SocketException || error is HttpException) {
    return UploadFailureKind.retryable;
  }
  if (error is StorageException) {
    final status = int.tryParse(error.statusCode ?? '');
    if (status == null || status == 408 || status == 429 || status >= 500) {
      return UploadFailureKind.retryable;
    }
    return UploadFailureKind.permanent;
  }
  if (error is PostgrestException) {
    final code = error.code ?? '';
    if (code == 'PGRST301' || code == 'PGRST302') {
      return UploadFailureKind.permanent;
    }
    if (code.startsWith('08') || code == '40001' || code == '40P01') {
      return UploadFailureKind.retryable;
    }
    if (code.startsWith('22') ||
        code.startsWith('23') ||
        code == '42501') {
      return UploadFailureKind.permanent;
    }
  }
  if (error is StateError || error is ArgumentError) {
    return UploadFailureKind.permanent;
  }
  return UploadFailureKind.retryable;
}
