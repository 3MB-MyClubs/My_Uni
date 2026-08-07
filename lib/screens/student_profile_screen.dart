import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/club.dart';
import '../services/checkin_store.dart';
import '../services/rsvp_store.dart';
import '../services/student_activity_service.dart';
import '../widgets/club_avatar.dart';
import '../widgets/student_activity_section.dart';
import '../widgets/student_campus_profile.dart';
import '../onboarding/widgets/starter_checklist_card.dart';
import 'event_detail_screen.dart';
import 'student_activity_screen.dart';
import 'this_week_screen.dart';

class StudentClubDetail {
  final Club club;
  final int memberCount;
  final String role;

  const StudentClubDetail({
    required this.club,
    required this.memberCount,
    this.role = 'Member',
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

class StudentProfileScreen extends StatelessWidget {
  final VoidCallback onSettings;
  final VoidCallback? onShare;
  final VoidCallback? onFindClubs;

  /// Overrides the default "See all" destination for the events & activities
  /// block. Defaults to this student's full [StudentActivityScreen] history.
  final VoidCallback? onSeeAllEvents;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;
  final List<Club> followedClubs;
  final ValueChanged<Club>? onClubTap;
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
    final memberships = _memberships(context).take(4).toList();

    return StudentCampusProfileView(
      profile: StudentCampusProfile(
        userId: data.userId,
        name: data.name,
        email: data.email,
        major: data.major == 'Major not added' ? '' : data.major,
        year: data.year == 'Year not added' ? '' : data.year,
        bio: data.bio,
        clubs: data.clubs,
        following: data.following,
        followers: data.followers,
        minors: data.minors,
        doubleMajors: data.doubleMajors,
      ),
      title: AppLocalizations.of(context)!.myProfileTitle,
      leading: StudentProfileIconButton(
        icon: Icons.ios_share_outlined,
        tooltip: AppLocalizations.of(context)!.shareProfileTooltip,
        onTap: onShare,
      ),
      trailing: StudentProfileIconButton(
        icon: Icons.settings_outlined,
        tooltip: AppLocalizations.of(context)!.settings,
        onTap: onSettings,
      ),
      supplementalContent: const StarterChecklistCard(),
      activitySection: _buildActivitySection(context),
      memberships: memberships,
      clubsTitle: AppLocalizations.of(context)!.myClubs,
      clubsActionLabel: onFindClubs == null
          ? AppLocalizations.of(context)!.seeAll
          : AppLocalizations.of(context)!.findClubsAction,
      onClubsAction: onFindClubs ?? () => _showFollowedClubsSheet(context),
      onClubTap: onClubTap,
      onClubsTap: () => _showFollowedClubsSheet(context),
      onFollowingTap: onFollowingTap,
      onFollowersTap: onFollowersTap,
    );
  }

  /// The events & activities block. Watches the RSVP and check-in stores
  /// directly so joining or leaving an event updates the profile in place.
  Widget _buildActivitySection(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([rsvpStore, checkinStore]),
      builder: (context, _) {
        final summary = studentActivityService.summaryFor(data.userId);
        return StudentActivityPreview(
          summary: summary,
          isOwnProfile: true,
          studentName: data.name,
          onSeeAll: onSeeAllEvents ?? () => _openActivityHistory(context),
          onEntryTap: (entry) => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  EventDetailScreen(event: entry.event, color: entry.color),
            ),
          ),
          onBrowseEvents: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ThisWeekScreen()),
          ),
        );
      },
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

  List<StudentCampusMembership> _memberships(BuildContext context) {
    if (data.clubDetails.isNotEmpty) {
      return [
        for (var index = 0; index < data.clubDetails.length; index++)
          StudentCampusMembership(
            club: data.clubDetails[index].club,
            color: _clubColors[index % _clubColors.length],
            role: data.clubDetails[index].role,
            detail: AppLocalizations.of(
              context,
            )!.membersCount(data.clubDetails[index].memberCount),
          ),
      ];
    }

    return [
      for (var index = 0; index < followedClubs.length; index++)
        StudentCampusMembership(
          club: followedClubs[index],
          color: _clubColors[index % _clubColors.length],
          role: AppLocalizations.of(context)!.memberRoleLabel,
          detail: AppLocalizations.of(context)!.clubMembershipLabel,
        ),
    ];
  }

  void _showFollowedClubsSheet(BuildContext context) {
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
            color: StudentCampusPalette.deep,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: StudentCampusPalette.borderStrong),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: StudentCampusPalette.borderStrong,
                  borderRadius: const BorderRadius.all(Radius.circular(999)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    AppLocalizations.of(context)!.followedClubsTitle,
                    style: TextStyle(
                      color: StudentCampusPalette.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: followedClubs.isEmpty
                    ? Center(
                        child: Text(
                          AppLocalizations.of(context)!.noFollowedClubsYet,
                          style: TextStyle(
                            color: StudentCampusPalette.secondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                        itemCount: followedClubs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final club = followedClubs[index];
                          final detail = data.clubDetails
                              .cast<StudentClubDetail?>()
                              .firstWhere(
                                (item) => item?.club.id == club.id,
                                orElse: () => null,
                              );
                          return Material(
                            color: StudentCampusPalette.card,
                            shape: RoundedRectangleBorder(
                              borderRadius: const BorderRadius.all(
                                Radius.circular(16),
                              ),
                              side: BorderSide(
                                color: StudentCampusPalette.border,
                              ),
                            ),
                            child: ListTile(
                              onTap: () {
                                Navigator.pop(sheetContext);
                                onClubTap?.call(club);
                              },
                              leading: ClubAvatar(
                                clubId: club.id,
                                clubName: club.name,
                                color: _clubColors[index % _clubColors.length],
                                imageUrl: club.logoUrl,
                                size: 42,
                                fontSize: 17,
                                borderRadius: 13,
                              ),
                              title: Text(
                                club.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: StudentCampusPalette.text,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: detail == null
                                  ? null
                                  : Text(
                                      AppLocalizations.of(
                                        context,
                                      )!.membersCount(detail.memberCount),
                                      style: TextStyle(
                                        color: StudentCampusPalette.secondary,
                                        fontSize: 11,
                                      ),
                                    ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  StudentClubRoleBadge(
                                    role:
                                        detail?.role ??
                                        AppLocalizations.of(
                                          context,
                                        )!.memberRoleLabel,
                                    compact: true,
                                  ),
                                  const SizedBox(width: 5),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: StudentCampusPalette.secondary,
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
}
