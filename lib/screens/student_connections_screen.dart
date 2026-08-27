import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/club.dart';
import '../models/user.dart';
import '../services/user_state.dart';
import '../widgets/club_avatar.dart';
import '../widgets/club_profile_design.dart';
import '../widgets/chats_design.dart';
import '../widgets/profile_design.dart' show profileHandle;
import '../widgets/user_avatar.dart';

enum StudentConnectionSection { clubs, followers, following }

/// Searchable student connections directory styled after Board Members.
///
/// Tapping a profile stat chooses the initial section, while the segmented
/// control lets the user move between Clubs, Followers, and Following without
/// leaving the screen. The search field and its query stay in place and filter
/// whichever section is currently selected.
class StudentConnectionsScreen extends StatefulWidget {
  const StudentConnectionsScreen({
    super.key,
    required this.initialSection,
    required this.clubs,
    required this.followers,
    required this.following,
    required this.clubColorFor,
    required this.clubSubtitleFor,
    required this.onOpenUser,
    this.onOpenClub,
    this.clubsLoading = false,
    this.peopleLoading = false,
    this.clubsError,
    this.peopleError,
  });

  final StudentConnectionSection initialSection;
  final List<Club> clubs;
  final List<User> followers;
  final List<User> following;
  final Color Function(Club club) clubColorFor;
  final String Function(Club club) clubSubtitleFor;
  final ValueChanged<Club>? onOpenClub;
  final ValueChanged<User> onOpenUser;
  final bool clubsLoading;
  final bool peopleLoading;
  final String? clubsError;
  final String? peopleError;

  @override
  State<StudentConnectionsScreen> createState() =>
      _StudentConnectionsScreenState();
}

class _StudentConnectionsScreenState extends State<StudentConnectionsScreen> {
  final TextEditingController _search = TextEditingController();
  late StudentConnectionSection _section = widget.initialSection;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Club> get _shownClubs {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.clubs;
    return widget.clubs.where((club) {
      return club.name.toLowerCase().contains(query) ||
          widget.clubSubtitleFor(club).toLowerCase().contains(query);
    }).toList();
  }

  List<User> _shownPeople(List<User> people) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return people;
    return people.where((person) {
      final displayName = userState.displayNameFor(person.id, person.name);
      final username = userState.usernameFor(person.id) ?? '';
      return displayName.toLowerCase().contains(query) ||
          person.name.toLowerCase().contains(query) ||
          username.toLowerCase().contains(query) ||
          person.email.toLowerCase().contains(query);
    }).toList();
  }

  String _personSubtitle(User person) {
    final username = userState.usernameFor(person.id)?.trim() ?? '';
    if (username.isNotEmpty) return person.name;
    return profileHandle(person.email);
  }

  int get _sectionIndex => StudentConnectionSection.values.indexOf(_section);

  String _sectionTitle(AppLocalizations l10n) => switch (_section) {
    StudentConnectionSection.clubs => l10n.clubs,
    StudentConnectionSection.followers => l10n.followers,
    StudentConnectionSection.following => l10n.following,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final searching = _query.trim().isNotEmpty;
    final clubs = _shownClubs;
    final people = _section == StudentConnectionSection.followers
        ? _shownPeople(widget.followers)
        : _shownPeople(widget.following);
    final showingClubs = _section == StudentConnectionSection.clubs;
    final itemCount = showingClubs ? clubs.length : people.length;
    final loading =
        !searching &&
        (showingClubs ? widget.clubsLoading : widget.peopleLoading);
    final error = searching
        ? null
        : showingClubs
        ? widget.clubsError
        : widget.peopleError;
    final emptyText = searching
        ? showingClubs
              ? l10n.noClubsFound
              : l10n.noMatchesFoundDot
        : switch (_section) {
            StudentConnectionSection.clubs => l10n.noFollowedClubsYet,
            StudentConnectionSection.followers => l10n.noFollowersYet,
            StudentConnectionSection.following => l10n.notFollowingAnyone,
          };

    return Scaffold(
      key: const ValueKey('student-connections-screen'),
      backgroundColor: ClubProfileColors.page,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClubProfileHeaderBar(
              title: _sectionTitle(l10n),
              compact: true,
              onBack: () => Navigator.maybePop(context),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
              child: ClubProfileSegmentedTabs(
                labels: [l10n.clubs, l10n.followers, l10n.following],
                index: _sectionIndex,
                keyPrefix: 'student-connections-tab',
                compact: true,
                onChanged: (index) => setState(
                  () => _section = StudentConnectionSection.values[index],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 12),
              child: ClubProfileCard(
                radius: 12,
                child: SizedBox(
                  height: 34,
                  child: ClubProfileSearchField(
                    key: const ValueKey('student-connections-search'),
                    controller: _search,
                    hint: l10n.search,
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
              ),
            ),
            Expanded(
              child: itemCount == 0 && loading
                  ? Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: ClubProfileColors.accent,
                      ),
                    )
                  : itemCount == 0
                  ? ListView(
                      children: [
                        ClubProfileEmptyState(
                          icon: showingClubs
                              ? Icons.groups_2_outlined
                              : Icons.person_search_outlined,
                          title: error ?? emptyText,
                        ),
                      ],
                    )
                  : ListView.separated(
                      key: ValueKey('student-connections-results-$_section'),
                      padding: const EdgeInsets.only(bottom: 28),
                      itemCount: itemCount,
                      separatorBuilder: (_, _) => const SizedBox.shrink(),
                      itemBuilder: (context, index) => showingClubs
                          ? _clubRow(clubs[index])
                          : _personRow(people[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _clubRow(Club club) => _chatStyleRow(
    rowKey: ValueKey('student-club-result-${club.id}'),
    height: 64,
    avatar: ClubAvatar(
      clubId: club.id,
      clubName: club.name,
      color: widget.clubColorFor(club),
      imageUrl: club.logoUrl,
      size: 44,
      fontSize: 17,
      shape: 'circle',
    ),
    title: club.name,
    subtitle: widget.clubSubtitleFor(club),
    showChevron: widget.onOpenClub != null,
    onTap: widget.onOpenClub == null ? null : () => widget.onOpenClub!(club),
  );

  Widget _personRow(User person) => _chatStyleRow(
    rowKey: ValueKey('student-person-result-${person.id}'),
    height: 72,
    avatar: UserAvatar(
      userId: person.id,
      name: person.name,
      size: 44,
      fontSize: 17,
    ),
    title: userState.displayNameFor(person.id, person.name),
    subtitle: _personSubtitle(person),
    showChevron: true,
    onTap: () => widget.onOpenUser(person),
  );

  Widget _chatStyleRow({
    required Key rowKey,
    required double height,
    required Widget avatar,
    required String title,
    required String subtitle,
    required bool showChevron,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: rowKey,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: ChatsColors.border)),
          ),
          child: SizedBox(
            height: height,
            child: Row(
              children: [
                const SizedBox(width: 20),
                SizedBox(width: 44, height: 44, child: avatar),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: figtree(
                          size: 14,
                          weight: FontWeight.w600,
                          color: ChatsColors.text,
                          letterSpacing: -0.1,
                        ),
                      ),
                      if (subtitle.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: figtree(
                            size: 13,
                            weight: FontWeight.w400,
                            color: ChatsColors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (showChevron) ...[
                  const SizedBox(width: 12),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: ChatsColors.muted,
                  ),
                ],
                const SizedBox(width: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
