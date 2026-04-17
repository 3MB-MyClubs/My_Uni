import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/campus_pulse_service.dart';
import '../services/location_permission_service.dart';
import '../services/user_prefs_service.dart';
import '../services/user_state.dart';
import 'campus_pulse_consent_sheet.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const SettingsScreen({super.key, required this.onLogout});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  LocationPermission _permission = LocationPermission.denied;

  @override
  void initState() {
    super.initState();
    _loadPermission();
  }

  Future<void> _loadPermission() async {
    final p = await locationPermissionService.currentPermission();
    if (mounted) setState(() => _permission = p);
  }

  String get _userId =>
      authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

  bool get _locationGranted =>
      _permission == LocationPermission.whileInUse ||
      _permission == LocationPermission.always;

  bool get _permanentlyDenied =>
      _permission == LocationPermission.deniedForever;

  String get _permissionLabel {
    switch (_permission) {
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return 'Allowed while using app';
      case LocationPermission.deniedForever:
        return 'Blocked — tap to open Settings';
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return 'Not granted';
    }
  }

  Future<void> _toggleCampusPulse(bool value) async {
    if (value && !_locationGranted) {
      // Show explainer then OS dialog.
      await showCampusPulseConsentSheet(context);
      await _loadPermission(); // refresh after dialog
      // Only flip the switch if permission was actually granted.
      if (!(_permission == LocationPermission.whileInUse ||
          _permission == LocationPermission.always)) {
        return;
      }
    }
    await campusPulseService.setOptIn(_userId, value);
    setState(() {});
  }

  Future<void> _clearContributions() async {
    await campusPulseService.clearContributions();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Local Campus Pulse data cleared.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 12),

          // ── Privacy section ──────────────────────────────────────────────
          _SectionHeader(title: 'Privacy'),
          Container(
            color: AppColors.card,
            child: SwitchListTile(
              value: userState.isPrivate,
              onChanged: (val) {
                setState(() => userState.isPrivate = val);
                final uid =
                    authService.currentUser?.id ?? authService.currentAdmin?.id;
                if (uid != null) userPrefsService.save(uid);
              },
              title: const Text(
                'Private Account',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              subtitle: Text(
                userState.isPrivate
                    ? 'Only approved followers can see your posts and send you messages.'
                    : 'Anyone can follow you and see your profile.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                ),
              ),
              activeThumbColor: AppColors.primaryRed,
            ),
          ),

          const SizedBox(height: 24),

          // ── Campus Pulse section ─────────────────────────────────────────
          _SectionHeader(title: 'Campus Pulse'),
          Container(
            color: AppColors.card,
            child: Column(
              children: [
                // Main toggle
                SwitchListTile(
                  value: campusPulseService.optedIn && _locationGranted,
                  onChanged: _toggleCampusPulse,
                  title: const Text(
                    'Share anonymous location',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  subtitle: const Text(
                    'Helps show which times campus is busy. '
                    'Only your approximate campus zone is used — never '
                    'exact coordinates or individual movement.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  activeThumbColor: AppColors.primaryRed,
                ),

                Divider(height: 1, color: AppColors.divider),

                // Permission status row
                ListTile(
                  dense: true,
                  leading: Icon(
                    _locationGranted
                        ? Icons.check_circle_outline_rounded
                        : _permanentlyDenied
                        ? Icons.block_rounded
                        : Icons.location_off_outlined,
                    size: 20,
                    color: _locationGranted
                        ? Colors.green
                        : _permanentlyDenied
                        ? Colors.orange
                        : AppColors.secondaryText,
                  ),
                  title: Text(
                    'Location permission: $_permissionLabel',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  onTap: _permanentlyDenied
                      ? () async {
                          await locationPermissionService.openSettings();
                          await _loadPermission();
                        }
                      : null,
                ),

                Divider(height: 1, color: AppColors.divider),

                // Clear data button
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.orange,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Clear local heatmap data',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Removes your locally stored Campus Pulse activity. '
                    'The heatmap will fall back to event-only data.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  onTap: _clearContributions,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Account section ──────────────────────────────────────────────
          _SectionHeader(title: 'Account'),
          Container(
            color: AppColors.card,
            child: ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout, color: Colors.red, size: 20),
              ),
              title: const Text(
                'Log Out',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                authService.logout();
                Navigator.of(context).popUntil((route) => route.isFirst);
                widget.onLogout();
              },
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppColors.secondaryText,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
