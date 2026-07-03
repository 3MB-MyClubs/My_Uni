import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/event.dart';
import '../services/app_colors.dart';
import '../services/app_strings.dart';
import '../services/user_state.dart';
import 'user_avatar.dart';

/// Versioned QR payload scanned at the door: `kuqr:v1:<eventId>:<userId>`.
String eventPassPayload(String eventId, String userId) =>
    'kuqr:v1:$eventId:$userId';

/// Parses a scanned pass payload; returns (eventId, userId) or null.
(String, String)? parseEventPassPayload(String raw) {
  final parts = raw.split(':');
  if (parts.length != 4 || parts[0] != 'kuqr' || parts[1] != 'v1') return null;
  if (parts[2].isEmpty || parts[3].isEmpty) return null;
  return (parts[2], parts[3]);
}

/// Shows the student's personal QR pass for an event they RSVP'd to.
Future<void> showEventPassSheet({
  required BuildContext context,
  required Event event,
  required String userId,
  required String userName,
  required Color accent,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _EventPassSheet(
      event: event,
      userId: userId,
      userName: userName,
      accent: accent,
    ),
  );
}

class _EventPassSheet extends StatelessWidget {
  final Event event;
  final String userId;
  final String userName;
  final Color accent;

  const _EventPassSheet({
    required this.event,
    required this.userId,
    required this.userName,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final date = event.dateTime;
    final dateLabel =
        '${date.day}.${date.month.toString().padLeft(2, '0')}.${date.year} · '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final displayName = userState.displayNameFor(userId, userName);

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Icon(Icons.qr_code_2_rounded, size: 20, color: accent),
                const SizedBox(width: 8),
                Text(
                  S.eventPass,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accent.withValues(alpha: 0.35)),
              ),
              child: QrImageView(
                data: eventPassPayload(event.id, userId),
                version: QrVersions.auto,
                size: 210,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                UserAvatar(
                  userId: userId,
                  name: displayName,
                  size: 30,
                  fontSize: 12,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              event.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              dateLabel,
              style: TextStyle(fontSize: 12.5, color: AppColors.secondaryText),
            ),
            const SizedBox(height: 10),
            Text(
              S.eventPassHint,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}
