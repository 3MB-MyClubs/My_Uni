import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/content_audience.dart';
import '../services/app_strings.dart';
import '../services/theme_service.dart';
import 'brief_toast.dart';
import 'clubup_design.dart';

/// The one audience picker, shared by the post composer and the event wizard.
///
/// Those two screens live in different palette worlds — the composer is on the
/// legacy warm `AppColors` set, the wizard on `EventWizardColors` with its
/// lifted dark accent — and neither owns the other's tokens. Rather than fork
/// the sheet or reach across areas, the caller passes its own five colours in.
/// The chrome reproduces the event wizard's sheet (radius-32 top, a 36×5 handle,
/// a 24/12 padded title row) because that is the established sheet shape in this
/// flow, but it does not import the wizard's private `_WizardSheet`.
///
/// Tapping an option pops with it, so there is no Done pill to plumb and one
/// fewer tap than the date and time sheets need. Returns null when dismissed.
Future<ContentAudience?> showContentAudienceSheet(
  BuildContext context, {
  required ContentAudience current,
  required Color surface,
  required Color border,
  required Color text,
  required Color muted,
  required Color accent,
}) {
  return showModalBottomSheet<ContentAudience>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x66000000),
    builder: (sheetContext) => _ContentAudienceSheet(
      current: current,
      surface: surface,
      border: border,
      text: text,
      muted: muted,
      accent: accent,
    ),
  );
}

class _ContentAudienceSheet extends StatelessWidget {
  const _ContentAudienceSheet({
    required this.current,
    required this.surface,
    required this.border,
    required this.text,
    required this.muted,
    required this.accent,
  });

  final ContentAudience current;
  final Color surface;
  final Color border;
  final Color text;
  final Color muted;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('content-audience-sheet'),
      decoration: BoxDecoration(
        color: surface,
        border: Border(top: BorderSide(color: border)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: muted,
                  borderRadius: const BorderRadius.all(Radius.circular(100)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      S.audienceSheetTitle,
                      style: figtree(
                        size: 16,
                        weight: FontWeight.w700,
                        color: text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (final audience in ContentAudience.values)
              _AudienceOptionRow(
                audience: audience,
                selected: audience == current,
                text: text,
                muted: muted,
                accent: accent,
                onTap: () => Navigator.pop(context, audience),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// One option: a ring, the tier name, and the line that says who that actually
/// means. The description is the reason this is not the app's existing radio
/// row — "Followers" alone does not tell a club president what they are picking.
class _AudienceOptionRow extends StatelessWidget {
  const _AudienceOptionRow({
    required this.audience,
    required this.selected,
    required this.text,
    required this.muted,
    required this.accent,
    required this.onTap,
  });

  final ContentAudience audience;
  final bool selected;
  final Color text;
  final Color muted;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        key: ValueKey('content-audience-option-${audience.wireValue}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? accent : muted,
                    width: 2,
                  ),
                ),
                child: selected
                    ? Center(
                        child: Container(
                          key: ValueKey(
                            'content-audience-selected-${audience.wireValue}',
                          ),
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accent,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      S.audienceTierLabel(audience),
                      style: figtree(
                        size: 14,
                        weight: FontWeight.w600,
                        color: text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      S.audienceTierHint(audience),
                      style: figtree(
                        size: 12,
                        weight: FontWeight.w400,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The glyph that stands for a tier.
///
/// A padlock for the board tier and a pair of people for followers, rather than
/// one generic eye for both. Since the badge lost its label this glyph carries
/// the meaning on its own at 12-14px, until the reader taps it for the bubble.
IconData audienceTierIcon(ContentAudience audience) => switch (audience) {
  ContentAudience.everyone => Icons.public,
  ContentAudience.followers => Icons.group_outlined,
  ContentAudience.board => Icons.lock_outline,
};

/// How long a bubble stays up before it fades on its own.
///
/// Long enough to read the Turkish line, which is the longer of the two, and
/// short enough that a bubble left behind by a mis-tap does not follow the
/// reader down the feed.
const Duration _audienceBubbleLinger = Duration(seconds: 3);

/// Below this many pixels of headroom the bubble flips under the icon instead
/// of over it — the event hero's badge sits near the top of the screen.
const double _audienceBubbleHeadroom = 88;

/// The mark a restricted post or event carries next to its timestamp (posts) or
/// its date chip (events), and the bubble it pops when tapped.
///
/// Renders nothing for [ContentAudience.everyone] — public content is the
/// overwhelming majority and a mark on all of it would say nothing.
///
/// This replaced a text badge ("Followers only" / "Board only"). The label was
/// the widest thing on a dense event row, it wrapped to a second line in
/// Turkish, and it needed a legible-accent token from every palette it visited.
/// A glyph beside the time costs one line of nothing, reads the same in both
/// languages, and moves the words into a bubble the reader asks for.
///
/// Two variants, because restricted content shows on two kinds of surface:
///
/// * The default **bare glyph**, tinted with whatever muted or accent colour
///   the host area already gives the line it sits on.
/// * [ContentAudienceIcon.onMedia] for a mark laid over a cover photo, which
///   brings its own dark disc and white glyph so it stays legible over an
///   arbitrary photograph.
///
/// The bubble is an [OverlayEntry] linked to the icon, so it floats over the
/// card's clip and follows the icon while the list scrolls; it closes on the
/// next tap anywhere, when the list scrolls, and after
/// [_audienceBubbleLinger]. The icon swallows its own tap, so it never opens
/// the card it is drawn on.
class ContentAudienceIcon extends StatefulWidget {
  const ContentAudienceIcon({
    super.key,
    required this.audience,
    required Color color,
    this.size = 14,
  }) : _color = color,
       _onMedia = false;

  /// The over-a-photo variant. Takes no colour: a cover image is arbitrary, so
  /// the mark brings its own contrast rather than borrowing the club's.
  const ContentAudienceIcon.onMedia({
    super.key,
    required this.audience,
    this.size = 12,
  }) : _color = Colors.white,
       _onMedia = true;

  final ContentAudience audience;

  /// Glyph size. The tap target adds padding around it without moving the
  /// glyph, so a caller can shrink this to match a small caption line.
  final double size;

  final Color _color;
  final bool _onMedia;

  @override
  State<ContentAudienceIcon> createState() => _ContentAudienceIconState();
}

class _ContentAudienceIconState extends State<ContentAudienceIcon>
    with SingleTickerProviderStateMixin {
  final LayerLink _link = LayerLink();

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
    reverseDuration: const Duration(milliseconds: 110),
  );

  /// Built once rather than per rebuild: a `CurvedAnimation` holds a listener
  /// on its parent and has to be disposed, so a fresh one each build leaks.
  late final CurvedAnimation _pop = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeIn,
  );

  OverlayEntry? _entry;

  /// Whether the bubble *should* be up. Distinct from `_entry != null`, which
  /// stays true through the fade-out, so a re-tap mid-fade reuses the entry
  /// rather than racing its removal.
  bool _visible = false;

  Timer? _linger;
  ScrollPosition? _scroll;

  /// Geometry resolved once per show, from where the icon sits on screen.
  bool _below = false;

  /// -1 left edge, 0 centred, 1 right edge — which end of the bubble the tail
  /// hangs from, so a bubble near a screen edge grows inward.
  int _side = 0;

  /// How far in from that edge the tail sits, and therefore how far the bubble
  /// shifts to leave the tail over the glyph. [_tailInset] unless the glyph is
  /// closer than that to the screen edge.
  double _tailShift = _tailInset;
  double _maxWidth = 240;

  @override
  void dispose() {
    _visible = false;
    _linger?.cancel();
    _scroll?.removeListener(_hide);
    _removeEntry();
    _pop.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// The only path that takes the entry out of the overlay. It nulls the field
  /// first, so a late fade-out callback and [dispose] can both call it.
  void _removeEntry() {
    final entry = _entry;
    _entry = null;
    if (entry == null) return;
    entry.remove();
    entry.dispose();
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    if (_visible) {
      _hide();
    } else {
      _show();
    }
  }

  void _show() {
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.maybeOf(context);
    final overlayBox = overlay?.context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || overlay == null) return;
    if (overlayBox == null || !overlayBox.hasSize) return;

    final origin = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    final width = overlayBox.size.width;
    final centerX = origin.dx + box.size.width / 2;
    _below = origin.dy < _audienceBubbleHeadroom;
    final ratio = width <= 0 ? 0.5 : centerX / width;
    _side = ratio < 0.34
        ? -1
        : ratio > 0.66
        ? 1
        : 0;
    // A glyph closer to the edge than the tail's own inset gets a shorter
    // shift, so the bubble stops at the edge with the tail still over it.
    _tailShift = switch (_side) {
      -1 => math.min(_tailInset, math.max(0, centerX)),
      1 => math.min(_tailInset, math.max(0, width - centerX)),
      _ => _tailInset,
    };
    // Cap the width by the room on the side the bubble grows into: the tail is
    // pinned to the glyph now, so a long tier string can no longer be balanced
    // by sliding the whole bubble back inward.
    final room = switch (_side) {
      -1 => width - (centerX - _tailShift) - 8,
      1 => centerX + _tailShift - 8,
      _ => width - 24,
    };
    _maxWidth = math.min(248, math.max(120, room));

    _visible = true;
    if (_entry == null) {
      _entry = OverlayEntry(builder: _buildBubble);
      overlay.insert(_entry!);
    } else {
      // Still fading out from the last tap: reuse it with the fresh geometry.
      _entry!.markNeedsBuild();
    }
    _controller.forward();

    _linger?.cancel();
    _linger = Timer(_audienceBubbleLinger, _hide);
    // The bubble follows the icon while the list moves, but a card scrolling
    // away would leave it floating over whatever took its place.
    _scroll = Scrollable.maybeOf(context)?.position;
    _scroll?.addListener(_hide);
  }

  void _hide() {
    if (!_visible) return;
    _visible = false;
    _linger?.cancel();
    _linger = null;
    _scroll?.removeListener(_hide);
    _scroll = null;
    // Reverse rather than removing here: [_hide] runs from a scroll listener
    // too, and taking an overlay entry out during that frame's layout throws.
    _controller.reverse().whenComplete(() {
      if (!_visible) _removeEntry();
    });
  }

  /// The scale grows out of the tail, so the bubble reads as coming from the
  /// icon rather than appearing beside it.
  Alignment get _growFrom => Alignment(_side.toDouble(), _below ? -1 : 1);

  CrossAxisAlignment get _tailAlignment => switch (_side) {
    -1 => CrossAxisAlignment.start,
    1 => CrossAxisAlignment.end,
    _ => CrossAxisAlignment.center,
  };

  Alignment get _followerAnchor => switch (_side) {
    -1 => _below ? Alignment.topLeft : Alignment.bottomLeft,
    1 => _below ? Alignment.topRight : Alignment.bottomRight,
    _ => _below ? Alignment.topCenter : Alignment.bottomCenter,
  };

  /// The tail hangs [_tailShift] in from the bubble's anchored edge, so an
  /// edge-anchored bubble has to slide that far *outward* — towards its own
  /// anchor — to leave the tail over the glyph instead of beside it.
  static const double _tailInset = 14;
  static const double _tailWidth = 12;
  static const double _tailHeight = 6;

  /// The 3 eats the glyph's own tap padding, so the tail tip lands on the
  /// icon rather than floating a few pixels off it.
  Offset get _followerOffset => Offset(_side * _tailShift, _below ? -3 : 3);

  Widget _buildBubble(BuildContext context) {
    final surface = bubbleSurfaceColor(themeService.isDark);
    final tail = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: _side == 0 ? 0 : math.max(0, _tailShift - _tailWidth / 2),
      ),
      child: CustomPaint(
        size: const Size(_tailWidth, _tailHeight),
        painter: _AudienceBubbleTail(color: surface, pointsUp: _below),
      ),
    );

    return Stack(
      children: [
        // An opaque barrier, not a translucent one: the next tap dismisses the
        // bubble and must not also open the card underneath it.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _hide,
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          child: CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: _below ? Alignment.bottomCenter : Alignment.topCenter,
            followerAnchor: _followerAnchor,
            offset: _followerOffset,
            child: FadeTransition(
              opacity: _controller,
              child: ScaleTransition(
                alignment: _growFrom,
                scale: _pop,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: _tailAlignment,
                  children: [
                    if (_below) tail,
                    Container(
                      key: const ValueKey('content-audience-bubble'),
                      constraints: BoxConstraints(maxWidth: _maxWidth),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x30000000),
                            offset: Offset(0, 4),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      // `DefaultTextStyle`, not a styled `Text`: an overlay
                      // entry sits outside the page's `Material`, and a
                      // `Text` there merges with the framework's error style
                      // — the yellow debug underline.
                      child: DefaultTextStyle(
                        style: figtree(
                          size: 11.5,
                          weight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.25,
                        ),
                        child: Text(S.audienceTierBubble(widget.audience)),
                      ),
                    ),
                    if (!_below) tail,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.audience == ContentAudience.everyone) {
      return const SizedBox.shrink();
    }
    final glyph = Icon(
      audienceTierIcon(widget.audience),
      size: widget.size,
      color: widget._color,
    );
    return Semantics(
      button: true,
      label: S.audienceTierBubble(widget.audience),
      child: CompositedTransformTarget(
        link: _link,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: Padding(
            // Widens the tap target without moving the glyph off the line it
            // shares with the timestamp.
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            child: widget._onMedia
                ? Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0x8C000000),
                      shape: BoxShape.circle,
                    ),
                    child: glyph,
                  )
                : glyph,
          ),
        ),
      ),
    );
  }
}

/// The little triangle that joins the bubble to the icon.
class _AudienceBubbleTail extends CustomPainter {
  const _AudienceBubbleTail({required this.color, required this.pointsUp});

  final Color color;

  /// True when the bubble hangs below the icon and the tail points back up at
  /// it; false for the usual bubble-above-icon case.
  final bool pointsUp;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (pointsUp) {
      path
        ..moveTo(0, size.height)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width / 2, 0);
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_AudienceBubbleTail oldDelegate) =>
      oldDelegate.color != color || oldDelegate.pointsUp != pointsUp;
}
