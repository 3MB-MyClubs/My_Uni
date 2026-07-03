import 'package:flutter/material.dart';

import '../models/club.dart';
import '../services/app_colors.dart';
import '../services/checkin_store.dart';
import '../services/club_insights_service.dart';
import '../widgets/club_avatar.dart';

/// Club admin insights: overview tiles, per-event RSVP vs check-in bars, and
/// top posts by likes. All bars are hand-rolled containers — no chart lib.
class ClubInsightsScreen extends StatefulWidget {
  final Club club;
  final Color accent;

  const ClubInsightsScreen({
    super.key,
    required this.club,
    required this.accent,
  });

  @override
  State<ClubInsightsScreen> createState() => _ClubInsightsScreenState();
}

class _ClubInsightsScreenState extends State<ClubInsightsScreen> {
  @override
  void initState() {
    super.initState();
    clubInsightsService.refreshRemote(widget.club).then((_) {
      if (mounted) setState(() {});
    });
  }

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
              clubId: widget.club.id,
              clubName: widget.club.name,
              color: widget.accent,
              imageUrl: widget.club.logoUrl,
              size: 28,
              fontSize: 12,
              borderRadius: 9,
            ),
            const SizedBox(width: 8),
            const Text(
              'Insights',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: checkinStore,
        builder: (context, _) {
          final data = clubInsightsService.compute(widget.club);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
            children: [
              // ── Overview tiles ──
              Row(
                children: [
                  _tile('Followers', data.followers, Icons.people_outline),
                  const SizedBox(width: 10),
                  _tile('RSVPs', data.totalRsvps, Icons.event_available),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _tile('Post likes', data.totalLikes, Icons.favorite_border),
                  const SizedBox(width: 10),
                  _tile(
                    'Post views',
                    data.totalViews,
                    Icons.visibility_outlined,
                  ),
                ],
              ),

              // ── Events: RSVP vs check-in ──
              if (data.events.isNotEmpty) ...[
                const SizedBox(height: 22),
                _sectionHead('Event attendance'),
                const SizedBox(height: 10),
                for (final stat in data.events) _eventBar(stat),
              ],

              // ── Top posts ──
              if (data.topPosts.isNotEmpty) ...[
                const SizedBox(height: 22),
                _sectionHead('Top posts'),
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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 17, color: widget.accent),
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

  Widget _eventBar(EventAttendanceStat stat) {
    final ratePercent = (stat.checkinRate * 100).round();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  stat.event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
              Text(
                '${stat.checkinCount}/${stat.rsvpCount} · $ratePercent%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: widget.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // RSVP track with check-in fill
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(color: widget.accent.withValues(alpha: 0.14)),
                  FractionallySizedBox(
                    widthFactor: stat.checkinRate.clamp(0.0, 1.0),
                    child: Container(color: widget.accent),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'RSVPs vs check-ins',
            style: TextStyle(fontSize: 10.5, color: AppColors.secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _postRow(PostStat stat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
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
          Icon(Icons.favorite, size: 13, color: widget.accent),
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
