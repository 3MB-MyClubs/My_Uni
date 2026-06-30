import 'package:flutter/material.dart';
import '../models/club.dart';
import '../services/app_colors.dart';
import '../services/tutorial_anchors.dart';
import '../widgets/club_avatar.dart';
import '../widgets/user_avatar.dart';

// ─── Data classes ──────────────────────────────────────────────────────────────

/// Detail entry for a single club shown in the Clubs card.
class StudentClubDetail {
  final Club club;
  final int memberCount;
  final String role; // 'Member' | 'Board'

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
  final String graduation;
  final String major;
  final String year;
  final String bio;
  final int clubs;
  final int followers;
  final int following;
  final List<String> vibes;
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
    required this.vibes,
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

// ─── Main screen ───────────────────────────────────────────────────────────────

class StudentProfileScreen extends StatelessWidget {
  final VoidCallback onSettings;
  final VoidCallback? onShare;
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
    this.onSeeAllEvents,
    this.onEventTap,
    this.onFollowersTap,
    this.onFollowingTap,
    this.followedClubs = const [],
    this.onClubTap,
  });

  // ─── Design tokens ──────────────────────────────────────────────────────────
  static const Color _burgundy = Color(0xFF8D1F2D);
  static const Color _burgundyDeep = Color(0xFF5A0D1B);
  static Color get _burgundyTint => AppColors.lightRed;
  static Color get _background => AppColors.background;
  static Color get _card => AppColors.card;
  static Color get _text => AppColors.text;
  static Color get _body => AppColors.text;
  static Color get _secondary => AppColors.secondaryText;
  static Color get _hair => AppColors.divider;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // ── Clean identity header (no banner) ───────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top toolbar: share · graduation · settings
                    Row(
                      children: [
                        if (onShare != null)
                          _HeaderIconButton(
                            icon: Icons.ios_share_outlined,
                            onTap: onShare,
                          )
                        else
                          const SizedBox(width: 40),
                        Expanded(
                          child: Text(
                            data.graduation,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.4,
                              fontWeight: FontWeight.w700,
                              color: StudentProfileScreen._burgundy,
                            ),
                          ),
                        ),
                        KeyedSubtree(
                          key: tutorialAnchors.keyFor(
                            TutorialAnchors.profileSettings,
                          ),
                          child: _HeaderIconButton(
                            icon: Icons.settings_outlined,
                            onTap: onSettings,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    // Avatar row
                    KeyedSubtree(
                      key: tutorialAnchors.keyFor(
                        TutorialAnchors.profileHeader,
                      ),
                      child: _AvatarRow(
                        userId: data.userId,
                        name: data.name,
                        initials: data.initials,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Name + major + year + double major / minor tags
                    _NameMajorBlock(data: data),
                  ],
                ),
              ),
            ),

            // ── Stats bar ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: StatsCard(
                  clubs: data.clubs,
                  followers: data.followers,
                  following: data.following,
                  onClubsTap: () => _showFollowedClubsSheet(context),
                  onFollowersTap: onFollowersTap,
                  onFollowingTap: onFollowingTap,
                ),
              ),
            ),

            // ── About card ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: _AboutCard(bio: data.bio),
              ),
            ),

            // ── Interests card ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: _InterestsCard(vibes: data.vibes),
              ),
            ),

            // ── Clubs card ──────────────────────────────────────────────────
            if (data.clubDetails.isNotEmpty || followedClubs.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: _ClubsCard(
                    details: data.clubDetails,
                    fallbackClubs: followedClubs,
                    onClubTap: onClubTap,
                    onSeeAll: () => _showFollowedClubsSheet(context),
                  ),
                ),
              ),

            // ── Up next event ───────────────────────────────────────────────
            if (data.nextEvent != null) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 28, 22, 0),
                  child: _UpNextHeader(onSeeAll: onSeeAllEvents),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                  child: EventCard(event: data.nextEvent!, onTap: onEventTap),
                ),
              ),
            ],

            SliverToBoxAdapter(child: SizedBox(height: bottom + 48)),
          ],
        ),
      ),
    );
  }

  // ─── Clubs sheet ─────────────────────────────────────────────────────────────

  void _showFollowedClubsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.48,
        minChildSize: 0.34,
        maxChildSize: 0.78,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: _background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: _secondary.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
                child: Row(
                  children: [
                    Text(
                      'Followed clubs',
                      style: TextStyle(
                        color: _text,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: _burgundy,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${followedClubs.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: followedClubs.isEmpty
                    ? Center(
                        child: Text(
                          'No followed clubs yet.',
                          style: TextStyle(
                            color: _secondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                        itemCount: followedClubs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final club = followedClubs[index];
                          return _ScaleTap(
                            onTap: () {
                              Navigator.pop(sheetContext);
                              onClubTap?.call(club);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _card,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _hair),
                              ),
                              child: Row(
                                children: [
                                  ClubAvatar(
                                    clubId: club.id,
                                    clubName: club.name,
                                    color: _burgundy,
                                    size: 46,
                                    fontSize: 18,
                                    borderRadius: 15,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      club.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: _text,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: _secondary,
                                    size: 22,
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

// ─── Header icon button (share / settings) ────────────────────────────────────

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _HeaderIconButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return _ScaleTap(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: StudentProfileScreen._card,
          shape: BoxShape.circle,
          border: Border.all(color: StudentProfileScreen._hair),
        ),
        child: Icon(icon, size: 19, color: StudentProfileScreen._burgundy),
      ),
    );
  }
}

// ─── Avatar row ───────────────────────────────────────────────────────────────

class _AvatarRow extends StatelessWidget {
  final String userId;
  final String name;
  final String initials;

  const _AvatarRow({
    required this.userId,
    required this.name,
    required this.initials,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Avatar: white-padded rounded rectangle with gradient fill
        Container(
          width: 92,
          height: 92,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: StudentProfileScreen._card,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? 0.42
                      : 0.22,
                ),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(26)),
            child: UserAvatar(
              userId: userId,
              name: name.isEmpty ? initials : name,
              size: 84,
              fontSize: 32,
              borderRadius: BorderRadius.circular(26),
              backgroundColor: const Color(0xFFE8CFD2),
              textColor: StudentProfileScreen._burgundyDeep,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Name + major + year block ────────────────────────────────────────────────

class _NameMajorBlock extends StatelessWidget {
  final StudentProfileData data;

  const _NameMajorBlock({required this.data});

  @override
  Widget build(BuildContext context) {
    final hasMajor = data.major.isNotEmpty && data.major != 'Major not added';
    final hasYear = data.year.isNotEmpty && data.year != 'Year not added';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name
        Text(
          data.name,
          style: TextStyle(
            color: StudentProfileScreen._text,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            height: 1.1,
          ),
        ),
        if (hasMajor || hasYear) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              if (hasMajor) ...[
                Flexible(
                  child: Text(
                    data.major,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: StudentProfileScreen._body,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
              ],
              if (hasMajor && hasYear) ...[
                Container(
                  width: 3,
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: StudentProfileScreen._secondary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
              if (hasYear)
                Text(
                  data.year,
                  style: TextStyle(
                    color: StudentProfileScreen._body,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.1,
                  ),
                ),
            ],
          ),
        ],
        if (data.doubleMajors.isNotEmpty || data.minors.isNotEmpty) ...[
          const SizedBox(height: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final dm in data.doubleMajors)
                _AcademicLine(label: 'Double major', value: dm),
              for (final mn in data.minors)
                _AcademicLine(label: 'Minor', value: mn),
            ],
          ),
        ],
      ],
    );
  }
}

class _AcademicLine extends StatelessWidget {
  final String label;
  final String value;
  const _AcademicLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$label: '),
            TextSpan(text: value),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: StudentProfileScreen._body,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

// ─── Stats card ───────────────────────────────────────────────────────────────

class StatsCard extends StatelessWidget {
  final int clubs;
  final int followers;
  final int following;
  final VoidCallback? onClubsTap;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;

  const StatsCard({
    super.key,
    required this.clubs,
    required this.followers,
    required this.following,
    this.onClubsTap,
    this.onFollowersTap,
    this.onFollowingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: StudentProfileScreen._card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: StudentProfileScreen._hair, width: 1),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _StatCell(value: clubs, label: 'Clubs', onTap: onClubsTap),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: StudentProfileScreen._hair,
            ),
            Expanded(
              child: _StatCell(
                value: following,
                label: 'Following',
                onTap: onFollowingTap,
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: StudentProfileScreen._hair,
            ),
            Expanded(
              child: _StatCell(
                value: followers,
                label: 'Followers',
                onTap: onFollowersTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final int value;
  final String label;
  final VoidCallback? onTap;

  const _StatCell({required this.value, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return _ScaleTap(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$value',
              style: TextStyle(
                color: StudentProfileScreen._text,
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: StudentProfileScreen._secondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── About card ───────────────────────────────────────────────────────────────

class _AboutCard extends StatelessWidget {
  final String bio;

  const _AboutCard({required this.bio});

  @override
  Widget build(BuildContext context) {
    final hasBio = bio.isNotEmpty && bio != 'Add a bio to introduce yourself.';
    return _ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardLabel(title: 'About'),
          const SizedBox(height: 10),
          if (hasBio)
            Text(
              bio,
              style: TextStyle(
                color: StudentProfileScreen._body,
                fontSize: 14.5,
                height: 1.5,
                letterSpacing: -0.1,
              ),
            )
          else
            Text(
              'No bio yet. Go to Settings to add one.',
              style: TextStyle(
                color: StudentProfileScreen._secondary,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Interests card ───────────────────────────────────────────────────────────

class _InterestsCard extends StatelessWidget {
  final List<String> vibes;

  const _InterestsCard({required this.vibes});

  @override
  Widget build(BuildContext context) {
    return _ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardLabel(title: 'Interests'),
          const SizedBox(height: 12),
          if (vibes.isEmpty)
            Text(
              'Go to Settings to add interests.',
              style: TextStyle(
                color: StudentProfileScreen._secondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: vibes.map((v) => InterestTag(label: v)).toList(),
            ),
        ],
      ),
    );
  }
}

// ─── Clubs card ───────────────────────────────────────────────────────────────

class _ClubsCard extends StatelessWidget {
  final List<StudentClubDetail> details;
  final List<Club> fallbackClubs;
  final ValueChanged<Club>? onClubTap;
  final VoidCallback? onSeeAll;

  const _ClubsCard({
    required this.details,
    required this.fallbackClubs,
    this.onClubTap,
    this.onSeeAll,
  });

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

  Color _colorFor(int index) => _hues[index % _hues.length];

  @override
  Widget build(BuildContext context) {
    // Use clubDetails if populated, otherwise fall back to raw club list.
    final hasDetails = details.isNotEmpty;
    final count = hasDetails ? details.length : fallbackClubs.length;
    final showSeeAll = count > 4;
    final displayCount = showSeeAll ? 4 : count;

    return _ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardLabel(
            title: 'Clubs · $count',
            trailing: showSeeAll
                ? GestureDetector(
                    onTap: onSeeAll,
                    child: const Text(
                      'See all',
                      style: TextStyle(
                        color: StudentProfileScreen._burgundy,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 4),
          for (int i = 0; i < displayCount; i++)
            hasDetails
                ? _ClubRow(
                    detail: details[i],
                    color: _colorFor(i),
                    isLast: i == displayCount - 1,
                    onTap: () => onClubTap?.call(details[i].club),
                  )
                : _ClubRowFallback(
                    club: fallbackClubs[i],
                    color: _colorFor(i),
                    isLast: i == displayCount - 1,
                    onTap: () => onClubTap?.call(fallbackClubs[i]),
                  ),
        ],
      ),
    );
  }
}

class _ClubRow extends StatelessWidget {
  final StudentClubDetail detail;
  final Color color;
  final bool isLast;
  final VoidCallback onTap;

  const _ClubRow({
    required this.detail,
    required this.color,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLeader = detail.role != 'Member';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    color: StudentProfileScreen._hair,
                    width: 1,
                  ),
                ),
        ),
        child: Row(
          children: [
            // Club avatar (uploaded photo or monogram fallback)
            ClubAvatar(
              clubId: detail.club.id,
              clubName: detail.club.name,
              color: color,
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
                    detail.club.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: StudentProfileScreen._text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${detail.memberCount} members',
                    style: TextStyle(
                      color: StudentProfileScreen._secondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Role badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: isLeader
                    ? StudentProfileScreen._burgundy
                    : StudentProfileScreen._background,
                borderRadius: BorderRadius.circular(100),
                border: isLeader
                    ? null
                    : Border.all(color: StudentProfileScreen._hair),
              ),
              child: Text(
                detail.role,
                style: TextStyle(
                  color: isLeader ? Colors.white : StudentProfileScreen._body,
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
}

class _ClubRowFallback extends StatelessWidget {
  final Club club;
  final Color color;
  final bool isLast;
  final VoidCallback onTap;

  const _ClubRowFallback({
    required this.club,
    required this.color,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    color: StudentProfileScreen._hair,
                    width: 1,
                  ),
                ),
        ),
        child: Row(
          children: [
            ClubAvatar(
              clubId: club.id,
              clubName: club.name,
              color: color,
              size: 42,
              fontSize: 18,
              borderRadius: 13,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                club.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: StudentProfileScreen._text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: StudentProfileScreen._background,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: StudentProfileScreen._hair),
              ),
              child: Text(
                'Member',
                style: TextStyle(
                  color: StudentProfileScreen._body,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared card shell ────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final Widget child;
  const _ProfileCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: StudentProfileScreen._card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: StudentProfileScreen._hair, width: 1),
      ),
      child: child,
    );
  }
}

class _CardLabel extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _CardLabel({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: StudentProfileScreen._secondary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.9,
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}

// ─── Up next header ───────────────────────────────────────────────────────────

class _UpNextHeader extends StatelessWidget {
  final VoidCallback? onSeeAll;

  const _UpNextHeader({this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Up next',
          style: TextStyle(
            color: StudentProfileScreen._text,
            fontSize: 21,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const Spacer(),
        _ScaleTap(
          onTap: onSeeAll,
          child: const Row(
            children: [
              Text(
                'See all',
                style: TextStyle(
                  color: StudentProfileScreen._burgundy,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(width: 2),
              Icon(
                Icons.chevron_right_rounded,
                color: StudentProfileScreen._burgundy,
                size: 19,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Interest tag ─────────────────────────────────────────────────────────────

class InterestTag extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const InterestTag({super.key, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return _ScaleTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: StudentProfileScreen._burgundyTint,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: StudentProfileScreen._burgundy,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ),
      ),
    );
  }
}

// ─── Event card ───────────────────────────────────────────────────────────────

class EventCard extends StatelessWidget {
  final StudentEventData event;
  final VoidCallback? onTap;

  const EventCard({super.key, required this.event, this.onTap});

  @override
  Widget build(BuildContext context) {
    return _ScaleTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: StudentProfileScreen._card,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: StudentProfileScreen._hair,
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 58,
              height: 64,
              decoration: BoxDecoration(
                color: StudentProfileScreen._burgundy,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    event.month,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    event.day,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: StudentProfileScreen._text,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    event.clubLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: StudentProfileScreen._secondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 15,
                        color: StudentProfileScreen._secondary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          event.location,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: StudentProfileScreen._secondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: StudentProfileScreen._burgundy.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.confirmation_number_outlined,
                    size: 14,
                    color: StudentProfileScreen._burgundy,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Going',
                    style: TextStyle(
                      color: StudentProfileScreen._burgundy,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Capsule badge (used externally) ─────────────────────────────────────────

class CapsuleBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const CapsuleBadge({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Scale-tap gesture helper ─────────────────────────────────────────────────

class _ScaleTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _ScaleTap({required this.child, this.onTap});

  @override
  State<_ScaleTap> createState() => _ScaleTapState();
}

class _ScaleTapState extends State<_ScaleTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.94,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
