import 'dart:io';
import 'package:flutter/material.dart';
import 'package:add_2_calendar/add_2_calendar.dart' as cal;
import '../services/app_colors.dart';
import '../services/content_store.dart';
import '../services/mock_data.dart';
import '../services/auth_service.dart';
import '../services/user_state.dart';
import '../services/user_prefs_service.dart';
import '../services/view_tracker.dart';
import '../widgets/club_avatar.dart';
import '../widgets/club_follow_button.dart';
import '../widgets/user_follow_button.dart';
import '../models/comment.dart';
import '../models/like.dart';
import '../models/share.dart';
import '../models/message.dart';
import '../models/news_post.dart';
import '../models/event.dart';
import '../models/user.dart';
import '../services/message_service.dart';
import 'messages_screen.dart';
import 'campus_map_screen.dart';
import 'user_profile_screen.dart';
import 'create_post_screen.dart' show buildPostBanner;
import '../widgets/user_avatar.dart';
import '../services/rsvp_store.dart';
import '../services/personalization_service.dart';
import '../widgets/rsvp_button.dart';

// ─── Feed Item (unified post + event wrapper) ─────────────────────────────────

class _FeedItem {
  final String id;
  final bool isEvent;        // true = Event, false = NewsPost
  final dynamic data;        // NewsPost | Event
  final double score;
  final DateTime postedAt;

  const _FeedItem({
    required this.id,
    required this.isEvent,
    required this.data,
    required this.score,
    required this.postedAt,
  });
}

// Inline recommendation marker types
class _EventSuggestion {
  final Event event;
  const _EventSuggestion(this.event);
}

class _ClubSuggestion {
  final dynamic club;
  const _ClubSuggestion(this.club);
}

// ─── Feed Screen ──────────────────────────────────────────────────────────────

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final Set<String> _viewedClubIds = {};

  // true = show only followed clubs, false = show all clubs
  bool _followedOnly = true;

  Set<String> get _followedIds => userState.followedClubIds;

  bool _clubVisible(String clubId) =>
      !_followedOnly || _followedIds.contains(clubId);

  List<_FeedItem> _buildFeed() {
    final items = newsPosts
        .where((post) => _clubVisible(post.clubId))
        .map((post) => _FeedItem(
          id: post.id,
          isEvent: false,
          data: post,
          score: postScore(post.id),
          postedAt: post.createdAt,
        )).toList();
    items.sort((a, b) => b.postedAt.compareTo(a.postedAt));
    return items;
  }

  // Events that have started and not yet ended
  List<dynamic> get _liveEvents {
    final now = DateTime.now();
    return events
        .where((e) =>
            _clubVisible(e.clubId) &&
            !e.dateTime.isAfter(now) &&
            e.endTime.isAfter(now))
        .toList();
  }

  // Events that haven't started yet
  List<dynamic> get _upcomingEvents {
    final now = DateTime.now();
    return events
        .where((e) =>
            _clubVisible(e.clubId) &&
            e.dateTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  // Users the logged-in person doesn't follow yet, sorted by shared club overlap.
  List<User> _suggestedUsers() {
    final myId = authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
    final myFollowing = userState.followedUserIds;
    final myClubs = userState.followedClubIds;

    return users
        .where((u) =>
            u.id != myId &&
            !myFollowing.contains(u.id))
        .toList()
      ..sort((a, b) {
          final aOverlap = a.subscribedClubIds.where(myClubs.contains).length;
          final bOverlap = b.subscribedClubIds.where(myClubs.contains).length;
          return bOverlap.compareTo(aOverlap);
        });
  }

  // Clubs the user doesn't follow, sorted by popularity.
  List<dynamic> _suggestedClubs() {
    return clubs
        .where((c) => !userState.followedClubIds.contains(c.id))
        .toList()
      ..sort((a, b) => clubMemberCount(b.id).compareTo(clubMemberCount(a.id)));
  }

  // Most-viewed upcoming event from the last 14 days.
  Event? _trendingEvent() {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 14));
    final eligible = events
        .where((e) => e.dateTime.isAfter(cutoff) && e.endTime.isAfter(now))
        .toList();
    if (eligible.isEmpty) return null;
    eligible.sort((a, b) {
      final scoreA = viewTracker.viewCount(a.id) + eventScore(a.id);
      final scoreB = viewTracker.viewCount(b.id) + eventScore(b.id);
      return scoreB.compareTo(scoreA);
    });
    return eligible.first;
  }

  // Builds the mixed feed:
  //   every 10 posts → People You Might Know card + Trending Event card
  //   every 15 posts → Club You Might Like card
  List<dynamic> _buildMixedFeed(List<_FeedItem> posts) {
    final result = <dynamic>[];
    final peopleSuggestions = _suggestedUsers();
    final clubSuggestions = _suggestedClubs();
    final trendingEv = _trendingEvent();
    int clubIdx = 0;

    for (int i = 0; i < posts.length; i++) {
      result.add(posts[i]);
      if ((i + 1) % 10 == 0) {
        if (peopleSuggestions.isNotEmpty) result.add(peopleSuggestions);
        if (trendingEv != null) result.add(_EventSuggestion(trendingEv));
      }
      if ((i + 1) % 15 == 0 && clubSuggestions.isNotEmpty) {
        result.add(_ClubSuggestion(clubSuggestions[clubIdx % clubSuggestions.length]));
        clubIdx++;
      }
    }
    return result;
  }

  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() {});
  }

  // ── Feed tab state ─────────────────────────────────────────────────────────
  // 0 = For You, 1 = Following, 2 = Events, 3 = Clubs
  int _feedTab = 0;

  @override
  Widget build(BuildContext context) {
    // "Following" tab → followed only; all others → all clubs visible
    _followedOnly = _feedTab == 1;

    final mixed = _buildMixedFeed(_buildFeed());
    final live = _liveEvents;
    final upcoming = _upcomingEvents;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppColors.primaryRed,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildAppBar(),
            _buildFeedTabs(),
            _buildStoriesRow(),
            _buildContextBar(),
            _buildScheduleStrip(),
            _buildWelcomeCard(live, upcoming),
            _buildEventsStrip(live, upcoming),
            if (mixed.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.explore_outlined, size: 64,
                            color: AppColors.secondaryText.withValues(alpha: 0.35)),
                        const SizedBox(height: 18),
                        const Text('Nothing here yet',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text)),
                        const SizedBox(height: 8),
                        const Text('Follow clubs to see their posts\nand events in your feed',
                            style: TextStyle(fontSize: 14, color: AppColors.secondaryText, height: 1.4),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => setState(() => _followedOnly = false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryRed,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.explore_rounded, size: 18),
                          label: const Text('Explore All Clubs',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                  child: Row(
                    children: [
                      const Text('Latest',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.text)),
                      const Spacer(),
                      Text(
                        _followedOnly ? 'From followed clubs' : 'All clubs',
                        style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final item = mixed[i];
                    if (item is List<User>) {
                      return _PeopleSuggestionCard(
                        suggestions: item,
                        onFollowed: () => setState(() {}),
                      );
                    }
                    if (item is _EventSuggestion) {
                      return _TrendingEventCard(
                        event: item.event,
                        onUpdate: () => setState(() {}),
                      );
                    }
                    if (item is _ClubSuggestion) {
                      return _ClubSuggestionCard(
                        club: item.club,
                        onUpdate: () => setState(() {}),
                      );
                    }
                    return _buildFeedCard(item as _FeedItem, i);
                  },
                  childCount: mixed.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ],
        ),
      ),
    );
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _firstName {
    final name = authService.currentUser?.name ?? authService.currentAdmin?.name ?? '';
    return name.split(' ').first;
  }

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      backgroundColor: AppColors.card,
      foregroundColor: AppColors.text,
      surfaceTintColor: Colors.transparent,
      floating: true,
      snap: true,
      expandedHeight: 76,
      collapsedHeight: 56,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(18, 0, 56, 12),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$_greeting, $_firstName',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.secondaryText.withValues(alpha: 0.8),
                fontWeight: FontWeight.w400,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 1),
            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'Uni',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      color: AppColors.primaryRed,
                      letterSpacing: -0.8,
                    ),
                  ),
                  TextSpan(
                    text: 'Hub',
                    style: TextStyle(
                      fontWeight: FontWeight.w200,
                      fontSize: 22,
                      color: AppColors.text,
                      letterSpacing: -0.8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E0A22), AppColors.card],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.map_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CampusMapScreen()),
          ),
          tooltip: 'Campus Map',
        ),
        IconButton(
          icon: const Icon(Icons.send_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MessagesScreen()),
          ),
          tooltip: 'Direct Messages',
        ),
      ],
    );
  }

  // ── Feed Tabs (For You / Following / Events / Clubs) ─────────────────────
  SliverToBoxAdapter _buildFeedTabs() {
    const labels = ['For You', 'Following', 'Events', 'Clubs'];
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E0A22), AppColors.card],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(labels.length, (i) {
              final active = _feedTab == i;
              return GestureDetector(
                onTap: () => setState(() => _feedTab = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: active
                        ? const LinearGradient(
                            colors: [AppColors.primaryRed, Color(0xFF6A1530)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: active ? null : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: active
                          ? AppColors.primaryRed.withValues(alpha: 0.6)
                          : AppColors.glassEdge,
                      width: active ? 0 : 1,
                    ),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: AppColors.primaryRed.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      color: active ? Colors.white : AppColors.secondaryText,
                      letterSpacing: active ? 0.2 : 0,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ── Context Bar (weather + academic week) ─────────────────────────────────
  SliverToBoxAdapter _buildContextBar() {
    // Static mock data — matches design
    const weather = '18°C · Cloudy';
    const weatherIcon = '⛅';
    final now = DateTime.now();
    // Approximate academic week (spring semester starts early Feb)
    final semesterStart = DateTime(now.year, 2, 3);
    final weekNum = ((now.difference(semesterStart).inDays) / 7).ceil().clamp(1, 16);
    final finalsWeek = DateTime(now.year, 5, 26);
    final weeksToFinals = ((finalsWeek.difference(now).inDays) / 7).ceil();
    final weekLabel = weekNum <= 16 ? 'Week $weekNum of 16' : 'Finals Week';
    final finalsLabel = weeksToFinals > 0 ? 'Finals in $weeksToFinals wks' : 'Finals now';

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
        child: Row(
          children: [
            // Weather card
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A1226), Color(0xFF140818)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.glassEdge),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Text(weatherIcon, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(weather,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text, letterSpacing: -0.2)),
                        const Text('Istanbul · Campus',
                            style: TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Academic week card
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryRed.withValues(alpha: 0.18),
                      AppColors.card,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryRed.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Text('📅', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(weekLabel,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text, letterSpacing: -0.2)),
                        Text(finalsLabel,
                            style: TextStyle(fontSize: 11, color: AppColors.primaryRed.withValues(alpha: 0.8))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Schedule Strip (today's classes) ──────────────────────────────────────
  bool _scheduleExpanded = false;

  // days: 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri — defined in personalization_service.dart
  List<Map<String, dynamic>> get _allCourses => kCourseSchedule;

  SliverToBoxAdapter _buildScheduleStrip() {
    final now = DateTime.now();
    final todayWeekday = now.weekday; // 1=Mon … 5=Fri
    final todayMinutes = now.hour * 60 + now.minute;

    // Filter to today's courses, sorted by start time
    final todayAll = _allCourses
        .where((c) => (c['days'] as List).contains(todayWeekday))
        .toList()
      ..sort((a, b) {
        final aM = (a['startH'] as int) * 60 + (a['startM'] as int);
        final bM = (b['startH'] as int) * 60 + (b['startM'] as int);
        return aM.compareTo(bM);
      });

    // Compute status for each
    List<Map<String, dynamic>> schedule = [];
    bool nextAssigned = false;
    for (final c in todayAll) {
      final startMin = (c['startH'] as int) * 60 + (c['startM'] as int);
      final endMin   = (c['endH']   as int) * 60 + (c['endM']   as int);
      final String status;
      if (todayMinutes >= startMin && todayMinutes < endMin) {
        status = 'now';
      } else if (todayMinutes < startMin && !nextAssigned) {
        status = 'next';
        nextAssigned = true;
      } else {
        status = todayMinutes >= endMin ? 'done' : 'later';
      }
      final sh = (c['startH'] as int).toString().padLeft(2, '0');
      final sm = (c['startM'] as int).toString().padLeft(2, '0');
      final eh = (c['endH']   as int).toString().padLeft(2, '0');
      final em = (c['endM']   as int).toString().padLeft(2, '0');
      final dur = (endMin - startMin);
      schedule.add({
        'title': c['title'],
        'room':  c['room'],
        'time':  '$sh:$sm – $eh:$em',
        'dur':   '${dur ~/ 60}h ${dur % 60 == 0 ? '' : '${dur % 60}m'}'.trim(),
        'status': status,
        'color':  c['color'],
      });
    }

    if (schedule.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    final visible = _scheduleExpanded ? schedule : schedule.take(2).toList();

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassEdge),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  const Text('📋', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 7),
                  const Text('Today\'s Schedule',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text, letterSpacing: -0.3)),
                  const Spacer(),
                  if (schedule.length > 2)
                  GestureDetector(
                    onTap: () => setState(() => _scheduleExpanded = !_scheduleExpanded),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _scheduleExpanded ? 'Less' : 'All ${schedule.length}',
                        style: const TextStyle(fontSize: 11, color: AppColors.primaryRed, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Schedule items
            ...visible.map((item) {
              final status = item['status'] as String;
              final color = Color(item['color'] as int);
              final isNow = status == 'now';
              final statusLabel = isNow ? 'NOW' : status == 'next' ? 'NEXT' : null;

              return Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: isNow
                      ? color.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(10),
                  border: isNow
                      ? Border.all(color: color.withValues(alpha: 0.25))
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 3, height: 38,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['title'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isNow ? AppColors.text : AppColors.text.withValues(alpha: 0.85),
                                letterSpacing: -0.2,
                              ),
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(
                            '${item['room']} · ${item['time']}  ${item['dur']}',
                            style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (statusLabel != null)
                      _ScheduleBadge(label: statusLabel, color: color),
                  ],
                ),
              );
            }),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  // ── Quick Campus Access Grid ───────────────────────────────────────────────

  SliverToBoxAdapter _buildWelcomeCard(List<dynamic> live, List<dynamic> upcoming) {
    if (live.isNotEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${live.length} event${live.length > 1 ? 's' : ''} happening right now on campus',
                  style: const TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.red, size: 16),
            ],
          ),
        ),
      );
    }

    if (upcoming.isNotEmpty) {
      final nextEvent = upcoming.first;
      final daysAway = (nextEvent.dateTime as DateTime).difference(DateTime.now()).inDays;
      final label = daysAway == 0 ? 'Today' : daysAway == 1 ? 'Tomorrow' : 'In $daysAway days';
      return SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.lightRed,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.event_rounded, size: 18, color: AppColors.primaryRed),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Next Up · $label',
                        style: const TextStyle(fontSize: 11, color: AppColors.primaryRed, fontWeight: FontWeight.w500)),
                    Text(nextEvent.title as String,
                        style: const TextStyle(fontSize: 13, color: AppColors.text, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SliverToBoxAdapter(child: SizedBox(height: 6));
  }

  SliverToBoxAdapter _buildEventsStrip(List<dynamic> live, List<dynamic> upcoming) {
    if (live.isEmpty && upcoming.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Happening Now ──
          if (live.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  const Text('Happening Now', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.text)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${live.length} live', style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: live.length,
                itemBuilder: (ctx, i) => _EventChip(event: live[i], isLive: true),
              ),
            ),
            const SizedBox(height: 6),
          ],

          // ── Upcoming ──
          if (upcoming.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
              child: Row(
                children: [
                  const Icon(Icons.event_rounded, size: 16, color: AppColors.primaryRed),
                  const SizedBox(width: 6),
                  const Text('Upcoming Events', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.text)),
                  const Spacer(),
                  Text('${upcoming.length} events', style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                ],
              ),
            ),
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: upcoming.length,
                itemBuilder: (ctx, i) => _EventChip(event: upcoming[i], isLive: false),
              ),
            ),
            const SizedBox(height: 6),
          ],

          const Divider(height: 1),
        ],
      ),
    );
  }

  // Returns clubs that have at least one story posted within the last 24 hours,
  // sorted: unseen (newest story first) → seen / oldest.
  List<({dynamic club, List<ClubStory> stories, bool seen, Color color})> _activeStoryClubs() {
    const colors = [
      Color(0xFF8C1D40), Color(0xFF1565C0), Color(0xFF2E7D32),
      Color(0xFF6A1B9A), Color(0xFFE65100), Color(0xFF00838F),
    ];
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));

    final result = <({dynamic club, List<ClubStory> stories, bool seen, Color color})>[];
    for (int i = 0; i < clubs.length; i++) {
      final club = clubs[i];
      if (!_clubVisible(club.id)) continue;
      final recent = clubStories
          .where((s) => s.clubId == club.id && s.postedAt.isAfter(cutoff))
          .toList()
        ..sort((a, b) => b.postedAt.compareTo(a.postedAt)); // newest first
      if (recent.isEmpty) continue;
      result.add((
        club: club,
        stories: recent,
        seen: _viewedClubIds.contains(club.id),
        color: colors[i % colors.length],
      ));
    }

    // Sort: unseen first (newest → oldest), then seen (newest → oldest).
    // Unseen always precede seen regardless of recency.
    result.sort((a, b) {
      if (a.seen != b.seen) return a.seen ? 1 : -1; // unseen before seen
      return b.stories.first.postedAt.compareTo(a.stories.first.postedAt); // newest leftmost in both groups
    });

    return result;
  }

  SliverToBoxAdapter _buildStoriesRow() {
    final active = _activeStoryClubs();
    if (active.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Container(
        color: AppColors.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 106,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: active.length,
                itemBuilder: (context, i) {
                  final entry = active[i];
                  return _StoryBubble(
                    club: entry.club,
                    stories: entry.stories,
                    seen: entry.seen,
                    color: entry.color,
                    allClubs: active,
                    startClubIndex: i,
                    onViewed: () => setState(() => _viewedClubIds.add(entry.club.id)),
                    onDeleted: () => setState(() {}),
                  );
                },
              ),
            ),
            const Divider(height: 1),
          ],
        ),
      ),
    );
  }


  Widget _buildFeedCard(_FeedItem item, int rank) {
    if (item.isEvent) {
      return _EventCard(
        event: item.data as Event,
        score: item.score,
        rank: rank,
        onUpdate: () => setState(() {}),
      );
    }
    return _PostCard(
      post: item.data as NewsPost,
      score: item.score,
      rank: rank,
      onUpdate: () => setState(() {}),
    );
  }
}

// ─── Story Bubble ─────────────────────────────────────────────────────────────

// ─── Event Chip ───────────────────────────────────────────────────────────────

// ─── Feed Filter Option (used inside showMenu) ───────────────────────────────

// ─── Schedule Badge ───────────────────────────────────────────────────────────

class _ScheduleBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _ScheduleBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

// ─── Event Chip ───────────────────────────────────────────────────────────────

class _EventChip extends StatelessWidget {
  final dynamic event;
  final bool isLive;

  static const List<Color> _colors = [
    Color(0xFFB41C18), Color(0xFF1565C0), Color(0xFF2E7D32),
    Color(0xFF6A1B9A), Color(0xFFE65100), Color(0xFF00838F),
  ];

  const _EventChip({required this.event, required this.isLive});

  void _showEventDetail(BuildContext context, dynamic ev, bool live, Color color) {
    final club = clubs.firstWhere((c) => c.id == ev.clubId, orElse: () => clubs.first);
    final DateTime start = ev.dateTime;
    final DateTime end = ev.endTime;
    final String location = ev.location as String;
    final int attendees = (ev.attendeeUserIds as List).length;
    // Seed global store so the modal RSVP button reflects current state
    final userId = authService.currentUser?.id ?? '';
    rsvpStore.seed(ev.id as String, (ev.attendeeUserIds as List).contains(userId));

    String fmtDateTime(DateTime dt) {
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour < 12 ? 'AM' : 'PM';
      return '${months[dt.month - 1]} ${dt.day}  ·  $h:$m $period';
    }

    String statusLine() {
      final now = DateTime.now();
      if (live) {
        final remaining = end.difference(now);
        if (remaining.inMinutes < 60) return 'Ends in ${remaining.inMinutes} min';
        return 'Ends in ${remaining.inHours}h ${remaining.inMinutes % 60}m';
      } else {
        final until = start.difference(now);
        if (until.inDays > 0) return 'Starts in ${until.inDays}d ${until.inHours % 24}h';
        if (until.inHours > 0) return 'Starts in ${until.inHours}h ${until.inMinutes % 60}m';
        return 'Starts in ${until.inMinutes} min';
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            // Club name + LIVE badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(club.name.split(' ').first,
                      style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                if (live)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                    child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Title
            Text(ev.title as String,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text)),
            const SizedBox(height: 16),
            // Location
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: AppColors.primaryRed),
                const SizedBox(width: 6),
                Expanded(child: Text(location, style: const TextStyle(fontSize: 14, color: AppColors.text))),
              ],
            ),
            const SizedBox(height: 10),
            // Start time
            Row(
              children: [
                const Icon(Icons.play_circle_outline, size: 16, color: AppColors.secondaryText),
                const SizedBox(width: 6),
                Text('Starts  ${fmtDateTime(start)}',
                    style: const TextStyle(fontSize: 13, color: AppColors.secondaryText)),
              ],
            ),
            const SizedBox(height: 6),
            // End time
            Row(
              children: [
                const Icon(Icons.stop_circle_outlined, size: 16, color: AppColors.secondaryText),
                const SizedBox(width: 6),
                Text('Ends  ${fmtDateTime(end)}',
                    style: const TextStyle(fontSize: 13, color: AppColors.secondaryText)),
              ],
            ),
            const SizedBox(height: 14),
            // Status countdown / remaining
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: live ? Colors.red.withValues(alpha: 0.1) : AppColors.lightRed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(live ? Icons.timer_outlined : Icons.hourglass_top_rounded,
                      size: 15, color: live ? Colors.red : AppColors.primaryRed),
                  const SizedBox(width: 6),
                  Text(statusLine(),
                      style: TextStyle(fontSize: 13, color: live ? Colors.red : AppColors.primaryRed,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Attendee count — only shown to the owning club admin
            if (() {
              final admin = authService.currentAdmin;
              if (admin == null) return false;
              try {
                return clubs
                        .firstWhere((c) => c.adminUserIds.contains(admin.id))
                        .id ==
                    ev.clubId;
              } catch (_) {
                return false;
              }
            }()) ...[
              Row(
                children: [
                  const Icon(Icons.people_outline, size: 16, color: AppColors.secondaryText),
                  const SizedBox(width: 6),
                  Text('$attendees attending',
                      style: const TextStyle(fontSize: 13, color: AppColors.secondaryText)),
                ],
              ),
              const SizedBox(height: 20),
            ] else
              const SizedBox(height: 20),
            // Action buttons row — Calendar collapses to icon when attending
            // so the RSVP button has enough horizontal room for its inner layout.
            ListenableBuilder(
              listenable: rsvpStore,
              builder: (ctx, _) {
                final attending = rsvpStore.isAttending(ev.id as String);
                void addToCalendar() {
                  final calEvent = cal.Event(
                    title: ev.title as String,
                    description: ev.description as String,
                    location: location,
                    startDate: start,
                    endDate: end,
                    allDay: false,
                  );
                  cal.Add2Calendar.addEvent2Cal(calEvent);
                }

                return Row(
                  children: [
                    // Calendar: full button when not attending, icon-only when attending
                    attending
                        ? OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryRed,
                              side: const BorderSide(color: AppColors.primaryRed, width: 1.5),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: addToCalendar,
                            child: const Icon(Icons.calendar_month_outlined, size: 20),
                          )
                        : Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryRed,
                                side: const BorderSide(color: AppColors.primaryRed, width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.calendar_month_outlined, size: 18),
                              label: const Text('Calendar', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              onPressed: addToCalendar,
                            ),
                          ),
                    const SizedBox(width: 10),
                    // RSVP — full remaining width
                    Expanded(
                      child: RsvpButton(
                        eventId: ev.id as String,
                        color: color,
                        isPast: end.isBefore(DateTime.now()),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final club = clubs.firstWhere((c) => c.id == event.clubId, orElse: () => clubs.first);
    final idx = clubs.indexOf(club);
    final color = _colors[idx % _colors.length];
    final dt = event.dateTime as DateTime;

    String timeLabel;
    if (isLive) {
      final diff = DateTime.now().difference(dt);
      if (diff.inDays >= 1) {
        timeLabel = 'Started ${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} ago';
      } else if (diff.inHours >= 1) {
        timeLabel = 'Started ${diff.inHours}h ago';
      } else {
        timeLabel = 'Started ${diff.inMinutes}m ago';
      }
    } else {
      final daysAway = dt.difference(DateTime.now()).inDays;
      timeLabel = daysAway == 0 ? 'Today' : daysAway == 1 ? 'Tomorrow' : 'In $daysAway days';
    }

    return GestureDetector(
      onTap: () => _showEventDetail(context, event, isLive, color),
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 10, bottom: 4),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isLive ? Colors.red.withValues(alpha: 0.6) : color.withValues(alpha: 0.3),
            width: isLive ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colour bar + live badge
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      club.name.split(' ').first,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isLive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    )
                  else
                    Icon(Icons.event, size: 14, color: color),
                ],
              ),
            ),
            // Event title + time
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
              child: Text(
                event.title as String,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text, height: 1.3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                timeLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: isLive ? Colors.red : AppColors.primaryRed,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── People You Might Know ────────────────────────────────────────────────────

class _PeopleSuggestionCard extends StatefulWidget {
  final List<User> suggestions;
  final VoidCallback onFollowed;
  const _PeopleSuggestionCard({required this.suggestions, required this.onFollowed});

  @override
  State<_PeopleSuggestionCard> createState() => _PeopleSuggestionCardState();
}

class _PeopleSuggestionCardState extends State<_PeopleSuggestionCard> {
  static const List<Color> _avatarColors = [
    Color(0xFF8C1D40), Color(0xFF1565C0), Color(0xFF2E7D32),
    Color(0xFF6A1B9A), Color(0xFFE65100), Color(0xFF00838F),
  ];

  @override
  Widget build(BuildContext context) {
    // Show at most 8 suggestions in the card
    final shown = widget.suggestions.take(8).toList();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: AppColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Icon(Icons.people_outline, size: 18, color: AppColors.primaryRed),
                const SizedBox(width: 6),
                const Text(
                  'People You Might Know',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.text),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 148,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: shown.length,
              separatorBuilder: (_, i) => const SizedBox(width: 10),
              itemBuilder: (ctx, i) {
                final u = shown[i];
                final color = _avatarColors[i % _avatarColors.length];

                return Container(
                  width: 110,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserProfileScreen(user: u),
                          ),
                        ),
                        child: UserAvatar(
                          userId: u.id,
                          name: u.name,
                          size: 52,
                          fontSize: 22,
                          backgroundColor: color.withValues(alpha: 0.15),
                          textColor: color,
                        ),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserProfileScreen(user: u),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Column(
                            children: [
                              Text(
                                u.name.split(' ').first,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text,
                                ),
                              ),
                              Builder(builder: (ctx) {
                                final mutualCount = userState.followedUserIds
                                    .intersection(Set<String>.from(u.followingUserIds))
                                    .length;
                                if (mutualCount == 0) return const SizedBox.shrink();
                                return Text(
                                  '$mutualCount mutual',
                                  style: const TextStyle(
                                      fontSize: 10, color: AppColors.secondaryText),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      UserFollowButton(
                        userId: u.id,
                        size: 'small',
                        onTap: () {
                          userState.toggleFollowUser(u.id);
                          userPrefsService.save(authService.currentUser?.id ?? authService.currentAdmin?.id ?? '');
                          widget.onFollowed();
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

// ─── Trending Event Card ──────────────────────────────────────────────────────

class _TrendingEventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onUpdate;

  static const List<Color> _colors = [
    Color(0xFFB41C18), Color(0xFF1565C0), Color(0xFF2E7D32),
    Color(0xFF6A1B9A), Color(0xFFE65100), Color(0xFF00838F),
  ];

  const _TrendingEventCard({required this.event, required this.onUpdate});

  void _showDetail(BuildContext context, Color color) {
    final club = clubs.firstWhere((c) => c.id == event.clubId,
        orElse: () => clubs.first);
    final DateTime start = event.dateTime;
    final DateTime end = event.endTime;
    final userId = authService.currentUser?.id ?? '';
    rsvpStore.seed(event.id, event.attendeeUserIds.contains(userId));

    String fmt(DateTime dt) {
      const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      return '${mo[dt.month-1]} ${dt.day}  ·  $h:$m ${dt.hour < 12 ? "AM" : "PM"}';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 36, height: 4,
                  decoration: BoxDecoration(color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(club.name.split(' ').first,
                  style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            Text(event.title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text)),
            const SizedBox(height: 14),
            Row(children: [
              const Icon(Icons.location_on_outlined, size: 16, color: AppColors.primaryRed),
              const SizedBox(width: 6),
              Expanded(child: Text(event.location,
                  style: const TextStyle(fontSize: 14, color: AppColors.text))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.play_circle_outline, size: 16, color: AppColors.secondaryText),
              const SizedBox(width: 6),
              Text('Starts  ${fmt(start)}',
                  style: const TextStyle(fontSize: 13, color: AppColors.secondaryText)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.stop_circle_outlined, size: 16, color: AppColors.secondaryText),
              const SizedBox(width: 6),
              Text('Ends  ${fmt(end)}',
                  style: const TextStyle(fontSize: 13, color: AppColors.secondaryText)),
            ]),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: RsvpButton(
                eventId: event.id,
                color: color,
                isPast: end.isBefore(DateTime.now()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final club = clubs.firstWhere((c) => c.id == event.clubId,
        orElse: () => clubs.first);
    final idx = clubs.indexOf(club);
    final color = _colors[idx % _colors.length];
    final dt = event.dateTime;
    const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final daysAway = dt.difference(DateTime.now()).inDays;
    final timeLabel = daysAway == 0 ? 'Today'
        : daysAway == 1 ? 'Tomorrow'
        : '${mo[dt.month - 1]} ${dt.day}';
    final views = viewTracker.viewCount(event.id);
    final attendees = event.attendeeUserIds.length;

    return GestureDetector(
      onTap: () => _showDetail(context, color),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        color: AppColors.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded,
                      size: 18, color: Colors.deepOrange),
                  const SizedBox(width: 6),
                  const Text('Trending This Week',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                          color: AppColors.text)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(club.name.split(' ').first,
                        style: TextStyle(fontSize: 11, color: color,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            // Event body
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Colour accent + date chip
                  Row(
                    children: [
                      Container(
                        width: 4, height: 40,
                        decoration: BoxDecoration(
                            color: color, borderRadius: BorderRadius.circular(4)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(event.title,
                                style: const TextStyle(fontSize: 15,
                                    fontWeight: FontWeight.bold, color: AppColors.text),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Row(children: [
                              Icon(Icons.event_rounded, size: 13, color: color),
                              const SizedBox(width: 4),
                              Text(timeLabel,
                                  style: TextStyle(fontSize: 12, color: color,
                                      fontWeight: FontWeight.w600)),
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (event.location.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      const Icon(Icons.location_on_outlined, size: 14,
                          color: AppColors.secondaryText),
                      const SizedBox(width: 4),
                      Text(event.location,
                          style: const TextStyle(fontSize: 12,
                              color: AppColors.secondaryText)),
                    ]),
                  ],
                  const SizedBox(height: 10),
                  Row(children: [
                    Icon(Icons.people_outline, size: 14,
                        color: AppColors.secondaryText),
                    const SizedBox(width: 4),
                    Text('$attendees attending',
                        style: const TextStyle(fontSize: 12,
                            color: AppColors.secondaryText)),
                    if (views > 0) ...[
                      const SizedBox(width: 14),
                      const Icon(Icons.visibility_outlined, size: 14,
                          color: AppColors.secondaryText),
                      const SizedBox(width: 4),
                      Text('$views views',
                          style: const TextStyle(fontSize: 12,
                              color: AppColors.secondaryText)),
                    ],
                    const Spacer(),
                    Text('Tap for details',
                        style: TextStyle(fontSize: 11,
                            color: color, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 14, color: color),
                  ]),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
        ),
      ),
    );
  }
}

// ─── Club Suggestion Card ─────────────────────────────────────────────────────

class _ClubSuggestionCard extends StatefulWidget {
  final dynamic club;
  final VoidCallback onUpdate;

  const _ClubSuggestionCard({required this.club, required this.onUpdate});

  @override
  State<_ClubSuggestionCard> createState() => _ClubSuggestionCardState();
}

class _ClubSuggestionCardState extends State<_ClubSuggestionCard> {
  static const List<Color> _colors = [
    Color(0xFF8C1D40), Color(0xFF1565C0), Color(0xFF2E7D32),
    Color(0xFF6A1B9A), Color(0xFFE65100), Color(0xFF00838F),
  ];

  @override
  Widget build(BuildContext context) {
    final c = widget.club;
    final idx = clubs.indexOf(c);
    final color = _colors[idx < 0 ? 0 : idx % _colors.length];
    final memberCount = clubMemberCount(c.id as String);
    final desc = (c.description as String).isNotEmpty
        ? c.description as String
        : 'Discover what this club is all about.';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: AppColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(Icons.explore_rounded, size: 18, color: color),
                const SizedBox(width: 6),
                const Text('Club You Might Like',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                        color: AppColors.text)),
              ],
            ),
          ),
          // Club row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  // Avatar
                  ClubAvatar(
                    clubId: c.id as String,
                    clubName: c.name as String,
                    color: color,
                    size: 52,
                    fontSize: 20,
                  ),
                  const SizedBox(width: 12),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name as String,
                            style: const TextStyle(fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.text),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(desc,
                            style: const TextStyle(fontSize: 12,
                                color: AppColors.secondaryText, height: 1.3),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Row(children: [
                          Icon(Icons.people_outline, size: 13, color: color),
                          const SizedBox(width: 4),
                          Text('$memberCount members',
                              style: TextStyle(fontSize: 11, color: color,
                                  fontWeight: FontWeight.w500)),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Follow button (self-contained)
                  ClubFollowButton(clubId: c.id as String),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

// ─── Story Bubble ─────────────────────────────────────────────────────────────

class _StoryBubble extends StatelessWidget {
  final dynamic club;
  final List<ClubStory> stories;
  final bool seen;
  final Color color;
  final List<({dynamic club, List<ClubStory> stories, bool seen, Color color})> allClubs;
  final int startClubIndex;
  final VoidCallback onViewed;
  final VoidCallback onDeleted;

  const _StoryBubble({
    required this.club,
    required this.stories,
    required this.seen,
    required this.color,
    required this.allClubs,
    required this.startClubIndex,
    required this.onViewed,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onViewed();
        _openStoryViewer(context, allClubs, startClubIndex);
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 10),
        child: SizedBox(
          width: 68,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: seen
                      ? const LinearGradient(
                          colors: [AppColors.secondaryText, AppColors.secondaryText],
                        )
                      : const LinearGradient(
                          colors: [AppColors.primaryRed, AppColors.accentGold],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.card),
                  child: ClubAvatar(
                    clubId: club.id,
                    clubName: club.name,
                    color: color,
                    size: 48,
                    fontSize: 18,
                    shape: 'circle',
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                club.name.split(' ').first,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: seen ? AppColors.secondaryText : AppColors.text,
                  fontWeight: seen ? FontWeight.normal : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openStoryViewer(
    BuildContext context,
    List<({dynamic club, List<ClubStory> stories, bool seen, Color color})> allClubs,
    int startClubIndex,
  ) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.transparent,
      pageBuilder: (_, a1, a2) => _StoryViewer(
        allClubs: allClubs,
        startClubIndex: startClubIndex,
        onDeleted: onDeleted,
      ),
      transitionsBuilder: (_, animation, a2, child) =>
          FadeTransition(opacity: animation, child: child),
      transitionDuration: const Duration(milliseconds: 200),
    ));
  }
}

// ─── Story Viewer ─────────────────────────────────────────────────────────────

class _StoryViewer extends StatefulWidget {
  final List<({dynamic club, List<ClubStory> stories, bool seen, Color color})> allClubs;
  final int startClubIndex;
  final VoidCallback? onDeleted;

  const _StoryViewer({
    required this.allClubs,
    required this.startClubIndex,
    this.onDeleted,
  });

  @override
  State<_StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<_StoryViewer> with TickerProviderStateMixin {
  late int _clubIndex;
  late List<ClubStory> _stories;
  int _index = 0;

  // Progress bar timer
  late AnimationController _progressController;

  // Crossfade between stories
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  // Swipe-down-to-dismiss
  double _dragOffset = 0;
  bool _dismissing = false;

  dynamic get _club => widget.allClubs[_clubIndex].club;
  Color get _color => widget.allClubs[_clubIndex].color;

  String get _loggedInId =>
      authService.currentAdmin?.id ?? authService.currentUser?.id ?? '';

  bool get _isOwner {
    if (_index >= _stories.length) return false;
    final creatorId = _stories[_index].createdByUserId;
    return creatorId != null && creatorId == _loggedInId;
  }

  void _loadClub(int clubIndex) {
    _clubIndex = clubIndex;
    _stories = List.of(widget.allClubs[clubIndex].stories);
    final uid = authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
    final firstUnseen = _stories.indexWhere(
        (s) => !viewTracker.viewerIds(s.id).contains(uid));
    _index = firstUnseen == -1 ? 0 : firstUnseen;
  }

  @override
  void initState() {
    super.initState();
    _loadClub(widget.startClubIndex);

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _nextStory();
      });

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);

    _progressController.forward();
    _fadeController.forward();
    _recordCurrentView();
  }

  void _recordCurrentView() {
    final userId = authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
    if (_index < _stories.length) {
      viewTracker.recordView(_stories[_index].id, userId);
    }
  }

  /// Crossfade to the new content, then restart progress.
  void _crossfadeTo(VoidCallback updateState) {
    _progressController.stop();
    _fadeController.reverse().then((_) {
      if (!mounted) return;
      setState(updateState);
      _fadeController.forward();
      _progressController.forward(from: 0);
      _recordCurrentView();
    });
  }

  void _nextStory() {
    if (_index < _stories.length - 1) {
      _crossfadeTo(() => _index++);
    } else if (_clubIndex < widget.allClubs.length - 1) {
      _crossfadeTo(() => _loadClub(_clubIndex + 1));
    } else {
      _animatedPop();
    }
  }

  void _prevStory() {
    if (_index > 0) {
      _crossfadeTo(() => _index--);
    } else if (_clubIndex > 0) {
      _crossfadeTo(() {
        _clubIndex--;
        _stories = List.of(widget.allClubs[_clubIndex].stories);
        _index = _stories.length - 1;
      });
    } else {
      _progressController.forward(from: 0);
    }
  }

  /// Slide the card down off screen then pop — smooth exit.
  void _animatedPop() {
    if (_dismissing) return;
    _dismissing = true;
    _progressController.stop();
    const dur = Duration(milliseconds: 280);
    final size = MediaQuery.of(context).size;
    // Animate _dragOffset to full screen height
    final start = _dragOffset;
    final end = size.height;
    // Use AnimationController for the exit slide
    final exitCtrl = AnimationController(vsync: this, duration: dur);
    final exitAnim = Tween<double>(begin: start, end: end)
        .animate(CurvedAnimation(parent: exitCtrl, curve: Curves.easeInCubic));
    exitAnim.addListener(() {
      if (mounted) setState(() => _dragOffset = exitAnim.value);
    });
    exitCtrl.forward().then((_) {
      exitCtrl.dispose();
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _deleteCurrentStory() {
    _progressController.stop();
    final nav = Navigator.of(context);
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete story?',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text)),
        content: const Text('This story will be permanently removed.',
            style: TextStyle(color: AppColors.secondaryText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed != true) {
        _progressController.forward();
        return;
      }
      final storyId = _stories[_index].id;
      clubStories.removeWhere((s) => s.id == storyId);
      contentStore.saveClubStories();
      setState(() => _stories.removeAt(_index));
      widget.onDeleted?.call();
      if (_stories.isEmpty) {
        nav.pop();
      } else {
        if (_index >= _stories.length) _index = _stories.length - 1;
        _progressController.forward(from: 0);
      }
    });
  }

  Future<void> _showViewersSheet(BuildContext context, String contentId, String title) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ViewersSheet(contentId: contentId, title: title),
    );
  }

  String _timeAgoStory(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  void dispose() {
    _progressController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final story = _stories[_index];
    final size = MediaQuery.of(context).size;
    final hasPhoto = story.imagePath != null;

    // How transparent the barrier gets as user drags down (0→1 over 200px)
    final dismissProgress = (_dragOffset / 200).clamp(0.0, 1.0);
    final barrierOpacity = 1.0 - dismissProgress * 0.85;

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: barrierOpacity),
      body: GestureDetector(
        // Vertical drag for dismiss
        onVerticalDragUpdate: (details) {
          if (details.delta.dy > 0) {
            setState(() => _dragOffset += details.delta.dy);
          } else if (_dragOffset > 0) {
            setState(() {
              _dragOffset = (_dragOffset + details.delta.dy).clamp(0.0, double.infinity);
            });
          }
        },
        onVerticalDragEnd: (details) {
          if (_dragOffset > 120 || (details.velocity.pixelsPerSecond.dy > 600)) {
            _animatedPop();
          } else {
            setState(() => _dragOffset = 0);
          }
        },
        child: Transform.translate(
          offset: Offset(0, _dragOffset),
          child: SafeArea(
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                    20 + dismissProgress * 10),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SizedBox(
                  width: size.width,
                  height: size.height * 0.88,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                  // Background: photo or gradient
                  if (hasPhoto && story.imagePath!.startsWith('https://'))
                    Image.network(
                      story.imagePath!,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : Container(
                              color: _color.withValues(alpha: 0.18),
                              child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)),
                            ),
                      errorBuilder: (_, err, trace) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_color, _color.withValues(alpha: 0.75), Colors.black],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    )
                  else if (hasPhoto)
                    Image.file(File(story.imagePath!), fit: BoxFit.cover)
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_color, _color.withValues(alpha: 0.75), Colors.black],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  // Dark overlay for readability when photo is shown
                  if (hasPhoto)
                    Container(color: Colors.black.withValues(alpha: 0.35)),

                  // Progress bars
                  Positioned(
                    top: 12, left: 12, right: 12,
                    child: Row(
                      children: List.generate(_stories.length, (i) {
                        return Expanded(
                          child: Container(
                            height: 2.5,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: i < _index
                                ? Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)))
                                : i == _index
                                    ? AnimatedBuilder(
                                        animation: _progressController,
                                        builder: (_, child) => FractionallySizedBox(
                                          alignment: Alignment.centerLeft,
                                          widthFactor: _progressController.value,
                                          child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))),
                                        ),
                                      )
                                    : const SizedBox(),
                          ),
                        );
                      }),
                    ),
                  ),

                  // Header: club name + delete (admin) + close
                  Positioned(
                    top: 28, left: 16, right: 16,
                    child: Row(
                      children: [
                        ClubAvatar(
                          clubId: _club.id,
                          clubName: _club.name,
                          color: Colors.white,
                          size: 40,
                          fontSize: 16,
                          shape: 'circle',
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_club.name,
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(_timeAgoStory(story.postedAt),
                                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                        ),
                        if (_isOwner)
                          GestureDetector(
                            onTap: _deleteCurrentStory,
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.25),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                            ),
                          ),
                        GestureDetector(
                          onTap: _animatedPop,
                          child: const Icon(Icons.close, color: Colors.white, size: 26),
                        ),
                      ],
                    ),
                  ),

                  // Emoji (bottom-left, only if set)
                  if (story.emoji != null)
                    Positioned(
                      left: 28, bottom: 80,
                      child: Text(story.emoji!, style: const TextStyle(fontSize: 52)),
                    ),

                  // Overlay text at saved position + color
                  if (story.text.isNotEmpty)
                    LayoutBuilder(
                      builder: (ctx, constraints) {
                        const maxW = 300.0;
                        final sw = constraints.maxWidth;
                        final sh = constraints.maxHeight;
                        final left = (story.textOffsetX * sw - maxW / 2)
                            .clamp(0.0, sw - maxW);
                        final top = (story.textOffsetY * sh - 22)
                            .clamp(40.0, sh - 80);
                        return Stack(
                          children: [
                            Positioned(
                              left: left, top: top,
                              child: Container(
                                constraints: const BoxConstraints(maxWidth: maxW),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  story.text,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(story.textColorValue),
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    shadows: const [
                                      Shadow(blurRadius: 6, color: Colors.black87),
                                      Shadow(blurRadius: 14, color: Colors.black54),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                  // Viewers bar (admin only — bottom of story)
                  if (_isOwner)
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: GestureDetector(
                        onTap: () {
                          _progressController.stop();
                          _showViewersSheet(context, _stories[_index].id, _stories[_index].text.isNotEmpty ? _stories[_index].text : 'Story')
                              .then((_) => _progressController.forward());
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.remove_red_eye_outlined, color: Colors.white70, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                '${viewTracker.viewCount(_stories[_index].id)} viewer${viewTracker.viewCount(_stories[_index].id) == 1 ? '' : 's'}',
                                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right, color: Colors.white54, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Tap left / right navigation
                  Row(
                    children: [
                      Expanded(child: GestureDetector(onTap: _prevStory, behavior: HitTestBehavior.translucent)),
                      Expanded(child: GestureDetector(onTap: _nextStory, behavior: HitTestBehavior.translucent)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
        ),
        ),
      ),
    );
  }
}

// ─── Viewers Sheet ────────────────────────────────────────────────────────────

class _ViewersSheet extends StatelessWidget {
  final String contentId;
  final String title;

  const _ViewersSheet({required this.contentId, required this.title});

  @override
  Widget build(BuildContext context) {
    final viewerList = viewTracker.viewers(contentId);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  const Icon(Icons.remove_red_eye_outlined, color: AppColors.primaryRed, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${viewerList.length} viewer${viewerList.length == 1 ? '' : 's'}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.text),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: AppColors.secondaryText, size: 22),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // List
            Expanded(
              child: viewerList.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.visibility_off_outlined, color: AppColors.secondaryText, size: 40),
                          SizedBox(height: 12),
                          Text('No views yet', style: TextStyle(color: AppColors.secondaryText, fontSize: 14)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: viewerList.length,
                      separatorBuilder: (_, s) => const Divider(height: 1, indent: 60),
                      itemBuilder: (_, i) {
                        final user = viewerList[i];
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.primaryRed.withValues(alpha: 0.12),
                            child: Text(
                              user.name.isNotEmpty ? user.name[0] : '?',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryRed),
                            ),
                          ),
                          title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.text)),
                          subtitle: Text(user.email, style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

const List<Color> _clubColors = [
  Color(0xFFB41C18), Color(0xFF1565C0), Color(0xFF2E7D32),
  Color(0xFF6A1B9A), Color(0xFFE65100), Color(0xFF00838F),
];

Color _colorForClub(String clubId) {
  final idx = clubs.indexWhere((c) => c.id == clubId);
  return _clubColors[(idx < 0 ? 0 : idx) % _clubColors.length];
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

// Returns the trending badge widget if score is high enough
Widget? _trendingBadge(double score) {
  if (score < 6) return null;
  final label = score >= 12 ? '🔥 Hot' : '📈 Trending';
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: score >= 12 ? const Color(0xFFFF6B35).withValues(alpha: 0.12) : AppColors.lightRed,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: score >= 12 ? const Color(0xFFFF6B35) : AppColors.primaryRed,
      ),
    ),
  );
}

void _openShareSheet(
  BuildContext context,
  String targetId,
  VoidCallback onShared, {
  String caption = '',
  String clubName = '',
}) {
  final currentUser = authService.currentUser;
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ShareSheet(
      targetId: targetId,
      userId: currentUser?.id ?? authService.currentAdmin?.id ?? 'guest',
      onShared: onShared,
      caption: caption,
      clubName: clubName,
    ),
  );
}

/// True only when the current session belongs to an admin of [clubId].
/// Ensures analytics and moderation controls are never shown for other clubs.
bool _isOwnerOfClub(String clubId) {
  final admin = authService.currentAdmin;
  if (admin == null) return false;
  final club = clubs.firstWhere((c) => c.id == clubId, orElse: () => clubs.first);
  return (club.adminUserIds as List).contains(admin.id);
}

// ─── Post Card ────────────────────────────────────────────────────────────────

class _PostCard extends StatefulWidget {
  final NewsPost post;
  final double score;
  final int rank;
  final VoidCallback onUpdate;

  const _PostCard({required this.post, required this.score, required this.rank, required this.onUpdate});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> with SingleTickerProviderStateMixin {
  late AnimationController _heartController;
  bool _showHeart = false;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          setState(() => _showHeart = false);
          _heartController.reset();
        }
      });
    // Record this user as having seen the post
    final userId = authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
    viewTracker.recordView(widget.post.id, userId);
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  void _doubleTapLike() {
    if (!userState.isLiked(widget.post.id)) {
      userState.toggleLike(widget.post.id);
      likes.add(Like(id: DateTime.now().millisecondsSinceEpoch.toString(), postId: widget.post.id, userId: authService.currentUser?.id ?? 'guest'));
      contentStore.saveLikes();
    }
    setState(() => _showHeart = true);
    _heartController.forward();
    widget.onUpdate();
  }

  void _toggleLike() {
    final postId = widget.post.id;
    final userId = authService.currentUser?.id ?? 'guest';
    if (userState.isLiked(postId)) {
      userState.toggleLike(postId);
      likes.removeWhere((l) => l.postId == postId && l.userId == userId);
    } else {
      userState.toggleLike(postId);
      likes.add(Like(id: DateTime.now().millisecondsSinceEpoch.toString(), postId: postId, userId: userId));
    }
    contentStore.saveLikes();
    setState(() {});
    widget.onUpdate();
  }

  @override
  Widget build(BuildContext context) {
    final club = clubs.firstWhere((c) => c.id == widget.post.clubId);
    final clubColor = _colorForClub(club.id);
    final likeCount = postLikeCount(widget.post.id);
    final shareCount = postShareCount(widget.post.id);
    final uniqueCommenters = comments.where((c) => c.postId == widget.post.id).map((c) => c.userId).toSet().length;
    final postComments = comments.where((c) => c.postId == widget.post.id).toList();
    final isLiked = userState.isLiked(widget.post.id);
    final isSaved = userState.isSaved(widget.post.id);
    final badge = _trendingBadge(widget.score);

    return Container(
      color: AppColors.card,
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 6),
            child: Row(
              children: [
                ClubAvatar(
                  clubId: club.id,
                  clubName: club.name,
                  color: clubColor,
                  size: 38,
                  fontSize: 16,
                  shape: 'circle',
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(club.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.text),
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 6),
                          // ignore: use_null_aware_elements
                          if (badge != null) badge,
                        ],
                      ),
                      const SizedBox(height: 1),
                      Builder(builder: (ctx) {
                        final author = users.firstWhere(
                          (u) => u.id == widget.post.authorId,
                          orElse: () => users.first,
                        );
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => Navigator.push(
                            ctx,
                            MaterialPageRoute(builder: (_) => UserProfileScreen(user: author)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2, bottom: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  author.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.primaryRed,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _timeAgo(widget.post.createdAt),
                                  style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                ClubFollowButton(clubId: club.id, size: 'small'),
                IconButton(icon: const Icon(Icons.more_horiz, color: AppColors.secondaryText), onPressed: () {}, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
              ],
            ),
          ),

          // ── Image banner ──
          GestureDetector(
            onDoubleTap: _doubleTapLike,
            child: Stack(
              alignment: Alignment.center,
              children: [
                buildPostBanner(
                  imagePath: widget.post.imagePath,
                  fallbackColor: clubColor,
                  fallbackLetter: club.name[0],
                  height: 200,
                ),
                if (_showHeart)
                  ScaleTransition(
                    scale: Tween(begin: 0.5, end: 1.4).animate(CurvedAnimation(parent: _heartController, curve: Curves.elasticOut)),
                    child: const Icon(Icons.favorite, color: Colors.white, size: 80),
                  ),
              ],
            ),
          ),

          // ── Action row ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Row(
              children: [
                _ActionBtn(icon: isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.pink : AppColors.text, onTap: _toggleLike),
                _ActionBtn(icon: Icons.chat_bubble_outline, color: AppColors.text, onTap: () => _openComments(context)),
                _ActionBtn(
                  icon: Icons.send_outlined,
                  color: AppColors.text,
                  onTap: () => _openShareSheet(
                    context,
                    widget.post.id,
                    () { setState(() {}); widget.onUpdate(); },
                    caption: widget.post.content,
                    clubName: clubs.firstWhere((c) => c.id == widget.post.clubId, orElse: () => clubs.first).name,
                  ),
                ),
                const Spacer(),
                _ActionBtn(
                  icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: isSaved ? AppColors.primaryRed : AppColors.text,
                  onTap: () {
                    setState(() => userState.toggleSave(widget.post.id));
                    userPrefsService.save(authService.currentUser?.id ?? authService.currentAdmin?.id ?? '');
                  },
                ),
              ],
            ),
          ),

          // ── Engagement stats (own-club admin only) ──
          if (_isOwnerOfClub(widget.post.clubId)) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _EngagementBar(
                likes: likeCount,
                commenters: uniqueCommenters,
                shares: shareCount,
                score: widget.score,
                views: viewTracker.viewCount(widget.post.id),
                onViewTap: () => showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => _ViewersSheet(contentId: widget.post.id, title: 'Post Viewers'),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],

          // ── Caption ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: RichText(
              text: TextSpan(children: [
                TextSpan(text: '${club.name}  ', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.text, fontSize: 13)),
                TextSpan(text: widget.post.content, style: const TextStyle(color: AppColors.text, fontSize: 13)),
              ]),
            ),
          ),
          const SizedBox(height: 4),

          // ── Comment preview ──
          if (postComments.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: GestureDetector(
                onTap: () => _openComments(context),
                child: Text(
                  _isOwnerOfClub(widget.post.clubId)
                      ? 'View all ${postComments.length} comment${postComments.length == 1 ? '' : 's'}'
                      : 'View comments',
                  style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Builder(builder: (_) {
                final last = postComments.last;
                final commenter = users.firstWhere((u) => u.id == last.userId, orElse: () => users.first);
                return RichText(
                  text: TextSpan(children: [
                    TextSpan(text: '${commenter.name}  ', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.text, fontSize: 12)),
                    TextSpan(text: last.content, style: const TextStyle(color: AppColors.text, fontSize: 12)),
                  ]),
                );
              }),
            ),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  void _openComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(postId: widget.post.id, clubId: widget.post.clubId),
    ).then((_) => setState(() {}));
  }
}

// ─── Event Card (in feed) ─────────────────────────────────────────────────────

class _EventCard extends StatefulWidget {
  final Event event;
  final double score;
  final int rank;
  final VoidCallback onUpdate;

  const _EventCard({required this.event, required this.score, required this.rank, required this.onUpdate});

  @override
  State<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<_EventCard> {
  bool? _lastAttending;

  @override
  void initState() {
    super.initState();
    final userId = authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
    rsvpStore.seed(
      widget.event.id,
      widget.event.attendeeUserIds.contains(userId),
    );
    _lastAttending = rsvpStore.isAttending(widget.event.id);
    rsvpStore.addListener(_onRsvpChanged);
    viewTracker.recordView(widget.event.id, userId);
  }

  @override
  void dispose() {
    rsvpStore.removeListener(_onRsvpChanged);
    super.dispose();
  }

  void _onRsvpChanged() {
    final current = rsvpStore.isAttending(widget.event.id);
    if (current == _lastAttending) return; // different event changed, skip
    _lastAttending = current;
    if (mounted) {
      setState(() {}); // refresh uniqueAttendees / engagement bar
      widget.onUpdate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final club = clubs.firstWhere((c) => c.id == widget.event.clubId);
    final clubColor = _colorForClub(club.id);
    final dt = widget.event.dateTime;
    final shareCount = postShareCount(widget.event.id);
    final uniqueAttendees = widget.event.attendeeUserIds.toSet().length;
    final badge = _trendingBadge(widget.score);

    final daysAway = dt.difference(DateTime.now()).inDays;
    final daysLabel = daysAway == 0 ? 'Today' : daysAway == 1 ? 'Tomorrow' : 'In $daysAway days';

    return Container(
      color: AppColors.card,
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 6),
            child: Row(
              children: [
                ClubAvatar(
                  clubId: club.id,
                  clubName: club.name,
                  color: clubColor,
                  size: 38,
                  fontSize: 16,
                  shape: 'circle',
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(club.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.text), overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.accentGold.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                            child: const Text('Event', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFB8860B))),
                          ),
                          if (badge != null) ...[const SizedBox(width: 4), badge],
                        ],
                      ),
                      Text(daysLabel, style: const TextStyle(fontSize: 11, color: AppColors.primaryRed, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                ClubFollowButton(clubId: club.id, size: 'small'),
              ],
            ),
          ),

          // ── Event banner ──
          Container(
            width: double.infinity,
            height: 160,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [clubColor.withValues(alpha: 0.8), clubColor.withValues(alpha: 0.3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                // Big date in background
                Positioned(
                  right: 16, top: 12,
                  child: Text(
                    '${dt.day}',
                    style: TextStyle(fontSize: 80, fontWeight: FontWeight.w900, color: Colors.white.withValues(alpha: 0.15)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Date chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_monthAbbr(dt.month)} ${dt.day}  ·  ${_fmt12(dt)}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(widget.event.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 4, color: Colors.black45)])),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Action row ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Row(
              children: [
                // RSVP button — reads/writes global store
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: RsvpButton(
                    eventId: widget.event.id,
                    color: AppColors.primaryRed,
                    compact: true,
                  ),
                ),
                const SizedBox(width: 4),
                _ActionBtn(
                  icon: Icons.send_outlined,
                  color: AppColors.text,
                  onTap: () => _openShareSheet(
                    context,
                    widget.event.id,
                    () { setState(() {}); widget.onUpdate(); },
                    caption: widget.event.title,
                    clubName: clubs.firstWhere((c) => c.id == widget.event.clubId, orElse: () => clubs.first).name,
                  ),
                ),
                const Spacer(),
                _ActionBtn(
                  icon: userState.isSaved(widget.event.id) ? Icons.bookmark : Icons.bookmark_border,
                  color: userState.isSaved(widget.event.id) ? AppColors.primaryRed : AppColors.text,
                  onTap: () {
                    setState(() => userState.toggleSave(widget.event.id));
                    userPrefsService.save(authService.currentUser?.id ?? authService.currentAdmin?.id ?? '');
                  },
                ),
              ],
            ),
          ),

          // ── Engagement stats (own-club admin only) ──
          if (_isOwnerOfClub(widget.event.clubId)) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _EngagementBar(
                likes: uniqueAttendees,
                likesLabel: 'attending',
                commenters: 0,
                shares: shareCount,
                score: widget.score,
                views: viewTracker.viewCount(widget.event.id),
                onViewTap: () => showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => _ViewersSheet(contentId: widget.event.id, title: 'Event Viewers'),
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),

          // ── Description ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: RichText(
              text: TextSpan(children: [
                TextSpan(text: '${club.name}  ', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.text, fontSize: 13)),
                TextSpan(text: widget.event.description, style: const TextStyle(color: AppColors.text, fontSize: 13)),
              ]),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  String _monthAbbr(int m) => ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];

  String _fmt12(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }
}

// ─── Engagement Bar ───────────────────────────────────────────────────────────

class _EngagementBar extends StatelessWidget {
  final int likes;
  final String likesLabel;
  final int commenters;
  final int shares;
  final int views;
  final double score;
  final VoidCallback? onViewTap;

  const _EngagementBar({
    required this.likes,
    required this.commenters,
    required this.shares,
    required this.score,
    this.likesLabel = 'likes',
    this.views = 0,
    this.onViewTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (views > 0) ...[
          GestureDetector(
            onTap: onViewTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.remove_red_eye_outlined, size: 13, color: AppColors.secondaryText),
                const SizedBox(width: 3),
                Text('$views view${views == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 12, color: AppColors.secondaryText,
                        decoration: TextDecoration.underline)),
              ],
            ),
          ),
        ],
        if (likes > 0) ...[
          if (views > 0) const SizedBox(width: 10),
          const Icon(Icons.favorite, size: 13, color: Colors.pink),
          const SizedBox(width: 3),
          Text('$likes $likesLabel', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text)),
        ],
        if (commenters > 0) ...[
          const SizedBox(width: 10),
          const Icon(Icons.chat_bubble, size: 13, color: Color(0xFF1565C0)),
          const SizedBox(width: 3),
          Text('$commenters ${commenters == 1 ? 'person' : 'people'} commented', style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
        ],
        if (shares > 0) ...[
          const SizedBox(width: 10),
          const Icon(Icons.send, size: 13, color: Color(0xFF2E7D32)),
          const SizedBox(width: 3),
          Text('$shares share${shares == 1 ? '' : 's'}', style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
        ],
      ],
    );
  }
}

// ─── Action Button ────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: color, size: 26),
      onPressed: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}

// ─── Share Bottom Sheet ───────────────────────────────────────────────────────

class _ShareSheet extends StatefulWidget {
  final String targetId;
  final String userId;
  final VoidCallback onShared;
  final String caption;
  final String clubName;

  const _ShareSheet({
    required this.targetId,
    required this.userId,
    required this.onShared,
    required this.caption,
    required this.clubName,
  });

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  bool _storyPosted = false;
  final Set<String> _sentToIds = {};
  final _searchCtrl = TextEditingController();
  String _query = '';

  String get _myId =>
      authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

  List<User> get _friends => users
      .where((u) => userState.isFollowingUser(u.id) && u.id != _myId)
      .toList();

  List<User> get _filtered {
    if (_query.isEmpty) return _friends;
    final q = _query.toLowerCase();
    return _friends.where((u) => u.name.toLowerCase().contains(q)).toList();
  }

  void _recordShare() {
    final alreadyShared = shares.any(
        (s) => s.targetId == widget.targetId && s.userId == widget.userId);
    if (!alreadyShared) {
      shares.add(Share(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        targetId: widget.targetId,
        userId: widget.userId,
        createdAt: DateTime.now(),
      ));
      contentStore.saveShares();
      widget.onShared();
    }
  }

  void _addToStory() {
    _recordShare();
    final admin = authService.currentAdmin;
    if (admin != null) {
      try {
        final myClub =
            clubs.firstWhere((c) => c.adminUserIds.contains(admin.id));
        final preview = widget.caption.length > 120
            ? '${widget.caption.substring(0, 120)}…'
            : widget.caption;
        clubStories.add(ClubStory(
          id: 'repost_${DateTime.now().millisecondsSinceEpoch}',
          clubId: myClub.id,
          emoji: '🔁',
          text: 'Reposted from ${widget.clubName}\n\n$preview',
          postedAt: DateTime.now(),
        ));
      } catch (_) {
        // no club found — success feedback still shown
      }
    }
    setState(() => _storyPosted = true);
  }

  Future<void> _sendToFriend(String friendId) async {
    _recordShare();
    await messageService.saveMessage(Message(
      id: 'share_${DateTime.now().millisecondsSinceEpoch}_$friendId',
      senderId: _myId,
      receiverId: friendId,
      content: 'kupost:${widget.targetId}',
      sentAt: DateTime.now(),
    ));
    setState(() => _sentToIds.add(friendId));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.88,
      snap: true,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle + title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                children: [
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.lightGray,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Share', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  const SizedBox(height: 2),
                  const Text(
                    'Choose how you\'d like to share this',
                    style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.lightGray),

            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // ── Option 1: Add to Story ────────────────────────────
                  _ShareOptionTile(
                    icon: Icons.auto_stories_rounded,
                    iconColor: const Color(0xFF7B5EA7),
                    iconBg: const Color(0xFFF0EAFA),
                    title: 'Add to your story',
                    subtitle: 'Repost this to your club\'s story',
                    trailing: _storyPosted
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 14, color: Colors.green),
                                SizedBox(width: 4),
                                Text('Added', style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          )
                        : const Icon(Icons.chevron_right_rounded, color: AppColors.secondaryText),
                    onTap: _storyPosted ? null : _addToStory,
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Divider(height: 1, color: AppColors.lightGray),
                  ),

                  // ── Option 2: Send to Friend ──────────────────────────
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 6, 16, 8),
                    child: Text(
                      'SEND TO A FRIEND',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.secondaryText, letterSpacing: 0.8),
                    ),
                  ),

                  // Search box
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _query = v),
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Search friends',
                          hintStyle: TextStyle(color: AppColors.secondaryText, fontSize: 14),
                          prefixIcon: Icon(Icons.search, size: 18, color: AppColors.secondaryText),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),

                  // Friends list
                  if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: Text(
                          'Follow people to send them posts',
                          style: TextStyle(color: AppColors.secondaryText, fontSize: 14),
                        ),
                      ),
                    )
                  else
                    ...filtered.map((u) => _FriendSendRow(
                          user: u,
                          sent: _sentToIds.contains(u.id),
                          onSend: _sentToIds.contains(u.id) ? null : () => _sendToFriend(u.id),
                        )),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareOptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _ShareOptionTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(13)),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _FriendSendRow extends StatelessWidget {
  final User user;
  final bool sent;
  final VoidCallback? onSend;

  const _FriendSendRow({required this.user, required this.sent, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          UserAvatar(userId: user.id, name: user.name, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text(user.email, style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: sent ? Colors.green.withValues(alpha: 0.1) : AppColors.primaryRed,
                borderRadius: BorderRadius.circular(20),
                border: sent ? Border.all(color: Colors.green.withValues(alpha: 0.35)) : null,
              ),
              child: sent
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded, size: 13, color: Colors.green),
                        SizedBox(width: 4),
                        Text('Sent', style: TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w600)),
                      ],
                    )
                  : const Text('Send', style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Comments Bottom Sheet ────────────────────────────────────────────────────

class _CommentsSheet extends StatefulWidget {
  final String postId;
  final String clubId;
  const _CommentsSheet({required this.postId, required this.clubId});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _post() {
    final user = authService.currentUser;
    if (user == null) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    comments.add(Comment(id: DateTime.now().millisecondsSinceEpoch.toString(), postId: widget.postId, userId: user.id, content: text, createdAt: DateTime.now()));
    contentStore.saveComments();
    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final postComments = comments.where((c) => c.postId == widget.postId).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          children: [
            Container(margin: const EdgeInsets.only(top: 10, bottom: 6), width: 40, height: 4, decoration: BoxDecoration(color: AppColors.lightGray, borderRadius: BorderRadius.circular(2))),
            Text(
              _isOwnerOfClub(widget.clubId) ? 'Comments (${postComments.length})' : 'Comments',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const Divider(),
            Expanded(
              child: postComments.isEmpty
                  ? const Center(child: Text('No comments yet. Be the first!', style: TextStyle(color: AppColors.secondaryText)))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: postComments.length,
                      itemBuilder: (context, i) {
                        final c = postComments[i];
                        final commenter = users.firstWhere((u) => u.id == c.userId, orElse: () => users.first);
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(radius: 16, backgroundColor: AppColors.lightRed, child: Text(commenter.name[0], style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryRed, fontSize: 13))),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  RichText(text: TextSpan(children: [
                                    TextSpan(text: '${commenter.name}  ', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.text, fontSize: 13)),
                                    TextSpan(text: c.content, style: const TextStyle(color: AppColors.text, fontSize: 13)),
                                  ])),
                                  const SizedBox(height: 2),
                                  Text(_timeAgo(c.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                                ]),
                              ),
                              // Admin-only delete button (own club only)
                              if (_isOwnerOfClub(widget.clubId))
                                GestureDetector(
                                  onTap: () {
                                    comments.removeWhere((x) => x.id == c.id);
                                    contentStore.saveComments();
                                    setState(() {});
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 8, top: 2),
                                    child: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade300),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: EdgeInsets.only(left: 12, right: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 12, top: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.lightRed,
                    child: Text((authService.currentUser?.name[0] ?? 'U').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryRed, fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: const TextStyle(color: AppColors.secondaryText, fontSize: 13),
                        filled: true, fillColor: AppColors.lightGray,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      ),
                      onSubmitted: (_) => _post(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(onTap: _post, child: const Text('Post', style: TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold, fontSize: 14))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
