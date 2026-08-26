import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/club.dart';
import '../models/user.dart';
import '../services/app_strings.dart';
import '../services/club_role_localization.dart';
import '../services/user_state.dart';
import '../widgets/club_profile_design.dart';
import '../widgets/user_avatar.dart';
import 'user_profile_screen.dart';

/// `board-members-all-light` / `-dark` — Figma `346:6` / `346:99`.
///
/// The full list behind the Board tab's "View all". The frame draws a search
/// field and plain rows with a chevron; the club's own edit-title / remove
/// actions have no cell there, so they hang off a long press and are handed in
/// by the caller, which owns that logic already.
class ClubBoardMembersScreen extends StatefulWidget {
  const ClubBoardMembersScreen({
    super.key,
    required this.club,
    required this.members,
    this.onEditTitle,
    this.onRemove,
  });

  final Club club;
  final List<User> members;

  /// Both are null for anyone who cannot manage this club's board.
  final Future<void> Function(User member)? onEditTitle;
  final Future<void> Function(User member)? onRemove;

  @override
  State<ClubBoardMembersScreen> createState() => _ClubBoardMembersScreenState();
}

class _ClubBoardMembersScreenState extends State<ClubBoardMembersScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _canManage => widget.onEditTitle != null || widget.onRemove != null;

  List<User> get _shown {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.members;
    return widget.members.where((member) {
      final name = userState.displayNameFor(member.id, member.name);
      return name.toLowerCase().contains(query) ||
          member.email.toLowerCase().contains(query);
    }).toList();
  }

  String _roleFor(BuildContext context, User member) {
    final title = widget.club.boardMemberTitles[member.id]?.trim() ?? '';
    if (title.isEmpty) return AppLocalizations.of(context)!.boardMemberLabel;
    return localizedClubRole(AppLocalizations.of(context)!, title);
  }

  Future<void> _showMemberActions(User member) async {
    await showClubBoardMemberActions(
      context: context,
      onEditTitle: widget.onEditTitle == null
          ? null
          : () => widget.onEditTitle!(member),
      onRemove: widget.onRemove == null ? null : () => widget.onRemove!(member),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shown = _shown;

    return Scaffold(
      backgroundColor: ClubProfileColors.page,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClubProfileHeaderBar(
              key: const ValueKey('club-board-members-header'),
              title: S.clubProfileBoardMembersTitle,
              compact: true,
              onBack: () => Navigator.maybePop(context),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                kClubProfileGutter,
                12,
                kClubProfileGutter,
                12,
              ),
              child: ClubProfileCard(
                key: const ValueKey('club-board-members-search-card'),
                padding: const EdgeInsets.all(16),
                child: ClubProfileSearchField(
                  controller: _search,
                  hint: S.clubProfileSearchMembers,
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
            ),
            Expanded(
              child: shown.isEmpty
                  ? ListView(
                      children: [
                        ClubProfileEmptyState(
                          icon: Icons.shield_outlined,
                          title: _query.trim().isEmpty
                              ? l10n.noBoardMembers
                              : S.clubProfileNoMembersMatch,
                          message: _query.trim().isEmpty
                              ? l10n.clubAdminsAddMembersHint
                              : null,
                        ),
                      ],
                    )
                  : ListView.separated(
                      key: const ValueKey('club-board-members-list'),
                      padding: const EdgeInsets.fromLTRB(
                        kClubProfileGutter,
                        0,
                        kClubProfileGutter,
                        28,
                      ),
                      itemCount: shown.length + (_canManage ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        if (i == shown.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              S.clubProfileBoardHint,
                              style: figtree(
                                size: 12,
                                weight: FontWeight.w400,
                                color: ClubProfileColors.muted,
                                height: 1.4,
                              ),
                            ),
                          );
                        }
                        final member = shown[i];
                        return ClubProfileMemberRow(
                          key: ValueKey('club-board-member-${member.id}'),
                          avatar: UserAvatar(
                            userId: member.id,
                            name: member.name,
                            size: 44,
                            fontSize: 18,
                          ),
                          name: userState.displayNameFor(
                            member.id,
                            member.name,
                          ),
                          role: _roleFor(context, member),
                          showChevron: true,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserProfileScreen(user: member),
                            ),
                          ),
                          onLongPress: _canManage
                              ? () => _showMemberActions(member)
                              : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The board-row actions the frames leave undrawn — shared by the Board tab
/// and this full list so a long press behaves the same in both.
Future<void> showClubBoardMemberActions({
  required BuildContext context,
  Future<void> Function()? onEditTitle,
  Future<void> Function()? onRemove,
}) async {
  if (onEditTitle == null && onRemove == null) return;
  final l10n = AppLocalizations.of(context)!;
  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: ClubProfileColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ClubProfileColors.border,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 8),
          if (onEditTitle != null)
            ListTile(
              key: const ValueKey('club-board-member-edit'),
              leading: Icon(Icons.edit_outlined, color: ClubProfileColors.text),
              title: Text(
                l10n.setTitleTooltip,
                style: figtree(
                  size: 14,
                  weight: FontWeight.w600,
                  color: ClubProfileColors.text,
                ),
              ),
              onTap: () => Navigator.pop(sheetContext, 'edit'),
            ),
          if (onRemove != null)
            ListTile(
              key: const ValueKey('club-board-member-remove'),
              leading: const Icon(
                Icons.person_remove_outlined,
                color: Color(0xFFDC2626),
              ),
              title: Text(
                l10n.removeFromBoardLabel,
                style: figtree(
                  size: 14,
                  weight: FontWeight.w600,
                  color: const Color(0xFFDC2626),
                ),
              ),
              onTap: () => Navigator.pop(sheetContext, 'remove'),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (action == 'edit') await onEditTitle?.call();
  if (action == 'remove') await onRemove?.call();
}
