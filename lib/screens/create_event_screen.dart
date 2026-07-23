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
import '../services/photo_upload_quality.dart';
import '../services/supabase_event_service.dart';
import '../services/user_state.dart';
import '../widgets/app_network_image.dart';
import '../widgets/club_avatar.dart';
import '../widgets/loading_skeleton.dart';
import '../widgets/mention_text_field.dart';
import '../l10n/app_localizations.dart';

bool _isRemoteEventImagePath(String path) =>
    path.startsWith('http://') || path.startsWith('https://');

List<String> _monthLabels(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return [
    l10n.monthJan,
    l10n.monthFeb,
    l10n.monthMar,
    l10n.monthApr,
    l10n.monthMay,
    l10n.monthJun,
    l10n.monthJul,
    l10n.monthAug,
    l10n.monthSep,
    l10n.monthOct,
    l10n.monthNov,
    l10n.monthDec,
  ];
}

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

  // Wizard navigation
  final PageController _pageController = PageController();
  int _step = 0;
  static const int _stepCount = 4;
  List<String> get _stepTitles {
    final l10n = AppLocalizations.of(context)!;
    return [
      l10n.eventStepBasics,
      l10n.eventStepWhen,
      l10n.eventStepDetails,
      l10n.eventStepReview,
    ];
  }

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

  // ── Wizard navigation ────────────────────────────────────────────────────

  // Whether the user may move past [step]. Required fields are validated on the
  // step that collects them so they're always satisfied before Review.
  bool _canAdvanceFrom(int step) {
    switch (step) {
      case 0:
        return _titleController.text.trim().isNotEmpty &&
            _locationController.text.trim().isNotEmpty;
      case 1:
        return _endDate.isAfter(_startDate);
      case 3:
        return _canPost;
      default:
        return true;
    }
  }

  // Reason shown when a Next is blocked, per step.
  String _blockedReason(int step) {
    final l10n = AppLocalizations.of(context)!;
    if (step == 0) return l10n.addTitleLocationToContinue;
    if (step == 1) return l10n.endTimeAfterStartTime;
    return l10n.completeRequiredFields;
  }

  void _goToStep(int target) {
    final clamped = target.clamp(0, _stepCount - 1);
    _pageController.animateToPage(
      clamped,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOut,
    );
  }

  void _next() {
    if (_step >= _stepCount - 1) return;
    if (!_canAdvanceFrom(_step)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(_blockedReason(_step)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    FocusScope.of(context).unfocus();
    _goToStep(_step + 1);
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
      return;
    }
    FocusScope.of(context).unfocus();
    _goToStep(_step - 1);
  }

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
        label: userState.displayNameFor(user.id, user.name),
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
                      AppLocalizations.of(context)!.cancel,
                      style: TextStyle(color: AppColors.secondaryText),
                    ),
                  ),
                  Text(
                    isStart
                        ? AppLocalizations.of(context)!.startsLabel
                        : AppLocalizations.of(context)!.endsLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, temp),
                    child: Text(
                      AppLocalizations.of(context)!.done,
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
                      AppLocalizations.of(context)!.cancel,
                      style: TextStyle(color: AppColors.secondaryText),
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context)!.time,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.pop(ctx, TimeOfDay.fromDateTime(temp)),
                    child: Text(
                      AppLocalizations.of(context)!.done,
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
      Event saved;
      try {
        saved = await supabaseEventService.updateEvent(
          updated,
          previousImagePath: ev.imagePath,
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.couldNotSaveEventSupabase,
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        return;
      }

      final ok = contentStore.updateEvent(
        saved,
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
            SnackBar(
              content: Text(AppLocalizations.of(context)!.couldNotSaveChanges),
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
      contentStore.notifyContentChanged();
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
    final l10n = AppLocalizations.of(context)!;
    final text = error.toString();
    if (text.contains('row-level security') ||
        text.contains('permission denied') ||
        text.contains('42501')) {
      return l10n.publishErrorRlsPolicyEvent;
    }
    if (text.contains('column') ||
        text.contains('schedule') ||
        text.contains('speakers')) {
      return l10n.publishErrorMigrationEvent;
    }
    if (text.contains('event-images') || text.contains('storage')) {
      return l10n.publishErrorStorageEvent;
    }
    return l10n.publishErrorGenericEvent;
  }

  @override
  void dispose() {
    _pageController.dispose();
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
          onPressed: _back,
          child: Text(
            _step == 0
                ? AppLocalizations.of(context)!.cancel
                : AppLocalizations.of(context)!.back,
            style: TextStyle(color: AppColors.secondaryText),
          ),
        ),
        leadingWidth: 80,
        title: Text(
          _isEditing
              ? AppLocalizations.of(context)!.editEventTitle
              : AppLocalizations.of(context)!.newEventTitle,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildProgress(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _step = i),
              children: [
                _buildStepBasics(),
                _buildStepWhen(),
                _buildStepDetails(),
                _buildStepReview(),
              ],
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ── Step 1: Basics ─────────────────────────────────────────────────────────
  Widget _buildStepBasics() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  label: AppLocalizations.of(context)!.eventTitleLabel,
                  hint: AppLocalizations.of(context)!.eventTitleHint,
                  onChanged: (_) => setState(() {}),
                ),
                const Divider(height: 1),
                _Field(
                  controller: _locationController,
                  label: AppLocalizations.of(context)!.locationLabel,
                  hint: AppLocalizations.of(context)!.locationHint,
                  onChanged: (_) => setState(() {}),
                ),
                const Divider(height: 1),
                _Field(
                  controller: _descController,
                  label: AppLocalizations.of(context)!.descriptionLabel,
                  hint: AppLocalizations.of(context)!.eventDescriptionHint,
                  maxLines: 4,
                  mentionOptions: _mentionOptions,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2: When ─────────────────────────────────────────────────────────
  Widget _buildStepWhen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.event_rounded,
            label: AppLocalizations.of(context)!.eventStepWhen,
            subtitle: AppLocalizations.of(context)!.whenSectionSubtitle,
          ),
          const SizedBox(height: 8),
          // ── Date & time ──────────────────────────────────────────────────
          _SectionCard(
            child: Column(
              children: [
                _DateTimeRow(
                  label: AppLocalizations.of(context)!.startsLabel,
                  dateTime: _startDate,
                  onTap: () => _pickDateTime(true),
                ),
                const Divider(height: 1),
                _DateTimeRow(
                  label: AppLocalizations.of(context)!.endsLabel,
                  dateTime: _endDate,
                  onTap: () => _pickDateTime(false),
                  error: !_endDate.isAfter(_startDate)
                      ? AppLocalizations.of(context)!.endMustBeAfterStartShort
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 3: Details (optional) ───────────────────────────────────────────
  Widget _buildStepDetails() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Tags ─────────────────────────────────────────────────────────
          _SectionHeader(
            icon: Icons.label_outline_rounded,
            label: AppLocalizations.of(context)!.tagsLabel,
            subtitle: AppLocalizations.of(context)!.tagsSectionSubtitle,
            badge: const _OptionalBadge(),
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
                            hintText: AppLocalizations.of(
                              context,
                            )!.addCustomTagHint,
                            hintStyle: TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 13,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(10),
                              ),
                              borderSide: BorderSide(color: AppColors.divider),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(10),
                              ),
                              borderSide: BorderSide(color: AppColors.divider),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(10),
                              ),
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
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.add,
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
            label: AppLocalizations.of(context)!.speakersLabel,
            subtitle: AppLocalizations.of(context)!.speakersSectionSubtitle,
            badge: const _OptionalBadge(),
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
                                label: AppLocalizations.of(
                                  context,
                                )!.speakerNameLabel,
                                hint: AppLocalizations.of(
                                  context,
                                )!.speakerNameHint,
                              ),
                              _Field(
                                controller: _speakers[i].roleCtrl,
                                label: AppLocalizations.of(
                                  context,
                                )!.roleOrDepartmentLabel,
                                hint: AppLocalizations.of(
                                  context,
                                )!.roleDeptHint,
                              ),
                              _Field(
                                controller: _speakers[i].linkedinCtrl,
                                label: AppLocalizations.of(
                                  context,
                                )!.linkedinOptionalLabel,
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
                        AppLocalizations.of(context)!.addSpeaker,
                        style: TextStyle(color: AppColors.primaryRed),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.divider),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
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
            label: AppLocalizations.of(context)!.registrationLabel,
            subtitle: AppLocalizations.of(context)!.registrationSectionSubtitle,
            badge: const _OptionalBadge(),
          ),
          const SizedBox(height: 8),
          _SectionCard(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  activeThumbColor: AppColors.primaryRed,
                  title: Text(
                    AppLocalizations.of(context)!.externalSignupLinkTitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  subtitle: Text(
                    AppLocalizations.of(context)!.externalSignupLinkSubtitle,
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
                    label: AppLocalizations.of(context)!.signupUrlLabel,
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
            label: AppLocalizations.of(context)!.programmeLabel,
            subtitle: AppLocalizations.of(context)!.programmeSectionSubtitle,
            badge: const _OptionalBadge(),
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
                        borderRadius: BorderRadius.all(Radius.circular(10)),
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
                            AppLocalizations.of(context)!.addTimeSlot,
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

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Step 4: Review ───────────────────────────────────────────────────────
  Widget _buildStepReview() {
    final clubId = widget.existing?.clubId ?? _adminClubId;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.visibility_outlined,
            label: AppLocalizations.of(context)!.eventStepReview,
            subtitle: AppLocalizations.of(context)!.reviewSectionSubtitle,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _goToStep(0),
                icon: const Icon(Icons.edit_outlined, size: 13),
                label: Text(AppLocalizations.of(context)!.eventStepBasics),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(color: AppColors.divider),
                  foregroundColor: AppColors.text,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _goToStep(1),
                icon: const Icon(Icons.schedule_outlined, size: 13),
                label: Text(AppLocalizations.of(context)!.eventStepWhen),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(color: AppColors.divider),
                  foregroundColor: AppColors.text,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _goToStep(2),
                icon: const Icon(Icons.settings_outlined, size: 13),
                label: Text(AppLocalizations.of(context)!.eventStepDetails),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(color: AppColors.divider),
                  foregroundColor: AppColors.text,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _EventPreviewCard(
            imagePath: _imagePath,
            title: _titleController.text.trim(),
            location: _locationController.text.trim(),
            startDate: _startDate,
            endDate: _endDate,
            tags: _selectedTags,
            clubId: clubId,
            hasRegistration: _externalReg && _regUrlCtrl.text.trim().isNotEmpty,
          ),
          const SizedBox(height: 16),
          if (!_canPost)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.lightRed,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: AppColors.primaryRed,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(
                        context,
                      )!.addRequiredFieldsBeforePublish,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.text,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              _isEditing
                  ? AppLocalizations.of(context)!.tapSaveChangesHint
                  : AppLocalizations.of(context)!.tapPublishEventHint,
              style: TextStyle(fontSize: 12.5, color: AppColors.secondaryText),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Progress header ──────────────────────────────────────────────────────
  Widget _buildProgress() {
    return Container(
      width: double.infinity,
      color: AppColors.card,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(_stepCount, (i) {
              final filled = i <= _step;
              // In edit mode every step is reachable; in create mode only
              // already-visited steps can be jumped to.
              final canTap = _isEditing || i <= _step;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: canTap ? () => _goToStep(i) : null,
                  child: Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: filled
                                ? AppColors.primaryRed
                                : AppColors.divider,
                            borderRadius: BorderRadius.all(Radius.circular(2)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _stepTitles[i],
                          style: TextStyle(
                            fontSize: 10,
                            color: i == _step
                                ? AppColors.primaryRed
                                : i < _step
                                ? AppColors.text
                                : AppColors.secondaryText,
                            fontWeight: i == _step
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(
              context,
            )!.stepProgressLabel(_step + 1, _stepCount, _stepTitles[_step]),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom navigation bar ──────────────────────────────────────────────────
  Widget _buildBottomBar() {
    final isLast = _step == _stepCount - 1;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            OutlinedButton(
              onPressed: _back,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.divider),
                foregroundColor: AppColors.text,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
              ),
              child: Text(
                _step == 0
                    ? AppLocalizations.of(context)!.cancel
                    : AppLocalizations.of(context)!.back,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: isLast ? _buildPublishButton() : _buildNextButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextButton() {
    final enabled = _canAdvanceFrom(_step);
    return ElevatedButton(
      // Always tappable — when blocked, _next() surfaces a reason via SnackBar.
      onPressed: _next,
      style: ElevatedButton.styleFrom(
        backgroundColor: enabled ? AppColors.primaryRed : AppColors.lightRed,
        foregroundColor: enabled ? Colors.white : AppColors.secondaryText,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
      child: Text(
        AppLocalizations.of(context)!.next,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
    );
  }

  Widget _buildPublishButton() {
    final enabled = _canPost && !_isPosting;
    return ElevatedButton(
      onPressed: enabled ? () => _post() : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.lightRed,
        disabledForegroundColor: AppColors.secondaryText,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
      child: _isPosting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              _isEditing
                  ? AppLocalizations.of(context)!.saveChangesButton
                  : AppLocalizations.of(context)!.publishEventButton,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live preview card — how the event will appear (Review step)
// ─────────────────────────────────────────────────────────────────────────────

class _EventPreviewCard extends StatelessWidget {
  final String? imagePath;
  final String title;
  final String location;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> tags;
  final String? clubId;
  final bool hasRegistration;

  const _EventPreviewCard({
    required this.imagePath,
    required this.title,
    required this.location,
    required this.startDate,
    required this.endDate,
    required this.tags,
    required this.clubId,
    required this.hasRegistration,
  });

  String _t(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _timeLine(BuildContext context) {
    final months = _monthLabels(context);
    final sameDay =
        startDate.year == endDate.year &&
        startDate.month == endDate.month &&
        startDate.day == endDate.day;
    if (sameDay) {
      return '${months[startDate.month - 1]} ${startDate.day} · ${_t(startDate)} – ${_t(endDate)}';
    }
    return '${months[startDate.month - 1]} ${startDate.day}, ${_t(startDate)} → '
        '${months[endDate.month - 1]} ${endDate.day}, ${_t(endDate)}';
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null && imagePath!.isNotEmpty;
    String clubName = AppLocalizations.of(context)!.yourClubFallback;
    if (clubId != null && clubId!.isNotEmpty) {
      for (final c in clubs) {
        if (c.id == clubId) {
          clubName = c.name;
          break;
        }
      }
    }
    final months = _monthLabels(context);
    final dateChip = '${months[startDate.month - 1]} ${startDate.day}';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage)
            SizedBox(
              height: 150,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _EventPreviewImage(path: imagePath!),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x8C000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 12,
                    child: Text(
                      title.isEmpty
                          ? AppLocalizations.of(context)!.eventTitlePlaceholder
                          : title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClubAvatar(
                      clubId: clubId ?? '',
                      clubName: clubName,
                      color: AppColors.primaryRed,
                      imageUrl: clubs.any((club) => club.id == clubId)
                          ? clubs
                                .firstWhere((club) => club.id == clubId)
                                .logoUrl
                          : null,
                      size: 36,
                      fontSize: 15,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        clubName,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lightRed,
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      child: Text(
                        dateChip,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryRed,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!hasImage) ...[
                  const SizedBox(height: 12),
                  Text(
                    title.isEmpty
                        ? AppLocalizations.of(context)!.eventTitlePlaceholder
                        : title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: title.isEmpty
                          ? AppColors.secondaryText
                          : AppColors.text,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: AppColors.secondaryText,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _timeLine(context),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.secondaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: AppColors.secondaryText,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        location.isEmpty
                            ? AppLocalizations.of(context)!.locationLabel
                            : location,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: location.isEmpty
                              ? AppColors.secondaryText.withValues(alpha: 0.7)
                              : AppColors.secondaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: tags
                        .map(
                          (t) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              borderRadius: BorderRadius.all(
                                Radius.circular(100),
                              ),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Text(
                              t,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                if (hasRegistration) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.link_rounded,
                        size: 14,
                        color: AppColors.primaryRed,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        AppLocalizations.of(context)!.externalSignupBadge,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryRed,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
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
      borderRadius: BorderRadius.all(Radius.circular(16)),
      child: SizedBox(
        height: 200,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage)
              _EventPreviewImage(path: imagePath!)
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
                        AppLocalizations.of(context)!.noEventImageSelected,
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppLocalizations.of(context)!.addImageOrKeepImageless,
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
                  titleText.isEmpty
                      ? AppLocalizations.of(
                          context,
                        )!.eventTitlePreviewPlaceholder
                      : titleText,
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

class _EventPreviewImage extends StatelessWidget {
  final String path;

  const _EventPreviewImage({required this.path});

  @override
  Widget build(BuildContext context) {
    if (_isRemoteEventImagePath(path)) {
      return AppNetworkImage(
        url: path,
        fit: BoxFit.cover,
        cacheWidth: 500,
        placeholderBuilder: (_) => const SkeletonBox(),
        errorBuilder: (_) => Container(
          color: AppColors.surfaceAlt,
          alignment: Alignment.center,
          child: Icon(
            Icons.image_not_supported_outlined,
            color: AppColors.secondaryText.withValues(alpha: 0.45),
            size: 28,
          ),
        ),
      );
    }
    return Image.file(File(path), fit: BoxFit.cover);
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
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !context.mounted) return;

    final cropPhotoTitle = AppLocalizations.of(context)!.cropPhotoTitle;
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      maxWidth: PhotoUploadQuality.contentMaxDimension,
      maxHeight: PhotoUploadQuality.contentMaxDimension,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: PhotoUploadQuality.jpegQuality,
      uiSettings: [
        IOSUiSettings(
          title: cropPhotoTitle,
          resetAspectRatioEnabled: true,
          rotateButtonsHidden: false,
        ),
        AndroidUiSettings(
          toolbarTitle: cropPhotoTitle,
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
          borderRadius: BorderRadius.all(Radius.circular(20)),
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
              hasImage
                  ? AppLocalizations.of(context)!.changeEventPhoto
                  : AppLocalizations.of(context)!.addPhoto,
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
                    borderRadius: BorderRadius.all(Radius.circular(8)),
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
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    border: Border.all(
                      color: entry.isHighlighted
                          ? AppColors.primaryRed.withValues(alpha: 0.4)
                          : AppColors.divider,
                    ),
                  ),
                  child: Text(
                    '★ ${AppLocalizations.of(context)!.highlight}',
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
              hintText: AppLocalizations.of(context)!.sessionTitleRequiredHint,
              hintStyle: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 13,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
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
              hintText: AppLocalizations.of(
                context,
              )!.subtitleSpeakerOptionalHint,
              hintStyle: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
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
  final Widget? badge;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.subtitle,
    this.badge,
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
            Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                if (badge != null) ...[const SizedBox(width: 6), badge!],
              ],
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

class _OptionalBadge extends StatelessWidget {
  const _OptionalBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.all(Radius.circular(4)),
        border: Border.all(color: AppColors.divider),
      ),
      child: Text(
        AppLocalizations.of(context)!.optional,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: AppColors.secondaryText,
        ),
      ),
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
        borderRadius: BorderRadius.all(Radius.circular(14)),
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

  String _fmtDate(BuildContext context, DateTime dt) {
    final months = _monthLabels(context);
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
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  child: Text(
                    _fmtDate(context, dateTime),
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
                    borderRadius: BorderRadius.all(Radius.circular(8)),
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
