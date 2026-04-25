import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:add_2_calendar/add_2_calendar.dart' as cal;
import '../models/recommendation.dart';
import '../models/event.dart';
import '../models/club.dart';
import '../models/user.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/mock_data.dart';
import '../services/rsvp_store.dart';
import '../widgets/rsvp_button.dart';
import '../services/personalization_service.dart';
import '../services/recommendation_service.dart';
import '../services/user_state.dart';
import '../services/user_prefs_service.dart';
import '../widgets/club_avatar.dart';
import 'chat_screen.dart';
import 'club_profile_screen.dart';
import 'event_detail_screen.dart';
import 'ku_day_onboarding_sheet.dart';
import 'user_profile_screen.dart';
import '../widgets/campus_pulse_card.dart';

// ── Color palette matching the rest of the app ───────────────────────────────
const _kColors = [
  Color(0xFFB41C18),
  Color(0xFF1565C0),
  Color(0xFF2E7D32),
  Color(0xFF6A1B9A),
  Color(0xFFE65100),
  Color(0xFF00838F),
];

Color _colorFor(String id) {
  final idx = clubs.indexWhere((c) => c.id == id);
  return _kColors[(idx < 0 ? math.Random(id.hashCode).nextInt(6) : idx) %
      _kColors.length];
}

// ── Section header labels ─────────────────────────────────────────────────────
const _slotLabel = {
  RecType.happeningNow: 'Happening Now',
  RecType.bestThisWeek: 'Best for You This Week',
  RecType.suggestFollow: 'You Might Like',
};

const _slotIcon = {
  RecType.happeningNow: Icons.radio_button_on_rounded,
  RecType.bestThisWeek: Icons.star_rounded,
  RecType.suggestFollow: Icons.person_add_rounded,
};

// ═════════════════════════════════════════════════════════════════════════════
// Main section widget
// ═════════════════════════════════════════════════════════════════════════════

class KuDaySection extends StatefulWidget {
  const KuDaySection({super.key});

  @override
  State<KuDaySection> createState() => _KuDaySectionState();
}

class _KuDaySectionState extends State<KuDaySection> {
  @override
  void initState() {
    super.initState();
    // Show onboarding after first frame if not complete.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!personalizationService.onboardingComplete && mounted) {
        showKuDayOnboarding(context).then((_) {
          if (mounted) setState(() {});
        });
      }
    });
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final recs = recommendationService.getRecommendations();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryRed,
                      AppColors.primaryRed.withValues(alpha: 0.75),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Your KU Day',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () =>
                    showKuDayOnboarding(context).then((_) => setState(() {})),
                child: Text(
                  'Tune',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primaryRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Digest strip ────────────────────────────────────────────────────
        _DigestStrip(onRefresh: _refresh),
        const SizedBox(height: 10),

        // ── Campus Pulse heatmap ─────────────────────────────────────────────
        const CampusPulseCard(),
        const SizedBox(height: 4),

        // ── Recommendation cards ─────────────────────────────────────────────
        if (recs.isEmpty)
          _EmptyState(
            onSetup: () =>
                showKuDayOnboarding(context).then((_) => setState(() {})),
          )
        else
          ...recs.map((rec) => _RecCard(rec: rec, onChanged: _refresh)),

        Divider(height: 1, color: AppColors.divider),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Digest strip — compact summary at the top of the section
// ═════════════════════════════════════════════════════════════════════════════

class _DigestStrip extends StatelessWidget {
  final VoidCallback onRefresh;
  const _DigestStrip({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final liveCount = events
        .where((e) => !e.dateTime.isAfter(now) && e.endTime.isAfter(now))
        .length;
    final todayCount = events
        .where(
          (e) =>
              e.dateTime.isAfter(now) &&
              e.dateTime.day == now.day &&
              e.dateTime.month == now.month,
        )
        .length;
    final weekCount = events
        .where(
          (e) =>
              e.dateTime.isAfter(now) &&
              e.dateTime.isBefore(now.add(const Duration(days: 7))),
        )
        .length;

    final parts = <String>[];
    if (liveCount > 0) parts.add('$liveCount live now');
    if (todayCount > 0) parts.add('$todayCount today');
    if (weekCount > 0) parts.add('$weekCount this week');

    if (parts.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 15,
            color: AppColors.primaryRed,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Campus today: ${parts.join(' · ')}',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.text,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Empty state
// ═════════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final VoidCallback onSetup;
  const _EmptyState({required this.onSetup});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.tune_rounded, color: AppColors.secondaryText),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tell us your interests and we\'ll personalise this for you.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.secondaryText,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onSetup,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Set up',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Recommendation card
// ═════════════════════════════════════════════════════════════════════════════

class _RecCard extends StatefulWidget {
  final Recommendation rec;
  final VoidCallback onChanged;

  const _RecCard({required this.rec, required this.onChanged});

  @override
  State<_RecCard> createState() => _RecCardState();
}

class _RecCardState extends State<_RecCard> {
  bool _hidden = false;

  String get _userId =>
      authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

  Future<void> _hide() async {
    setState(() => _hidden = true);
    await personalizationService.hideItem(_userId, widget.rec.id);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();

    final rec = widget.rec;
    final color = rec.targetType == RecTargetType.event
        ? _colorFor((rec.data as Event).clubId)
        : rec.targetType == RecTargetType.club
        ? _colorFor(rec.id)
        : AppColors.primaryRed;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Slot label row ──
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
              child: Row(
                children: [
                  Icon(
                    _slotIcon[rec.type],
                    size: 13,
                    color: rec.type == RecType.happeningNow
                        ? Colors.red
                        : color,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _slotLabel[rec.type]!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: rec.type == RecType.happeningNow
                          ? Colors.red
                          : color,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _hide,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _buildBody(context, rec, color),
            ),

            // ── Reason line ──
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 12,
                    color: AppColors.secondaryText,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      rec.reason,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.secondaryText,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Action buttons ──
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _buildActions(context, rec, color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, Recommendation rec, Color color) {
    switch (rec.targetType) {
      case RecTargetType.event:
        return _EventBody(event: rec.data as Event, color: color);
      case RecTargetType.club:
        return _ClubBody(club: rec.data as Club, color: color);
      case RecTargetType.person:
        return _PersonBody(user: rec.data as User, color: color);
    }
  }

  Widget _buildActions(BuildContext context, Recommendation rec, Color color) {
    switch (rec.targetType) {
      case RecTargetType.event:
        return _EventActions(
          event: rec.data as Event,
          color: color,
          userId: _userId,
          onChanged: widget.onChanged,
          onHide: _hide,
        );
      case RecTargetType.club:
        return _ClubActions(
          club: rec.data as Club,
          color: color,
          userId: _userId,
          onChanged: widget.onChanged,
          onHide: _hide,
        );
      case RecTargetType.person:
        return _PersonActions(
          user: rec.data as User,
          color: color,
          userId: _userId,
          onChanged: widget.onChanged,
          onHide: _hide,
        );
    }
  }
}

// ── Event body ──────────────────────────────────────────────────────────────

class _EventBody extends StatelessWidget {
  final Event event;
  final Color color;
  const _EventBody({required this.event, required this.color});

  bool get _isCurrentAdminEventOwner {
    final admin = authService.currentAdmin;
    if (admin == null) return false;
    try {
      return clubs.firstWhere((c) => c.adminUserIds.contains(admin.id)).id ==
          event.clubId;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isLive = !event.dateTime.isAfter(now) && event.endTime.isAfter(now);
    final daysAway = event.dateTime.difference(now).inDays;
    final timeLabel = isLive
        ? 'Happening now'
        : daysAway == 0
        ? 'Today'
        : daysAway == 1
        ? 'Tomorrow'
        : 'In $daysAway days';

    final club = clubs.firstWhere(
      (c) => c.id == event.clubId,
      orElse: () => clubs.first,
    );

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventDetailScreen(event: event, color: color),
        ),
      ),
      child: Row(
        children: [
          ClubAvatar(
            clubId: club.id,
            clubName: club.name,
            color: color,
            size: 44,
            fontSize: 20,
            shape: 'circle',
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (isLive) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        '$timeLabel · ${event.location}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (_isCurrentAdminEventOwner)
                  ListenableBuilder(
                    listenable: rsvpStore,
                    builder: (context, _) {
                      if (event.attendeeUserIds.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '${event.attendeeUserIds.length} attending',
                          style: TextStyle(
                            fontSize: 11,
                            color: color.withValues(alpha: 0.8),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: AppColors.secondaryText,
          ),
        ],
      ),
    );
  }
}

// ── Club body ────────────────────────────────────────────────────────────────

class _ClubBody extends StatelessWidget {
  final Club club;
  final Color color;
  const _ClubBody({required this.club, required this.color});

  @override
  Widget build(BuildContext context) {
    final memberCount = users
        .where((u) => u.subscribedClubIds.contains(club.id))
        .length;
    final shortName = _shortClubName(club.name);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClubProfileScreen(club: club, color: color),
        ),
      ),
      child: Row(
        children: [
          ClubAvatar(
            clubId: club.id,
            clubName: club.name,
            color: color,
            size: 44,
            fontSize: 20,
            shape: 'circle',
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shortName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$memberCount members',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  club.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: AppColors.secondaryText,
          ),
        ],
      ),
    );
  }
}

// ── Person body ──────────────────────────────────────────────────────────────

class _PersonBody extends StatelessWidget {
  final User user;
  final Color color;
  const _PersonBody({required this.user, required this.color});

  @override
  Widget build(BuildContext context) {
    final sharedClubs = user.subscribedClubIds
        .where(userState.followedClubIds.contains)
        .map(
          (id) =>
              clubs.firstWhere((c) => c.id == id, orElse: () => clubs.first),
        )
        .take(2)
        .map((c) => _shortClubName(c.name))
        .join(', ');

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => UserProfileScreen(user: user)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                user.name[0],
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.text,
                  ),
                ),
                if (sharedClubs.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      sharedClubs,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: AppColors.secondaryText,
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Action button rows
// ═════════════════════════════════════════════════════════════════════════════

class _EventActions extends StatefulWidget {
  final Event event;
  final Color color;
  final String userId;
  final VoidCallback onChanged;
  final VoidCallback onHide;

  const _EventActions({
    required this.event,
    required this.color,
    required this.userId,
    required this.onChanged,
    required this.onHide,
  });

  @override
  State<_EventActions> createState() => _EventActionsState();
}

class _EventActionsState extends State<_EventActions> {
  late bool _reminded;

  @override
  void initState() {
    super.initState();
    // Seed global store so this card stays in sync with all other screens
    rsvpStore.seed(
      widget.event.id,
      widget.event.attendeeUserIds.contains(widget.userId),
    );
    _reminded = personalizationService.isReminded(widget.event.id);
  }

  Future<void> _toggleRemind() async {
    if (_reminded) {
      await personalizationService.unremindEvent(
        widget.userId,
        widget.event.id,
      );
    } else {
      await personalizationService.remindEvent(widget.userId, widget.event.id);
    }
    setState(() => _reminded = !_reminded);
  }

  void _addToCalendar() {
    final calEvent = cal.Event(
      title: widget.event.title,
      description: widget.event.description,
      location: widget.event.location,
      startDate: widget.event.dateTime,
      endDate: widget.event.endTime,
      allDay: false,
    );
    cal.Add2Calendar.addEvent2Cal(calEvent);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // RSVP — reads/writes global store, identical state as every other screen
        RsvpButton(
          eventId: widget.event.id,
          color: widget.color,
          compact: true,
        ),
        _ActionChip(
          label: 'Calendar',
          icon: Icons.calendar_month_outlined,
          color: widget.color,
          filled: false,
          onTap: _addToCalendar,
        ),
        _ActionChip(
          label: _reminded ? 'Remind ✓' : 'Remind me',
          icon: _reminded
              ? Icons.notifications_active_rounded
              : Icons.notifications_outlined,
          color: widget.color,
          filled: _reminded,
          onTap: _toggleRemind,
        ),
      ],
    );
  }
}

class _ClubActions extends StatefulWidget {
  final Club club;
  final Color color;
  final String userId;
  final VoidCallback onChanged;
  final VoidCallback onHide;

  const _ClubActions({
    required this.club,
    required this.color,
    required this.userId,
    required this.onChanged,
    required this.onHide,
  });

  @override
  State<_ClubActions> createState() => _ClubActionsState();
}

class _ClubActionsState extends State<_ClubActions> {
  late bool _following;

  @override
  void initState() {
    super.initState();
    _following = userState.followedClubIds.contains(widget.club.id);
  }

  void _toggleFollow() {
    userState.toggleFollow(widget.club.id);
    final uid = widget.userId;
    if (uid.isNotEmpty) userPrefsService.save(uid);
    setState(() => _following = !_following);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ActionChip(
          label: _following ? 'Following ✓' : 'Follow',
          icon: _following
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          color: widget.color,
          filled: _following,
          onTap: _toggleFollow,
        ),
        _ActionChip(
          label: 'View',
          icon: Icons.open_in_new_rounded,
          color: widget.color,
          filled: false,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ClubProfileScreen(club: widget.club, color: widget.color),
            ),
          ),
        ),
      ],
    );
  }
}

class _PersonActions extends StatefulWidget {
  final User user;
  final Color color;
  final String userId;
  final VoidCallback onChanged;
  final VoidCallback onHide;

  const _PersonActions({
    required this.user,
    required this.color,
    required this.userId,
    required this.onChanged,
    required this.onHide,
  });

  @override
  State<_PersonActions> createState() => _PersonActionsState();
}

class _PersonActionsState extends State<_PersonActions> {
  late bool _following;

  @override
  void initState() {
    super.initState();
    _following = userState.followedUserIds.contains(widget.user.id);
  }

  void _toggleFollow() {
    userState.toggleFollowUser(widget.user.id);
    setState(() => _following = !_following);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ActionChip(
          label: _following ? 'Following ✓' : 'Follow',
          icon: _following ? Icons.person_rounded : Icons.person_add_outlined,
          color: widget.color,
          filled: _following,
          onTap: _toggleFollow,
        ),
        _ActionChip(
          label: 'Message',
          icon: Icons.chat_bubble_outline_rounded,
          color: widget.color,
          filled: false,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                otherUserId: widget.user.id,
                otherUserName: widget.user.name,
              ),
            ),
          ),
        ),
        _ActionChip(
          label: 'Profile',
          icon: Icons.open_in_new_rounded,
          color: widget.color,
          filled: false,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserProfileScreen(user: widget.user),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Generic action chip ───────────────────────────────────────────────────────

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: filled ? color : color.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: filled ? Colors.white : color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: filled ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _shortClubName(String name) {
  final i = name.indexOf(' (');
  return i > 0 ? name.substring(0, i) : name;
}
