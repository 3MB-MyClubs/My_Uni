import 'package:flutter/material.dart';

class ExpandablePostCaption extends StatefulWidget {
  final String authorName;
  final String caption;
  final TextStyle? authorStyle;
  final TextStyle? captionStyle;
  final TextStyle? moreStyle;
  final int collapsedWordCount;

  const ExpandablePostCaption({
    super.key,
    required this.authorName,
    required this.caption,
    this.authorStyle,
    this.captionStyle,
    this.moreStyle,
    this.collapsedWordCount = 7,
  });

  @override
  State<ExpandablePostCaption> createState() => _ExpandablePostCaptionState();
}

class _ExpandablePostCaptionState extends State<ExpandablePostCaption> {
  bool _isExpanded = false;

  @override
  void didUpdateWidget(covariant ExpandablePostCaption oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.caption != widget.caption) {
      _isExpanded = false;
    }
  }

  List<String> get _words {
    final caption = widget.caption.trim();
    return caption.isEmpty ? const [] : caption.split(RegExp(r'\s+'));
  }

  @override
  Widget build(BuildContext context) {
    final words = _words;
    final canExpand = words.length > widget.collapsedWordCount;
    final visibleCaption = canExpand && !_isExpanded
        ? words.take(widget.collapsedWordCount).join(' ')
        : widget.caption;

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '${widget.authorName}  ', style: widget.authorStyle),
          TextSpan(text: visibleCaption, style: widget.captionStyle),
          if (canExpand && !_isExpanded) ...[
            TextSpan(text: '\u2026 ', style: widget.captionStyle),
            _captionControl(
              label: 'more',
              semanticsLabel: 'Show full caption',
              onTap: () => setState(() => _isExpanded = true),
            ),
          ],
          if (canExpand && _isExpanded) ...[
            TextSpan(text: ' ', style: widget.captionStyle),
            _captionControl(
              label: 'less',
              semanticsLabel: 'Show less caption',
              onTap: () => setState(() => _isExpanded = false),
            ),
          ],
        ],
      ),
    );
  }

  WidgetSpan _captionControl({
    required String label,
    required String semanticsLabel,
    required VoidCallback onTap,
  }) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: Semantics(
        button: true,
        label: semanticsLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Text(label, style: widget.moreStyle ?? widget.captionStyle),
        ),
      ),
    );
  }
}
