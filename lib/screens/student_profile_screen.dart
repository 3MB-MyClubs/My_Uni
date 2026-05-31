import 'package:flutter/material.dart';
import '../models/club.dart';
import '../widgets/club_avatar.dart';

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
  final VoidCallback? onEditBio;
  final VoidCallback? onEditProfile;
  final List<Club> followedClubs;
  final ValueChanged<Club>? onClubTap;
  final StudentProfileData data;

  const StudentProfileScreen({
    super.key,
    required this.onSettings,
    required this.data,
    this.onEditBio,
    this.onEditProfile,
    this.followedClubs = const [],
    this.onClubTap,
  });

  static const Color _burgundy = Color(0xFF8D1F2D);
  static const Color _background = Color(0xFFF7F4F2);
  static const Color _text = Color(0xFF1F1F1F);
  static const Color _secondary = Color(0xFF7A7A7A);
  static const Color _green = Color(0xFF27C46B);

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _burgundy,
          brightness: Brightness.light,
          surface: _background,
        ),
        scaffoldBackgroundColor: _background,
      ),
      child: Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
                  child: _TopBar(onSettings: onSettings),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
                  child: ProfileHeader(data: data),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: _ProfileIdentity(data: data, onEditBio: onEditBio),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
                  child: StatsCard(
                    clubs: data.clubs,
                    followers: data.followers,
                    following: data.following,
                    onClubsTap: () =>
                        _showFollowedClubsSheet(context, followedClubs),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
                  child: _ProfileActions(onEditProfile: onEditProfile),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 28, 22, 0),
                  child: _VibeSection(vibes: data.vibes),
                ),
              ),
              if (data.nextEvent != null) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 28, 22, 0),
                    child: _UpNextHeader(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                    child: EventCard(event: data.nextEvent!),
                  ),
                ),
              ],
              SliverToBoxAdapter(child: SizedBox(height: bottom + 116)),
            ],
          ),
        ),
      ),
    );
  }

  void _showFollowedClubsSheet(BuildContext context, List<Club> clubs) {
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
          decoration: const BoxDecoration(
            color: _background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
                child: Row(
                  children: [
                    const Text(
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
                        '${clubs.length}',
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
                child: clubs.isEmpty
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
                        itemCount: clubs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final club = clubs[index];
                          return _ScaleTap(
                            onTap: () {
                              Navigator.pop(sheetContext);
                              onClubTap?.call(club);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.black.withValues(alpha: 0.05),
                                ),
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
                                      style: const TextStyle(
                                        color: _text,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const Icon(
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

class _TopBar extends StatelessWidget {
  final VoidCallback onSettings;

  const _TopBar({required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Text(
            'Profile',
            style: TextStyle(
              color: StudentProfileScreen._text,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          Positioned(
            right: 0,
            child: _ScaleTap(
              onTap: onSettings,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: const Icon(
                  Icons.settings_outlined,
                  size: 20,
                  color: StudentProfileScreen._text,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileHeader extends StatelessWidget {
  final StudentProfileData data;

  const ProfileHeader({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 198,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 154,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF67101F),
                  Color(0xFF8D1F2D),
                  Color(0xFF3B0B15),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: StudentProfileScreen._burgundy.withValues(alpha: 0.25),
                  blurRadius: 30,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: Stack(
                children: [
                  Positioned(
                    left: -34,
                    top: 18,
                    child: _BlurCircle(
                      size: 118,
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  Positioned(
                    right: -22,
                    bottom: -32,
                    child: _BlurCircle(
                      size: 136,
                      color: const Color(0xFFFFB3C0).withValues(alpha: 0.18),
                    ),
                  ),
                  Positioned(
                    right: 18,
                    top: 18,
                    child: CapsuleBadge(
                      icon: Icons.school_outlined,
                      label: data.graduation,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 22,
            bottom: 0,
            child: _Avatar(initials: data.initials),
          ),
        ],
      ),
    );
  }
}

class _BlurCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _BlurCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 40, spreadRadius: 18)],
      ),
    );
  }
}

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

class _Avatar extends StatelessWidget {
  final String initials;

  const _Avatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      height: 108,
      decoration: BoxDecoration(
        color: const Color(0xFFF7DCE4),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: Text(
              initials,
              style: const TextStyle(
                color: StudentProfileScreen._burgundy,
                fontSize: 31,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
              ),
            ),
          ),
          Positioned(
            right: 7,
            bottom: 8,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: StudentProfileScreen._green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileIdentity extends StatelessWidget {
  final StudentProfileData data;
  final VoidCallback? onEditBio;

  const _ProfileIdentity({required this.data, this.onEditBio});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.name,
                    style: const TextStyle(
                      color: StudentProfileScreen._text,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      height: 1.04,
                      letterSpacing: -0.9,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.school_outlined,
                        size: 15,
                        color: StudentProfileScreen._secondary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          data.major,
                          overflow: TextOverflow.ellipsis,
                          style: _metaStyle(),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 7),
                        child: Text(
                          '•',
                          style: TextStyle(
                            color: StudentProfileScreen._secondary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(data.year, style: _metaStyle()),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            _ScaleTap(
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.07),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.ios_share_outlined,
                      size: 17,
                      color: StudentProfileScreen._text,
                    ),
                    SizedBox(width: 7),
                    Text(
                      'Share',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: StudentProfileScreen._text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        RichText(
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            style: const TextStyle(
              color: StudentProfileScreen._text,
              fontSize: 15,
              height: 1.42,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.1,
            ),
            children: [
              TextSpan(text: data.bio),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.only(left: 7),
                  child: GestureDetector(
                    onTap: onEditBio,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 14,
                          color: StudentProfileScreen._burgundy,
                        ),
                        SizedBox(width: 3),
                        Text(
                          'Edit',
                          style: TextStyle(
                            color: StudentProfileScreen._burgundy,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
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
      ],
    );
  }

  static TextStyle _metaStyle() {
    return const TextStyle(
      color: StudentProfileScreen._secondary,
      fontSize: 14,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.1,
    );
  }
}

class StatsCard extends StatelessWidget {
  final int clubs;
  final int followers;
  final int following;
  final VoidCallback? onClubsTap;

  const StatsCard({
    super.key,
    required this.clubs,
    required this.followers,
    required this.following,
    this.onClubsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 94,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.055),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              value: clubs.toString(),
              label: 'Clubs',
              onTap: onClubsTap,
            ),
          ),
          _StatDivider(),
          Expanded(
            child: _StatItem(value: followers.toString(), label: 'Followers'),
          ),
          _StatDivider(),
          Expanded(
            child: _StatItem(value: following.toString(), label: 'Following'),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback? onTap;

  const _StatItem({required this.value, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return _ScaleTap(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: StudentProfileScreen._burgundy,
              fontSize: 25,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: StudentProfileScreen._secondary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 44,
      color: Colors.black.withValues(alpha: 0.07),
    );
  }
}

class _ProfileActions extends StatelessWidget {
  final VoidCallback? onEditProfile;

  const _ProfileActions({this.onEditProfile});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ScaleTap(
            onTap: onEditProfile,
            child: Container(
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: StudentProfileScreen._burgundy,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: StudentProfileScreen._burgundy.withValues(
                      alpha: 0.25,
                    ),
                    blurRadius: 18,
                    offset: const Offset(0, 9),
                  ),
                ],
              ),
              child: const Text(
                'Edit Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _ScaleTap(
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: StudentProfileScreen._text,
              size: 21,
            ),
          ),
        ),
      ],
    );
  }
}

class _VibeSection extends StatelessWidget {
  final List<String> vibes;

  const _VibeSection({required this.vibes});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'Vibe', trailing: 'Edit', onTrailingTap: () {}),
        const SizedBox(height: 14),
        Wrap(
          spacing: 9,
          runSpacing: 10,
          children: vibes.map((vibe) => InterestTag(label: vibe)).toList(),
        ),
      ],
    );
  }
}

class InterestTag extends StatelessWidget {
  final String label;

  const InterestTag({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return _ScaleTap(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: StudentProfileScreen._burgundy,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: StudentProfileScreen._burgundy.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _UpNextHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Up next',
          style: TextStyle(
            color: StudentProfileScreen._text,
            fontSize: 21,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: StudentProfileScreen._burgundy,
            shape: BoxShape.circle,
          ),
          child: const Text(
            '2',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const Spacer(),
        _ScaleTap(
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final String trailing;
  final VoidCallback? onTrailingTap;

  const _SectionHeader({
    required this.title,
    required this.trailing,
    this.onTrailingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: StudentProfileScreen._text,
            fontSize: 21,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onTrailingTap,
          child: Text(
            trailing,
            style: const TextStyle(
              color: StudentProfileScreen._burgundy,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class EventCard extends StatelessWidget {
  final StudentEventData event;

  const EventCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return _ScaleTap(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
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
                    style: const TextStyle(
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
                    style: const TextStyle(
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
                    style: const TextStyle(
                      color: StudentProfileScreen._secondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 15,
                        color: StudentProfileScreen._secondary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          event.location,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
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

class _ScaleTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _ScaleTap({required this.child, this.onTap});

  @override
  State<_ScaleTap> createState() => _ScaleTapState();
}

class _ScaleTapState extends State<_ScaleTap> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
