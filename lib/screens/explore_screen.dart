import 'package:flutter/material.dart';
import '../models/club.dart';
import '../models/user.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/lazy_content_loader.dart';
import '../services/mock_data.dart';
import '../services/people_service.dart';
import '../services/club_follow_helper.dart';
import '../services/user_state.dart';
import '../services/user_prefs_service.dart';
import '../widgets/club_avatar.dart';
import '../widgets/user_avatar.dart';
import 'club_profile_screen.dart';
import 'user_profile_screen.dart';

/// Discover Clubs + Find People.
///
/// Recreated from the Campus Signup Flow design handoff (screens 07 "Find
/// People" and 08 "Discover Clubs"): card rows with a colored monogram, a
/// title, a meta line, interest pills, and a pill toggle button — plus a
/// rounded search field and horizontally-scrolling category chips for clubs.
/// Everything is wired to the app's real follow state and navigation.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Clubs tab state
  final _clubSearchController = TextEditingController();
  String _clubQuery = '';

  // People tab state
  final _peopleSearchController = TextEditingController();
  String _peopleQuery = '';
  String? _peopleFeedback;
  bool _peopleFeedbackIsFollowing = false;
  int _peopleFeedbackVersion = 0;
  List<User> _people = const [];
  bool _peopleLoading = false;
  String? _peopleError;

  // Palette for the colored monograms (mirrors the design's per-item hues).
  static const List<Color> _hues = [
    Color(0xFFB41C18),
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFF6A1B9A),
    Color(0xFFE65100),
    Color(0xFF00838F),
    Color(0xFF512DA8),
    Color(0xFFAD1457),
  ];

  Color _hueFor(int index) => _hues[index.abs() % _hues.length];

  String get _myId =>
      authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

  bool get _canFollowPeople => authService.isStudentSession;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadClubContent();
    _loadPeople();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _clubSearchController.dispose();
    _peopleSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadClubContent() async {
    try {
      await lazyContentLoader.ensureContentLoaded();
      if (mounted) setState(() {});
    } catch (_) {
      // Keep local seed clubs visible if Supabase content is unreachable.
    }
  }

  static String categoryFor(Club club) {
    final category = club.categoryName?.trim();
    if (category != null && category.isNotEmpty) return category;

    final n = club.name.toLowerCase();
    bool has(List<String> keys) => keys.any(n.contains);

    if (has([
      'mühendis',
      'bilgisayar',
      'aiche',
      'kumech',
      'ies',
      'kuswe',
      'kuacm',
    ])) {
      return 'Engineering';
    }
    if (has(['ekonomi', 'girişimcilik', 'işletme', 'pazarlama', 'politik'])) {
      return 'Business';
    }
    if (has(['dağcılık', 'fenerbahçe', 'kartal', 'spor'])) {
      return 'Sports';
    }
    if (has([
      'sanat',
      'dans',
      'ebru',
      'fotoğraf',
      'folklör',
      'müzik',
      'müzikal',
      'orkestra',
      'resim',
      'sinema',
      'tiyatro',
      'radyo',
      'thm',
      'koro',
    ])) {
      return 'Arts';
    }
    if (has([
      'gönüllü',
      'kadın',
      'kuir',
      'kürt',
      'sosyal',
      'düşünce',
      'dayanışma',
    ])) {
      return 'Social';
    }
    // Felsefe, Hukuk, Tarih, Tıp, Hemşirelik, Nöroloji, Münazara, Beşeri,
    // Türk Araştırmaları, Arkeoloji, Atatürkçü … and anything else.
    return 'Academic';
  }

  List<Club> get _filteredClubs {
    final q = _clubQuery.toLowerCase();
    return clubs.where((c) {
      final category = categoryFor(c).toLowerCase();
      final matchesQuery =
          q.isEmpty ||
          c.name.toLowerCase().contains(q) ||
          c.description.toLowerCase().contains(q) ||
          (c.shortName?.toLowerCase().contains(q) ?? false) ||
          (c.email?.toLowerCase().contains(q) ?? false) ||
          category.contains(q);
      return matchesQuery;
    }).toList();
  }

  /// The current user's subscribed club ids (for computing shared interests).
  Set<String> get _mySubscribedClubIds {
    final me = users.cast<User?>().firstWhere(
      (u) => u?.id == _myId,
      orElse: () => null,
    );
    return {...?me?.subscribedClubIds};
  }

  List<String> _sharedClubNames(User other) {
    final mine = _mySubscribedClubIds;
    return other.subscribedClubIds
        .where(mine.contains)
        .map((id) {
          final club = clubs.cast<Club?>().firstWhere(
            (c) => c?.id == id,
            orElse: () => null,
          );
          return club?.name;
        })
        .whereType<String>()
        .toList();
  }

  int _personSearchScore(User person, String query) {
    final name = userState.displayNameFor(person.id, person.name).toLowerCase();
    final words = name.split(RegExp(r'\s+'));
    if (name == query) return 0;
    if (words.any((word) => word == query)) return 1;
    if (name.startsWith(query)) return 2;
    if (words.any((word) => word.startsWith(query))) return 3;
    return 4;
  }

  /// Search by first name, surname, or display name, with strongest matches first.
  List<User> get _filteredPeople {
    final q = _peopleQuery.toLowerCase().trim();
    if (q.isEmpty) return _randomPeoplePreview;

    final matches = _people.where((person) {
      if (person.id == _myId) return false;
      final name = userState
          .displayNameFor(person.id, person.name)
          .toLowerCase();
      final email = person.email.toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();
    matches.sort((a, b) {
      final byRelevance = _personSearchScore(
        a,
        q,
      ).compareTo(_personSearchScore(b, q));
      if (byRelevance != 0) return byRelevance;
      final aName = userState.displayNameFor(a.id, a.name);
      final bName = userState.displayNameFor(b.id, b.name);
      return aName.compareTo(bName);
    });
    return matches;
  }

  List<User> get _randomPeoplePreview {
    final preview = peopleService.randomProfiles(excludeId: _myId);
    final source = preview.isNotEmpty
        ? preview
        : _people.where((person) => person.id != _myId).toList();
    return source.take(10).toList();
  }

  void _persist() => userPrefsService.save(_myId);

  Future<void> _loadPeople() async {
    if (_peopleLoading) return;
    setState(() {
      _peopleLoading = true;
      _peopleError = null;
    });

    try {
      await peopleService.hydrateFollowing(_myId);
      final people = await peopleService.fetchPeople(excludeId: _myId);
      if (!mounted) return;
      setState(() {
        _people = people;
        _peopleLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _people = users.where((user) => user.id != _myId).toList();
        _peopleLoading = false;
        _peopleError = 'Could not load people from profiles.';
      });
    }
  }

  Future<void> _togglePersonFollow(User person) async {
    if (!_canFollowPeople) return;

    final nowFollowing = !userState.isFollowingUser(person.id);
    final feedbackVersion = ++_peopleFeedbackVersion;

    userState.toggleFollowUser(person.id);
    _persist();

    setState(() {
      _peopleFeedbackIsFollowing = nowFollowing;
      _peopleFeedback = nowFollowing
          ? 'You are now following ${person.name}.'
          : 'You unfollowed ${person.name}.';
    });

    try {
      await peopleService.setFollowing(
        followerId: _myId,
        followingId: person.id,
        follow: nowFollowing,
      );
      _persist();
    } catch (_) {
      userState.toggleFollowUser(person.id);
      _persist();
      if (!mounted) return;
      setState(() {
        _peopleFeedbackIsFollowing = !nowFollowing;
        _peopleFeedback = 'Could not update follow. Please try again.';
      });
      return;
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted || feedbackVersion != _peopleFeedbackVersion) return;
      setState(() => _peopleFeedback = null);
    });
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
            Tab(text: 'Discover Clubs'),
            Tab(text: 'Find People'),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: userState,
        builder: (context, _) => TabBarView(
          controller: _tabController,
          children: [_buildClubsTab(), _buildPeopleTab()],
        ),
      ),
    );
  }

  // ─── Shared atoms ────────────────────────────────────────────────────────

  Widget _searchField({
    required TextEditingController controller,
    required String hint,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.divider, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 19, color: AppColors.secondaryText),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: hint,
                hintStyle: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 15,
                ),
              ),
              style: TextStyle(color: AppColors.text, fontSize: 15),
            ),
          ),
          if (value.isNotEmpty)
            GestureDetector(
              onTap: () {
                controller.clear();
                onChanged('');
              },
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: AppColors.secondaryText,
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0.9,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryText,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  /// The Join / Follow style pill toggle used by both card types.
  Widget _togglePill({
    required bool active,
    required String activeLabel,
    required String inactiveLabel,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.lightRed : AppColors.primaryRed,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: active ? AppColors.primaryRed : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          active ? activeLabel : inactiveLabel,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? AppColors.primaryRed : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  Widget _emptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
          ),
        ],
      ),
    );
  }

  // ─── Discover Clubs tab ──────────────────────────────────────────────────

  Widget _buildClubsTab() {
    final filtered = _filteredClubs;
    final filtering = _clubQuery.isNotEmpty;
    final label = filtering
        ? '${filtered.length} club${filtered.length == 1 ? '' : 's'}'
        : 'All clubs';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              _searchField(
                controller: _clubSearchController,
                hint: 'Search clubs…',
                value: _clubQuery,
                onChanged: (v) => setState(() => _clubQuery = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: filtered.isEmpty
              ? _emptyState('No clubs match', 'Try a different search term')
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    MediaQuery.of(context).padding.bottom + 112,
                  ),
                  itemCount: filtered.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) return _sectionLabel(label);
                    final club = filtered[i - 1];
                    return _ClubRow(
                      club: club,
                      category: categoryFor(club),
                      members: clubMemberCount(club.id),
                      color: _hueFor(clubs.indexOf(club)),
                      joined: userState.isFollowing(club.id),
                      onJoin: () => handleFollowTap(context, club.id, () {
                        _persist();
                        setState(() {});
                      }),
                      onOpen: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ClubProfileScreen(
                            club: club,
                            color: _hueFor(clubs.indexOf(club)),
                          ),
                        ),
                      ),
                      pillBuilder: _pill,
                      toggleBuilder: _togglePill,
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ─── Find People tab ─────────────────────────────────────────────────────

  Widget _buildPeopleTab() {
    final searching = _peopleQuery.trim().isNotEmpty;
    final people = _filteredPeople;

    final label = searching
        ? '${people.length} result${people.length == 1 ? '' : 's'}'
        : 'People you might know';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              _searchField(
                controller: _peopleSearchController,
                hint: 'Search by name or surname…',
                value: _peopleQuery,
                onChanged: (v) => setState(() => _peopleQuery = v),
              ),
              if (_peopleLoading || _peopleError != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (_peopleLoading) ...[
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryRed,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        _peopleLoading
                            ? 'Loading people...'
                            : _peopleError ?? '',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SizeTransition(
                        sizeFactor: animation,
                        axisAlignment: -1,
                        child: child,
                      ),
                    );
                  },
                  child: _peopleFeedback == null
                      ? const SizedBox(key: ValueKey('no-follow-feedback'))
                      : Container(
                          key: ValueKey(_peopleFeedback),
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: _peopleFeedbackIsFollowing
                                ? AppColors.lightRed
                                : AppColors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _peopleFeedbackIsFollowing
                                  ? AppColors.primaryRed.withValues(alpha: 0.25)
                                  : AppColors.divider,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _peopleFeedbackIsFollowing
                                    ? Icons.check_circle_rounded
                                    : Icons.person_remove_rounded,
                                size: 18,
                                color: _peopleFeedbackIsFollowing
                                    ? AppColors.primaryRed
                                    : AppColors.secondaryText,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _peopleFeedback!,
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
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              MediaQuery.of(context).padding.bottom + 112,
            ),
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemCount: people.isEmpty ? 2 : people.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return _sectionLabel(label);
              }
              if (people.isEmpty) {
                return SizedBox(
                  height: 340,
                  child: _emptyState(
                    searching
                        ? 'No one matches "$_peopleQuery"'
                        : 'No profiles yet',
                    searching
                        ? 'Try a name, surname, or email'
                        : 'Profiles will appear here after users sign up',
                  ),
                );
              }
              final person = people[i - 1];
              final personIndex = _people.indexWhere(
                (candidate) => candidate.id == person.id,
              );
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 380),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final slide = Tween<Offset>(
                    begin: const Offset(0.08, 0),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: _PersonRow(
                  key: ValueKey(person.id),
                  user: person,
                  subtitle: _personSubtitle(person),
                  sharedTags: _sharedClubNames(person),
                  color: _hueFor(personIndex),
                  canFollow: _canFollowPeople,
                  following: userState.isFollowingUser(person.id),
                  onFollow: () => _togglePersonFollow(person),
                  onOpen: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserProfileScreen(user: person),
                    ),
                  ),
                  pillBuilder: _pill,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _personSubtitle(User u) {
    final major = userState.majors[u.id]?.trim();
    final year = userState.years[u.id]?.trim();
    if (major != null && major.isNotEmpty) {
      return year != null && year.isNotEmpty ? '$major · $year' : major;
    }
    return u.email.isNotEmpty ? u.email : 'Student profile';
  }
}

// ─── Club row ────────────────────────────────────────────────────────────────

class _ClubRow extends StatelessWidget {
  final Club club;
  final String category;
  final int members;
  final Color color;
  final bool joined;
  final VoidCallback onJoin;
  final VoidCallback onOpen;
  final Widget Function(String, Color) pillBuilder;
  final Widget Function({
    required bool active,
    required String activeLabel,
    required String inactiveLabel,
    required VoidCallback onTap,
  })
  toggleBuilder;

  const _ClubRow({
    required this.club,
    required this.category,
    required this.members,
    required this.color,
    required this.joined,
    required this.onJoin,
    required this.onOpen,
    required this.pillBuilder,
    required this.toggleBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$members members · $category',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 7),
                  pillBuilder(category, color),
                ],
              ),
            ),
            const SizedBox(width: 10),
            toggleBuilder(
              active: joined,
              activeLabel: 'Joined ✓',
              inactiveLabel: 'Join',
              onTap: onJoin,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Person row ──────────────────────────────────────────────────────────────

class _PersonRow extends StatefulWidget {
  final User user;
  final String subtitle;
  final List<String> sharedTags;
  final Color color;
  final bool canFollow;
  final bool following;
  final VoidCallback onFollow;
  final VoidCallback onOpen;
  final Widget Function(String, Color) pillBuilder;

  const _PersonRow({
    super.key,
    required this.user,
    required this.subtitle,
    required this.sharedTags,
    required this.color,
    required this.canFollow,
    required this.following,
    required this.onFollow,
    required this.onOpen,
    required this.pillBuilder,
  });

  @override
  State<_PersonRow> createState() => _PersonRowState();
}

class _PersonRowState extends State<_PersonRow> {
  late bool _displayFollowing;
  bool _changing = false;

  @override
  void initState() {
    super.initState();
    _displayFollowing = widget.following;
  }

  @override
  void didUpdateWidget(covariant _PersonRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_changing && oldWidget.following != widget.following) {
      _displayFollowing = widget.following;
    }
  }

  Future<void> _toggleFollow() async {
    if (_changing || !widget.canFollow) return;
    setState(() {
      _changing = true;
      _displayFollowing = !_displayFollowing;
    });
    widget.onFollow();

    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (mounted) {
      setState(() => _changing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onOpen,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _changing && _displayFollowing
                ? AppColors.primaryRed.withValues(alpha: 0.35)
                : AppColors.divider,
          ),
          boxShadow: _changing
              ? [
                  BoxShadow(
                    color: AppColors.primaryRed.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            UserAvatar(
              userId: widget.user.id,
              name: widget.user.name,
              size: 48,
              fontSize: 16,
              backgroundColor: widget.color.withValues(alpha: 0.14),
              textColor: widget.color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    widget.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  if (widget.sharedTags.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: widget.sharedTags
                          .take(2)
                          .map(
                            (t) => widget.pillBuilder(t, AppColors.primaryRed),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (widget.canFollow)
              GestureDetector(
                onTap: _toggleFollow,
                child: AnimatedScale(
                  scale: _changing ? 1.06 : 1,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _displayFollowing
                          ? AppColors.lightRed
                          : AppColors.primaryRed,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: _displayFollowing
                            ? AppColors.primaryRed
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: animation,
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      child: Row(
                        key: ValueKey(_displayFollowing),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _displayFollowing
                                ? Icons.check_rounded
                                : Icons.person_add_alt_1_rounded,
                            size: 15,
                            color: _displayFollowing
                                ? AppColors.primaryRed
                                : Colors.white,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _displayFollowing ? 'Following' : 'Follow',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _displayFollowing
                                  ? AppColors.primaryRed
                                  : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
