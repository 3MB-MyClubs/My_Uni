import 'package:flutter/material.dart';
import '../models/club.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/mock_data.dart';
import '../services/user_state.dart';
import '../services/club_follow_helper.dart';
import 'post_detail_screen.dart';
import 'user_profile_screen.dart';
import 'create_post_screen.dart' show buildPostBanner;

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

  // Posts that tag this club via @ClubName
  List get _taggedPosts => newsPosts
      .where((p) =>
          p.clubId != widget.club.id &&
          p.taggedClubIds.contains(widget.club.id))
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // Events co-hosted: events from other clubs that explicitly tag this club
  // (taggedClubIds on events not modelled, so we use posts for now)
  // Partner clubs = clubs whose posts tag this club OR this club's posts tag them
  List<Club> get _partnerClubs {
    final ids = <String>{};
    for (final p in newsPosts) {
      if (p.clubId == widget.club.id) {
        ids.addAll(p.taggedClubIds);
      } else if (p.taggedClubIds.contains(widget.club.id)) {
        ids.add(p.clubId);
      }
    }
    return clubs.where((c) => ids.contains(c.id)).toList();
  }

  /// True when the currently logged-in admin is the admin of THIS club.
  bool get _isThisClubAdmin {
    final admin = authService.currentAdmin;
    if (admin == null) return false;
    return widget.club.adminUserIds.contains(admin.id);
  }

  void _openBoardManagement() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BoardManagementSheet(club: widget.club),
    ).then((_) => setState(() {}));
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
            actions: [
              if (_isThisClubAdmin)
                IconButton(
                  icon: const Icon(Icons.manage_accounts_outlined),
                  tooltip: 'Manage Board',
                  onPressed: _openBoardManagement,
                ),
            ],
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
                        onTap: () => handleFollowTap(context, widget.club.id, () => setState(() {})),
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
              taggedPosts: _taggedPosts,
              partnerClubs: _partnerClubs,
              thisClub: widget.club,
              clubColor: widget.color,
              timeAgo: _timeAgo,
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

              // ── Image banner ──
              buildPostBanner(
                imagePath: post.imagePath as String?,
                fallbackColor: clubColor,
                fallbackLetter: clubColor.toString()[0],
                height: 180,
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
  final List taggedPosts;
  final List<Club> partnerClubs;
  final Club thisClub;
  final Color clubColor;
  final String Function(DateTime) timeAgo;

  const _CollaborationsTab({
    required this.taggedPosts,
    required this.partnerClubs,
    required this.thisClub,
    required this.clubColor,
    required this.timeAgo,
  });

  static const List<Color> _colors = [
    Color(0xFF8C1D40), Color(0xFF1565C0), Color(0xFF2E7D32),
    Color(0xFF6A1B9A), Color(0xFFE65100), Color(0xFF00838F),
  ];

  @override
  Widget build(BuildContext context) {
    final isEmpty = taggedPosts.isEmpty && partnerClubs.isEmpty;

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      children: [
        if (isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: Text(
                'No collaborations yet.\nPosts that tag this club with @ will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.secondaryText, height: 1.6),
              ),
            ),
          ),

        // ── Partner clubs banner row ──
        if (partnerClubs.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text('Partner Clubs',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.text)),
          ),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: partnerClubs.length,
              itemBuilder: (ctx, i) {
                final club = partnerClubs[i];
                final color = _colors[clubs.indexOf(club) % _colors.length];
                return GestureDetector(
                  onTap: () => Navigator.push(ctx,
                      MaterialPageRoute(builder: (_) => ClubProfileScreen(club: club, color: color))),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: color.withValues(alpha: 0.3)),
                          ),
                          child: Center(
                            child: Text(club.name[0],
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 64,
                          child: Text(club.name.split(' ').first,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 24),
        ],

        // ── Tagged posts ──
        if (taggedPosts.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Posts featuring this club',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.text)),
          ),
          ...taggedPosts.map((post) {
            final authorClub = clubs.firstWhere((c) => c.id == post.clubId, orElse: () => clubs.first);
            final color = _colors[clubs.indexOf(authorClub) % _colors.length];
            final commentCount = comments.where((c) => c.postId == post.id).length;
            final likeCount = postLikeCount(post.id as String);

            return GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => PostDetailScreen(post: post, clubColor: color))),
              child: Container(
                color: AppColors.card,
                margin: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                      child: Row(
                        children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(authorClub.name[0],
                                  style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(authorClub.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.text),
                                    overflow: TextOverflow.ellipsis),
                                Text(timeAgo(post.createdAt as DateTime),
                                    style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                              ],
                            ),
                          ),
                          // Collab badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: clubColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.handshake_outlined, size: 12, color: clubColor),
                                const SizedBox(width: 4),
                                Text('Collab', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: clubColor)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Banner
                    buildPostBanner(
                      imagePath: post.imagePath as String?,
                      fallbackColor: color,
                      fallbackLetter: authorClub.name[0],
                      height: 140,
                    ),
                    // Stats
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.favorite, size: 14, color: Colors.pink),
                          const SizedBox(width: 4),
                          Text('$likeCount', style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
                          const SizedBox(width: 12),
                          const Icon(Icons.chat_bubble_outline, size: 14, color: AppColors.secondaryText),
                          const SizedBox(width: 4),
                          Text('$commentCount', style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
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

// ─── Board Management Sheet ───────────────────────────────────────────────────

class _BoardManagementSheet extends StatefulWidget {
  final Club club;
  const _BoardManagementSheet({required this.club});

  @override
  State<_BoardManagementSheet> createState() => _BoardManagementSheetState();
}

class _BoardManagementSheetState extends State<_BoardManagementSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  List get _matchedUsers {
    if (_query.trim().isEmpty) return [];
    final q = _query.trim().toLowerCase();
    return users
        .where((u) =>
            u.name.toLowerCase().contains(q) &&
            !widget.club.boardMemberIds.contains(u.id))
        .toList();
  }

  List get _currentBoardMembers => users
      .where((u) => widget.club.boardMemberIds.contains(u.id))
      .toList();

  void _addMember(String userId) {
    setState(() {
      if (!widget.club.boardMemberIds.contains(userId)) {
        widget.club.boardMemberIds.add(userId);
      }
      _searchController.clear();
      _query = '';
    });
  }

  void _removeMember(String userId) {
    setState(() => widget.club.boardMemberIds.remove(userId));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final boardMembers = _currentBoardMembers;
    final matches = _matchedUsers;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle + title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.manage_accounts_outlined,
                          color: AppColors.primaryRed, size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        'Manage Board Members',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Board members are restricted to this club only.',
                    style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                  ),
                  const SizedBox(height: 14),
                  // Search field
                  TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                    style: const TextStyle(fontSize: 14, color: AppColors.text),
                    decoration: InputDecoration(
                      hintText: 'Search users by name...',
                      hintStyle: const TextStyle(color: AppColors.secondaryText, fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: AppColors.secondaryText, size: 20),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),

            const Divider(height: 1),

            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // Search results
                  if (matches.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text('Add to Board',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.secondaryText,
                              letterSpacing: 0.4)),
                    ),
                    ...matches.map((u) => ListTile(
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.lightRed,
                            child: Text(
                              u.name[0].toUpperCase(),
                              style: const TextStyle(
                                  color: AppColors.primaryRed,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(u.name,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text)),
                          subtitle: Text(u.email,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.secondaryText)),
                          trailing: TextButton(
                            onPressed: () => _addMember(u.id),
                            style: TextButton.styleFrom(
                              backgroundColor: AppColors.lightRed,
                              foregroundColor: AppColors.primaryRed,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Add',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        )),
                    const Divider(height: 16),
                  ],

                  // Current board members
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: Text(
                      boardMembers.isEmpty
                          ? 'No board members yet'
                          : 'Current Board Members (${boardMembers.length})',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondaryText,
                          letterSpacing: 0.4),
                    ),
                  ),
                  if (boardMembers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: Text(
                        'Search for a user above to add them to the board.',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.secondaryText),
                      ),
                    )
                  else
                    ...boardMembers.map((u) => ListTile(
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFF1565C0).withValues(alpha: 0.12),
                            child: Text(
                              u.name[0].toUpperCase(),
                              style: const TextStyle(
                                  color: Color(0xFF1565C0),
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(u.name,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text)),
                          subtitle: Text(u.email,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.secondaryText)),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                color: AppColors.secondaryText, size: 22),
                            tooltip: 'Remove from board',
                            onPressed: () => _removeMember(u.id),
                          ),
                        )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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
