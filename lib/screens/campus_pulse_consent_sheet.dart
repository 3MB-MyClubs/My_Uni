import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/campus_pulse_service.dart';
import '../services/location_permission_service.dart';

/// Shows the in-app explainer and then requests system location permission.
///
/// Always call this BEFORE [Geolocator.requestPermission()] so the user
/// understands why we need location access and knows it is optional.
///
/// Usage:
///   await showCampusPulseConsentSheet(context);
Future<void> showCampusPulseConsentSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ConsentSheet(),
  );
}

class _ConsentSheet extends StatefulWidget {
  const _ConsentSheet();
  @override
  State<_ConsentSheet> createState() => _ConsentSheetState();
}

class _ConsentSheetState extends State<_ConsentSheet> {
  bool _loading = false;

  String get _userId =>
      authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

  Future<void> _onEnable() async {
    if (_loading) return;
    setState(() => _loading = true);

    // Mark explainer as shown so we don't nag again.
    await locationPermissionService.markExplainerShown(_userId);

    final isPermanent = await locationPermissionService.isPermanentlyDenied();
    if (isPermanent) {
      // User previously hard-denied in OS settings — send them there.
      await locationPermissionService.openSettings();
      if (mounted) Navigator.pop(context);
      return;
    }

    // Request OS permission (geolocator pops the native dialog).
    final result = await locationPermissionService.requestPermission();

    final granted =
        result == LocationPermission.whileInUse ||
        result == LocationPermission.always;

    if (granted) {
      await campusPulseService.setOptIn(_userId, true);
      await campusPulseService.maybeSample();
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _onSkip() async {
    await locationPermissionService.markExplainerShown(_userId);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 36,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.lightRed,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.location_on_rounded,
              color: AppColors.primaryRed,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Make Campus Pulse smarter',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Explainer copy
          Text(
            'Help show which times campus is actually busy by sharing your '
            'approximate location while using the app.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.secondaryText,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Privacy bullets
          _BulletRow(
            icon: Icons.shield_outlined,
            text:
                'Only your approximate area on campus is used — never exact coordinates.',
          ),
          const SizedBox(height: 8),
          _BulletRow(
            icon: Icons.people_outline_rounded,
            text:
                'Contributions are anonymised and blended — your movement is never shown.',
          ),
          const SizedBox(height: 8),
          _BulletRow(
            icon: Icons.toggle_off_outlined,
            text:
                'You can turn this off at any time in Settings → Campus Pulse.',
          ),
          const SizedBox(height: 28),

          // Primary CTA
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _onEnable,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Enable location sharing',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),

          // Skip CTA
          TextButton(
            onPressed: _loading ? null : _onSkip,
            child: Text(
              'No thanks — use events only',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _BulletRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.primaryRed),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.secondaryText,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
