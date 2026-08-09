import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/event.dart';
import '../models/user.dart';
import '../services/app_colors.dart';
import '../services/mock_data.dart';
import '../services/people_service.dart';
import '../services/user_state.dart';
import '../widgets/user_avatar.dart';
import 'user_profile_screen.dart';

/// Public, profile-focused attendee list opened from the student event detail.
/// Organizer-only RSVP timestamps and check-in state stay in the private
/// organizer attendance screen.
class EventAttendeeListScreen extends StatefulWidget {
  const EventAttendeeListScreen({
    super.key,
    required this.event,
    required this.color,
  });

  final Event event;
  final Color color;

  @override
  State<EventAttendeeListScreen> createState() =>
      _EventAttendeeListScreenState();
}

class _EventAttendeeListScreenState extends State<EventAttendeeListScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _hydrateAttendees();
  }

  Future<void> _hydrateAttendees() async {
    try {
      await peopleService.hydrateProfilesByIds(widget.event.attendeeUserIds);
    } catch (_) {
      // The list remains useful with locally known profiles and initials.
    }
    if (mounted) setState(() => _loading = false);
  }

  Map<String, User> get _knownPeople => {
    for (final user in users) user.id: user,
    for (final user in peopleService.cachedPeople) user.id: user,
  };

  User _userFor(String id, String fallbackName) {
    return _knownPeople[id] ??
        User(
          id: id,
          name: fallbackName,
          email: '',
          password: '',
          role: 'student',
          subscribedClubIds: const [],
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final attendeeIds = widget.event.attendeeUserIds.toSet().toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.attendees,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            Text(
              l10n.attendingCount(attendeeIds.length),
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: _loading && attendeeIds.isNotEmpty
          ? Center(child: CircularProgressIndicator(color: widget.color))
          : attendeeIds.isEmpty
          ? Center(
              child: Text(
                l10n.noRsvpsYet,
                style: TextStyle(color: AppColors.secondaryText, fontSize: 15),
              ),
            )
          : ListView.separated(
              key: const ValueKey('event-public-attendee-list'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: attendeeIds.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, indent: 60, color: AppColors.divider),
              itemBuilder: (context, index) {
                final id = attendeeIds[index];
                final user = _userFor(id, l10n.studentProfile);
                final isKnown = _knownPeople.containsKey(id);
                final displayName = userState.displayNameFor(id, user.name);
                final detail = userState.academicSummaryFor(id);

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 5,
                  ),
                  onTap: isKnown
                      ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserProfileScreen(user: user),
                          ),
                        )
                      : null,
                  leading: UserAvatar(
                    userId: id,
                    name: displayName,
                    size: 46,
                    fontSize: 15,
                    backgroundColor: widget.color.withValues(alpha: 0.14),
                    textColor: widget.color,
                  ),
                  title: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: detail.isEmpty
                      ? null
                      : Text(
                          detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 12.5,
                          ),
                        ),
                  trailing: isKnown
                      ? Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.secondaryText,
                        )
                      : null,
                );
              },
            ),
    );
  }
}
