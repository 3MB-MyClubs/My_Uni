import 'package:flutter/material.dart';

import '../models/club.dart';
import '../services/tutorial_anchors.dart';
import '../widgets/club_avatar.dart';
import '../widgets/student_campus_profile.dart';

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
  final StudentEventData? nextEvent;
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
    this.nextEvent,
    this.clubDetails = const [],
  });
}

class StudentEventData {
  final String month;
  final String day;
  final String title;
  final String clubLine;
  final String location;

  const StudentEventData({
    required this.month,
    required this.day,
    required this.title,
    required this.clubLine,
    required this.location,
  });
}

class StudentProfileScreen extends StatelessWidget {
  final VoidCallback onSettings;
  final VoidCallback? onShare;
  final VoidCallback? onFindClubs;
  final VoidCallback? onSeeAllEvents;
  final VoidCallback? onEventTap;
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
    this.onEventTap,
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
    final memberships = _memberships.take(4).toList();

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
      title: 'My Profile',
      leading: StudentProfileIconButton(
        icon: Icons.ios_share_outlined,
        tooltip: 'Share profile',
        onTap: onShare,
      ),
      trailing: KeyedSubtree(
        key: tutorialAnchors.keyFor(TutorialAnchors.profileSettings),
        child: StudentProfileIconButton(
          icon: Icons.settings_outlined,
          tooltip: 'Settings',
          onTap: onSettings,
        ),
      ),
      memberships: memberships,
      clubsTitle: 'My Clubs',
      clubsActionLabel: onFindClubs == null ? 'See all' : 'Find clubs',
      onClubsAction: onFindClubs ?? () => _showFollowedClubsSheet(context),
      onClubTap: onClubTap,
      onClubsTap: () => _showFollowedClubsSheet(context),
      onFollowingTap: onFollowingTap,
      onFollowersTap: onFollowersTap,
    );
  }

  List<StudentCampusMembership> get _memberships {
    if (data.clubDetails.isNotEmpty) {
      return [
        for (var index = 0; index < data.clubDetails.length; index++)
          StudentCampusMembership(
            club: data.clubDetails[index].club,
            color: _clubColors[index % _clubColors.length],
            role: data.clubDetails[index].role,
            detail: '${data.clubDetails[index].memberCount} members',
          ),
      ];
    }

    return [
      for (var index = 0; index < followedClubs.length; index++)
        StudentCampusMembership(
          club: followedClubs[index],
          color: _clubColors[index % _clubColors.length],
          role: 'Member',
          detail: 'Club membership',
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
                    'Followed clubs',
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
                          'No followed clubs yet.',
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
                                      '${detail.memberCount} members',
                                      style: TextStyle(
                                        color: StudentCampusPalette.secondary,
                                        fontSize: 11,
                                      ),
                                    ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  StudentClubRoleBadge(
                                    role: detail?.role ?? 'Member',
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
