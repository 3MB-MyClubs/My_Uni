import 'package:flutter/material.dart';

import 'club_chat_theme.dart';

/// Bottom sheet holding one community panel — the members roster the ••• menu
/// opens.
///
/// The Board + Chat design retired the tabbed Members / Events / Notices sheet:
/// the Board is the notice archive, Events live in the club's Events tab, and
/// this sheet keeps only the chrome — grab handle, title, and scrolling.
class ClubCommunitySheet extends StatelessWidget {
  const ClubCommunitySheet({
    super.key,
    required this.t,
    required this.title,
    required this.builder,
  });

  final ClubChatTheme t;
  final String title;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
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
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 13, 16, 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: t.hair)),
              ),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  color: t.text,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                child: builder(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
