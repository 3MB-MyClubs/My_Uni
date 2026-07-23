import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/club.dart';
import '../services/app_colors.dart';
import '../services/club_insights_service.dart';
import '../widgets/club_avatar.dart';

/// Club admin insights: overview tiles and top posts by likes. All bars are
/// hand-rolled containers — no chart lib.
class ClubInsightsScreen extends StatelessWidget {
  final Club club;
  final Color accent;

  const ClubInsightsScreen({super.key, required this.club, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.text,
        surfaceTintColor: Colors.transparent,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClubAvatar(
              clubId: club.id,
              clubName: club.name,
              color: accent,
              imageUrl: club.logoUrl,
              size: 28,
              fontSize: 12,
              borderRadius: 9,
            ),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context)!.insightsTitle,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
      ),
      body: Builder(
        builder: (context) {
          final data = clubInsightsService.compute(club);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
            children: [
              // ── Overview tiles ──
              Row(
                children: [
                  _tile(
                    AppLocalizations.of(context)!.followers,
                    data.followers,
                    Icons.people_outline,
                  ),
                  const SizedBox(width: 10),
                  _tile(
                    AppLocalizations.of(context)!.rsvpsLabel,
                    data.totalRsvps,
                    Icons.event_available,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _tile(
                    AppLocalizations.of(context)!.postLikes,
                    data.totalLikes,
                    Icons.favorite_border,
                  ),
                  const SizedBox(width: 10),
                  _tile(
                    AppLocalizations.of(context)!.postViews,
                    data.totalViews,
                    Icons.visibility_outlined,
                  ),
                ],
              ),

              // ── Top posts ──
              if (data.topPosts.isNotEmpty) ...[
                const SizedBox(height: 22),
                _sectionHead(AppLocalizations.of(context)!.topPosts),
                const SizedBox(height: 10),
                for (final stat in data.topPosts) _postRow(stat),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHead(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        color: AppColors.secondaryText,
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
            Icon(icon, size: 17, color: accent),
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

  Widget _postRow(PostStat stat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              stat.post.content,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: AppColors.text),
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.favorite, size: 13, color: accent),
          const SizedBox(width: 3),
          Text(
            '${stat.likes}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            Icons.visibility_outlined,
            size: 13,
            color: AppColors.secondaryText,
          ),
          const SizedBox(width: 3),
          Text(
            '${stat.views}',
            style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
          ),
        ],
      ),
    );
  }
}
