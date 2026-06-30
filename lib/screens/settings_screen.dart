import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/club.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/club_admin_access.dart';
import '../services/personalization_service.dart';
import '../services/rsvp_store.dart';
import '../services/user_prefs_service.dart';
import '../services/user_state.dart';
import '../services/theme_service.dart';
import '../services/locale_service.dart';
import '../services/app_strings.dart';
import '../services/tutorial_service.dart';
import '../widgets/club_avatar.dart';
import 'club_profile_screen.dart' show BoardManagementSheet;
import 'edit_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const SettingsScreen({super.key, required this.onLogout});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String get _userId =>
      authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

  /// The club this account administers (null for students and the super admin).
  Club? get _managedClub {
    final adminId = authService.currentAdmin?.id;
    if (adminId == null || adminId == 'admin1') return null;
    return managedClubForAdmin(adminId);
  }

  static const List<String> _clubCategoryOptions = [
    'Academic',
    'Arts',
    'Business',
    'Career',
    'Engineering',
    'Music',
    'Social Impact',
    'Sports',
    'Tech',
    'Wellness',
  ];

  List<String> _clubCategories(Club club) {
    final raw = club.categoryName?.trim();
    if (raw == null || raw.isEmpty) return const [];
    return raw
        .split(',')
        .map((category) => category.trim())
        .where((category) => category.isNotEmpty)
        .toList();
  }

  // ── Club photo ──────────────────────────────────────────────────────────────
  void _showClubPhotoOptions(Club club) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              const SizedBox(height: 16),
              Text(
                S.changeClubPhoto,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 16),
              _clubPhotoOption(Icons.camera_alt_outlined, S.takePhoto, () {
                Navigator.pop(context);
                _pickClubPhoto(club, ImageSource.camera);
              }),
              Divider(height: 1, indent: 16, color: AppColors.divider),
              _clubPhotoOption(
                Icons.photo_library_outlined,
                S.chooseFromLib,
                () {
                  Navigator.pop(context);
                  _pickClubPhoto(club, ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _clubPhotoOption(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.lightRed,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primaryRed),
      ),
      title: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.text),
      ),
      onTap: onTap,
    );
  }

  Future<void> _pickClubPhoto(Club club, ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null || !mounted) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        IOSUiSettings(
          title: 'Crop Photo',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: true,
          aspectRatioPickerButtonHidden: true,
        ),
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo',
          toolbarColor: AppColors.primaryRed,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: true,
          hideBottomControls: false,
        ),
      ],
    );
    if (cropped == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          S.useThisPhoto,
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text),
        ),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(File(cropped.path), fit: BoxFit.cover),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(S.usePhoto),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final docsDir = await getApplicationDocumentsDirectory();
      final ext = cropped.path.contains('.')
          ? cropped.path.substring(cropped.path.lastIndexOf('.'))
          : '.jpg';
      final permanentPath = '${docsDir.path}/club_${club.id}$ext';
      await File(cropped.path).copy(permanentPath);
      if (!mounted) return;
      userState.setClubPhoto(club.id, permanentPath);
      await userPrefsService.saveClubPhoto(club.id, permanentPath);
      setState(() {});
    }
  }

  void _openClubDescriptionSheet(Club club) {
    final controller = TextEditingController(text: club.description);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final value = controller.text.trim();
          final canSave = value.isNotEmpty && value != club.description;
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
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    S.clubDescription,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "This appears on ${club.name}’s profile across the app.",
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLength: 240,
                    maxLines: 4,
                    style: TextStyle(color: AppColors.text, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: S.clubDescriptionHint,
                      hintStyle: TextStyle(color: AppColors.secondaryText),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.primaryRed,
                          width: 1.5,
                        ),
                      ),
                      counterStyle: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 11,
                      ),
                    ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            S.cancel,
                            style: TextStyle(color: AppColors.secondaryText),
                          ),
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
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: canSave
                              ? () {
                                  club.description = value;
                                  userState.bumpClubInfo();
                                  if (mounted) setState(() {});
                                  Navigator.of(ctx).pop();
                                  unawaited(
                                    userPrefsService.saveClubDescription(
                                      club.id,
                                      value,
                                    ),
                                  );
                                }
                              : null,
                          child: Text(
                            S.save,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openClubNameSheet(Club club) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ClubNameSheet(club: club),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _openBoardManagement(Club club) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BoardManagementSheet(club: club),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _openClubCategoriesSheet(Club club) {
    final selected = _clubCategories(club).toSet();
    final extra = selected
        .where((category) => !_clubCategoryOptions.contains(category))
        .join(', ');
    final controller = TextEditingController(text: extra);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          List<String> categories() {
            final custom = controller.text
                .split(',')
                .map((category) => category.trim())
                .where((category) => category.isNotEmpty);
            return {...selected, ...custom}.toList()..sort();
          }

          final values = categories();
          final nextValue = values.join(', ');
          final currentValue = _clubCategories(club).join(', ');
          final canSave = nextValue != currentValue;

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
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    S.clubCategories,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    S.chooseTagsHint,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final category in _clubCategoryOptions)
                        FilterChip(
                          label: Text(category),
                          selected: selected.contains(category),
                          selectedColor: AppColors.lightRed,
                          checkmarkColor: AppColors.primaryRed,
                          labelStyle: TextStyle(
                            color: selected.contains(category)
                                ? AppColors.primaryRed
                                : AppColors.text,
                            fontWeight: FontWeight.w600,
                          ),
                          side: BorderSide(color: AppColors.divider),
                          onSelected: (value) {
                            setSheetState(() {
                              if (value) {
                                selected.add(category);
                              } else {
                                selected.remove(category);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: controller,
                    style: TextStyle(color: AppColors.text, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: S.customTags,
                      hintText: S.customTagsHint,
                      helperText: S.separateWithCommas,
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.primaryRed,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            S.cancel,
                            style: TextStyle(color: AppColors.secondaryText),
                          ),
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
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: canSave
                              ? () {
                                  club.categoryName = nextValue.isEmpty
                                      ? null
                                      : nextValue;
                                  userState.bumpClubInfo();
                                  if (mounted) setState(() {});
                                  Navigator.of(ctx).pop();
                                  unawaited(
                                    userPrefsService.saveClubCategory(
                                      club.id,
                                      club.categoryName,
                                    ),
                                  );
                                }
                              : null,
                          child: Text(
                            S.saveCategories,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _replayTutorial() async {
    await tutorialService.reset(_userId);
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    tutorialService.requestReplay();
  }

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

  void _openChangeNameSheet() {
    final user = authService.currentUser;
    if (user == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChangeNameSheet(userId: user.id, realName: user.name),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(S.settings, style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListenableBuilder(
        listenable: localeService,
        builder: (context, _) => ListView(
        children: [
          const SizedBox(height: 12),

          // ── Profile section (students only) ──────────────────────────────
          // Clubs and the super admin edit via the Club section / dashboard,
          // so the personal profile editor is shown for student accounts only.
          if (authService.isStudentSession) ...[
            _SectionHeader(title: S.profileSection),
            ListenableBuilder(
              listenable: userState,
              builder: (context, _) {
                final user = authService.currentUser!;
                final currentName = userState.displayNameFor(
                  user.id,
                  user.name,
                );

                return Container(
                  color: AppColors.card,
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.lightRed,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.person_outline_rounded,
                            color: AppColors.primaryRed,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          S.editProfile,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        subtitle: Text(
                          S.editProfileSubtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.secondaryText,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditProfileScreen(
                                userId: user.id,
                                realName: user.name,
                              ),
                            ),
                          ).then((_) {
                            if (mounted) setState(() {});
                          });
                        },
                      ),
                      Divider(height: 1, indent: 56, color: AppColors.divider),
                      ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.lightRed,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.badge_outlined,
                            color: AppColors.primaryRed,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          S.changeMyName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        subtitle: Text(
                          currentName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.secondaryText,
                        ),
                        onTap: _openChangeNameSheet,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],

          // ── Club section (club admins only) ──────────────────────────────
          if (_managedClub != null) ...[
            const SizedBox(height: 24),
            _SectionHeader(title: S.clubSection),
            ListenableBuilder(
              listenable: userState,
              builder: (context, _) {
                final club = _managedClub!;
                return Container(
                  color: AppColors.card,
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.lightRed,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.edit_outlined,
                            color: AppColors.primaryRed,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          S.clubName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        subtitle: Text(
                          club.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.secondaryText,
                        ),
                        onTap: () => _openClubNameSheet(club),
                      ),
                      Divider(height: 1, indent: 56, color: AppColors.divider),
                      ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: ClubAvatar(
                            clubId: club.id,
                            clubName: club.name,
                            color: AppColors.primaryRed,
                            size: 36,
                            fontSize: 16,
                            borderRadius: 10,
                          ),
                        ),
                        title: Text(
                          S.clubPhoto,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        subtitle: Text(
                          S.tapToChangeLogo,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.secondaryText,
                        ),
                        onTap: () => _showClubPhotoOptions(club),
                      ),
                      Divider(height: 1, indent: 56, color: AppColors.divider),
                      ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.lightRed,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.sell_outlined,
                            color: AppColors.primaryRed,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          S.clubCategories,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        subtitle: Text(
                          _clubCategories(club).isEmpty
                              ? S.addDiscoveryTags
                              : _clubCategories(club).join(', '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.secondaryText,
                        ),
                        onTap: () => _openClubCategoriesSheet(club),
                      ),
                      Divider(height: 1, indent: 56, color: AppColors.divider),
                      ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.lightRed,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.description_outlined,
                            color: AppColors.primaryRed,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          S.clubDescription,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        subtitle: Text(
                          club.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.secondaryText,
                        ),
                        onTap: () => _openClubDescriptionSheet(club),
                      ),
                      Divider(height: 1, indent: 56, color: AppColors.divider),
                      ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.lightRed,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.manage_accounts_outlined,
                            color: AppColors.primaryRed,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          S.manageBoardMembers,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        subtitle: Text(
                          S.manageBoardSubtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.secondaryText,
                        ),
                        onTap: () => _openBoardManagement(club),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],

          if (authService.isStudentSession) ...[
            const SizedBox(height: 24),

            // ── Preferences section ──────────────────────────────────────────
            _SectionHeader(title: S.preferences),
            ListenableBuilder(
              listenable: personalizationService,
              builder: (context, _) {
                final major = personalizationService.major;
                final interests = personalizationService.interests;
                final times = personalizationService.timePrefs;
                final summary = [
                  if (major.isNotEmpty) major,
                  if (interests.isNotEmpty)
                    interests.take(2).join(', ') +
                        (interests.length > 2 ? '…' : ''),
                ].join(' · ');
                return Container(
                  color: AppColors.card,
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.lightRed,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.tune_rounded,
                            color: AppColors.primaryRed,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          S.myPreferences,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        subtitle: Text(
                          summary.isNotEmpty
                              ? summary
                              : S.notSetConfigure,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.secondaryText,
                        ),
                        onTap: () => _openPreferencesSheet(times),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],

          const SizedBox(height: 24),

          // ── Appearance section ───────────────────────────────────────────
          _SectionHeader(title: S.appearance),
          ListenableBuilder(
            listenable: themeService,
            builder: (context, _) => Container(
              color: AppColors.card,
              child: Column(
                children: [
                  SwitchListTile(
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
                      themeService.isDark ? S.darkMode : S.lightMode,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    subtitle: Text(
                      themeService.isDark
                          ? S.switchToLight
                          : S.switchToDark,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    value: themeService.isDark,
                    activeThumbColor: AppColors.primaryRed,
                    onChanged: (v) => themeService.setDark(v),
                  ),
                  Divider(height: 1, color: AppColors.divider),
                  ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.lightRed,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.language_rounded,
                        color: AppColors.primaryRed,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      S.language,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    trailing: _LanguageToggle(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Help section ────────────────────────────────────────────────
          _SectionHeader(title: S.help),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryRed, AppColors.darkRed],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryRed.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _replayTutorial,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.play_circle_fill_rounded,
                            color: Colors.white,
                            size: 27,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                S.replayTutorial,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                S.replayTutorialSubtitle,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.3,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Account section ──────────────────────────────────────────────
          _SectionHeader(title: S.account),
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
                S.logOut,
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
      widget.userId,
      _interests,
      _times,
      _major,
    );
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
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.lightRed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: AppColors.primaryRed,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.myPreferences,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                    Text(
                      'Interests, major & schedule',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primaryRed : AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _tabLabels[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                        color: sel ? Colors.white : AppColors.text,
                      ),
                    ),
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
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
                'Save changes',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
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
          onTap: () => setState(
            () => sel ? _interests.remove(tag) : _interests.add(tag),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: sel ? AppColors.primaryRed : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: sel ? AppColors.primaryRed : AppColors.divider,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (sel) ...[
                  Icon(Icons.check_rounded, size: 13, color: Colors.white),
                  const SizedBox(width: 5),
                ],
                Text(
                  tag,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: sel ? Colors.white : AppColors.text,
                  ),
                ),
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
                width: sel ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.lightRed,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Icons.school_outlined,
                    size: 16,
                    color: AppColors.primaryRed,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                      Text(
                        depts,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: sel ? AppColors.primaryRed : Colors.transparent,
                    border: Border.all(
                      color: sel ? AppColors.primaryRed : AppColors.divider,
                      width: 1.5,
                    ),
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
          onTap: () =>
              setState(() => sel ? _times.remove(slot) : _times.add(slot)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              color: sel ? AppColors.primaryRed : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: sel ? AppColors.primaryRed : AppColors.divider,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  iconMap[slot],
                  size: 18,
                  color: sel ? Colors.white : AppColors.secondaryText,
                ),
                const SizedBox(width: 8),
                Text(
                  slot,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : AppColors.text,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Bottom sheet for editing a club's name. Owns its own controller and disposes
/// it in [dispose] — disposing it in `whenComplete` crashed because the dismiss
/// animation rebuilds the [TextField] against a disposed controller.
class _ClubNameSheet extends StatefulWidget {
  final Club club;

  const _ClubNameSheet({required this.club});

  @override
  State<_ClubNameSheet> createState() => _ClubNameSheetState();
}

class _ClubNameSheetState extends State<_ClubNameSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.club.name,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save(String value) {
    widget.club.name = value;
    userState.bumpClubInfo();
    unawaited(userPrefsService.saveClubName(widget.club.id, value));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final value = _controller.text.trim();
    final canSave = value.isNotEmpty && value != widget.club.name;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              S.clubName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'This appears across the app wherever your club is shown.',
              style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: 60,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(color: AppColors.text, fontSize: 14),
              decoration: InputDecoration(
                labelText: S.clubNameLabel,
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primaryRed, width: 1.5),
                ),
                counterStyle: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 11,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      S.cancel,
                      style: TextStyle(color: AppColors.secondaryText),
                    ),
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
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: canSave ? () => _save(value) : null,
                    child: Text(
                      S.saveName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle();

  @override
  Widget build(BuildContext context) {
    final current = localeService.languageCode;
    return Container(
      height: 34,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _seg('EN', current == 'en', () => localeService.setLanguage('en')),
          _seg('TR', current == 'tr', () => localeService.setLanguage('tr')),
        ],
      ),
    );
  }

  Widget _seg(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.primaryRed : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active ? Colors.white : AppColors.secondaryText,
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for editing the student's display name. Owns its own
/// [TextEditingController] so it is disposed only after the sheet is fully
/// removed — disposing it earlier (e.g. in `whenComplete`) crashed because the
/// dismiss animation rebuilds the [TextField] against a disposed controller.
class _ChangeNameSheet extends StatefulWidget {
  final String userId;
  final String realName;

  const _ChangeNameSheet({required this.userId, required this.realName});

  @override
  State<_ChangeNameSheet> createState() => _ChangeNameSheetState();
}

class _ChangeNameSheetState extends State<_ChangeNameSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: userState.usernameFor(widget.userId) ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _useRealName() async {
    userState.clearUsername(widget.userId);
    await userPrefsService.save(widget.userId);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _save(String name) async {
    userState.setUsername(widget.userId, name);
    await userPrefsService.save(widget.userId);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final customName = _controller.text.trim();
    final hasCustomName = userState.usernameFor(widget.userId) != null;
    final isTaken =
        customName.isNotEmpty &&
        userState.isUsernameTaken(customName, excludeId: widget.userId);
    final canSave =
        customName.isNotEmpty &&
        customName != userState.usernameFor(widget.userId) &&
        !isTaken;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
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
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              S.changeMyName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              S.changeNameSubtitle,
              style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: 40,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(color: AppColors.text, fontSize: 14),
              decoration: InputDecoration(
                labelText: S.displayName,
                hintText: widget.realName,
                errorText: isTaken ? S.nameTaken : null,
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.primaryRed,
                    width: 1.5,
                  ),
                ),
                counterStyle: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 11,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: hasCustomName
                        ? _useRealName
                        : () => Navigator.pop(context),
                    child: Text(
                      hasCustomName ? S.useRealName : S.cancel,
                      style: TextStyle(color: AppColors.secondaryText),
                    ),
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
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: canSave ? () => _save(customName) : null,
                    child: Text(
                      S.saveName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
