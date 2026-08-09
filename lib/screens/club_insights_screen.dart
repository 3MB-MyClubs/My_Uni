import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/club.dart';
import '../services/app_colors.dart';
import '../services/club_insights_service.dart';
import 'post_detail_screen.dart';

/// Private club-admin analytics, designed as a compact at-a-glance dashboard.
class ClubInsightsScreen extends StatefulWidget {
  final Club club;
  final Color accent;

  /// Deterministic data for previews and visual regression tests. Production
  /// callers omit this and read the live club caches through the service.
  final ClubInsightsData? previewData;

  const ClubInsightsScreen({
    super.key,
    required this.club,
    required this.accent,
    this.previewData,
  });

  @override
  State<ClubInsightsScreen> createState() => _ClubInsightsScreenState();
}

class _ClubInsightsScreenState extends State<ClubInsightsScreen> {
  Color get _insightAccent => AppColors.primaryRed;

  Future<void> _refresh() async {
    if (widget.previewData != null) {
      if (mounted) setState(() {});
      return;
    }
    await clubInsightsService.refreshRemote(widget.club);
    if (mounted) setState(() {});
  }

  Future<void> _openPost(PostStat stat) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            PostDetailScreen(post: stat.post, clubColor: widget.accent),
      ),
    );
    if (mounted) setState(() {});
  }

  String _clubIdentity() {
    final shortName = widget.club.shortName?.trim();
    final displayName = shortName == null || shortName.isEmpty
        ? widget.club.name
        : shortName;
    return '$displayName · @${clubHandle(widget.club)}';
  }

  String _sinceLabel(BuildContext context, DateTime date) {
    final formatted = DateFormat(
      'd MMM y',
      Localizations.localeOf(context).toLanguageTag(),
    ).format(date).toUpperCase();
    return AppLocalizations.of(context)!.insightsSince(formatted);
  }

  String _postDate(BuildContext context, DateTime date) {
    final now = DateTime.now();
    final includeYear = date.year != now.year;
    return DateFormat(
      includeYear ? 'd MMM y' : 'd MMM',
      Localizations.localeOf(context).toLanguageTag(),
    ).format(date);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final data = widget.previewData ?? clubInsightsService.compute(widget.club);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        toolbarHeight: 78,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        shape: Border(bottom: BorderSide(color: AppColors.divider)),
        leadingWidth: 76,
        leading: Center(
          child: Semantics(
            button: true,
            label: MaterialLocalizations.of(context).backButtonTooltip,
            child: InkWell(
              key: const ValueKey('insights-back-button'),
              onTap: () => Navigator.maybePop(context),
              borderRadius: BorderRadius.circular(5),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF83C4FF),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 22,
                  color: AppColors.text,
                ),
              ),
            ),
          ),
        ),
        titleSpacing: 0,
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.insightsTitle,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 21,
                height: 1.05,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.55,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _clubIdentity(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 13,
                height: 1,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
        actions: const [SizedBox(width: 76)],
      ),
      body: RefreshIndicator(
        color: _insightAccent,
        backgroundColor: AppColors.card,
        onRefresh: _refresh,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth < 380 ? 16.0 : 24.0;
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  key: const ValueKey('club-insights-scroll'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    22,
                    horizontalPadding,
                    34,
                  ),
                  children: [
                    _SinceDivider(label: _sinceLabel(context, data.since)),
                    const SizedBox(height: 18),
                    _MetricGrid(data: data, accent: _insightAccent),
                    const SizedBox(height: 34),
                    _SectionHeading(
                      title: l10n.topPosts,
                      trailing: l10n.insightsTopPostsByViews,
                    ),
                    const SizedBox(height: 13),
                    if (data.topPosts.isEmpty)
                      _EmptyPostsCard(accent: _insightAccent)
                    else
                      _TopPostsList(
                        posts: data.topPosts,
                        accent: _insightAccent,
                        dateLabel: (date) => _postDate(context, date),
                        onOpen: _openPost,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SinceDivider extends StatelessWidget {
  const _SinceDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.secondaryText,
            fontSize: 12,
            height: 1,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.1,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Divider(height: 1, color: AppColors.divider)),
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.data, required this.accent});

  final ClubInsightsData data;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = [
      _MetricItem(
        keyName: 'followers',
        label: l10n.followers,
        helper: l10n.insightsAllTime,
        value: data.followers,
        icon: Icons.people_outline_rounded,
      ),
      _MetricItem(
        keyName: 'rsvps',
        label: l10n.rsvpsLabel,
        helper: l10n.insightsAcrossEvents(data.eventCount),
        value: data.totalRsvps,
        icon: Icons.event_available_outlined,
      ),
      _MetricItem(
        keyName: 'likes',
        label: l10n.postLikes,
        helper: l10n.insightsAcrossPosts(data.postCount),
        value: data.totalLikes,
        icon: Icons.favorite_border_rounded,
      ),
      _MetricItem(
        keyName: 'views',
        label: l10n.postViews,
        helper: l10n.insightsAcrossPosts(data.postCount),
        value: data.totalViews,
        icon: Icons.visibility_outlined,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 134,
      ),
      itemBuilder: (context, index) =>
          _MetricCard(item: items[index], accent: accent),
    );
  }
}

class _MetricItem {
  const _MetricItem({
    required this.keyName,
    required this.label,
    required this.helper,
    required this.value,
    required this.icon,
  });

  final String keyName;
  final String label;
  final String helper;
  final int value;
  final IconData icon;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.item, required this.accent});

  final _MetricItem item;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${item.value} ${item.label}, ${item.helper}',
      child: Container(
        key: ValueKey('insights-metric-${item.keyName}'),
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  accent.withValues(alpha: 0.22),
                  AppColors.card,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, size: 18, color: accent),
            ),
            const Spacer(),
            Text(
              '${item.value}',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 31,
                height: 0.95,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 7),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: item.label),
                  const TextSpan(text: '\n'),
                  TextSpan(text: item.helper),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12.5,
                height: 1.3,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.trailing});

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: AppColors.secondaryText,
            fontSize: 12,
            height: 1,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Divider(height: 1, color: AppColors.divider)),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            trailing,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
              height: 1,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

class _TopPostsList extends StatelessWidget {
  const _TopPostsList({
    required this.posts,
    required this.accent,
    required this.dateLabel,
    required this.onOpen,
  });

  final List<PostStat> posts;
  final Color accent;
  final String Function(DateTime) dateLabel;
  final ValueChanged<PostStat> onOpen;

  @override
  Widget build(BuildContext context) {
    final maxViews = posts.fold<int>(0, (max, item) {
      return item.views > max ? item.views : max;
    });

    return Column(
      children: [
        for (var index = 0; index < posts.length; index++) ...[
          _TopPostCard(
            rank: index + 1,
            stat: posts[index],
            maxViews: maxViews,
            accent: accent,
            date: dateLabel(posts[index].post.createdAt),
            onTap: () => onOpen(posts[index]),
          ),
          if (index != posts.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _TopPostCard extends StatelessWidget {
  const _TopPostCard({
    required this.rank,
    required this.stat,
    required this.maxViews,
    required this.accent,
    required this.date,
    required this.onTap,
  });

  final int rank;
  final PostStat stat;
  final int maxViews;
  final Color accent;
  final String date;
  final VoidCallback onTap;

  String get _title {
    final content = stat.post.content.trim();
    if (content.isNotEmpty) return content;
    final title = stat.post.title.trim();
    return title.isEmpty ? '—' : title;
  }

  @override
  Widget build(BuildContext context) {
    final isLeader = rank == 1;
    final progress = maxViews == 0 ? 0.0 : stat.views / maxViews;
    final mutedAccent = Color.alphaBlend(
      accent.withValues(alpha: 0.62),
      AppColors.card,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('insights-post-${stat.post.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(13, 11, 11, 11),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isLeader
                  ? accent.withValues(alpha: 0.58)
                  : AppColors.divider,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isLeader ? accent : AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        color: isLeader
                            ? Colors.white
                            : AppColors.secondaryText,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      _title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.25,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    date,
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.secondaryText,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        key: ValueKey('insights-post-bar-${stat.post.id}'),
                        value: progress,
                        minHeight: 5,
                        backgroundColor: AppColors.surfaceAlt,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isLeader ? accent : mutedAccent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  _PostMetric(
                    icon: Icons.visibility_outlined,
                    value: stat.views,
                    color: AppColors.secondaryText,
                  ),
                  const SizedBox(width: 12),
                  _PostMetric(
                    icon: Icons.favorite_rounded,
                    value: stat.likes,
                    color: accent,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostMetric extends StatelessWidget {
  const _PostMetric({
    required this.icon,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          '$value',
          style: TextStyle(
            color: AppColors.bodyText,
            fontSize: 12,
            height: 1,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EmptyPostsCard extends StatelessWidget {
  const _EmptyPostsCard({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      key: const ValueKey('insights-empty-posts'),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(Icons.bar_chart_rounded, size: 28, color: accent),
          const SizedBox(height: 9),
          Text(
            l10n.insightsAcrossPosts(0),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
