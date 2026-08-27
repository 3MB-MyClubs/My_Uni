import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../services/account_switcher_service.dart';
import '../services/app_strings.dart';
import '../services/auth_service.dart';
import '../services/club_role_localization.dart';
import '../services/theme_service.dart';
import 'club_avatar.dart';
import 'clubup_design.dart';
import 'user_avatar.dart';

/// `profile-switcher-light` / `profile-switcher-dark` (Figma `424:113` /
/// `424:6`, at canvas x=4876 / x=4371, y=1780) from the HOME section of the
/// ClubUp-Desings handoff — the "Switch Account" bottom sheet.
///
/// Scope is the sheet only. The frames also show a mock profile screen behind
/// the scrim; that is context, not part of this pass, and
/// [AccountSwitcherService] is untouched — this is a restyle of the same
/// `prepare()` / `accounts` / `select()` calls the old sheet made.
///
/// Two deliberate departures from the frames:
///
///  * **The accent is burgundy, not `#1DA1F2`.** The handoff drew the selected
///    radio and the avatar rings in Twitter blue; the app's accent is
///    `#800020`, so every blue pixel in the frame is burgundy here.
///  * **The avatar rings are dropped.** The frames ring rows 2 and 4 — every
///    *other* club row — which is mock alternation, not a state: the ringed
///    pair is President + Treasurer against un-ringed Vice President +
///    Secretary, and the selected row has no ring at all. Nothing in
///    [SwitchableAccount] distinguishes them, and a story-style "has unread"
///    ring would be backend work.
///
/// The role line under each club name is real data: [Club.boardMemberTitles]
/// for the signed-in student, run through [localizedClubRole].
Future<void> showAccountSwitcherSheet(BuildContext context) async {
  final service = accountSwitcherService;
  await service.prepare();
  if (!context.mounted || !service.hasSwitchableAccounts) return;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    // The frames' scrim is black at 60% — the mock's white page reads #666666
    // through it.
    barrierColor: const Color(0x99000000),
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => const _AccountSwitcherSheet(),
  );
}

// ── tokens ───────────────────────────────────────────────────────────────────

/// Palette for the switcher sheet.
///
/// Sampled from the two frames, and **not** the zinc set the rest of the
/// handoff uses: this sheet is painted on the iOS system greys — `#FFFFFF` /
/// `#1C1C1E` surface, `#E5E5EA` / `#2C2C2E` hairlines, `#8E8E93` secondary
/// text in both themes. Kept local rather than folded into [ClubUpColors] or
/// `ProfileColors`, both of which carry different values for the same roles.
class AccountSwitcherColors {
  const AccountSwitcherColors._();

  static bool get _dark => themeService.isDark;

  /// Sheet surface — `#FFFFFF` / `#1C1C1E`.
  static Color get sheet =>
      _dark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);

  /// The rules above and below the title, and below the last row —
  /// `#E5E5EA` / `#2C2C2E`.
  static Color get hairline =>
      _dark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);

  /// Drag handle, and the unselected radio's stroke — `#D1D1D6` / `#48484A`.
  static Color get handle =>
      _dark ? const Color(0xFF48484A) : const Color(0xFFD1D1D6);

  /// Title and account name — `#1C1C1E` / `#FFFFFF`.
  static Color get text =>
      _dark ? const Color(0xFFFFFFFF) : const Color(0xFF1C1C1E);

  /// The role line — `#8E8E93` in both themes.
  static const Color muted = Color(0xFF8E8E93);

  /// The selected radio. `#800020` where the frames drew `#1DA1F2`.
  static const Color accent = Color(0xFF800020);
}

// ── sheet ────────────────────────────────────────────────────────────────────

const double _kRowHeight = 64;
const double _kRowGap = 4;
const double _kSheetRadius = 24;

class _AccountSwitcherSheet extends StatelessWidget {
  const _AccountSwitcherSheet();

  @override
  Widget build(BuildContext context) {
    // The frames end in a 34pt home-indicator band, hairline at its top. On a
    // device without one there is still a little breathing room under the last
    // row.
    final bottomInset = MediaQuery.viewPaddingOf(
      context,
    ).bottom.clamp(12.0, 34.0);

    return ListenableBuilder(
      listenable: accountSwitcherService,
      builder: (context, _) {
        final accounts = accountSwitcherService.accounts;
        final active = accountSwitcherService.activeAccount;

        return Container(
          key: const ValueKey('account-switcher-sheet'),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          decoration: BoxDecoration(
            color: AccountSwitcherColors.sheet,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(_kSheetRadius),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _DragHandle(),
              _Hairline(),
              const _SheetTitle(),
              _Hairline(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final (index, account) in accounts.indexed) ...[
                        if (index > 0) const SizedBox(height: _kRowGap),
                        _AccountRow(
                          account: account,
                          selected:
                              active?.kind == account.kind &&
                              active?.id == account.id,
                          onTap: () => _select(context, account),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              _Hairline(),
              SizedBox(height: bottomInset - 1),
            ],
          ),
        );
      },
    );
  }

  Future<void> _select(BuildContext context, SwitchableAccount account) async {
    HapticFeedback.lightImpact();
    final selected = await accountSwitcherService.select(account);
    if (!context.mounted) return;
    if (selected) {
      Navigator.of(context).pop();
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(S.switchAccountFailed),
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      );
  }
}

/// The 22pt band with the 36x5 pill — 21 here, because the rule below it is
/// 1pt of layout rather than an overlay stroke as in the frame.
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 21,
      child: Center(
        child: Container(
          width: 36,
          height: 5,
          decoration: BoxDecoration(
            color: AccountSwitcherColors.handle,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: AccountSwitcherColors.hairline);
  }
}

/// "Switch Account", centered in a 46pt band — 45 plus the rule below it, so
/// the first row starts at the frame's y=68.
class _SheetTitle extends StatelessWidget {
  const _SheetTitle();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 45,
      child: Center(
        child: Text(
          S.switchAccountTitle,
          style: figtree(
            size: 17,
            weight: FontWeight.w600,
            color: AccountSwitcherColors.text,
            height: 22 / 17,
          ),
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.account,
    required this.selected,
    required this.onTap,
  });

  final SwitchableAccount account;
  final bool selected;
  final VoidCallback onTap;

  /// "Personal" for the student's own identity; otherwise their board title in
  /// that club, localized.
  String _subtitle(BuildContext context) {
    if (account.isPersonal) return S.switchAccountPersonal;
    final l10n = AppLocalizations.of(context)!;
    final userId = authService.currentUser?.id;
    final title = userId == null
        ? null
        : account.club?.boardMemberTitles[userId];
    return localizedClubRole(l10n, title);
  }

  @override
  Widget build(BuildContext context) {
    final club = account.club;

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: _kRowHeight,
        child: Row(
          children: [
            const SizedBox(width: 20),
            SizedBox(
              width: 48,
              height: 48,
              // Both avatars wrap themselves in a tap-to-open-full-screen
              // gesture. In a switcher row the whole row selects, so the
              // avatar must not compete for the tap.
              child: IgnorePointer(
                child: Center(
                  child: account.isPersonal
                      ? UserAvatar(
                          userId: account.id,
                          name: account.name,
                          size: 40,
                          fontSize: 16,
                        )
                      : ClubAvatar(
                          clubId: club!.id,
                          clubName: club.name,
                          color: AccountSwitcherColors.accent,
                          imageUrl: club.logoUrl,
                          shape: 'circle',
                          size: 40,
                          fontSize: 16,
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: figtree(
                      size: 15,
                      weight: FontWeight.w600,
                      color: AccountSwitcherColors.text,
                      height: 19 / 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: figtree(
                      size: 13,
                      weight: FontWeight.w400,
                      color: AccountSwitcherColors.muted,
                      height: 16 / 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _SelectionRadio(selected: selected),
            const SizedBox(width: 22),
          ],
        ),
      ),
    );
  }
}

/// 20pt circle — burgundy fill with a white check when selected, a 2pt grey
/// ring when not. (`#1DA1F2` in the frames.)
class _SelectionRadio extends StatelessWidget {
  const _SelectionRadio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AccountSwitcherColors.accent : Colors.transparent,
        border: selected
            ? null
            : Border.all(color: AccountSwitcherColors.handle, width: 2),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
          : null,
    );
  }
}
