import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/club.dart';
import '../navigation/chat_page_route.dart';
import '../services/app_colors.dart';
import '../services/app_strings.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/chat_store.dart';
import '../services/checkin_store.dart';
import '../services/club_role_localization.dart';
import '../services/lazy_content_loader.dart';
import '../services/mock_data.dart';
import '../services/moderation_service.dart';
import '../services/people_service.dart';
import '../services/rsvp_store.dart';
import '../services/student_activity_service.dart';
import '../services/student_club_role_service.dart';
import '../services/user_prefs_service.dart';
import '../services/user_state.dart';
import '../widgets/club_avatar.dart';
import '../widgets/moderation_reason_sheet.dart';
import '../widgets/profile_design.dart';
import '../widgets/user_avatar.dart';
import 'chat_thread_screen.dart';
import 'club_profile_screen.dart';
import 'event_detail_screen.dart';
import 'saved_posts_screen.dart';
import 'student_activity_screen.dart';

// ── Design palette ─────────────────────────────────────────────────────────────
const _burgundy = Color(0xFF8C1D40);

class UserProfileScreen extends StatefulWidget {
  final User user;
  const UserProfileScreen({super.key, required this.user});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  /// Anchors `dropdown-menu` under the header's overflow button.
  final GlobalKey _moreButtonKey = GlobalKey();
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
    final idx = clubOrdinal(club.id);
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
          .where((user) => !moderationService.isUserBlocked(user.id))
          .toList();
    }

    final liveFollowing = peopleService.followingFor(widget.user.id);
    if (liveFollowing.isNotEmpty) {
      return liveFollowing
          .where((user) => !moderationService.isUserBlocked(user.id))
          .toList();
    }

    final knownPeople = _knownPeopleById;
    return widget.user.followingUserIds
        .map((id) => knownPeople[id])
        .whereType<User>()
        .where((user) => !moderationService.isUserBlocked(user.id))
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

    return followers.values
        .where((user) => !moderationService.isUserBlocked(user.id))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _hydrateProfile();
    _refreshClubMemberCounts();
  }

  @override
  void didUpdateWidget(covariant UserProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id) {
      _hydrateProfile();
      _refreshClubMemberCounts();
    }
  }

  Future<void> _refreshClubMemberCounts() async {
    try {
      // Profile visits should reuse the shared 30-second engagement snapshot.
      // Pull-to-refresh remains the explicit force-refresh path.
      await lazyContentLoader.ensureCountsLoaded();
      if (mounted) setState(() {});
    } catch (_) {
      // Keep the last successful aggregate snapshot while offline.
    }
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
        _connectionsError = AppLocalizations.of(
          context,
        )!.couldNotLoadConnections;
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

    return studentClubRoleService.orderedProfileClubs(
      userId: widget.user.id,
      followedClubIds: ids,
      allClubs: clubs,
    );
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

  /// `dropdown-menu` on `profile-menu` — the anchored Report / Ban card that
  /// replaced the old safety bottom sheet. The frame's second row reads "Ban
  /// User"; a student cannot ban anyone, so it carries the app's real
  /// destructive action, block-and-report, in the same red weight.
  void _showSafetyMenu() {
    showProfileOverflowMenu(
      context: context,
      anchorKey: _moreButtonKey,
      actions: [
        ProfileMenuAction(
          icon: Icons.flag_outlined,
          label: AppLocalizations.of(context)!.reportUser,
          onTap: _reportUser,
        ),
        ProfileMenuAction(
          icon: Icons.block_rounded,
          label: AppLocalizations.of(context)!.blockAndReportUser,
          onTap: _blockUser,
          destructive: true,
        ),
      ],
    );
  }

  Future<void> _reportUser() async {
    final reason = await showModerationReasonSheet(
      context,
      title: AppLocalizations.of(context)!.whyReportUser,
    );
    if (reason == null || !mounted) return;
    try {
      await moderationService.reportUser(widget.user.id, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.userReported),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.reportSendFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _blockUser() async {
    final reason = await showModerationReasonSheet(
      context,
      title: AppLocalizations.of(context)!.whyBlockUser,
    );
    if (reason == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          AppLocalizations.of(context)!.blockUserQuestion(
            userState.displayNameFor(widget.user.id, widget.user.name),
          ),
          style: TextStyle(color: AppColors.text),
        ),
        content: Text(
          AppLocalizations.of(context)!.blockUserExplanation,
          style: TextStyle(color: AppColors.secondaryText, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppLocalizations.of(context)!.blockAndReportUser),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final myId = authService.currentUser?.id ?? '';
    userState.followedUserIds.remove(widget.user.id);
    userState.pendingFollowRequests.remove(widget.user.id);
    userPrefsService.save(myId);

    var delivered = true;
    try {
      await moderationService.blockUser(widget.user.id, reason: reason);
    } catch (_) {
      delivered = false;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.maybePop(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            delivered
                ? AppLocalizations.of(context)!.userBlockedAndReported
                : AppLocalizations.of(context)!.userBlockedOffline,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

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
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ListenableBuilder(
      listenable: userState,
      builder: (context, _) {
        final displayName = userState.displayNameFor(user.id, user.name);
        final handle = profileHandle(user.email);
        final isFollowingUser = userState.isFollowingUser(user.id);
        final isPending = userState.hasPendingRequest(user.id);
        final canAct = !_isOwnProfile && authService.isStudentSession;

        return Scaffold(
          backgroundColor: ProfileColors.background,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                ProfileBackHeader(
                  title: _isOwnProfile
                      ? l10n.myProfileTitle
                      : handle.isEmpty
                      ? displayName
                      : handle,
                  onBack: () => Navigator.maybePop(context),
                  backTooltip: l10n.backTooltip,
                  trailing: _buildHeaderAction(context),
                ),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      kProfilePagePadding,
                      16,
                      kProfilePagePadding,
                      bottomInset + kProfileNavClearance,
                    ),
                    children: [
                      ProfileHero(
                        userId: user.id,
                        name: displayName,
                        handle: handle,
                        bio: userState.bios[user.id] ?? '',
                        badgeLabel: !_isOwnProfile && _userFollowsMe(user)
                            ? S.followsYou
                            : null,
                        gap: 14,
                        identityGap: 6,
                        stats: [
                          ProfileStat(
                            value: '${_subscribedClubs.length}',
                            label: l10n.clubs,
                            onTap: () => _openConnections(_ConnTab.clubs),
                          ),
                          ProfileStat(
                            value: '${_following.length}',
                            label: l10n.following,
                            onTap: () => _openConnections(_ConnTab.following),
                          ),
                          ProfileStat(
                            value: '${_followers.length}',
                            label: l10n.followers,
                            onTap: () => _openConnections(_ConnTab.followers),
                          ),
                        ],
                        actions: canAct
                            ? Row(
                                children: [
                                  Expanded(
                                    child: ProfileActionButton(
                                      label: isPending
                                          ? l10n.requestedLabel
                                          : isFollowingUser
                                          ? l10n.following
                                          : _userFollowsMe(user)
                                          ? l10n.followBack
                                          : l10n.follow,
                                      // `btn-follow` carries a plus only while
                                      // following is still the action to take.
                                      icon: isFollowingUser || isPending
                                          ? null
                                          : Icons.add_rounded,
                                      filled: !isFollowingUser && !isPending,
                                      onTap: _handleFollowTap,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ProfileActionButton(
                                      label: S.message,
                                      icon: Icons.chat_bubble_outline_rounded,
                                      iconSize: 19,
                                      filled: false,
                                      onTap: () => _openThread(user),
                                    ),
                                  ),
                                ],
                              )
                            : null,
                      ),
                      const SizedBox(height: 22),
                      _buildClubsSection(context),
                      _buildEventsSection(context, user),
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

  /// The header's trailing control: saved posts on your own profile, the
  /// overflow menu when a student is looking at someone else, nothing
  /// otherwise (a club account has no follow, message or report action).
  Widget _buildHeaderAction(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_isOwnProfile) {
      return ProfileCircleButton(
        icon: Icons.bookmark_border_rounded,
        iconSize: 19,
        tooltip: l10n.savedPostsTooltip,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SavedPostsScreen()),
        ),
      );
    }
    if (!authService.isStudentSession) return const SizedBox(width: 34);
    return ProfileCircleButton(
      key: _moreButtonKey,
      icon: Icons.more_vert_rounded,
      iconSize: 20,
      washed: true,
      tooltip: l10n.safetyOptions,
      onTap: _showSafetyMenu,
    );
  }

  void _openThread(User user) {
    final myId = authService.currentUser?.id ?? '';
    final threadId = chatStore.ensureDirectThread(myId, user.id);
    if (threadId == null) return;
    Navigator.push(
      context,
      ChatPageRoute(
        builder: (_) => ChatThreadScreen(threadId: threadId, recipient: user),
      ),
    );
  }

  // ── mutual-clubs ───────────────────────────────────────────────────────────

  /// `mutual-clubs`. The header is only honest when there is an overlap, so
  /// with none it falls back to this student's own clubs under the existing
  /// count header rather than calling them mutual.
  Widget _buildClubsSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theirClubs = _subscribedClubs;
    final mutual = _isOwnProfile || !authService.isStudentSession
        ? const <Club>[]
        : theirClubs.where((club) => userState.isFollowing(club.id)).toList();
    final shown = mutual.isNotEmpty ? mutual : theirClubs;
    if (shown.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionHeader(
          title: mutual.isNotEmpty
              ? S.mutualClubs
              : l10n.clubsCountTitle(theirClubs.length),
          actionLabel: shown.length > 2 ? l10n.seeAll : null,
          onAction: () => _openConnections(_ConnTab.clubs),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < shown.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                ProfileClubCard(
                  club: shown[i],
                  color: _clubColor(shown[i]),
                  detail: l10n.membersCountLabel(clubMemberCount(shown[i].id)),
                  width: 150,
                  nameSize: 11,
                  onTap: () => _openClub(shown[i]),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),
      ],
    );
  }

  // ── hosting ────────────────────────────────────────────────────────────────

  /// `hosting` — what this student is running next. Students never host events
  /// in the app, clubs do, so "Hosting Next" here means an upcoming event at a
  /// club where they hold a board role. With no such event the same cards show
  /// their upcoming events under the plain header instead of over-claiming.
  Widget _buildEventsSection(BuildContext context, User user) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: Listenable.merge([
        rsvpStore,
        checkinStore,
        studentActivityService,
      ]),
      builder: (context, _) {
        final upcoming = studentActivityService.summaryFor(user.id).upcoming;
        final hosting = upcoming
            .where(
              (entry) =>
                  entry.club != null && _roleTitleFor(entry.club!) != null,
            )
            .toList();
        final shown = (hosting.isNotEmpty ? hosting : upcoming)
            .take(3)
            .toList();
        if (shown.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProfileSectionHeader(
              title: hosting.isNotEmpty ? S.hostingNext : l10n.upcomingEvents,
              actionLabel: l10n.seeAll,
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentActivityScreen(
                    userId: user.id,
                    studentName: userState.displayNameFor(user.id, user.name),
                    isOwnProfile: _isOwnProfile,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              ProfileEventCard(
                event: shown[i].event,
                color: shown[i].color,
                whenLabel: profileWhenLabel(
                  context,
                  shown[i].event.dateTime,
                  live: shown[i].isLive,
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EventDetailScreen(
                      event: shown[i].event,
                      color: shown[i].color,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// The board role title this student holds at [club], or null if none.
  /// Empty stored titles fall back to a generic "Board Member" label.
  String? _roleTitleFor(Club club) {
    return studentClubRoleService.roleTitleFor(club, widget.user.id);
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
}

// ── Follow toggle helper ────────────────────────────────────────────────────────
// Shared by the name-block follow button and every row button inside
// _ConnectionsScreen, so following/unfollowing works the same way regardless
// of which list a person is tapped from.

Future<void> _toggleUserFollow(User target, VoidCallback rebuild) async {
  if (!authService.isStudentSession) return;
  final myId =
      authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
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
  final myId =
      authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
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
                    AppLocalizations.of(context)!.noFollowersYet,
                  ),
                  _ConnTab.following => _buildPeopleList(
                    _matchPeople(following),
                    AppLocalizations.of(context)!.notFollowingAnyone,
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
        tabItem(
          AppLocalizations.of(context)!.clubs,
          clubsCount,
          _ConnTab.clubs,
        ),
        tabItem(
          AppLocalizations.of(context)!.followers,
          followersCount,
          _ConnTab.followers,
        ),
        tabItem(
          AppLocalizations.of(context)!.following,
          followingCount,
          _ConnTab.following,
        ),
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
          borderRadius: BorderRadius.all(Radius.circular(12)),
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
                  filled: false,
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: AppLocalizations.of(context)!.search,
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
      return _emptyState(
        _query.isEmpty
            ? AppLocalizations.of(context)!.noClubsYetShort
            : AppLocalizations.of(context)!.noClubsFound,
      );
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
          ? AppLocalizations.of(context)!.noMatchesFoundDot
          : widget.peopleLoading
          ? AppLocalizations.of(context)!.loadingConnections
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
          borderRadius: BorderRadius.all(Radius.circular(999)),
          border: isLeader ? null : Border.all(color: AppColors.divider),
        ),
        child: Text(
          localizedClubRole(
            AppLocalizations.of(context)!,
            role ?? AppLocalizations.of(context)!.memberRoleFallback,
          ),
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
    final myId =
        authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
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
        ? AppLocalizations.of(context)!.requestedLabel
        : isFollowing
        ? AppLocalizations.of(context)!.following
        : followsMe
        ? AppLocalizations.of(context)!.followBack
        : AppLocalizations.of(context)!.follow;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: filled ? _burgundy : Colors.transparent,
          borderRadius: BorderRadius.all(Radius.circular(999)),
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
