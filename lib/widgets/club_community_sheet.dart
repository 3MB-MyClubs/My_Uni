import 'package:flutter/material.dart';

import '../services/app_strings.dart';
import 'club_chat_theme.dart';

/// The three panels behind the community context bar.
enum ClubSheetTab { members, events, notices }

/// Bottom sheet holding the Members / Events / Notices panels.
///
/// Panel contents are built by the screen (which owns the live data); this
/// widget owns the chrome: grab handle, segmented tabs, and scrolling.
class ClubCommunitySheet extends StatefulWidget {
  const ClubCommunitySheet({
    super.key,
    required this.t,
    required this.initialTab,
    required this.builders,
  });

  final ClubChatTheme t;
  final ClubSheetTab initialTab;
  final Map<ClubSheetTab, WidgetBuilder> builders;

  @override
  State<ClubCommunitySheet> createState() => _ClubCommunitySheetState();
}

class _ClubCommunitySheetState extends State<ClubCommunitySheet> {
  late ClubSheetTab _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return FractionallySizedBox(
      heightFactor: 0.74,
      child: Container(
        key: const ValueKey('club-community-sheet'),
        decoration: BoxDecoration(
          color: t.sheet,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: t.borderB,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: t.hair)),
              ),
              child: Row(
                children: [
                  for (final tab in ClubSheetTab.values)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: GestureDetector(
                          onTap: () => setState(() => _tab = tab),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: _tab == tab ? t.meGradient : null,
                              borderRadius: BorderRadius.circular(10),
                              border: _tab == tab
                                  ? null
                                  : Border.all(color: t.border),
                            ),
                            child: Text(
                              _label(tab),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: _tab == tab ? Colors.white : t.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                child: widget.builders[_tab]!(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _label(ClubSheetTab tab) => switch (tab) {
    ClubSheetTab.members => S.communityMembersButton,
    ClubSheetTab.events => S.events,
    ClubSheetTab.notices => S.communityNotices,
  };
}

/// Uppercase group heading inside a sheet panel.
class ClubSheetLabel extends StatelessWidget {
  const ClubSheetLabel({
    super.key,
    required this.label,
    required this.t,
    this.top = false,
  });

  final String label;
  final ClubChatTheme t;
  final bool top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(0, top ? 18 : 10, 0, 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.1,
          color: t.sub,
        ),
      ),
    );
  }
}
