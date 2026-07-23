import 'package:flutter/material.dart';

import '../../services/app_colors.dart';
import '../../services/app_strings.dart';
import '../../services/auth_service.dart';
import '../onboarding_service.dart';
import '../starter_checklist_service.dart';

/// The dismissible "Get started" card shown on the student's Profile page
/// after the tour. It disappears when dismissed or when every task is done.
class StarterChecklistCard extends StatelessWidget {
  const StarterChecklistCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: starterChecklistService,
      builder: (context, _) {
        final userId = authService.currentUser?.id ?? '';
        if (!starterChecklistService.isActiveFor(userId)) {
          return const SizedBox.shrink();
        }
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primaryRed.withValues(alpha: 0.22),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          S.checklistTitle,
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          S.checklistSubtitle,
                          style: TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('starter-checklist-close'),
                    onPressed: starterChecklistService.dismiss,
                    tooltip: S.checklistDismiss,
                    style: IconButton.styleFrom(
                      foregroundColor: AppColors.secondaryText,
                      backgroundColor: AppColors.secondaryText.withValues(
                        alpha: 0.08,
                      ),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 19),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _ChecklistItem(
                done: starterChecklistService.followDone,
                icon: Icons.groups_rounded,
                label: S.checklistFollowClub,
                action: S.checklistFollowClubAction,
                onTap: () => onboardingService.requestTab(2),
              ),
              _ChecklistItem(
                done: starterChecklistService.rsvpDone,
                icon: Icons.event_available_rounded,
                label: S.checklistRsvpEvent,
                action: S.checklistRsvpEventAction,
                onTap: () => onboardingService.requestTab(1),
              ),
              _ChecklistItem(
                done: starterChecklistService.chatDone,
                icon: Icons.waving_hand_rounded,
                label: S.checklistSayHi,
                action: S.checklistSayHiAction,
                onTap: () => onboardingService.requestTab(3),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  final bool done;
  final IconData icon;
  final String label;
  final String action;
  final VoidCallback onTap;

  const _ChecklistItem({
    required this.done,
    required this.icon,
    required this.label,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: done ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: done
                    ? AppColors.primaryRed
                    : AppColors.primaryRed.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                done ? Icons.check_rounded : icon,
                size: 14,
                color: done ? Colors.white : AppColors.primaryRed,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: done ? AppColors.secondaryText : AppColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  decoration: done
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                  decorationColor: AppColors.secondaryText,
                ),
              ),
            ),
            if (!done)
              Text(
                action,
                style: TextStyle(
                  color: AppColors.primaryRed,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
