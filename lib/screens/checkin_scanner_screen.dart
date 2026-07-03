import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/event.dart';
import '../models/user.dart';
import '../services/app_colors.dart';
import '../services/app_strings.dart';
import '../services/auth_service.dart';
import '../services/checkin_store.dart';
import '../services/mock_data.dart';
import '../services/people_service.dart';
import '../widgets/event_pass_sheet.dart';

/// Door scanner for club admins: scans student Event Passes and records
/// attendance. Duplicate scans and passes for other events are rejected;
/// students who didn't RSVP can still be admitted explicitly.
class CheckinScannerScreen extends StatefulWidget {
  final Event event;
  final Color accent;

  const CheckinScannerScreen({
    super.key,
    required this.event,
    required this.accent,
  });

  @override
  State<CheckinScannerScreen> createState() => _CheckinScannerScreenState();
}

class _CheckinScannerScreenState extends State<CheckinScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  String? _lastPayload;
  String _statusText = '';
  Color _statusColor = Colors.white70;
  bool _confirming = false;

  String get _actorId =>
      authService.currentAdmin?.id ?? authService.currentUser?.id ?? '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _studentName(String userId) {
    for (final u in users) {
      if (u.id == userId) return u.name;
    }
    for (final User u in peopleService.cachedPeople) {
      if (u.id == userId) return u.name;
    }
    return userId;
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_confirming) return;
    final raw = capture.barcodes.isEmpty
        ? null
        : capture.barcodes.first.rawValue;
    if (raw == null || raw == _lastPayload) return;
    _lastPayload = raw;

    final parsed = parseEventPassPayload(raw);
    if (parsed == null) {
      _setStatus(S.scanInvalidPass, Colors.orangeAccent);
      return;
    }
    final (eventId, userId) = parsed;
    if (eventId != widget.event.id) {
      _setStatus(S.scanWrongEvent, Colors.orangeAccent);
      return;
    }
    if (checkinStore.isCheckedIn(eventId, userId)) {
      _setStatus('${_studentName(userId)} — ${S.scanAlreadyIn}', Colors.amber);
      return;
    }

    final rsvpd = widget.event.attendeeUserIds.contains(userId);
    if (!rsvpd) {
      _confirming = true;
      final admit = await _confirmNonRsvp(_studentName(userId));
      _confirming = false;
      if (admit != true) {
        _setStatus(S.scanNotAdmitted, Colors.orangeAccent);
        return;
      }
    }

    await checkinStore.toggle(
      eventId: eventId,
      userId: userId,
      actorId: _actorId,
      method: 'qr',
    );
    _setStatus('${_studentName(userId)} ✓', Colors.greenAccent);
  }

  Future<bool?> _confirmNonRsvp(String name) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          S.scanNoRsvpTitle,
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text),
        ),
        content: Text(
          S.scanNoRsvpBody(name),
          style: TextStyle(color: AppColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              S.cancel,
              style: TextStyle(color: AppColors.secondaryText),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(S.scanAdmitAnyway),
          ),
        ],
      ),
    );
  }

  void _setStatus(String text, Color color) {
    if (!mounted) return;
    setState(() {
      _statusText = text;
      _statusColor = color;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          S.scanCheckins,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),

          // Viewfinder frame
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: widget.accent, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),

          // Status + running counter
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
              color: Colors.black.withValues(alpha: 0.55),
              child: ListenableBuilder(
                listenable: checkinStore,
                builder: (_, _) {
                  final checked = checkinStore.countFor(widget.event.id);
                  final total = widget.event.attendeeUserIds.length;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_statusText.isNotEmpty)
                        Text(
                          _statusText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _statusColor,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        S.checkedInCounter(checked, total),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
