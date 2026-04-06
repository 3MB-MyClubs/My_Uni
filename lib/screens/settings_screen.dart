import 'package:flutter/material.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/user_prefs_service.dart';
import '../services/user_state.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const SettingsScreen({super.key, required this.onLogout});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 12),

          // ── Privacy section ────────────────────────────────────────────────
          _SectionHeader(title: 'Privacy'),
          Container(
            color: AppColors.card,
            child: SwitchListTile(
              value: userState.isPrivate,
              onChanged: (val) {
                setState(() => userState.isPrivate = val);
                final uid = authService.currentUser?.id ?? authService.currentAdmin?.id;
                if (uid != null) userPrefsService.save(uid);
              },
              title: const Text('Private Account',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.text)),
              subtitle: Text(
                userState.isPrivate
                    ? 'Only approved followers can see your posts and send you messages.'
                    : 'Anyone can follow you and see your profile.',
                style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
              ),
              activeThumbColor: AppColors.primaryRed,
            ),
          ),

          const SizedBox(height: 24),

          // ── Account section ────────────────────────────────────────────────
          _SectionHeader(title: 'Account'),
          Container(
            color: AppColors.card,
            child: ListTile(
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout, color: Colors.red, size: 20),
              ),
              title: const Text('Log Out',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
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
