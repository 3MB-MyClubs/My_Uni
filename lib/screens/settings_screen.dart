import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/rsvp_store.dart';
import '../services/user_prefs_service.dart';
import '../services/user_state.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const SettingsScreen({super.key, required this.onLogout});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String get _userId =>
      authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

  void _openUsernameSheet() {
    final userId = _userId;
    final current = userState.usernameFor(userId) ?? '';
    final controller = TextEditingController(text: current);
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final value = controller.text.trim();
            final isValid = value.isEmpty || _isValidUsername(value);
            final isTaken = isValid && value.isNotEmpty &&
                userState.isUsernameTaken(value, excludeId: userId);
            final canSave = value != current && isValid && !isTaken;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36, height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Set Username',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Choose how others see you. Your real name stays for search.',
                      style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      maxLength: 30,
                      style: const TextStyle(color: AppColors.text),
                      decoration: InputDecoration(
                        prefixText: '@',
                        prefixStyle: const TextStyle(
                          color: AppColors.primaryRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        hintText: 'your_username',
                        hintStyle: const TextStyle(color: AppColors.secondaryText),
                        errorText: isTaken
                            ? 'This username is already taken'
                            : (!isValid && value.isNotEmpty)
                                ? 'Only letters, numbers, underscores and dots'
                                : errorText,
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.primaryRed, width: 1.5),
                        ),
                        counterStyle: const TextStyle(
                            color: AppColors.secondaryText, fontSize: 11),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9_.À-öø-ÿ]')),
                      ],
                      onChanged: (_) => setSheetState(() {}),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Letters, numbers, underscores and dots. Leave blank to use your real name.',
                      style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel',
                                style: TextStyle(color: AppColors.secondaryText)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: canSave
                                  ? AppColors.primaryRed
                                  : AppColors.divider,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: canSave
                                ? () {
                                    final newVal = value;
                                    if (newVal.isEmpty) {
                                      userState.clearUsername(userId);
                                    } else {
                                      userState.setUsername(userId, newVal);
                                    }
                                    userPrefsService.save(userId);
                                    Navigator.pop(ctx);
                                    setState(() {});
                                  }
                                : null,
                            child: const Text('Save',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  bool _isValidUsername(String value) =>
      RegExp(r'^[a-zA-Z0-9_.À-öø-ÿ]{1,30}$').hasMatch(value);

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

          // ── Username section ─────────────────────────────────────────────
          _SectionHeader(title: 'Profile'),
          Container(
            color: AppColors.card,
            child: ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.lightRed,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.alternate_email_rounded,
                    color: AppColors.primaryRed, size: 20),
              ),
              title: const Text(
                'Username',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.text),
              ),
              subtitle: Text(
                userState.usernameFor(_userId) != null
                    ? '@${userState.usernameFor(_userId)}'
                    : 'Not set — tap to choose one',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.secondaryText),
              ),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.secondaryText),
              onTap: _openUsernameSheet,
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
                rsvpStore.clear();
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
