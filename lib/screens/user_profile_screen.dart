import 'dart:io';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/club.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/mock_data.dart';
import '../services/user_prefs_service.dart';
import '../services/user_state.dart';
import 'chat_screen.dart';
import 'club_profile_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final User user;

  const UserProfileScreen({super.key, required this.user});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  static const List<Color> _clubColors = [
    Color(0xFF8C1D40), Color(0xFF1565C0), Color(0xFF2E7D32),
    Color(0xFF6A1B9A), Color(0xFFE65100), Color(0xFF00838F),
  ];

  Color _clubColor(Club club) {
    final idx = clubs.indexOf(club);
    return _clubColors[(idx < 0 ? 0 : idx) % _clubColors.length];
  }

  bool get _isOwnProfile {
    final myId = authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
    return widget.user.id == myId;
  }

  List<User> get _following => widget.user.followingUserIds
      .map((id) => users.firstWhere((u) => u.id == id, orElse: () => users.first))
      .where((u) => widget.user.followingUserIds.contains(u.id))
      .toList();

  List<User> get _followers =>
      users.where((u) => u.followingUserIds.contains(widget.user.id)).toList();

  // People that both the logged-in user and this profile user follow.
  List<User> get _mutuals {
    final myFollowing = userState.followedUserIds; // Set<String>
    final theirFollowing = Set<String>.from(widget.user.followingUserIds);
    final sharedIds = myFollowing.intersection(theirFollowing);
    return users.where((u) => sharedIds.contains(u.id)).toList();
  }

  List<Club> get _subscribedClubs => widget.user.subscribedClubIds
      .map((id) => clubs.firstWhere((c) => c.id == id, orElse: () => clubs.first))
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

  String get _myId => authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

  void _persist() => userPrefsService.save(_myId);

  bool _isMutual(String otherId) {
    final meFollowsThem = userState.isFollowingUser(otherId);
    final theyFollowMe = widget.user.followingUserIds.contains(_myId);
    return meFollowsThem && theyFollowMe;
  }

  Future<void> _tryOpenChat() async {
    final otherId = widget.user.id;
    final name = widget.user.name;

    // Block messaging if follow request to a private profile is still pending.
    if (userState.isProfilePrivate(otherId) &&
        !userState.isFollowingUser(otherId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userState.hasPendingRequest(otherId)
                ? 'Wait for $name to accept your follow request first.'
                : 'Request to follow $name before sending a message.',
          ),
          backgroundColor: AppColors.card,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_isMutual(otherId) || userState.hasAcceptedMessageRequest(_myId, otherId)) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatScreen(otherUserId: otherId, otherUserName: name),
      ));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Send message request?',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text)),
        content: Text(
          '$name doesn\'t follow you back yet. Your message will be sent as a request — they\'ll need to accept it before you can chat freely.',
          style: const TextStyle(fontSize: 14, color: AppColors.secondaryText, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      userState.acceptMessageRequest(_myId, otherId);
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatScreen(otherUserId: otherId, otherUserName: name),
      ));
    }
  }

  Future<void> _handleFollowTap() async {
    final user = widget.user;
    final isFollowing = userState.isFollowingUser(user.id);
    final isPending = userState.hasPendingRequest(user.id);
    final isPrivate = userState.isProfilePrivate(user.id);
    final theyFollowMe = user.followingUserIds.contains(_myId);

    // ── Already following → unfollow ─────────────────────────────────────────
    if (isFollowing && !isPending) {
      setState(() => userState.toggleFollowUser(user.id));
      return;
    }

    // ── Pending request → cancel ──────────────────────────────────────────────
    if (isPending) {
      setState(() {
        userState.pendingFollowRequests.remove(user.id);
        userState.followedUserIds.remove(user.id);
      });
      return;
    }

    // ── Private profile → send follow request ─────────────────────────────────
    if (isPrivate) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Request to Follow',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text)),
          content: Text(
            '${user.name} has a private account. Send them a follow request? Once accepted, you\'ll be able to see their posts and send messages.',
            style: const TextStyle(fontSize: 14, color: AppColors.secondaryText, height: 1.5),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Send Request'),
            ),
          ],
        ),
      );
      if (confirmed == true && mounted) {
        setState(() => userState.pendingFollowRequests.add(user.id));
        // Simulate acceptance after 6 seconds for demo.
        Future.delayed(const Duration(seconds: 6), () {
          if (mounted && userState.hasPendingRequest(user.id)) {
            setState(() => userState.acceptFollowRequest(_myId, user.id));
          }
        });
      }
      return;
    }

    // ── Non-private, they don't follow back → show 1-time notice ─────────────
    if (!theyFollowMe && !userState.shownFollowNotice.contains(user.id)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Follow',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text)),
          content: Text(
            '${user.name} doesn\'t follow you back yet. You can still follow them — they won\'t need to approve it.',
            style: const TextStyle(fontSize: 14, color: AppColors.secondaryText, height: 1.5),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Follow'),
            ),
          ],
        ),
      );
      if (confirmed == true && mounted) {
        setState(() {
          userState.followedUserIds.add(user.id);
          userState.shownFollowNotice.add(user.id);
        });
      }
      return;
    }

    // ── Default: just follow ──────────────────────────────────────────────────
    setState(() => userState.followedUserIds.add(user.id));
  }

  void _openUserProfile(User u) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserProfileScreen(user: u)),
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
                    const SizedBox(height: 14),
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              if (people.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No one here yet.',
                      style: TextStyle(color: AppColors.secondaryText)),
                )
              else
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: people.length,
                    separatorBuilder: (_, i) => const Divider(height: 1, indent: 72),
                    itemBuilder: (ctx, i) {
                      final u = people[i];
                      return ListTile(
                        onTap: () {
                          Navigator.pop(ctx);
                          _openUserProfile(u);
                        },
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.lightRed,
                          child: Text(
                            u.name[0].toUpperCase(),
                            style: const TextStyle(
                                color: AppColors.primaryRed,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
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
                        trailing: const Icon(Icons.chevron_right,
                            color: AppColors.secondaryText),
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

  @override
  Widget build(BuildContext context) {
    final subClubs = _subscribedClubs;
    final following = _following;
    final followers = _followers;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.card,
            surfaceTintColor: Colors.transparent,
            foregroundColor: AppColors.text,
            pinned: true,
            title: Text(widget.user.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(followers, following),
                const Divider(height: 1),
                if (userState.isProfilePrivate(widget.user.id) &&
                    !userState.isFollowingUser(widget.user.id))
                  _buildPrivateLock()
                else ...[
                  if (subClubs.isNotEmpty) _buildClubsSection(subClubs),
                ],
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(List<User> followers, List<User> following) {
    final user = widget.user;
    final isFollowingUser = userState.isFollowingUser(user.id);
    final bannerPath = userState.bannerPaths[user.id];
    final mutuals = _mutuals;

    return Container(
      color: AppColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Banner (read-only) ───────────────────────────────────────────
          SizedBox(
            height: 120,
            width: double.infinity,
            child: bannerPath != null
                ? Image.file(File(bannerPath), fit: BoxFit.cover)
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF6A1B9A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
          ),

          // ── Avatar + stats ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppColors.primaryRed, AppColors.accentGold],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Container(
                        width: 76,
                        height: 76,
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle, color: AppColors.card),
                        child: Container(
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle, color: AppColors.lightRed),
                          child: Center(
                            child: Text(
                              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryRed),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          GestureDetector(
                            onTap: () => _showPeopleSheet('Followers', followers),
                            child: _StatCell(
                                value: '${followers.length}', label: 'Followers'),
                          ),
                          GestureDetector(
                            onTap: () => _showPeopleSheet('Following', following),
                            child: _StatCell(
                                value: '${following.length}', label: 'Following'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(user.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.text)),
                const SizedBox(height: 2),
                Text(user.email,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.secondaryText)),

                // ── Mutuals row ────────────────────────────────────────────
                if (mutuals.isNotEmpty && !_isOwnProfile) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _showPeopleSheet('Mutual Friends', mutuals),
                    child: Row(
                      children: [
                        // Stacked avatars (up to 3)
                        SizedBox(
                          width: (mutuals.length.clamp(1, 3) * 18 + 10).toDouble(),
                          height: 22,
                          child: Stack(
                            children: [
                              for (int i = mutuals.length.clamp(1, 3) - 1; i >= 0; i--)
                                Positioned(
                                  left: (i * 18).toDouble(),
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: AppColors.lightRed,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: AppColors.card, width: 1.5),
                                    ),
                                    child: Center(
                                      child: Text(
                                        mutuals[i].name[0].toUpperCase(),
                                        style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryRed),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            mutuals.length == 1
                                ? '${mutuals[0].name.split(' ').first} is a mutual'
                                : '${mutuals[0].name.split(' ').first} and ${mutuals.length - 1} other${mutuals.length > 2 ? 's' : ''} are mutuals',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.secondaryText),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right,
                            size: 16, color: AppColors.secondaryText),
                      ],
                    ),
                  ),
                ],

                if (user.role == 'admin') ...[
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.lightRed,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Club Admin',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryRed,
                            fontWeight: FontWeight.w600)),
                  ),
                ],

                // Follow + Message buttons
                if (!_isOwnProfile) ...[
                  const SizedBox(height: 14),
                  Builder(builder: (_) {
                    final isPending = userState.hasPendingRequest(user.id);
                    final isPrivate = userState.isProfilePrivate(user.id);
                    final String followLabel = isPending
                        ? 'Requested'
                        : isFollowingUser
                            ? 'Following'
                            : isPrivate
                                ? 'Request'
                                : 'Follow';
                    final bool followFilled = !isFollowingUser && !isPending;
                    return Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _handleFollowTap,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: followFilled
                                    ? AppColors.primaryRed
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: followFilled
                                      ? AppColors.primaryRed
                                      : AppColors.secondaryText
                                          .withValues(alpha: 0.5),
                                ),
                              ),
                              child: Text(
                                followLabel,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: followFilled
                                      ? Colors.white
                                      : AppColors.secondaryText,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: _tryOpenChat,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.secondaryText
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              child: const Text(
                                'Message',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivateLock() {
    final isPending = userState.hasPendingRequest(widget.user.id);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.lightRed,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_rounded, size: 36, color: AppColors.primaryRed),
          ),
          const SizedBox(height: 16),
          const Text(
            'This account is private',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text),
          ),
          const SizedBox(height: 8),
          Text(
            isPending
                ? 'Your follow request is pending. Once accepted, you\'ll be able to see their posts.'
                : 'Follow this account to see their posts and clubs.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.secondaryText, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildClubsSection(List<Club> subClubs) {
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Subscribed Clubs',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: subClubs.length,
              separatorBuilder: (ctx, i) => const SizedBox(width: 16),
              itemBuilder: (context, i) {
                final club = subClubs[i];
                final color = _clubColor(club);
                return GestureDetector(
                  onTap: () => _openClub(club),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: color.withValues(alpha: 0.3)),
                        ),
                        child: Center(
                          child: Text(
                            club.name[0],
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: color),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 60,
                        child: Text(
                          club.name.split(' ').first,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppColors.text),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

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
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.text)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
      ],
    );
  }
}
