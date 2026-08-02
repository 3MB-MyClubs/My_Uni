import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/club.dart';
import '../services/app_colors.dart';
import '../services/app_links.dart';
import '../services/app_strings.dart';
import '../services/auth_service.dart';
import '../services/club_admin_access.dart';
import '../services/rsvp_store.dart';
import '../services/student_profile_service.dart';
import '../services/supabase_club_service.dart';
import '../services/user_prefs_service.dart';
import '../services/user_state.dart';
import '../services/theme_service.dart';
import '../services/locale_service.dart';
import '../services/mock_clubup_profile.dart';
import '../l10n/app_localizations.dart';
import '../services/photo_upload_quality.dart';
import '../onboarding/onboarding_service.dart';
import '../widgets/club_avatar.dart';
import '../widgets/language_toggle.dart';
import 'club_profile_screen.dart' show BoardManagementSheet;
import 'blocked_accounts_screen.dart';
import 'edit_profile_screen.dart';
import 'moderation_center_screen.dart';

Future<bool> showLogoutConfirmationDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          title: Text(
            l10n.confirmLogoutTitle,
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            l10n.confirmLogoutMessage,
            style: TextStyle(color: AppColors.secondaryText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.logOut),
            ),
          ],
        ),
      ) ??
      false;
}

class SettingsScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const SettingsScreen({super.key, required this.onLogout});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String get _userId =>
      authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

  bool get _isClubUpModerator => isClubUpAdmin(authService.currentAdmin);

  /// The club this account administers (null for students and the super admin).
  Club? get _managedClub {
    final adminId = authService.currentAdmin?.id;
    if (adminId == null || adminId == 'admin1') return null;
    return managedClubForAdmin(adminId);
  }

  Future<void> _confirmAndLogout() async {
    final confirmed = await showLogoutConfirmationDialog(context);
    if (!confirmed || !mounted) return;

    await authService.logout();
    if (!mounted) return;
    rsvpStore.clear();
    Navigator.of(context).popUntil((route) => route.isFirst);
    widget.onLogout();
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

  String _localizedClubCategory(BuildContext context, String category) {
    final l10n = AppLocalizations.of(context)!;
    return switch (category.trim().toLowerCase()) {
      'academic' => l10n.categoryAcademic,
      'arts' => l10n.categoryArts,
      'business' => l10n.categoryBusiness,
      'career' => l10n.categoryCareer,
      'engineering' => l10n.categoryEngineering,
      'music' => l10n.categoryMusic,
      'social' => l10n.categorySocial,
      'social impact' => l10n.categorySocialImpact,
      'sports' => l10n.categorySports,
      'tech' => l10n.categoryTech,
      'wellness' => l10n.categoryWellness,
      _ => category,
    };
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
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.changeClubPhoto,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 16),
              _clubPhotoOption(
                Icons.camera_alt_outlined,
                AppLocalizations.of(context)!.takePhoto,
                () {
                  Navigator.pop(context);
                  _pickClubPhoto(club, ImageSource.camera);
                },
              ),
              Divider(height: 1, indent: 16, color: AppColors.divider),
              _clubPhotoOption(
                Icons.photo_library_outlined,
                AppLocalizations.of(context)!.chooseFromLib,
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
          borderRadius: BorderRadius.all(Radius.circular(12)),
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
    final picked = await picker.pickImage(source: source);
    if (picked == null || !mounted) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      maxWidth: PhotoUploadQuality.avatarMaxDimension,
      maxHeight: PhotoUploadQuality.avatarMaxDimension,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: PhotoUploadQuality.jpegQuality,
      uiSettings: [
        IOSUiSettings(
          title: AppLocalizations.of(context)!.cropPhoto,
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: true,
          aspectRatioPickerButtonHidden: true,
        ),
        AndroidUiSettings(
          toolbarTitle: AppLocalizations.of(context)!.cropPhoto,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        title: Text(
          AppLocalizations.of(context)!.useThisPhoto,
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text),
        ),
        content: ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          child: Image.file(File(cropped.path), fit: BoxFit.cover),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              AppLocalizations.of(context)!.cancel,
              style: TextStyle(color: AppColors.secondaryText),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context)!.usePhoto),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final remoteUrl = await supabaseClubService.updateClubLogo(
          club: club,
          imagePath: cropped.path,
        );
        if (remoteUrl != null) {
          club.logoUrl = remoteUrl;
          userState.setClubPhoto(club.id, remoteUrl);
          await userPrefsService.removeClubPhoto(club.id);
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context)!.couldNotUploadClubPhoto,
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
        }
      }
      setState(() {});
    }
  }

  void _openClubDescriptionSheet(Club club) {
    final controller = TextEditingController(text: club.description);
    var saving = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final value = controller.text.trim();
          final canSave =
              value.isNotEmpty && value != club.description && !saving;
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
                        borderRadius: BorderRadius.all(Radius.circular(2)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    AppLocalizations.of(context)!.clubDescription,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppLocalizations.of(
                      context,
                    )!.descriptionAppearsOnClubProfile(club.name),
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
                      hintText: AppLocalizations.of(
                        context,
                      )!.clubDescriptionHint,
                      hintStyle: TextStyle(color: AppColors.secondaryText),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
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
                            AppLocalizations.of(context)!.cancel,
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
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: canSave
                              ? () async {
                                  setSheetState(() => saving = true);
                                  try {
                                    await supabaseClubService
                                        .updateClubDescription(
                                          club: club,
                                          description: value,
                                        );
                                  } catch (_) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context)
                                      ..hideCurrentSnackBar()
                                      ..showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            AppLocalizations.of(
                                              context,
                                            )!.couldNotUpdateClubDescription,
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    if (ctx.mounted) {
                                      setSheetState(() => saving = false);
                                    }
                                    return;
                                  }
                                  if (!mounted || !ctx.mounted) return;
                                  club.description = value;
                                  userState.bumpClubInfo();
                                  setState(() {});
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
                            saving
                                ? AppLocalizations.of(context)!.savingEllipsis
                                : AppLocalizations.of(context)!.save,
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
                        borderRadius: BorderRadius.all(Radius.circular(2)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    AppLocalizations.of(context)!.clubCategories,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppLocalizations.of(context)!.chooseTagsHint,
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
                          label: Text(_localizedClubCategory(ctx, category)),
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
                      labelText: AppLocalizations.of(context)!.customTags,
                      hintText: AppLocalizations.of(context)!.customTagsHint,
                      helperText: AppLocalizations.of(
                        context,
                      )!.separateWithCommas,
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
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
                            AppLocalizations.of(context)!.cancel,
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
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
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
                                    userPrefsService
                                        .saveClubCategory(
                                          club.id,
                                          club.categoryName,
                                        )
                                        .catchError((_) {}),
                                  );
                                }
                              : null,
                          child: Text(
                            AppLocalizations.of(context)!.saveCategories,
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
    await onboardingService.reset(_userId);
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    onboardingService.requestReplay();
  }

  Future<void> _openExternalPage(String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.couldNotOpenPage),
          ),
        );
    }
  }

  Widget _externalPageTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String url,
    Color? color,
  }) {
    final accent = color ?? AppColors.primaryRed;
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        child: Icon(icon, color: accent, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.text),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
      ),
      trailing: Icon(Icons.open_in_new_rounded, color: AppColors.secondaryText),
      onTap: () => _openExternalPage(url),
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
        title: Text(
          AppLocalizations.of(context)!.settings,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
              _SectionHeader(
                title: AppLocalizations.of(context)!.profileSection,
              ),
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
                              borderRadius: BorderRadius.all(
                                Radius.circular(10),
                              ),
                            ),
                            child: Icon(
                              Icons.person_outline_rounded,
                              color: AppColors.primaryRed,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            AppLocalizations.of(context)!.editProfile,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                          ),
                          subtitle: Text(
                            AppLocalizations.of(context)!.editProfileSubtitle,
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
                        Divider(
                          height: 1,
                          indent: 56,
                          color: AppColors.divider,
                        ),
                        ListTile(
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.lightRed,
                              borderRadius: BorderRadius.all(
                                Radius.circular(10),
                              ),
                            ),
                            child: Icon(
                              Icons.badge_outlined,
                              color: AppColors.primaryRed,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            AppLocalizations.of(context)!.changeMyName,
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
              _SectionHeader(title: AppLocalizations.of(context)!.clubSection),
              ListenableBuilder(
                listenable: userState,
                builder: (context, _) {
                  final club = _managedClub;
                  if (club == null) return const SizedBox.shrink();
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
                              borderRadius: BorderRadius.all(
                                Radius.circular(10),
                              ),
                            ),
                            child: Icon(
                              Icons.edit_outlined,
                              color: AppColors.primaryRed,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            AppLocalizations.of(context)!.clubName,
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
                        Divider(
                          height: 1,
                          indent: 56,
                          color: AppColors.divider,
                        ),
                        ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                            child: ClubAvatar(
                              clubId: club.id,
                              clubName: club.name,
                              color: AppColors.primaryRed,
                              imageUrl: club.logoUrl,
                              size: 36,
                              fontSize: 16,
                              borderRadius: 10,
                            ),
                          ),
                          title: Text(
                            AppLocalizations.of(context)!.clubPhoto,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                          ),
                          subtitle: Text(
                            AppLocalizations.of(context)!.tapToChangeLogo,
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
                        Divider(
                          height: 1,
                          indent: 56,
                          color: AppColors.divider,
                        ),
                        ListTile(
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.lightRed,
                              borderRadius: BorderRadius.all(
                                Radius.circular(10),
                              ),
                            ),
                            child: Icon(
                              Icons.sell_outlined,
                              color: AppColors.primaryRed,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            AppLocalizations.of(context)!.clubCategories,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                          ),
                          subtitle: Text(
                            _clubCategories(club).isEmpty
                                ? AppLocalizations.of(context)!.addDiscoveryTags
                                : _clubCategories(club)
                                      .map(
                                        (category) => _localizedClubCategory(
                                          context,
                                          category,
                                        ),
                                      )
                                      .join(', '),
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
                        Divider(
                          height: 1,
                          indent: 56,
                          color: AppColors.divider,
                        ),
                        ListTile(
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.lightRed,
                              borderRadius: BorderRadius.all(
                                Radius.circular(10),
                              ),
                            ),
                            child: Icon(
                              Icons.description_outlined,
                              color: AppColors.primaryRed,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            AppLocalizations.of(context)!.clubDescription,
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
                        Divider(
                          height: 1,
                          indent: 56,
                          color: AppColors.divider,
                        ),
                        ListTile(
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.lightRed,
                              borderRadius: BorderRadius.all(
                                Radius.circular(10),
                              ),
                            ),
                            child: Icon(
                              Icons.manage_accounts_outlined,
                              color: AppColors.primaryRed,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            AppLocalizations.of(context)!.manageBoardMembers,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                          ),
                          subtitle: Text(
                            AppLocalizations.of(context)!.manageBoardSubtitle,
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

            if (_isClubUpModerator) ...[
              const SizedBox(height: 24),
              _SectionHeader(title: S.moderation),
              Container(
                color: AppColors.card,
                child: ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.lightRed,
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                    ),
                    child: Icon(
                      Icons.admin_panel_settings_outlined,
                      color: AppColors.primaryRed,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    S.moderationCenter,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  subtitle: Text(
                    S.moderationCenterSubtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.secondaryText,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ModerationCenterScreen(),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ── Safety section ───────────────────────────────────────────────
            _SectionHeader(title: S.safetyOptions),
            Container(
              color: AppColors.card,
              child: ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.lightRed,
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                  ),
                  child: Icon(
                    Icons.block_outlined,
                    color: AppColors.primaryRed,
                    size: 20,
                  ),
                ),
                title: Text(
                  S.blockedAccounts,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                subtitle: Text(
                  S.blockedAccountsSubtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.secondaryText,
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BlockedAccountsScreen(),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Appearance section ───────────────────────────────────────────
            _SectionHeader(title: AppLocalizations.of(context)!.appearance),
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
                          borderRadius: BorderRadius.all(Radius.circular(10)),
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
                        themeService.isDark
                            ? AppLocalizations.of(context)!.darkMode
                            : AppLocalizations.of(context)!.lightMode,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                      subtitle: Text(
                        themeService.isDark
                            ? AppLocalizations.of(context)!.switchToLight
                            : AppLocalizations.of(context)!.switchToDark,
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
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        child: Icon(
                          Icons.language_rounded,
                          color: AppColors.primaryRed,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        AppLocalizations.of(context)!.language,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                      trailing: const LanguageToggle(),
                    ),
                  ],
                ),
              ),
            ),

            // ── Help section (replay the student app tour — students only) ───
            if (authService.isStudentSession) ...[
              const SizedBox(height: 24),
              _SectionHeader(title: AppLocalizations.of(context)!.help),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primaryRed, AppColors.darkRed],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.all(Radius.circular(16)),
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
                      borderRadius: BorderRadius.all(Radius.circular(16)),
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
                                borderRadius: BorderRadius.all(
                                  Radius.circular(13),
                                ),
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
                                    AppLocalizations.of(
                                      context,
                                    )!.replayTutorial,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    AppLocalizations.of(
                                      context,
                                    )!.replayTutorialSubtitle,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.3,
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
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
            ],

            // ── Help section (replay the club admin tour — club admins only) ──
            if (_managedClub != null) ...[
              const SizedBox(height: 24),
              _SectionHeader(title: AppLocalizations.of(context)!.help),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primaryRed, AppColors.darkRed],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.all(Radius.circular(16)),
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
                      borderRadius: BorderRadius.all(Radius.circular(16)),
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
                                borderRadius: BorderRadius.all(
                                  Radius.circular(13),
                                ),
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
                                    AppLocalizations.of(
                                      context,
                                    )!.replayTutorial,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    AppLocalizations.of(
                                      context,
                                    )!.replayTutorialSubtitle,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.3,
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
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
            ],

            const SizedBox(height: 24),

            // ── Public support and legal pages ──────────────────────────────
            _SectionHeader(
              title: AppLocalizations.of(context)!.supportAndLegal,
            ),
            Container(
              color: AppColors.card,
              child: Column(
                children: [
                  _externalPageTile(
                    icon: Icons.help_outline_rounded,
                    title: AppLocalizations.of(context)!.supportCenter,
                    subtitle: AppLocalizations.of(
                      context,
                    )!.supportCenterSubtitle,
                    url: localeService.languageCode == 'tr'
                        ? AppLinks.supportTurkish
                        : AppLinks.support,
                  ),
                  Divider(height: 1, indent: 56, color: AppColors.divider),
                  _externalPageTile(
                    icon: Icons.privacy_tip_outlined,
                    title: AppLocalizations.of(context)!.privacyPolicy,
                    subtitle: AppLocalizations.of(
                      context,
                    )!.privacyPolicySubtitle,
                    url: localeService.languageCode == 'tr'
                        ? AppLinks.privacyPolicyTurkish
                        : AppLinks.privacyPolicy,
                  ),
                  Divider(height: 1, indent: 56, color: AppColors.divider),
                  _externalPageTile(
                    icon: Icons.gavel_rounded,
                    title: AppLocalizations.of(context)!.termsOfUse,
                    subtitle: AppLocalizations.of(context)!.termsOfUseSubtitle,
                    url: localeService.languageCode == 'tr'
                        ? AppLinks.termsOfUseTurkish
                        : AppLinks.termsOfUse,
                  ),
                  Divider(height: 1, indent: 56, color: AppColors.divider),
                  _externalPageTile(
                    icon: Icons.delete_outline_rounded,
                    title: AppLocalizations.of(context)!.deleteAccount,
                    subtitle: AppLocalizations.of(
                      context,
                    )!.deleteAccountSubtitle,
                    url: localeService.languageCode == 'tr'
                        ? AppLinks.accountDeletionTurkish
                        : AppLinks.accountDeletion,
                    color: Colors.red,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Account section ──────────────────────────────────────────────
            _SectionHeader(title: AppLocalizations.of(context)!.account),
            Container(
              color: AppColors.card,
              child: ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  child: Icon(Icons.logout, color: Colors.red, size: 20),
                ),
                title: Text(
                  AppLocalizations.of(context)!.logOut,
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: _confirmAndLogout,
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
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save(String value) async {
    setState(() => _saving = true);
    try {
      await supabaseClubService.updateClubName(club: widget.club, name: value);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.couldNotUpdateClubName),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    if (!mounted) return;
    widget.club.name = value;
    userState.bumpClubInfo();
    unawaited(userPrefsService.saveClubName(widget.club.id, value));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final value = _controller.text.trim();
    final canSave = value.isNotEmpty && value != widget.club.name && !_saving;

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
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              AppLocalizations.of(context)!.clubName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppLocalizations.of(context)!.clubNameAppearsAcrossApp,
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
                labelText: AppLocalizations.of(context)!.clubNameLabel,
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
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
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      AppLocalizations.of(context)!.cancel,
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
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: canSave ? () => _save(value) : null,
                    child: Text(
                      _saving
                          ? AppLocalizations.of(context)!.savingEllipsis
                          : AppLocalizations.of(context)!.saveName,
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
    text: widget.realName,
  );
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save(String name) async {
    setState(() => _saving = true);
    try {
      await studentProfileService.updateFullName(
        userId: widget.userId,
        fullName: name,
      );
      authService.updateCurrentUserName(name);
      userState.clearUsername(widget.userId);
      await userPrefsService.save(widget.userId);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.couldNotUpdateName),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final customName = _controller.text.trim();
    final canSave =
        customName.isNotEmpty && customName != widget.realName && !_saving;

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
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              AppLocalizations.of(context)!.changeMyName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppLocalizations.of(context)!.changeNameSubtitle,
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
                labelText: AppLocalizations.of(context)!.displayName,
                hintText: widget.realName,
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
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
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: Text(
                      AppLocalizations.of(context)!.cancel,
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
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: canSave ? () => _save(customName) : null,
                    child: Text(
                      _saving
                          ? AppLocalizations.of(context)!.savingEllipsis
                          : AppLocalizations.of(context)!.saveName,
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
