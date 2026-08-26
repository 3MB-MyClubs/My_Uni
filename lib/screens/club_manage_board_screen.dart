import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/club.dart';
import '../models/user.dart';
import '../services/app_strings.dart';
import '../services/club_role_localization.dart';
import '../services/mock_data.dart' show clubMembers, users;
import '../services/people_service.dart';
import '../services/student_club_role_service.dart';
import '../services/user_state.dart';
import '../widgets/club_profile_design.dart';
import '../widgets/user_avatar.dart';
import 'club_board_members_screen.dart' show showClubBoardMemberActions;

/// `board-members-light` / `-dark` — Figma `413:7` / `413:105`, inside
/// `canvas-preview` `413:6`.
///
/// The club's own Manage Board Members screen, pushed from
/// Settings ▸ Manage Board Members. Replaces `BoardManagementSheet` for club
/// sessions; students and the ClubUp moderator never reach this row, so the
/// legacy sheet is left standing for them.
///
/// Two deliberate departures from the frame, both agreed before building:
///
/// * **The accent.** Every accent on the frame is drawn `#1DA1F2` — the Add
///   button, the role line, the lit tab, even the trash glyph. It is the only
///   frame in this section not on `#800020`, i.e. a mockup default, so the
///   screen uses [ClubProfileColors.accent] like its neighbours and paints the
///   remove control [ClubProfileColors.danger] instead of blue.
/// * **The bottom nav** the frame draws is mockup context. This is a pushed
///   route and covers the real bar, exactly like `board-members-all` `346:6`,
///   which draws no nav either.
///
/// No new persistence: adding, retitling and removing all go through
/// `studentClubRoleService.setBoardMembership`, the same call the sheet made.
class ClubManageBoardScreen extends StatefulWidget {
  const ClubManageBoardScreen({super.key, required this.club});

  final Club club;

  @override
  State<ClubManageBoardScreen> createState() => _ClubManageBoardScreenState();
}

class _ClubManageBoardScreenState extends State<ClubManageBoardScreen> {
  final TextEditingController _search = TextEditingController();
  final TextEditingController _role = TextEditingController();

  /// Everyone the screen has ever resolved, so a board member still renders
  /// after being filtered out of the candidate list.
  final Map<String, User> _pool = <String, User>{};

  List<User> _members = const [];
  String _query = '';
  String? _selectedId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _absorb(clubMembers(widget.club.id));
    _absorb(users);
    _absorb(peopleService.cachedPeople);
    _members = _sorted(clubMembers(widget.club.id));
    unawaited(_load());
  }

  @override
  void dispose() {
    _search.dispose();
    _role.dispose();
    super.dispose();
  }

  void _absorb(Iterable<User> people) {
    for (final person in people) {
      _pool[person.id] = person;
    }
  }

  Future<void> _load() async {
    List<User> fetched = const [];
    try {
      fetched = await peopleService.fetchClubMembers(widget.club.id);
    } catch (_) {
      // Offline, or before the first sync — the local roster already showing
      // is the right fallback.
    }
    if (!mounted || fetched.isEmpty) return;
    _absorb(fetched);
    setState(() => _members = _sorted(fetched));
  }

  List<User> _sorted(List<User> source) {
    final sorted = [...source];
    sorted.sort(
      (a, b) => _nameOf(a).toLowerCase().compareTo(_nameOf(b).toLowerCase()),
    );
    return sorted;
  }

  String _nameOf(User user) => userState.displayNameFor(user.id, user.name);

  /// `search-results-dropdown` `413:35` — club members who are not on the
  /// board yet, narrowed by the search field.
  List<User> get _candidates {
    final query = _query.trim().toLowerCase();
    return _members.where((user) {
      if (widget.club.boardMemberIds.contains(user.id)) return false;
      if (query.isEmpty) return true;
      return _nameOf(user).toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query);
    }).toList();
  }

  /// `members-list-card` `413:53`, in the club's own board order.
  List<User> get _board => widget.club.boardMemberIds
      .map((id) => _pool[id])
      .whereType<User>()
      .toList();

  String _roleFor(BuildContext context, User member) {
    final title = widget.club.boardMemberTitles[member.id]?.trim() ?? '';
    if (title.isEmpty) return AppLocalizations.of(context)!.boardMemberLabel;
    return localizedClubRole(AppLocalizations.of(context)!, title);
  }

  /// The frame tints exactly one role line — "President". Matching the
  /// localized label reproduces that without inventing a seniority order.
  bool _isLeadRole(BuildContext context, String role) =>
      role == AppLocalizations.of(context)!.clubRolePresident;

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  void _showRoleError() =>
      _toast(AppLocalizations.of(context)!.couldNotUpdateBoardRole);

  Future<bool> _apply({
    required String userId,
    required bool isBoardMember,
    String? title,
  }) async {
    setState(() => _busy = true);
    try {
      await studentClubRoleService.setBoardMembership(
        club: widget.club,
        userId: userId,
        isBoardMember: isBoardMember,
        title: title,
      );
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        _showRoleError();
      }
      return false;
    }
    if (mounted) setState(() => _busy = false);
    return true;
  }

  // ── actions ────────────────────────────────────────────────────────────────

  Future<void> _addSelected() async {
    final id = _selectedId;
    if (id == null) {
      _toast(S.clubBoardPickSomeone);
      return;
    }
    final title = _role.text.trim();
    if (title.isEmpty) {
      _toast(S.clubBoardRoleRequired);
      return;
    }
    // Reset the composer up front so the row leaves the dropdown and the
    // keyboard closes the moment the club commits, not a round-trip later.
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _selectedId = null;
      _role.clear();
      _search.clear();
      _query = '';
    });
    final added = await _apply(userId: id, isBoardMember: true, title: title);
    // The write failed and said so — hand the club back what it had typed.
    if (!added && mounted) {
      setState(() {
        _selectedId = id;
        _role.text = title;
      });
    }
  }

  Future<void> _remove(User member) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('club-manage-board-remove-confirm'),
        backgroundColor: ClubProfileColors.card,
        title: Text(
          l10n.removeBoardMemberTitle,
          style: figtree(
            size: 16,
            weight: FontWeight.w800,
            color: ClubProfileColors.text,
          ),
        ),
        content: Text(
          l10n.confirmRemoveBoardMemberBody(_nameOf(member)),
          style: figtree(
            size: 13.5,
            weight: FontWeight.w400,
            color: ClubProfileColors.muted,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              l10n.cancel,
              style: figtree(
                size: 13.5,
                weight: FontWeight.w600,
                color: ClubProfileColors.muted,
              ),
            ),
          ),
          TextButton(
            key: const ValueKey('club-manage-board-remove-confirm-yes'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              l10n.removeLabel,
              style: figtree(
                size: 13.5,
                weight: FontWeight.w700,
                color: ClubProfileColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _apply(userId: member.id, isBoardMember: false);
  }

  /// The frame draws no retitle control, so it stays on the long press this
  /// section uses for every undrawn action.
  Future<void> _editTitle(User member) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _TitleDialog(
        initialTitle: widget.club.boardMemberTitles[member.id] ?? '',
      ),
    );
    if (result == null || !mounted) return;
    await _apply(
      userId: member.id,
      isBoardMember: result.trim().isNotEmpty,
      title: result,
    );
  }

  Future<void> _memberActions(User member) => showClubBoardMemberActions(
    context: context,
    onEditTitle: () => _editTitle(member),
    onRemove: () => _remove(member),
  );

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final board = _board;

    return Scaffold(
      backgroundColor: ClubProfileColors.page,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClubProfileHeaderBar(
              key: const ValueKey('club-manage-board-header'),
              title: S.clubProfileBoardMembersTitle,
              compact: true,
              onBack: () => Navigator.maybePop(context),
            ),
            Expanded(
              child: ListView(
                key: const ValueKey('club-manage-board-scroll'),
                padding: const EdgeInsets.fromLTRB(
                  kClubProfileGutter,
                  8,
                  kClubProfileGutter,
                  28,
                ),
                children: [
                  _SectionLabel(S.clubBoardAddSection),
                  const SizedBox(height: 8),
                  _buildAddCard(),
                  const SizedBox(height: 20),
                  _SectionLabel(S.clubBoardCurrentCount(board.length)),
                  const SizedBox(height: 8),
                  _buildBoardCard(board),
                  if (board.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      S.clubBoardManageHint,
                      style: figtree(
                        size: 12,
                        weight: FontWeight.w400,
                        color: ClubProfileColors.muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// `add-member-card` `413:30`.
  Widget _buildAddCard() {
    final candidates = _candidates;
    return ClubProfileCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FilledField(
            key: const ValueKey('club-manage-board-search'),
            controller: _search,
            hint: S.clubBoardSearchByName,
            icon: Icons.search_rounded,
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 14),
          _buildDropdown(candidates),
          const SizedBox(height: 14),
          Text(
            S.clubBoardRoleLabel,
            style: figtree(
              size: 13,
              weight: FontWeight.w600,
              color: ClubProfileColors.text,
            ),
          ),
          const SizedBox(height: 6),
          _FilledField(
            key: const ValueKey('club-manage-board-role'),
            controller: _role,
            hint: S.clubBoardRoleHint,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          _PillButton(
            key: const ValueKey('club-manage-board-add'),
            label: S.clubBoardAddToBoard,
            enabled:
                _selectedId != null && _role.text.trim().isNotEmpty && !_busy,
            onTap: _busy ? null : _addSelected,
          ),
        ],
      ),
    );
  }

  /// `search-results-dropdown` `413:35` — 4 rows of 64pt on the frame, so the
  /// list scrolls inside that height rather than growing the card.
  Widget _buildDropdown(List<User> candidates) {
    final empty = candidates.isEmpty;
    return Container(
      constraints: const BoxConstraints(maxHeight: 256),
      decoration: BoxDecoration(
        color: ClubProfileColors.field,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: empty
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
              child: Text(
                _query.trim().isEmpty
                    ? S.clubBoardNoCandidates
                    : S.clubBoardNoCandidateMatch,
                textAlign: TextAlign.center,
                style: figtree(
                  size: 12.5,
                  weight: FontWeight.w500,
                  color: ClubProfileColors.muted,
                  height: 1.4,
                ),
              ),
            )
          : ListView.separated(
              key: const ValueKey('club-manage-board-candidates'),
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: candidates.length,
              separatorBuilder: (_, _) =>
                  Container(height: 1, color: ClubProfileColors.border),
              itemBuilder: (context, i) {
                final user = candidates[i];
                final selected = user.id == _selectedId;
                return GestureDetector(
                  key: ValueKey('club-manage-board-candidate-${user.id}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () =>
                      setState(() => _selectedId = selected ? null : user.id),
                  child: Container(
                    height: 64,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    color: selected
                        ? ClubProfileColors.accentSurface
                        : Colors.transparent,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: ClipOval(
                            child: UserAvatar(
                              userId: user.id,
                              name: user.name,
                              size: 40,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _nameOf(user),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: figtree(
                              size: 14,
                              weight: FontWeight.w700,
                              color: ClubProfileColors.text,
                            ),
                          ),
                        ),
                        // `select-btn` `416:23` — the frame's 32pt trailing
                        // square, drawn only on the picked row.
                        if (selected)
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: ClubProfileColors.accent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  /// `members-list-card` `413:53`.
  Widget _buildBoardCard(List<User> board) {
    final l10n = AppLocalizations.of(context)!;
    if (board.isEmpty) {
      return ClubProfileCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Text(
          l10n.noBoardMembers,
          textAlign: TextAlign.center,
          style: figtree(
            size: 13,
            weight: FontWeight.w500,
            color: ClubProfileColors.muted,
            height: 1.4,
          ),
        ),
      );
    }

    return ClubProfileCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < board.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(height: 1, color: ClubProfileColors.border),
              ),
            _buildMemberRow(board[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildMemberRow(User member) {
    final role = _roleFor(context, member);
    return GestureDetector(
      key: ValueKey('club-manage-board-member-${member.id}'),
      behavior: HitTestBehavior.opaque,
      onLongPress: _busy ? null : () => unawaited(_memberActions(member)),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: ClipOval(
                child: UserAvatar(
                  userId: member.id,
                  name: member.name,
                  size: 40,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _nameOf(member),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: figtree(
                      size: 14,
                      weight: FontWeight.w700,
                      color: ClubProfileColors.text,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    role,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: figtree(
                      size: 12,
                      weight: FontWeight.w500,
                      color: _isLeadRole(context, role)
                          ? ClubProfileColors.accentText
                          : ClubProfileColors.muted,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // `remove-btn` `413:61` — blue on the frame, destructive here.
            GestureDetector(
              key: ValueKey('club-manage-board-remove-${member.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: _busy ? null : () => unawaited(_remove(member)),
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ClubProfileColors.dangerSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  size: 16,
                  color: ClubProfileColors.danger,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `section-label` `413:28` — an uppercase 11pt tracked label above each card.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: figtree(
          size: 11,
          weight: FontWeight.w700,
          color: ClubProfileColors.muted,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// `search-field` `413:31` and `role-textfield` `413:46` — a clean 44pt field
/// with no fill or border because both sit inside a card.
class _FilledField extends StatelessWidget {
  const _FilledField({
    super.key,
    required this.controller,
    required this.hint,
    this.icon,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: ClubProfileColors.muted),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: autofocus,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                textInputAction: TextInputAction.done,
                style: figtree(
                  size: 13.5,
                  weight: FontWeight.w500,
                  color: ClubProfileColors.text,
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
                    color: ClubProfileColors.muted,
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

/// `add-to-board-btn` `413:48` — a 41pt full-radius accent pill.
class _PillButton extends StatelessWidget {
  const _PillButton({
    super.key,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 41,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ClubProfileColors.accent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: figtree(
              size: 14,
              weight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// The retitle dialog behind a member row's long press. It owns its controller
/// so the field is not disposed underneath the dialog's exit transition.
class _TitleDialog extends StatefulWidget {
  const _TitleDialog({required this.initialTitle});

  final String initialTitle;

  @override
  State<_TitleDialog> createState() => _TitleDialogState();
}

class _TitleDialogState extends State<_TitleDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialTitle,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      key: const ValueKey('club-manage-board-title-dialog'),
      backgroundColor: ClubProfileColors.card,
      title: Text(
        l10n.setTitleTooltip,
        style: figtree(
          size: 16,
          weight: FontWeight.w800,
          color: ClubProfileColors.text,
        ),
      ),
      content: _FilledField(
        controller: _controller,
        hint: S.clubBoardRoleHint,
        autofocus: true,
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            l10n.cancel,
            style: figtree(
              size: 13.5,
              weight: FontWeight.w600,
              color: ClubProfileColors.muted,
            ),
          ),
        ),
        TextButton(
          key: const ValueKey('club-manage-board-title-save'),
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(
            l10n.save,
            style: figtree(
              size: 13.5,
              weight: FontWeight.w700,
              color: ClubProfileColors.accentText,
            ),
          ),
        ),
      ],
    );
  }
}
