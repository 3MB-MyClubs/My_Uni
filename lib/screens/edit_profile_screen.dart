import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../services/app_colors.dart';
import '../services/personalization_service.dart'
    show kAcademicPrograms, kInterests;
import '../services/student_profile_service.dart';
import '../services/user_prefs_service.dart';
import '../services/user_state.dart';
import '../widgets/academic_program_picker.dart';
import '../widgets/user_avatar.dart';

/// Full-page profile editor: name, photo, bio, university year, major,
/// double major(s), minor(s) and interests — all in one place.
class EditProfileScreen extends StatefulWidget {
  final String userId;
  final String realName;

  const EditProfileScreen({
    super.key,
    required this.userId,
    required this.realName,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const List<String> _fallbackYearOptions = [
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
    '5th Year',
    'Graduate',
  ];

  late final TextEditingController _bioCtrl;

  String? _year;
  String? _major;
  late Set<String> _interests;
  String? _doubleMajor;
  String? _minor;
  List<ProfileLookupItem> _majors = const [];
  List<ProfileLookupItem> _academicYears = const [];
  List<ProfileLookupItem> _interestOptions = const [];
  bool _isLoadingRemote = true;
  bool _isSaving = false;
  String? _loadError;

  String get _userId => widget.userId;
  List<String> get _majorNames =>
      _majors.isEmpty ? kAcademicPrograms : _majors.map((m) => m.name).toList();
  List<String> get _yearOptions => _academicYears.isEmpty
      ? _fallbackYearOptions
      : _academicYears.map((year) => year.name).toList();
  List<String> get _interestNames => _interestOptions.isEmpty
      ? kInterests
      : _interestOptions.map((interest) => interest.name).toList();

  @override
  void initState() {
    super.initState();
    _bioCtrl = TextEditingController(text: userState.bios[_userId] ?? '');
    final savedMajor = userState.majors[_userId];
    _major = kAcademicPrograms.contains(savedMajor) ? savedMajor : null;
    final y = userState.years[_userId];
    _year = (y != null && y.isNotEmpty) ? y : null;
    _interests = {...?userState.interests[_userId]};
    _doubleMajor = userState.doubleMajors[_userId]?.firstOrNull;
    _minor = userState.minors[_userId]?.firstOrNull;
    _loadRemoteData();
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    super.dispose();
  }

  // ── Save ────────────────────────────────────────────────────────────────────
  Future<void> _loadRemoteData() async {
    try {
      final results = await Future.wait([
        studentProfileService.fetchMajors(),
        studentProfileService.fetchAcademicYears(),
        studentProfileService.fetchInterests(),
        studentProfileService.fetchProfile(_userId),
      ]);
      if (!mounted) return;

      final profile = results[3] as StudentProfileData?;
      setState(() {
        _majors = results[0] as List<ProfileLookupItem>;
        _academicYears = results[1] as List<ProfileLookupItem>;
        _interestOptions = results[2] as List<ProfileLookupItem>;
        if (profile != null) {
          _bioCtrl.text = profile.bio ?? '';
          _major = profile.majorName;
          _year = profile.academicYearName;
          _interests = profile.interestNames.toSet();
          _doubleMajor = profile.doubleMajorNames.firstOrNull;
          _minor = profile.minorNames.firstOrNull;
        }
        _isLoadingRemote = false;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingRemote = false;
        _loadError = 'Could not load profile options from Supabase.';
      });
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      if (_majors.isNotEmpty || _academicYears.isNotEmpty) {
        await studentProfileService.updateProfile(
          UpdateStudentProfileInput(
            userId: _userId,
            fullName: widget.realName,
            bio: _bioCtrl.text,
            majorId: _idForName(_majors, _major),
            academicYearId: _idForName(_academicYears, _year),
            interestIds: _idsForNames(_interestOptions, _interests),
            doubleMajorIds: _idsForNames(_majors, _oneOrEmpty(_doubleMajor)),
            minorIds: _idsForNames(_majors, _oneOrEmpty(_minor)),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not save profile to Supabase'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    userState.setBio(_userId, _bioCtrl.text);
    userState.setMajor(_userId, _major ?? '');
    userState.setYear(_userId, _year ?? '');
    userState.setInterests(_userId, _interests.toList());
    userState.setDoubleMajors(
      _userId,
      _doubleMajor == null ? const [] : [_doubleMajor!],
    );
    userState.setMinors(_userId, _minor == null ? const [] : [_minor!]);
    await userPrefsService.save(_userId);
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Profile updated'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    Navigator.pop(context);
  }

  String? _idForName(List<ProfileLookupItem> items, String? name) {
    if (name == null || name.trim().isEmpty) return null;
    for (final item in items) {
      if (item.name == name) return item.id;
    }
    return null;
  }

  List<String> _idsForNames(
    List<ProfileLookupItem> items,
    Iterable<String> names,
  ) {
    final selected = names.toSet();
    return items
        .where((item) => selected.contains(item.name))
        .map((item) => item.id)
        .toList();
  }

  List<String> _oneOrEmpty(String? value) =>
      value == null || value.trim().isEmpty ? const [] : [value.trim()];

  // ── Photo ─────────────────────────────────────────────────────────────────
  void _showPhotoOptions() {
    final hasPhoto = userState.hasProfilePhoto(_userId);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              _photoOption(Icons.camera_alt_outlined, 'Take a photo', () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.camera);
              }),
              Divider(height: 1, indent: 16, color: AppColors.divider),
              _photoOption(
                Icons.photo_library_outlined,
                'Choose from library',
                () {
                  Navigator.pop(context);
                  _pickPhoto(ImageSource.gallery);
                },
              ),
              if (hasPhoto) ...[
                Divider(height: 1, indent: 16, color: AppColors.divider),
                _photoOption(
                  Icons.delete_outline_rounded,
                  'Remove photo',
                  () async {
                    Navigator.pop(context);
                    await _removePhoto();
                  },
                  danger: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoOption(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool danger = false,
  }) {
    final color = danger ? Colors.red.shade400 : AppColors.primaryRed;
    return ListTile(
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: danger ? color : AppColors.text,
        ),
      ),
      onTap: onTap,
    );
  }

  Future<void> _removePhoto() async {
    userState.removeProfilePhoto(_userId);
    await userPrefsService.save(_userId);
    try {
      await studentProfileService.removeAvatar(_userId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Photo removed locally, but remote delete failed.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
    if (mounted) setState(() {});
  }

  Future<void> _pickPhoto(ImageSource source) async {
    CroppedFile? cropped;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 72,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked == null || !mounted) return;

      cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        maxWidth: 512,
        maxHeight: 512,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 72,
        uiSettings: [
          IOSUiSettings(
            title: 'Crop Photo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: true,
            aspectRatioPickerButtonHidden: true,
            cropStyle: CropStyle.circle,
          ),
          AndroidUiSettings(
            toolbarTitle: 'Crop Photo',
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
          const SnackBar(
            content: Text('Could not open photo cropper.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    if (cropped == null || !mounted) return;

    final docsDir = await getApplicationDocumentsDirectory();
    final ext = cropped.path.contains('.')
        ? cropped.path.substring(cropped.path.lastIndexOf('.'))
        : '.jpg';
    final permanentPath = '${docsDir.path}/profile_$_userId$ext';
    await File(cropped.path).copy(permanentPath);
    if (!mounted) return;
    userState.setProfilePhoto(_userId, permanentPath);
    userPrefsService.save(_userId);
    try {
      await studentProfileService.uploadAvatar(
        userId: _userId,
        bytes: await File(permanentPath).readAsBytes(),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Photo saved locally, but upload failed.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
    setState(() {});
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: Text(
              _isSaving ? 'Saving...' : 'Save',
              style: TextStyle(
                color: AppColors.primaryRed,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          if (_isLoadingRemote) ...[
            LinearProgressIndicator(
              color: AppColors.primaryRed,
              backgroundColor: AppColors.lightRed,
              minHeight: 2,
            ),
            const SizedBox(height: 16),
          ] else if (_loadError != null) ...[
            Text(
              _loadError!,
              style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
            ),
            const SizedBox(height: 16),
          ],
          // Photo
          Center(
            child: GestureDetector(
              onTap: _showPhotoOptions,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  UserAvatar(
                    userId: _userId,
                    name: widget.realName,
                    size: 100,
                    fontSize: 38,
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.background,
                          width: 3,
                        ),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _showPhotoOptions,
              child: Text(
                'Change photo',
                style: TextStyle(
                  color: AppColors.primaryRed,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          _label('Bio'),
          _field(
            controller: _bioCtrl,
            hint: 'Tell people a little about yourself',
            maxLength: 80,
            maxLines: 3,
          ),
          const SizedBox(height: 18),

          _label('University year'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _yearOptions.map((y) {
              final on = _year == y;
              return _choiceChip(y, on, () {
                setState(() => _year = on ? null : y);
              });
            }).toList(),
          ),
          const SizedBox(height: 18),

          _label('Major'),
          AcademicProgramField(
            value: _major,
            hint: 'Select your major',
            onTap: () async {
              final result = await showAcademicProgramPicker(
                context: context,
                title: 'Select major',
                selected: _major == null ? const [] : [_major!],
                programs: _majorNames,
              );
              if (result == null || !mounted) return;
              setState(() => _major = result.firstOrNull);
            },
          ),
          const SizedBox(height: 18),

          _label('Double major'),
          _singleProgramEditor(
            value: _doubleMajor,
            hint: 'Select a double major',
            onChanged: (value) => setState(() => _doubleMajor = value),
          ),
          const SizedBox(height: 18),

          _label('Minor'),
          _singleProgramEditor(
            value: _minor,
            hint: 'Select a minor',
            onChanged: (value) => setState(() => _minor = value),
          ),
          const SizedBox(height: 18),

          _label('Interests'),
          Wrap(
            spacing: 9,
            runSpacing: 10,
            children:
                <String>[
                  ..._interestNames,
                  ..._interests.where((i) => !_interestNames.contains(i)),
                ].map((topic) {
                  final on = _interests.contains(topic);
                  return _choiceChip(topic, on, () {
                    setState(() {
                      if (on) {
                        _interests.remove(topic);
                      } else {
                        _interests.add(topic);
                      }
                    });
                  });
                }).toList(),
          ),
          const SizedBox(height: 28),

          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                _isSaving ? 'Saving...' : 'Save changes',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Reusable pieces ─────────────────────────────────────────────────────────
  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
        color: AppColors.secondaryText,
      ),
    ),
  );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    int? maxLength,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      onChanged: onChanged,
      style: TextStyle(color: AppColors.text, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.secondaryText),
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primaryRed, width: 1.5),
        ),
      ),
    );
  }

  Widget _choiceChip(String label, bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: on ? AppColors.primaryRed : AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: on ? AppColors.primaryRed : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: on ? Colors.white : AppColors.text,
          ),
        ),
      ),
    );
  }

  Widget _singleProgramEditor({
    required String? value,
    required String hint,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AcademicProgramField(
          value: value,
          hint: hint,
          onTap: () async {
            final result = await showAcademicProgramPicker(
              context: context,
              title: hint,
              selected: value == null ? const [] : [value],
              programs: _majorNames,
            );
            if (result == null || !mounted) return;
            onChanged(result.firstOrNull);
          },
        ),
        if (value != null && value.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => onChanged(null),
              icon: Icon(
                Icons.close_rounded,
                size: 16,
                color: AppColors.secondaryText,
              ),
              label: Text(
                'Clear',
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
