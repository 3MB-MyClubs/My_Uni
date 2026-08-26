import 'package:flutter/material.dart';

import '../models/club.dart';
import '../models/user.dart';
import '../services/app_strings.dart';
import '../services/locale_service.dart';
import '../services/mock_data.dart';
import '../services/moderation_service.dart';
import '../services/people_service.dart';
import '../services/user_state.dart';
import '../widgets/club_avatar.dart';
import '../widgets/clubup_design.dart';
import '../widgets/settings_design.dart';
import '../widgets/user_avatar.dart';

/// `blocked-students` / `blocked-clubs` — Figma `414:8` / `414:103` (light) and
/// `414:180` / `414:275` (dark).
///
/// Reached two ways, which is why it is on [SettingsColors] rather than the
/// club ramp: the club's Settings ▸ Blocked People & Clubs, and the student's
/// Settings ▸ Privacy. Those frames sample to `#FAF9F6`/`#09090B` page and
/// `#FFFFFF`/`#18181B` rows — the settings ramp exactly — and draw the ringed
/// back button the student settings header already uses.
///
/// Two departures, both the same calls made on the board screen:
/// * The frame's accents are `#1DA1F2`; the burgundy is used instead.
/// * The frame's bottom nav is mockup context — this is a pushed route.
///
/// Nothing new is stored: the lists are `moderationService.blockedUserIds` /
/// `blockedClubIds` and Unban calls `unblockUser` / `unblockClub`.
class BlockedAccountsScreen extends StatefulWidget {
  const BlockedAccountsScreen({super.key});

  @override
  State<BlockedAccountsScreen> createState() => _BlockedAccountsScreenState();
}

class _BlockedAccountsScreenState extends State<BlockedAccountsScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  int _tab = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  User? _userFor(String id) {
    final all = <String, User>{
      for (final user in users) user.id: user,
      for (final user in peopleService.cachedPeople) user.id: user,
    };
    return all[id];
  }

  Club? _clubFor(String id) {
    for (final club in clubs) {
      if (club.id == id) return club;
    }
    return null;
  }

  bool _matches(String name) {
    final query = _query.trim().toLowerCase();
    return query.isEmpty || name.toLowerCase().contains(query);
  }

  Future<void> _confirmUnblock({
    required String name,
    required Future<void> Function() unblock,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('blocked-unblock-confirm'),
        backgroundColor: SettingsColors.card,
        title: Text(
          S.unblockQuestion(name),
          style: figtree(
            size: 16,
            weight: FontWeight.w800,
            color: SettingsColors.text,
          ),
        ),
        content: Text(
          S.unblockExplanation,
          style: figtree(
            size: 13.5,
            weight: FontWeight.w400,
            color: SettingsColors.muted,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              S.cancel,
              style: figtree(
                size: 13.5,
                weight: FontWeight.w600,
                color: SettingsColors.muted,
              ),
            ),
          ),
          TextButton(
            key: const ValueKey('blocked-unblock-confirm-yes'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              S.unblock,
              style: figtree(
                size: 13.5,
                weight: FontWeight.w700,
                color: SettingsColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await unblock();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(S.unblockFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([localeService, moderationService]),
      builder: (context, _) => Scaffold(
        backgroundColor: SettingsColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsHeaderBar(
                key: const ValueKey('blocked-header'),
                title: S.clubSettingsBlockedRow,
                backTooltip: MaterialLocalizations.of(
                  context,
                ).backButtonTooltip,
                onBack: () => Navigator.of(context).maybePop(),
              ),
              // `search-bar` 414:24.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  kSettingsPagePadding,
                  0,
                  kSettingsPagePadding,
                  12,
                ),
                child: Container(
                  key: const ValueKey('blocked-search-card'),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: SettingsColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: SettingsColors.border),
                  ),
                  child: _BlockedSearchField(
                    controller: _search,
                    hint: S.blockedSearchHint,
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
              ),
              // `filter-tabs` 414:28 — a two-up pill, not a TabBar.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  kSettingsPagePadding,
                  0,
                  kSettingsPagePadding,
                  16,
                ),
                child: SettingsSegmentedToggle(
                  key: const ValueKey('blocked-tabs'),
                  labels: [S.blockedStudentsTab, S.blockedClubsTab],
                  selectedIndex: _tab,
                  expanded: true,
                  onSelected: (index) => setState(() => _tab = index),
                ),
              ),
              Expanded(child: _tab == 0 ? _blockedPeople() : _blockedClubs()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 12),
    child: Text(
      label.toUpperCase(),
      style: figtree(
        size: 11,
        weight: FontWeight.w600,
        color: SettingsColors.muted,
        letterSpacing: 0.6,
      ),
    ),
  );

  Widget _list({required String label, required List<Widget> rows}) {
    if (rows.isEmpty) {
      return _BlockedEmptyState(
        message: _query.trim().isEmpty
            ? (_tab == 0 ? S.noBlockedPeople : S.noBlockedClubs)
            : S.blockedNoMatch,
      );
    }
    return ListView(
      key: const ValueKey('blocked-list'),
      padding: EdgeInsets.fromLTRB(
        kSettingsPagePadding,
        4,
        kSettingsPagePadding,
        28 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        _sectionLabel(label),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          rows[i],
        ],
      ],
    );
  }

  Widget _blockedPeople() {
    final ids = moderationService.blockedUserIds.toList();
    ids.sort((a, b) {
      final aName = _userFor(a)?.name ?? a;
      final bName = _userFor(b)?.name ?? b;
      return aName.toLowerCase().compareTo(bName.toLowerCase());
    });

    final rows = <Widget>[];
    for (final id in ids) {
      final user = _userFor(id);
      final name = user == null
          ? S.people
          : userState.displayNameFor(id, user.name);
      if (!_matches(name)) continue;
      rows.add(
        _BlockedRow(
          key: ValueKey('blocked-user-$id'),
          avatar: UserAvatar(userId: id, name: name, size: 38, fontSize: 15),
          name: name,
          onUnban: () => _confirmUnblock(
            name: name,
            unblock: () => moderationService.unblockUser(id),
          ),
        ),
      );
    }
    return _list(label: S.bannedStudentsLabel, rows: rows);
  }

  Widget _blockedClubs() {
    final ids = moderationService.blockedClubIds.toList();
    ids.sort((a, b) {
      final aName = _clubFor(a)?.name ?? a;
      final bName = _clubFor(b)?.name ?? b;
      return aName.toLowerCase().compareTo(bName.toLowerCase());
    });

    final rows = <Widget>[];
    for (final id in ids) {
      final club = _clubFor(id);
      final name = club?.name ?? S.clubsLabel;
      if (!_matches(name)) continue;
      rows.add(
        _BlockedRow(
          key: ValueKey('blocked-club-$id'),
          avatar: ClubAvatar(
            clubId: id,
            clubName: name,
            color: SettingsColors.accent,
            imageUrl: club?.logoUrl,
            size: 38,
            fontSize: 15,
            borderRadius: 12,
          ),
          name: name,
          // `row-banned-entry` on `blocked-clubs` carries a member count; the
          // app has a real one for every club it knows.
          subtitle: club == null
              ? null
              : S.blockedClubMembers(clubMemberCount(club.id)),
          onUnban: () => _confirmUnblock(
            name: name,
            unblock: () => moderationService.unblockClub(id),
          ),
        ),
      );
    }
    return _list(label: S.bannedClubsLabel, rows: rows);
  }
}

/// `search-bar` `414:24` — a clean 44pt field with no fill or outline.
class _BlockedSearchField extends StatelessWidget {
  const _BlockedSearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 16, color: SettingsColors.muted),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: const ValueKey('blocked-search'),
                controller: controller,
                onChanged: onChanged,
                textInputAction: TextInputAction.done,
                style: figtree(
                  size: 13.5,
                  weight: FontWeight.w500,
                  color: SettingsColors.text,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: hint,
                  hintStyle: figtree(
                    size: 13.5,
                    weight: FontWeight.w400,
                    color: SettingsColors.muted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `row-banned-entry` `414:36` — a 62pt card: 38pt photo, the name, and an
/// outlined Unban pill.
class _BlockedRow extends StatelessWidget {
  const _BlockedRow({
    super.key,
    required this.avatar,
    required this.name,
    required this.onUnban,
    this.subtitle,
  });

  final Widget avatar;
  final String name;
  final String? subtitle;
  final VoidCallback onUnban;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: SettingsColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SettingsColors.border),
      ),
      child: Row(
        children: [
          SizedBox(width: 38, height: 38, child: ClipOval(child: avatar)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: figtree(
                    size: 14,
                    weight: FontWeight.w700,
                    color: SettingsColors.text,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: figtree(
                      size: 12,
                      weight: FontWeight.w400,
                      color: SettingsColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onUnban,
            child: Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: SettingsColors.accent),
              ),
              child: Text(
                S.unblock,
                style: figtree(
                  size: 12.5,
                  weight: FontWeight.w700,
                  color: SettingsColors.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockedEmptyState extends StatelessWidget {
  const _BlockedEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block_outlined, size: 44, color: SettingsColors.muted),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: figtree(
                size: 13,
                weight: FontWeight.w500,
                color: SettingsColors.muted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
