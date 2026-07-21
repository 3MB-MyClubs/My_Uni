import 'package:flutter/material.dart';

import '../models/club.dart';
import '../services/app_colors.dart';
import '../services/app_strings.dart';
import 'club_avatar.dart';

/// Reusable identity + live community information header for every club chat.
class ClubCommunityHeader extends StatelessWidget {
  const ClubCommunityHeader({
    super.key,
    required this.club,
    required this.avatarColor,
    required this.memberCount,
    required this.onlineCount,
    required this.onOpenClub,
    this.onBack,
  });

  final Club club;
  final Color avatarColor;
  final int memberCount;
  final int onlineCount;
  final VoidCallback onOpenClub;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final membersLabel = S.communityMembers(memberCount);
    final onlineLabel = S.communityOnline(onlineCount);
    return Container(
      key: const ValueKey('club-community-header'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 9, 16, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (onBack != null)
            Positioned(
              left: 0,
              top: 5,
              child: GestureDetector(
                onTap: onBack,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 16,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
            ),
          Semantics(
            button: true,
            label: '${club.name}, $membersLabel, $onlineLabel',
            child: InkWell(
              borderRadius: const BorderRadius.all(Radius.circular(18)),
              onTap: onOpenClub,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 52),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClubAvatar(
                      clubId: club.id,
                      clubName: club.name,
                      color: avatarColor,
                      imageUrl: club.logoUrl,
                      size: 44,
                      fontSize: 17,
                      shape: 'circle',
                    ),
                    const SizedBox(height: 5),
                    Text(
                      club.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      membersLabel,
                      key: const ValueKey('club-community-members'),
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Color(0xFF39A85A),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          onlineLabel,
                          key: const ValueKey('club-community-online'),
                          style: TextStyle(
                            fontSize: 10.5,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
