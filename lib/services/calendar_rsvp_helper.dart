import 'package:flutter/material.dart';
import '../models/event.dart';
import '../services/auth_service.dart';
import '../services/calendar_sync_service.dart';

Future<void> syncRsvpToDeviceCalendar(BuildContext context, Event event) async {
  final userId = authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
  if (userId.isEmpty) return;

  final status = await calendarSyncService.checkPermission();

  if (status == 'authorized') {
    final ok = await calendarSyncService.addToDeviceCalendar(event, userId);
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Expanded(child: Text('Added to both calendars')),
          ]),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ));
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
        ..showSnackBar(SnackBar(
          content: const Text(
            "You're going! Enable calendar access in Settings to also sync to your phone.",
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ));
    }
  }
}
