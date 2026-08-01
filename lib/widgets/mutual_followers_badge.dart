import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/user.dart';
import '../services/app_colors.dart';
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

    return Semantics(
      container: true,
      label: badgeLabel,
      child: Container(
        key: ValueKey('mutual-followers-$suggestedUserId'),
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          border: Border.all(color: AppColors.borderStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
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
            Text(
              badgeLabel,
              style: TextStyle(
                fontSize: 10,
                height: 1,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
