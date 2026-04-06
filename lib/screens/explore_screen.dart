import 'package:flutter/material.dart';
import '../models/club.dart';
import '../models/user.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/mock_data.dart';
import '../services/user_state.dart';
import '../services/club_follow_helper.dart';
import '../widgets/user_avatar.dart';
import 'chat_screen.dart';
import 'club_profile_screen.dart';
import 'user_profile_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Clubs tab
  final _clubSearchController = TextEditingController();
  String _clubQuery = '';
  String _selectedCategory = 'All';

  // People tab
  final _peopleSearchController = TextEditingController();
  String _peopleQuery = '';

  static const _categories = ['All', 'Tech', 'Arts', 'Music', 'Sports', 'Academic'];

  static const Map<String, String> _clubCategory = {
    'c1': 'Tech',
    'c2': 'Arts',
    'c3': 'Arts',
    'c4': 'Music',
    'c5': 'Academic',
    'c6': 'Academic',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _clubSearchController.dispose();
    _peopleSearchController.dispose();
    super.dispose();
  }

  List<Club> get _filteredClubs {
    return clubs.where((c) {
      final matchesQuery = _clubQuery.isEmpty ||
          c.name.toLowerCase().contains(_clubQuery.toLowerCase()) ||
          c.description.toLowerCase().contains(_clubQuery.toLowerCase());
      final matchesCategory =
          _selectedCategory == 'All' || (_clubCategory[c.id] == _selectedCategory);
      return matchesQuery && matchesCategory;
    }).toList();
  }

  List<User> get _filteredPeople {
    if (_peopleQuery.isEmpty) return [];
    final myId =
        authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
    return users.where((u) {
      if (u.id == myId) return false;
      return u.name.toLowerCase().contains(_peopleQuery.toLowerCase()) ||
          u.email.toLowerCase().contains(_peopleQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Explore',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryRed,
          unselectedLabelColor: AppColors.secondaryText,
          indicatorColor: AppColors.primaryRed,
          tabs: const [
            Tab(text: 'Clubs'),
            Tab(text: 'People'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildClubsTab(),
          _buildPeopleTab(),
        ],
      ),
    );
  }

  // ─── Clubs Tab ───────────────────────────────────────────────────────────────

  Widget _buildClubsTab() {
    return CustomScrollView(
      slivers: [
        _buildClubSearchBar(),
        _buildCategories(),
        _buildClubsGrid(),
        _buildUpcomingEventsHeader(),
        _buildEventsList(),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  SliverToBoxAdapter _buildClubSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: TextField(
          controller: _clubSearchController,
          onChanged: (v) => setState(() => _clubQuery = v),
          decoration: InputDecoration(
            hintText: 'Search clubs...',
            prefixIcon: const Icon(Icons.search, color: AppColors.secondaryText),
            suffixIcon: _clubQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      _clubSearchController.clear();
                      setState(() => _clubQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: AppColors.lightGray,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildCategories() {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: _categories.length,
          separatorBuilder: (context, i) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final cat = _categories[i];
            final selected = cat == _selectedCategory;
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primaryRed : AppColors.lightGray,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  cat,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.text,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  SliverPadding _buildClubsGrid() {
    final filtered = _filteredClubs;
    if (filtered.isEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.all(32),
        sliver: const SliverToBoxAdapter(
          child: Center(
            child: Text(
              'No clubs found',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 16),
            ),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, i) => _ClubCard(club: filtered[i]),
          childCount: filtered.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildUpcomingEventsHeader() {
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text(
          'Upcoming Events',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text),
        ),
      ),
    );
  }

  SliverList _buildEventsList() {
    final upcoming = events
        .where((e) => e.dateTime.isAfter(DateTime.now()))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) => _EventCard(event: upcoming[i]),
        childCount: upcoming.length,
      ),
    );
  }

  // ─── People Tab ──────────────────────────────────────────────────────────────

  Widget _buildPeopleTab() {
    final people = _filteredPeople;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _peopleSearchController,
            onChanged: (v) => setState(() => _peopleQuery = v),
            decoration: InputDecoration(
              hintText: 'Search people...',
              prefixIcon:
                  const Icon(Icons.person_search, color: AppColors.secondaryText),
              suffixIcon: _peopleQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _peopleSearchController.clear();
                        setState(() => _peopleQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.lightGray,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: people.isEmpty
              ? Center(
                  child: Text(
                    _peopleQuery.isEmpty ? 'Type a name to search people' : 'No people found',
                    style: const TextStyle(color: AppColors.secondaryText),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: people.length,
                  separatorBuilder: (context, i) =>
                      const Divider(height: 1, indent: 72),
                  itemBuilder: (context, i) =>
                      _PeopleCard(user: people[i], onStateChanged: () => setState(() {})),
                ),
        ),
      ],
    );
  }
}

// ─── Club Card ───────────────────────────────────────────────────────────────

class _ClubCard extends StatefulWidget {
  final Club club;
  const _ClubCard({required this.club});

  @override
  State<_ClubCard> createState() => _ClubCardState();
}

class _ClubCardState extends State<_ClubCard> {
  static const List<Color> _avatarColors = [
    Color(0xFFB41C18),
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFF6A1B9A),
    Color(0xFFE65100),
    Color(0xFF00838F),
  ];

  Color get _color {
    final idx = clubs.indexOf(widget.club) % _avatarColors.length;
    return _avatarColors[idx];
  }

  @override
  Widget build(BuildContext context) {
    final following = userState.isFollowing(widget.club.id);
    final members = clubMemberCount(widget.club.id);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClubProfileScreen(club: widget.club, color: _color),
        ),
      ),
      child: Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  widget.club.name[0],
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _color,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.club.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '$members members',
              style:
                  const TextStyle(fontSize: 12, color: AppColors.secondaryText),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                widget.club.description,
                style:
                    const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () =>
                    handleFollowTap(context, widget.club.id, () => setState(() {})),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: following ? Colors.transparent : AppColors.primaryRed,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: following
                          ? AppColors.secondaryText
                          : AppColors.primaryRed,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      following ? 'Following' : 'Follow',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: following ? AppColors.secondaryText : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// ─── People Card ─────────────────────────────────────────────────────────────

class _PeopleCard extends StatelessWidget {
  final User user;
  final VoidCallback onStateChanged;

  const _PeopleCard({required this.user, required this.onStateChanged});

  static const List<Color> _colors = [
    Color(0xFFB41C18),
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFF6A1B9A),
    Color(0xFFE65100),
    Color(0xFF00838F),
  ];

  Color get _color {
    final idx = users.indexOf(user) % _colors.length;
    return _colors[idx];
  }

  @override
  Widget build(BuildContext context) {
    final following = userState.isFollowingUser(user.id);
    final isClubAdmin = user.role == 'admin';

    return ListTile(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => UserProfileScreen(user: user)),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: UserAvatar(
        userId: user.id,
        name: user.name,
        size: 48,
        fontSize: 18,
        backgroundColor: _color.withValues(alpha: 0.15),
        textColor: _color,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              user.name,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isClubAdmin) ...[
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.lightRed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Club Admin',
                style: TextStyle(
                    fontSize: 10,
                    color: AppColors.primaryRed,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        user.email,
        style:
            const TextStyle(fontSize: 12, color: AppColors.secondaryText),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (following)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      otherUserId: user.id,
                      otherUserName: user.name,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: AppColors.lightRed,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.chat_bubble_outline,
                    size: 16, color: AppColors.primaryRed),
              ),
            ),
          GestureDetector(
            onTap: () {
              userState.toggleFollowUser(user.id);
              onStateChanged();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color:
                    following ? Colors.transparent : AppColors.primaryRed,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: following
                      ? AppColors.secondaryText
                      : AppColors.primaryRed,
                ),
              ),
              child: Text(
                following ? 'Following' : 'Follow',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: following ? AppColors.secondaryText : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Event Card ──────────────────────────────────────────────────────────────

class _EventCard extends StatefulWidget {
  final dynamic event;
  const _EventCard({required this.event});

  @override
  State<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<_EventCard> {
  bool _attending = false;

  @override
  Widget build(BuildContext context) {
    final club = clubs.firstWhere((c) => c.id == widget.event.clubId);
    final dt = widget.event.dateTime as DateTime;
    final daysAway = dt.difference(DateTime.now()).inDays;
    final daysLabel = daysAway == 0
        ? 'Today'
        : daysAway == 1
            ? 'Tomorrow'
            : 'In $daysAway days';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
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
                Text(
                  '${dt.day}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryRed,
                    height: 1,
                  ),
                ),
                Text(
                  _monthAbbr(dt.month),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.primaryRed),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.event.title as String,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  club.name,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.secondaryText),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.schedule,
                        size: 12, color: AppColors.primaryRed),
                    const SizedBox(width: 3),
                    Text(
                      daysLabel,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryRed,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.people_outline,
                        size: 12, color: AppColors.secondaryText),
                    const SizedBox(width: 3),
                    Text(
                      '${(widget.event.attendeeUserIds as List).length} attending',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.secondaryText),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _attending = !_attending),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _attending ? AppColors.primaryRed : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primaryRed),
              ),
              child: Text(
                _attending ? 'Going' : 'Join',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _attending ? Colors.white : AppColors.primaryRed,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _monthAbbr(int month) {
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    return months[month - 1];
  }
}
