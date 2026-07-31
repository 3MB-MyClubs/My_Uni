import 'dart:io';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../services/locale_service.dart';
import '../services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/app_network_image.dart';
import '../widgets/club_avatar.dart';
import '../models/club.dart';
import '../models/event.dart';
import '../models/user.dart';
import '../services/personalization_service.dart';
import '../services/academic_year_options.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/club_admin_access.dart';
import '../services/content_store.dart';
import '../services/event_access.dart';
import '../services/lazy_content_loader.dart';
import '../services/mock_data.dart';
import '../services/people_service.dart';
import '../services/photo_upload_quality.dart';
import '../services/student_profile_service.dart' as remote_profile;
import '../services/student_club_role_service.dart';
import '../services/supabase_club_service.dart';
import '../services/user_prefs_service.dart';
import '../services/user_state.dart';
import '../widgets/academic_program_picker.dart';
import '../widgets/loading_skeleton.dart';
import '../widgets/profile_photo_viewer.dart';
import '../widgets/user_avatar.dart';
import 'club_profile_screen.dart';
import 'event_detail_screen.dart';
import 'explore_screen.dart';
import 'my_calendar_screen.dart';
import 'rsvp_list_screen.dart';
import 'post_detail_screen.dart';
import 'settings_screen.dart';
import 'student_profile_screen.dart';
import 'user_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onLogout;
  const ProfileScreen({super.key, this.onLogout});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const List<Color> _clubColors = [
    Color(0xFFB41C18),
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFF6A1B9A),
    Color(0xFFE65100),
    Color(0xFF00838F),
  ];

  Color _clubColor(int index) => _clubColors[index % _clubColors.length];

  @override
  void initState() {
    super.initState();
    localeService.addListener(_onLocaleChanged);
    themeService.addListener(_onLocaleChanged);
    _refreshClubMemberCounts();
  }

  @override
  void dispose() {
    localeService.removeListener(_onLocaleChanged);
    themeService.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshClubMemberCounts() async {
    try {
      await lazyContentLoader.ensureCountsLoaded(force: true);
      if (mounted) setState(() {});
    } catch (_) {
      // Keep the last successful aggregate snapshot while offline.
    }
  }

  int _contentTab = 0; // 0 = Posts, 1 = Events
  String? _hydratedConnectionsForUserId;
  static const List<String> _yearOptions = fallbackAcademicYearNames;

  Widget _initialAvatar(String name) => Container(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.primaryRed.withValues(alpha: 0.18),
    ),
    child: Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryRed,
        ),
      ),
    ),
  );

  Future<void> _hydrateMyConnections(String userId) async {
    if (userId.isEmpty || _hydratedConnectionsForUserId == userId) return;
    _hydratedConnectionsForUserId = userId;
    try {
      await peopleService.hydrateConnectionsFor(userId);
      if (mounted) setState(() {});
    } catch (_) {
      _hydratedConnectionsForUserId = null;
    }
  }

  Future<void> _pickProfilePhoto(String userId, ImageSource source) async {
    CroppedFile? cropped;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source);
      if (picked == null || !mounted) return;

      cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        maxWidth: PhotoUploadQuality.avatarMaxDimension,
        maxHeight: PhotoUploadQuality.avatarMaxDimension,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: PhotoUploadQuality.jpegQuality,
        uiSettings: [
          IOSUiSettings(
            title: AppLocalizations.of(context)!.cropPhotoTitle,
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: true,
            aspectRatioPickerButtonHidden: true,
            cropStyle: CropStyle.circle,
          ),
          AndroidUiSettings(
            toolbarTitle: AppLocalizations.of(context)!.cropPhotoTitle,
            toolbarColor: AppColors.primaryRed,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
            hideBottomControls: false,
            cropStyle: CropStyle.circle,
          ),
        ],
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.couldNotOpenPhotoCropper,
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    if (cropped == null || !mounted) return;
    final croppedFile = cropped;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        title: Text(
          AppLocalizations.of(context)!.useThisPhoto,
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text),
        ),
        content: Center(
          heightFactor: 1,
          child: ClipOval(
            child: Image.file(
              File(croppedFile.path),
              width: 180,
              height: 180,
              fit: BoxFit.cover,
            ),
          ),
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
      // Copy from temp dir to permanent app documents dir so the file
      // survives app restarts (temp files are cleared by the OS).
      final docsDir = await getApplicationDocumentsDirectory();
      final ext = croppedFile.path.contains('.')
          ? croppedFile.path.substring(croppedFile.path.lastIndexOf('.'))
          : '.jpg';
      final permanentPath = '${docsDir.path}/profile_$userId$ext';
      await File(croppedFile.path).copy(permanentPath);

      if (!mounted) return;
      userState.setProfilePhoto(userId, permanentPath);
      final managedClub = authService.currentAdmin?.id == userId
          ? managedClubForAdmin(userId)
          : null;
      if (managedClub != null) {
        try {
          final remoteUrl = await supabaseClubService.updateClubLogo(
            club: managedClub,
            imagePath: croppedFile.path,
          );
          if (remoteUrl != null) {
            managedClub.logoUrl = remoteUrl;
            userState.setClubPhoto(managedClub.id, remoteUrl);
            await userPrefsService.removeClubPhoto(managedClub.id);
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
      }
      userPrefsService.save(userId);
      try {
        await remote_profile.studentProfileService.uploadAvatar(
          userId: userId,
          bytes: await File(permanentPath).readAsBytes(),
        );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context)!.photoSavedLocallyUploadFailed,
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
        }
      }
      setState(() {});
    }
  }

  Future<void> _editMajorAndYear(BuildContext context, String userId) async {
    final savedMajor = userState.majors[userId];
    String? selectedMajor = kAcademicPrograms.contains(savedMajor)
        ? savedMajor
        : null;
    var selectedYear = userState.years[userId];

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppColors.surfaceAlt,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          title: Text(
            AppLocalizations.of(context)!.majorYearLabel,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AcademicProgramField(
                value: selectedMajor,
                hint: AppLocalizations.of(context)!.selectMajorHint,
                onTap: () async {
                  final result = await showAcademicProgramPicker(
                    context: ctx,
                    title: AppLocalizations.of(context)!.selectMajor,
                    selected: selectedMajor == null
                        ? const []
                        : [selectedMajor!],
                  );
                  if (result == null || !ctx.mounted) return;
                  setModalState(
                    () => selectedMajor = result.isEmpty ? null : result.first,
                  );
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: selectedYear != null && selectedYear!.isNotEmpty
                    ? selectedYear
                    : null,
                dropdownColor: AppColors.card,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.yearLabel,
                ),
                items: _yearOptions
                    .map(
                      (year) => DropdownMenuItem<String>(
                        value: year,
                        child: Text(
                          academicYearDisplayName(year),
                          style: TextStyle(color: AppColors.text),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setModalState(() => selectedYear = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                AppLocalizations.of(context)!.cancel,
                style: TextStyle(color: AppColors.secondaryText),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                userState.setMajor(userId, selectedMajor ?? '');
                userState.setYear(userId, selectedYear ?? '');
                await userPrefsService.save(userId);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(AppLocalizations.of(context)!.save),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editBio(BuildContext context, String userId) async {
    final bioController = TextEditingController(
      text: userState.bios[userId] ?? '',
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        title: Text(
          AppLocalizations.of(context)!.bioLabel,
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text),
        ),
        content: TextField(
          controller: bioController,
          maxLength: 80,
          maxLines: 3,
          style: TextStyle(color: AppColors.text),
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.bioHint,
            hintStyle: TextStyle(color: AppColors.secondaryText),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              AppLocalizations.of(context)!.cancel,
              style: TextStyle(color: AppColors.secondaryText),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              userState.setBio(userId, bioController.text);
              await userPrefsService.save(userId);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(AppLocalizations.of(context)!.save),
          ),
        ],
      ),
    );

    bioController.dispose();
  }

  List<User> _followersForUser(String userId) {
    final liveFollowers = peopleService.followersFor(userId);
    if (liveFollowers.isNotEmpty) return liveFollowers;
    return users
        .where(
          (user) => user.id != userId && user.followingUserIds.contains(userId),
        )
        .toList();
  }

  List<User> _followingUsers() {
    final peopleById = {
      for (final user in users) user.id: user,
      for (final user in peopleService.cachedPeople) user.id: user,
    };
    return userState.followedUserIds
        .map(
          (id) =>
              peopleById[id] ??
              User(
                id: id,
                name: AppLocalizations.of(context)!.studentProfile,
                email: '',
                password: '',
                role: 'student',
                subscribedClubIds: const [],
              ),
        )
        .toList();
  }

  String _initialsFor(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  String _graduationLabel(String? year) {
    final value = year?.trim();
    return value == null || value.isEmpty ? '' : value.toUpperCase();
  }

  Event? _nextUpcomingEvent(String userId) {
    final now = DateTime.now();
    final upcoming =
        events
            .where(
              (event) =>
                  event.endTime.isAfter(now) &&
                  event.attendeeUserIds.contains(userId),
            )
            .toList()
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  StudentEventData _eventDataFor(Event event) {
    final club = clubs.cast<Club?>().firstWhere(
      (club) => club?.id == event.clubId,
      orElse: () => null,
    );
    final hour = event.dateTime.hour.toString().padLeft(2, '0');
    final minute = event.dateTime.minute.toString().padLeft(2, '0');

    return StudentEventData(
      month: _monthAbbr(event.dateTime.month),
      day: event.dateTime.day.toString(),
      title: event.title,
      clubLine:
          '${club?.name ?? AppLocalizations.of(context)!.campusEventFallback} · '
          '${DateFormat.E(localeService.languageCode).format(event.dateTime)} · $hour:$minute',
      location: event.location,
    );
  }

  Color _colorForClubId(String clubId) {
    final idx = clubOrdinal(clubId);
    return _clubColor(idx < 0 ? 0 : idx);
  }

  /// Copies a shareable profile link to the clipboard and confirms via snackbar.
  void _shareProfile(String userId, String name) {
    final handle = userState.usernameFor(userId) ?? userId;
    Clipboard.setData(ClipboardData(text: 'kuclubs://user/$handle'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.profileLinkCopied(name)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showFollowersSheet(List<User> followers) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.72,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.people_alt_outlined,
                    size: 18,
                    color: AppColors.primaryRed,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.followers,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${followers.length}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: followers.isEmpty
                    ? Center(
                        child: Text(
                          AppLocalizations.of(context)!.noFollowersYet,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: followers.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: AppColors.divider),
                        itemBuilder: (_, index) {
                          final follower = followers[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 0,
                              vertical: 4,
                            ),
                            leading: UserAvatar(
                              userId: follower.id,
                              name: follower.name,
                              size: 42,
                              fontSize: 18,
                            ),
                            title: Text(
                              userState.displayNameFor(
                                follower.id,
                                follower.name,
                              ),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                              ),
                            ),
                            subtitle: userState.usernameFor(follower.id) != null
                                ? Text(
                                    follower.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.secondaryText,
                                    ),
                                  )
                                : null,
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.secondaryText,
                            ),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      UserProfileScreen(user: follower),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFollowingSheet(List<User> following) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.72,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.person_add_alt_1_outlined,
                    size: 18,
                    color: AppColors.primaryRed,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.following,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${following.length}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: following.isEmpty
                    ? Center(
                        child: Text(
                          AppLocalizations.of(context)!.notFollowingAnyone,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: following.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: AppColors.divider),
                        itemBuilder: (_, index) {
                          final person = following[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 0,
                              vertical: 4,
                            ),
                            leading: UserAvatar(
                              userId: person.id,
                              name: person.name,
                              size: 42,
                              fontSize: 18,
                            ),
                            title: Text(
                              userState.displayNameFor(person.id, person.name),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                              ),
                            ),
                            subtitle: userState.usernameFor(person.id) != null
                                ? Text(
                                    person.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.secondaryText,
                                    ),
                                  )
                                : null,
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.secondaryText,
                            ),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      UserProfileScreen(user: person),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfilePhotoOptions(BuildContext context, String userId) {
    final hasPhoto = userState.hasProfilePhoto(userId);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
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
              AppLocalizations.of(context)!.changePhoto,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.primaryRed,
                ),
              ),
              title: Text(
                AppLocalizations.of(context)!.takePhoto,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              subtitle: Text(
                AppLocalizations.of(context)!.useCamera,
                style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickProfilePhoto(userId, ImageSource.camera);
              },
            ),
            Divider(height: 1, indent: 16, color: AppColors.divider),
            ListTile(
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.primaryRed,
                ),
              ),
              title: Text(
                AppLocalizations.of(context)!.chooseFromLib,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              subtitle: Text(
                AppLocalizations.of(context)!.pickFromLib,
                style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickProfilePhoto(userId, ImageSource.gallery);
              },
            ),
            if (hasPhoto) ...[
              Divider(height: 1, indent: 16, color: AppColors.divider),
              ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.red.shade400.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red.shade400,
                  ),
                ),
                title: Text(
                  AppLocalizations.of(context)!.removePhoto,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade400,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _removeProfilePhoto(userId);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _removeProfilePhoto(String userId) async {
    userState.removeProfilePhoto(userId);
    final managedClub = authService.currentAdmin?.id == userId
        ? managedClubForAdmin(userId)
        : null;
    if (managedClub != null) {
      userState.removeClubPhoto(managedClub.id);
      await userPrefsService.removeClubPhoto(managedClub.id);
      try {
        await supabaseClubService.removeClubLogo(managedClub);
        managedClub.logoUrl = null;
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(
                  context,
                )!.clubPhotoRemovedLocallyDeleteFailed,
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    }
    await userPrefsService.save(userId);
    try {
      await remote_profile.studentProfileService.removeAvatar(userId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.photoRemovedLocallyDeleteFailed,
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = authService.currentUser;
    final admin = authService.currentAdmin;
    final myId = user?.id ?? admin?.id ?? '';
    final realName =
        user?.name ?? admin?.name ?? AppLocalizations.of(context)!.guestName;
    final displayName = userState.displayNameFor(myId, realName);
    final isAdmin = admin != null;

    if (user != null && !isAdmin) {
      _hydrateMyConnections(user.id);
      return ListenableBuilder(
        listenable: userState,
        builder: (context, _) {
          final followedClubs = studentClubRoleService.orderedProfileClubs(
            userId: user.id,
            followedClubIds: userState.followedClubIds,
            allClubs: clubs,
          );
          final followers = _followersForUser(user.id);
          final following = _followingUsers();
          final name = userState.displayNameFor(user.id, user.name);
          final year = userState.years[user.id];
          final nextEvent = _nextUpcomingEvent(user.id);

          final clubDetails = followedClubs.map((club) {
            final memberCount = clubMemberCount(club.id);
            final role =
                studentClubRoleService.roleTitleFor(club, user.id) ??
                AppLocalizations.of(context)!.memberRoleFallback;
            return StudentClubDetail(
              club: club,
              memberCount: memberCount,
              role: role,
            );
          }).toList();

          return StudentProfileScreen(
            data: StudentProfileData(
              userId: user.id,
              initials: _initialsFor(name),
              name: name,
              email: user.email,
              graduation: _graduationLabel(year),
              major:
                  userState.majors[user.id] ??
                  AppLocalizations.of(context)!.majorNotAdded,
              year: year ?? AppLocalizations.of(context)!.yearNotAdded,
              bio:
                  userState.bios[user.id] ??
                  AppLocalizations.of(context)!.addBioIntro,
              clubs: followedClubs.length,
              followers: followers.length,
              following: following.length,
              minors: userState.minors[user.id] ?? const [],
              doubleMajors: userState.doubleMajors[user.id] ?? const [],
              nextEvent: nextEvent == null ? null : _eventDataFor(nextEvent),
              clubDetails: clubDetails,
            ),
            onSettings: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    SettingsScreen(onLogout: widget.onLogout ?? () {}),
              ),
            ),
            onShare: () => _shareProfile(user.id, name),
            onFindClubs: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExploreScreen()),
            ),
            onSeeAllEvents: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyCalendarScreen()),
            ),
            onEventTap: nextEvent == null
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EventDetailScreen(
                        event: nextEvent,
                        color: _colorForClubId(nextEvent.clubId),
                      ),
                    ),
                  ),
            onFollowersTap: () => _showFollowersSheet(followers),
            onFollowingTap: () => _showFollowingSheet(following),
            followedClubs: followedClubs,
            onClubTap: (club) => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ClubProfileScreen(
                  club: club,
                  color: _clubColor(clubOrdinal(club.id)),
                ),
              ),
            ),
          );
        },
      );
    }

    // A club account (any admin except the super admin) sees its OWN club
    // profile page — the same v2 layout every visitor sees — as the Profile
    // tab, with a settings gear for logout. Only the super admin keeps the
    // all-clubs dashboard below.
    if (admin != null && admin.id != 'admin1') {
      final adminId = admin.id;
      final managed = managedClubForAdmin(adminId) ?? clubs.first;
      return ClubProfileScreen(
        club: managed,
        color: _clubColor(clubOrdinal(managed.id)),
        onSettings: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SettingsScreen(onLogout: widget.onLogout ?? () {}),
          ),
        ),
      );
    }

    final myClubs = isAdmin
        ? clubs
        : clubs.where((c) => userState.isFollowing(c.id)).toList();

    final myEventCount = events
        .where((e) => myClubs.any((c) => c.id == e.clubId))
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 400));
          if (mounted) setState(() {});
        },
        color: AppColors.primaryRed,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildAppBar(context, displayName),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListenableBuilder(
                    listenable: userState,
                    builder: (context, _) => _buildProfileHeader(
                      displayName,
                      realName,
                      isAdmin,
                      myClubs.length,
                      myEventCount,
                    ),
                  ),
                  Divider(height: 1, color: AppColors.divider),
                  _buildMyClubsSection(myClubs),
                  if (isAdmin) _buildMyContentSection(admin.id),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, String name) {
    return SliverAppBar(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.text,
      pinned: true,
      title: Text(
        name,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: AppColors.text,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.settings_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  SettingsScreen(onLogout: widget.onLogout ?? () {}),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader(
    String displayName,
    String realName,
    bool isAdmin,
    int clubCount,
    int eventCount,
  ) {
    final name = displayName;
    final myId =
        authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
    final isSuperAdmin = isAdmin && authService.currentAdmin?.id == 'admin1';

    final followers = !isAdmin ? _followersForUser(myId) : const <User>[];
    final following = !isAdmin ? _followingUsers() : const <User>[];

    // Stats for club admins: posts, events, board members
    final Club? managedClub = isAdmin ? managedClubForAdmin(myId) : null;
    final int postCount = managedClub != null
        ? newsPosts.where((p) => p.clubId == managedClub.id).length
        : 0;
    final int boardMemberCount = managedClub?.boardMemberIds.length ?? 0;
    if (isAdmin) {
      return _buildAdminProfileHeader(
        name: name,
        realName: realName,
        isSuperAdmin: isSuperAdmin,
        managedClub: managedClub,
        myId: myId,
        postCount: postCount,
        eventCount: eventCount,
        boardMemberCount: boardMemberCount,
      );
    }

    return _buildStudentProfileHeader(
      name: name,
      realName: realName,
      userId: myId,
      clubCount: clubCount,
      followers: followers,
      following: following,
    );
  }

  Widget _buildAdminProfileHeader({
    required String name,
    required String realName,
    required bool isSuperAdmin,
    required Club? managedClub,
    required String myId,
    required int postCount,
    required int eventCount,
    required int boardMemberCount,
  }) {
    return Container(
      color: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => _showProfilePhotoOptions(context, myId),
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primaryRed,
                              AppColors.accentGold,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.background,
                          ),
                          padding: const EdgeInsets.all(2),
                          child: () {
                            final photoPath = userState.profilePhotoPaths[myId];
                            final file = photoPath != null
                                ? File(photoPath)
                                : null;
                            if (file != null && file.existsSync()) {
                              final imageProvider = FileImage(file);
                              return ClipOval(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => showProfilePhotoViewer(
                                    context: context,
                                    imageProvider: imageProvider,
                                  ),
                                  child: Image(
                                    image: imageProvider,
                                    fit: BoxFit.cover,
                                    width: 88,
                                    height: 88,
                                    errorBuilder: (ctx, e, st) =>
                                        _initialAvatar(name),
                                  ),
                                ),
                              );
                            }
                            return _initialAvatar(name);
                          }(),
                        ),
                      ),
                      Positioned(
                        right: 1,
                        bottom: 1,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.background,
                              width: 2.5,
                            ),
                          ),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatCell(
                        value: '$postCount',
                        label: AppLocalizations.of(context)!.posts,
                      ),
                      _StatCell(
                        value: '$eventCount',
                        label: AppLocalizations.of(context)!.events,
                      ),
                      _StatCell(
                        value: '$boardMemberCount',
                        label: AppLocalizations.of(context)!.membersLabel,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: AppColors.text,
              ),
            ),
            if (name != realName) ...[
              const SizedBox(height: 2),
              Text(
                realName,
                style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
              ),
            ],
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isSuperAdmin
                      ? [const Color(0xFF6A1B9A), const Color(0xFF8E24AA)]
                      : [AppColors.primaryRed, const Color(0xFFE53935)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.all(Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color:
                        (isSuperAdmin
                                ? const Color(0xFF6A1B9A)
                                : AppColors.primaryRed)
                            .withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSuperAdmin
                        ? Icons.admin_panel_settings_rounded
                        : Icons.shield_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isSuperAdmin
                        ? AppLocalizations.of(context)!.superAdmin
                        : AppLocalizations.of(context)!.clubAdmin,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (managedClub != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      '·',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      managedClub.name.split(' ').first,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentProfileHeader({
    required String name,
    required String realName,
    required String userId,
    required int clubCount,
    required List<User> followers,
    required List<User> following,
  }) {
    final major = (userState.majors[userId] ?? '').trim();
    final year = (userState.years[userId] ?? '').trim();
    final bio = (userState.bios[userId] ?? '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Hero banner + avatar overlap ─────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Banner
              Container(
                height: 96,
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF8B1A2B), Color(0xFF6E1422)],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -30,
                      right: -20,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0x0FFFFFFF),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -50,
                      left: 40,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0x0DFFFFFF),
                        ),
                      ),
                    ),
                    if (year.isNotEmpty)
                      Positioned(
                        top: 14,
                        right: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.all(
                              Radius.circular(999),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.school_outlined,
                                size: 13,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                year.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Avatar overlapping banner
              Positioned(
                left: 20,
                bottom: -36,
                child: GestureDetector(
                  onTap: () => _showProfilePhotoOptions(context, userId),
                  child: Container(
                    width: 90,
                    height: 90,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF2DDE0),
                      border: Border.all(color: AppColors.background, width: 4),
                    ),
                    child: UserAvatar(
                      userId: userId,
                      name: name,
                      size: 90,
                      fontSize: 32,
                      backgroundColor: const Color(0xFFF2DDE0),
                      textColor: AppColors.primaryRed,
                    ),
                  ),
                ),
              ),
              // Online dot
              Positioned(
                left: 92,
                bottom: -32,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF3F6B4E),
                    border: Border.all(color: AppColors.background, width: 3),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Name block ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 46, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                  letterSpacing: -0.6,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => _editMajorAndYear(context, userId),
                child: Row(
                  children: [
                    Icon(
                      Icons.school_outlined,
                      size: 14,
                      color: AppColors.primaryRed,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        [
                              if (major.isNotEmpty) major,
                              if (year.isNotEmpty) year,
                            ].join(' · ').isNotEmpty
                            ? [
                                if (major.isNotEmpty) major,
                                if (year.isNotEmpty) year,
                              ].join(' · ')
                            : AppLocalizations.of(context)!.addMajorYear,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.secondaryText,
                          fontStyle: (major.isEmpty && year.isEmpty)
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Bio ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: GestureDetector(
            onTap: () => _editBio(context, userId),
            child: bio.isEmpty
                ? Text(
                    AppLocalizations.of(context)!.addBio,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.secondaryText,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                : Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '“',
                          style: TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 13.5,
                          ),
                        ),
                        TextSpan(
                          text: bio,
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 13.5,
                            height: 1.5,
                          ),
                        ),
                        TextSpan(
                          text: '”',
                          style: TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),

        // ── Stats card ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border.all(color: AppColors.divider),
              borderRadius: BorderRadius.all(Radius.circular(18)),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _StatsBlock(
                      value: '$clubCount',
                      label: AppLocalizations.of(context)!.clubs,
                    ),
                  ),
                  VerticalDivider(width: 1, color: AppColors.divider),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _showFollowersSheet(followers),
                      child: _StatsBlock(
                        value: '${followers.length}',
                        label: AppLocalizations.of(context)!.followers,
                      ),
                    ),
                  ),
                  VerticalDivider(width: 1, color: AppColors.divider),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _showFollowingSheet(following),
                      child: _StatsBlock(
                        value: '${following.length}',
                        label: AppLocalizations.of(context)!.following,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMyClubsSection(List myClubs) {
    final adminId = authService.currentAdmin?.id ?? '';
    final Club? managedClub = managedClubForAdmin(adminId);
    final boardMembers = managedClub != null
        ? users.where((u) => managedClub.boardMemberIds.contains(u.id)).toList()
        : <dynamic>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── My Clubs ──────────────────────────────────────────────────────
        Container(
          color: AppColors.surfaceAlt,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section header
              Row(
                children: [
                  Icon(
                    Icons.groups_2_rounded,
                    size: 18,
                    color: AppColors.primaryRed,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.myClubs,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  if (myClubs.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      child: Text(
                        '${myClubs.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryRed,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              myClubs.isEmpty
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                        border: Border.all(color: AppColors.divider, width: 1),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.explore_outlined,
                            size: 32,
                            color: AppColors.secondaryText,
                          ),
                          SizedBox(height: 8),
                          Text(
                            AppLocalizations.of(context)!.noClubsYet,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            AppLocalizations.of(context)!.exploreClubsHint,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : SizedBox(
                      height: 118,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: myClubs.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (ctx, i) {
                          final club = myClubs[i];
                          final color = _clubColor(i);
                          return GestureDetector(
                            onTap: () => Navigator.push(
                              ctx,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ClubProfileScreen(club: club, color: color),
                              ),
                            ).then((_) => setState(() {})),
                            child: Container(
                              width: 90,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.all(
                                  Radius.circular(16),
                                ),
                                border: Border.all(
                                  color: color.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 8,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ClubAvatar(
                                    clubId: club.id,
                                    clubName: club.name,
                                    color: color,
                                    imageUrl: club.logoUrl,
                                    size: 52,
                                    fontSize: 20,
                                    borderRadius: 14,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    club.name.split(' ').first,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.text,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ],
          ),
        ),

        // ── Board Members (club admin only) ───────────────────────────────
        if (managedClub != null) ...[
          const SizedBox(height: 8),
          Container(
            color: AppColors.surfaceAlt,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                GestureDetector(
                  onTap: () {
                    final idx = clubs.indexOf(managedClub);
                    final color = _clubColor(idx < 0 ? 0 : idx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ClubProfileScreen(club: managedClub, color: color),
                      ),
                    ).then((_) => setState(() {}));
                  },
                  child: Row(
                    children: [
                      Icon(
                        Icons.shield_rounded,
                        size: 18,
                        color: Color(0xFF1565C0),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context)!.boardMembers,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x1A1565C0),
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        child: Text(
                          '${managedClub.boardMemberIds.length}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1565C0),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.secondaryText,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                if (boardMembers.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 16,
                    ),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0x1A1565C0).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      border: Border.all(
                        color: const Color(0x281565C0),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 28,
                          color: Color(0xFF90CAF9),
                        ),
                        SizedBox(height: 6),
                        Text(
                          AppLocalizations.of(context)!.noBoardMembers,
                          style: TextStyle(
                            color: Color(0xFF1565C0),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          AppLocalizations.of(context)!.approvedHere,
                          style: TextStyle(
                            color: Color(0xFF1565C0),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...boardMembers.asMap().entries.map((entry) {
                    final i = entry.key;
                    final u = entry.value;
                    final title = managedClub.boardMemberTitles[u.id];
                    final hasTitle = title != null && title.isNotEmpty;
                    return Column(
                      children: [
                        if (i > 0)
                          Divider(
                            height: 1,
                            indent: 60,
                            color: AppColors.divider,
                          ),
                        InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserProfileScreen(user: u),
                            ),
                          ),
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 4,
                            ),
                            child: Row(
                              children: [
                                UserAvatar(
                                  userId: u.id,
                                  name: u.name,
                                  size: 44,
                                  fontSize: 18,
                                  backgroundColor: const Color(
                                    0xFF1565C0,
                                  ).withValues(alpha: 0.12),
                                  textColor: const Color(0xFF1565C0),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        userState.displayNameFor(u.id, u.name),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.text,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        hasTitle ? title : u.email,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: hasTitle
                                              ? const Color(0xFF1565C0)
                                              : AppColors.secondaryText,
                                          fontWeight: hasTitle
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0x1A1565C0),
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(20),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.shield_rounded,
                                        size: 11,
                                        color: Color(0xFF1565C0),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        AppLocalizations.of(context)!.board,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1565C0),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── My Content section (admin only) ──────────────────────────────────────────

  Widget _buildMyContentSection(String adminId) {
    final managedClub = managedClubForAdmin(adminId);
    if (managedClub == null) return const SizedBox.shrink();

    final clubIdx = clubs.indexOf(managedClub);
    final clubColor = _clubColor(clubIdx < 0 ? 0 : clubIdx);

    final myPosts = newsPosts.where((p) => p.clubId == managedClub.id).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final myEvents = events.where((e) => e.clubId == managedClub.id).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 1, color: AppColors.divider),
        Container(
          color: AppColors.surfaceAlt,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Row(
                  children: [
                    Icon(Icons.grid_view_rounded, size: 18, color: clubColor),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!.myContent,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: clubColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      child: Text(
                        managedClub.name,
                        style: TextStyle(
                          fontSize: 11,
                          color: clubColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Tab chips ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Row(
                  children: [
                    _ContentTabChip(
                      label: AppLocalizations.of(context)!.posts,
                      count: myPosts.length,
                      selected: _contentTab == 0,
                      color: clubColor,
                      onTap: () => setState(() => _contentTab = 0),
                    ),
                    const SizedBox(width: 8),
                    _ContentTabChip(
                      label: AppLocalizations.of(context)!.events,
                      count: myEvents.length,
                      selected: _contentTab == 1,
                      color: clubColor,
                      onTap: () => setState(() => _contentTab = 1),
                    ),
                  ],
                ),
              ),

              // ── Tab content ──
              if (_contentTab == 0)
                _buildPostsList(myPosts, clubColor, adminId),
              if (_contentTab == 1)
                _buildEventsList(myEvents, clubColor, adminId),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  Future<bool?> _confirmDelete(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text),
        ),
        content: Text(
          message,
          style: TextStyle(color: AppColors.secondaryText),
        ),
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
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsList(List myPosts, Color color, String adminId) {
    if (myPosts.isEmpty) {
      return _EmptyHint(text: AppLocalizations.of(context)!.noPostsYet);
    }
    return Column(
      children: myPosts.map((p) {
        return Dismissible(
          key: ValueKey(p.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.red.withValues(alpha: 0.85),
            child: Icon(Icons.delete_outline, color: Colors.white, size: 22),
          ),
          confirmDismiss: (_) => _confirmDelete(
            AppLocalizations.of(context)!.deletePost,
            AppLocalizations.of(context)!.deletePostMsg,
          ),
          onDismissed: (_) {
            final ok = contentStore.deletePost(p.id, adminId);
            if (mounted) {
              if (ok) {
                setState(() {});
              } else {
                Navigator.popUntil(context, (r) => r.isFirst);
              }
            }
          },
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PostDetailScreen(post: p, clubColor: color),
                  ),
                ).then((_) => setState(() {})),
                leading: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: p.imagePath != null && p.imagePath!.startsWith('http')
                      ? AppNetworkImage(
                          url: p.imagePath!,
                          fit: BoxFit.cover,
                          cacheWidth: 52,
                          cacheHeight: 52,
                          placeholderBuilder: (_) => const SkeletonBox(),
                          errorBuilder: (ctx2) => Center(
                            child: Text(
                              clubs
                                  .firstWhere(
                                    (c) => c.id == p.clubId,
                                    orElse: () => clubs.first,
                                  )
                                  .name[0],
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ),
                        )
                      : p.imagePath != null
                      ? Image.file(File(p.imagePath!), fit: BoxFit.cover)
                      : Center(
                          child: Text(
                            clubs
                                .firstWhere(
                                  (c) => c.id == p.clubId,
                                  orElse: () => clubs.first,
                                )
                                .name[0],
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ),
                ),
                title: Text(
                  p.content.length > 80
                      ? '${p.content.substring(0, 80)}…'
                      : p.content,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.text,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  _timeAgoLabel(p.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.secondaryText,
                  ),
                ),
                trailing: Icon(
                  Icons.swipe_left_outlined,
                  size: 16,
                  color: AppColors.secondaryText,
                ),
              ),
              Divider(height: 1, indent: 84, color: AppColors.divider),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEventsList(List myEvents, Color color, String adminId) {
    if (myEvents.isEmpty) {
      return _EmptyHint(text: AppLocalizations.of(context)!.noEventsYet);
    }
    return Column(
      children: myEvents.map((e) {
        final now = DateTime.now();
        final isLive = e.dateTime.isBefore(now) && e.endTime.isAfter(now);
        final isPast = e.endTime.isBefore(now);
        final diff = e.dateTime.difference(now);

        String statusLabel;
        Color statusColor;
        if (isLive) {
          statusLabel = AppLocalizations.of(context)!.live;
          statusColor = Colors.green;
        } else if (isPast) {
          statusLabel = AppLocalizations.of(context)!.ended;
          statusColor = AppColors.secondaryText;
        } else if (diff.inDays == 0) {
          statusLabel = AppLocalizations.of(context)!.today;
          statusColor = Colors.orange;
        } else if (diff.inDays == 1) {
          statusLabel = AppLocalizations.of(context)!.tomorrow;
          statusColor = color;
        } else {
          statusLabel = AppLocalizations.of(context)!.eventInDays(diff.inDays);
          statusColor = color;
        }

        return Dismissible(
          key: ValueKey(e.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.red.withValues(alpha: 0.85),
            child: Icon(Icons.delete_outline, color: Colors.white, size: 22),
          ),
          confirmDismiss: (_) => _confirmDelete(
            AppLocalizations.of(context)!.deleteEvent,
            AppLocalizations.of(context)!.deleteEventMsg,
          ),
          onDismissed: (_) {
            final ok = contentStore.deleteEvent(e.id, adminId);
            if (mounted) {
              if (ok) {
                setState(() {});
              } else {
                Navigator.popUntil(context, (r) => r.isFirst);
              }
            }
          },
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EventDetailScreen(event: e, color: color),
                  ),
                ).then((_) => setState(() {})),
                leading: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${e.dateTime.day}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        _monthAbbr(e.dateTime.month),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
                title: Text(
                  e.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  e.location,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.secondaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.swipe_left_outlined,
                      size: 14,
                      color: AppColors.secondaryText,
                    ),
                  ],
                ),
              ),
              if (canViewEventAttendance(e))
                Padding(
                  padding: const EdgeInsets.only(
                    left: 84,
                    right: 16,
                    bottom: 8,
                  ),
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RsvpListScreen(event: e, color: color),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.people_outline, size: 14, color: color),
                        const SizedBox(width: 4),
                        Text(
                          AppLocalizations.of(
                            context,
                          )!.attendingViewRsvps(e.attendeeUserIds.length),
                          style: TextStyle(
                            fontSize: 12,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.chevron_right, size: 14, color: color),
                      ],
                    ),
                  ),
                ),
              Divider(height: 1, indent: 84, color: AppColors.divider),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _timeAgoLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.isNegative) {
      final ahead = dt.difference(DateTime.now());
      if (ahead.inDays > 0) {
        return AppLocalizations.of(context)!.timeAgoInDays(ahead.inDays);
      }
      if (ahead.inHours > 0) {
        return AppLocalizations.of(context)!.timeAgoInHours(ahead.inHours);
      }
      return AppLocalizations.of(context)!.timeAgoSoon;
    }
    if (diff.inSeconds < 60) {
      return AppLocalizations.of(context)!.timeAgoJustNow;
    }
    if (diff.inMinutes < 60) {
      return AppLocalizations.of(context)!.timeAgoMinutes(diff.inMinutes);
    }
    if (diff.inHours < 24) {
      return AppLocalizations.of(context)!.timeAgoHours(diff.inHours);
    }
    if (diff.inDays < 7) {
      return AppLocalizations.of(context)!.timeAgoDays(diff.inDays);
    }
    return '${DateFormat.MMM(localeService.languageCode).format(dt)} ${dt.day}';
  }

  String _monthAbbr(int m) =>
      DateFormat.MMM(localeService.languageCode).format(DateTime(2024, m));
}

class _ContentTabChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ContentTabChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : AppColors.card,
          borderRadius: BorderRadius.all(Radius.circular(20)),
          border: Border.all(color: selected ? color : AppColors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.secondaryText,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.25)
                    : AppColors.lightRed,
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : AppColors.secondaryText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Center(
        child: Text(
          text,
          style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  const _StatCell({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
        ),
      ],
    );
  }
}

class _StatsBlock extends StatelessWidget {
  final String value;
  final String label;
  const _StatsBlock({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryRed,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}
