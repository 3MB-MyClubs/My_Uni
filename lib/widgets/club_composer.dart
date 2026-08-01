import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../l10n/app_localizations.dart';
import '../services/app_strings.dart';
import '../services/club_role_localization.dart';
import 'club_chat_theme.dart';
import 'club_stream_items.dart';

/// What the "+" sheet can attach to a community message.
enum ClubAttachment { photo, poll, event }

/// Community composer: attachment sheet, @-mention autocomplete, and send.
class ClubComposer extends StatefulWidget {
  const ClubComposer({
    super.key,
    required this.controller,
    required this.t,
    required this.hintText,
    required this.people,
    required this.avatarBuilder,
    required this.onSend,
    required this.onAttach,
    required this.onTypingChanged,
    this.enabled = true,
  });

  final TextEditingController controller;
  final ClubChatTheme t;
  final String hintText;

  /// Members that can be mentioned, board members first.
  final List<ClubPerson> people;
  final Widget Function(ClubPerson person, double size) avatarBuilder;

  /// Sends the draft with the user ids (plus `everyone`) it mentions.
  final void Function(String text, List<String> mentions) onSend;
  final void Function(ClubAttachment attachment) onAttach;
  final VoidCallback onTypingChanged;
  final bool enabled;

  /// Resolves `@token`s in [text] to member ids using [people].
  static List<String> resolveMentions(String text, List<ClubPerson> people) {
    final mentions = <String>{};
    for (final match in RegExp(r'@([\wçğıöşüÇĞİÖŞÜ]+)').allMatches(text)) {
      final token = match.group(1)!.toLowerCase();
      if (token == 'everyone' || token == S.mentionEveryone.toLowerCase()) {
        mentions.add(ChatMessage.everyoneMention);
        continue;
      }
      for (final person in people) {
        final name = person.name.toLowerCase();
        final first = name.split(RegExp(r'\s+')).first;
        if (first == token || name.replaceAll(' ', '') == token) {
          mentions.add(person.id);
          break;
        }
      }
    }
    return mentions.toList(growable: false);
  }

  @override
  State<ClubComposer> createState() => _ClubComposerState();
}

class _ClubComposerState extends State<ClubComposer> {
  static final _mentionQuery = RegExp(r'(^|\s)@([\wçğıöşüÇĞİÖŞÜ]*)$');

  final _focusNode = FocusNode();
  bool _attachOpen = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
    if (widget.controller.text.trim().isNotEmpty) widget.onTypingChanged();
  }

  List<ClubPerson> get _suggestions {
    final selection = widget.controller.selection;
    final text = widget.controller.text;
    final caret = selection.isValid ? selection.baseOffset : text.length;
    if (caret < 0 || caret > text.length) return const [];
    final match = _mentionQuery.firstMatch(text.substring(0, caret));
    if (match == null) return const [];
    final query = (match.group(2) ?? '').toLowerCase();
    final everyone = ClubPerson(
      id: ChatMessage.everyoneMention,
      name: S.mentionEveryone,
      role: S.allMembers,
    );
    return [everyone, ...widget.people]
        .where((person) => person.name.toLowerCase().startsWith(query))
        .take(4)
        .toList(growable: false);
  }

  void _pick(ClubPerson person) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final caret = selection.isValid ? selection.baseOffset : text.length;
    final head = text.substring(0, caret);
    final token = person.id == ChatMessage.everyoneMention
        ? S.mentionEveryone
        : person.name.split(RegExp(r'\s+')).first;
    final replaced = head.replaceFirst(
      RegExp(r'@[\wçğıöşüÇĞİÖŞÜ]*$'),
      '@$token ',
    );
    final next = replaced + text.substring(caret);
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: replaced.length),
    );
    _focusNode.requestFocus();
  }

  void _send() {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text, ClubComposer.resolveMentions(text, widget.people));
    widget.controller.clear();
    setState(() => _attachOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final hasDraft = widget.enabled && widget.controller.text.trim().isNotEmpty;
    final suggestions = _suggestions;

    return Container(
      decoration: BoxDecoration(
        color: t.body,
        border: Border(top: BorderSide(color: t.hair)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (suggestions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Container(
                  key: const ValueKey('club-mention-suggestions'),
                  decoration: BoxDecoration(
                    color: t.sheet,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: t.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final person in suggestions)
                        InkWell(
                          onTap: () => _pick(person),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: t.hair)),
                            ),
                            child: Row(
                              children: [
                                person.id == ChatMessage.everyoneMention
                                    ? Container(
                                        width: 26,
                                        height: 26,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: t.ltRed,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.alternate_email_rounded,
                                          size: 15,
                                          color: t.red,
                                        ),
                                      )
                                    : widget.avatarBuilder(person, 26),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    person.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: t.text,
                                    ),
                                  ),
                                ),
                                Text(
                                  localizedClubRole(
                                    AppLocalizations.of(context)!,
                                    person.role ?? S.memberRole,
                                  ),
                                  style: TextStyle(fontSize: 11, color: t.sub),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            if (_attachOpen)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
                child: Row(
                  key: const ValueKey('club-attach-sheet'),
                  children: [
                    for (final entry in const [
                      (ClubAttachment.photo, Icons.image_outlined),
                      (ClubAttachment.poll, Icons.bar_chart_rounded),
                      (ClubAttachment.event, Icons.calendar_today_outlined),
                    ])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _attachOpen = false);
                              widget.onAttach(entry.$1);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                color: t.solid,
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(color: t.border),
                              ),
                              child: Column(
                                children: [
                                  Icon(entry.$2, size: 19, color: t.red),
                                  const SizedBox(height: 6),
                                  Text(
                                    _attachLabel(entry.$1),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: t.textSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  GestureDetector(
                    key: const ValueKey('club-attach-button'),
                    onTap: widget.enabled
                        ? () => setState(() => _attachOpen = !_attachOpen)
                        : null,
                    child: AnimatedRotation(
                      turns: _attachOpen ? 0.125 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _attachOpen ? t.ltRed : t.solid,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _attachOpen ? t.red : t.border,
                          ),
                        ),
                        child: Icon(Icons.add_rounded, size: 20, color: t.red),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 42),
                      padding: const EdgeInsets.only(left: 15, right: 6),
                      decoration: BoxDecoration(
                        color: t.input,
                        borderRadius: BorderRadius.circular(21),
                        border: Border.all(color: t.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: widget.controller,
                              focusNode: _focusNode,
                              enabled: widget.enabled,
                              minLines: 1,
                              maxLines: 4,
                              textCapitalization: TextCapitalization.sentences,
                              onSubmitted: (_) => _send(),
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w500,
                                color: t.text,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                hintText: widget.hintText,
                                hintStyle: TextStyle(
                                  fontSize: 14.5,
                                  color: t.sub,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 11,
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            key: const ValueKey('club-mention-button'),
                            onTap: widget.enabled ? _insertMentionToken : null,
                            child: SizedBox(
                              width: 32,
                              height: 40,
                              child: Icon(
                                Icons.alternate_email_rounded,
                                size: 18,
                                color: t.sub,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  GestureDetector(
                    onTap: hasDraft ? _send : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: hasDraft ? t.meGradient : null,
                        color: hasDraft ? null : t.solid,
                        shape: BoxShape.circle,
                        border: hasDraft ? null : Border.all(color: t.border),
                      ),
                      child: Icon(
                        Icons.send_rounded,
                        size: 19,
                        color: hasDraft ? Colors.white : t.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _insertMentionToken() {
    final text = widget.controller.text;
    final needsSpace = text.isNotEmpty && !text.endsWith(' ');
    final next = '$text${needsSpace ? ' ' : ''}@';
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _focusNode.requestFocus();
  }

  String _attachLabel(ClubAttachment attachment) => switch (attachment) {
    ClubAttachment.photo => S.attachPhoto,
    ClubAttachment.poll => S.attachPoll,
    ClubAttachment.event => S.attachEvent,
  };
}
