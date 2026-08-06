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
import '../widgets/user_avatar.dart';
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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ClubCategoriesSheet(
        club: club,
        categoryOptions: _clubCategoryOptions,
        localizeCategory: _localizedClubCategory,
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
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

  /// Sections of the settings list, in the order the redesign lays them out:
  /// identity card → role-specific group → privacy → appearance → tutorial →
  /// support & legal → the destructive group.
  List<Widget> _sections(BuildContext context, AppLocalizations l10n) {
    final club = _managedClub;
    final isStudent = authService.isStudentSession;

    return [
      // ── Identity card (students) ───────────────────────────────────────────
      // Replaces the old "Edit profile" row: the row's destination now hangs
      // off the card's own action strip.
      if (isStudent)
        ListenableBuilder(
          listenable: userState,
          builder: (context, _) {
            final user = authService.currentUser!;
            final displayName = userState.displayNameFor(user.id, user.name);
            return _IdentityCard(
              avatar: UserAvatar(
                userId: user.id,
                name: user.name,
                size: 58,
                fontSize: 22,
              ),
              avatarRadius: const BorderRadius.all(Radius.circular(29)),
              name: displayName,
              meta: userState.academicSummaryFor(user.id),
              editLabel: l10n.editProfile,
              onEdit: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        EditProfileScreen(userId: user.id, realName: user.name),
                  ),
                ).then((_) {
                  if (mounted) setState(() {});
                });
              },
            );
          },
        ),

      // ── Identity card (club admins) ────────────────────────────────────────
      if (club != null)
        ListenableBuilder(
          listenable: userState,
          builder: (context, _) => _IdentityCard(
            avatar: ClubAvatar(
              clubId: club.id,
              clubName: club.name,
              color: AppColors.primaryRed,
              imageUrl: club.logoUrl,
              size: 58,
              fontSize: 22,
              borderRadius: 16,
            ),
            avatarRadius: const BorderRadius.all(Radius.circular(16)),
            name: club.name,
            meta: l10n.clubAdmin,
          ),
        ),

      // ── Club section (club admins only) ────────────────────────────────────
      if (club != null)
        ListenableBuilder(
          listenable: userState,
          builder: (context, _) {
            final categories = _clubCategories(club);
            return _SettingsGroup(
              label: l10n.clubSection,
              children: [
                _SettingsRow(
                  icon: Icons.edit_outlined,
                  title: l10n.clubName,
                  value: club.name,
                  onTap: () => _openClubNameSheet(club),
                ),
                _SettingsRow(
                  iconNode: ClubAvatar(
                    clubId: club.id,
                    clubName: club.name,
                    color: AppColors.primaryRed,
                    imageUrl: club.logoUrl,
                    size: 32,
                    fontSize: 13,
                    borderRadius: 10,
                  ),
                  title: l10n.clubPhoto,
                  subtitle: l10n.tapToChangeLogo,
                  onTap: () => _showClubPhotoOptions(club),
                ),
                _SettingsRow(
                  icon: Icons.sell_outlined,
                  title: l10n.clubCategories,
                  subtitle: categories.isEmpty
                      ? l10n.addDiscoveryTags
                      : categories
                            .map(
                              (category) =>
                                  _localizedClubCategory(context, category),
                            )
                            .join(', '),
                  onTap: () => _openClubCategoriesSheet(club),
                ),
                _SettingsRow(
                  icon: Icons.description_outlined,
                  title: l10n.clubDescription,
                  onTap: () => _openClubDescriptionSheet(club),
                ),
                _SettingsRow(
                  icon: Icons.manage_accounts_outlined,
                  title: l10n.manageBoardMembers,
                  subtitle: l10n.manageBoardSubtitle,
                  value: '${club.boardMemberIds.length}',
                  onTap: () => _openBoardManagement(club),
                ),
              ],
            );
          },
        ),

      // ── Account section (students only) ────────────────────────────────────
      if (isStudent)
        ListenableBuilder(
          listenable: userState,
          builder: (context, _) {
            final user = authService.currentUser!;
            return _SettingsGroup(
              label: l10n.account,
              children: [
                _SettingsRow(
                  icon: Icons.badge_outlined,
                  title: l10n.changeMyName,
                  value: userState.displayNameFor(user.id, user.name),
                  onTap: _openChangeNameSheet,
                ),
              ],
            );
          },
        ),

      // ── Moderation section (ClubUp moderators only) ────────────────────────
      if (_isClubUpModerator)
        _SettingsGroup(
          label: S.moderation,
          children: [
            _SettingsRow(
              icon: Icons.admin_panel_settings_outlined,
              title: S.moderationCenter,
              subtitle: S.moderationCenterSubtitle,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ModerationCenterScreen(),
                ),
              ),
            ),
          ],
        ),

      // ── Privacy section ────────────────────────────────────────────────────
      _SettingsGroup(
        label: S.privacySection,
        children: [
          _SettingsRow(
            icon: Icons.block_outlined,
            title: S.blockedAccounts,
            subtitle: S.blockedAccountsSubtitle,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BlockedAccountsScreen()),
            ),
          ),
        ],
      ),

      // ── Appearance section ─────────────────────────────────────────────────
      ListenableBuilder(
        listenable: themeService,
        builder: (context, _) => _SettingsGroup(
          label: l10n.appearance,
          children: [
            _SettingsRow(
              icon: themeService.isDark
                  ? Icons.dark_mode_rounded
                  : Icons.light_mode_rounded,
              title: themeService.isDark ? l10n.darkMode : l10n.lightMode,
              subtitle: themeService.isDark
                  ? l10n.switchToLight
                  : l10n.switchToDark,
              onTap: () => themeService.setDark(!themeService.isDark),
              trailing: _ThemeSwitch(
                value: themeService.isDark,
                onChanged: themeService.setDark,
              ),
            ),
            _SettingsRow(
              icon: Icons.language_rounded,
              title: l10n.language,
              trailing: const LanguageToggle(),
            ),
          ],
        ),
      ),

      // ── Help section (replay the app tour) ─────────────────────────────────
      if (isStudent || club != null)
        _TutorialCard(
          label: l10n.help,
          title: l10n.replayTutorial,
          subtitle: l10n.replayTutorialSubtitle,
          onTap: _replayTutorial,
        ),

      // ── Public support and legal pages ─────────────────────────────────────
      _SettingsGroup(
        label: l10n.supportAndLegal,
        children: [
          _SettingsRow(
            icon: Icons.help_outline_rounded,
            title: l10n.supportCenter,
            subtitle: l10n.supportCenterSubtitle,
            external: true,
            onTap: () => _openExternalPage(
              localeService.languageCode == 'tr'
                  ? AppLinks.supportTurkish
                  : AppLinks.support,
            ),
          ),
          _SettingsRow(
            icon: Icons.privacy_tip_outlined,
            title: l10n.privacyPolicy,
            subtitle: l10n.privacyPolicySubtitle,
            external: true,
            onTap: () => _openExternalPage(
              localeService.languageCode == 'tr'
                  ? AppLinks.privacyPolicyTurkish
                  : AppLinks.privacyPolicy,
            ),
          ),
          _SettingsRow(
            icon: Icons.gavel_rounded,
            title: l10n.termsOfUse,
            subtitle: l10n.termsOfUseSubtitle,
            external: true,
            onTap: () => _openExternalPage(
              localeService.languageCode == 'tr'
                  ? AppLinks.termsOfUseTurkish
                  : AppLinks.termsOfUse,
            ),
          ),
        ],
      ),

      // ── Destructive actions ────────────────────────────────────────────────
      _SettingsGroup(
        children: [
          _SettingsRow(
            icon: Icons.logout,
            title: l10n.logOut,
            danger: true,
            chevron: false,
            onTap: _confirmAndLogout,
          ),
          _SettingsRow(
            icon: Icons.delete_outline_rounded,
            title: l10n.deleteAccount,
            subtitle: l10n.deleteAccountSubtitle,
            danger: true,
            external: true,
            onTap: () => _openExternalPage(
              localeService.languageCode == 'tr'
                  ? AppLinks.accountDeletionTurkish
                  : AppLinks.accountDeletion,
            ),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // The theme listener wraps the Scaffold, not just its body: the page
    // background is read from AppColors at Scaffold construction, so a rebuild
    // confined to the body would leave it on the previous theme.
    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) => Scaffold(
        backgroundColor: AppColors.background,
        body: ListenableBuilder(
          listenable: localeService,
          builder: (context, _) {
            final l10n = AppLocalizations.of(context)!;
            return Stack(
              children: [
                // Warm burgundy bloom behind the top of the page.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 220,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, -1.4),
                          radius: 1.3,
                          colors: [
                            AppColors.darkRed.withValues(
                              alpha: themeService.isDark ? 0.30 : 0.10,
                            ),
                            AppColors.darkRed.withValues(alpha: 0),
                          ],
                          stops: const [0, 0.7],
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      _SettingsHeader(title: l10n.settings),
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            6,
                            16,
                            32 + MediaQuery.paddingOf(context).bottom,
                          ),
                          children: _sections(context, l10n),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Destructive-action red. Brighter on the dark theme so it stays legible on
/// the near-black background.
Color get _dangerColor =>
    themeService.isDark ? const Color(0xFFFF5F5F) : const Color(0xFFC62828);

/// Back chevron in a soft square, with the title optically centred against the
/// full width rather than against the remaining space.
class _SettingsHeader extends StatelessWidget {
  final String title;
  const _SettingsHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: SizedBox(
        height: 34,
        child: Stack(
          children: [
            Center(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                  color: AppColors.text,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Material(
                color: AppColors.card,
                borderRadius: const BorderRadius.all(Radius.circular(11)),
                child: InkWell(
                  borderRadius: const BorderRadius.all(Radius.circular(11)),
                  onTap: () => Navigator.maybePop(context),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: const BorderRadius.all(Radius.circular(11)),
                    ),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      size: 22,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An inset card of rows under an optional uppercase label. Rows are separated
/// by a full-width hairline; the card clips them so the corners stay round.
class _SettingsGroup extends StatelessWidget {
  final String? label;
  final List<Widget> children;

  const _SettingsGroup({this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Divider(height: 1, thickness: 1, color: AppColors.divider));
      }
      rows.add(children[i]);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
              child: Text(
                label!.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.3,
                  color: AppColors.secondaryText,
                ),
              ),
            ),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: const BorderRadius.all(Radius.circular(18)),
              border: Border.all(color: AppColors.divider),
              boxShadow: themeService.isDark
                  ? null
                  : [
                      BoxShadow(
                        color: const Color(0xFF1A0610).withValues(alpha: 0.04),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }
}

/// The rounded icon square that opens every row.
class _RowIcon extends StatelessWidget {
  final IconData? icon;
  final Widget? node;
  final bool danger;

  const _RowIcon({this.icon, this.node, required this.danger});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: danger
            ? _dangerColor.withValues(alpha: 0.13)
            : AppColors.surfaceAlt,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child:
          node ??
          Icon(
            icon,
            size: 17,
            color: danger ? _dangerColor : AppColors.mutedText,
          ),
    );
  }
}

/// One row inside a [_SettingsGroup]: icon, title, optional subtitle, an
/// optional right-aligned value, and either a supplied control or an affordance
/// chevron / external-link glyph.
class _SettingsRow extends StatelessWidget {
  final IconData? icon;
  final Widget? iconNode;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final bool chevron;
  final bool external;
  final bool danger;
  final VoidCallback? onTap;

  const _SettingsRow({
    this.icon,
    this.iconNode,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.chevron = true,
    this.external = false,
    this.danger = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget? end = trailing;
    if (end == null && external) {
      end = Icon(
        Icons.open_in_new_rounded,
        size: 16,
        color: AppColors.secondaryText,
      );
    } else if (end == null && chevron) {
      end = Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: AppColors.secondaryText,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: subtitle == null ? 13 : 12,
          ),
          child: Row(
            children: [
              _RowIcon(icon: icon, node: iconNode, danger: danger),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: danger ? _dangerColor : AppColors.text,
                      ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (value != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Text(
                      value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                ),
              if (end != null)
                Padding(padding: const EdgeInsets.only(left: 8), child: end),
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatar, name and supporting line at the top of the screen. Students also get
/// an action strip that opens the profile editor; clubs edit through the rows
/// in the Club group below, so the strip is omitted when [onEdit] is null.
class _IdentityCard extends StatelessWidget {
  final Widget avatar;
  final BorderRadius avatarRadius;
  final String name;
  final String? meta;
  final String? editLabel;
  final VoidCallback? onEdit;

  const _IdentityCard({
    required this.avatar,
    required this.avatarRadius,
    required this.name,
    this.meta,
    this.editLabel,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = themeService.isDark;
    final metaLine = meta?.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        border: Border.all(
          color: isDark
              ? AppColors.primaryRed.withValues(alpha: 0.22)
              : AppColors.divider,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0, 0.62],
            colors: [
              AppColors.darkRed.withValues(alpha: isDark ? 0.30 : 0.09),
              AppColors.darkRed.withValues(alpha: 0),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: avatarRadius,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.darkRed.withValues(
                            alpha: isDark ? 0.30 : 0.12,
                          ),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: avatar,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: AppColors.text,
                          ),
                        ),
                        if (metaLine != null && metaLine.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              metaLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (onEdit != null) ...[
              Divider(height: 1, thickness: 1, color: AppColors.divider),
              Material(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : AppColors.primaryRed.withValues(alpha: 0.05),
                child: InkWell(
                  onTap: onEdit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 15,
                          color: AppColors.primaryRed,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          editLabel ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Standalone outlined card that replays the guided tour.
class _TutorialCard extends StatelessWidget {
  final String label;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _TutorialCard({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.3,
                color: AppColors.secondaryText,
              ),
            ),
          ),
          Material(
            color: AppColors.card,
            borderRadius: const BorderRadius.all(Radius.circular(18)),
            child: InkWell(
              borderRadius: const BorderRadius.all(Radius.circular(18)),
              onTap: onTap,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(18)),
                  border: Border.all(
                    color: AppColors.primaryRed.withValues(
                      alpha: themeService.isDark ? 0.28 : 0.16,
                    ),
                  ),
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.lightRed,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(11),
                        ),
                      ),
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        size: 19,
                        color: AppColors.primaryRed,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.2,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppColors.secondaryText,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill switch used by the appearance row — the design's gradient track instead
/// of the stock Material thumb.
class _ThemeSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ThemeSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: 46,
          height: 28,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(999)),
            color: value ? null : AppColors.divider,
            gradient: value
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.darkRed, AppColors.primaryRed],
                  )
                : null,
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x4D000000),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for editing a club's discovery categories. The controller is
/// owned by the sheet so it survives the dismissal animation and is disposed
/// only when the sheet widget is actually removed.
class _ClubCategoriesSheet extends StatefulWidget {
  final Club club;
  final List<String> categoryOptions;
  final String Function(BuildContext context, String category) localizeCategory;

  const _ClubCategoriesSheet({
    required this.club,
    required this.categoryOptions,
    required this.localizeCategory,
  });

  @override
  State<_ClubCategoriesSheet> createState() => _ClubCategoriesSheetState();
}

class _ClubCategoriesSheetState extends State<_ClubCategoriesSheet> {
  late final Set<String> _selected;
  late final TextEditingController _controller;

  List<String> _clubCategories() {
    final raw = widget.club.categoryName?.trim();
    if (raw == null || raw.isEmpty) return const [];
    return raw
        .split(',')
        .map((category) => category.trim())
        .where((category) => category.isNotEmpty)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _selected = _clubCategories().toSet();
    final extra = _selected
        .where((category) => !widget.categoryOptions.contains(category))
        .join(', ');
    _controller = TextEditingController(text: extra);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<String> _categories() {
    final custom = _controller.text
        .split(',')
        .map((category) => category.trim())
        .where((category) => category.isNotEmpty);
    return {..._selected, ...custom}.toList()..sort();
  }

  void _save() {
    final nextValue = _categories().join(', ');
    final currentValue = _clubCategories().join(', ');
    if (nextValue == currentValue) return;

    widget.club.categoryName = nextValue.isEmpty ? null : nextValue;
    userState.bumpClubInfo();
    Navigator.of(context).pop();
    unawaited(
      userPrefsService
          .saveClubCategory(widget.club.id, widget.club.categoryName)
          .catchError((_) {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final nextValue = _categories().join(', ');
    final currentValue = _clubCategories().join(', ');
    final canSave = nextValue != currentValue;

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
              l10n.clubCategories,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.chooseTagsHint,
              style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in widget.categoryOptions)
                  FilterChip(
                    label: Text(widget.localizeCategory(context, category)),
                    selected: _selected.contains(category),
                    selectedColor: AppColors.lightRed,
                    checkmarkColor: AppColors.primaryRed,
                    labelStyle: TextStyle(
                      color: _selected.contains(category)
                          ? AppColors.primaryRed
                          : AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(color: AppColors.divider),
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          _selected.add(category);
                        } else {
                          _selected.remove(category);
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _controller,
              style: TextStyle(color: AppColors.text, fontSize: 14),
              decoration: InputDecoration(
                labelText: l10n.customTags,
                hintText: l10n.customTagsHint,
                helperText: l10n.separateWithCommas,
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
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      l10n.cancel,
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
                    onPressed: canSave ? _save : null,
                    child: Text(
                      l10n.saveCategories,
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
