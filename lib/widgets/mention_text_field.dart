import 'package:flutter/material.dart';

import '../services/app_colors.dart';

enum MentionType { club, student }

class MentionOption {
  final String id;
  final String label;
  final MentionType type;

  const MentionOption({
    required this.id,
    required this.label,
    required this.type,
  });
}

class MentionTextField extends StatefulWidget {
  final TextEditingController controller;
  final List<MentionOption> options;
  final InputDecoration? decoration;
  final TextStyle? style;
  final int? maxLines;
  final int? minLines;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<MentionOption>? onMentionSelected;

  const MentionTextField({
    super.key,
    required this.controller,
    required this.options,
    this.decoration,
    this.style,
    this.maxLines = 1,
    this.minLines,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onSubmitted,
    this.onMentionSelected,
  });

  @override
  State<MentionTextField> createState() => _MentionTextFieldState();
}

class _MentionTextFieldState extends State<MentionTextField> {
  static final _mentionPattern = RegExp(r'(^|\s)@([^\s@]*)$');

  List<MentionOption> _matches = const [];
  int? _mentionStart;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncMatches);
  }

  @override
  void didUpdateWidget(covariant MentionTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncMatches);
      widget.controller.addListener(_syncMatches);
      _syncMatches();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncMatches);
    super.dispose();
  }

  void _syncMatches() {
    final selection = widget.controller.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      _clearMatches();
      return;
    }

    final cursor = selection.baseOffset;
    if (cursor < 0 || cursor > widget.controller.text.length) {
      _clearMatches();
      return;
    }

    final beforeCursor = widget.controller.text.substring(0, cursor);
    final match = _mentionPattern.firstMatch(beforeCursor);
    if (match == null) {
      _clearMatches();
      return;
    }

    final query = (match.group(2) ?? '').toLowerCase();
    final start = beforeCursor.lastIndexOf('@');
    final matches = widget.options
        .where((option) => option.label.toLowerCase().contains(query))
        .take(6)
        .toList();

    if (!mounted) return;
    setState(() {
      _mentionStart = start;
      _matches = matches;
    });
  }

  void _clearMatches() {
    if (_matches.isEmpty && _mentionStart == null) return;
    if (!mounted) return;
    setState(() {
      _matches = const [];
      _mentionStart = null;
    });
  }

  void _insertMention(MentionOption option) {
    final start = _mentionStart;
    if (start == null) return;

    final text = widget.controller.text;
    final cursor = widget.controller.selection.baseOffset;
    if (cursor < start || cursor > text.length) return;

    final mention = '@${option.label} ';
    final updated = text.replaceRange(start, cursor, mention);
    final nextOffset = start + mention.length;
    widget.controller.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: nextOffset),
    );
    widget.onChanged?.call(updated);
    widget.onMentionSelected?.call(option);
    _clearMatches();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          style: widget.style,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          textCapitalization: widget.textCapitalization,
          decoration: widget.decoration,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
        ),
        if (_matches.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: _matches.length,
              separatorBuilder: (_, index) => Divider(
                height: 1,
                indent: 52,
                color: AppColors.divider.withValues(alpha: 0.7),
              ),
              itemBuilder: (context, index) {
                final option = _matches[index];
                final isClub = option.type == MentionType.club;
                return InkWell(
                  onTap: () => _insertMention(option),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: isClub
                              ? AppColors.lightRed
                              : AppColors.lightGray,
                          child: Icon(
                            isClub
                                ? Icons.groups_rounded
                                : Icons.person_rounded,
                            size: 16,
                            color: isClub
                                ? AppColors.primaryRed
                                : AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            option.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isClub ? 'Club' : 'Student',
                          style: TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
