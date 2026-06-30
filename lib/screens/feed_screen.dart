import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_colors.dart';
import '../services/app_strings.dart';
import '../services/locale_service.dart';
import '../services/content_store.dart';
import '../services/mock_data.dart';
import '../services/auth_service.dart';
import '../services/club_admin_access.dart';
import '../services/lazy_content_loader.dart';
import '../services/people_service.dart';
import '../services/user_state.dart';
import '../services/user_prefs_service.dart';
import '../services/personalization_service.dart';
import '../services/post_like_helper.dart';
import '../services/view_tracker.dart';
import '../services/tutorial_anchors.dart';
import '../widgets/club_avatar.dart';
import '../widgets/club_follow_button.dart';
import '../widgets/loading_skeleton.dart';
import '../widgets/user_follow_button.dart';
import '../models/share.dart';
import '../models/message.dart';
import '../models/news_post.dart';
import '../models/event.dart';
import '../models/user.dart';
import '../models/club.dart';
import '../services/message_service.dart';
import 'user_profile_screen.dart';
import 'club_profile_screen.dart';
import 'create_post_screen.dart' show buildPostBanner, CreatePostScreen;
import '../services/supabase_post_service.dart';
import '../services/club_notification_service.dart';
import '../widgets/user_avatar.dart';
import '../services/rsvp_store.dart';
import '../widgets/rsvp_button.dart';
import '../widgets/expandable_post_caption.dart';
import '../services/group_chat_service.dart';
import '../services/supabase_interaction_service.dart';
import 'group_chat_screen.dart';
import 'notifications_screen.dart';
import 'this_week_screen.dart';
import 'event_detail_screen.dart';

// ─── Feed Item (unified post + event wrapper) ─────────────────────────────────

class _FeedItem {
  final String id;
  final bool isEvent; // true = Event, false = NewsPost
  final dynamic data; // NewsPost | Event
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

Club? _clubById(String id) {
  for (final club in clubs) {
    if (club.id == id) return club;
  }
  return null;
}

// ─── Feed Screen ──────────────────────────────────────────────────────────────

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  // 0 = Following (followed clubs only), 1 = All
  int _feedTab = 1;

  bool get _followedOnly => authService.isStudentSession && _feedTab == 0;

  Set<String> get _followedIds => userState.followedClubIds;

  bool _clubVisible(String clubId) =>
      !_followedOnly || _followedIds.contains(clubId);

  List<_FeedItem> _buildFeed() {
    final items = newsPosts
        .where((post) => _clubById(post.clubId) != null)
        .where((post) => _clubVisible(post.clubId))
        .map(
          (post) => _FeedItem(
            id: post.id,
            isEvent: false,
            data: post,
            score: postScore(post.id),
            postedAt: post.createdAt,
          ),
        )
        .toList();
    items.sort((a, b) => b.postedAt.compareTo(a.postedAt));
    return items;
  }

  bool _loadingPeopleDirectory = false;
  bool _loadingFeedContent = false;

  // Profile users to suggest in the feed. Prefer people who follow me but I do
  // not follow back, then other unfollowed profiles. If no eligible profiles
  // remain, the suggestion rail is omitted.
  List<User> _suggestedUsers() {
    final myId =
        authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
    final myFollowing = userState.followedUserIds;
    final myFollowers = peopleService.cachedFollowerIds;
    final profiles = peopleService.cachedPeople
        .where((user) => user.id != myId)
        .toList();
    final suggested = <String, User>{};

    void addAll(Iterable<User> candidates) {
      for (final user in candidates) {
        suggested.putIfAbsent(user.id, () => user);
      }
    }

    addAll(
      profiles.where(
        (user) =>
            myFollowers.contains(user.id) && !myFollowing.contains(user.id),
      ),
    );

    addAll(
      peopleService
          .randomProfiles(excludeId: myId)
          .where((user) => !myFollowing.contains(user.id)),
    );

    return suggested.values.toList();
  }

  // Clubs the user doesn't follow yet, ranked by how well they match the
  // user's interests, then by popularity — "which club should I follow next".
  List<dynamic> _suggestedClubs() {
    if (!authService.isStudentSession) return const [];
    return clubs
        .where((c) => !userState.followedClubIds.contains(c.id))
        .toList()
      ..sort((a, b) {
        final byInterest = personalizationService
            .interestMatchCount(b.id)
            .compareTo(personalizationService.interestMatchCount(a.id));
        if (byInterest != 0) return byInterest;
        return clubMemberCount(b.id).compareTo(clubMemberCount(a.id));
      });
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
  //   every 10 posts → People You Might Know (friend suggestions)
  //   every 15 posts → a trending event suggestion
  //   every 20 posts → a "club you should follow" suggestion (interest-ranked,
  //                    cycling through candidates so it isn't always the same)
  // Tapping any suggestion opens that person, event, or club.
  List<dynamic> _buildMixedFeed(List<_FeedItem> posts) {
    final result = <dynamic>[];
    final peopleSuggestions = _suggestedUsers();
    final clubSuggestions = _suggestedClubs();
    final trendingEv = _trendingEvent();
    int clubIdx = 0;

    for (int i = 0; i < posts.length; i++) {
      result.add(posts[i]);
      final n = i + 1;
      if (n % 10 == 0 && peopleSuggestions.isNotEmpty) {
        result.add(peopleSuggestions);
      }
      if (n % 15 == 0 && trendingEv != null) {
        result.add(_EventSuggestion(trendingEv));
      }
      if (n % 20 == 0 && clubSuggestions.isNotEmpty) {
        result.add(
          _ClubSuggestion(clubSuggestions[clubIdx % clubSuggestions.length]),
        );
        clubIdx++;
      }
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    viewTracker.addListener(_onViewCountsChanged);
    localeService.addListener(_onLocaleChanged);
    _loadFeedContent();
    _loadPeopleDirectory();
  }

  @override
  void dispose() {
    viewTracker.removeListener(_onViewCountsChanged);
    localeService.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onViewCountsChanged() {
    if (mounted) setState(() {});
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  void _hydrateVisiblePostViews() {
    viewTracker.hydratePostViewCounts(newsPosts.map((post) => post.id));
  }

  Future<void> _onRefresh() async {
    try {
      await lazyContentLoader.refreshContent();
    } catch (_) {
      // Keep currently loaded content if the network request fails.
    }
    await _loadPeopleDirectory();
    _hydrateVisiblePostViews();
    setState(() {});
  }

  Future<void> _loadFeedContent() async {
    if (mounted) setState(() => _loadingFeedContent = true);
    try {
      await lazyContentLoader.ensureContentLoaded();
      _hydrateVisiblePostViews();
    } catch (_) {
      // Keep local seed data visible if Supabase content is unreachable.
    } finally {
      if (mounted) setState(() => _loadingFeedContent = false);
    }
  }

  Future<void> _loadPeopleDirectory() async {
    if (_loadingPeopleDirectory) return;
    _loadingPeopleDirectory = true;
    final myId =
        authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
    try {
      await peopleService.refreshPeopleDirectory(excludeId: myId);
      if (mounted) setState(() {});
    } catch (_) {
      // Keep the feed usable; the card simply won't render until profiles load.
    } finally {
      _loadingPeopleDirectory = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mixed = _buildMixedFeed(_buildFeed());
    final showFeedSkeleton = _loadingFeedContent && mixed.isEmpty;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppColors.primaryRed,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildTopBar(),
            _buildGreeting(),
            _buildEventsRail(),
            _buildFeedTabs(),
            _buildComposer(),
            if (showFeedSkeleton) ...[
              ..._buildFeedSkeletonSlivers(),
            ] else if (mixed.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.explore_outlined,
                          size: 64,
                          color: AppColors.secondaryText.withValues(
                            alpha: 0.35,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          S.nothingHere,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          S.followClubs,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.secondaryText,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => setState(() => _feedTab = 1),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryRed,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          icon: Icon(Icons.explore_rounded, size: 18),
                          label: Text(
                            S.exploreClubs,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
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
                      Text(
                        S.latest,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, i) {
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
                }, childCount: mixed.length),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).padding.bottom + 112,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFeedSkeletonSlivers() {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
          child: SkeletonBox(
            width: 70,
            height: 18,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) => const _FeedPostSkeleton(),
          childCount: 4,
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(height: MediaQuery.of(context).padding.bottom + 112),
      ),
    ];
  }

  String get _greetingName {
    final student = authService.currentUser;
    if (authService.isStudentSession && student != null) {
      return student.name.split(' ').first;
    }

    final admin = authService.currentAdmin;
    if (admin != null) {
      return managedClubForAdmin(admin.id)?.name ?? admin.name;
    }

    return '';
  }

  // ── UniHub top bar ───────────────────────────────────────────────────────
  SliverAppBar _buildTopBar() {
    return SliverAppBar(
      pinned: true,
      floating: false,
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 56,
      leading: const SizedBox.shrink(),
      leadingWidth: 0,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            // UniHub logotype
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Uni',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                      letterSpacing: -0.8,
                    ),
                  ),
                  TextSpan(
                    text: 'Hub',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                      color: AppColors.primaryRed,
                      letterSpacing: -0.8,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Bell button with unread badge
            ListenableBuilder(
              listenable: userState,
              builder: (_, x) => GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => NotificationsScreen()),
                ),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Center(
                        child: Icon(
                          Icons.notifications_none_rounded,
                          size: 18,
                          color: AppColors.text,
                        ),
                      ),
                      if (userState.unreadNotifications > 0)
                        Positioned(
                          top: 7,
                          right: 8,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: AppColors.primaryRed,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.card,
                                width: 1.5,
                              ),
                            ),
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
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: AppColors.divider.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  // ── Greeting ─────────────────────────────────────────────────────────────
  SliverToBoxAdapter _buildGreeting() {
    final h = DateTime.now().hour;
    final greet = h < 5
        ? S.stillUp
        : h < 12
        ? S.goodMorning
        : h < 17
        ? S.goodAfternoon
        : S.goodEvening;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$greet,',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: 2),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: _greetingName,
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                      letterSpacing: -1.2,
                      height: 1.02,
                    ),
                  ),
                  TextSpan(
                    text: '.',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryRed,
                      letterSpacing: -1.2,
                      height: 1.02,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── This Week events rail ─────────────────────────────────────────────────
  SliverToBoxAdapter _buildEventsRail() {
    final now = DateTime.now();
    final weekEnd = now.add(const Duration(days: 7));
    final weekEvents =
        events
            .where(
              (e) =>
                  e.dateTime.isAfter(now.subtract(const Duration(hours: 2))) &&
                  e.dateTime.isBefore(weekEnd),
            )
            .toList()
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    if (weekEvents.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final shown = weekEvents.take(10).toList();
    final userId =
        authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
    rsvpStore.seedAll(shown, userId);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    S.thisWeek,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.secondaryText,
                      letterSpacing: 0.9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ThisWeekScreen()),
                    ),
                    child: Text(
                      S.seeAll,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.primaryRed,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: shown.length,
                separatorBuilder: (_, i) => const SizedBox(width: 12),
                itemBuilder: (ctx, i) => _EventRailCard(event: shown[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Feed section header + filter tabs ────────────────────────────────────
  SliverToBoxAdapter _buildFeedTabs() {
    if (!authService.isStudentSession) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text(
            S.clubFeed,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.secondaryText,
              letterSpacing: 0.9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    // tab 0 = Following, tab 1 = All
    final tabs = [('following', S.following), ('all', S.all)];
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: Row(
          children: [
            Text(
              S.fromYourClubs,
              style: TextStyle(
                fontSize: 10,
                color: AppColors.secondaryText,
                letterSpacing: 0.9,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Row(
              key: tutorialAnchors.keyFor(TutorialAnchors.homeFeedToggle),
              children: tabs.asMap().entries.map((entry) {
                final i = entry.key;
                final label = entry.value.$2;
                final active = _feedTab == i;
                return GestureDetector(
                  onTap: () => setState(() => _feedTab = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(left: i == 0 ? 0 : 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: active ? AppColors.primaryRed : Colors.transparent,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: active
                            ? AppColors.primaryRed
                            : AppColors.divider.withValues(alpha: 1.4),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: active ? Colors.white : AppColors.secondaryText,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Quick post composer (club admins only) ───────────────────────────────
  // Inline card for the managing admin to post a quick text update to their
  // club, mirroring the design's composer. Hidden for student sessions and
  // admins without a managed club, since only clubs author posts.
  Widget _buildComposer() {
    final admin = authService.currentAdmin;
    if (admin == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final club = managedClubForAdmin(admin.id);
    if (club == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
        child: _QuickPostComposer(
          club: club,
          color: _colorForClub(club.id),
          onPosted: () => setState(() {}),
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
      key: ValueKey(item.id),
      post: item.data as NewsPost,
      score: item.score,
      rank: rank,
      onUpdate: () => setState(() {}),
    );
  }
}

class _FeedPostSkeleton extends StatelessWidget {
  const _FeedPostSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(
          bottom: BorderSide(
            color: AppColors.divider.withValues(alpha: 0.7),
            width: 0.6,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox.circle(size: 44),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(
                  width: 128,
                  height: 14,
                  borderRadius: BorderRadius.circular(7),
                ),
                const SizedBox(height: 8),
                SkeletonBox(
                  width: double.infinity,
                  height: 12,
                  borderRadius: BorderRadius.circular(6),
                ),
                const SizedBox(height: 6),
                SkeletonBox(
                  width: MediaQuery.sizeOf(context).width * 0.46,
                  height: 12,
                  borderRadius: BorderRadius.circular(6),
                ),
                const SizedBox(height: 12),
                SkeletonBox(
                  width: double.infinity,
                  height: 176,
                  borderRadius: BorderRadius.circular(16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Quick Post Composer ──────────────────────────────────────────────────────

/// Inline composer card shown at the top of the feed for the managing club
/// admin. Collapsed it's a single-line prompt; once focused it expands to a
/// multi-line field with a photo / event action row, a 280-char counter, and a
/// Post button. Text posts publish through the same path as CreatePostScreen.
class _QuickPostComposer extends StatefulWidget {
  final dynamic club; // Club
  final Color color;
  final VoidCallback onPosted;

  const _QuickPostComposer({
    required this.club,
    required this.color,
    required this.onPosted,
  });

  @override
  State<_QuickPostComposer> createState() => _QuickPostComposerState();
}

class _QuickPostComposerState extends State<_QuickPostComposer> {
  static const int _maxChars = 500;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _focused = false;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus && !_focused) {
      setState(() => _focused = true);
    }
  }

  void _onTextChanged() => setState(() {});

  int get _remaining => _maxChars - _controller.text.length;

  bool get _canPost =>
      !_posting && _controller.text.trim().isNotEmpty && _remaining >= 0;

  Future<void> _post() async {
    if (!_canPost) return;
    final content = _controller.text.trim();
    setState(() => _posting = true);
    try {
      final post = await supabasePostService.createPost(
        clubId: widget.club.id as String,
        authorId: authService.currentAdmin?.id ?? '',
        content: content,
        taggedClubIds: const [],
        taggedUserIds: const [],
        imagePath: null,
      );
      if (!mounted) return;
      newsPosts.insert(0, post);
      unawaited(contentStore.saveNewsPosts());
      unawaited(clubNotificationService.notifyFollowersAboutPost(post));
      _controller.clear();
      _focusNode.unfocus();
      setState(() {
        _focused = false;
        _posting = false;
      });
      widget.onPosted();
    } catch (error) {
      if (!mounted) return;
      setState(() => _posting = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not publish post. Check Supabase settings.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  // Opens the full post creation screen (with photo upload). Used by the
  // image-add button in the composer action bar.
  void _openFullComposer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreatePostScreen(
          onPosted: widget.onPosted,
          startWithPhotoUpload: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = AppColors.background;
    final textColor = AppColors.text;
    final secondaryTextColor = AppColors.secondaryText;

    return Material(
      color: surfaceColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClubAvatar(
              key: ValueKey('quick-post-club-avatar-${widget.club.id}'),
              clubId: widget.club.id as String,
              clubName: widget.club.name as String,
              color: textColor,
              size: 42,
              fontSize: 18,
              shape: 'circle',
              borderRadius: 13,
              imageUrl: widget.club.logoUrl as String?,
              profilePhotoFallbackId: authService.currentAdmin?.id,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Read-only club label
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      widget.club.name as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: secondaryTextColor,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                  // Expanding text field — selection handles/highlight forced to
                  // the current text color so no burgundy accent appears.
                  Theme(
                    data: Theme.of(context).copyWith(
                      primaryColor: textColor,
                      focusColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      splashColor: Colors.transparent,
                      colorScheme: Theme.of(context).colorScheme.copyWith(
                        primary: textColor,
                        onPrimary: surfaceColor,
                        surface: surfaceColor,
                        onSurface: textColor,
                      ),
                      textSelectionTheme: TextSelectionThemeData(
                        cursorColor: textColor,
                        selectionColor: textColor.withValues(alpha: 0.18),
                        selectionHandleColor: textColor,
                      ),
                      inputDecorationTheme: InputDecorationTheme(
                        filled: true,
                        fillColor: surfaceColor,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                      ),
                    ),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: _focused ? 5 : 1,
                      maxLength: _maxChars,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      textCapitalization: TextCapitalization.sentences,
                      cursorColor: textColor,
                      style: TextStyle(
                        fontSize: 15,
                        color: textColor,
                        height: 1.55,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        filled: true,
                        fillColor: surfaceColor,
                        counterText: '',
                        hintText: S.whatsHappeningAtClub,
                        hintStyle: TextStyle(
                          fontSize: 15,
                          color: secondaryTextColor,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ),
                  // Action bar — revealed once focused
                  if (_focused) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Tooltip(
                          message: S.addPhoto,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _openFullComposer,
                            child: Icon(
                              Icons.image_outlined,
                              size: 19,
                              color: textColor,
                            ),
                          ),
                        ),
                        const Spacer(),
                        _PostButton(enabled: _canPost, onTap: _post),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _PostButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        child: Text(
          S.post,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
            color: enabled ? const Color(0xFFFFFFFF) : const Color(0xFF8A8A8E),
          ),
        ),
      ),
    );
  }
}

// ─── People You Might Know ────────────────────────────────────────────────────

class _PeopleSuggestionCard extends StatefulWidget {
  final List<User> suggestions;
  final VoidCallback onFollowed;
  const _PeopleSuggestionCard({
    required this.suggestions,
    required this.onFollowed,
  });

  @override
  State<_PeopleSuggestionCard> createState() => _PeopleSuggestionCardState();
}

class _PeopleSuggestionCardState extends State<_PeopleSuggestionCard> {
  static const List<Color> _avatarColors = [
    Color(0xFF8C1D40),
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFF6A1B9A),
    Color(0xFFE65100),
    Color(0xFF00838F),
  ];

  @override
  Widget build(BuildContext context) {
    // Re-check live follow state so a newly followed person disappears at once.
    final shown = widget.suggestions
        .where((user) => !userState.isFollowingUser(user.id))
        .take(8)
        .toList();

    if (shown.isEmpty) return const SizedBox.shrink();

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
                Icon(
                  Icons.people_outline,
                  size: 18,
                  color: AppColors.primaryRed,
                ),
                const SizedBox(width: 6),
                Text(
                  S.peopleMightKnow,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
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
                                userState
                                    .displayNameFor(u.id, u.name)
                                    .split(' ')
                                    .first,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text,
                                ),
                              ),
                              Builder(
                                builder: (ctx) {
                                  final mutualCount = userState.followedUserIds
                                      .intersection(
                                        Set<String>.from(u.followingUserIds),
                                      )
                                      .length;
                                  if (mutualCount == 0) {
                                    return const SizedBox.shrink();
                                  }
                                  return Text(
                                    '$mutualCount mutual',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.secondaryText,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      UserFollowButton(
                        userId: u.id,
                        size: 'small',
                        onTap: () async {
                          final myId = authService.isStudentSession
                              ? authService.currentUser?.id ?? ''
                              : '';
                          if (myId.isEmpty) return;
                          final follow = !userState.isFollowingUser(u.id);
                          userState.setFollowingUser(u.id, follow);
                          userPrefsService.save(myId);
                          widget.onFollowed();
                          try {
                            await peopleService.setFollowing(
                              followerId: myId,
                              followingId: u.id,
                              follow: follow,
                            );
                            userPrefsService.save(myId);
                          } catch (_) {
                            userState.setFollowingUser(u.id, !follow);
                            userPrefsService.save(myId);
                            widget.onFollowed();
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1),
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
    Color(0xFFB41C18),
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFF6A1B9A),
    Color(0xFFE65100),
    Color(0xFF00838F),
  ];

  const _TrendingEventCard({required this.event, required this.onUpdate});

  void _showDetail(BuildContext context, Color color) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(event: event, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final club = _clubById(event.clubId);
    if (club == null) return const SizedBox.shrink();
    final idx = clubs.indexOf(club);
    final color = _colors[idx % _colors.length];
    final dt = event.dateTime;
    const mo = [
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
    final daysAway = dt.difference(DateTime.now()).inDays;
    final timeLabel = daysAway == 0
        ? S.today
        : daysAway == 1
        ? S.tomorrow
        : '${mo[dt.month - 1]} ${dt.day}';
    final views = viewTracker.viewCount(event.id);

    return GestureDetector(
      onTap: () => _showDetail(context, color),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        color: AppColors.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event body
            Container(
              margin: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
                        width: 4,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.text,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.event_rounded,
                                  size: 13,
                                  color: color,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  timeLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: color,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (event.location.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppColors.secondaryText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          event.location,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (views > 0) ...[
                        Icon(
                          Icons.visibility_outlined,
                          size: 14,
                          color: AppColors.secondaryText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$views views',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        S.tapForDetails,
                        style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 14, color: color),
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 1),
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
    Color(0xFF8C1D40),
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFF6A1B9A),
    Color(0xFFE65100),
    Color(0xFF00838F),
  ];

  @override
  Widget build(BuildContext context) {
    final c = widget.club;
    final idx = clubs.indexOf(c);
    final color = _colors[idx < 0 ? 0 : idx % _colors.length];
    final memberCount = clubMemberCount(c.id as String);
    final matches = personalizationService.interestMatchCount(c.id as String);
    final desc = (c.description as String).isNotEmpty
        ? c.description as String
        : 'Discover what this club is all about.';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClubProfileScreen(club: c, color: color),
        ),
      ),
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
                  Icon(Icons.explore_rounded, size: 18, color: color),
                  const SizedBox(width: 6),
                  Text(
                    S.clubMightLike,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
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
                      imageUrl: c.logoUrl,
                      size: 52,
                      fontSize: 20,
                    ),
                    const SizedBox(width: 12),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.name as String,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            desc,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.secondaryText,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                matches > 0
                                    ? Icons.auto_awesome_rounded
                                    : Icons.people_outline,
                                size: 13,
                                color: color,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  matches > 0
                                      ? '$memberCount members · matches your interests'
                                      : '$memberCount members',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: color,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (authService.isStudentSession)
                      ClubFollowButton(clubId: c.id as String),
                  ],
                ),
              ),
            ),
            Divider(height: 1),
          ],
        ),
      ),
    );
  }
}

class _PeopleEngagementSheet extends StatelessWidget {
  final IconData icon;
  final String emptyText;
  final List<User> people;
  final ScrollController scrollController;

  const _PeopleEngagementSheet({
    required this.icon,
    required this.emptyText,
    required this.people,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Handle
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primaryRed, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${people.length} ${people.length == 1 ? 'person' : 'people'}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.text,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(
                  Icons.close,
                  color: AppColors.secondaryText,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1),
        Expanded(
          child: people.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: AppColors.secondaryText, size: 40),
                      SizedBox(height: 12),
                      Text(
                        emptyText,
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: people.length,
                  separatorBuilder: (_, s) => Divider(height: 1, indent: 60),
                  itemBuilder: (_, i) {
                    final user = people[i];
                    return ListTile(
                      leading: UserAvatar(
                        userId: user.id,
                        name: user.name,
                        size: 40,
                        fontSize: 15,
                      ),
                      title: Text(
                        userState.displayNameFor(user.id, user.name),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.text,
                        ),
                      ),
                      subtitle: Text(
                        user.email,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserProfileScreen(user: user),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _PeopleEngagementSkeleton extends StatelessWidget {
  final IconData icon;
  final ScrollController scrollController;

  const _PeopleEngagementSkeleton({
    required this.icon,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primaryRed, size: 20),
              const SizedBox(width: 8),
              SkeletonBox(
                width: 118,
                height: 16,
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: AppColors.divider),
        Expanded(
          child: ListView.separated(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: 6,
            separatorBuilder: (_, s) =>
                Divider(height: 1, indent: 60, color: AppColors.divider),
            itemBuilder: (_, i) => const _PeopleEngagementSkeletonRow(),
          ),
        ),
      ],
    );
  }
}

class _PeopleEngagementSkeletonRow extends StatelessWidget {
  const _PeopleEngagementSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const SkeletonBox.circle(size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(
                  width: 140,
                  height: 13,
                  borderRadius: BorderRadius.circular(7),
                ),
                const SizedBox(height: 8),
                SkeletonBox(
                  width: 190,
                  height: 11,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewersSheet extends StatefulWidget {
  final String contentId;
  final String title;

  const _ViewersSheet({required this.contentId, required this.title});

  @override
  State<_ViewersSheet> createState() => _ViewersSheetState();
}

class _ViewersSheetState extends State<_ViewersSheet> {
  List<User> _viewers = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadViewers();
  }

  Future<void> _loadViewers() async {
    var viewers = viewTracker.viewers(widget.contentId);

    try {
      final remote = await supabaseInteractionService.fetchPostViewers(
        widget.contentId,
      );
      if (remote.isNotEmpty) viewers = remote;
    } catch (_) {
      // Keep local/Hive viewers.
    }

    if (!mounted) return;
    setState(() {
      _viewers = viewers;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: _loading
            ? _PeopleEngagementSkeleton(
                icon: Icons.remove_red_eye_outlined,
                scrollController: scrollController,
              )
            : _PeopleEngagementSheet(
                icon: Icons.remove_red_eye_outlined,
                emptyText: 'No views yet',
                people: _viewers,
                scrollController: scrollController,
              ),
      ),
    );
  }
}

class _LikersSheet extends StatefulWidget {
  final String postId;

  const _LikersSheet({required this.postId});

  @override
  State<_LikersSheet> createState() => _LikersSheetState();
}

class _LikersSheetState extends State<_LikersSheet> {
  List<User> _likers = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLikers();
  }

  Future<void> _loadLikers() async {
    var likers = users
        .where((user) {
          return likes.any(
            (like) => like.postId == widget.postId && like.userId == user.id,
          );
        })
        .toList()
        .cast<User>();

    try {
      final remote = await supabaseInteractionService.fetchPostLikers(
        widget.postId,
      );
      if (remote.isNotEmpty) likers = remote;
    } catch (_) {
      // Keep local/mock likers.
    }

    if (!mounted) return;
    setState(() {
      _likers = likers;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: _loading
            ? _PeopleEngagementSkeleton(
                icon: Icons.favorite_rounded,
                scrollController: scrollController,
              )
            : _PeopleEngagementSheet(
                icon: Icons.favorite_rounded,
                emptyText: 'No likes yet',
                people: _likers,
                scrollController: scrollController,
              ),
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

const List<Color> _clubColors = [
  Color(0xFFB41C18),
  Color(0xFF1565C0),
  Color(0xFF2E7D32),
  Color(0xFF6A1B9A),
  Color(0xFFE65100),
  Color(0xFF00838F),
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

void _openShareSheet(
  BuildContext context,
  String targetId,
  VoidCallback onShared, {
  bool isEvent = false,
}) {
  final currentUser = authService.currentUser;
  if (!authService.isStudentSession || currentUser == null) return;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ShareSheet(
      targetId: targetId,
      contentPrefix: isEvent ? 'kuevent' : 'kupost',
      userId: currentUser.id,
      onShared: onShared,
    ),
  );
}

/// True only when the current session belongs to an admin of [clubId].
/// Ensures analytics and moderation controls are never shown for other clubs.
bool _isOwnerOfClub(String clubId) {
  final admin = authService.currentAdmin;
  if (admin == null) return false;
  final club = clubs.firstWhere(
    (c) => c.id == clubId,
    orElse: () => clubs.first,
  );
  return clubIsManagedByAdmin(club, admin.id);
}

// ─── Post Card ────────────────────────────────────────────────────────────────

class _PostCard extends StatefulWidget {
  final NewsPost post;
  final double score;
  final int rank;
  final VoidCallback onUpdate;

  const _PostCard({
    super.key,
    required this.post,
    required this.score,
    required this.rank,
    required this.onUpdate,
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _heartController;
  bool _showHeart = false;

  @override
  void initState() {
    super.initState();
    _heartController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 700),
        )..addStatusListener((s) {
          if (s == AnimationStatus.completed) {
            setState(() => _showHeart = false);
            _heartController.reset();
          }
        });
    // Record this user as having seen the post
    final userId =
        authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
    viewTracker.recordView(widget.post.id, userId, syncRemote: true);
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  void _doubleTapLike() {
    if (!authService.isStudentSession) return;
    ensurePostLiked(widget.post.id);
    setState(() => _showHeart = true);
    _heartController.forward();
    widget.onUpdate();
  }

  void _toggleLike() {
    if (!authService.isStudentSession) return;
    togglePostLike(widget.post.id);
    setState(() {});
    widget.onUpdate();
  }

  void _showPostOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        Widget tile({
          required IconData icon,
          required String label,
          required VoidCallback onTap,
          Color? color,
        }) {
          return ListTile(
            leading: Icon(icon, color: color ?? AppColors.text),
            title: Text(
              label,
              style: TextStyle(
                color: color ?? AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () {
              Navigator.pop(sheetContext);
              onTap();
            },
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              tile(
                icon: Icons.link_rounded,
                label: 'Copy link',
                onTap: () {
                  Clipboard.setData(
                    ClipboardData(text: 'kuclubs://post/${widget.post.id}'),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Link copied to clipboard'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              tile(
                icon: Icons.flag_outlined,
                label: 'Report post',
                color: AppColors.primaryRed,
                onTap: _reportPost,
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _reportPost() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          'Report this post?',
          style: TextStyle(color: AppColors.text),
        ),
        content: Text(
          'Our team will review it for violations of community guidelines.',
          style: TextStyle(color: AppColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Thanks for the report. We\'ll take a look.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final club = _clubById(widget.post.clubId);
    if (club == null) return const SizedBox.shrink();
    final clubColor = _colorForClub(club.id);
    final likeCount = postLikeCount(widget.post.id);
    final shareCount = postShareCount(widget.post.id);
    final isLiked = userState.isLiked(widget.post.id);
    final isStudent = authService.isStudentSession;
    final ownContent = _isOwnerOfClub(widget.post.clubId);
    final hasImage =
        widget.post.imagePath != null && widget.post.imagePath!.isNotEmpty;

    // ── Twitter / X-style row: avatar gutter on the left, everything else in a
    //    right-hand column, posts separated by a hairline divider. ──
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(
          bottom: BorderSide(
            color: AppColors.divider.withValues(alpha: 0.7),
            width: 0.6,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Avatar gutter ──
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ClubProfileScreen(club: club, color: clubColor),
              ),
            ),
            child: ClubAvatar(
              clubId: club.id,
              clubName: club.name,
              color: clubColor,
              imageUrl: club.logoUrl,
              size: 44,
              fontSize: 18,
              shape: 'circle',
            ),
          ),
          const SizedBox(width: 11),
          // ── Body column ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: club identity + time, with follow + more on the right
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ClubProfileScreen(
                                        club: club,
                                        color: clubColor,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    club.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.5,
                                      color: AppColors.text,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            _timeAgo(widget.post.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isStudent)
                      ClubFollowButton(clubId: club.id, size: 'small'),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _showPostOptions,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4, top: 2),
                        child: Icon(
                          Icons.more_horiz,
                          size: 18,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),
                // ── Content ──
                if (widget.post.content.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  ExpandablePostCaption(
                    authorName: '',
                    caption: widget.post.content,
                    captionStyle: TextStyle(
                      color: AppColors.text,
                      fontSize: 14.5,
                      height: 1.45,
                    ),
                    moreStyle: TextStyle(
                      color: AppColors.primaryRed,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                // ── Media (indented, rounded) ──
                if (hasImage) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onDoubleTap: isStudent ? _doubleTapLike : null,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          buildPostBanner(
                            imagePath: widget.post.imagePath,
                            fallbackColor: clubColor,
                            fallbackLetter: club.name[0],
                            height: 190,
                          ),
                          if (_showHeart)
                            ScaleTransition(
                              scale: Tween(begin: 0.5, end: 1.4).animate(
                                CurvedAnimation(
                                  parent: _heartController,
                                  curve: Curves.elasticOut,
                                ),
                              ),
                              child: Icon(
                                Icons.favorite,
                                color: Colors.white,
                                size: 72,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                // ── Engagement stats (own-club admin only) ──
                if (ownContent) ...[
                  const SizedBox(height: 10),
                  _EngagementBar(
                    likes: likeCount,
                    shares: shareCount,
                    score: widget.score,
                    views: viewTracker.viewCount(widget.post.id),
                    onViewTap: () => showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (_) => _ViewersSheet(
                        contentId: widget.post.id,
                        title: 'Post Viewers',
                      ),
                    ),
                    onLikeTap: () => showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (_) => _LikersSheet(postId: widget.post.id),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                // ── Action row (counts inline, X-style) ──
                if (isStudent)
                  Row(
                    children: [
                      _twAction(
                        icon: isLiked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        count: null,
                        color: isLiked
                            ? AppColors.primaryRed
                            : AppColors.secondaryText,
                        onTap: _toggleLike,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // X-style action: an icon with an optional count beside it.
  Widget _twAction({
    required IconData icon,
    String? count,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 19, color: color),
            if (count != null) ...[
              const SizedBox(width: 6),
              Text(
                count,
                style: TextStyle(
                  fontSize: 12.5,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Event Card (in feed) ─────────────────────────────────────────────────────

class _EventCard extends StatefulWidget {
  final Event event;
  final double score;
  final int rank;
  final VoidCallback onUpdate;

  const _EventCard({
    required this.event,
    required this.score,
    required this.rank,
    required this.onUpdate,
  });

  @override
  State<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<_EventCard> {
  bool? _lastAttending;

  @override
  void initState() {
    super.initState();
    final userId =
        authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
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
      setState(() {});
      widget.onUpdate();
    }
  }

  void _openDetails(Color color) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(event: widget.event, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final club = _clubById(widget.event.clubId);
    if (club == null) return const SizedBox.shrink();
    final clubColor = _colorForClub(club.id);
    final dt = widget.event.dateTime;
    final shareCount = postShareCount(widget.event.id);

    final daysAway = dt.difference(DateTime.now()).inDays;
    final daysLabel = daysAway == 0
        ? S.today
        : daysAway == 1
        ? S.tomorrow
        : 'In $daysAway days';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openDetails(clubColor),
      child: Container(
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
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ClubProfileScreen(club: club, color: clubColor),
                      ),
                    ),
                    child: ClubAvatar(
                      clubId: club.id,
                      clubName: club.name,
                      color: clubColor,
                      imageUrl: club.logoUrl,
                      size: 38,
                      fontSize: 16,
                      shape: 'circle',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ClubProfileScreen(
                                      club: club,
                                      color: clubColor,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  club.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.text,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          daysLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primaryRed,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (authService.isStudentSession)
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
                  colors: [
                    clubColor.withValues(alpha: 0.8),
                    clubColor.withValues(alpha: 0.3),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  // Big date in background
                  Positioned(
                    right: 16,
                    top: 12,
                    child: Text(
                      '${dt.day}',
                      style: TextStyle(
                        fontSize: 80,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_monthAbbr(dt.month)} ${dt.day}  ·  ${_fmt12(dt)}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.event.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(blurRadius: 4, color: Colors.black45),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (authService.isStudentSession)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: RsvpButton(
                        eventId: widget.event.id,
                        color: AppColors.primaryRed,
                        isPast: !widget.event.endTime.isAfter(DateTime.now()),
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: 4),
                    _ActionBtn(
                      icon: Icons.send_outlined,
                      color: AppColors.text,
                      onTap: () =>
                          _openShareSheet(context, widget.event.id, () {
                            setState(() {});
                            widget.onUpdate();
                          }, isEvent: true),
                    ),
                    const Spacer(),
                    _ActionBtn(
                      icon: userState.isSaved(widget.event.id)
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      color: userState.isSaved(widget.event.id)
                          ? AppColors.primaryRed
                          : AppColors.text,
                      onTap: () {
                        setState(() => userState.toggleSave(widget.event.id));
                        userPrefsService.save(
                          authService.isStudentSession
                              ? authService.currentUser?.id ?? ''
                              : '',
                        );
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
                  likes: 0,
                  shares: shareCount,
                  score: widget.score,
                  views: viewTracker.viewCount(widget.event.id),
                  onViewTap: () => showModalBottomSheet<void>(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (_) => _ViewersSheet(
                      contentId: widget.event.id,
                      title: 'Event Viewers',
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 6),

            // ── Description ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${club.name}  ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                        fontSize: 13,
                      ),
                    ),
                    TextSpan(
                      text: widget.event.description,
                      style: TextStyle(color: AppColors.text, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  String _monthAbbr(int m) => [
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
  ][m - 1];

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
  final int shares;
  final int views;
  final double score;
  final VoidCallback? onViewTap;
  final VoidCallback? onLikeTap;

  const _EngagementBar({
    required this.likes,
    required this.shares,
    required this.score,
    this.views = 0,
    this.onViewTap,
    this.onLikeTap,
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
                Icon(
                  Icons.remove_red_eye_outlined,
                  size: 13,
                  color: AppColors.secondaryText,
                ),
                const SizedBox(width: 3),
                Text(
                  '$views view${views == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (likes > 0) ...[
          if (views > 0) const SizedBox(width: 10),
          GestureDetector(
            onTap: onLikeTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite, size: 13, color: Colors.pink),
                const SizedBox(width: 3),
                Text(
                  '$likes likes',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                    decoration: onLikeTap == null
                        ? TextDecoration.none
                        : TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (shares > 0) ...[
          const SizedBox(width: 10),
          Icon(Icons.send, size: 13, color: Color(0xFF2E7D32)),
          const SizedBox(width: 3),
          Text(
            '$shares share${shares == 1 ? '' : 's'}',
            style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
          ),
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

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

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
  final String contentPrefix; // 'kupost' or 'kuevent'
  final String userId;
  final VoidCallback onShared;

  const _ShareSheet({
    required this.targetId,
    required this.contentPrefix,
    required this.userId,
    required this.onShared,
  });

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final Set<String> _selected = {};
  bool _sending = false;
  final _searchCtrl = TextEditingController();
  String _query = '';

  String get _myId =>
      authService.isStudentSession ? authService.currentUser?.id ?? '' : '';

  String get _contentPayload => '${widget.contentPrefix}:${widget.targetId}';

  List<User> get _friends => users
      .where((u) => userState.isFollowingUser(u.id) && u.id != _myId)
      .toList();

  List<User> get _filtered {
    if (_query.isEmpty) return _friends;
    final q = _query.toLowerCase();
    return _friends.where((u) => u.name.toLowerCase().contains(q)).toList();
  }

  void _toggleSelect(String uid) => setState(
    () => _selected.contains(uid) ? _selected.remove(uid) : _selected.add(uid),
  );

  void _recordShare() {
    final alreadyShared = shares.any(
      (s) => s.targetId == widget.targetId && s.userId == widget.userId,
    );
    if (!alreadyShared) {
      shares.add(
        Share(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          targetId: widget.targetId,
          userId: widget.userId,
          createdAt: DateTime.now(),
        ),
      );
      contentStore.saveShares();
      widget.onShared();
    }
  }

  Future<void> _sendSeparately() async {
    if (_selected.isEmpty || _sending) return;
    setState(() => _sending = true);
    _recordShare();
    final ts = DateTime.now().millisecondsSinceEpoch;
    for (final uid in _selected) {
      await messageService.saveMessage(
        Message(
          id: 'share_${ts}_$uid',
          senderId: _myId,
          receiverId: uid,
          content: _contentPayload,
          sentAt: DateTime.now(),
        ),
      );
    }
    if (mounted) {
      setState(() => _sending = false);
      Navigator.pop(context);
    }
  }

  void _createGroup() {
    if (_selected.length < 2 || _sending) return;
    _recordShare();
    final group = groupChatService.createGroup(
      creatorId: _myId,
      memberIds: _selected.toList(),
      initialContent: _contentPayload,
    );
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GroupChatScreen(group: group)),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final hasSelection = _selected.isNotEmpty;
    final canGroup = _selected.length >= 2;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      snap: true,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.lightGray,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Send to…',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Select people, then choose how to send',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.lightGray),

            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                    child: Text(
                      'SELECT PEOPLE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondaryText,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),

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
                        decoration: InputDecoration(
                          hintText: 'Search friends…',
                          hintStyle: TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            size: 18,
                            color: AppColors.secondaryText,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),

                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: Text(
                          'Follow people to send them content',
                          style: TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  else
                    ...filtered.map((u) {
                      final selected = _selected.contains(u.id);
                      return InkWell(
                        onTap: () => _toggleSelect(u.id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              UserAvatar(userId: u.id, name: u.name, size: 42),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userState.displayNameFor(u.id, u.name),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.text,
                                      ),
                                    ),
                                    Text(
                                      u.email,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: selected
                                      ? AppColors.primaryRed
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.primaryRed
                                        : AppColors.divider,
                                    width: 2,
                                  ),
                                ),
                                child: selected
                                    ? const Icon(
                                        Icons.check_rounded,
                                        size: 15,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 100),
                ],
              ),
            ),

            Container(
              color: AppColors.card,
              padding: EdgeInsets.fromLTRB(
                16,
                10,
                16,
                MediaQuery.of(context).padding.bottom + 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasSelection)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${_selected.length} ${_selected.length == 1 ? "person" : "people"} selected',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.secondaryText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: hasSelection ? _sendSeparately : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            height: 48,
                            decoration: BoxDecoration(
                              color: hasSelection
                                  ? AppColors.primaryRed
                                  : AppColors.lightGray,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.center,
                            child: _sending
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.send_rounded,
                                        size: 16,
                                        color: hasSelection
                                            ? Colors.white
                                            : AppColors.secondaryText,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Send Separately',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: hasSelection
                                              ? Colors.white
                                              : AppColors.secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      if (canGroup) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: _createGroup,
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.primaryRed),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.group_rounded,
                                    size: 16,
                                    color: AppColors.primaryRed,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Create Group',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryRed,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Event Rail Card ──────────────────────────────────────────────────────────

class _EventRailCard extends StatefulWidget {
  final Event event;
  const _EventRailCard({required this.event});

  @override
  State<_EventRailCard> createState() => _EventRailCardState();
}

class _EventRailCardState extends State<_EventRailCard> {
  static const _colors = [
    Color(0xFFB41C18),
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFF6A1B9A),
    Color(0xFFE65100),
    Color(0xFF00838F),
    Color(0xFF512DA8),
    Color(0xFFAD1457),
  ];

  @override
  Widget build(BuildContext context) {
    final ev = widget.event;
    final club = clubs.firstWhere(
      (c) => c.id == ev.clubId,
      orElse: () => clubs.first,
    );
    final idx = clubs.indexOf(club);
    final color = _colors[idx < 0 ? 0 : idx % _colors.length];
    final now = DateTime.now();
    final isLive = ev.dateTime.isBefore(now) && ev.endTime.isAfter(now);
    final daysAway = ev.dateTime.difference(now).inDays;
    final String dayLabel;
    if (isLive) {
      dayLabel = 'LIVE';
    } else if (daysAway == 0) {
      dayLabel = S.today;
    } else if (daysAway == 1) {
      dayLabel = S.tomorrow;
    } else {
      const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      dayLabel = wd[ev.dateTime.weekday - 1];
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventDetailScreen(event: ev, color: color),
        ),
      ),
      child: Container(
        width: 188,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Club monogram + live/day badge
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      club.name.replaceFirst(RegExp(r'^KU\s+'), '').isNotEmpty
                          ? club.name.replaceFirst(RegExp(r'^KU\s+'), '')[0]
                          : club.name[0],
                      style: TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                if (isLive)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PulsingDot(color: AppColors.primaryRed),
                      const SizedBox(width: 4),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryRed,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    dayLabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.secondaryText,
                      letterSpacing: 0.3,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Event title
            Expanded(
              child: Text(
                ev.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                  letterSpacing: -0.3,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Location
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 12,
                  color: AppColors.secondaryText,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    ev.location,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.secondaryText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            // Time
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 12,
                  color: AppColors.secondaryText,
                ),
                const SizedBox(width: 4),
                Text(
                  isLive
                      ? 'Now · ${_fmt(ev.dateTime)}'
                      : '$dayLabel · ${_fmt(ev.dateTime)}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primaryRed,
                borderRadius: BorderRadius.circular(100),
              ),
              alignment: Alignment.center,
              child: const Text(
                'View details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.hour < 12 ? 'AM' : 'PM'}';
  }
}

// ─── Pulsing dot (live indicator) ─────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.45,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
