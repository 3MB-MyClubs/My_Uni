import 'package:flutter/material.dart';
import '../models/club.dart';
import '../services/app_colors.dart';
import '../services/mock_data.dart';
import '../services/user_state.dart';
import 'post_detail_screen.dart';
import 'user_profile_screen.dart';

class ClubProfileScreen extends StatefulWidget {
  final Club club;
  final Color color;

  const ClubProfileScreen({super.key, required this.club, required this.color});

  @override
  State<ClubProfileScreen> createState() => _ClubProfileScreenState();
}

class _ClubProfileScreenState extends State<ClubProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Posts by this club
  List get _clubPosts => newsPosts
      .where((p) => p.clubId == widget.club.id)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // Events by this club
  List get _clubEvents => events
      .where((e) => e.clubId == widget.club.id)
      .toList()
    ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

  // Members: all users who have subscribed to this club
  List get _members => users
      .where((u) => u.subscribedClubIds.contains(widget.club.id))
      .toList();

  // Collaborations: other clubs that share at least one member with this club
  List<Club> get _collaboratingClubs {
    final memberIds = users
        .where((u) => u.subscribedClubIds.contains(widget.club.id))
        .map((u) => u.id)
        .toSet();

    final sharedClubIds = <String>{};
    for (final u in users) {
      if (memberIds.contains(u.id)) {
        for (final cid in u.subscribedClubIds) {
          if (cid != widget.club.id) sharedClubIds.add(cid);
        }
      }
    }
    return clubs.where((c) => sharedClubIds.contains(c.id)).toList();
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _monthAbbr(int m) {
    const months = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
    return months[m - 1];
  }

  @override
  Widget build(BuildContext context) {
    final isFollowing = userState.isFollowing(widget.club.id);
    final memberCount = clubMemberCount(widget.club.id);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          // ── Collapsing app bar ──
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.card,
            surfaceTintColor: Colors.transparent,
            foregroundColor: AppColors.text,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.color,
                      widget.color.withValues(alpha: 0.5),
                      AppColors.background,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: widget.color.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: widget.color.withValues(alpha: 0.4), width: 2),
                        ),
                        child: Center(
                          child: Text(
                            widget.club.name[0],
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: widget.color,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              title: Text(
                widget.club.name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.text),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              titlePadding: const EdgeInsets.only(left: 56, bottom: 14, right: 16),
            ),
          ),

          // ── Stats + follow + description ──
          SliverToBoxAdapter(
            child: Container(
              color: AppColors.card,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats row
                  Row(
                    children: [
                      _StatCell(value: '${_clubPosts.length}', label: 'Posts'),
                      const SizedBox(width: 28),
                      _StatCell(value: '$memberCount', label: 'Members'),
                      const SizedBox(width: 28),
                      _StatCell(value: '${_clubEvents.length}', label: 'Events'),
                      const Spacer(),
                      // Follow button
                      GestureDetector(
                        onTap: () => setState(() => userState.toggleFollow(widget.club.id)),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: isFollowing ? Colors.transparent : AppColors.primaryRed,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isFollowing
                                  ? AppColors.secondaryText.withValues(alpha: 0.5)
                                  : AppColors.primaryRed,
                            ),
                          ),
                          child: Text(
                            isFollowing ? 'Following' : 'Follow',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: isFollowing ? AppColors.secondaryText : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Description
                  Text(
                    widget.club.description,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.secondaryText, height: 1.5),
                  ),
                ],
              ),
            ),
          ),

          // ── Tab bar ──
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyTabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primaryRed,
                unselectedLabelColor: AppColors.secondaryText,
                indicatorColor: AppColors.primaryRed,
                tabs: const [
                  Tab(text: 'Posts'),
                  Tab(text: 'Events'),
                  Tab(text: 'Collaborations'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _PostsTab(posts: _clubPosts, timeAgo: _timeAgo, clubColor: widget.color),
            _EventsTab(events: _clubEvents, monthAbbr: _monthAbbr),
            _CollaborationsTab(
              collaboratingClubs: _collaboratingClubs,
              members: _members,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Posts Tab ────────────────────────────────────────────────────────────────

class _PostsTab extends StatelessWidget {
  final List posts;
  final String Function(DateTime) timeAgo;
  final Color clubColor;

  const _PostsTab({required this.posts, required this.timeAgo, required this.clubColor});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const Center(
        child: Text('No posts yet.', style: TextStyle(color: AppColors.secondaryText)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: posts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final post = posts[i];
        final author = users.firstWhere((u) => u.id == post.authorId,
            orElse: () => users.first);
        final likeCount = postLikeCount(post.id as String);
        final commentCount = comments.where((c) => c.postId == post.id).length;

        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => PostDetailScreen(post: post, clubColor: clubColor),
          )),
          child: Container(
          color: AppColors.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Author header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Row(
                  children: [
                    // Avatar
                    GestureDetector(
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => UserProfileScreen(user: author))),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: clubColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            author.name[0].toUpperCase(),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: clubColor,
                                fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Name + time
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => UserProfileScreen(user: author))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(author.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.primaryRed)),
                            Text(timeAgo(post.createdAt as DateTime),
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.secondaryText)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Gradient image banner ──
              Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: 180,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          clubColor.withValues(alpha: 0.85),
                          clubColor.withValues(alpha: 0.3),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        (post.title as String)[0], // decorative letter
                        style: TextStyle(
                          fontSize: 80,
                          fontWeight: FontWeight.w900,
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                  ),
                  // Post title overlaid on banner
                  Positioned(
                    bottom: 12,
                    left: 14,
                    right: 14,
                    child: Text(
                      post.title as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
                      ),
                    ),
                  ),
                ],
              ),

              // ── Engagement row ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.favorite, size: 16, color: Colors.pink),
                    const SizedBox(width: 4),
                    Text('$likeCount',
                        style: const TextStyle(fontSize: 13, color: AppColors.secondaryText)),
                    const SizedBox(width: 14),
                    const Icon(Icons.chat_bubble_outline,
                        size: 16, color: AppColors.secondaryText),
                    const SizedBox(width: 4),
                    Text('$commentCount',
                        style: const TextStyle(fontSize: 13, color: AppColors.secondaryText)),
                  ],
                ),
              ),

              // ── Caption ──
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: RichText(
                  text: TextSpan(children: [
                    TextSpan(
                      text: '${author.name}  ',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                          fontSize: 13),
                    ),
                    TextSpan(
                      text: post.content as String,
                      style: const TextStyle(color: AppColors.secondaryText, fontSize: 13),
                    ),
                  ]),
                ),
              ),
            ],
          ),
          ),
        );
      },
    );
  }
}

// ─── Events Tab ───────────────────────────────────────────────────────────────

class _EventsTab extends StatelessWidget {
  final List events;
  final String Function(int) monthAbbr;

  const _EventsTab({required this.events, required this.monthAbbr});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Center(
        child: Text('No events yet.', style: TextStyle(color: AppColors.secondaryText)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      itemCount: events.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final event = events[i];
        final dt = event.dateTime as DateTime;
        final diff = dt.difference(DateTime.now());
        final daysLabel = diff.isNegative
            ? 'Passed'
            : diff.inDays == 0
                ? 'Today'
                : diff.inDays == 1
                    ? 'Tomorrow'
                    : 'In ${diff.inDays} days';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.lightRed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${dt.day}',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryRed,
                            height: 1)),
                    Text(monthAbbr(dt.month),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.primaryRed)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title as String,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.text),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(event.description as String,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.secondaryText),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 12, color: AppColors.primaryRed),
                        const SizedBox(width: 3),
                        Text(daysLabel,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.primaryRed,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(width: 10),
                        const Icon(Icons.people_outline,
                            size: 12, color: AppColors.secondaryText),
                        const SizedBox(width: 3),
                        Text('${(event.attendeeUserIds as List).length} attending',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.secondaryText)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Collaborations Tab ───────────────────────────────────────────────────────

class _CollaborationsTab extends StatelessWidget {
  final List<Club> collaboratingClubs;
  final List members;

  const _CollaborationsTab(
      {required this.collaboratingClubs, required this.members});

  static const List<Color> _colors = [
    Color(0xFF8C1D40), Color(0xFF1565C0), Color(0xFF2E7D32),
    Color(0xFF6A1B9A), Color(0xFFE65100), Color(0xFF00838F),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      children: [
        // ── Shared members section ──
        if (members.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text('Members',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text)),
          ),
          ...members.map((user) {
            final idx = users.indexOf(user);
            final color = _colors[idx % _colors.length];
            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => UserProfileScreen(user: user))),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.15),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Center(
                    child: Text(user.name[0].toUpperCase(),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: color,
                            fontSize: 16)),
                  ),
                ),
              ),
              title: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => UserProfileScreen(user: user))),
                child: Text(user.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
              ),
              subtitle: Text(user.email,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.secondaryText)),
            );
          }),
          const Divider(height: 24),
        ],

        // ── Clubs with shared members ──
        if (collaboratingClubs.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Also Active In',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text)),
          ),
          ...collaboratingClubs.map((club) {
            final idx = clubs.indexOf(club);
            final color = _colors[idx % _colors.length];
            // Count shared members
            final sharedCount = members
                .where((u) => u.subscribedClubIds.contains(club.id))
                .length;
            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) =>
                            ClubProfileScreen(club: club, color: color))),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(club.name[0],
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: color,
                            fontSize: 18)),
                  ),
                ),
              ),
              title: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) =>
                            ClubProfileScreen(club: club, color: color))),
                child: Text(club.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              subtitle: Text(
                '$sharedCount shared member${sharedCount == 1 ? '' : 's'}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.secondaryText),
              ),
              trailing: const Icon(Icons.chevron_right,
                  color: AppColors.secondaryText, size: 20),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) =>
                          ClubProfileScreen(club: club, color: color))),
            );
          }),
        ],

        if (collaboratingClubs.isEmpty && members.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text('No collaboration data yet.',
                  style: TextStyle(color: AppColors.secondaryText)),
            ),
          ),
      ],
    );
  }
}

// ─── Sticky tab bar delegate ──────────────────────────────────────────────────

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _StickyTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: AppColors.card, child: tabBar);
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate old) => false;
}

// ─── Stat cell ────────────────────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  const _StatCell({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
      ],
    );
  }
}
