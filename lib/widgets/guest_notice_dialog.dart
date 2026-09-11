import 'package:flutter/material.dart';

import '../services/app_colors.dart';
import '../services/app_strings.dart';

/// Tells a visitor, once, that the campus they just walked into is fabricated.
///
/// Shown immediately after the Guest Login pill is tapped and before the tour
/// starts. Guest state is never persisted, so this appears for every visitor
/// on every guest session — which is the point: nobody should mistake the
/// seeded students, clubs, posts and messages for real people and real
/// content, and nobody should think their likes and RSVPs were kept.
///
/// Deliberately not dismissible by tapping outside: it is one tap to
/// acknowledge, and it is the only place the demo is spelled out.
Future<void> showGuestNoticeDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      key: const ValueKey<String>('guest-notice-dialog'),
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      // `Demo Tutorial` 675:94: a 48px disc holding the 24px sparkles glyph,
      // parked in the dialog's left gutter rather than centred. The frame's
      // indigo tint is a template leftover — the disc takes the app's burgundy.
      icon: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primaryRed.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.auto_awesome_outlined,
            size: 24,
            color: AppColors.primaryRed,
          ),
        ),
      ),
      title: Text(
        S.guestNoticeTitle,
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.guestNoticeBody,
            style: TextStyle(color: AppColors.secondaryText, height: 1.45),
          ),
          const SizedBox(height: 12),
          Text(
            S.guestNoticeFooter,
            style: TextStyle(color: AppColors.secondaryText, height: 1.45),
          ),
        ],
      ),
      actions: [
        FilledButton(
          key: const ValueKey<String>('guest-notice-accept'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryRed,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(S.guestNoticeAction),
        ),
      ],
    ),
  );
}
