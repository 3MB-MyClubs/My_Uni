import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../models/user.dart';
import '../services/app_colors.dart';
import '../l10n/app_localizations.dart';
import '../services/checkin_store.dart';
import '../services/event_access.dart';
import '../services/locale_service.dart';
import '../services/mock_data.dart';
import '../services/user_state.dart';

class RsvpListScreen extends StatelessWidget {
  final Event event;
  final Color color;

  const RsvpListScreen({super.key, required this.event, required this.color});

  @override
  Widget build(BuildContext context) {
    if (!canViewEventAttendance(event)) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: color,
          foregroundColor: Colors.white,
          title: Text(AppLocalizations.of(context)!.attendees),
        ),
        body: Center(
          child: Text(
            AppLocalizations.of(context)!.onlyPosterCanViewRsvps,
            style: TextStyle(color: AppColors.secondaryText),
          ),
        ),
      );
    }

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
            Text(
              AppLocalizations.of(context)!.attendees,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            Text(
              AppLocalizations.of(context)!.registeredCount(totalCount),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        elevation: 0,
      ),
      body: totalCount == 0
          ? Center(
              child: Text(
                AppLocalizations.of(context)!.noRsvpsYet,
                style: TextStyle(color: AppColors.secondaryText, fontSize: 16),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: entries.length + legacyIds.length,
              separatorBuilder: (_, _) => Divider(height: 1, indent: 72),
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
                    name: AppLocalizations.of(context)!.unknownUser,
                    email: '',
                    password: '',
                    role: '',
                    subscribedClubIds: [],
                  ),
                );

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Text(
                      () {
                        final n = userState.displayNameFor(user.id, user.name);
                        return n.isNotEmpty ? n[0].toUpperCase() : '?';
                      }(),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    userState.displayNameFor(user.id, user.name),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: timestamp != null
                      ? Text(
                          AppLocalizations.of(
                            context,
                          )!.rsvpdAt(_formatTimestamp(timestamp)),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        )
                      : null,
                  trailing: ListenableBuilder(
                    listenable: checkinStore,
                    builder: (_, _) {
                      if (!checkinStore.isCheckedIn(event.id, userId)) {
                        return const SizedBox.shrink();
                      }
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.all(Radius.circular(100)),
                          border: Border.all(
                            color: color.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded, size: 12, color: color),
                            const SizedBox(width: 3),
                            Text(
                              AppLocalizations.of(context)!.checkedIn,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '${DateFormat.MMM(localeService.languageCode).format(dt)} ${dt.day}, ${dt.year}  ·  $h:$m $period';
  }
}
