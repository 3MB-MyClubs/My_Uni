import 'package:flutter/material.dart';
import '../models/event.dart';
import '../models/user.dart';
import '../services/app_colors.dart';
import '../services/mock_data.dart';

class RsvpListScreen extends StatelessWidget {
  final Event event;
  final Color color;

  const RsvpListScreen({super.key, required this.event, required this.color});

  @override
  Widget build(BuildContext context) {
    // Sort attendees by RSVP timestamp (earliest first); fall back to userId sort
    final entries = event.rsvpTimestamps.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    // Users who are in attendeeUserIds but have no timestamp (legacy / seed data)
    final legacyIds = event.attendeeUserIds
        .where((id) => !event.rsvpTimestamps.containsKey(id))
        .toList();

    final totalCount = event.attendeeUserIds.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: color,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Attendees',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            Text('$totalCount registered',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        elevation: 0,
      ),
      body: totalCount == 0
          ? const Center(
              child: Text(
                'No RSVPs yet.',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 16),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: entries.length + legacyIds.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 72),
              itemBuilder: (context, i) {
                final String userId;
                final DateTime? timestamp;

                if (i < entries.length) {
                  userId = entries[i].key;
                  timestamp = DateTime.tryParse(entries[i].value);
                } else {
                  userId = legacyIds[i - entries.length];
                  timestamp = null;
                }

                final user = users.firstWhere(
                  (u) => u.id == userId,
                  orElse: () => User(
                    id: userId,
                    name: 'Unknown User',
                    email: '',
                    password: '',
                    role: '',
                    subscribedClubIds: [],
                  ),
                );

                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Text(
                      user.name.isNotEmpty
                          ? user.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    user.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                        fontSize: 14),
                  ),
                  subtitle: timestamp != null
                      ? Text(
                          'RSVP\'d ${_formatTimestamp(timestamp)}',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.secondaryText),
                        )
                      : null,
                );
              },
            ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  ·  $h:$m $period';
  }
}
