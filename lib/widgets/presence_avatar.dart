import 'package:flutter/material.dart';

import '../services/app_colors.dart';
import 'user_avatar.dart';

/// [UserAvatar] with a real-presence green dot pinned to the bottom-right.
class PresenceAvatar extends StatelessWidget {
  final String userId;
  final String name;
  final double size;
  final double fontSize;
  final bool online;

  const PresenceAvatar({
    super.key,
    required this.userId,
    required this.name,
    required this.size,
    required this.fontSize,
    required this.online,
  });

  @override
  Widget build(BuildContext context) {
    final dot = size * 0.26;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          UserAvatar(
            userId: userId,
            name: name,
            size: size,
            fontSize: fontSize,
          ),
          if (online)
            Positioned(
              bottom: -1,
              right: -1,
              child: Container(
                width: dot,
                height: dot,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.background, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
