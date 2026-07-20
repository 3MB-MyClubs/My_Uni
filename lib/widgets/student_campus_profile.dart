import 'package:flutter/material.dart';

import '../models/club.dart';
import '../services/app_colors.dart';
import '../services/theme_service.dart';
import 'club_avatar.dart';
import 'user_avatar.dart';

/// Campus ID reference-design palette. The ID card itself keeps its fixed
/// burgundy/white branding in both themes; the surrounding page chrome
/// (background, buttons, cards, text) follows the app's light/dark setting.
abstract final class _StudentDark {
  static const background = DarkColors.background;
  static const deep = DarkColors.card;
  static const solid = DarkColors.surfaceAlt;
  static const card = DarkColors.card;
  static const text = Colors.white;
  static const textSoft = Color(0xD1FFFFFF);
  static const textMuted = DarkColors.secondaryText;
  static const secondary = DarkColors.secondaryText;
  static const border = DarkColors.divider;
  static const borderStrong = DarkColors.divider;
  static const accent = Color(0xFF9E2045);
}

abstract final class _StudentLight {
  static const background = Color(0xFFFBF7F5);
  static const deep = Color(0xFFF5EDEA);
  static const solid = Color(0xFFFFFFFF);
  static const card = Color(0x0A9E2045);
  static const text = Color(0xFF1A0610);
  static const textSoft = Color(0xD11A0610);
  static const textMuted = Color(0x8C1A0610);
  static const secondary = Color(0xFF9A7888);
  static const border = Color(0x14000000);
  static const borderStrong = Color(0x2E000000);
  static const accent = Color(0xFF9E2045);
}

abstract final class StudentCampusPalette {
  // Same in both themes — the ID card keeps its fixed brand colors.
  static const burgundy = Color(0xFF8C1D40);
  static const burgundyDeep = Color(0xFF6A1530);

  static Color get background =>
      themeService.isDark ? _StudentDark.background : _StudentLight.background;
  static Color get deep =>
      themeService.isDark ? _StudentDark.deep : _StudentLight.deep;
  static Color get solid =>
      themeService.isDark ? _StudentDark.solid : _StudentLight.solid;
  static Color get card =>
      themeService.isDark ? _StudentDark.card : _StudentLight.card;
  static Color get text =>
      themeService.isDark ? _StudentDark.text : _StudentLight.text;
  static Color get textSoft =>
      themeService.isDark ? _StudentDark.textSoft : _StudentLight.textSoft;
  static Color get textMuted =>
      themeService.isDark ? _StudentDark.textMuted : _StudentLight.textMuted;
  static Color get secondary =>
      themeService.isDark ? _StudentDark.secondary : _StudentLight.secondary;
  static Color get border =>
      themeService.isDark ? _StudentDark.border : _StudentLight.border;
  static Color get borderStrong => themeService.isDark
      ? _StudentDark.borderStrong
      : _StudentLight.borderStrong;
  static Color get accent =>
      themeService.isDark ? _StudentDark.accent : _StudentLight.accent;
}

class StudentCampusProfile {
  final String userId;
  final String name;
  final String email;
  final String major;
  final String year;
  final String bio;
  final List<String> doubleMajors;
  final List<String> minors;
  final int clubs;
  final int following;
  final int followers;

  const StudentCampusProfile({
    required this.userId,
    required this.name,
    required this.email,
    required this.major,
    required this.year,
    required this.bio,
    required this.clubs,
    required this.following,
    required this.followers,
    this.doubleMajors = const [],
    this.minors = const [],
  });
}

class StudentCampusMembership {
  final Club club;
  final Color color;
  final String role;
  final String detail;

  const StudentCampusMembership({
    required this.club,
    required this.color,
    required this.role,
    required this.detail,
  });
}

class StudentCampusProfileView extends StatelessWidget {
  final StudentCampusProfile profile;
  final String title;
  final Widget leading;
  final Widget trailing;
  final Widget? primaryAction;
  final Widget? supplementalContent;
  final List<StudentCampusMembership> memberships;
  final String clubsTitle;
  final String? clubsActionLabel;
  final VoidCallback? onClubsAction;
  final ValueChanged<Club>? onClubTap;
  final VoidCallback? onClubsTap;
  final VoidCallback? onFollowingTap;
  final VoidCallback? onFollowersTap;

  const StudentCampusProfileView({
    super.key,
    required this.profile,
    required this.title,
    required this.leading,
    required this.trailing,
    required this.memberships,
    required this.clubsTitle,
    this.primaryAction,
    this.supplementalContent,
    this.clubsActionLabel,
    this.onClubsAction,
    this.onClubTap,
    this.onClubsTap,
    this.onFollowingTap,
    this.onFollowersTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: StudentCampusPalette.background,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(
              top: -82,
              left: MediaQuery.sizeOf(context).width / 2 - 150,
              child: IgnorePointer(
                child: Container(
                  width: 300,
                  height: 220,
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      colors: [Color(0x388C1D40), Color(0x008C1D40)],
                    ),
                  ),
                ),
              ),
            ),
            CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: _StudentProfileTopBar(
                    title: title,
                    leading: leading,
                    trailing: trailing,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                    child: StudentCampusIdCard(
                      profile: profile,
                      onClubsTap: onClubsTap,
                      onFollowingTap: onFollowingTap,
                      onFollowersTap: onFollowersTap,
                    ),
                  ),
                ),
                if (primaryAction != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: primaryAction,
                    ),
                  ),
                if (supplementalContent != null)
                  SliverToBoxAdapter(child: supplementalContent),
                if (profile.bio.trim().isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _StudentBioCard(bio: profile.bio),
                    ),
                  ),
                if (memberships.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: StudentProfileSectionLabel(clubsTitle),
                          ),
                          if (clubsActionLabel != null)
                            StudentProfileTextButton(
                              label: clubsActionLabel!,
                              onTap: onClubsAction,
                            ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid.builder(
                      itemCount: memberships.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            mainAxisExtent: 112,
                          ),
                      itemBuilder: (context, index) => _MembershipCard(
                        membership: memberships[index],
                        onTap: onClubTap == null
                            ? null
                            : () => onClubTap!(memberships[index].club),
                      ),
                    ),
                  ),
                ],
                SliverToBoxAdapter(child: SizedBox(height: bottomInset + 24)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class StudentCampusIdCard extends StatelessWidget {
  final StudentCampusProfile profile;
  final VoidCallback? onClubsTap;
  final VoidCallback? onFollowingTap;
  final VoidCallback? onFollowersTap;

  const StudentCampusIdCard({
    super.key,
    required this.profile,
    this.onClubsTap,
    this.onFollowingTap,
    this.onFollowersTap,
  });

  String get _majorLine {
    final programs = <String>[
      if (profile.major.trim().isNotEmpty) profile.major.trim(),
      ...profile.doubleMajors
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty),
    ];
    return programs.isEmpty ? 'Major not added' : programs.join(' & ');
  }

  String get _minorLine {
    final values = profile.minors
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (values.isEmpty) return '';
    return 'Minor in ${values.join(' & ')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            StudentCampusPalette.burgundyDeep,
            StudentCampusPalette.burgundy,
            StudentCampusPalette.burgundyDeep,
          ],
          stops: [0, 0.55, 1],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x598C1D40),
            blurRadius: 34,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(top: -40, right: -34, child: _CardGlow(size: 150)),
          const Positioned(bottom: -52, left: -42, child: _CardGlow(size: 166)),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 13, 16, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Club',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            TextSpan(
                              text: 'Up',
                              style: TextStyle(fontWeight: FontWeight.w300),
                            ),
                          ],
                        ),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ),
                    Text(
                      'STUDENT ID',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Row(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.25),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x738C1D40),
                            blurRadius: 22,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: UserAvatar(
                        userId: profile.userId,
                        name: profile.name,
                        size: 57,
                        fontSize: 22,
                        backgroundColor: StudentCampusPalette.burgundyDeep,
                        textColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _majorLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 11.5,
                            ),
                          ),
                          if (_minorLine.isNotEmpty) ...[
                            const SizedBox(height: 1),
                            Text(
                              _minorLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                          if (profile.year.isNotEmpty ||
                              profile.email.isNotEmpty) ...[
                            const SizedBox(height: 1),
                            Text(
                              [
                                profile.year.trim(),
                                profile.email.trim(),
                              ].where((value) => value.isNotEmpty).join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    _CampusStat(
                      value: profile.clubs,
                      label: 'Clubs',
                      onTap: onClubsTap,
                    ),
                    _CampusStat(
                      value: profile.following,
                      label: 'Following',
                      onTap: onFollowingTap,
                    ),
                    _CampusStat(
                      value: profile.followers,
                      label: 'Followers',
                      onTap: onFollowersTap,
                      showDivider: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StudentProfileIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const StudentProfileIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: StudentCampusPalette.solid,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: StudentCampusPalette.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 19, color: StudentCampusPalette.secondary),
          ),
        ),
      ),
    );
  }
}

class StudentProfilePrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool filled;

  const StudentProfilePrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: filled
              ? StudentCampusPalette.burgundy
              : StudentCampusPalette.card,
          foregroundColor: filled
              ? Colors.white
              : StudentCampusPalette.textSoft,
          side: BorderSide(
            color: filled
                ? StudentCampusPalette.burgundy
                : StudentCampusPalette.borderStrong,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        child: Text(label),
      ),
    );
  }
}

class StudentProfileSectionLabel extends StatelessWidget {
  final String text;

  const StudentProfileSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: StudentCampusPalette.secondary,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
      ),
    );
  }
}

class StudentProfileTextButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const StudentProfileTextButton({super.key, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            color: StudentCampusPalette.accent,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _StudentProfileTopBar extends StatelessWidget {
  final String title;
  final Widget leading;
  final Widget trailing;

  const _StudentProfileTopBar({
    required this.title,
    required this.leading,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: StudentCampusPalette.secondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _StudentBioCard extends StatelessWidget {
  final String bio;

  const _StudentBioCard({required this.bio});

  @override
  Widget build(BuildContext context) {
    final text = bio.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: StudentCampusPalette.card,
        border: Border.all(color: StudentCampusPalette.border),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StudentProfileSectionLabel('Bio'),
          const SizedBox(height: 6),
          Text(
            text,
            style: TextStyle(
              color: StudentCampusPalette.textSoft,
              fontSize: 12.5,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _MembershipCard extends StatelessWidget {
  final StudentCampusMembership membership;
  final VoidCallback? onTap;

  const _MembershipCard({required this.membership, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StudentCampusPalette.card,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: StudentCampusPalette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClubAvatar(
                    clubId: membership.club.id,
                    clubName: membership.club.name,
                    color: membership.color,
                    imageUrl: membership.club.logoUrl,
                    size: 34,
                    fontSize: 13,
                    borderRadius: 11,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      membership.club.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: StudentCampusPalette.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              StudentClubRoleBadge(role: membership.role),
              const SizedBox(height: 5),
              Text(
                membership.detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: StudentCampusPalette.secondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A prominent, consistent club-role label shared by student profile previews
/// and complete club lists. Leadership titles receive stronger emphasis while
/// regular membership stays clearly readable without competing with them.
class StudentClubRoleBadge extends StatelessWidget {
  final String role;
  final bool compact;

  const StudentClubRoleBadge({
    super.key,
    required this.role,
    this.compact = false,
  });

  String get _label {
    final value = role.trim();
    return value.isEmpty ? 'Member' : value;
  }

  bool get _isMember => _label.toLowerCase() == 'member';

  bool get _isFounder {
    final value = _label.toLowerCase();
    return value.contains('founder') || value.contains('co-founder');
  }

  @override
  Widget build(BuildContext context) {
    final foreground = _isFounder
        ? const Color(0xFFFFD27A)
        : _isMember
        ? StudentCampusPalette.textSoft
        : const Color(0xFFFFB3C8);
    final background = _isFounder
        ? const Color(0x26FFC857)
        : _isMember
        ? (themeService.isDark
              ? const Color(0x0FFFFFFF)
              : const Color(0x0A000000))
        : const Color(0x478C1D40);
    final border = _isFounder
        ? const Color(0x66FFC857)
        : _isMember
        ? StudentCampusPalette.borderStrong
        : const Color(0x73D96A8B);
    final icon = _isFounder
        ? Icons.auto_awesome_rounded
        : _isMember
        ? Icons.person_outline_rounded
        : Icons.workspace_premium_rounded;

    return Semantics(
      label: 'Club role: $_label',
      child: Container(
        constraints: BoxConstraints(maxWidth: compact ? 112 : 150),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 9,
          vertical: compact ? 4 : 5,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: const BorderRadius.all(Radius.circular(999)),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 12 : 13, color: foreground),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                _label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: compact ? 10.5 : 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CampusStat extends StatelessWidget {
  final int value;
  final String label;
  final VoidCallback? onTap;
  final bool showDivider;

  const _CampusStat({
    required this.value,
    required this.label,
    this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            border: showDivider
                ? Border(
                    right: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  )
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 10,
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

class _CardGlow extends StatelessWidget {
  final double size;

  const _CardGlow({required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [Color(0x1AFFFFFF), Color(0x00FFFFFF)],
          ),
        ),
      ),
    );
  }
}
