import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'signup_theme.dart';

const List<String> kMajors = [
  'Business Administration',
  'Economics',
  'International Relations',
  'Computer Engineering',
  'Electrical & Electronics Engineering',
  'Industrial Engineering',
  'Mechanical Engineering',
  'Chemical & Biological Engineering',
  'Mathematics',
  'Physics',
  'Chemistry',
  'Molecular Biology and Genetics',
  'Psychology',
  'Sociology',
  'History',
  'Philosophy',
  'Comparative Literature',
  'Archaeology and History of Art',
  'Media and Visual Arts',
  'Law',
  'Medicine',
  'Nursing',
];

const List<String> kYears = [
  '1st Year',
  '2nd Year',
  '3rd Year',
  '4th Year',
  'Grad',
];

class StepProfile extends StatefulWidget {
  final String initialName;
  final String initialMajor;
  final String initialYear;
  final void Function(String name, String major, String year, String? imagePath)
  onNext;

  const StepProfile({
    super.key,
    this.initialName = '',
    this.initialMajor = '',
    this.initialYear = '',
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
  String _selectedYear = '';
  String? _imagePath;

  List<String> _suggestions = [];
  bool _showSuggestions = false;
  final FocusNode _majorFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _majorController = TextEditingController(text: widget.initialMajor);
    _selectedYear = widget.initialYear;

    _majorFocus.addListener(() {
      if (!_majorFocus.hasFocus) {
        setState(() => _showSuggestions = false);
      }
    });
  }

  // ── Major autocomplete ─────────────────────────────────────────
  void _onMajorChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        _suggestions = kMajors;
        _showSuggestions = true;
      });
      return;
    }
    final q = query.toLowerCase();
    final scored =
        kMajors
            .map((m) {
              final ml = m.toLowerCase();
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
    });
  }

  void _selectMajor(String major) {
    _majorController.text = major;
    setState(() {
      _showSuggestions = false;
      _majorError = null;
    });
    _majorFocus.unfocus();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _imagePath = picked.path);
    }
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

    if (name.isEmpty) {
      setState(() => _nameError = 'Please enter your full name.');
      hasError = true;
    } else {
      setState(() => _nameError = null);
    }

    if (major.isEmpty) {
      setState(() => _majorError = 'Please select your major.');
      hasError = true;
    } else if (!kMajors.contains(major)) {
      setState(() => _majorError = 'Please pick a major from the list.');
      hasError = true;
    } else {
      setState(() => _majorError = null);
    }

    if (_selectedYear.isEmpty) {
      setState(() => _yearError = 'Please select your year.');
      hasError = true;
    } else {
      setState(() => _yearError = null);
    }

    if (!hasError) {
      widget.onNext(name, major, _selectedYear, _imagePath);
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

                // ── Avatar ─────────────────────────────────────
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
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
                  errorText: _majorError,
                  onChanged: _onMajorChanged,
                  onSelect: _selectMajor,
                  onTap: () => _onMajorChanged(_majorController.text),
                ),
                const SizedBox(height: 14),

                // Year
                _YearSelector(
                  selected: _selectedYear,
                  errorText: _yearError,
                  onSelect: (y) => setState(() {
                    _selectedYear = y;
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
              onPressed: _submit,
              style: SC.primaryButtonStyle(),
              child: Text('Continue'),
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
  final String selected;
  final String? errorText;
  final ValueChanged<String> onSelect;

  const _YearSelector({
    required this.selected,
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
        Row(
          children: kYears.map((y) {
            final sel = selected == y;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: y != kYears.last ? 6 : 0),
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
                        y,
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
  final List<String> suggestions;
  final bool showSuggestions;
  final String? errorText;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSelect;
  final VoidCallback onTap;

  const _MajorField({
    required this.controller,
    required this.focusNode,
    required this.suggestions,
    required this.showSuggestions,
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
            hint: 'Search your major…',
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
                        children: _highlight(m, controller.text),
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
