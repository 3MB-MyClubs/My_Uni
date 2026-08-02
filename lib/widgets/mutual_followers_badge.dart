import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/user.dart';
import '../services/app_colors.dart';
import '../services/user_state.dart';
import 'user_avatar.dart';

/// Compact social proof shown directly beneath a suggested person's avatar.
class MutualFollowersBadge extends StatelessWidget {
  final String suggestedUserId;
  final List<User> mutualUsers;
  final int mutualCount;

  const MutualFollowersBadge({
    super.key,
    required this.suggestedUserId,
    required this.mutualUsers,
    required this.mutualCount,
  });

  @override
  Widget build(BuildContext context) {
    if (mutualCount <= 0) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final countLabel = mutualCount > 30 ? '30+' : '$mutualCount';
    final visibleUsers = mutualUsers.take(3).toList();
    final badgeLabel = mutualCount == 1
        ? l10n.oneMutualBadge
        : l10n.mutualBadgeCount(countLabel);
    final mutualName = visibleUsers.isEmpty
        ? null
        : userState.displayNameFor(
            visibleUsers.first.id,
            visibleUsers.first.name,
          );

    return Semantics(
      container: true,
      label: mutualName == null ? badgeLabel : '$badgeLabel, $mutualName',
      child: Container(
        key: ValueKey('mutual-followers-$suggestedUserId'),
        height: mutualName == null ? 24 : 36,
        constraints: const BoxConstraints(maxWidth: 126),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          border: Border.all(color: AppColors.borderStrong),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (visibleUsers.isNotEmpty) ...[
                  ExcludeSemantics(
                    child: SizedBox(
                      width: 16 + (visibleUsers.length - 1) * 10,
                      height: 16,
                      child: Stack(
                        children: [
                          for (var i = 0; i < visibleUsers.length; i++)
                            Positioned(
                              left: i * 10,
                              child: Container(
                                width: 16,
                                height: 16,
                                padding: const EdgeInsets.all(1),
                                decoration: BoxDecoration(
                                  color: AppColors.card,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.card),
                                ),
                                child: UserAvatar(
                                  userId: visibleUsers[i].id,
                                  name: visibleUsers[i].name,
                                  size: 12,
                                  fontSize: 6,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      badgeLabel,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (mutualName != null) ...[
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  mutualName,
                  key: ValueKey('mutual-preview-name-$suggestedUserId'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 8.5,
                    height: 1,
                    fontWeight: FontWeight.w500,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
