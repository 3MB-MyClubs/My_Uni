import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/club.dart';
import '../models/event.dart';
import '../services/app_strings.dart';
import '../services/checkin_store.dart';
import '../services/club_role_localization.dart';
import '../services/mock_data.dart';
import '../services/rsvp_store.dart';
import '../services/student_activity_service.dart';
import '../onboarding/widgets/starter_checklist_card.dart';
import '../widgets/clubup_design.dart';
import '../widgets/profile_design.dart';
import 'event_detail_screen.dart';
import 'student_activity_screen.dart';

class StudentClubDetail {
  final Club club;
  final int memberCount;
  final String role;

  /// The board title this student holds at [club] — "President", "Treasurer",
  /// or the generic "Board Member" fallback — and null when they are only a
  /// follower. [role] carries the same string with "Member" substituted, so
  /// this is what `board-memberships-overlay` filters on.
  final String? boardRole;

  const StudentClubDetail({
    required this.club,
    required this.memberCount,
    this.role = 'Member',
    this.boardRole,
  });
}

class StudentProfileData {
  final String userId;
  final String initials;
  final String name;
  final String email;
  final String graduation;
  final String major;
  final String year;
  final String bio;
  final int clubs;
  final int followers;
  final int following;
  final List<String> minors;
  final List<String> doubleMajors;
  final List<StudentClubDetail> clubDetails;

  const StudentProfileData({
    required this.userId,
    required this.initials,
    required this.name,
    required this.graduation,
    required this.major,
    required this.year,
    required this.bio,
    required this.clubs,
    required this.followers,
    required this.following,
    this.email = '',
    this.minors = const [],
    this.doubleMajors = const [],
    this.clubDetails = const [],
  });
}

/// `profile-screen-light` / `profile-screen-dark` (Figma `59:6` / `59:114`) —
/// the student's own Profile tab.
///
/// Stripped to the frame: the campus ID card, the starter checklist and the
/// events-&-activities history block are gone. Everything the frame shows —
/// the wordmark header, the hero, My Clubs and Upcoming Events — is here, and
/// nothing else. [StudentActivityScreen] is still the "See All" destination
/// for Upcoming Events, so the full history stays reachable.
///
/// The academic fields on [StudentProfileData] (`major`, `year`, `minors`,
/// `doubleMajors`, `graduation`, `initials`) are no longer drawn here: the
/// handoff puts academic info on `profile-edit`, not on the profile. They are
/// kept on the model because `profile_screen.dart` fills them and Edit Profile
/// reads the same state.
class StudentProfileScreen extends StatelessWidget {
  final VoidCallback onSettings;
  final VoidCallback? onShare;
  final VoidCallback? onFindClubs;

  /// Overrides the default "See All" destination for Upcoming Events. Defaults
  /// to this student's full [StudentActivityScreen] history.
  final VoidCallback? onSeeAllEvents;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;
  final List<Club> followedClubs;
  final ValueChanged<Club>? onClubTap;
  final bool clubsLoading;
  final StudentProfileData data;

  const StudentProfileScreen({
    super.key,
    required this.onSettings,
    required this.data,
    this.onShare,
    this.onFindClubs,
    this.onSeeAllEvents,
    this.onFollowersTap,
    this.onFollowingTap,
    this.followedClubs = const [],
    this.onClubTap,
    this.clubsLoading = false,
  });

  static const _clubColors = [
    Color(0xFFC62828),
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFF6A1B9A),
    Color(0xFFE65100),
    Color(0xFF00838F),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final boardMemberships = _boardMemberships;

    return Scaffold(
      backgroundColor: ProfileColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ProfileWordmarkHeader(
              onShare: onShare,
              onSettings: onSettings,
              shareTooltip: l10n.shareProfileTooltip,
              settingsTooltip: l10n.settings,
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(
                  kProfilePagePadding,
                  12,
                  kProfilePagePadding,
                  bottomInset + kProfileNavClearance,
                ),
                children: [
                  ProfileHero(
                    userId: data.userId,
                    name: data.name,
                    handle: '',
                    bio: data.bio,
                    nameBadge: boardMemberships.isEmpty
                        ? null
                        : ProfileRolePill(
                            label: l10n.boardMemberLabel,
                            semanticsLabel: l10n.boardMemberships,
                            onTap: () => _showBoardMembershipsSheet(context),
                          ),
                    stats: [
                      ProfileStat(
                        value: '${data.clubs}',
                        label: l10n.clubs,
                        onTap: () => _showFollowedClubsSheet(context),
                      ),
                      ProfileStat(
                        value: '${data.following}',
                        label: l10n.following,
                        onTap: onFollowingTap,
                      ),
                      ProfileStat(
                        value: '${data.followers}',
                        label: l10n.followers,
                        onTap: onFollowersTap,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Not in the frame, and invisible in every normal session:
                  // [StarterChecklistCard] collapses to nothing unless the
                  // first-login checklist is still active for this student.
                  // Profile is where the onboarding tour hands off to it, so
                  // dropping it outright would strand that flow. It still
                  // paints in `AppColors` — restyling it would touch the
                  // shared onboarding widget.
                  const StarterChecklistCard(),
                  const SizedBox(height: 28),
                  _buildClubsSection(context),
                  const SizedBox(height: 28),
                  _StudentActivityHydrator(
                    userId: data.userId,
                    child: _buildEventsSection(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── my-clubs-section ───────────────────────────────────────────────────────

  Widget _buildClubsSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final entries = _clubEntries(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionHeader(
          title: l10n.myClubs,
          actionLabel: clubsLoading || entries.isEmpty ? null : l10n.seeAll,
          onAction: () => _showFollowedClubsSheet(context),
        ),
        const SizedBox(height: 14),
        if (clubsLoading)
          LinearProgressIndicator(
            key: const ValueKey('profile-clubs-loading'),
            minHeight: 3,
            borderRadius: const BorderRadius.all(Radius.circular(999)),
            color: ProfileColors.accent,
            backgroundColor: ProfileColors.border,
          )
        else if (entries.isEmpty)
          GestureDetector(
            onTap: onFindClubs,
            behavior: HitTestBehavior.opaque,
            child: ProfileSectionEmptyLine(label: S.noClubsYetLine),
          )
        else
          // `clubs-scroller`: the frame's third card is clipped by the page
          // edge, so the row scrolls and keeps that peek.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  ProfileClubCard(
                    club: entries[i].club,
                    color: entries[i].color,
                    detail: entries[i].detail,
                    onTap: onClubTap == null
                        ? null
                        : () => onClubTap!(entries[i].club),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  List<_ProfileClubEntry> _clubEntries(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (data.clubDetails.isNotEmpty) {
      return [
        for (var i = 0; i < data.clubDetails.length; i++)
          _ProfileClubEntry(
            club: data.clubDetails[i].club,
            color: _clubColors[i % _clubColors.length],
            detail: l10n.membersCount(data.clubDetails[i].memberCount),
          ),
      ];
    }
    return [
      for (var i = 0; i < followedClubs.length; i++)
        _ProfileClubEntry(
          club: followedClubs[i],
          color: _clubColors[i % _clubColors.length],
          detail: l10n.membersCount(clubMemberCount(followedClubs[i].id)),
        ),
    ];
  }

  // ── events-section ─────────────────────────────────────────────────────────

  /// `Upcoming Events` — the student's own RSVPs and check-ins that have not
  /// happened yet, straight from [studentActivityService]. Watches the RSVP and
  /// check-in stores so joining or leaving an event updates the list in place.
  Widget _buildEventsSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: Listenable.merge([
        rsvpStore,
        checkinStore,
        studentActivityService,
      ]),
      builder: (context, _) {
        final upcoming = studentActivityService
            .summaryFor(data.userId)
            .upcoming
            .take(4)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProfileSectionHeader(
              title: l10n.upcomingEvents,
              actionLabel: upcoming.isEmpty ? null : l10n.seeAll,
              onAction: onSeeAllEvents ?? () => _openActivityHistory(context),
            ),
            const SizedBox(height: 14),
            if (upcoming.isEmpty)
              ProfileSectionEmptyLine(label: S.noUpcomingEventsLine)
            else
              for (var i = 0; i < upcoming.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                ProfileEventCard(
                  event: upcoming[i].event,
                  color: upcoming[i].color,
                  whenLabel: profileWhenLabel(
                    context,
                    upcoming[i].event.dateTime,
                    live: upcoming[i].isLive,
                  ),
                  clubName: upcoming[i].club?.name,
                  onTap: () =>
                      _openEvent(context, upcoming[i].event, upcoming[i].color),
                ),
              ],
          ],
        );
      },
    );
  }

  void _openEvent(BuildContext context, Event event, Color color) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(event: event, color: color),
      ),
    );
  }

  void _openActivityHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentActivityScreen(
          userId: data.userId,
          studentName: data.name,
          isOwnProfile: true,
        ),
      ),
    );
  }

  // ── "See All" clubs sheet ──────────────────────────────────────────────────

  /// There is no frame for this sheet, so it borrows the area's tokens rather
  /// than the old campus palette — otherwise "See All" opened a differently
  /// themed surface on top of the redesigned page.
  void _showFollowedClubsSheet(BuildContext context) {
    final entries = _clubEntries(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.34,
        maxChildSize: 0.82,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: ProfileColors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: ProfileColors.border)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: ProfileColors.border,
                  borderRadius: const BorderRadius.all(Radius.circular(999)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    AppLocalizations.of(context)!.followedClubsTitle,
                    style: figtree(
                      size: 20,
                      weight: FontWeight.w800,
                      color: ProfileColors.text,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: entries.isEmpty
                    ? Center(
                        child: Text(
                          AppLocalizations.of(context)!.noFollowedClubsYet,
                          style: figtree(
                            size: 14,
                            weight: FontWeight.w600,
                            color: ProfileColors.muted,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                        itemCount: entries.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.pop(sheetContext);
                              onClubTap?.call(entry.club);
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: ProfileColors.card,
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(16),
                                ),
                                border: Border.all(color: ProfileColors.border),
                              ),
                              child: Row(
                                children: [
                                  ProfileClubCover(
                                    club: entry.club,
                                    color: entry.color,
                                    width: 46,
                                    height: 46,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          entry.club.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: figtree(
                                            size: 14,
                                            weight: FontWeight.w700,
                                            color: ProfileColors.text,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          entry.detail,
                                          style: figtree(
                                            size: 11,
                                            weight: FontWeight.w400,
                                            color: ProfileColors.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: ProfileColors.muted,
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

  // ── board-memberships ──────────────────────────────────────────────────────

  /// Every club where this student sits on the board. Ordering follows
  /// [StudentProfileData.clubDetails], which `orderedProfileClubs` has already
  /// sorted role clubs to the front of.
  List<StudentClubDetail> get _boardMemberships => [
    for (final detail in data.clubDetails)
      if (detail.boardRole != null) detail,
  ];

  /// The overlay behind the `board-badge`: one row per board seat, with the
  /// club's cover, its member count and the student's title on the right.
  void _showBoardMembershipsSheet(BuildContext context) {
    final memberships = _boardMemberships;
    if (memberships.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.42,
        minChildSize: 0.3,
        maxChildSize: 0.82,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: ProfileColors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: ProfileColors.border)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: ProfileColors.border,
                  borderRadius: const BorderRadius.all(Radius.circular(999)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    AppLocalizations.of(context)!.boardMemberships,
                    style: figtree(
                      size: 20,
                      weight: FontWeight.w800,
                      color: ProfileColors.text,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  itemCount: memberships.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final membership = memberships[index];
                    final l10n = AppLocalizations.of(context)!;
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(sheetContext);
                        onClubTap?.call(membership.club);
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: ProfileColors.card,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(16),
                          ),
                          border: Border.all(color: ProfileColors.border),
                        ),
                        child: Row(
                          children: [
                            ProfileClubCover(
                              club: membership.club,
                              color: _clubColorFor(membership.club),
                              width: 46,
                              height: 46,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    membership.club.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: figtree(
                                      size: 14,
                                      weight: FontWeight.w700,
                                      color: ProfileColors.text,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    l10n.membersCount(membership.memberCount),
                                    style: figtree(
                                      size: 11,
                                      weight: FontWeight.w400,
                                      color: ProfileColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            ProfileRolePill(
                              label: localizedClubRole(
                                l10n,
                                membership.boardRole,
                              ),
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

  /// The cover tint a club carries in `my-clubs-section`, so a club keeps the
  /// same colour in both overlays.
  Color _clubColorFor(Club club) {
    final index = data.clubDetails.indexWhere(
      (detail) => detail.club.id == club.id,
    );
    return _clubColors[(index < 0 ? 0 : index) % _clubColors.length];
  }
}

class _ProfileClubEntry {
  final Club club;
  final Color color;
  final String detail;

  const _ProfileClubEntry({
    required this.club,
    required this.color,
    required this.detail,
  });
}

class _StudentActivityHydrator extends StatefulWidget {
  final String userId;
  final Widget child;

  const _StudentActivityHydrator({required this.userId, required this.child});

  @override
  State<_StudentActivityHydrator> createState() =>
      _StudentActivityHydratorState();
}

class _StudentActivityHydratorState extends State<_StudentActivityHydrator> {
  @override
  void initState() {
    super.initState();
    studentActivityService.hydrateForUser(widget.userId);
  }

  @override
  void didUpdateWidget(covariant _StudentActivityHydrator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      studentActivityService.hydrateForUser(widget.userId);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
