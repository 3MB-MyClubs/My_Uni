import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/club.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/mock_data.dart';
import '../services/people_service.dart';
import '../services/user_prefs_service.dart';
import '../services/user_state.dart';
import '../widgets/club_avatar.dart';
import '../widgets/user_avatar.dart';
import 'club_profile_screen.dart';
import 'saved_posts_screen.dart';

// ── Design palette ─────────────────────────────────────────────────────────────
const _burgundy = Color(0xFF8C1D40);
const _burgundyDeep = Color(0xFF6E1422);
const _burgundySoft = Color(0xFFF2DDE0);
const _forest = Color(0xFF3F6B4E);

class UserProfileScreen extends StatefulWidget {
  final User user;
  const UserProfileScreen({super.key, required this.user});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _connectionsLoading = false;
  String? _connectionsError;
  static const List<Color> _clubColors = [
    Color(0xFF8C1D40),
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFF6A1B9A),
    Color(0xFFE65100),
    Color(0xFF00838F),
  ];

  Color _clubColor(Club club) {
    final idx = clubs.indexOf(club);
    return _clubColors[(idx < 0 ? 0 : idx) % _clubColors.length];
  }

  bool get _isOwnProfile {
    final myId =
        authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
    return widget.user.id == myId;
  }

  Map<String, User> get _knownPeopleById {
    final knownPeople = <String, User>{
      for (final user in users) user.id: user,
      for (final user in peopleService.cachedPeople) user.id: user,
    };
    final currentUser = authService.currentUser;
    if (currentUser != null) knownPeople[currentUser.id] = currentUser;
    return knownPeople;
  }

  List<User> get _following {
    if (_isOwnProfile) {
      final knownPeople = _knownPeopleById;
      return userState.followedUserIds
          .map((id) => knownPeople[id])
          .whereType<User>()
          .toList();
    }

    final liveFollowing = peopleService.followingFor(widget.user.id);
    if (liveFollowing.isNotEmpty) return liveFollowing;

    final knownPeople = _knownPeopleById;
    return widget.user.followingUserIds
        .map((id) => knownPeople[id])
        .whereType<User>()
        .toList();
  }

  List<User> get _followers {
    final liveFollowers = peopleService.followersFor(widget.user.id);
    final followers = <String, User>{
      for (final user in liveFollowers) user.id: user,
      for (final user in users.where(
        (u) => u.followingUserIds.contains(widget.user.id),
      ))
        user.id: user,
    };

    final currentUser = authService.currentUser;
    if (!_isOwnProfile &&
        currentUser != null &&
        userState.isFollowingUser(widget.user.id)) {
      followers[currentUser.id] = currentUser;
    }

    return followers.values.toList();
  }

  @override
  void initState() {
    super.initState();
    _hydrateProfile();
  }

  @override
  void didUpdateWidget(covariant UserProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id) _hydrateProfile();
  }

  Future<void> _hydrateProfile() async {
    setState(() {
      _connectionsLoading = true;
      _connectionsError = null;
    });
    try {
      await Future.wait([
        peopleService.hydrateConnectionsFor(widget.user.id),
        peopleService.hydrateProfileDetailsFor(widget.user.id),
      ]);
      if (mounted) {
        setState(() => _connectionsLoading = false);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _connectionsLoading = false;
        _connectionsError = 'Could not load connections.';
      });
    }
  }

  List<Club> get _subscribedClubs {
    final liveIds = peopleService.clubIdsFor(widget.user.id);
    final ids = _isOwnProfile
        ? userState.followedClubIds
        : liveIds.isNotEmpty
        ? liveIds
        : widget.user.subscribedClubIds.toSet();

    final followed = [
      for (final id in ids)
        for (final club in clubs)
          if (club.id == id) club,
    ];

    // Include clubs where this student holds a board role even if they don't
    // follow them, and pin all role-clubs to the very top.
    for (final club in clubs) {
      if (_roleTitleFor(club) != null && !followed.contains(club)) {
        followed.add(club);
      }
    }
    final withRole = [
      for (final c in followed)
        if (_roleTitleFor(c) != null) c,
    ];
    final rest = [
      for (final c in followed)
        if (_roleTitleFor(c) == null) c,
    ];
    return [...withRole, ...rest];
  }

  void _openClub(Club club) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClubProfileScreen(club: club, color: _clubColor(club)),
      ),
    );
  }

  Future<void> _handleFollowTap() =>
      _toggleUserFollow(widget.user, () => setState(() {}));

  void _openUserProfile(User u) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserProfileScreen(user: u)),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final subClubs = _subscribedClubs;
    final followingList = _following;
    final followersList = _followers;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Slim pinned app bar ──────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            foregroundColor: AppColors.text,
            elevation: 0,
            title: ListenableBuilder(
              listenable: userState,
              builder: (_, _) => Text(
                userState.displayNameFor(user.id, user.name),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
          ),

          // ── Main content ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1 ── Hero banner + avatar ─────────────────────────────────────
                _HeroBanner(user: user),

                // 2 ── Name block ───────────────────────────────────────────────
                _buildNameBlock(user),

                // 3 ── Bio strip ────────────────────────────────────────────────
                _buildBioStrip(user),

                // 4 ── Stats card ───────────────────────────────────────────────
                _buildStatsCard(subClubs, followersList, followingList),

                // 5 ── Clubs card ───────────────────────────────────────────────
                if (subClubs.isNotEmpty) _buildClubsCard(subClubs),

                // 6 ── Footer ──────────────────────────────────────────────────
                _buildFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Name block ───────────────────────────────────────────────────────────────

  Widget _buildNameBlock(User user) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 46, 24, 0),
      child: ListenableBuilder(
        listenable: userState,
        builder: (_, _) {
          final isFollowingUser = userState.isFollowingUser(user.id);
          final isPending = userState.hasPendingRequest(user.id);
          final major = userState.majors[user.id];
          final year = userState.years[user.id];

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: name + sub-line
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userState.displayNameFor(user.id, user.name),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (major != null || year != null)
                      Row(
                        children: [
                          const Icon(
                            Icons.school_outlined,
                            size: 14,
                            color: _burgundy,
                          ),
                          const SizedBox(width: 4),
                          if (major != null) ...[
                            Flexible(
                              child: Text(
                                major,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _burgundy,
                                ),
                              ),
                            ),
                            if (year != null) ...[
                              Text(
                                '  ·  ',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                              Text(
                                year,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ],
                          ] else if (year != null) ...[
                            Flexible(
                              child: Text(
                                year,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Right: action buttons
              if (_isOwnProfile)
                Column(
                  children: [
                    SizedBox(
                      height: 34,
                      width: 34,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SavedPostsScreen(),
                          ),
                        ),
                        icon: Icon(
                          Icons.bookmark_outline,
                          color: AppColors.text,
                          size: 20,
                        ),
                        style: IconButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                            side: BorderSide(
                              color: AppColors.divider,
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else if (authService.isStudentSession)
                Column(
                  children: [
                    // Follow button
                    _FollowButton(
                      isFollowing: isFollowingUser,
                      isPending: isPending,
                      onTap: _handleFollowTap,
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  // ── Bio strip ────────────────────────────────────────────────────────────────

  Widget _buildBioStrip(User user) {
    return ListenableBuilder(
      listenable: userState,
      builder: (_, _) {
        final bioRaw = userState.bios[user.id];
        final bioText = (bioRaw == null || bioRaw.trim().isEmpty)
            ? ''
            : bioRaw.trim();
        final isEmpty = bioText.isEmpty;
        if (isEmpty && !_isOwnProfile) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  isEmpty ? 'Add a bio…' : bioText,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    color: isEmpty ? AppColors.secondaryText : AppColors.text,
                  ),
                ),
              ),
              if (_isOwnProfile) ...[
                const SizedBox(width: 6),
                const Icon(Icons.edit_outlined, size: 12, color: _burgundy),
              ],
            ],
          ),
        );
      },
    );
  }

  // ── Stats card ───────────────────────────────────────────────────────────────

  Widget _buildStatsCard(
    List<Club> subClubs,
    List<User> followers,
    List<User> following,
  ) {
    return ListenableBuilder(
      listenable: userState,
      builder: (_, _) {
        // Recompute live from userState
        final liveFollowers = _followers;
        final liveFollowing = _following;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border.all(color: AppColors.divider, width: 1),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openConnections(_ConnTab.clubs),
                  child: _StatBlock(
                    value: '${subClubs.length}',
                    label: 'Clubs',
                  ),
                ),
              ),
              _VertDivider(),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openConnections(_ConnTab.followers),
                  child: _StatBlock(
                    value: '${liveFollowers.length}',
                    label: 'Followers',
                  ),
                ),
              ),
              _VertDivider(),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openConnections(_ConnTab.following),
                  child: _StatBlock(
                    value: '${liveFollowing.length}',
                    label: 'Following',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Clubs card ───────────────────────────────────────────────────────────────

  Widget _buildClubsCard(List<Club> subClubs) {
    final showSeeAll = subClubs.length > 4;
    final displayCount = showSeeAll ? 4 : subClubs.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.divider, width: 1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'CLUBS · ${subClubs.length}',
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.9,
                ),
              ),
              if (showSeeAll) ...[
                const Spacer(),
                GestureDetector(
                  onTap: () => _openConnections(_ConnTab.clubs),
                  child: const Text(
                    'See all',
                    style: TextStyle(
                      color: _burgundy,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          for (int i = 0; i < displayCount; i++)
            _buildClubRow(subClubs[i], isLast: i == displayCount - 1),
        ],
      ),
    );
  }

  Widget _buildClubRow(Club club, {required bool isLast}) {
    final memberCount = subscriptions.where((s) => s.clubId == club.id).length;
    final roleTitle = _roleTitleFor(club);
    final isLeader = roleTitle != null;

    return GestureDetector(
      onTap: () => _openClub(club),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(color: AppColors.divider, width: 1),
                ),
        ),
        child: Row(
          children: [
            ClubAvatar(
              clubId: club.id,
              clubName: club.name,
              color: _clubColor(club),
              imageUrl: club.logoUrl,
              size: 42,
              fontSize: 18,
              borderRadius: 13,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    club.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$memberCount members',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: isLeader ? _burgundy : AppColors.background,
                borderRadius: BorderRadius.circular(100),
                border: isLeader ? null : Border.all(color: AppColors.divider),
              ),
              child: Text(
                roleTitle ?? 'Member',
                style: TextStyle(
                  color: isLeader ? Colors.white : AppColors.text,
                  fontSize: 11,
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

  /// The board role title this student holds at [club], or null if none.
  /// Empty stored titles fall back to a generic "Board Member" label.
  String? _roleTitleFor(Club club) {
    if (!club.boardMemberIds.contains(widget.user.id)) return null;
    final raw = club.boardMemberTitles[widget.user.id]?.trim() ?? '';
    return raw.isEmpty ? 'Board Member' : raw;
  }

  void _openConnections(_ConnTab tab) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ConnectionsScreen(
          title: userState.displayNameFor(widget.user.id, widget.user.name),
          initialTab: tab,
          clubsOf: () => _subscribedClubs,
          followersOf: () => _followers,
          followingOf: () => _following,
          roleTitleFor: _roleTitleFor,
          clubColor: _clubColor,
          onOpenClub: _openClub,
          onOpenUser: _openUserProfile,
          peopleLoading: _connectionsLoading,
          peopleError: _connectionsError,
        ),
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return const SizedBox(height: 28);
  }
}

// ── Follow toggle helper ────────────────────────────────────────────────────────
// Shared by the name-block follow button and every row button inside
// _ConnectionsScreen, so following/unfollowing works the same way regardless
// of which list a person is tapped from.

Future<void> _toggleUserFollow(User target, VoidCallback rebuild) async {
  if (!authService.isStudentSession) return;
  final myId = authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
  if (target.id == myId) return;

  final isFollowing = userState.isFollowingUser(target.id);
  final isPending = userState.hasPendingRequest(target.id);

  if (isFollowing && !isPending) {
    userState.toggleFollowUser(target.id);
    rebuild();
    userPrefsService.save(myId);
    try {
      await peopleService.setFollowing(
        followerId: myId,
        followingId: target.id,
        follow: false,
      );
    } catch (_) {
      userState.toggleFollowUser(target.id);
      rebuild();
      userPrefsService.save(myId);
    }
    return;
  }
  if (isPending) {
    userState.pendingFollowRequests.remove(target.id);
    userState.followedUserIds.remove(target.id);
    rebuild();
    userPrefsService.save(myId);
    return;
  }
  userState.followedUserIds.add(target.id);
  rebuild();
  userPrefsService.save(myId);
  try {
    await peopleService.setFollowing(
      followerId: myId,
      followingId: target.id,
      follow: true,
    );
  } catch (_) {
    userState.followedUserIds.remove(target.id);
    rebuild();
    userPrefsService.save(myId);
  }
}

/// Whether [other] already follows the current session user (drives the
/// "Follow back" vs. plain "Follow" label, same distinction Instagram makes).
bool _userFollowsMe(User other) {
  final myId = authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
  if (myId.isEmpty || other.id == myId) return false;
  if (peopleService.followersFor(myId).any((u) => u.id == other.id)) {
    return true;
  }
  return other.followingUserIds.contains(myId);
}

// ── Connections screen ──────────────────────────────────────────────────────────
// Instagram-style full-screen list with tabs to shuffle between a profile's
// Clubs, Followers and Following, plus a search field — replaces the old
// separate bottom sheets so all three live behind one consistent UI.

enum _ConnTab { clubs, followers, following }

class _ConnectionsScreen extends StatefulWidget {
  final String title;
  final _ConnTab initialTab;
  final List<Club> Function() clubsOf;
  final List<User> Function() followersOf;
  final List<User> Function() followingOf;
  final String? Function(Club) roleTitleFor;
  final Color Function(Club) clubColor;
  final ValueChanged<Club> onOpenClub;
  final ValueChanged<User> onOpenUser;
  final bool peopleLoading;
  final String? peopleError;

  const _ConnectionsScreen({
    required this.title,
    required this.initialTab,
    required this.clubsOf,
    required this.followersOf,
    required this.followingOf,
    required this.roleTitleFor,
    required this.clubColor,
    required this.onOpenClub,
    required this.onOpenUser,
    required this.peopleLoading,
    required this.peopleError,
  });

  @override
  State<_ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<_ConnectionsScreen> {
  late _ConnTab _tab = widget.initialTab;
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Club> _matchClubs(List<Club> list) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  List<User> _matchPeople(List<User> list) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((u) {
      final displayName = userState.displayNameFor(u.id, u.name).toLowerCase();
      return displayName.contains(q) || u.name.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.text,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: ListenableBuilder(
        listenable: userState,
        builder: (_, _) {
          final clubs = widget.clubsOf();
          final followers = widget.followersOf();
          final following = widget.followingOf();

          return Column(
            children: [
              _buildTabBar(clubs.length, followers.length, following.length),
              Divider(height: 1, color: AppColors.divider),
              _buildSearchBar(),
              Expanded(
                child: switch (_tab) {
                  _ConnTab.clubs => _buildClubsList(_matchClubs(clubs)),
                  _ConnTab.followers => _buildPeopleList(
                    _matchPeople(followers),
                    'No followers yet.',
                  ),
                  _ConnTab.following => _buildPeopleList(
                    _matchPeople(following),
                    'Not following anyone yet.',
                  ),
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabBar(int clubsCount, int followersCount, int followingCount) {
    Widget tabItem(String label, int count, _ConnTab tab) {
      final selected = _tab == tab;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _tab = tab),
          child: Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 12),
            child: Column(
              children: [
                Text(
                  '$count $label',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? AppColors.text : AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 2,
                  color: selected ? _burgundy : Colors.transparent,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tabItem('Clubs', clubsCount, _ConnTab.clubs),
        tabItem('Followers', followersCount, _ConnTab.followers),
        tabItem('Following', followingCount, _ConnTab.following),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.search, size: 18, color: AppColors.secondaryText),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                style: TextStyle(fontSize: 14, color: AppColors.text),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Search',
                  hintStyle: TextStyle(color: AppColors.secondaryText),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClubsList(List<Club> clubs) {
    if (clubs.isEmpty) {
      return _emptyState(_query.isEmpty ? 'No clubs yet.' : 'No clubs found.');
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: clubs.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, indent: 72, color: AppColors.divider),
      itemBuilder: (_, i) => _clubTile(clubs[i]),
    );
  }

  Widget _buildPeopleList(List<User> people, String emptyFallback) {
    if (people.isEmpty) {
      final message = _query.isNotEmpty
          ? 'No matches found.'
          : widget.peopleLoading
          ? 'Loading connections...'
          : widget.peopleError ?? emptyFallback;
      return _emptyState(message);
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: people.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, indent: 72, color: AppColors.divider),
      itemBuilder: (_, i) => _personTile(people[i]),
    );
  }

  Widget _emptyState(String text) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.secondaryText),
        ),
      ),
    );
  }

  Widget _clubTile(Club club) {
    final role = widget.roleTitleFor(club);
    final isLeader = role != null;
    return ListTile(
      onTap: () => widget.onOpenClub(club),
      leading: ClubAvatar(
        clubId: club.id,
        clubName: club.name,
        color: widget.clubColor(club),
        imageUrl: club.logoUrl,
        size: 44,
        fontSize: 18,
        borderRadius: 13,
      ),
      title: Text(
        club.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isLeader ? _burgundy : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(999),
          border: isLeader ? null : Border.all(color: AppColors.divider),
        ),
        child: Text(
          role ?? 'Member',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: isLeader ? Colors.white : AppColors.secondaryText,
          ),
        ),
      ),
    );
  }

  Widget _personTile(User user) {
    final myId = authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
    final isMe = user.id == myId;
    final hasUsername = userState.usernameFor(user.id) != null;

    return ListTile(
      onTap: () => widget.onOpenUser(user),
      leading: UserAvatar(
        userId: user.id,
        name: user.name,
        size: 44,
        fontSize: 16,
      ),
      title: Text(
        userState.displayNameFor(user.id, user.name),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
      ),
      subtitle: hasUsername
          ? Text(
              user.name,
              style: TextStyle(fontSize: 12.5, color: AppColors.secondaryText),
            )
          : null,
      trailing: isMe || !authService.isStudentSession
          ? null
          // ListTile.trailing needs a bounded width or it throws — the
          // longest label ("Follow back") sets the fixed width for all.
          : SizedBox(
              width: 108,
              height: 34,
              child: _FollowButton(
                isFollowing: userState.isFollowingUser(user.id),
                isPending: userState.hasPendingRequest(user.id),
                followsMe: _userFollowsMe(user),
                onTap: () => _toggleUserFollow(user, () => setState(() {})),
              ),
            ),
    );
  }
}

// ── Hero banner widget ─────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final User user;
  const _HeroBanner({required this.user});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: userState,
      builder: (_, _) {
        final year = userState.years[user.id];

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SizedBox(
            height: 96,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Banner gradient container
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_burgundy, _burgundyDeep],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Decorative blob 1
                          Positioned(
                            top: -30,
                            right: -20,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                            ),
                          ),
                          // Decorative blob 2
                          Positioned(
                            bottom: -40,
                            right: 60,
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Year badge top-right
                if (year != null && year.isNotEmpty)
                  Positioned(
                    top: 10,
                    right: 12,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.school_outlined,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                year.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // Avatar (overlapping banner bottom)
                Positioned(
                  left: 20,
                  bottom: -36,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _burgundySoft,
                          border: Border.all(
                            color: AppColors.background,
                            width: 4,
                          ),
                        ),
                        child: ClipOval(
                          child: UserAvatar(
                            userId: user.id,
                            name: user.name,
                            size: 90,
                            fontSize: 34,
                          ),
                        ),
                      ),
                      // Online dot
                      Positioned(
                        right: -4,
                        bottom: 4,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _forest,
                            border: Border.all(color: Colors.white, width: 3),
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
      },
    );
  }
}

// ── Follow button ──────────────────────────────────────────────────────────────

class _FollowButton extends StatelessWidget {
  final bool isFollowing;
  final bool isPending;
  final bool followsMe;
  final VoidCallback onTap;

  const _FollowButton({
    required this.isFollowing,
    required this.isPending,
    this.followsMe = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final filled = !isFollowing && !isPending;
    final label = isPending
        ? 'Requested'
        : isFollowing
        ? 'Following'
        : followsMe
        ? 'Follow back'
        : 'Follow';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: filled ? _burgundy : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: filled ? _burgundy : AppColors.divider,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: filled ? Colors.white : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Stat block ─────────────────────────────────────────────────────────────────

class _StatBlock extends StatelessWidget {
  final String value;
  final String label;
  const _StatBlock({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _burgundy,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Vertical divider helper ────────────────────────────────────────────────────

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(vertical: 14),
      color: AppColors.divider,
    );
  }
}
