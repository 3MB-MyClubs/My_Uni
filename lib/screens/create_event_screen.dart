import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart'
    show
        CupertinoDatePicker,
        CupertinoDatePickerMode,
        CupertinoTheme,
        CupertinoThemeData;
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../models/event.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/club_admin_access.dart';
import '../services/club_notification_service.dart';
import '../services/content_store.dart';
import '../services/mock_data.dart';
import '../services/supabase_event_service.dart';
import '../widgets/mention_text_field.dart';

class CreateEventScreen extends StatefulWidget {
  final VoidCallback? onCreated;

  /// When provided, the form opens in edit mode pre-filled with this event and
  /// saves changes in place instead of creating a new event.
  final Event? existing;

  const CreateEventScreen({super.key, this.onCreated, this.existing});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

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

class _SpeakerEntry {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController roleCtrl = TextEditingController();
  final TextEditingController linkedinCtrl = TextEditingController();

  void dispose() {
    nameCtrl.dispose();
    roleCtrl.dispose();
    linkedinCtrl.dispose();
  }
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  String? _imagePath;

  // Tags
  final List<String> _selectedTags = [];
  final _customTagCtrl = TextEditingController();

  // Schedule
  final List<_ScheduleEntry> _scheduleEntries = [];

  // Registration (external sign-up link)
  bool _externalReg = false;
  final _regUrlCtrl = TextEditingController();

  // Speakers (name / role / LinkedIn)
  final List<_SpeakerEntry> _speakers = [];
  bool _isPosting = false;

  DateTime _startDate = DateTime.now().add(const Duration(hours: 1));
  DateTime _endDate = DateTime.now().add(const Duration(hours: 3));

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final ev = widget.existing;
    if (ev == null) return;

    _titleController.text = ev.title;
    _descController.text = ev.description;
    _locationController.text = ev.location;
    _imagePath = ev.imagePath;
    _selectedTags.addAll(ev.tags);
    _startDate = ev.dateTime;
    _endDate = ev.endTime;

    final reg = ev.registrationUrl?.trim() ?? '';
    if (reg.isNotEmpty) {
      _externalReg = true;
      _regUrlCtrl.text = reg;
    }

    for (final slot in ev.schedule ?? const <EventSlot>[]) {
      final entry = _ScheduleEntry(
        time: TimeOfDay(hour: slot.time.hour, minute: slot.time.minute),
        titleCtrl: TextEditingController(text: slot.title),
        subtitleCtrl: TextEditingController(text: slot.subtitle ?? ''),
      );
      entry.isHighlighted = slot.isHighlighted;
      _scheduleEntries.add(entry);
    }

    for (final sp in ev.speakers) {
      final entry = _SpeakerEntry();
      entry.nameCtrl.text = sp.name;
      entry.roleCtrl.text = sp.role;
      entry.linkedinCtrl.text = sp.linkedin ?? '';
      _speakers.add(entry);
    }
  }

  bool get _canPost =>
      _titleController.text.trim().isNotEmpty &&
      _locationController.text.trim().isNotEmpty &&
      _endDate.isAfter(_startDate);

  String? get _adminClubId {
    final admin = authService.currentAdmin;
    if (admin == null) return null;
    try {
      return clubs.firstWhere((c) => clubIsManagedByAdmin(c, admin.id)).id;
    } catch (_) {
      return null;
    }
  }

  List<MentionOption> get _mentionOptions => [
    ...clubs.map(
      (club) =>
          MentionOption(id: club.id, label: club.name, type: MentionType.club),
    ),
    ...users.map(
      (user) => MentionOption(
        id: user.id,
        label: user.name,
        type: MentionType.student,
      ),
    ),
  ];

  // Single, fast iOS-style wheel for both the date and the time — one scroll
  // sets everything (replaces the fiddly Material calendar + analog clock).
  Future<void> _pickDateTime(bool isStart) async {
    final now = DateTime.now();
    final initial = isStart ? _startDate : _endDate;
    // Cupertino requires initialDateTime >= minimumDate.
    final minDate = isStart
        ? now.subtract(const Duration(days: 1))
        : _startDate;
    var temp = initial.isBefore(minDate) ? minDate : initial;

    final result = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: Cancel · Starts/Ends · Done
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: AppColors.secondaryText),
                    ),
                  ),
                  Text(
                    isStart ? 'Starts' : 'Ends',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, temp),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        color: AppColors.primaryRed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.divider),
            // The wheel — date + time together, 24-hour.
            SizedBox(
              height: 232,
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: Theme.of(context).brightness,
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.dateAndTime,
                  initialDateTime: temp,
                  minimumDate: minDate,
                  maximumDate: now.add(const Duration(days: 365)),
                  use24hFormat: true,
                  onDateTimeChanged: (d) => temp = d,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (result == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = result;
        // Keep the end after the start automatically.
        if (!_endDate.isAfter(_startDate)) {
          _endDate = _startDate.add(const Duration(hours: 1));
        }
      } else {
        _endDate = result;
      }
    });
  }

  Future<void> _pickSlotTime(_ScheduleEntry entry) async {
    final now = DateTime.now();
    var temp = DateTime(
      now.year,
      now.month,
      now.day,
      entry.time.hour,
      entry.time.minute,
    );
    final result = await showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: AppColors.secondaryText),
                    ),
                  ),
                  Text(
                    'Time',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.pop(ctx, TimeOfDay.fromDateTime(temp)),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        color: AppColors.primaryRed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.divider),
            SizedBox(
              height: 200,
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: Theme.of(context).brightness,
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: temp,
                  use24hFormat: true,
                  onDateTimeChanged: (d) => temp = d,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => entry.time = result);
  }

  void _addScheduleEntry() {
    final lastTime = _scheduleEntries.isEmpty
        ? TimeOfDay(hour: _startDate.hour, minute: _startDate.minute)
        : _scheduleEntries.last.time;
    // Default next slot 30 min after previous
    final nextMinutes = lastTime.hour * 60 + lastTime.minute + 30;
    setState(() {
      _scheduleEntries.add(
        _ScheduleEntry(
          time: TimeOfDay(
            hour: (nextMinutes ~/ 60) % 24,
            minute: nextMinutes % 60,
          ),
          titleCtrl: TextEditingController(),
          subtitleCtrl: TextEditingController(),
        ),
      );
    });
  }

  void _removeScheduleEntry(int idx) {
    setState(() {
      _scheduleEntries[idx].dispose();
      _scheduleEntries.removeAt(idx);
    });
  }

  Future<void> _post() async {
    final clubId = widget.existing?.clubId ?? _adminClubId;
    if (clubId == null || _isPosting) return;

    // Build schedule
    List<EventSlot>? schedule;
    final filledSlots = _scheduleEntries
        .where((e) => e.titleCtrl.text.trim().isNotEmpty)
        .toList();
    if (filledSlots.isNotEmpty) {
      final baseDate = _startDate;
      schedule = filledSlots.map((e) {
        return EventSlot(
          time: DateTime(
            baseDate.year,
            baseDate.month,
            baseDate.day,
            e.time.hour,
            e.time.minute,
          ),
          title: e.titleCtrl.text.trim(),
          subtitle: e.subtitleCtrl.text.trim().isEmpty
              ? null
              : e.subtitleCtrl.text.trim(),
          isHighlighted: e.isHighlighted,
        );
      }).toList();
    }

    final speakers = _speakers
        .where((s) => s.nameCtrl.text.trim().isNotEmpty)
        .map(
          (s) => EventSpeaker(
            name: s.nameCtrl.text.trim(),
            role: s.roleCtrl.text.trim(),
            linkedin: s.linkedinCtrl.text.trim().isEmpty
                ? null
                : s.linkedinCtrl.text.trim(),
          ),
        )
        .toList();

    final regUrl = _regUrlCtrl.text.trim();

    // ── Edit mode: update the existing event in place ──────────────────────
    if (_isEditing) {
      final ev = widget.existing!;
      final updated = Event(
        id: ev.id,
        clubId: ev.clubId,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        location: _locationController.text.trim(),
        dateTime: _startDate,
        endTime: _endDate,
        attendeeUserIds: ev.attendeeUserIds,
        rsvpTimestamps: ev.rsvpTimestamps,
        imagePath: _imagePath,
        createdByUserId: ev.createdByUserId,
        tags: List.from(_selectedTags),
        schedule: schedule,
        accentColorHex: ev.accentColorHex,
        registrationUrl: (_externalReg && regUrl.isNotEmpty) ? regUrl : null,
        capacity: ev.capacity,
        speakers: speakers,
      );
      final ok = contentStore.updateEvent(
        updated,
        authService.currentAdmin?.id ?? '',
      );
      if (!mounted) return;
      if (ok) {
        widget.onCreated?.call();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Could not save changes.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
      return;
    }

    final draftEvent = Event(
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
      schedule: schedule,
      registrationUrl: (_externalReg && regUrl.isNotEmpty) ? regUrl : null,
      speakers: speakers,
    );

    setState(() => _isPosting = true);
    try {
      final newEvent = await supabaseEventService.createEvent(draftEvent);
      if (!mounted) return;
      events.add(newEvent);
      unawaited(contentStore.saveEvents());
      unawaited(clubNotificationService.notifyFollowersAboutEvent(newEvent));
      widget.onCreated?.call();
      Navigator.pop(context);
    } catch (error, stackTrace) {
      debugPrint('Create event failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _isPosting = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(_publishErrorMessage(error)),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  String _publishErrorMessage(Object error) {
    final text = error.toString();
    if (text.contains('row-level security') ||
        text.contains('permission denied') ||
        text.contains('42501')) {
      return 'Could not publish event. Check events RLS policies for this club account.';
    }
    if (text.contains('column') ||
        text.contains('schedule') ||
        text.contains('speakers')) {
      return 'Could not publish event. Run the latest events SQL migration.';
    }
    if (text.contains('event-images') || text.contains('storage')) {
      return 'Could not upload event image. Check the event-images bucket policies.';
    }
    return 'Could not publish event. Check Supabase settings.';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    _customTagCtrl.dispose();
    _regUrlCtrl.dispose();
    for (final e in _scheduleEntries) {
      e.dispose();
    }
    for (final s in _speakers) {
      s.dispose();
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
          child: Text(
            'Cancel',
            style: TextStyle(color: AppColors.secondaryText),
          ),
        ),
        leadingWidth: 80,
        title: Text(
          _isEditing ? 'Edit Event' : 'New Event',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        centerTitle: true,
        actions: [
          ValueListenableBuilder(
            valueListenable: _titleController,
            builder: (ctx, value, child) => TextButton(
              onPressed: _canPost && !_isPosting ? () => _post() : null,
              child: _isPosting
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryRed,
                      ),
                    )
                  : Text(
                      _isEditing ? 'Save' : 'Post',
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
          // ── Hero preview + optional image ────────────────────────────────
          _HeroEditor(
            imagePath: _imagePath,
            titleText: _titleController.text.trim(),
            onImageChanged: (p) => setState(() => _imagePath = p),
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
                _Field(
                  controller: _locationController,
                  label: 'Location',
                  hint: 'Write the event location',
                  onChanged: (_) => setState(() {}),
                ),
                const Divider(height: 1),
                _Field(
                  controller: _descController,
                  label: 'Description',
                  hint: 'Tell people what this event is about...',
                  maxLines: 4,
                  mentionOptions: _mentionOptions,
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
                  onTap: () => _pickDateTime(true),
                ),
                const Divider(height: 1),
                _DateTimeRow(
                  label: 'Ends',
                  dateTime: _endDate,
                  onTap: () => _pickDateTime(false),
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
            subtitle: 'Create your own tags for discovery',
          ),
          const SizedBox(height: 8),
          _SectionCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedTags.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selectedTags.map((tag) {
                        return InputChip(
                          label: Text(tag),
                          onDeleted: () =>
                              setState(() => _selectedTags.remove(tag)),
                          backgroundColor: AppColors.surfaceAlt,
                          deleteIconColor: AppColors.secondaryText,
                          labelStyle: TextStyle(
                            color: AppColors.text,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          side: BorderSide(color: AppColors.divider),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customTagCtrl,
                          style: TextStyle(fontSize: 13, color: AppColors.text),
                          decoration: InputDecoration(
                            hintText: 'Add custom tag…',
                            hintStyle: TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 13,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: AppColors.divider),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: AppColors.divider),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: AppColors.primaryRed,
                              ),
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
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
                          if (tag.isNotEmpty && !_selectedTags.contains(tag)) {
                            setState(() {
                              _selectedTags.add(tag);
                              _customTagCtrl.clear();
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
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

          // ── Speakers ──────────────────────────────────────────────────────
          _SectionHeader(
            icon: Icons.groups_2_rounded,
            label: 'Speakers',
            subtitle: 'Optional — add speaker name, role & LinkedIn',
          ),
          const SizedBox(height: 8),
          _SectionCard(
            child: Column(
              children: [
                for (int i = 0; i < _speakers.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: AppColors.divider,
                      indent: 16,
                      endIndent: 16,
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              _Field(
                                controller: _speakers[i].nameCtrl,
                                label: 'Speaker name',
                                hint: 'e.g. Prof. Elif Yıldız',
                              ),
                              _Field(
                                controller: _speakers[i].roleCtrl,
                                label: 'Role / department',
                                hint: 'e.g. History',
                              ),
                              _Field(
                                controller: _speakers[i].linkedinCtrl,
                                label: 'LinkedIn (optional)',
                                hint: 'linkedin.com/in/…',
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.remove_circle_outline,
                            color: AppColors.secondaryText,
                            size: 22,
                          ),
                          onPressed: () => setState(() {
                            _speakers[i].dispose();
                            _speakers.removeAt(i);
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          setState(() => _speakers.add(_SpeakerEntry())),
                      icon: Icon(
                        Icons.add_rounded,
                        color: AppColors.primaryRed,
                      ),
                      label: Text(
                        'Add speaker',
                        style: TextStyle(color: AppColors.primaryRed),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.divider),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Registration ──────────────────────────────────────────────────
          _SectionHeader(
            icon: Icons.link_rounded,
            label: 'Registration',
            subtitle: 'Send attendees to your own sign-up form',
          ),
          const SizedBox(height: 8),
          _SectionCard(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  activeThumbColor: AppColors.primaryRed,
                  title: Text(
                    'External sign-up link',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  subtitle: Text(
                    'Attendees register on your form (Google Form, Eventbrite…)',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  value: _externalReg,
                  onChanged: (v) => setState(() => _externalReg = v),
                ),
                if (_externalReg)
                  _Field(
                    controller: _regUrlCtrl,
                    label: 'Sign-up URL',
                    hint: 'https://forms.gle/…',
                    onChanged: (_) => setState(() {}),
                  ),
              ],
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
                  if (i > 0) Divider(height: 1, color: AppColors.divider),
                  _ScheduleSlotEditor(
                    entry: _scheduleEntries[i],
                    index: i,
                    onRemove: () => _removeScheduleEntry(i),
                    onTimeTap: () => _pickSlotTime(_scheduleEntries[i]),
                    onChanged: () => setState(() {}),
                  ),
                ],

                // Add slot button
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
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
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            size: 16,
                            color: AppColors.secondaryText,
                          ),
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
// Hero preview + optional photo
// ─────────────────────────────────────────────────────────────────────────────

class _HeroEditor extends StatelessWidget {
  final String? imagePath;
  final String titleText;
  final ValueChanged<String?> onImageChanged;

  const _HeroEditor({
    required this.imagePath,
    required this.titleText,
    required this.onImageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 200,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage)
              Image.file(File(imagePath!), fit: BoxFit.cover)
            else
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  border: Border.all(color: AppColors.divider),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.image_outlined,
                        size: 34,
                        color: AppColors.secondaryText.withValues(alpha: 0.75),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No event image selected',
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Add an image or keep this event imageless',
                        style: TextStyle(
                          color: AppColors.secondaryText.withValues(
                            alpha: 0.75,
                          ),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (hasImage)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
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

            if (hasImage)
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
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

            Positioned(
              top: 10,
              right: 10,
              child: _PhotoEditButton(
                hasImage: hasImage,
                imagePath: imagePath,
                onChanged: onImageChanged,
              ),
            ),
          ],
        ),
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

  Future<void> _pickFromGallery(BuildContext context) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null || !context.mounted) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      uiSettings: [
        IOSUiSettings(
          title: 'Crop Photo',
          resetAspectRatioEnabled: true,
          rotateButtonsHidden: false,
        ),
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo',
          toolbarColor: AppColors.primaryRed,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: false,
          showCropGrid: true,
        ),
      ],
    );
    if (cropped != null && context.mounted) {
      onChanged(cropped.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _pickFromGallery(context),
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
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
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
                    horizontal: 10,
                    vertical: 6,
                  ),
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
                    horizontal: 8,
                    vertical: 6,
                  ),
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
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.secondaryText,
                ),
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
                color: AppColors.secondaryText,
                fontSize: 13,
              ),
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
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
                color: AppColors.secondaryText,
                fontSize: 12,
              ),
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
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
              style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
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
  final List<MentionOption>? mentionOptions;
  final ValueChanged<String>? onChanged;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.mentionOptions,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppColors.secondaryText, fontSize: 13),
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.secondaryText, fontSize: 13),
      border: InputBorder.none,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: mentionOptions == null
          ? TextField(
              controller: controller,
              maxLines: maxLines,
              onChanged: onChanged,
              style: TextStyle(fontSize: 14, color: AppColors.text),
              decoration: decoration,
            )
          : MentionTextField(
              controller: controller,
              options: mentionOptions!,
              maxLines: maxLines,
              onChanged: onChanged,
              style: TextStyle(fontSize: 14, color: AppColors.text),
              decoration: decoration,
            ),
    );
  }
}

class _DateTimeRow extends StatelessWidget {
  final String label;
  final DateTime dateTime;
  final VoidCallback onTap;
  final String? error;

  const _DateTimeRow({
    required this.label,
    required this.dateTime,
    required this.onTap,
    this.error,
  });

  String _fmtDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 52,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.text,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.lightRed,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _fmtDate(dateTime),
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primaryRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.lightRed,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _fmtTime(dateTime),
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primaryRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 4),
            Text(
              error!,
              style: const TextStyle(fontSize: 11, color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }
}
