import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/signup_service.dart';
import 'signup_theme.dart';

class StepProfile extends StatefulWidget {
  final String initialName;
  final String initialMajor;
  final String initialYear;
  final Future<List<SignupLookupItem>> Function() loadMajors;
  final Future<List<SignupLookupItem>> Function() loadAcademicYears;
  final void Function(
    String name,
    String majorId,
    String majorName,
    String academicYearId,
    String academicYearName,
    String? imagePath,
  )
  onNext;

  const StepProfile({
    super.key,
    this.initialName = '',
    this.initialMajor = '',
    this.initialYear = '',
    required this.loadMajors,
    required this.loadAcademicYears,
    required this.onNext,
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
  bool _isLoadingLookups = true;
  String? _lookupError;

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
          _lookupError = 'Could not load profile options. Please try again.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingLookups = false;
        _lookupError = 'Could not load profile options. Please try again.';
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
        _suggestions = _majors;
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
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: SC.card,
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
                  color: SC.hair,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              _photoOption(Icons.camera_alt_outlined, 'Take a photo', () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.camera);
              }),
              Divider(height: 1, indent: 16, color: SC.hair),
              _photoOption(
                Icons.photo_library_outlined,
                'Choose from library',
                () {
                  Navigator.pop(context);
                  _pickPhoto(ImageSource.gallery);
                },
              ),
              if (hasPhoto) ...[
                Divider(height: 1, indent: 16, color: SC.hair),
                _photoOption(Icons.delete_outline_rounded, 'Remove photo', () {
                  Navigator.pop(context);
                  setState(() => _imagePath = null);
                }, danger: true),
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
    final color = danger ? Colors.red.shade400 : SC.burgundy;
    return ListTile(
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(12),
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

  Future<void> _pickPhoto(ImageSource source) async {
    CroppedFile? cropped;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 85);
      if (picked == null || !mounted) return;

      cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 82,
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
            toolbarColor: SC.burgundy,
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
    setState(() => _imagePath = cropped!.path);
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

  // ── Submit ─────────────────────────────────────────────────────
  void _submit() {
    final name = _nameController.text.trim();
    final major = _majorController.text.trim();
    bool hasError = false;

    if (_isLoadingLookups || _lookupError != null) {
      setState(
        () =>
            _lookupError = 'Could not load profile options. Please try again.',
      );
      return;
    }

    final nameParts = name.split(RegExp(r'\s+')).where((part) {
      return part.isNotEmpty;
    }).toList();

    if (name.isEmpty) {
      setState(() => _nameError = 'Please enter your full name.');
      hasError = true;
    } else if (nameParts.length < 2) {
      setState(() => _nameError = 'Please enter your first and last name.');
      hasError = true;
    } else {
      setState(() => _nameError = null);
    }

    if (major.isEmpty) {
      setState(() => _majorError = 'Please select your major.');
      hasError = true;
    } else if (_selectedMajorId.isEmpty) {
      setState(() => _majorError = 'Please pick a major from the list.');
      hasError = true;
    } else {
      setState(() => _majorError = null);
    }

    if (_selectedYearId.isEmpty) {
      setState(() => _yearError = 'Please select your year.');
      hasError = true;
    } else {
      setState(() => _yearError = null);
    }

    if (!hasError) {
      widget.onNext(
        name,
        _selectedMajorId,
        major,
        _selectedYearId,
        _selectedYearName,
        _imagePath,
      );
    }
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
      return Image.network(path, width: 92, height: 92, fit: BoxFit.cover);
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
                  'Tell us about you.',
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
                  'This shows up on your campus profile.',
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
                      borderRadius: BorderRadius.circular(10),
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
                    label: 'Full name',
                    hint: 'e.g. Ali Yılmaz',
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

        // ── Continue — pinned to bottom ─────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoadingLookups ? null : _submit,
              style: SC.primaryButtonStyle(),
              child: _isLoadingLookups
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text('Continue'),
            ),
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
          'Year',
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
              borderRadius: BorderRadius.circular(11),
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
          Row(
            children: years.map((y) {
              final sel = selectedId == y.id;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: y != years.last ? 6 : 0),
                  child: GestureDetector(
                    onTap: () => onSelect(y),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      height: 44,
                      decoration: BoxDecoration(
                        color: sel ? SC.burgundy : SC.card,
                        borderRadius: BorderRadius.circular(11),
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
                          y.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: sel ? Colors.white : SC.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
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
            label: 'Major',
            hint: isLoading ? 'Loading majors...' : 'Search your major...',
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
