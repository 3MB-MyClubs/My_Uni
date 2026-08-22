import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/news_post.dart';
import '../screens/club_profile_screen.dart';
import '../screens/create_post_screen.dart' show buildPostBanner;
import '../services/app_strings.dart';
import '../services/auth_service.dart';
import '../services/club_follow_helper.dart';
import '../services/comment_store.dart';
import '../services/image_aspect_ratio.dart';
import '../services/mock_data.dart';
import '../services/moderation_service.dart';
import '../services/post_like_helper.dart';
import '../services/theme_service.dart';
import '../services/user_state.dart';
import '../services/view_tracker.dart';
import 'app_motion.dart';
import 'club_avatar.dart';
import 'clubup_design.dart';
import 'expandable_post_caption.dart';
import 'home_comments_sheet.dart';
import 'home_share_sheet.dart';
import 'moderation_reason_sheet.dart';
import 'poll_card.dart';

/// The STUDENT HOME area of the ClubUp-Desings handoff — `home-feed-alt-light`
/// / `home-feed-alt-dark` (Figma `313:9` / `313:85`).
///
/// These widgets are deliberately *local to the Home area*: `feed_screen.dart`
/// draws them only for student sessions. Club-admin and platform-admin
/// sessions still get the pre-redesign Home, whose frames have not been
/// reviewed yet, so nothing shared with them is restyled here. The tokens come
/// from [ClubUpColors] / [figtree] like every other redesigned area.

// ── header ───────────────────────────────────────────────────────────────────

/// `premium-header-container` — the two-tone ClubUp wordmark, the feed-scope
/// dropdown that replaced the old segmented Following/For-You pill, and the
/// notification bell chip, over a hairline.
class HomeFeedHeader extends StatelessWidget {
  const HomeFeedHeader({
    super.key,
    required this.feedTab,
    required this.onSelectFeedTab,
    required this.unreadCount,
    required this.onBellTap,
    required this.atTop,
    required this.controlsVisible,
    this.overlay,
    this.scopeAnchorKey,
  });

  /// 0 = Following, 1 = For You — the same tabs the old pill switched.
  final int feedTab;
  final ValueChanged<int> onSelectFeedTab;
  final int unreadCount;
  final VoidCallback onBellTap;
  final bool atTop;
  final bool controlsVisible;

  /// Centred pull-to-refresh spinner, layered over the row like before.
  final Widget? overlay;

  /// The first-login tour highlights the feed-scope control; the old segmented
  /// pill carried this key, so the dropdown that replaced it carries it now.
  final Key? scopeAnchorKey;

  @override
  Widget build(BuildContext context) {
    final label = feedTab == 0 ? S.following : S.forYou;
    final showControls = atTop || controlsVisible;
    return AnimatedContainer(
      key: const ValueKey('home-header-surface'),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: atTop ? ClubUpColors.background : Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: atTop ? ClubUpColors.border : Colors.transparent,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          IgnorePointer(
            ignoring: !showControls,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              offset: showControls ? Offset.zero : const Offset(0, -0.28),
              child: AnimatedOpacity(
                key: const ValueKey('home-header-controls'),
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                opacity: showControls ? 1 : 0,
                child: Row(
                  children: [
                    Text.rich(
                      key: const ValueKey('home-clubup-logo'),
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Club',
                            style: figtree(
                              size: 22,
                              weight: FontWeight.w900,
                              color: ClubUpColors.accent,
                            ),
                          ),
                          TextSpan(
                            text: 'Up',
                            style: figtree(
                              size: 22,
                              weight: FontWeight.w900,
                              color: ClubUpColors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: Center(child: _scopeDropdown(label))),
                    _HomeBellChip(
                      unreadCount: unreadCount,
                      onTap: onBellTap,
                      simple: !atTop,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (overlay != null) IgnorePointer(child: overlay),
        ],
      ),
    );
  }

  /// `greeting-text` — the feed-scope dropdown that replaced the segmented
  /// Following / For You pill.
  Widget _scopeDropdown(String label) {
    return KeyedSubtree(
      key: scopeAnchorKey ?? const ValueKey('home-feed-scope-anchor'),
      child: PopupMenuButton<int>(
        key: const ValueKey('home-feed-scope-dropdown'),
        tooltip: label,
        position: PopupMenuPosition.under,
        padding: EdgeInsets.zero,
        color: ClubUpColors.card,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: ClubUpColors.border),
        ),
        onSelected: onSelectFeedTab,
        itemBuilder: (_) => [
          _scopeItem(0, S.following),
          _scopeItem(1, S.forYou),
        ],
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: figtree(
                  size: 18,
                  weight: FontWeight.w400,
                  color: ClubUpColors.accentText,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: ClubUpColors.accentText,
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<int> _scopeItem(int value, String text) {
    return PopupMenuItem<int>(
      value: value,
      height: 44,
      child: Row(
        children: [
          Text(
            text,
            style: figtree(
              size: 14,
              weight: feedTab == value ? FontWeight.w700 : FontWeight.w500,
              color: feedTab == value
                  ? ClubUpColors.accentText
                  : ClubUpColors.text,
            ),
          ),
          if (feedTab == value) ...[
            const Spacer(),
            Icon(Icons.check_rounded, size: 16, color: ClubUpColors.accentText),
          ],
        ],
      ),
    );
  }
}

/// `notification-trigger` — a 36pt rounded chip with the bell and, when
/// anything is unread, the 8pt burgundy dot in its top-right corner.
class _HomeBellChip extends StatelessWidget {
  const _HomeBellChip({
    required this.unreadCount,
    required this.onTap,
    required this.simple,
  });

  final int unreadCount;
  final VoidCallback onTap;
  final bool simple;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppLocalizations.of(context)!.notifications,
      child: GestureDetector(
        key: const ValueKey('home-notifications-bell'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: AnimatedContainer(
              key: const ValueKey('home-notifications-bell-surface'),
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: simple ? Colors.transparent : ClubUpColors.card,
                borderRadius: const BorderRadius.all(Radius.circular(18)),
                border: Border.all(
                  color: simple ? Colors.transparent : ClubUpColors.border,
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      Icons.notifications_none_rounded,
                      size: 20,
                      color: ClubUpColors.text,
                    ),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        key: const ValueKey('home-bell-badge'),
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: ClubUpColors.accent,
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `categories-horizontal-track` — "Hi, [name]".
class HomeGreeting extends StatelessWidget {
  const HomeGreeting({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        children: [
          Text(
            S.hiPrefix,
            style: figtree(
              size: 15,
              weight: FontWeight.w500,
              color: ClubUpColors.muted,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: figtree(
                size: 16,
                weight: FontWeight.w700,
                color: ClubUpColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── post card ────────────────────────────────────────────────────────────────

const double _portraitRatio = 4 / 5;
const double _landscapeRatio = 1.91;

/// `tech-connect-post` (photo) and `post-info-header` + `text-announcement-body`
/// (text) — one rounded card per post.
///
/// The design has no "…" button, so the report flow moved onto a long-press;
/// double-tap-to-like is kept from the old card since it costs no pixels.
class HomeFeedPostCard extends StatefulWidget {
  const HomeFeedPostCard({
    super.key,
    required this.post,
    required this.onChanged,
  });

  final NewsPost post;
  final VoidCallback onChanged;

  @override
  State<HomeFeedPostCard> createState() => _HomeFeedPostCardState();
}

class _HomeFeedPostCardState extends State<HomeFeedPostCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heart;
  late final Animation<double> _likeButtonScale;
  bool _burst = false;
  double _aspectRatio = 1;
  String? _probedPath;

  @override
  void initState() {
    super.initState();
    _heart =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 700),
        )..addStatusListener((status) {
          if (status != AnimationStatus.completed) return;
          if (mounted && _burst) setState(() => _burst = false);
          _heart.reset();
        });
    _likeButtonScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1, end: 1.28), weight: 34),
      TweenSequenceItem(tween: Tween(begin: 1.28, end: 0.94), weight: 28),
      TweenSequenceItem(tween: Tween(begin: 0.94, end: 1), weight: 38),
    ]).animate(CurvedAnimation(parent: _heart, curve: Curves.easeOut));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final userId = authService.currentUser?.id ?? '';
      viewTracker.recordView(widget.post.id, userId, syncRemote: true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _probeAspectRatio();
  }

  @override
  void didUpdateWidget(covariant HomeFeedPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.imagePath == widget.post.imagePath) return;
    _probedPath = null;
    _aspectRatio = 1;
    _probeAspectRatio();
  }

  @override
  void dispose() {
    _heart.dispose();
    super.dispose();
  }

  void _probeAspectRatio() {
    final path = widget.post.imagePath?.trim() ?? '';
    if (_probedPath == path) return;
    _probedPath = path;
    if (path.isEmpty) {
      _aspectRatio = 1;
      return;
    }
    if (path.startsWith('tpl:')) {
      _aspectRatio = _portraitRatio;
      return;
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      _aspectRatio = 1;
      return;
    }
    _aspectRatio = imageAspectRatioFromFile(File(path)) ?? 1;
  }

  void _onAspectRatio(double ratio) {
    if (!mounted || !ratio.isFinite || ratio <= 0) return;
    if ((_aspectRatio - ratio).abs() <= 0.001) return;
    setState(() => _aspectRatio = ratio);
  }

  String _timeAgo(DateTime dt) {
    final l10n = AppLocalizations.of(context)!;
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return l10n.minutesAgoSuffix(diff.inMinutes);
    if (diff.inHours < 24) return l10n.hoursAgoSuffix(diff.inHours);
    return l10n.daysAgoSuffix(diff.inDays);
  }

  void _openClub() {
    final club = clubForId(widget.post.clubId);
    if (club == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ClubProfileScreen(club: club, color: ClubUpColors.accent),
      ),
    );
  }

  void _toggleLike() {
    final becomingLiked = !userState.isLiked(widget.post.id);
    togglePostLike(widget.post.id);
    if (becomingLiked) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    if (!MediaQuery.disableAnimationsOf(context)) _heart.forward(from: 0);
    setState(() {});
    widget.onChanged();
  }

  void _doubleTapLike() {
    ensurePostLiked(widget.post.id);
    HapticFeedback.mediumImpact();
    setState(() => _burst = true);
    _heart.forward(from: 0);
    widget.onChanged();
  }

  void _openComments() {
    showHomeCommentsSheet(
      context,
      post: widget.post,
      onChanged: () {
        if (mounted) setState(() {});
        widget.onChanged();
      },
    );
  }

  void _openShare() {
    showHomeShareSheet(
      context,
      post: widget.post,
      onChanged: () {
        if (mounted) setState(() {});
        widget.onChanged();
      },
    );
  }

  Future<void> _reportPost() async {
    HapticFeedback.mediumImpact();
    final reason = await showModerationReasonSheet(
      context,
      title: AppLocalizations.of(context)!.whyReportPost,
    );
    if (reason == null || !mounted) return;
    var delivered = true;
    try {
      await moderationService.reportPost(widget.post, reason: reason);
    } catch (_) {
      delivered = false;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            delivered
                ? AppLocalizations.of(context)!.postReportedAndRemoved
                : AppLocalizations.of(context)!.postHiddenOffline,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final club = clubForId(widget.post.clubId);
    if (club == null) return const SizedBox.shrink();
    final dark = themeService.isDark;
    final hasImage =
        widget.post.imagePath != null &&
        widget.post.imagePath!.trim().isNotEmpty;
    final body = widget.post.content.trim();

    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onLongPress: _reportPost,
      child: Container(
        key: ValueKey('home-post-card-${widget.post.id}'),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: ClubUpColors.background,
          borderRadius: BorderRadius.zero,
        ),
        foregroundDecoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: ClubUpColors.text.withValues(alpha: 0.56),
              width: 2,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasImage) ...[
              _media(club.name),
              _postInfoHeader(club.name, dark, belowMedia: true),
            ] else
              _postInfoHeader(club.name, dark),
            if (widget.post.isAnnouncement)
              Padding(
                padding: EdgeInsets.fromLTRB(16, hasImage ? 16 : 14, 16, 0),
                child: _announcementChip(),
              ),
            if (body.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  hasImage
                      ? 10
                      : widget.post.isAnnouncement
                      ? 14
                      : 16,
                  16,
                  0,
                ),
                child: ExpandablePostCaption(
                  key: ValueKey('home-post-caption-${widget.post.id}'),
                  authorName: '',
                  caption: body,
                  // The design's cards print their whole announcement, so the
                  // fold only kicks in on posts longer than any of its frames.
                  collapsedWordCount: 45,
                  captionStyle: figtree(
                    size: 14,
                    weight: FontWeight.w400,
                    color: ClubUpColors.text,
                    height: hasImage ? 1.4 : 1.5,
                  ),
                  moreStyle: figtree(
                    size: 14,
                    weight: FontWeight.w600,
                    color: ClubUpColors.accentText,
                  ),
                ),
              ),
            if (widget.post.poll != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: PollCard(post: widget.post, accent: ClubUpColors.accent),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: _interactionRow(),
            ),
          ],
        ),
      ),
    );
  }

  /// `image-viewport` — the photo stays visually clean; its club attribution
  /// and caption now live together in the writing area immediately below it.
  Widget _media(String clubName) {
    // Keep the established vertical size even though photo posts now extend
    // horizontally to the phone edges like Instagram's feed.
    final heightBasisWidth = MediaQuery.sizeOf(context).width - 40;
    final safeRatio = _aspectRatio.isFinite && _aspectRatio > 0
        ? _aspectRatio
        : 1.0;
    final height =
        heightBasisWidth / safeRatio.clamp(_portraitRatio, _landscapeRatio);
    return GestureDetector(
      key: ValueKey('home-feed-photo-${widget.post.id}'),
      onDoubleTap: _doubleTapLike,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            buildPostBanner(
              imagePath: widget.post.imagePath,
              fallbackColor: ClubUpColors.accent,
              fallbackLetter: clubName.isEmpty ? '?' : clubName[0],
              height: height,
              onAspectRatio: _onAspectRatio,
            ),
            if (_burst)
              Center(
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.5, end: 1.4).animate(
                    CurvedAnimation(parent: _heart, curve: Curves.elasticOut),
                  ),
                  child: const Icon(
                    Icons.favorite,
                    color: Colors.white,
                    size: 72,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// `post-info-header` — avatar/name/time and follow control. Photo posts put
  /// this in their writing area so the caption can sit directly underneath.
  Widget _postInfoHeader(
    String clubName,
    bool dark, {
    bool belowMedia = false,
  }) {
    return Container(
      key: belowMedia
          ? ValueKey('home-post-photo-attribution-${widget.post.id}')
          : null,
      padding: belowMedia
          ? const EdgeInsets.fromLTRB(16, 14, 16, 0)
          : const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: belowMedia
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: ClubUpColors.border)),
            ),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openClub,
            child: Container(
              decoration: dark
                  ? const BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.fromBorderSide(
                        BorderSide(color: ClubUpColors.accent, width: 1.5),
                      ),
                    )
                  : null,
              child: ClubAvatar(
                clubId: widget.post.clubId,
                clubName: clubName,
                color: ClubUpColors.accent,
                imageUrl: clubForId(widget.post.clubId)?.logoUrl,
                size: 32,
                fontSize: 13,
                shape: 'circle',
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _openClub,
                  child: Text(
                    clubName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: figtree(
                      size: dark ? 13 : 14,
                      weight: FontWeight.w700,
                      color: dark ? Colors.white : ClubUpColors.text,
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  _timeAgo(widget.post.createdAt),
                  style: figtree(
                    size: dark ? 10 : 11,
                    weight: FontWeight.w500,
                    color: ClubUpColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _FollowText(
            clubId: widget.post.clubId,
            fontSize: 11,
            color: ClubUpColors.muted,
            onChanged: widget.onChanged,
          ),
        ],
      ),
    );
  }

  Widget _announcementChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ClubUpColors.accent.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: Text(
        S.announcementLabel,
        style: figtree(
          size: 10,
          weight: FontWeight.w800,
          color: ClubUpColors.accentText,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  /// `interaction-row` — likes and comments on the left over a hairline, the
  /// share plane on the right.
  Widget _interactionRow() {
    return Container(
      key: ValueKey('home-post-actions-panel-${widget.post.id}'),
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: ClubUpColors.text.withValues(alpha: 0.07),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          ListenableBuilder(
            listenable: userState,
            builder: (context, _) {
              final liked = userState.isLiked(widget.post.id);
              return _HomePostAction(
                key: ValueKey('home-post-like-${widget.post.id}'),
                icon: liked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                count: postLikeCount(widget.post.id),
                color: liked ? ClubUpColors.accent : ClubUpColors.muted,
                iconScale: _likeButtonScale,
                motionKey: ValueKey(
                  'home-post-like-heart-motion-${widget.post.id}',
                ),
                onTap: _toggleLike,
              );
            },
          ),
          const SizedBox(width: 18),
          ListenableBuilder(
            listenable: commentStore,
            builder: (context, _) => _HomePostAction(
              key: ValueKey('home-post-comment-${widget.post.id}'),
              icon: Icons.chat_bubble_outline_rounded,
              count: commentStore.countFor(widget.post.id),
              color: ClubUpColors.muted,
              onTap: _openComments,
            ),
          ),
          const Spacer(),
          GestureDetector(
            key: ValueKey('home-post-share-${widget.post.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: _openShare,
            child: SizedBox(
              width: 28,
              height: 28,
              child: Center(
                child: Transform.rotate(
                  angle: -0.35,
                  child: Icon(
                    Icons.send_outlined,
                    size: 18,
                    color: ClubUpColors.muted,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `like-action` / `comment-action` — an 18pt icon with its count beside it.
class _HomePostAction extends StatelessWidget {
  const _HomePostAction({
    super.key,
    required this.icon,
    required this.count,
    required this.color,
    required this.onTap,
    this.iconScale,
    this.motionKey,
  });

  final IconData icon;
  final int count;
  final Color color;
  final VoidCallback onTap;
  final Animation<double>? iconScale;
  final Key? motionKey;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    Widget iconWidget = AnimatedSwitcher(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.68, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: Icon(icon, key: ValueKey(icon), size: 18, color: color),
    );
    if (iconScale != null) {
      iconWidget = ScaleTransition(
        key: motionKey,
        scale: reduceMotion ? const AlwaysStoppedAnimation(1) : iconScale!,
        child: iconWidget,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        children: [
          iconWidget,
          RollingCount(
            value: count,
            style: figtree(
              size: 11,
              weight: FontWeight.w600,
              color: ClubUpColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// `follow-button` — a Home-only burgundy action box. [ClubFollowButton] is
/// shared with Explore and the club profile and stays untouched.
class _FollowText extends StatelessWidget {
  const _FollowText({
    required this.clubId,
    required this.fontSize,
    required this.color,
    required this.onChanged,
  });

  final String clubId;
  final double fontSize;
  final Color color;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: userState,
      builder: (context, _) {
        final following = userState.isFollowing(clubId);
        return GestureDetector(
          key: ValueKey('home-post-follow-$clubId'),
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            handleFollowTap(context, clubId, onChanged);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            height: 28,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: following ? Colors.transparent : ClubUpColors.accent,
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              border: Border.all(
                color: following ? ClubUpColors.border : ClubUpColors.accent,
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Text(
                following ? S.unfollow : AppLocalizations.of(context)!.follow,
                key: ValueKey(following),
                style: figtree(
                  size: fontSize,
                  weight: FontWeight.w700,
                  color: following ? color : Colors.white,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
