import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/personalization_service.dart';
import '../services/rsvp_store.dart';
import '../services/user_prefs_service.dart';
import '../services/user_state.dart';
import '../services/theme_service.dart';

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
                decoration: BoxDecoration(
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
                    Text(
                      'Set Username',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose how others see you. Your real name stays for search.',
                      style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      maxLength: 30,
                      style: TextStyle(color: AppColors.text),
                      decoration: InputDecoration(
                        prefixText: '@',
                        prefixStyle: TextStyle(
                          color: AppColors.primaryRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        hintText: 'your_username',
                        hintStyle: TextStyle(color: AppColors.secondaryText),
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
                          borderSide: BorderSide(
                              color: AppColors.primaryRed, width: 1.5),
                        ),
                        counterStyle: TextStyle(
                            color: AppColors.secondaryText, fontSize: 11),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9_.À-öø-ÿ]')),
                      ],
                      onChanged: (_) => setSheetState(() {}),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Letters, numbers, underscores and dots. Leave blank to use your real name.',
                      style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text('Cancel',
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
                            child: Text('Save',
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

  void _openPreferencesSheet(Set<String> _) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditPreferencesSheet(
        userId: _userId,
        onSaved: () => setState(() {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
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
                child: Icon(Icons.alternate_email_rounded,
                    color: AppColors.primaryRed, size: 20),
              ),
              title: Text(
                'Username',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.text),
              ),
              subtitle: Text(
                userState.usernameFor(_userId) != null
                    ? '@${userState.usernameFor(_userId)}'
                    : 'Not set — tap to choose one',
                style: TextStyle(
                    fontSize: 12, color: AppColors.secondaryText),
              ),
              trailing: Icon(Icons.chevron_right_rounded,
                  color: AppColors.secondaryText),
              onTap: _openUsernameSheet,
            ),
          ),

          const SizedBox(height: 24),

          // ── Preferences section ──────────────────────────────────────────
          _SectionHeader(title: 'Preferences'),
          ListenableBuilder(
            listenable: personalizationService,
            builder: (context, _) {
              final major = personalizationService.major;
              final interests = personalizationService.interests;
              final times = personalizationService.timePrefs;
              final summary = [
                if (major.isNotEmpty) major,
                if (interests.isNotEmpty) interests.take(2).join(', ') + (interests.length > 2 ? '…' : ''),
              ].join(' · ');
              return Container(
                color: AppColors.card,
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.lightRed,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.tune_rounded,
                            color: AppColors.primaryRed, size: 20),
                      ),
                      title: Text('My Preferences',
                          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.text)),
                      subtitle: Text(
                        summary.isNotEmpty ? summary : 'Not set — tap to configure',
                        style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Icon(Icons.chevron_right_rounded,
                          color: AppColors.secondaryText),
                      onTap: () => _openPreferencesSheet(times),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // ── Appearance section ───────────────────────────────────────────
          _SectionHeader(title: 'Appearance'),
          ListenableBuilder(
            listenable: themeService,
            builder: (context, _) => Container(
              color: AppColors.card,
              child: SwitchListTile(
                secondary: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.lightRed,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    themeService.isDark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    color: AppColors.primaryRed,
                    size: 20,
                  ),
                ),
                title: Text(
                  themeService.isDark ? 'Dark Mode' : 'Light Mode',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: AppColors.text),
                ),
                subtitle: Text(
                  themeService.isDark
                      ? 'Switch to light theme'
                      : 'Switch to dark theme',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.secondaryText),
                ),
                value: themeService.isDark,
                activeThumbColor: AppColors.primaryRed,
                onChanged: (v) => themeService.setDark(v),
              ),
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
                child: Icon(Icons.logout, color: Colors.red, size: 20),
              ),
              title: Text(
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
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppColors.secondaryText,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit Preferences Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _EditPreferencesSheet extends StatefulWidget {
  final String userId;
  final VoidCallback onSaved;
  const _EditPreferencesSheet({required this.userId, required this.onSaved});

  @override
  State<_EditPreferencesSheet> createState() => _EditPreferencesSheetState();
}

class _EditPreferencesSheetState extends State<_EditPreferencesSheet> {
  late Set<String> _interests;
  late Set<String> _times;
  late String _major;
  int _tab = 0;
  static const _tabLabels = ['Interests', 'Major', 'Schedule'];

  @override
  void initState() {
    super.initState();
    _interests = Set.of(personalizationService.interests);
    _times = Set.of(personalizationService.timePrefs);
    _major = personalizationService.major;
  }

  Future<void> _save() async {
    await personalizationService.completeOnboarding(
        widget.userId, _interests, _times, _major);
    await userPrefsService.save(widget.userId);
    if (mounted) {
      Navigator.pop(context);
      widget.onSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                    color: AppColors.lightRed,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.tune_rounded,
                    color: AppColors.primaryRed, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('My Preferences',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text)),
                    Text('Interests, major & schedule',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.secondaryText)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Tab chips
          Row(
            children: List.generate(_tabLabels.length, (i) {
              final sel = _tab == i;
              return Padding(
                padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
                child: GestureDetector(
                  onTap: () => setState(() => _tab = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primaryRed : AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_tabLabels[i],
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                            color: sel ? Colors.white : AppColors.text)),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _tab == 0
                ? _buildInterestsTab()
                : _tab == 1
                    ? _buildMajorTab()
                    : _buildScheduleTab(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text('Save changes',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestsTab() {
    return Wrap(
      key: const ValueKey('interests'),
      spacing: 8,
      runSpacing: 8,
      children: kInterests.map((tag) {
        final sel = _interests.contains(tag);
        return GestureDetector(
          onTap: () => setState(() => sel ? _interests.remove(tag) : _interests.add(tag)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: sel ? AppColors.primaryRed : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: sel ? AppColors.primaryRed : AppColors.divider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (sel) ...[
                  Icon(Icons.check_rounded, size: 13, color: Colors.white),
                  const SizedBox(width: 5),
                ],
                Text(tag,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: sel ? Colors.white : AppColors.text)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMajorTab() {
    return ListView.separated(
      key: const ValueKey('major'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: kFaculties.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final faculty = kFaculties[i];
        final name = faculty['name'] as String;
        final depts = faculty['departments'] as String;
        final sel = _major == name;
        return GestureDetector(
          onTap: () => setState(() => _major = name),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: sel ? AppColors.lightRed : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: sel ? AppColors.primaryRed : AppColors.divider,
                  width: sel ? 1.5 : 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                      color: AppColors.lightRed,
                      borderRadius: BorderRadius.circular(9)),
                  child: Icon(Icons.school_outlined,
                      size: 16, color: AppColors.primaryRed),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text)),
                      Text(depts,
                          style: TextStyle(
                              fontSize: 12, color: AppColors.secondaryText)),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: sel ? AppColors.primaryRed : Colors.transparent,
                    border: Border.all(
                        color: sel ? AppColors.primaryRed : AppColors.divider,
                        width: 1.5),
                  ),
                  child: sel
                      ? Icon(Icons.check, size: 12, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScheduleTab() {
    const iconMap = {
      'Morning': Icons.wb_sunny_outlined,
      'Afternoon': Icons.wb_cloudy_outlined,
      'Evening': Icons.nights_stay_outlined,
      'Weekend': Icons.weekend_outlined,
    };
    return GridView.count(
      key: const ValueKey('schedule'),
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.8,
      children: kTimeSlots.map((slot) {
        final sel = _times.contains(slot);
        return GestureDetector(
          onTap: () => setState(
              () => sel ? _times.remove(slot) : _times.add(slot)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              color: sel ? AppColors.primaryRed : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: sel ? AppColors.primaryRed : AppColors.divider),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(iconMap[slot],
                    size: 18,
                    color: sel ? Colors.white : AppColors.secondaryText),
                const SizedBox(width: 8),
                Text(slot,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : AppColors.text)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
