import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../services/app_colors.dart';
import '../services/personalization_service.dart' show kInterests, kFaculties;
import '../services/user_prefs_service.dart';
import '../services/user_state.dart';
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
  static const List<String> _yearOptions = [
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
    '5th Year',
    'Graduate',
  ];

  late final TextEditingController _nameCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _majorCtrl;
  final _doubleMajorCtrl = TextEditingController();
  final _minorCtrl = TextEditingController();

  String? _year;
  late Set<String> _interests;
  late List<String> _doubleMajors;
  late List<String> _minors;

  String get _userId => widget.userId;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: userState.usernameFor(_userId) ?? widget.realName,
    );
    _bioCtrl = TextEditingController(text: userState.bios[_userId] ?? '');
    _majorCtrl = TextEditingController(text: userState.majors[_userId] ?? '');
    final y = userState.years[_userId];
    _year = (y != null && y.isNotEmpty) ? y : null;
    _interests = {...?userState.interests[_userId]};
    _doubleMajors = [...?userState.doubleMajors[_userId]];
    _minors = [...?userState.minors[_userId]];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _majorCtrl.dispose();
    _doubleMajorCtrl.dispose();
    _minorCtrl.dispose();
    super.dispose();
  }

  // ── Save ────────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    // Treat the name field as the display name (username). Clearing it or
    // matching the real account name reverts to the real name.
    if (name.isEmpty || name == widget.realName) {
      userState.clearUsername(_userId);
    } else {
      userState.setUsername(_userId, name);
    }
    userState.setBio(_userId, _bioCtrl.text);
    userState.setMajor(_userId, _majorCtrl.text);
    userState.setYear(_userId, _year ?? '');
    userState.setInterests(_userId, _interests.toList());
    userState.setDoubleMajors(_userId, _doubleMajors);
    userState.setMinors(_userId, _minors);
    await userPrefsService.save(_userId);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Profile updated'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ));
    Navigator.pop(context);
  }

  // ── Photo ─────────────────────────────────────────────────────────────────
  void _showPhotoOptions() {
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
              _photoOption(Icons.photo_library_outlined, 'Choose from library',
                  () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.gallery);
              }),
              if (userState.profilePhotoPaths[_userId] != null) ...[
                Divider(height: 1, indent: 16, color: AppColors.divider),
                _photoOption(Icons.delete_outline_rounded, 'Remove photo', () {
                  Navigator.pop(context);
                  userState.removeProfilePhoto(_userId);
                  userPrefsService.save(_userId);
                  setState(() {});
                }, danger: true),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoOption(IconData icon, String label, VoidCallback onTap,
      {bool danger = false}) {
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
      title: Text(label,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              color: danger ? color : AppColors.text)),
      onTap: onTap,
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
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
          resetAspectRatioEnabled: false,
        ),
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo',
          toolbarColor: AppColors.primaryRed,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: true,
        ),
      ],
    );
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
    setState(() {});
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final name = _nameCtrl.text.trim().isEmpty
        ? widget.realName
        : _nameCtrl.text.trim();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: Text('Edit Profile',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('Save',
                style: TextStyle(
                    color: AppColors.primaryRed,
                    fontWeight: FontWeight.w800,
                    fontSize: 15)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // Photo
          Center(
            child: GestureDetector(
              onTap: _showPhotoOptions,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  UserAvatar(userId: _userId, name: name, size: 100, fontSize: 38),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.background, width: 3),
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          size: 16, color: Colors.white),
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
              child: Text('Change photo',
                  style: TextStyle(
                      color: AppColors.primaryRed, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 8),

          _label('Display name'),
          _field(
            controller: _nameCtrl,
            hint: 'How your name appears',
            maxLength: 40,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 18),

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
          _field(
            controller: _majorCtrl,
            hint: 'e.g. Computer Science',
            maxLength: 48,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final f in kFaculties)
                if ((f['name'] as String) != 'Undecided')
                  _suggestionChip(f['name'] as String, () {
                    setState(() => _majorCtrl.text = f['name'] as String);
                  }),
            ],
          ),
          const SizedBox(height: 18),

          _label('Double major'),
          _listEditor(
            controller: _doubleMajorCtrl,
            items: _doubleMajors,
            hint: 'Add a double major program',
          ),
          const SizedBox(height: 18),

          _label('Minor'),
          _listEditor(
            controller: _minorCtrl,
            items: _minors,
            hint: 'Add a minor program',
          ),
          const SizedBox(height: 18),

          _label('Interests'),
          Wrap(
            spacing: 9,
            runSpacing: 10,
            children: <String>[
              ...kInterests,
              ..._interests.where((i) => !kInterests.contains(i)),
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
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Save changes',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Reusable pieces ─────────────────────────────────────────────────────────
  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(text,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                color: AppColors.secondaryText)),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              color: on ? AppColors.primaryRed : AppColors.divider),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: on ? Colors.white : AppColors.text)),
      ),
    );
  }

  Widget _suggestionChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 13, color: AppColors.secondaryText),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryText)),
          ],
        ),
      ),
    );
  }

  /// Text field + "Add" button, with the added entries shown as removable chips.
  Widget _listEditor({
    required TextEditingController controller,
    required List<String> items,
    required String hint,
  }) {
    void add() {
      final v = controller.text.trim();
      if (v.isEmpty) return;
      if (!items.contains(v)) setState(() => items.add(v));
      controller.clear();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _field(
                controller: controller,
                hint: hint,
                maxLength: 48,
                onChanged: null,
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: add,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primaryRed,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map((item) => Container(
                      padding:
                          const EdgeInsets.only(left: 14, right: 6, top: 7, bottom: 7),
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: AppColors.primaryRed.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(item,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryRed)),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => setState(() => items.remove(item)),
                            child: Icon(Icons.close_rounded,
                                size: 16, color: AppColors.primaryRed),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}
