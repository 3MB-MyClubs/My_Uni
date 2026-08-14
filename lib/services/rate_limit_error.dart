import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Parsed server-side 429 metadata. This is UX only; all enforcement remains
/// in Postgres/Edge Functions and cannot be bypassed by omitting this client.
class RateLimitInfo {
  final Duration retryAfter;
  final String serverMessage;

  const RateLimitInfo({required this.retryAfter, required this.serverMessage});

  String get displayMessage {
    final seconds = retryAfter.inSeconds;
    if (seconds <= 0) return serverMessage;
    if (seconds < 60) {
      return 'Too many requests. Try again in $seconds seconds.';
    }
    final minutes = (seconds / 60).ceil();
    return 'Too many requests. Try again in about $minutes minutes.';
  }

  static RateLimitInfo? from(Object? errorOrPayload) {
    if (errorOrPayload is PostgrestException) {
      final details = _mapOf(errorOrPayload.details);
      final isLimited =
          errorOrPayload.code == 'rate_limit_exceeded' ||
          errorOrPayload.message.toLowerCase().contains('too many requests');
      if (!isLimited) return null;
      return _fromMap(details, fallbackMessage: errorOrPayload.message);
    }

    if (errorOrPayload is FunctionException) {
      final details = _mapOf(errorOrPayload.details);
      if (errorOrPayload.status != 429 && !_isLimitedMap(details)) return null;
      return _fromMap(details);
    }

    final payload = _mapOf(errorOrPayload);
    if (!_isLimitedMap(payload)) {
      final text = errorOrPayload?.toString().toLowerCase() ?? '';
      if (!text.contains('rate_limit_exceeded') &&
          !text.contains('too many requests')) {
        return null;
      }
    }
    return _fromMap(payload);
  }

  static bool _isLimitedMap(Map<String, dynamic> value) {
    return value['error'] == 'rate_limit_exceeded' ||
        value['code'] == 'rate_limit_exceeded' ||
        value['status'] == 429 ||
        value['message']?.toString().toLowerCase().contains(
              'too many requests',
            ) ==
            true;
  }

  static RateLimitInfo _fromMap(
    Map<String, dynamic> value, {
    String fallbackMessage = 'Too many requests. Try again later.',
  }) {
    final nested = _mapOf(value['details']);
    final rawRetry =
        value['retry_after_seconds'] ??
        nested['retry_after_seconds'] ??
        value['retryAfterSeconds'];
    final seconds = switch (rawRetry) {
      num number => number.ceil(),
      String text => num.tryParse(text)?.ceil() ?? 0,
      _ => 0,
    };
    final message = value['message']?.toString().trim();
    return RateLimitInfo(
      retryAfter: Duration(seconds: seconds.clamp(0, 86400).toInt()),
      serverMessage: message == null || message.isEmpty
          ? fallbackMessage
          : message,
    );
  }

  static Map<String, dynamic> _mapOf(Object? value) {
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) {
          return decoded.map((key, item) => MapEntry(key.toString(), item));
        }
      } catch (_) {
        // Plain-text server details are not structured rate-limit metadata.
      }
    }
    return const {};
  }
}
