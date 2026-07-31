import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/club.dart';
import '../services/app_colors.dart';
import '../services/club_insights_service.dart';
import '../services/lazy_content_loader.dart';
import '../services/locale_service.dart';
import '../services/mock_data.dart';
import '../services/people_service.dart';
import '../services/theme_service.dart';
import 'club_insights_screen.dart';

/// Super-admin dashboard: campus-wide totals and a club engagement
/// leaderboard (followers, RSVPs, posts). Rows open per-club insights.
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  static const List<Color> _hues = [
    Color(0xFFB41C18),
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFF6A1B9A),
    Color(0xFFE65100),
    Color(0xFF00838F),
  ];

  int _peopleCount = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
    themeService.addListener(_onThemeOrLocaleChanged);
    localeService.addListener(_onThemeOrLocaleChanged);
  }

  @override
  void dispose() {
    themeService.removeListener(_onThemeOrLocaleChanged);
    localeService.removeListener(_onThemeOrLocaleChanged);
    super.dispose();
  }

  void _onThemeOrLocaleChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    try {
      await lazyContentLoader.ensureContentLoaded();
      final people = await peopleService.fetchPeople();
      if (!mounted) return;
      setState(() => _peopleCount = people.length);
    } catch (_) {
      if (!mounted) return;
      setState(() => _peopleCount = users.length);
    }
  }

  Color _hueFor(Club club) {
    final idx = clubs.indexOf(club);
    return _hues[(idx < 0 ? 0 : idx) % _hues.length];
  }

  @override
  Widget build(BuildContext context) {
    // Leaderboard: clubs ranked by followers, then total RSVPs.
    final ranked = [...clubs];
    final stats = clubInsightsService.computeAll(ranked);
    ranked.sort((a, b) {
      final byFollowers = stats[b.id]!.followers.compareTo(
        stats[a.id]!.followers,
      );
      if (byFollowers != 0) return byFollowers;
      return stats[b.id]!.totalRsvps.compareTo(stats[a.id]!.totalRsvps);
    });
    final top = ranked.take(10).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.text,
        surfaceTintColor: Colors.transparent,
        title: Text(
          AppLocalizations.of(context)!.adminDashboardTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
          children: [
            Row(
              children: [
                _tile(
                  AppLocalizations.of(context)!.students,
                  _peopleCount == 0 ? users.length : _peopleCount,
                  Icons.school_outlined,
                ),
                const SizedBox(width: 10),
                _tile(
                  AppLocalizations.of(context)!.clubs,
                  clubs.length,
                  Icons.groups_2_outlined,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _tile(
                  AppLocalizations.of(context)!.events,
                  events.length,
                  Icons.event_outlined,
                ),
                const SizedBox(width: 10),
                _tile(
                  AppLocalizations.of(context)!.posts,
                  newsPosts.length,
                  Icons.article_outlined,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.clubLeaderboard.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < top.length; i++)
              _leaderRow(rank: i + 1, club: top[i], stat: stats[top[i].id]!),
          ],
        ),
      ),
    );
  }

  Widget _tile(String label, int value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.all(Radius.circular(16)),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 17, color: AppColors.primaryRed),
            const SizedBox(height: 8),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _leaderRow({
    required int rank,
    required Club club,
    required ClubInsightsData stat,
  }) {
    final color = _hueFor(club);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClubInsightsScreen(club: club, accent: color),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.all(Radius.circular(14)),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: rank <= 3
                    ? AppColors.primaryRed.withValues(alpha: 0.14)
                    : AppColors.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: rank <= 3
                      ? AppColors.primaryRed
                      : AppColors.secondaryText,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                club.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(
                context,
              )!.followersAndRsvpsSummary(stat.followers, stat.totalRsvps),
              style: TextStyle(fontSize: 11.5, color: AppColors.secondaryText),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.secondaryText,
            ),
          ],
        ),
      ),
    );
  }
}
