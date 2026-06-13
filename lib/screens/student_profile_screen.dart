import 'package:flutter/material.dart';
import '../models/club.dart';
import '../services/app_colors.dart';
import '../widgets/club_avatar.dart';

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
  final StudentEventData? nextEvent;
  final List<StudentClubDetail> clubDetails;

  const StudentProfileData({
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
  final VoidCallback? onEditBio;
  final VoidCallback? onEditProfile;
  final VoidCallback? onShare;
  final VoidCallback? onEditVibes;
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
    this.onEditBio,
    this.onEditProfile,
    this.onShare,
    this.onEditVibes,
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
            // ── Banner + overlapping identity (all in one Stack) ────────────
            SliverToBoxAdapter(
              child: IntrinsicHeight(
                child: Stack(
                  children: [
                    // Full-width gradient banner
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 168,
                      child: _BannerSection(
                        graduation: data.graduation,
                        onSettings: onSettings,
                        onShare: onShare,
                      ),
                    ),
                    // Identity section overlaps banner by 44px
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 124, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Avatar + Edit profile row
                          _AvatarEditRow(
                            initials: data.initials,
                            onEditProfile: onEditProfile,
                          ),
                          const SizedBox(height: 14),
                          // Name + major + year
                          _NameMajorBlock(data: data),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Stats bar ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
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
                child: _AboutCard(bio: data.bio, onEdit: onEditBio),
              ),
            ),

            // ── Interests card ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: _InterestsCard(vibes: data.vibes, onEdit: onEditVibes),
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

// ─── Banner section ───────────────────────────────────────────────────────────

class _BannerSection extends StatelessWidget {
  final String graduation;
  final VoidCallback onSettings;
  final VoidCallback? onShare;

  const _BannerSection({
    required this.graduation,
    required this.onSettings,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 168,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF5A0D1B), // burgundyDeep
            Color(0xFF8D1F2D), // burgundy
            Color(0xFF8C3020), // warm orange-red
          ],
          stops: [0.0, 0.6, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Shield watermark (top-right, partially visible)
          Positioned(
            right: -32,
            top: -28,
            child: Opacity(
              opacity: 0.12,
              child: CustomPaint(
                size: const Size(210, 240),
                painter: _ShieldPainter(),
              ),
            ),
          ),
          // Nav overlay
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Share icon (left)
                GestureDetector(
                  onTap: onShare,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.ios_share_outlined,
                      color: Colors.white,
                      size: 17,
                    ),
                  ),
                ),
                // Graduation badge (center)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    graduation,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.78),
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Settings icon (right)
                GestureDetector(
                  onTap: onSettings,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.settings_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shield crest watermark — matches the SVG `M2 4 H54 V36 C54 50 42 60 28 62 C14 60 2 50 2 36 Z`
/// painted in white, scaled to the custom size.
class _ShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 56.0;
    final sy = size.height / 64.0;

    final path = Path()
      ..moveTo(2 * sx, 4 * sy)
      ..lineTo(54 * sx, 4 * sy)
      ..lineTo(54 * sx, 36 * sy)
      ..cubicTo(54 * sx, 50 * sy, 42 * sx, 60 * sy, 28 * sx, 62 * sy)
      ..cubicTo(14 * sx, 60 * sy, 2 * sx, 50 * sy, 2 * sx, 36 * sy)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_ShieldPainter old) => false;
}

// ─── Avatar + Edit profile row ────────────────────────────────────────────────

class _AvatarEditRow extends StatelessWidget {
  final String initials;
  final VoidCallback? onEditProfile;

  const _AvatarEditRow({required this.initials, this.onEditProfile});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
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
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFEDD5D8), Color(0xFFE0C4C0)],
              ),
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: StudentProfileScreen._burgundyDeep,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
            ),
          ),
        ),
        // Edit profile pill button
        _ScaleTap(
          onTap: onEditProfile,
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: StudentProfileScreen._card,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: StudentProfileScreen._burgundy.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: const Text(
              'Edit profile',
              style: TextStyle(
                color: StudentProfileScreen._burgundy,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
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
                _FacultySquare(major: data.major),
                const SizedBox(width: 6),
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
      ],
    );
  }
}

/// Small 18×18 colored square representing the student's faculty / major.
class _FacultySquare extends StatelessWidget {
  final String major;
  const _FacultySquare({required this.major});

  static Color _colorFor(String major) {
    // Fixed palette derived from first letter, similar to design's oklab approach.
    final hues = [
      const Color(0xFF1565C0), // A-C → blue
      const Color(0xFF2E7D32), // D-G → green
      const Color(0xFF6A1B9A), // H-M → purple
      const Color(0xFFE65100), // N-R → orange
      const Color(0xFF00838F), // S-Z → teal
    ];
    if (major.isEmpty) return hues[0];
    final c = major.toUpperCase().codeUnitAt(0);
    if (c <= 67) return hues[0]; // A-C
    if (c <= 71) return hues[1]; // D-G
    if (c <= 77) return hues[2]; // H-M
    if (c <= 82) return hues[3]; // N-R
    return hues[4]; // S-Z
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(major);
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Center(
        child: Text(
          major.isNotEmpty ? major[0].toUpperCase() : '?',
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
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
  final VoidCallback? onEdit;

  const _AboutCard({required this.bio, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final hasBio = bio.isNotEmpty && bio != 'Add a bio to introduce yourself.';
    return _ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardLabel(
            title: 'About',
            trailing: hasBio
                ? GestureDetector(
                    onTap: onEdit,
                    child: const Text(
                      'Edit',
                      style: TextStyle(
                        color: StudentProfileScreen._burgundy,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : null,
          ),
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
            _ScaleTap(
              onTap: onEdit,
              child: Row(
                children: [
                  const Icon(
                    Icons.add_rounded,
                    size: 16,
                    color: StudentProfileScreen._burgundy,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Add a bio',
                    style: TextStyle(
                      color: StudentProfileScreen._burgundy,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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
  final VoidCallback? onEdit;

  const _InterestsCard({required this.vibes, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return _ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardLabel(
            title: 'Interests',
            trailing: vibes.isNotEmpty
                ? GestureDetector(
                    onTap: onEdit,
                    child: const Text(
                      'Edit',
                      style: TextStyle(
                        color: StudentProfileScreen._burgundy,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          if (vibes.isEmpty)
            _ScaleTap(
              onTap: onEdit,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: StudentProfileScreen._burgundy.withValues(
                      alpha: 0.3,
                    ),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.add_rounded,
                      size: 15,
                      color: StudentProfileScreen._burgundy,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Add your interests',
                      style: TextStyle(
                        color: StudentProfileScreen._burgundy,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: vibes
                  .map((v) => InterestTag(label: v, onTap: onEdit))
                  .toList(),
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
            // Club monogram
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(
                child: Text(
                  detail.club.name.isNotEmpty
                      ? detail.club.name[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
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
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(
                child: Text(
                  club.name.isNotEmpty ? club.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
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
