import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../services/user_profile_link.dart';

typedef PlainMessageSpanBuilder = InlineSpan Function(String text);

/// Message text that turns `kuclubs://user/...` values into tappable links.
class UserProfileLinkText extends StatefulWidget {
  const UserProfileLinkText({
    super.key,
    required this.text,
    required this.style,
    required this.linkStyle,
    required this.onUserLinkTap,
    this.plainTextSpanBuilder,
  });

  final String text;
  final TextStyle style;
  final TextStyle linkStyle;
  final ValueChanged<String> onUserLinkTap;

  /// Lets richer chat surfaces retain formatting such as mention pills in the
  /// non-link portions of the message.
  final PlainMessageSpanBuilder? plainTextSpanBuilder;

  @override
  State<UserProfileLinkText> createState() => _UserProfileLinkTextState();
}

class _UserProfileLinkTextState extends State<UserProfileLinkText> {
  final Map<String, TapGestureRecognizer> _recognizers = {};

  TapGestureRecognizer _recognizerFor(
    String key,
    String userIdentifier,
    Set<String> usedKeys,
  ) {
    usedKeys.add(key);
    final recognizer = _recognizers.putIfAbsent(key, TapGestureRecognizer.new);
    recognizer.onTap = () => widget.onUserLinkTap(userIdentifier);
    return recognizer;
  }

  InlineSpan _plainSpan(String text) =>
      widget.plainTextSpanBuilder?.call(text) ?? TextSpan(text: text);

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    final usedRecognizerKeys = <String>{};
    var cursor = 0;

    for (final match in UserProfileLink.matchesIn(widget.text)) {
      if (match.start > cursor) {
        spans.add(_plainSpan(widget.text.substring(cursor, match.start)));
      }
      final recognizerKey = '${match.start}:${match.end}:${match.link}';
      spans.add(
        TextSpan(
          text: match.link,
          style: widget.linkStyle,
          recognizer: _recognizerFor(
            recognizerKey,
            match.userIdentifier,
            usedRecognizerKeys,
          ),
        ),
      );
      cursor = match.end;
    }

    if (cursor < widget.text.length) {
      spans.add(_plainSpan(widget.text.substring(cursor)));
    }
    if (spans.isEmpty) spans.add(_plainSpan(widget.text));

    final staleKeys = _recognizers.keys
        .where((key) => !usedRecognizerKeys.contains(key))
        .toList(growable: false);
    for (final key in staleKeys) {
      _recognizers.remove(key)?.dispose();
    }

    return Text.rich(TextSpan(style: widget.style, children: spans));
  }

  @override
  void dispose() {
    for (final recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    _recognizers.clear();
    super.dispose();
  }
}
