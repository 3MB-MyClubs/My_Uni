import 'package:flutter/material.dart';
import '../models/club.dart';
import '../models/event.dart';
import '../models/news_post.dart';
import '../models/user.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/club_admin_access.dart';
import '../services/mock_data.dart';
import '../services/people_service.dart';
import '../services/user_state.dart';
import '../services/user_prefs_service.dart';
import '../services/content_store.dart';
import '../services/event_access.dart';
import '../services/supabase_event_service.dart';
import '../services/supabase_post_service.dart';
import '../widgets/club_avatar.dart';
import '../widgets/club_follow_button.dart';
import 'event_detail_screen.dart';
import 'post_detail_screen.dart';
import 'user_profile_screen.dart';
import 'create_post_screen.dart' show buildPostBanner;
import '../widgets/user_avatar.dart';

bool _isDarkClubTheme(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color _clubPagePanel(BuildContext context) =>
    _isDarkClubTheme(context) ? const Color(0xFF160008) : AppColors.surfaceAlt;

Color _clubPageCard(BuildContext context) =>
    _isDarkClubTheme(context) ? const Color(0x0EFFFFFF) : AppColors.card;

Color _clubPageBorder(BuildContext context) =>
    _isDarkClubTheme(context) ? const Color(0x14FFFFFF) : AppColors.divider;

Color _clubPageStrongBorder(BuildContext context) => _isDarkClubTheme(context)
    ? const Color(0x2EFFFFFF)
    : AppColors.divider.withValues(alpha: 0.95);

Color _clubPageBodyText(BuildContext context) => _isDarkClubTheme(context)
    ? const Color(0xD1FFFFFF)
    : AppColors.text.withValues(alpha: 0.82);

class ClubProfileScreen extends StatefulWidget {
  final Club club;
  final Color color;
  // When provided, the nav bar shows a settings gear instead of the back
  // button — used when this screen IS the logged-in club's Profile tab root.
  final VoidCallback? onSettings;

  const ClubProfileScreen({
    super.key,
    required this.club,
    required this.color,
    this.onSettings,
  });

  @override
  State<ClubProfileScreen> createState() => _ClubProfileScreenState();
}

class _ClubProfileScreenState extends State<ClubProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Posts by this club
  List get _clubPosts =>
      newsPosts.where((p) => p.clubId == widget.club.id).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // Events by this club
  List get _clubEvents =>
      events.where((e) => e.clubId == widget.club.id).toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

  // Posts that tag this club via @ClubName
  List get _taggedPosts =>
      newsPosts
          .where(
            (p) =>
                p.clubId != widget.club.id &&
                p.taggedClubIds.contains(widget.club.id),
          )
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
    return clubIsManagedByAdmin(widget.club, admin.id);
  }

  List<User> get _membersForThisClub {
    final byId = <String, User>{
      for (final member in clubMembers(widget.club.id)) member.id: member,
    };
    final currentUser = authService.currentUser;
    if (currentUser != null && userState.isFollowing(widget.club.id)) {
      byId[currentUser.id] = currentUser;
    }
    final members = byId.values.toList();
    members.sort((a, b) {
      final aBoard = widget.club.boardMemberIds.contains(a.id);
      final bBoard = widget.club.boardMemberIds.contains(b.id);
      if (aBoard != bBoard) return aBoard ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return members;
  }

  void _openMembersSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ClubMembersSheet(
        club: widget.club,
        color: widget.color,
        members: _membersForThisClub,
        totalCount: clubMemberCount(widget.club.id),
      ),
    ).then((_) {
      // Roles assigned inside the sheet change the board — rebuild so the
      // BOARD tab and header stats reflect them immediately.
      if (mounted) setState(() {});
    });
  }

  String _handleFor(Club club) {
    final shortName = club.shortName?.trim();
    if (shortName != null && shortName.isNotEmpty) {
      return shortName
          .replaceFirst(RegExp(r'^@+'), '')
          .replaceAll(RegExp(r'\s+'), '')
          .toLowerCase();
    }

    final name = club.name;
    final words = name.split(RegExp(r'[\s\-]+'));
    final initials = words
        .where((w) => w.isNotEmpty && RegExp(r'[A-Za-z]').hasMatch(w[0]))
        .map((w) => w[0])
        .join()
        .toLowerCase();
    return initials.isEmpty
        ? name.toLowerCase().replaceAll(RegExp(r'\s+'), '')
        : initials;
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _monthAbbr(int m) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return months[m - 1];
  }

  List<String> _categoryTagsFor(Club club) {
    final raw = club.categoryName?.trim();
    if (raw == null || raw.isEmpty) return const [];
    return raw
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final memberCount = clubMemberCount(widget.club.id);
    final bg = AppColors.background;
    final borderColor = _clubPageBorder(context);
    final subText = AppColors.secondaryText;
    final panelText = AppColors.text;
    final bodyText = _clubPageBodyText(context);
    final handle = _handleFor(widget.club);
    final showFollowAction = authService.isStudentSession && !_isThisClubAdmin;
    return Scaffold(
      backgroundColor: bg,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          // ── Nav bar ──
          SliverAppBar(
            pinned: true,
            toolbarHeight: 44,
            backgroundColor: bg,
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: Icon(
                      Icons.chevron_left_rounded,
                      color: panelText,
                      size: 28,
                    ),
                    onPressed: () => Navigator.pop(context),
                  )
                : const SizedBox(width: 40),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '@$handle',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: panelText,
                    letterSpacing: -0.3,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      size: 10,
                      color: AppColors.primaryRed,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Official Club',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.primaryRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            centerTitle: true,
            actions: [
              // Owner's Profile tab: a single settings gear. Board management
              // now lives inside Settings.
              if (widget.onSettings != null)
                IconButton(
                  icon: Icon(
                    Icons.settings_outlined,
                    color: panelText,
                    size: 22,
                  ),
                  onPressed: () => widget.onSettings!(),
                ),
            ],
          ),

          // ── Scrollable header ──
          SliverToBoxAdapter(
            child: ListenableBuilder(
              listenable: userState,
              builder: (context, _) {
                final categoryTags = _categoryTagsFor(widget.club);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.topCenter,
                          radius: 1.4,
                          colors: [
                            widget.color.withValues(alpha: 0.10),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.68],
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Avatar + Stats row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 104,
                                height: 104,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28),
                                  gradient: LinearGradient(
                                    begin: const Alignment(-0.8, -0.8),
                                    end: const Alignment(0.8, 0.8),
                                    colors: [
                                      widget.color.withValues(alpha: 0.23),
                                      widget.color.withValues(alpha: 0.44),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: widget.color.withValues(alpha: 0.40),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: widget.color.withValues(
                                        alpha: 0.10,
                                      ),
                                      blurRadius: 0,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(26),
                                  child: ClubAvatar(
                                    clubId: widget.club.id,
                                    clubName: widget.club.name,
                                    color: widget.color,
                                    imageUrl: widget.club.logoUrl,
                                    size: 104,
                                    fontSize: 46,
                                    borderRadius: 28,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 22),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _StatCell(
                                      value: '${_clubPosts.length}',
                                      label: 'Posts',
                                      dark: true,
                                    ),
                                    Container(
                                      width: 1,
                                      height: 28,
                                      color: borderColor,
                                    ),
                                    _StatCell(
                                      value: '$memberCount',
                                      label: 'Members',
                                      dark: true,
                                      onTap: _openMembersSheet,
                                    ),
                                    Container(
                                      width: 1,
                                      height: 28,
                                      color: borderColor,
                                    ),
                                    _StatCell(
                                      value: '${_clubEvents.length}',
                                      label: 'Events',
                                      dark: true,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // Name
                          Text(
                            widget.club.name,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: panelText,
                              letterSpacing: -0.5,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Badges
                          Wrap(
                            spacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.color.withValues(alpha: 0.13),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '@$handle',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: widget.color,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              for (final category in categoryTags)
                                Padding(
                                  padding: const EdgeInsets.only(right: 2),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryRed.withValues(
                                        alpha: 0.18,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      category,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primaryRed,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Bio
                          Text(
                            widget.club.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: bodyText,
                              height: 1.6,
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Students can follow clubs, but clubs do not have
                          // direct messages.
                          if (showFollowAction) ...[
                            SizedBox(
                              height: 48,
                              width: double.infinity,
                              child: ClubFollowButton(
                                clubId: widget.club.id,
                                size: 'large',
                              ),
                            ),
                            const SizedBox(height: 16),
                          ] else
                            const SizedBox(height: 4),
                        ],
                      ),
                    ),

                    // Section divider
                    Container(height: 1, color: borderColor),
                  ],
                );
              },
            ),
          ),

          // ── Sticky tab bar ──
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyTabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primaryRed,
                unselectedLabelColor: subText,
                indicatorColor: AppColors.primaryRed,
                indicatorSize: TabBarIndicatorSize.tab,
                labelPadding: EdgeInsets.zero,
                tabs: [
                  _IconTab(icon: Icons.view_agenda_outlined, label: 'POSTS'),
                  _IconTab(icon: Icons.event_rounded, label: 'EVENTS'),
                  _IconTab(icon: Icons.people_alt_outlined, label: 'COLLABS'),
                  _IconTab(icon: Icons.assignment_outlined, label: 'BOARD'),
                ],
              ),
              backgroundColor: AppColors.card,
              borderColor: borderColor,
              height: 58,
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _PostsTab(
              posts: _clubPosts,
              club: widget.club,
              clubColor: widget.color,
              isAdmin: _isThisClubAdmin,
              onChanged: () {
                if (mounted) setState(() {});
              },
            ),
            _EventsTab(
              events: _clubEvents,
              monthAbbr: _monthAbbr,
              clubColor: widget.color,
              isAdmin: _isThisClubAdmin,
              onChanged: () {
                if (mounted) setState(() {});
              },
            ),
            _CollaborationsTab(
              taggedPosts: _taggedPosts,
              partnerClubs: _partnerClubs,
              thisClub: widget.club,
              clubColor: widget.color,
              timeAgo: _timeAgo,
            ),
            _BoardTab(
              club: widget.club,
              onBoardChanged: () {
                if (!mounted) return;
                // Refresh the header stats but stay on the BOARD tab so editing
                // a member's role doesn't bounce the admin back to Posts.
                setState(() {});
              },
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
  final Club club;
  final Color clubColor;
  final bool isAdmin;
  final VoidCallback onChanged;

  const _PostsTab({
    required this.posts,
    required this.club,
    required this.clubColor,
    required this.isAdmin,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 32),
            child: Column(
              children: [
                Icon(
                  Icons.article_outlined,
                  size: 46,
                  color: AppColors.secondaryText.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 12),
                Text(
                  'No posts yet.',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "When ${club.name} posts, it'll show up here.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Club feed split into NEW THIS WEEK (pinned first, then last 7 days) and
    // EARLIER. Rebuilds on pin / like changes.
    return ListenableBuilder(
      listenable: userState,
      builder: (context, _) {
        final weekAgo = DateTime.now().subtract(const Duration(days: 7));
        final pinned = posts
            .where((p) => userState.isPostPinned(p.id as String))
            .toList();
        final pinnedIds = pinned.map((p) => p.id as String).toSet();
        final fresh = posts
            .where(
              (p) =>
                  !pinnedIds.contains(p.id) &&
                  (p.createdAt as DateTime).isAfter(weekAgo),
            )
            .toList();
        final earlier = posts
            .where(
              (p) =>
                  !pinnedIds.contains(p.id) &&
                  !(p.createdAt as DateTime).isAfter(weekAgo),
            )
            .toList();
        final newThisWeek = [...pinned, ...fresh];

        final children = <Widget>[];
        if (newThisWeek.isNotEmpty) {
          children.add(const _FeedLabel('NEW THIS WEEK'));
          children.addAll(
            newThisWeek.map(
              (p) => _ClubPostCompact(
                post: p,
                club: club,
                clubColor: clubColor,
                isAdmin: isAdmin,
                onChanged: onChanged,
              ),
            ),
          );
        }
        if (earlier.isNotEmpty) {
          children.add(const _FeedLabel('EARLIER'));
          children.addAll(
            earlier.map(
              (p) => _ClubPostCompact(
                post: p,
                club: club,
                clubColor: clubColor,
                isAdmin: isAdmin,
                onChanged: onChanged,
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 90),
          children: children,
        );
      },
    );
  }
}

/// Small letter-spaced section label with a trailing hairline (NEW / EARLIER).
class _FeedLabel extends StatelessWidget {
  final String text;
  const _FeedLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 9),
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(child: Container(height: 1, color: AppColors.divider)),
        ],
      ),
    );
  }
}

// ─── Club post card (compact) ─────────────────────────────────────────────────

/// Compact post row for the club profile — smaller than the home feed. Shows a
/// thumbnail (or accent tile), time, a short snippet and like count; tapping
/// opens the full post. The club's own admin gets a ⋯ menu to pin or delete
/// the post.
class _ClubPostCompact extends StatelessWidget {
  final dynamic post;
  final Club club;
  final Color clubColor;
  final bool isAdmin;
  final VoidCallback onChanged;

  const _ClubPostCompact({
    required this.post,
    required this.club,
    required this.clubColor,
    required this.isAdmin,
    required this.onChanged,
  });

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    }
    return '${(diff.inDays / 7).floor()}w ago';
  }

  void _openDetail(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PostDetailScreen(post: post, clubColor: clubColor),
    ),
  );

  void _togglePin() {
    userState.togglePinnedPost(post.id as String);
    userPrefsService.savePinnedPosts();
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete post?',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text),
        ),
        content: Text(
          'This post will be permanently removed from your club.',
          style: TextStyle(color: AppColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.secondaryText),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final uid = authService.currentAdmin?.id ?? '';
    final typedPost = post is NewsPost ? post as NewsPost : null;
    if (typedPost == null) return;
    try {
      await supabasePostService.deletePost(typedPost);
      contentStore.deletePost(typedPost.id, uid);
      onChanged();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not delete post from Supabase.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final postId = post.id as String;
    final content = (post.content as String).trim();
    final hasImage =
        post.imagePath != null && (post.imagePath as String).isNotEmpty;

    return ListenableBuilder(
      listenable: userState,
      builder: (context, _) {
        final pinned = userState.isPostPinned(postId);
        final likeCount = postLikeCount(postId);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openDetail(context),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border(
                bottom: BorderSide(
                  color: AppColors.divider.withValues(alpha: 0.7),
                  width: 0.6,
                ),
              ),
            ),
            padding: EdgeInsets.fromLTRB(16, 12, isAdmin ? 4 : 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail / accent tile
                ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: hasImage
                        ? buildPostBanner(
                            imagePath: post.imagePath as String?,
                            fallbackColor: clubColor,
                            fallbackLetter: club.name.isNotEmpty
                                ? club.name[0]
                                : '?',
                            height: 52,
                          )
                        : ClubAvatar(
                            clubId: club.id,
                            clubName: club.name,
                            color: clubColor,
                            imageUrl: club.logoUrl,
                            size: 52,
                            fontSize: 22,
                            borderRadius: 11,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (pinned) ...[
                            Icon(
                              Icons.push_pin_rounded,
                              size: 12,
                              color: AppColors.primaryRed,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            _timeAgo(post.createdAt as DateTime),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: pinned
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: pinned
                                  ? AppColors.primaryRed
                                  : AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                      if (content.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: AppColors.text.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.favorite_border_rounded,
                            size: 14,
                            color: AppColors.secondaryText,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$likeCount',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isAdmin)
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      color: AppColors.secondaryText,
                      size: 20,
                    ),
                    color: AppColors.card,
                    onSelected: (v) {
                      if (v == 'pin') _togglePin();
                      if (v == 'delete') _confirmDelete(context);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'pin',
                        child: Row(
                          children: [
                            Icon(
                              pinned
                                  ? Icons.push_pin_outlined
                                  : Icons.push_pin_rounded,
                              size: 19,
                              color: AppColors.text,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              pinned ? 'Unpin from top' : 'Pin to top',
                              style: TextStyle(color: AppColors.text),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              size: 19,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Delete post',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _EventsTab extends StatefulWidget {
  final List events;
  final String Function(int) monthAbbr;
  final Color clubColor;
  final bool isAdmin;
  final VoidCallback onChanged;

  const _EventsTab({
    required this.events,
    required this.monthAbbr,
    required this.clubColor,
    required this.isAdmin,
    required this.onChanged,
  });

  @override
  State<_EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<_EventsTab> {
  // 'past' | 'now' | 'upcoming'  — defaults to upcoming (matches the design).
  String _filter = 'upcoming';

  String _statusOf(dynamic e) {
    final now = DateTime.now();
    final start = e.dateTime as DateTime;
    final end = e.endTime as DateTime;
    if (end.isBefore(now)) return 'past';
    if (!start.isAfter(now)) return 'now'; // started, not yet ended → live
    return 'upcoming';
  }

  List _withStatus(String status) {
    final list = widget.events.where((e) => _statusOf(e) == status).toList();
    if (status == 'past') {
      list.sort(
        (a, b) => (b.dateTime as DateTime).compareTo(a.dateTime as DateTime),
      );
    } else {
      list.sort(
        (a, b) => (a.dateTime as DateTime).compareTo(b.dateTime as DateTime),
      );
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final segments = const [('now', 'Now'), ('upcoming', 'Upcoming')];
    final shown = _withStatus(_filter);
    final panelColor = _clubPagePanel(context);

    return Column(
      children: [
        // Segmented filter (Past / Now / Upcoming) with live counts.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: panelColor,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: segments.map((seg) {
                final active = _filter == seg.$1;
                final n = widget.events
                    .where((e) => _statusOf(e) == seg.$1)
                    .length;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _filter = seg.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.primaryRed
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            seg.$2,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: active
                                  ? Colors.white
                                  : AppColors.secondaryText,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '$n',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: active
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : AppColors.secondaryText.withValues(
                                      alpha: 0.6,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Cards / empty state.
        Expanded(
          child: shown.isEmpty
              ? ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 44,
                        horizontal: 20,
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Nothing here right now.',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _filter == 'now'
                                ? 'No event is live at the moment.'
                                : _filter == 'past'
                                ? 'No past events to show.'
                                : 'Check back soon for new events.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _EventCardV2(
                    event: shown[i],
                    status: _filter,
                    monthAbbr: widget.monthAbbr,
                    clubColor: widget.clubColor,
                    isAdmin: widget.isAdmin,
                    onChanged: widget.onChanged,
                  ),
                ),
        ),
      ],
    );
  }
}

/// Event card with a status pill (HAPPENING NOW · UPCOMING · PAST), date badge,
/// time / location / attendance rows, and a contextual action (Join / RSVP /
/// Recap). Live events get a green accent and a pulsing dot; past events dim.
class _EventCardV2 extends StatelessWidget {
  final dynamic event;
  final String status; // 'past' | 'now' | 'upcoming'
  final String Function(int) monthAbbr;
  final Color clubColor;

  final bool isAdmin;
  final VoidCallback onChanged;

  const _EventCardV2({
    required this.event,
    required this.status,
    required this.monthAbbr,
    required this.clubColor,
    this.isAdmin = false,
    this.onChanged = _noop,
  });

  static void _noop() {}

  static const Color _green = Color(0xFF2E9E5B);

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete event?',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text),
        ),
        content: Text(
          'This event will be permanently removed from your club.',
          style: TextStyle(color: AppColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.secondaryText),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final uid = authService.currentAdmin?.id ?? '';
    final typedEvent = event is Event ? event as Event : null;
    if (typedEvent == null) return;
    try {
      await supabaseEventService.deleteEvent(typedEvent);
      contentStore.deleteEvent(typedEvent.id, uid);
      onChanged();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not delete event from Supabase.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLive = status == 'now';
    final isPast = status == 'past';
    final accent = isLive ? _green : AppColors.primaryRed;
    final cardColor = _clubPageCard(context);
    final borderColor = _clubPageBorder(context);
    final strongBorder = _clubPageStrongBorder(context);
    final panelColor = _clubPagePanel(context);
    final dt = event.dateTime as DateTime;

    final timeLabel = isLive
        ? 'Today · ${_clock(dt)}'
        : isPast
        ? '${monthAbbr(dt.month)} ${dt.day} · ${_clock(dt)}'
        : _clock(dt);
    final countLabel = isPast
        ? 'attended'
        : isLive
        ? 'attending'
        : 'going';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              EventDetailScreen(event: event as dynamic, color: clubColor),
        ),
      ),
      child: Opacity(
        opacity: isPast ? 0.82 : 1,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            border: Border.all(
              color: isLive ? _green.withValues(alpha: 0.4) : borderColor,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date badge
              Container(
                width: 50,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: panelColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      monthAbbr(dt.month),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: isPast ? AppColors.secondaryText : accent,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      '${dt.day}',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status pill
                    _statusPill(),
                    const SizedBox(height: 6),
                    Text(
                      event.title as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.text,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _infoRow(Icons.access_time_rounded, timeLabel),
                    const SizedBox(height: 4),
                    _infoRow(
                      Icons.location_on_outlined,
                      event.location as String,
                    ),
                    if (canViewEventAttendance(event)) ...[
                      const SizedBox(height: 4),
                      _infoRow(
                        Icons.people_outline,
                        '${(event.attendeeUserIds as List).length} $countLabel',
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Action (+ admin delete menu on the club's own profile)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isAdmin) ...[
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_horiz_rounded,
                        color: AppColors.secondaryText,
                        size: 20,
                      ),
                      color: AppColors.card,
                      padding: EdgeInsets.zero,
                      onSelected: (v) {
                        if (v == 'delete') _confirmDelete(context);
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 19,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Delete event',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: isPast ? Colors.transparent : accent,
                      border: isPast ? Border.all(color: strongBorder) : null,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      authService.isStudentSession
                          ? (isLive
                                ? 'Join'
                                : isPast
                                ? 'Recap'
                                : 'RSVP')
                          : (isPast ? 'Recap' : 'View'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isPast ? AppColors.text : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusPill() {
    if (status == 'now') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: _green.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _LiveDot(color: _green),
            const SizedBox(width: 5),
            Text(
              'HAPPENING NOW',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: _green,
              ),
            ),
          ],
        ),
      );
    }
    final isPast = status == 'past';
    final c = isPast ? AppColors.secondaryText : AppColors.primaryRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isPast ? 'PAST' : 'UPCOMING',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: c,
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 11, color: AppColors.secondaryText),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
          ),
        ),
      ],
    );
  }

  String _clock(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// A small pulsing dot for the HAPPENING NOW status pill.
class _LiveDot extends StatefulWidget {
  final Color color;
  const _LiveDot({required this.color});

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.35).animate(_c),
      child: ScaleTransition(
        scale: Tween(begin: 1.0, end: 0.78).animate(_c),
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),
      ),
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
    Color(0xFF8C1D40),
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFF6A1B9A),
    Color(0xFFE65100),
    Color(0xFF00838F),
  ];

  @override
  Widget build(BuildContext context) {
    final cardColor = _clubPageCard(context);
    final borderColor = _clubPageBorder(context);
    final strongBorderColor = _clubPageStrongBorder(context);
    final isEmpty = taggedPosts.isEmpty && partnerClubs.isEmpty;

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      children: [
        if (isEmpty)
          Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: Text(
                'No collaborations yet.\nPosts that tag this club with @ will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.secondaryText, height: 1.6),
              ),
            ),
          ),

        // ── Partner clubs ──
        if (partnerClubs.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'PARTNER CLUBS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: AppColors.secondaryText,
              ),
            ),
          ),
          ...partnerClubs.map((club) {
            final color = _colors[clubs.indexOf(club) % _colors.length];
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClubProfileScreen(club: club, color: color),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: cardColor,
                    border: Border.all(color: borderColor),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      ClubAvatar(
                        clubId: club.id,
                        clubName: club.name,
                        color: color,
                        imageUrl: club.logoUrl,
                        size: 48,
                        fontSize: 20,
                        borderRadius: 14,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              club.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${clubMemberCount(club.id)} members',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: strongBorderColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'View ›',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
        ],

        // ── Tagged posts ──
        if (taggedPosts.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'POSTS FEATURING THIS CLUB',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: AppColors.secondaryText,
              ),
            ),
          ),
          ...taggedPosts.map((post) {
            final authorClub = clubs.firstWhere(
              (c) => c.id == post.clubId,
              orElse: () => clubs.first,
            );
            final color = _colors[clubs.indexOf(authorClub) % _colors.length];
            final likeCount = postLikeCount(post.id as String);
            final hasImage =
                post.imagePath != null && (post.imagePath as String).isNotEmpty;

            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      PostDetailScreen(post: post, clubColor: color),
                ),
              ),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                decoration: BoxDecoration(
                  color: cardColor,
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.hardEdge,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                      child: Row(
                        children: [
                          ClubAvatar(
                            clubId: authorClub.id,
                            clubName: authorClub.name,
                            color: color,
                            imageUrl: authorClub.logoUrl,
                            size: 36,
                            fontSize: 15,
                            borderRadius: 10,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  authorClub.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppColors.text,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  timeAgo(post.createdAt as DateTime),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Collab badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: clubColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.handshake_outlined,
                                  size: 12,
                                  color: clubColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Collab',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: clubColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Banner / club avatar fallback
                    if (hasImage)
                      buildPostBanner(
                        imagePath: post.imagePath as String?,
                        fallbackColor: color,
                        fallbackLetter: authorClub.name[0],
                        height: 140,
                      )
                    else
                      Container(
                        height: 140,
                        width: double.infinity,
                        color: color.withValues(alpha: 0.08),
                        alignment: Alignment.center,
                        child: ClubAvatar(
                          clubId: authorClub.id,
                          clubName: authorClub.name,
                          color: color,
                          imageUrl: authorClub.logoUrl,
                          size: 72,
                          fontSize: 30,
                          borderRadius: 20,
                        ),
                      ),
                    // Stats
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.favorite, size: 14, color: Colors.pink),
                          const SizedBox(width: 4),
                          Text(
                            '$likeCount',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.secondaryText,
                            ),
                          ),
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
  final Color backgroundColor;
  final Color borderColor;
  final double height;
  const _StickyTabBarDelegate(
    this.tabBar, {
    required this.backgroundColor,
    required this.borderColor,
    this.height = 0,
  });

  double get _h => height > 0 ? height : tabBar.preferredSize.height;

  @override
  double get minExtent => _h;
  @override
  double get maxExtent => _h;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          top: BorderSide(color: borderColor, width: 0.6),
          bottom: BorderSide(color: borderColor, width: 0.6),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          height: _h,
          child: Center(child: tabBar),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate old) =>
      old.tabBar != tabBar ||
      old.backgroundColor != backgroundColor ||
      old.borderColor != borderColor ||
      old.height != height;
}

// ─── Board Management Sheet ───────────────────────────────────────────────────

class BoardManagementSheet extends StatefulWidget {
  final Club club;
  const BoardManagementSheet({super.key, required this.club});

  @override
  State<BoardManagementSheet> createState() => BoardManagementSheetState();
}

class BoardManagementSheetState extends State<BoardManagementSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  List get _matchedUsers {
    if (_query.trim().isEmpty) return [];
    final q = _query.trim().toLowerCase();
    return users
        .where(
          (u) =>
              u.name.toLowerCase().contains(q) &&
              !widget.club.boardMemberIds.contains(u.id),
        )
        .toList();
  }

  List get _currentBoardMembers =>
      users.where((u) => widget.club.boardMemberIds.contains(u.id)).toList();

  Future<void> _addMember(String userId) async {
    if (!widget.club.boardMemberIds.contains(userId)) {
      widget.club.boardMemberIds.add(userId);
    }
    _searchController.clear();
    _query = '';
    await contentStore.saveBoardMemberIds();
    userState.bumpClubInfo();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _editTitleInSheet(dynamic u) async {
    final current = widget.club.boardMemberTitles[u.id] ?? '';
    final result = await showDialog<String>(
      context: context,
      builder: (_) =>
          _BoardTitleDialog(memberName: u.name, initialTitle: current),
    );
    if (result == null || !mounted) return;
    if (result.isEmpty) {
      widget.club.boardMemberTitles.remove(u.id);
    } else {
      widget.club.boardMemberTitles[u.id] = result;
    }
    await contentStore.saveBoardMemberTitles();
    // Refresh any open student profile showing this club role.
    userState.bumpClubInfo();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _removeMember(dynamic u) async {
    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          'Remove Board Member',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to remove ${u.name} from the board?',
          style: TextStyle(color: AppColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.secondaryText),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Remove',
              style: TextStyle(color: AppColors.primaryRed),
            ),
          ),
        ],
      ),
    );
    if (first != true || !mounted) return;

    final second = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          'Confirm Removal',
          style: TextStyle(
            color: AppColors.primaryRed,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will permanently remove ${u.name} from the board of ${widget.club.name}. Continue?',
          style: TextStyle(color: AppColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.secondaryText),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Yes, Remove'),
          ),
        ],
      ),
    );
    if (second != true || !mounted) return;

    widget.club.boardMemberIds.remove(u.id);
    widget.club.boardMemberTitles.remove(u.id);
    await contentStore.saveBoardMemberIds();
    await contentStore.saveBoardMemberTitles();
    userState.bumpClubInfo();
    if (!mounted) return;
    Navigator.of(context).pop(true);
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
        decoration: BoxDecoration(
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
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.manage_accounts_outlined,
                        color: AppColors.primaryRed,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
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
                    'Members added here are added instantly, no confirmation needed.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Search field
                  TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                    style: TextStyle(fontSize: 14, color: AppColors.text),
                    decoration: InputDecoration(
                      hintText: 'Search users by name...',
                      hintStyle: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppColors.secondaryText,
                        size: 20,
                      ),
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

            Divider(height: 1),

            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // Search results
                  if (matches.isNotEmpty) ...[
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(
                        'Add to Board',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondaryText,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    ...matches.map(
                      (u) => ListTile(
                        leading: UserAvatar(
                          userId: u.id,
                          name: u.name,
                          size: 40,
                          fontSize: 16,
                          backgroundColor: AppColors.lightRed,
                          textColor: AppColors.primaryRed,
                        ),
                        title: Text(
                          userState.displayNameFor(u.id, u.name),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        subtitle: Text(
                          u.email,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        trailing: TextButton(
                          onPressed: () => _addMember(u.id),
                          style: TextButton.styleFrom(
                            backgroundColor: AppColors.lightRed,
                            foregroundColor: AppColors.primaryRed,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Add',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    Divider(height: 16),
                  ],

                  // Current board members
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: Text(
                      boardMembers.isEmpty
                          ? 'No board members yet'
                          : 'Current Board Members (${boardMembers.length})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondaryText,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  if (boardMembers.isEmpty)
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: Text(
                        'Search for a user above to add them to the board.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    )
                  else
                    ...boardMembers.map(
                      (u) => ListTile(
                        leading: UserAvatar(
                          userId: u.id,
                          name: u.name,
                          size: 40,
                          fontSize: 16,
                          backgroundColor: const Color(
                            0xFF1565C0,
                          ).withValues(alpha: 0.12),
                          textColor: const Color(0xFF1565C0),
                        ),
                        title: Text(
                          userState.displayNameFor(u.id, u.name),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.club.boardMemberTitles[u.id]?.isNotEmpty ==
                                      true
                                  ? widget.club.boardMemberTitles[u.id]!
                                  : 'No title set',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    widget
                                            .club
                                            .boardMemberTitles[u.id]
                                            ?.isNotEmpty ==
                                        true
                                    ? const Color(0xFF1565C0)
                                    : AppColors.secondaryText,
                                fontWeight:
                                    widget
                                            .club
                                            .boardMemberTitles[u.id]
                                            ?.isNotEmpty ==
                                        true
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            Text(
                              u.email,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.edit_outlined,
                                color: Color(0xFF1565C0),
                                size: 20,
                              ),
                              tooltip: 'Set title',
                              onPressed: () => _editTitleInSheet(u),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.remove_circle_outline,
                                color: AppColors.secondaryText,
                                size: 22,
                              ),
                              tooltip: 'Remove from board',
                              onPressed: () => _removeMember(u),
                            ),
                          ],
                        ),
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
}

// ─── Board Tab ────────────────────────────────────────────────────────────────

class _BoardTab extends StatefulWidget {
  final Club club;
  final VoidCallback onBoardChanged;

  const _BoardTab({required this.club, required this.onBoardChanged});

  @override
  State<_BoardTab> createState() => _BoardTabState();
}

class _BoardTabState extends State<_BoardTab> {
  @override
  void initState() {
    super.initState();
    // Load the club's members into the people cache so board members whose
    // profiles aren't in the static seed data resolve and render immediately —
    // without the user having to open the Members sheet first.
    _ensureMembersLoaded();
  }

  Future<void> _ensureMembersLoaded() async {
    try {
      await peopleService.fetchClubMembers(widget.club.id);
    } catch (_) {
      // Offline / mock mode — board members come from the static user list.
    }
    if (mounted) setState(() {});
  }

  // Only the club's own admin can approve/decline requests, add/remove members,
  // or assign titles. Board members and external users have no write access.
  bool get _isClubAdmin {
    final adminId = authService.currentAdmin?.id ?? '';
    final userId = authService.currentUser?.id ?? '';
    return clubIsManagedByAdmin(widget.club, adminId) ||
        widget.club.adminUserIds.contains(userId);
  }

  Future<void> _editTitle(dynamic u) async {
    final current = widget.club.boardMemberTitles[u.id] ?? '';
    final result = await showDialog<String>(
      context: context,
      builder: (_) =>
          _BoardTitleDialog(memberName: u.name, initialTitle: current),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (result.isEmpty) {
        // Deleting the role removes the student from the board entirely.
        widget.club.boardMemberIds.remove(u.id);
        widget.club.boardMemberTitles.remove(u.id);
      } else {
        widget.club.boardMemberTitles[u.id] = result;
      }
    });
    await contentStore.saveBoardMemberIds();
    await contentStore.saveBoardMemberTitles();
    userState.bumpClubInfo();
    if (!mounted) return;
    widget.onBoardChanged();
  }

  Future<void> _confirmRemove(dynamic u) async {
    // First confirmation
    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          'Remove Board Member',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to remove ${u.name} from the board?',
          style: TextStyle(color: AppColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.secondaryText),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Remove',
              style: TextStyle(color: AppColors.primaryRed),
            ),
          ),
        ],
      ),
    );
    if (first != true || !mounted) return;

    // Second confirmation
    final second = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          'Confirm Removal',
          style: TextStyle(
            color: AppColors.primaryRed,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will permanently remove ${u.name} from the board of ${widget.club.name}. Continue?',
          style: TextStyle(color: AppColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.secondaryText),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Yes, Remove'),
          ),
        ],
      ),
    );
    if (second != true || !mounted) return;

    setState(() {
      widget.club.boardMemberIds.remove(u.id);
      widget.club.boardMemberTitles.remove(u.id);
    });
    await contentStore.saveBoardMemberIds();
    await contentStore.saveBoardMemberTitles();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${u.name} removed from the board.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    widget.onBoardChanged();
  }

  @override
  Widget build(BuildContext context) {
    // Resolve every board-member id against both the static user list and the
    // people-service cache, so a member added from the live members list (not
    // in the seed data) still shows up here for everyone.
    final pool = <String, User>{
      for (final u in users) u.id: u,
      for (final u in peopleService.cachedPeople) u.id: u,
    };
    final members = widget.club.boardMemberIds
        .map((id) => pool[id])
        .whereType<User>()
        .toList();
    final authorized = _isClubAdmin;
    final cardColor = _clubPageCard(context);
    final borderColor = _clubPageBorder(context);
    final panelText = AppColors.text;
    final mutedText = AppColors.secondaryText;

    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        // ── Board Members header ───────────────────────────────────────────────
        Container(
          width: double.infinity,
          color: cardColor,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              const Icon(
                Icons.shield_outlined,
                color: Color(0xFF1565C0),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Board Members',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: panelText,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0x1E1565C0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${members.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0),
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: borderColor),

        // ── Board Members list ─────────────────────────────────────────────────
        if (members.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, size: 48, color: mutedText),
                SizedBox(height: 12),
                Text(
                  'No board members yet.',
                  style: TextStyle(fontSize: 15, color: mutedText),
                ),
                SizedBox(height: 6),
                Text(
                  'Club admins can add members from Manage board members.',
                  style: TextStyle(fontSize: 12, color: mutedText),
                ),
              ],
            ),
          )
        else
          ...members.map((u) {
            final title = widget.club.boardMemberTitles[u.id];
            final isAdmin = _isClubAdmin;
            return Column(
              children: [
                ListTile(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserProfileScreen(user: u),
                    ),
                  ),
                  leading: UserAvatar(
                    userId: u.id,
                    name: u.name,
                    size: 44,
                    fontSize: 18,
                    backgroundColor: const Color(
                      0xFF1565C0,
                    ).withValues(alpha: 0.12),
                    textColor: const Color(0xFF1565C0),
                  ),
                  title: Text(
                    userState.displayNameFor(u.id, u.name),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: panelText,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null && title.isNotEmpty)
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1565C0),
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        Text(
                          'Board Member',
                          style: TextStyle(fontSize: 12, color: mutedText),
                        ),
                      Text(
                        u.email,
                        style: TextStyle(fontSize: 11, color: mutedText),
                      ),
                    ],
                  ),
                  trailing: authorized
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isAdmin)
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  color: Color(0xFF1565C0),
                                  size: 20,
                                ),
                                tooltip: 'Set title',
                                onPressed: () => _editTitle(u),
                              ),
                            IconButton(
                              icon: Icon(
                                Icons.remove_circle_outline,
                                color: mutedText,
                                size: 22,
                              ),
                              tooltip: 'Remove from board',
                              onPressed: () => _confirmRemove(u),
                            ),
                          ],
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x1E1565C0),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Board',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1565C0),
                            ),
                          ),
                        ),
                ),
                Divider(height: 1, indent: 72, color: borderColor),
              ],
            );
          }),
      ],
    );
  }
}

// ─── Board title dialog ───────────────────────────────────────────────────────
// Owns its TextEditingController so it is disposed only when the dialog route is
// fully gone — avoids "TextEditingController used after being disposed" crashes
// that happen if the caller disposes the controller during the close animation.
// Pops with: null (cancel), '' (remove title), or the trimmed title (save).

class _BoardTitleDialog extends StatefulWidget {
  final String memberName;
  final String initialTitle;

  const _BoardTitleDialog({
    required this.memberName,
    required this.initialTitle,
  });

  @override
  State<_BoardTitleDialog> createState() => _BoardTitleDialogState();
}

class _BoardTitleDialogState extends State<_BoardTitleDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialTitle,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: Text(
        'Set title for ${widget.memberName}',
        style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        style: TextStyle(color: AppColors.text),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
        decoration: InputDecoration(
          hintText: 'e.g. President, Secretary…',
          hintStyle: TextStyle(color: AppColors.secondaryText),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: AppColors.secondaryText),
          ),
        ),
        if (widget.initialTitle.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: Text(
              'Remove role',
              style: TextStyle(color: AppColors.primaryRed),
            ),
          ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text('Save'),
        ),
      ],
    );
  }
}

// ─── Stat cell ────────────────────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final bool dark;
  final VoidCallback? onTap;
  const _StatCell({
    required this.value,
    required this.label,
    this.dark = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: dark
                ? AppColors.secondaryText.withValues(alpha: 0.9)
                : AppColors.secondaryText,
          ),
        ),
      ],
    );

    if (onTap == null) return content;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: content,
      ),
    );
  }
}

// ─── Members sheet ───────────────────────────────────────────────────────────

class _ClubMembersSheet extends StatefulWidget {
  final Club club;
  final Color color;
  final List<User> members;
  final int totalCount;

  const _ClubMembersSheet({
    required this.club,
    required this.color,
    required this.members,
    required this.totalCount,
  });

  @override
  State<_ClubMembersSheet> createState() => _ClubMembersSheetState();
}

class _ClubMembersSheetState extends State<_ClubMembersSheet> {
  late List<User> _members = widget.members;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final members = await peopleService.fetchClubMembers(widget.club.id);
      if (!mounted) return;
      setState(() {
        if (members.isNotEmpty || widget.members.isEmpty) {
          _members = _sortMembers(members);
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _members = _sortMembers(widget.members);
        _loading = false;
        _error = widget.members.isEmpty
            ? 'Member profiles could not be loaded.'
            : null;
      });
    }
  }

  List<User> _sortMembers(List<User> members) {
    final sorted = [...members];
    sorted.sort((a, b) {
      final aBoard = widget.club.boardMemberIds.contains(a.id);
      final bBoard = widget.club.boardMemberIds.contains(b.id);
      if (aBoard != bBoard) return aBoard ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return sorted;
  }

  /// Only the club's own admin can assign / clear board roles here.
  bool get _isClubAdmin =>
      clubIsManagedByAdmin(widget.club, authService.currentAdmin?.id ?? '');

  /// The role label for [member], or null if they hold no board role.
  String? _roleFor(User member) {
    if (!widget.club.boardMemberIds.contains(member.id)) return null;
    final raw = widget.club.boardMemberTitles[member.id]?.trim() ?? '';
    return raw.isEmpty ? 'Board Member' : raw;
  }

  void _viewProfile(User member) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserProfileScreen(user: member)),
    );
  }

  /// Owner tap → choose: view profile, assign/edit a club role, or remove role.
  void _openMemberActions(User member) {
    final hasRole = widget.club.boardMemberIds.contains(member.id);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        top: false,
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
            ListTile(
              leading: Icon(Icons.person_outline, color: AppColors.text),
              title: Text(
                'View profile',
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(sheetCtx);
                _viewProfile(member);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.workspace_premium_outlined,
                color: AppColors.primaryRed,
              ),
              title: Text(
                hasRole ? 'Edit club role' : 'Assign club role',
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(sheetCtx);
                _assignRole(member);
              },
            ),
            if (hasRole)
              ListTile(
                leading: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.red,
                ),
                title: const Text(
                  'Remove from board',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _removeRole(member);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _assignRole(User member) async {
    final current = widget.club.boardMemberTitles[member.id] ?? '';
    final result = await showDialog<String>(
      context: context,
      builder: (_) =>
          _BoardTitleDialog(memberName: member.name, initialTitle: current),
    );
    if (result == null || !mounted) return;

    if (result.isEmpty) {
      // Clearing the title deletes the role entirely — the student leaves the
      // board and disappears from the board area and their profile.
      widget.club.boardMemberIds.remove(member.id);
      widget.club.boardMemberTitles.remove(member.id);
    } else {
      if (!widget.club.boardMemberIds.contains(member.id)) {
        widget.club.boardMemberIds.add(member.id);
      }
      widget.club.boardMemberTitles[member.id] = result;
    }
    await contentStore.saveBoardMemberIds();
    await contentStore.saveBoardMemberTitles();
    userState.bumpClubInfo();
    if (!mounted) return;
    setState(() => _members = _sortMembers(_members));
  }

  Future<void> _removeRole(User member) async {
    widget.club.boardMemberIds.remove(member.id);
    widget.club.boardMemberTitles.remove(member.id);
    await contentStore.saveBoardMemberIds();
    await contentStore.saveBoardMemberTitles();
    userState.bumpClubInfo();
    if (!mounted) return;
    setState(() => _members = _sortMembers(_members));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.42,
      maxChildSize: 0.92,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Members',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${widget.totalCount}',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (_loading) LinearProgressIndicator(color: widget.color),
            Expanded(
              child: _members.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Text(
                          _loading
                              ? 'Loading members...'
                              : _error ?? 'No members to show yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                      itemCount: _members.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        indent: 62,
                        color: AppColors.divider.withValues(alpha: 0.8),
                      ),
                      itemBuilder: (context, index) {
                        final member = _members[index];
                        final role = _roleFor(member);

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 6,
                          ),
                          leading: UserAvatar(
                            userId: member.id,
                            name: member.name,
                            size: 46,
                            fontSize: 16,
                          ),
                          title: Text(
                            userState.displayNameFor(member.id, member.name),
                            style: TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: role == null
                              ? null
                              : Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.workspace_premium_outlined,
                                        size: 13,
                                        color: widget.color,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          role,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: widget.color,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                          trailing: _isClubAdmin
                              ? Icon(
                                  Icons.more_horiz_rounded,
                                  color: AppColors.secondaryText,
                                )
                              : null,
                          onTap: () {
                            if (_isClubAdmin) {
                              _openMemberActions(member);
                            } else {
                              _viewProfile(member);
                            }
                          },
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

// ─── Icon tab (icon + label) ──────────────────────────────────────────────────

class _IconTab extends StatelessWidget {
  final IconData icon;
  final String label;
  const _IconTab({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}
