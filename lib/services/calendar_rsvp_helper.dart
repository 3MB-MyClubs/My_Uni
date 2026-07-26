import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/event.dart';
import '../services/auth_service.dart';
import '../services/calendar_sync_service.dart';

Future<void> syncRsvpToDeviceCalendar(BuildContext context, Event event) async {
  final userId =
      authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
  if (userId.isEmpty) return;

  final status = await calendarSyncService.checkPermission();

  if (status == 'authorized') {
    final ok = await calendarSyncService.addToDeviceCalendar(event, userId);
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.addedToBothCalendars,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
    }
  } else if (status == 'notDetermined') {
    final granted = await calendarSyncService.requestPermission();
    if (granted) {
      await calendarSyncService.addToDeviceCalendar(event, userId);
    }
  } else {
    // denied / restricted
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.enableCalendarAccessHint,
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
    }
  }
}
