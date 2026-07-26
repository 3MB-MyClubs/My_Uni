import 'app_strings.dart';

/// Lightweight pre-publication safety filter.
///
/// This is a first line of defense, not a substitute for human review. The
/// report/block queue handles context-dependent violations that an on-device
/// phrase filter cannot reliably identify.
class ContentSafetyService {
  static final _blockedPatterns = <RegExp>[
    RegExp(r'\bkill\s+yourself\b', caseSensitive: false),
    RegExp(
      r"\b(?:i(?:\s+am|'m)\s+going\s+to|i\s+will)\s+kill\s+you\b",
      caseSensitive: false,
    ),
    RegExp(r'\bsend\s+(?:me\s+)?nudes?\b', caseSensitive: false),
    RegExp(r'\bchild\s+(?:porn|sexual\s+content)\b', caseSensitive: false),
    RegExp(
      r'\b(?:share|send)\s+(?:your\s+)?(?:password|verification\s+code)\b',
      caseSensitive: false,
    ),
  ];

  String? rejectionMessage(Iterable<String> values) {
    final content = values.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (content.isEmpty) return null;
    if (_blockedPatterns.any((pattern) => pattern.hasMatch(content))) {
      return S.contentSafetyRejected;
    }
    return null;
  }
}

final contentSafetyService = ContentSafetyService();

class ContentSafetyException implements Exception {
  final String message;

  const ContentSafetyException(this.message);

  @override
  String toString() => message;
}
