import 'package:flutter/material.dart';
import '../models/event.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/mock_data.dart';

class CreateEventScreen extends StatefulWidget {
  final VoidCallback? onCreated;
  const CreateEventScreen({super.key, this.onCreated});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();

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

  void _post() {
    final clubId = _adminClubId;
    if (clubId == null) return;

    final newEvent = Event(
      id: 'ev_${DateTime.now().millisecondsSinceEpoch}',
      clubId: clubId,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      location: _locationController.text.trim(),
      dateTime: _startDate,
      endTime: _endDate,
      attendeeUserIds: [],
    );

    events.add(newEvent);
    widget.onCreated?.call();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

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
          child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
        ),
        leadingWidth: 80,
        title: const Text('New Event', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        centerTitle: true,
        actions: [
          ValueListenableBuilder(
            valueListenable: _titleController,
            builder: (ctx, value, child) => TextButton(
              onPressed: _canPost ? _post : null,
              child: Text(
                'Post',
                style: TextStyle(
                  color: _canPost ? AppColors.primaryRed : AppColors.secondaryText,
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
          _SectionCard(
            child: Column(
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
                  hint: 'e.g. Main Campus, SOS B101',
                  icon: Icons.location_on_outlined,
                  onChanged: (_) => setState(() {}),
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
                  error: !_endDate.isAfter(_startDate) ? 'End must be after start' : null,
                ),
              ],
            ),
          ),
        ],
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
  final IconData? icon;
  final ValueChanged<String>? onChanged;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.icon,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Icon(icon, size: 18, color: AppColors.secondaryText),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 14, color: AppColors.text),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: const TextStyle(color: AppColors.secondaryText, fontSize: 13),
                hintText: hint,
                hintStyle: const TextStyle(color: AppColors.secondaryText, fontSize: 13),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
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
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 52,
                child: Text(label,
                    style: const TextStyle(fontSize: 14, color: AppColors.text, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onDateTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.lightRed,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_fmtDate(dateTime),
                      style: const TextStyle(fontSize: 13, color: AppColors.primaryRed, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onTimeTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.lightRed,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_fmtTime(dateTime),
                      style: const TextStyle(fontSize: 13, color: AppColors.primaryRed, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 4),
            Text(error!, style: const TextStyle(fontSize: 11, color: Colors.red)),
          ],
        ],
      ),
    );
  }
}
