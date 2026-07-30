import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/academic_year_options.dart';
import '../../services/photo_upload_quality.dart';
import '../../l10n/app_localizations.dart';
import '../../services/signup_service.dart';
import '../../widgets/app_network_image.dart';
import '../../widgets/loading_skeleton.dart';
import '../widgets/terms_content.dart';
import 'signup_theme.dart';

typedef SignupImagePicker = Future<XFile?> Function(ImageSource source);
typedef SignupImageCropper = Future<CroppedFile?> Function(String sourcePath);

class StepProfile extends StatefulWidget {
  final String initialName;
  final String initialMajor;
  final String initialYear;
  final Future<List<SignupLookupItem>> Function() loadMajors;
  final Future<List<SignupLookupItem>> Function() loadAcademicYears;
  final Future<String?> Function(
    String name,
    String majorId,
    String majorName,
    String academicYearId,
    String academicYearName,
    String? imagePath,
  )
  onNext;
  final SignupImagePicker? imagePickerOverride;
  final SignupImageCropper? imageCropperOverride;

  const StepProfile({
    super.key,
    this.initialName = '',
    this.initialMajor = '',
    this.initialYear = '',
    required this.loadMajors,
    required this.loadAcademicYears,
    required this.onNext,
    @visibleForTesting this.imagePickerOverride,
    @visibleForTesting this.imageCropperOverride,
  });

  @override
  State<StepProfile> createState() => _StepProfileState();
}

class _StepProfileState extends State<StepProfile> {
  late final TextEditingController _nameController;
  late final TextEditingController _majorController;
  String? _nameError;
  String? _majorError;
  String? _yearError;
  String _selectedMajorId = '';
  String _selectedYearId = '';
  String _selectedYearName = '';
  String? _imagePath;
  bool _isPickingPhoto = false;
  bool _isLoadingLookups = true;
  String? _lookupError;
  bool _agreedToTerms = false;
  bool _isSubmitting = false;
  String? _submitError;

  List<SignupLookupItem> _majors = const [];
  List<SignupLookupItem> _years = const [];
  List<SignupLookupItem> _suggestions = [];
  bool _showSuggestions = false;
  final FocusNode _majorFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _majorController = TextEditingController(text: widget.initialMajor);
    _selectedYearName = widget.initialYear;

    _majorFocus.addListener(() {
      if (!_majorFocus.hasFocus) {
        setState(() => _showSuggestions = false);
      }
    });

    _loadLookups();
  }

  Future<void> _loadLookups() async {
    try {
      final results = await Future.wait([
        widget.loadMajors(),
        widget.loadAcademicYears(),
      ]);
      if (!mounted) return;
      final majors = results[0];
      final years = results[1];
      final initialMajor = widget.initialMajor;
      final initialYear = widget.initialYear;
      final matchedMajor = _firstByName(majors, initialMajor);
      final matchedYear = _firstByName(years, initialYear);

      setState(() {
        _majors = majors;
        _years = years;
        _selectedMajorId = matchedMajor?.id ?? '';
        _selectedYearId = matchedYear?.id ?? '';
        _selectedYearName = matchedYear?.name ?? initialYear;
        _isLoadingLookups = false;
        if (majors.isEmpty || years.isEmpty) {
          _lookupError = AppLocalizations.of(
            context,
          )!.couldNotLoadProfileOptionsRetry;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingLookups = false;
        _lookupError = AppLocalizations.of(
          context,
        )!.couldNotLoadProfileOptionsRetry;
      });
    }
  }

  SignupLookupItem? _firstByName(List<SignupLookupItem> items, String name) {
    for (final item in items) {
      if (item.name == name) return item;
    }
    return null;
  }

  // ── Major autocomplete ─────────────────────────────────────────
  void _onMajorChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        // Capped so focusing the empty field doesn't lay out the entire
        // major catalog inside the shrinkWrap suggestion list below.
        _suggestions = _majors.take(20).toList();
        _showSuggestions = true;
      });
      return;
    }
    final q = query.toLowerCase();
    final scored =
        _majors
            .map((m) {
              final ml = m.name.toLowerCase();
              int score = 0;
              if (ml.startsWith(q)) {
                score = 3;
              } else if (ml.split(' ').any((w) => w.startsWith(q))) {
                score = 2;
              } else if (ml.contains(q)) {
                score = 1;
              }
              return MapEntry(m, score);
            })
            .where((e) => e.value > 0)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    setState(() {
      _suggestions = scored.map((e) => e.key).toList();
      _showSuggestions = _suggestions.isNotEmpty;
      _selectedMajorId = '';
    });
  }

  void _selectMajor(SignupLookupItem major) {
    _majorController.text = major.name;
    setState(() {
      _selectedMajorId = major.id;
      _showSuggestions = false;
      _majorError = null;
    });
    _majorFocus.unfocus();
  }

  void _showPhotoOptions() {
    final hasPhoto = _imagePath != null;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: SC.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        child: SafeArea(
          top: false,
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: SC.hair,
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                _photoOption(
                  Icons.camera_alt_outlined,
                  AppLocalizations.of(context)!.takePhoto,
                  () => _pickPhotoAfterSheetCloses(
                    sheetContext,
                    ImageSource.camera,
                  ),
                  key: const ValueKey('signup-photo-camera'),
                ),
                Divider(height: 1, indent: 16, color: SC.hair),
                _photoOption(
                  Icons.photo_library_outlined,
                  AppLocalizations.of(context)!.chooseFromLib,
                  () => _pickPhotoAfterSheetCloses(
                    sheetContext,
                    ImageSource.gallery,
                  ),
                  key: const ValueKey('signup-photo-library'),
                ),
                if (hasPhoto) ...[
                  Divider(height: 1, indent: 16, color: SC.hair),
                  _photoOption(
                    Icons.delete_outline_rounded,
                    AppLocalizations.of(context)!.removePhoto,
                    () {
                      Navigator.pop(context);
                      setState(() => _imagePath = null);
                    },
                    danger: true,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _photoOption(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Key? key,
    bool danger = false,
  }) {
    final color = danger ? Colors.red.shade400 : SC.burgundy;
    return ListTile(
      key: key,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: danger ? color : SC.ink,
        ),
      ),
      onTap: onTap,
    );
  }

  Future<void> _pickPhotoAfterSheetCloses(
    BuildContext sheetContext,
    ImageSource source,
  ) async {
    Navigator.of(sheetContext).pop();
    // Native camera controllers are sensitive to being presented while the
    // modal sheet is still animating out, especially on iOS.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    await _pickPhoto(source);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_isPickingPhoto) return;
    final cropPhotoTitle = AppLocalizations.of(context)!.cropPhoto;
    setState(() => _isPickingPhoto = true);

    try {
      final picked = widget.imagePickerOverride != null
          ? await widget.imagePickerOverride!(source)
          : await ImagePicker().pickImage(
              source: source,
              maxWidth: PhotoUploadQuality.avatarMaxDimension.toDouble(),
              maxHeight: PhotoUploadQuality.avatarMaxDimension.toDouble(),
              imageQuality: PhotoUploadQuality.jpegQuality,
              preferredCameraDevice: CameraDevice.front,
            );
      if (picked == null || !mounted) return;

      if (source == ImageSource.camera) {
        // On iOS the picker Future can resolve before the native camera has
        // completely dismissed. Opening the cropper in that window fails or
        // lets the "Use Photo" tap hit Continue underneath.
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
      }

      final cropped = widget.imageCropperOverride != null
          ? await widget.imageCropperOverride!(picked.path)
          : await ImageCropper().cropImage(
              sourcePath: picked.path,
              aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
              maxWidth: PhotoUploadQuality.avatarMaxDimension,
              maxHeight: PhotoUploadQuality.avatarMaxDimension,
              compressFormat: ImageCompressFormat.jpg,
              compressQuality: PhotoUploadQuality.jpegQuality,
              uiSettings: [
                IOSUiSettings(
                  title: cropPhotoTitle,
                  aspectRatioLockEnabled: true,
                  resetAspectRatioEnabled: true,
                  aspectRatioPickerButtonHidden: true,
                  cropStyle: CropStyle.circle,
                ),
                AndroidUiSettings(
                  toolbarTitle: cropPhotoTitle,
                  toolbarColor: SC.burgundy,
                  toolbarWidgetColor: Colors.white,
                  lockAspectRatio: true,
                  hideBottomControls: false,
                  cropStyle: CropStyle.circle,
                ),
              ],
            );
      if (cropped == null || !mounted) return;
      setState(() => _imagePath = cropped.path);
    } catch (_) {
      _showPhotoError(source);
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  void _showPhotoError(ImageSource source) {
    if (!mounted) return;
    final message = source == ImageSource.camera
        ? AppLocalizations.of(context)!.couldNotUseCamera
        : AppLocalizations.of(context)!.couldNotOpenPhotoCropper;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  // ── Initials from name ─────────────────────────────────────────
  String get _initials {
    final parts = _nameController.text
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  /// Presents the full Community Safety Terms in an in-app bottom sheet
  /// (rather than handing off to the external browser) so the student can
  /// review them without leaving the sign-up flow.
  void _showTermsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SC.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: SC.hair,
                  borderRadius: const BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
                child: const TermsContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Submit ─────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_isSubmitting) return;
    final name = _nameController.text.trim();
    final major = _majorController.text.trim();
    bool hasError = false;

    if (_isLoadingLookups || _lookupError != null) {
      setState(
        () => _lookupError = AppLocalizations.of(
          context,
        )!.couldNotLoadProfileOptionsRetry,
      );
      return;
    }

    final nameParts = name.split(RegExp(r'\s+')).where((part) {
      return part.isNotEmpty;
    }).toList();

    if (name.isEmpty) {
      setState(
        () => _nameError = AppLocalizations.of(context)!.pleaseEnterFullName,
      );
      hasError = true;
    } else if (nameParts.length < 2) {
      setState(
        () =>
            _nameError = AppLocalizations.of(context)!.pleaseEnterFirstLastName,
      );
      hasError = true;
    } else {
      setState(() => _nameError = null);
    }

    if (major.isEmpty) {
      setState(
        () => _majorError = AppLocalizations.of(context)!.pleaseSelectMajor,
      );
      hasError = true;
    } else if (_selectedMajorId.isEmpty) {
      setState(
        () =>
            _majorError = AppLocalizations.of(context)!.pleasePickMajorFromList,
      );
      hasError = true;
    } else {
      setState(() => _majorError = null);
    }

    if (_selectedYearId.isEmpty) {
      setState(
        () => _yearError = AppLocalizations.of(context)!.pleaseSelectYear,
      );
      hasError = true;
    } else {
      setState(() => _yearError = null);
    }

    if (hasError) return;

    setState(() {
      _submitError = null;
      _isSubmitting = true;
    });
    final error = await widget.onNext(
      name,
      _selectedMajorId,
      major,
      _selectedYearId,
      _selectedYearName,
      _imagePath,
    );
    if (!mounted) return;
    setState(() {
      _submitError = error;
      _isSubmitting = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _majorController.dispose();
    _majorFocus.dispose();
    super.dispose();
  }

  Widget _selectedAvatarImage(String path) {
    if (kIsWeb) {
      return AppNetworkImage(
        url: path,
        width: 92,
        height: 92,
        fit: BoxFit.cover,
        placeholderBuilder: (_) => const SkeletonBox.circle(size: 92),
        errorBuilder: (_) => Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            color: SC.burgundyTint,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.person_outline_rounded,
            color: SC.burgundy,
            size: 32,
          ),
        ),
      );
    }
    return Image.file(File(path), width: 92, height: 92, fit: BoxFit.cover);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Scrollable content ──────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.tellUsAboutYouTitle,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: SC.ink,
                    height: 1.1,
                    letterSpacing: -0.9,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  AppLocalizations.of(context)!.showsOnCampusProfile,
                  style: TextStyle(
                    fontSize: 15,
                    color: SC.body,
                    height: 1.45,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 24),
                if (_lookupError != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: SC.burgundyTint,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    child: Text(
                      _lookupError!,
                      style: TextStyle(color: SC.burgundyDeep, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // ── Avatar ─────────────────────────────────────
                Center(
                  child: GestureDetector(
                    key: const ValueKey('signup-profile-photo'),
                    onTap: _showPhotoOptions,
                    child: AnimatedBuilder(
                      animation: _nameController,
                      builder: (_, _) => Stack(
                        children: [
                          _imagePath != null
                              ? ClipOval(
                                  child: _selectedAvatarImage(_imagePath!),
                                )
                              : _DashedCircleAvatar(initials: _initials),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: SC.ink,
                                border: Border.all(color: SC.bg, width: 3),
                              ),
                              child: Icon(
                                _imagePath != null ? Icons.edit : Icons.add,
                                color: Colors.white,
                                size: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Full name
                TextField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(
                    color: SC.ink,
                    fontSize: 16,
                    letterSpacing: -0.1,
                  ),
                  decoration: SC.fieldDecoration(
                    label: AppLocalizations.of(context)!.fullNameLabel,
                    hint: AppLocalizations.of(context)!.fullNameExampleHint,
                    errorText: _nameError,
                  ),
                ),
                const SizedBox(height: 14),

                // Major autocomplete
                _MajorField(
                  controller: _majorController,
                  focusNode: _majorFocus,
                  suggestions: _suggestions,
                  showSuggestions: _showSuggestions,
                  isLoading: _isLoadingLookups,
                  errorText: _majorError,
                  onChanged: _onMajorChanged,
                  onSelect: _selectMajor,
                  onTap: _isLoadingLookups
                      ? null
                      : () => _onMajorChanged(_majorController.text),
                ),
                const SizedBox(height: 14),

                // Year
                _YearSelector(
                  years: _years,
                  selectedId: _selectedYearId,
                  isLoading: _isLoadingLookups,
                  errorText: _yearError,
                  onSelect: (y) => setState(() {
                    _selectedYearId = y.id;
                    _selectedYearName = y.name;
                    _yearError = null;
                  }),
                ),
              ],
            ),
          ),
        ),

        // ── Terms acceptance + Continue — pinned to bottom ──────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_submitError != null) ...[
                Text(
                  _submitError!,
                  style: TextStyle(color: SC.burgundy, fontSize: 13),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Checkbox(
                    value: _agreedToTerms,
                    activeColor: SC.burgundy,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (value) =>
                        setState(() => _agreedToTerms = value ?? false),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.agreeToSafetyTerms,
                          style: TextStyle(
                            fontSize: 13,
                            color: SC.body,
                            height: 1.35,
                          ),
                        ),
                        GestureDetector(
                          onTap: _showTermsSheet,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              AppLocalizations.of(context)!.readFullTerms,
                              style: TextStyle(
                                fontSize: 13,
                                color: SC.burgundy,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                                decoration: TextDecoration.underline,
                                decorationColor: SC.burgundy,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  key: const ValueKey('signup-profile-continue'),
                  onPressed:
                      _isLoadingLookups ||
                          _isPickingPhoto ||
                          _isSubmitting ||
                          !_agreedToTerms
                      ? null
                      : _submit,
                  style: SC.primaryButtonStyle(),
                  child: _isLoadingLookups || _isPickingPhoto || _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(AppLocalizations.of(context)!.continueButton),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Dashed circle avatar ──────────────────────────────────────────────────────
class _DashedCircleAvatar extends StatelessWidget {
  final String initials;
  const _DashedCircleAvatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedCirclePainter(),
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: SC.burgundyTint,
        ),
        alignment: Alignment.center,
        child: initials.isEmpty
            ? Icon(Icons.person_outline_rounded, color: SC.burgundy, size: 32)
            : Text(
                initials,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  color: SC.burgundy,
                  letterSpacing: -0.5,
                ),
              ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SC.burgundy
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const center = Offset(46, 46);
    const radius = 44.0;
    const dashCount = 24;
    const dashArc = (2 * 3.14159265) / (dashCount * 2);

    for (int i = 0; i < dashCount; i++) {
      final start = i * dashArc * 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        dashArc,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Year chip selector ────────────────────────────────────────────────────────
class _YearSelector extends StatelessWidget {
  final List<SignupLookupItem> years;
  final String selectedId;
  final bool isLoading;
  final String? errorText;
  final ValueChanged<SignupLookupItem> onSelect;

  const _YearSelector({
    required this.years,
    required this.selectedId,
    required this.isLoading,
    required this.onSelect,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.yearLabel,
          style: TextStyle(
            fontSize: 13,
            color: SC.body,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 6),
        if (isLoading)
          Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SC.card,
              borderRadius: BorderRadius.all(Radius.circular(11)),
              border: Border.all(color: SC.hair),
            ),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: SC.burgundy,
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 7.0;
              final itemWidth = (constraints.maxWidth - spacing * 2) / 3;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: years.map((y) {
                  final sel = selectedId == y.id;
                  return GestureDetector(
                    key: ValueKey('signup-year-${y.id}'),
                    onTap: () => onSelect(y),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: itemWidth,
                      height: 44,
                      decoration: BoxDecoration(
                        color: sel ? SC.burgundy : SC.card,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(11),
                        ),
                        border: Border.all(
                          color: sel ? SC.burgundy : SC.hair,
                          width: sel ? 1.5 : 1,
                        ),
                        boxShadow: sel
                            ? [
                                BoxShadow(
                                  color: SC.burgundyTint,
                                  spreadRadius: 3,
                                  blurRadius: 0,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          academicYearDisplayName(y.name),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: sel ? Colors.white : SC.ink,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(errorText!, style: TextStyle(color: SC.burgundy, fontSize: 12)),
        ],
      ],
    );
  }
}

// ── Major autocomplete field ──────────────────────────────────────────────────
class _MajorField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<SignupLookupItem> suggestions;
  final bool showSuggestions;
  final bool isLoading;
  final String? errorText;
  final ValueChanged<String> onChanged;
  final ValueChanged<SignupLookupItem> onSelect;
  final VoidCallback? onTap;

  const _MajorField({
    required this.controller,
    required this.focusNode,
    required this.suggestions,
    required this.showSuggestions,
    required this.isLoading,
    required this.onChanged,
    required this.onSelect,
    required this.onTap,
    this.errorText,
  });

  List<TextSpan> _highlight(String text, String query) {
    if (query.isEmpty) {
      return [
        TextSpan(
          text: text,
          style: TextStyle(color: SC.ink),
        ),
      ];
    }
    final lower = text.toLowerCase();
    final idx = lower.indexOf(query.toLowerCase());
    if (idx < 0) {
      return [
        TextSpan(
          text: text,
          style: TextStyle(color: SC.ink),
        ),
      ];
    }
    return [
      if (idx > 0)
        TextSpan(
          text: text.substring(0, idx),
          style: TextStyle(color: SC.ink),
        ),
      TextSpan(
        text: text.substring(idx, idx + query.length),
        style: TextStyle(color: SC.burgundy, fontWeight: FontWeight.w700),
      ),
      if (idx + query.length < text.length)
        TextSpan(
          text: text.substring(idx + query.length),
          style: TextStyle(color: SC.ink),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.next,
          style: TextStyle(color: SC.ink, fontSize: 16, letterSpacing: -0.1),
          onChanged: onChanged,
          onTap: onTap,
          decoration: SC.fieldDecoration(
            label: AppLocalizations.of(context)!.majorFieldLabel,
            hint: isLoading
                ? AppLocalizations.of(context)!.loadingMajors
                : AppLocalizations.of(context)!.searchYourMajor,
            radiusTop: showSuggestions,
            suffixIcon: controller.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      controller.clear();
                      onChanged('');
                    },
                    child: Container(
                      width: 18,
                      height: 18,
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: SC.muted,
                      ),
                      child: Icon(Icons.close, color: Colors.white, size: 12),
                    ),
                  )
                : null,
            errorText: errorText,
          ),
        ),
        if (showSuggestions)
          Container(
            constraints: const BoxConstraints(maxHeight: 210),
            decoration: BoxDecoration(
              color: SC.card,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
              border: Border.all(color: SC.burgundy, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: SC.burgundyTint,
                  spreadRadius: 3,
                  blurRadius: 0,
                ),
              ],
            ),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              // Content can still exceed the 210px cap above even after
              // capping suggestions, so keep it scrollable (not Never).
              physics: const ClampingScrollPhysics(),
              itemCount: suggestions.length,
              separatorBuilder: (_, _) => Divider(height: 1, color: SC.hair),
              itemBuilder: (_, i) {
                final m = suggestions[i];
                return InkWell(
                  onTap: () => onSelect(m),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: RichText(
                      text: TextSpan(
                        children: _highlight(m.name, controller.text),
                        style: TextStyle(fontSize: 15),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
