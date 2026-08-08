import 'package:flutter/material.dart';

import '../services/account_switcher_service.dart';
import '../services/app_colors.dart';
import 'club_avatar.dart';
import 'user_avatar.dart';

Future<void> showAccountSwitcherSheet(BuildContext context) async {
  final service = accountSwitcherService;
  await service.prepare();
  if (!context.mounted || !service.hasSwitchableAccounts) return;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => const _AccountSwitcherSheet(),
  );
}

class _AccountSwitcherSheet extends StatelessWidget {
  const _AccountSwitcherSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: accountSwitcherService,
      builder: (context, _) {
        final accounts = accountSwitcherService.accounts;
        final active = accountSwitcherService.activeAccount;
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Material(
            color: AppColors.card,
            borderRadius: const BorderRadius.all(Radius.circular(28)),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Switch account',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppColors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose how you appear when you publish for a club.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (final account in accounts)
                    _AccountRow(
                      account: account,
                      selected:
                          active?.kind == account.kind &&
                          active?.id == account.id,
                      onTap: () async {
                        final selected = await accountSwitcherService.select(
                          account,
                        );
                        if (!context.mounted) return;
                        if (selected) {
                          Navigator.of(context).pop();
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'This account could not be selected. Try again.',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AccountRow extends StatelessWidget {
  final SwitchableAccount account;
  final bool selected;
  final VoidCallback onTap;

  const _AccountRow({
    required this.account,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final club = account.club;
    final subtitle = account.isPersonal
        ? 'Personal account'
        : 'Club admin account';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? AppColors.primaryRed.withValues(alpha: 0.10)
            : AppColors.surfaceAlt,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(18)),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                if (account.isPersonal)
                  UserAvatar(
                    userId: account.id,
                    name: account.name,
                    size: 44,
                    fontSize: 18,
                  )
                else
                  ClubAvatar(
                    clubId: club!.id,
                    clubName: club.name,
                    color: AppColors.primaryRed,
                    imageUrl: club.logoUrl,
                    size: 44,
                    fontSize: 18,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected
                      ? AppColors.primaryRed
                      : AppColors.secondaryText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
