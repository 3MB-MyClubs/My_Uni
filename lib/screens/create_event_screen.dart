import 'package:flutter/material.dart';
import '../models/event.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/club_notification_service.dart';
import '../services/content_store.dart';
import '../services/mock_data.dart';
import 'dart:io';
import '../widgets/story_image_uploader.dart';

class CreateEventScreen extends StatefulWidget {
  final VoidCallback? onCreated;
  const CreateEventScreen({super.key, this.onCreated});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

const _kLocationChips = [
  'SCI', 'ENG', 'SNA', 'Henry Çimleri',
  'Kurucular Salonu', 'SOS', 'Odeon', 'CASE',
];

const _kTagSuggestions = [
  'Free entry', 'Free food', 'Workshop', 'Talk', 'Panel',
  'Networking', 'Career', 'Competition', 'Social', 'Arts',
  'Music', 'Film', 'Tech', 'Academic', 'Volunteer',
];

class _ScheduleEntry {
  TimeOfDay time;
  TextEditingController titleCtrl;
  TextEditingController subtitleCtrl;
  bool isHighlighted = false;

  _ScheduleEntry({
    required this.time,
    required this.titleCtrl,
    required this.subtitleCtrl,
  });

  void dispose() {
    titleCtrl.dispose();
    subtitleCtrl.dispose();
  }
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  final _speakerController = TextEditingController();
  String? _imagePath;
  String? _selectedLocationChip;

  // Hero customization
  String? _accentColorHex; // null = auto (club color)

  // Tags
  final List<String> _selectedTags = [];
  final _customTagCtrl = TextEditingController();

  // Schedule
  final List<_ScheduleEntry> _scheduleEntries = [];
  bool _scheduleGated = false;

  DateTime _startDate = DateTime.now().add(const Duration(hours: 1));
  DateTime _endDate = DateTime.now().add(const Duration(hours: 3));

  bool get _canPost =>
      _titleController.text.trim().isNotEmpty &&
      _locationController.text.trim().isNotEmpty &&
      _endDate.isAfter(_startDate);

  String? get _adminClubId {
    final admin = authService.currentAdmin;
    if (admin == null) return null;
    try {
      return clubs.firstWhere((c) => c.adminUserIds.contains(admin.id)).id;
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primaryRed),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = DateTime(picked.year, picked.month, picked.day,
            _startDate.hour, _startDate.minute);
      } else {
        _endDate = DateTime(picked.year, picked.month, picked.day,
            _endDate.hour, _endDate.minute);
      }
    });
  }

  Future<void> _pickTime(bool isStart) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primaryRed),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = DateTime(_startDate.year, _startDate.month, _startDate.day,
            picked.hour, picked.minute);
      } else {
        _endDate = DateTime(_endDate.year, _endDate.month, _endDate.day,
            picked.hour, picked.minute);
      }
    });
  }

  Future<void> _pickSlotTime(_ScheduleEntry entry) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: entry.time,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primaryRed),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => entry.time = picked);
  }

  void _addScheduleEntry() {
    final lastTime = _scheduleEntries.isEmpty
        ? TimeOfDay(hour: _startDate.hour, minute: _startDate.minute)
        : _scheduleEntries.last.time;
    // Default next slot 30 min after previous
    final nextMinutes = lastTime.hour * 60 + lastTime.minute + 30;
    setState(() {
      _scheduleEntries.add(_ScheduleEntry(
        time: TimeOfDay(
            hour: (nextMinutes ~/ 60) % 24, minute: nextMinutes % 60),
        titleCtrl: TextEditingController(),
        subtitleCtrl: TextEditingController(),
      ));
    });
  }

  void _removeScheduleEntry(int idx) {
    setState(() {
      _scheduleEntries[idx].dispose();
      _scheduleEntries.removeAt(idx);
    });
  }

  void _post() {
    final clubId = _adminClubId;
    if (clubId == null) return;

    // Build schedule
    List<EventSlot>? schedule;
    final filledSlots = _scheduleEntries
        .where((e) => e.titleCtrl.text.trim().isNotEmpty)
        .toList();
    if (filledSlots.isNotEmpty) {
      final baseDate = _startDate;
      schedule = filledSlots.map((e) {
        return EventSlot(
          time: DateTime(baseDate.year, baseDate.month, baseDate.day,
              e.time.hour, e.time.minute),
          title: e.titleCtrl.text.trim(),
          subtitle: e.subtitleCtrl.text.trim().isEmpty
              ? null
              : e.subtitleCtrl.text.trim(),
          isHighlighted: e.isHighlighted,
        );
      }).toList();
    }

    final speaker = _speakerController.text.trim();

    final newEvent = Event(
      id: 'ev_${DateTime.now().millisecondsSinceEpoch}',
      clubId: clubId,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      location: _locationController.text.trim(),
      dateTime: _startDate,
      endTime: _endDate,
      attendeeUserIds: [],
      imagePath: _imagePath,
      createdByUserId: authService.currentAdmin?.id,
      tags: List.from(_selectedTags),
      guestSpeaker: speaker.isEmpty ? null : speaker,
      schedule: schedule,
      scheduleGated: _scheduleGated && schedule != null,
      accentColorHex: _accentColorHex,
    );

    events.add(newEvent);
    contentStore.saveEvents();
    clubNotificationService.notifyFollowersAboutEvent(newEvent);
    widget.onCreated?.call();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    _speakerController.dispose();
    _customTagCtrl.dispose();
    for (final e in _scheduleEntries) {
      e.dispose();
    }
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.text,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: TextStyle(color: AppColors.secondaryText)),
        ),
        leadingWidth: 80,
        title: Text('New Event',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 17)),
        centerTitle: true,
        actions: [
          ValueListenableBuilder(
            valueListenable: _titleController,
            builder: (ctx, value, child) => TextButton(
              onPressed: _canPost ? _post : null,
              child: Text(
                'Post',
                style: TextStyle(
                  color: _canPost
                      ? AppColors.primaryRed
                      : AppColors.secondaryText,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Hero preview + customization ─────────────────────────────────
          _HeroEditor(
            imagePath: _imagePath,
            accentColorHex: _accentColorHex,
            titleText: _titleController.text.trim(),
            onImageChanged: (p) => setState(() => _imagePath = p),
            onColorChanged: (hex) =>
                setState(() => _accentColorHex = hex),
          ),
          const SizedBox(height: 16),

          // ── Basic info ───────────────────────────────────────────────────
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Field(
                  controller: _titleController,
                  label: 'Event Title',
                  hint: 'e.g. Spring Hackathon',
                  onChanged: (_) => setState(() {}),
                ),
                const Divider(height: 1),
                _LocationPicker(
                  controller: _locationController,
                  selectedChip: _selectedLocationChip,
                  onChipTap: (chip, selected) => setState(() {
                    _selectedLocationChip = selected ? null : chip;
                    _locationController.text = selected ? '' : chip;
                  }),
                  onTextChanged: (v) => setState(() {
                    if (!_kLocationChips.contains(v.trim())) {
                      _selectedLocationChip = null;
                    }
                  }),
                ),
                const Divider(height: 1),
                _Field(
                  controller: _descController,
                  label: 'Description',
                  hint: 'Tell people what this event is about...',
                  maxLines: 4,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Date & time ──────────────────────────────────────────────────
          _SectionCard(
            child: Column(
              children: [
                _DateTimeRow(
                  label: 'Starts',
                  dateTime: _startDate,
                  onDateTap: () => _pickDate(true),
                  onTimeTap: () => _pickTime(true),
                ),
                const Divider(height: 1),
                _DateTimeRow(
                  label: 'Ends',
                  dateTime: _endDate,
                  onDateTap: () => _pickDate(false),
                  onTimeTap: () => _pickTime(false),
                  error: !_endDate.isAfter(_startDate)
                      ? 'End must be after start'
                      : null,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Tags ─────────────────────────────────────────────────────────
          _SectionHeader(
            icon: Icons.label_outline_rounded,
            label: 'Tags',
            subtitle: 'Help people discover your event',
          ),
          const SizedBox(height: 8),
          _SectionCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _kTagSuggestions.map((tag) {
                      final selected = _selectedTags.contains(tag);
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (selected) {
                            _selectedTags.remove(tag);
                          } else {
                            _selectedTags.add(tag);
                          }
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primaryRed
                                : AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primaryRed
                                  : AppColors.divider,
                            ),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white
                                  : AppColors.secondaryText,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (_selectedTags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Divider(color: AppColors.divider, height: 1),
                    const SizedBox(height: 8),
                    Text(
                      'Selected: ${_selectedTags.join(', ')}',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.secondaryText),
                    ),
                  ],
                  const SizedBox(height: 10),
                  // Custom tag input
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customTagCtrl,
                          style: TextStyle(
                              fontSize: 13, color: AppColors.text),
                          decoration: InputDecoration(
                            hintText: 'Add custom tag…',
                            hintStyle: TextStyle(
                                color: AppColors.secondaryText,
                                fontSize: 13),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: AppColors.divider),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: AppColors.divider),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: AppColors.primaryRed),
                            ),
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                          ),
                          onSubmitted: (v) {
                            final tag = v.trim();
                            if (tag.isNotEmpty &&
                                !_selectedTags.contains(tag)) {
                              setState(() {
                                _selectedTags.add(tag);
                                _customTagCtrl.clear();
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () {
                          final tag = _customTagCtrl.text.trim();
                          if (tag.isNotEmpty &&
                              !_selectedTags.contains(tag)) {
                            setState(() {
                              _selectedTags.add(tag);
                              _customTagCtrl.clear();
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Add',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Guest speaker ─────────────────────────────────────────────────
          _SectionHeader(
            icon: Icons.mic_rounded,
            label: 'Guest Speaker',
            subtitle: 'Optional — adds a featured speaker card',
          ),
          const SizedBox(height: 8),
          _SectionCard(
            child: _Field(
              controller: _speakerController,
              label: 'Speaker name',
              hint: 'e.g. Dr. Ayşe Yılmaz, CEO of ...',
              onChanged: (_) => setState(() {}),
            ),
          ),

          const SizedBox(height: 16),

          // ── Schedule / Programme ──────────────────────────────────────────
          _SectionHeader(
            icon: Icons.format_list_bulleted_rounded,
            label: 'Programme',
            subtitle: 'Add a timetable for your event',
          ),
          const SizedBox(height: 8),
          _SectionCard(
            child: Column(
              children: [
                // Existing slots
                for (int i = 0; i < _scheduleEntries.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, color: AppColors.divider),
                  _ScheduleSlotEditor(
                    entry: _scheduleEntries[i],
                    index: i,
                    onRemove: () => _removeScheduleEntry(i),
                    onTimeTap: () =>
                        _pickSlotTime(_scheduleEntries[i]),
                    onChanged: () => setState(() {}),
                  ),
                ],

                // Add slot button
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: GestureDetector(
                    onTap: _addScheduleEntry,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.divider,
                            style: BorderStyle.solid),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded,
                              size: 16,
                              color: AppColors.secondaryText),
                          const SizedBox(width: 6),
                          Text(
                            'Add time slot',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Gate toggle
                if (_scheduleEntries.isNotEmpty) ...[
                  Divider(height: 1, color: AppColors.divider),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline_rounded,
                            size: 16, color: AppColors.secondaryText),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Require RSVP to see programme',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text,
                                ),
                              ),
                              Text(
                                'Programme only visible to confirmed attendees',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.secondaryText),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _scheduleGated,
                          onChanged: (v) =>
                              setState(() => _scheduleGated = v),
                          activeThumbColor: AppColors.primaryRed,
                          activeTrackColor: AppColors.primaryRed.withValues(alpha: 0.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero preview + customization (photo + color palette)
// ─────────────────────────────────────────────────────────────────────────────

const _kPaletteColors = [
  // null = auto (uses club color)
  '8C1D40', // KU burgundy
  'EF5350', // red
  'E65100', // deep orange
  'F9A825', // amber
  '2E7D32', // green
  '00838F', // teal
  '1565C0', // blue
  '4527A0', // deep purple
  '6A1B9A', // purple
  '283593', // navy
  '4E342E', // brown
  '37474F', // dark slate
];

class _HeroEditor extends StatelessWidget {
  final String? imagePath;
  final String? accentColorHex;
  final String titleText;
  final ValueChanged<String?> onImageChanged;
  final ValueChanged<String?> onColorChanged;

  const _HeroEditor({
    required this.imagePath,
    required this.accentColorHex,
    required this.titleText,
    required this.onImageChanged,
    required this.onColorChanged,
  });

  Color get _previewColor => accentColorHex != null
      ? Color(int.parse('FF$accentColorHex', radix: 16))
      : AppColors.primaryRed;

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Live preview ──────────────────────────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 200,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background: image or gradient
                if (hasImage)
                  Image.file(File(imagePath!), fit: BoxFit.cover)
                else
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _previewColor,
                          Color.lerp(_previewColor, Colors.black, 0.35)!,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Stack(children: [
                      Positioned(
                        top: -30, right: -30,
                        child: Container(
                          width: 140, height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.07),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 10, left: -20,
                        child: Container(
                          width: 90, height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                      ),
                    ]),
                  ),

                // Color tint overlay when image + color chosen
                if (hasImage && accentColorHex != null)
                  Container(
                    color: _previewColor.withValues(alpha: 0.35),
                  ),

                // Bottom scrim
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  height: 110,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.65),
                        ],
                      ),
                    ),
                  ),
                ),

                // Title preview
                Positioned(
                  left: 14, right: 14, bottom: 14,
                  child: Text(
                    titleText.isEmpty ? 'Event title preview' : titleText,
                    style: TextStyle(
                      color: titleText.isEmpty
                          ? Colors.white.withValues(alpha: 0.4)
                          : Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      height: 1.15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Photo edit button (top-right)
                Positioned(
                  top: 10, right: 10,
                  child: _PhotoEditButton(
                    hasImage: hasImage,
                    imagePath: imagePath,
                    onChanged: onImageChanged,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        // ── Color palette ─────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.palette_outlined,
                      size: 15, color: AppColors.secondaryText),
                  const SizedBox(width: 6),
                  Text(
                    'Background colour',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    accentColorHex == null ? 'Auto (club colour)' : '#$accentColorHex',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.secondaryText),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  // "Auto" swatch
                  _ColorSwatch(
                    color: AppColors.primaryRed,
                    isSelected: accentColorHex == null,
                    isAuto: true,
                    onTap: () => onColorChanged(null),
                  ),
                  ..._kPaletteColors.map((hex) {
                    final c = Color(int.parse('FF$hex', radix: 16));
                    return _ColorSwatch(
                      color: c,
                      isSelected: accentColorHex == hex,
                      isAuto: false,
                      onTap: () => onColorChanged(hex),
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final bool isAuto;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.color,
    required this.isSelected,
    required this.isAuto,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isSelected ? 0.55 : 0.25),
              blurRadius: isSelected ? 10 : 4,
              spreadRadius: isSelected ? 2 : 0,
            ),
          ],
        ),
        child: isAuto
            ? Center(
                child: Text(
                  'A',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              )
            : isSelected
                ? const Icon(Icons.check_rounded,
                    color: Colors.white, size: 18)
                : null,
      ),
    );
  }
}

class _PhotoEditButton extends StatelessWidget {
  final bool hasImage;
  final String? imagePath;
  final ValueChanged<String?> onChanged;

  const _PhotoEditButton({
    required this.hasImage,
    required this.imagePath,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => _PhotoPickerSheet(
            hasImage: hasImage,
            onChanged: onChanged,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.50),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasImage ? Icons.edit_rounded : Icons.add_photo_alternate_rounded,
              color: Colors.white,
              size: 14,
            ),
            const SizedBox(width: 5),
            Text(
              hasImage ? 'Change photo' : 'Add photo',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPickerSheet extends StatelessWidget {
  final bool hasImage;
  final ValueChanged<String?> onChanged;

  const _PhotoPickerSheet(
      {required this.hasImage, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return StoryImageUploader(
      imagePath: null,
      onChanged: (p) {
        Navigator.pop(context);
        onChanged(p);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Schedule slot editor row
// ─────────────────────────────────────────────────────────────────────────────

class _ScheduleSlotEditor extends StatelessWidget {
  final _ScheduleEntry entry;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onTimeTap;
  final VoidCallback onChanged;

  const _ScheduleSlotEditor({
    required this.entry,
    required this.index,
    required this.onRemove,
    required this.onTimeTap,
    required this.onChanged,
  });

  String _fmtTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Time picker button
              GestureDetector(
                onTap: onTimeTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.lightRed,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _fmtTime(entry.time),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryRed,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Highlight toggle
              GestureDetector(
                onTap: () {
                  entry.isHighlighted = !entry.isHighlighted;
                  onChanged();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: entry.isHighlighted
                        ? AppColors.primaryRed.withValues(alpha: 0.12)
                        : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: entry.isHighlighted
                          ? AppColors.primaryRed.withValues(alpha: 0.4)
                          : AppColors.divider,
                    ),
                  ),
                  child: Text(
                    '★ Highlight',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: entry.isHighlighted
                          ? AppColors.primaryRed
                          : AppColors.secondaryText,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              // Remove button
              GestureDetector(
                onTap: onRemove,
                child: Icon(Icons.close_rounded,
                    size: 18, color: AppColors.secondaryText),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: entry.titleCtrl,
            onChanged: (_) => onChanged(),
            style: TextStyle(fontSize: 13, color: AppColors.text),
            decoration: InputDecoration(
              hintText: 'Session title (required)',
              hintStyle: TextStyle(
                  color: AppColors.secondaryText, fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.primaryRed),
              ),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: entry.subtitleCtrl,
            onChanged: (_) => onChanged(),
            style: TextStyle(fontSize: 12, color: AppColors.text),
            decoration: InputDecoration(
              hintText: 'Subtitle / speaker (optional)',
              hintStyle: TextStyle(
                  color: AppColors.secondaryText, fontSize: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.primaryRed),
              ),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared form widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primaryRed),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                  fontSize: 11, color: AppColors.secondaryText),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: child,
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        onChanged: onChanged,
        style: TextStyle(fontSize: 14, color: AppColors.text),
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              TextStyle(color: AppColors.secondaryText, fontSize: 13),
          hintText: hint,
          hintStyle:
              TextStyle(color: AppColors.secondaryText, fontSize: 13),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _LocationPicker extends StatelessWidget {
  final TextEditingController controller;
  final String? selectedChip;
  final void Function(String chip, bool currentlySelected) onChipTap;
  final ValueChanged<String> onTextChanged;

  const _LocationPicker({
    required this.controller,
    required this.selectedChip,
    required this.onChipTap,
    required this.onTextChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Icon(Icons.location_on_outlined,
                  size: 18, color: AppColors.secondaryText),
              const SizedBox(width: 8),
              Text('Location',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.secondaryText)),
            ],
          ),
        ),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            itemCount: _kLocationChips.length,
            separatorBuilder: (_, i) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final chip = _kLocationChips[i];
              final selected = selectedChip == chip;
              return GestureDetector(
                onTap: () => onChipTap(chip, selected),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primaryRed
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? AppColors.primaryRed
                          : AppColors.divider,
                    ),
                  ),
                  child: Text(
                    chip,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Colors.white
                          : AppColors.secondaryText,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
          child: TextField(
            controller: controller,
            style: TextStyle(fontSize: 14, color: AppColors.text),
            onChanged: onTextChanged,
            decoration: InputDecoration(
              hintText: 'Or type a custom location…',
              hintStyle: TextStyle(
                  color: AppColors.secondaryText, fontSize: 13),
              border: InputBorder.none,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
      ],
    );
  }
}

class _DateTimeRow extends StatelessWidget {
  final String label;
  final DateTime dateTime;
  final VoidCallback onDateTap;
  final VoidCallback onTimeTap;
  final String? error;

  const _DateTimeRow({
    required this.label,
    required this.dateTime,
    required this.onDateTap,
    required this.onTimeTap,
    this.error,
  });

  String _fmtDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 52,
                child: Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        color: AppColors.text,
                        fontWeight: FontWeight.w500)),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onDateTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.lightRed,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_fmtDate(dateTime),
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.primaryRed,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onTimeTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.lightRed,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_fmtTime(dateTime),
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.primaryRed,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 4),
            Text(error!,
                style: const TextStyle(fontSize: 11, color: Colors.red)),
          ],
        ],
      ),
    );
  }
}
