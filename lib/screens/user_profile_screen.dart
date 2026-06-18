import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/club.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/mock_data.dart';
import '../services/people_service.dart';
import '../services/personalization_service.dart' show kAcademicPrograms;
import '../services/user_prefs_service.dart';
import '../services/user_state.dart';
import '../widgets/academic_program_picker.dart';
import '../widgets/club_avatar.dart';
import '../widgets/user_avatar.dart';
import 'chat_screen.dart';
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
    _hydrateConnections();
  }

  @override
  void didUpdateWidget(covariant UserProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id) _hydrateConnections();
  }

  Future<void> _hydrateConnections() async {
    setState(() {
      _connectionsLoading = true;
      _connectionsError = null;
    });
    try {
      await peopleService.hydrateConnectionsFor(widget.user.id);
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

  List<Club> get _subscribedClubs => widget.user.subscribedClubIds
      .map(
        (id) => clubs.firstWhere((c) => c.id == id, orElse: () => clubs.first),
      )
      .where((c) => widget.user.subscribedClubIds.contains(c.id))
      .toList();

  void _openClub(Club club) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClubProfileScreen(club: club, color: _clubColor(club)),
      ),
    );
  }

  String get _myId =>
      authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

  void _persist() => userPrefsService.save(_myId);

  void _tryOpenChat() {
    final otherId = widget.user.id;
    final name = userState.displayNameFor(otherId, widget.user.name);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(otherUserId: otherId, otherUserName: name),
      ),
    );
  }

  Future<void> _handleFollowTap() async {
    final user = widget.user;
    final isFollowing = userState.isFollowingUser(user.id);
    final isPending = userState.hasPendingRequest(user.id);

    if (isFollowing && !isPending) {
      setState(() => userState.toggleFollowUser(user.id));
      _persist();
      try {
        await peopleService.setFollowing(
          followerId: _myId,
          followingId: user.id,
          follow: false,
        );
      } catch (_) {
        setState(() => userState.toggleFollowUser(user.id));
        _persist();
      }
      return;
    }
    if (isPending) {
      setState(() {
        userState.pendingFollowRequests.remove(user.id);
        userState.followedUserIds.remove(user.id);
      });
      _persist();
      return;
    }
    setState(() => userState.followedUserIds.add(user.id));
    _persist();
    try {
      await peopleService.setFollowing(
        followerId: _myId,
        followingId: user.id,
        follow: true,
      );
    } catch (_) {
      setState(() => userState.followedUserIds.remove(user.id));
      _persist();
    }
  }

  void _openUserProfile(User u) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserProfileScreen(user: u)),
    );
  }

  static const List<String> _yearOptions = [
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
    '5th Year',
  ];

  void _editProfile() {
    final id = _myId;
    final bioController = TextEditingController(text: userState.bios[id] ?? '');
    final savedMajor = userState.majors[id];
    String? selectedMajor = kAcademicPrograms.contains(savedMajor)
        ? savedMajor
        : null;
    var selectedYear = userState.years[id];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            18,
            22,
            MediaQuery.of(context).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Edit profile',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Bio',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: bioController,
                maxLines: 3,
                maxLength: 160,
                decoration: const InputDecoration(
                  hintText: 'Tell people a bit about yourself',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Major',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 6),
              AcademicProgramField(
                value: selectedMajor,
                hint: 'Select your major',
                onTap: () async {
                  final result = await showAcademicProgramPicker(
                    context: context,
                    title: 'Select major',
                    selected: selectedMajor == null
                        ? const []
                        : [selectedMajor!],
                  );
                  if (result == null || !context.mounted) return;
                  setSheetState(
                    () => selectedMajor = result.isEmpty ? null : result.first,
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Year',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _yearOptions.map((year) {
                  final isOn = selectedYear == year;
                  return GestureDetector(
                    onTap: () =>
                        setSheetState(() => selectedYear = isOn ? null : year),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: isOn ? _burgundy : AppColors.lightGray,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isOn ? _burgundy : AppColors.divider,
                        ),
                      ),
                      child: Text(
                        year,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isOn ? Colors.white : AppColors.text,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    userState.setBio(id, bioController.text.trim());
                    userState.setMajor(id, selectedMajor ?? '');
                    userState.setYear(id, selectedYear ?? '');
                    _persist();
                    Navigator.pop(sheetContext);
                    if (mounted) setState(() {});
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPeopleSheet(String title, List<User> people) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
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
                    const SizedBox(height: 14),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              if (people.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    _connectionsLoading
                        ? 'Loading connections...'
                        : _connectionsError ?? 'No one here yet.',
                    style: TextStyle(color: AppColors.secondaryText),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: people.length,
                    separatorBuilder: (_, i) =>
                        const Divider(height: 1, indent: 72),
                    itemBuilder: (ctx, i) {
                      final u = people[i];
                      return ListTile(
                        onTap: () {
                          Navigator.pop(ctx);
                          _openUserProfile(u);
                        },
                        leading: UserAvatar(
                          userId: u.id,
                          name: u.name,
                          size: 44,
                          fontSize: 16,
                        ),
                        title: Text(
                          userState.displayNameFor(u.id, u.name),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        subtitle: userState.usernameFor(u.id) != null
                            ? Text(
                                u.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.secondaryText,
                                ),
                              )
                            : null,
                        trailing: Icon(
                          Icons.chevron_right,
                          color: AppColors.secondaryText,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
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

                // 5 ── Interests section ────────────────────────────────────────
                _buildInterestsSection(_interestsForUser(user)),

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
                            Text(
                              major,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _burgundy,
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
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ],
                          ] else if (year != null) ...[
                            Text(
                              year,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.secondaryText,
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
                      child: ElevatedButton(
                        onPressed: _editProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _burgundy,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Edit profile',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
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
              else
                Column(
                  children: [
                    // Follow button
                    _FollowButton(
                      isFollowing: isFollowingUser,
                      isPending: isPending,
                      onTap: _handleFollowTap,
                    ),
                    const SizedBox(height: 6),
                    // Message button
                    SizedBox(
                      height: 34,
                      child: OutlinedButton(
                        onPressed: _tryOpenChat,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.text,
                          side: BorderSide(color: AppColors.divider, width: 1),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Message',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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
                  onTap: () => _showClubsSheet(subClubs),
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
                  onTap: () => _showPeopleSheet('Followers', liveFollowers),
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
                  onTap: () => _showPeopleSheet('Following', liveFollowing),
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

  List<String> _interestsForUser(User user) {
    final saved = userState.interests[user.id];
    if (saved != null && saved.isNotEmpty) return saved;
    const fallback = {
      'u1': ['Robotics', 'Photography', 'Film', 'Coding', 'AI / ML'],
      'u2': ['Debate', 'Rowing', 'Film', 'Climate', 'Entrepreneur'],
      'u3': ['Music', 'Theatre', 'Greek life', 'Dance', 'Esports'],
      'u4': ['Climate', 'Hiking', 'Volunteering', 'Photography'],
      'u5': ['Coding', 'AI / ML', 'Robotics', 'Entrepreneur', 'Film'],
    };
    return fallback[user.id] ??
        user.subscribedClubIds.take(5).map((id) {
          final club = clubs.firstWhere(
            (c) => c.id == id,
            orElse: () => clubs.first,
          );
          final name = club.name.split('(').first.trim();
          return name.split(' ').take(2).join(' ');
        }).toList();
  }

  Widget _buildInterestsSection(List<String> interests) {
    if (interests.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Interests',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_isOwnProfile)
                const Text(
                  'Edit',
                  style: TextStyle(
                    fontSize: 13,
                    color: _burgundy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 9,
            children: interests
                .map(
                  (interest) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: _burgundy,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      interest,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  void _showClubsSheet(List<Club> subClubs) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.52,
        minChildSize: 0.35,
        maxChildSize: 0.84,
        expand: false,
        builder: (sheetContext, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Row(
                  children: [
                    const Text(
                      'Followed clubs',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _burgundy,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${subClubs.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: subClubs.isEmpty
                    ? Center(
                        child: Text(
                          'No followed clubs yet.',
                          style: TextStyle(color: AppColors.secondaryText),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: subClubs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final club = subClubs[index];
                          final color = _clubColor(club);
                          return GestureDetector(
                            onTap: () {
                              Navigator.pop(sheetContext);
                              _openClub(club);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: Row(
                                children: [
                                  ClubAvatar(
                                    clubId: club.id,
                                    clubName: club.name,
                                    color: color,
                                    size: 44,
                                    fontSize: 18,
                                    borderRadius: 13,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      club.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.text,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.secondaryText,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return const SizedBox(height: 28);
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
  final VoidCallback onTap;

  const _FollowButton({
    required this.isFollowing,
    required this.isPending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final filled = !isFollowing && !isPending;
    final label = isPending
        ? 'Requested'
        : isFollowing
        ? 'Following'
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
