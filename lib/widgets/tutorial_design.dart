import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/theme_service.dart';
import 'clubup_design.dart';

/// Design tokens and primitives for the `STUDENT UI · IN-APP TUTORIAL` board
/// in ClubUp-Desings (`canvas-tutorial-kit` `391:4`, frames `tut-*` at
/// y≈34000).
///
/// One coach-mark pattern is reused across every student page: a dimmed scrim
/// with a cut-out spotlight on the element being taught, a card that explains
/// it in one sentence, and a Skip / Back / Next footer.
///
/// **The drawn frames render this card in `#1DA1F2` blue.** That is a leftover
/// from the template they were built on — the mocks underneath them are the
/// stale blue home feed too. The kit board `panel-tokens` (`391:124`, a newer
/// node) states "Burgundy 800020 is the only accent", the dark frames already
/// draw their spotlight ring in `#E8A1B0`, and step 2's own body copy reads
/// "The tab you are on turns burgundy". Burgundy is what is implemented.
class TutorialColors {
  const TutorialColors._();

  static bool get _dark => themeService.isDark;

  /// Card surface — `#FFFFFF` / `#18181B`. Sampled from `tut-chats-tabs-light`
  /// and `tut-profile-hero-dark`.
  static Color get card => _dark ? const Color(0xFF18181B) : Colors.white;

  /// The card's 1px hairline — `#E4E4E7` / `#27272A`.
  static Color get border =>
      _dark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7);

  /// Card title — `#18181B` / `#FFFFFF`.
  static Color get title => _dark ? Colors.white : const Color(0xFF18181B);

  /// Card body — `#52525B` zinc-600 / `#A1A1AA` zinc-400.
  static Color get body =>
      _dark ? const Color(0xFFA1A1AA) : const Color(0xFF52525B);

  /// Footnote and the "Skip tour" control — one step quieter than [body].
  static Color get muted =>
      _dark ? const Color(0xFF8B8B93) : const Color(0xFF71717A);

  /// The primary pill's fill. `panel-tokens` lists the burgundy under
  /// "Accent · ring, dots, primary pill" and the dark tint under "Accent on
  /// dark · eyebrow, ring" — the pill is deliberately absent from the dark
  /// entry, so it keeps the full-strength burgundy in both themes and carries
  /// white text.
  static const Color accent = Color(0xFF800020);

  /// Accent *ink* — eyebrow, spotlight ring, glow and progress dots.
  /// `#800020` fails contrast on an `#18181B` card, so dark lifts it to the
  /// `#E8A1B0` the dark frames' rings are drawn in.
  static Color get accentInk => _dark ? const Color(0xFFE8A1B0) : accent;

  /// The wash behind the finish card — the accent at 14%, matching the
  /// `#E2F1FE` (accent-at-13%-over-white) sampled from `tut-finish-light`.
  static Color get accentWash =>
      Color.alphaBlend(accent.withValues(alpha: _dark ? 0.16 : 0.14), card);

  /// Idle progress dot.
  static Color get dotIdle =>
      _dark ? const Color(0xFF3F3F46) : const Color(0xFFE4E4E7);

  /// The secondary "Back" pill.
  static Color get secondaryFill =>
      _dark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5);

  /// The dimmed page behind the tour — `#09090B` at 74% in light, `#000000` at
  /// 80% in dark. Verified by sampling: `#FAF9F6` under the light scrim lands
  /// on `#484748`, and `#09090B` under the dark one on `#020202`.
  static Color get scrim => _dark
      ? const Color(0xFF000000).withValues(alpha: 0.80)
      : const Color(0xFF09090B).withValues(alpha: 0.74);

  /// `0 18 40 rgba(0,0,0,0.30)` on the card.
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: _dark ? 0.45 : 0.30),
      offset: const Offset(0, 18),
      blurRadius: 40,
    ),
  ];
}

/// Geometry from `panel-coach-mark` `391:10` and `panel-spotlight` `391:73`,
/// cross-checked against every `tut-*` frame.
class TutorialMetrics {
  const TutorialMetrics._();

  /// A coach card is a fixed 306 wide and hugs its content vertically. Turkish
  /// runs ~20% longer than English, so the height is never fixed.
  static const double cardWidth = 306;

  /// Welcome and Tour-complete centre a wider card and drop the beak.
  static const double fullScreenCardWidth = 330;

  static const double cardRadius = 22;

  /// Measured from the card's outer edge, as Figma reports it: text sits at
  /// x=20 in a 306-wide card, so the content column is 266.
  static const double padTop = 18;
  static const double padSide = 20;
  static const double padBottom = 18;

  /// The card's 1px stroke. Flutter's [Border] is drawn inside the box *and*
  /// insets the child, while Figma's is drawn on the box and does not — so the
  /// padding is reduced by the stroke to land the content on 20/18.
  static const double hairline = 1;

  /// Every block inside the card is separated by the same 10.
  static const double blockGap = 10;

  static const double beakWidth = 20;
  static const double beakHeight = 10;

  /// The beak's tip clears the spotlight by 5, and the card sits 14 clear —
  /// so the beak overlaps the card's top edge by 1 and hides the seam.
  static const double beakClearance = 5;

  /// Target bounds are inflated by 8 on every side to make the cut-out.
  static const double spotlightInset = 8;

  /// 2px accent stroke on the hole.
  static const double ringWidth = 2;

  /// A 6px accent stroke at 30%, sitting 5px outside the ring.
  static const double glowWidth = 6;
  static const double glowOffset = 5;

  /// Clearance between the spotlight and the card.
  static const double clearance = 14;

  /// Minimum gap from the screen edge.
  static const double screenEdge = 12;

  /// The beak is clamped this far inside the card's edge.
  static const double beakEdgeClamp = 16;

  static const double footerHeight = 34;
  static const double buttonHeight = 34;
  static const double buttonPadding = 15;

  static const double dotHeight = 6;
  static const double dotWidth = 6;
  static const double dotActiveWidth = 20;
  static const double dotGap = 5;

  /// Corner radius of the cut-out, which "matches the element being taught,
  /// from 14 px on a chip to 30 px on the floating nav".
  static const double radiusChip = 14;
  static const double radiusCard = 20;
  static const double radiusNav = 30;
  static const double radiusPill = 999;
}

// ── Type ramp (`type-ramp` 391:163) ─────────────────────────────────────────

TextStyle tutorialEyebrowStyle() => figtree(
  size: 10,
  weight: FontWeight.w800,
  color: TutorialColors.accentInk,
  height: 14 / 10,
  letterSpacing: 0.8, // 8% tracking
);

TextStyle tutorialTitleStyle() => figtree(
  size: 17,
  weight: FontWeight.w700,
  color: TutorialColors.title,
  height: 22 / 17,
);

TextStyle tutorialFullScreenTitleStyle() => figtree(
  size: 20,
  weight: FontWeight.w700,
  color: TutorialColors.title,
  height: 26 / 20,
);

TextStyle tutorialBodyStyle() => figtree(
  size: 13,
  weight: FontWeight.w400,
  color: TutorialColors.body,
  height: 19 / 13,
);

TextStyle tutorialFootnoteStyle({Color? color}) => figtree(
  size: 11,
  weight: FontWeight.w500,
  color: color ?? TutorialColors.muted,
  height: 16 / 11,
);

TextStyle tutorialSkipStyle() => figtree(
  size: 12,
  weight: FontWeight.w600,
  color: TutorialColors.muted,
  height: 16 / 12,
);

TextStyle tutorialPillStyle(Color color) => figtree(
  size: 12.5,
  weight: FontWeight.w700,
  color: color,
  height: 16 / 12.5,
);

// ── Controls ────────────────────────────────────────────────────────────────

/// `btn-Next` / `btn-Got it` — a 34-tall stadium pill, 15pt of padding either
/// side of a Bold 12.5 label.
class TutorialPillButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  /// Primary pills carry the burgundy fill; the secondary "Back" pill is a
  /// flat neutral.
  final bool primary;

  const TutorialPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = true,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = primary ? Colors.white : TutorialColors.title;
    return Semantics(
      button: true,
      child: Material(
        color: primary ? TutorialColors.accent : TutorialColors.secondaryFill,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            height: TutorialMetrics.buttonHeight,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(
              horizontal: TutorialMetrics.buttonPadding,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tutorialPillStyle(foreground),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "Skip tour" text control. It sits on the left of every card's footer so
/// it stays reachable on every step, and it is the first focusable control.
class TutorialSkipButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  /// Placed on the tappable itself so tests can hit the control rather than
  /// the [Semantics] wrapper.
  final Key? buttonKey;

  const TutorialSkipButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.buttonKey,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      // Carries its own Material so the control never depends on an ancestor
      // one — the tutorial is stacked over whatever screen it is teaching.
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: buttonKey,
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            // Keeps the label's box on the footer's left edge while giving the
            // control a 34-tall tap target.
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
            child: Text(label, style: tutorialSkipStyle()),
          ),
        ),
      ),
    );
  }
}

/// `progress` — pill dots, 6 tall, the active one widened to 20. Hidden
/// entirely on single-step pages.
class TutorialProgressDots extends StatelessWidget {
  final int index;
  final int total;

  const TutorialProgressDots({
    super.key,
    required this.index,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            margin: EdgeInsets.only(
              right: i == total - 1 ? 0 : TutorialMetrics.dotGap,
            ),
            width: i == index
                ? TutorialMetrics.dotActiveWidth
                : TutorialMetrics.dotWidth,
            height: TutorialMetrics.dotHeight,
            decoration: BoxDecoration(
              color: i == index
                  ? TutorialColors.accentInk
                  : TutorialColors.dotIdle,
              borderRadius: BorderRadius.circular(
                TutorialMetrics.dotHeight / 2,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Painters ────────────────────────────────────────────────────────────────

/// The scrim, drawn as one shape with the target subtracted out of it so the
/// real UI stays readable and nothing underneath is redrawn or restyled.
class TutorialScrimPainter extends CustomPainter {
  final Rect? spotlight;
  final double radius;
  final Color color;

  const TutorialScrimPainter({
    required this.spotlight,
    required this.radius,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    final hole = spotlight;
    if (hole != null && !hole.isEmpty) {
      path.addRRect(
        RRect.fromRectAndRadius(
          hole,
          Radius.circular(math.min(radius, hole.shortestSide / 2)),
        ),
      );
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant TutorialScrimPainter oldDelegate) =>
      oldDelegate.spotlight != spotlight ||
      oldDelegate.color != color ||
      oldDelegate.radius != radius;
}

/// `spotlight-ring` + `spotlight-glow` — a 2px accent stroke on the edge of the
/// hole, plus a 6px accent stroke at 30% sitting 5px outside it.
///
/// Painted in a box that has already been inflated by [TutorialMetrics.glowOffset]
/// + half the glow stroke, so the hole itself is this box deflated by that much.
class TutorialSpotlightRingPainter extends CustomPainter {
  final double radius;
  final Color color;

  /// How far the paint box was inflated past the hole.
  final double outset;

  const TutorialSpotlightRingPainter({
    required this.radius,
    required this.color,
    required this.outset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final hole = (Offset.zero & size).deflate(outset);
    if (hole.isEmpty) return;
    final holeRadius = Radius.circular(math.min(radius, hole.shortestSide / 2));

    // The glow's 6px stroke is centred 5px outside the hole's edge, i.e. on a
    // rect inflated by glowOffset.
    final glowRect = hole.inflate(TutorialMetrics.glowOffset);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        glowRect,
        Radius.circular(holeRadius.x + TutorialMetrics.glowOffset),
      ),
      Paint()
        ..color = color.withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = TutorialMetrics.glowWidth,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(hole, holeRadius),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = TutorialMetrics.ringWidth,
    );
  }

  @override
  bool shouldRepaint(covariant TutorialSpotlightRingPainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.color != color ||
      oldDelegate.outset != outset;
}

/// The 20 × 10 beak that points at the spotlight, filled and hairlined to
/// match the card it hangs off.
class TutorialBeakPainter extends CustomPainter {
  /// True when the card sits *below* the spotlight, so the beak points up.
  final bool pointsUp;
  final Color fill;
  final Color border;

  const TutorialBeakPainter({
    required this.pointsUp,
    required this.fill,
    required this.border,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (pointsUp) {
      path
        ..moveTo(0, size.height)
        ..lineTo(size.width / 2, 0)
        ..lineTo(size.width, size.height);
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = fill);

    // Only the two slanted sides are stroked — the base is the card's own edge.
    final edge = Path();
    if (pointsUp) {
      edge
        ..moveTo(0, size.height)
        ..lineTo(size.width / 2, 0)
        ..lineTo(size.width, size.height);
    } else {
      edge
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0);
    }
    canvas.drawPath(
      edge,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant TutorialBeakPainter oldDelegate) =>
      oldDelegate.pointsUp != pointsUp ||
      oldDelegate.fill != fill ||
      oldDelegate.border != border;
}

/// The card shell every tutorial card shares: fixed width, hugged height,
/// 22px radius, 1px border and the drop shadow.
class TutorialCardShell extends StatelessWidget {
  final double width;
  final Widget child;

  /// The finish card is washed in the accent and hairlined in it.
  final bool accented;

  const TutorialCardShell({
    super.key,
    required this.width,
    required this.child,
    this.accented = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: accented ? TutorialColors.accentWash : TutorialColors.card,
        borderRadius: BorderRadius.circular(TutorialMetrics.cardRadius),
        border: Border.all(
          color: accented ? TutorialColors.accentInk : TutorialColors.border,
          width: TutorialMetrics.hairline,
        ),
        boxShadow: [
          ...TutorialColors.cardShadow,
          if (accented)
            BoxShadow(
              color: TutorialColors.accentInk.withValues(alpha: 0.22),
              blurRadius: 28,
              spreadRadius: -4,
            ),
        ],
      ),
      child: Padding(
        // See [TutorialMetrics.hairline]: the border has already eaten 1pt on
        // every side, so the frame's 20/18 is that plus this.
        padding: const EdgeInsets.fromLTRB(
          TutorialMetrics.padSide - TutorialMetrics.hairline,
          TutorialMetrics.padTop - TutorialMetrics.hairline,
          TutorialMetrics.padSide - TutorialMetrics.hairline,
          TutorialMetrics.padBottom - TutorialMetrics.hairline,
        ),
        child: child,
      ),
    );
  }
}

// ── Placement ───────────────────────────────────────────────────────────────

/// Where the beak is drawn and which way it points.
class TutorialBeak {
  final double left;
  final double top;
  final bool pointsUp;

  const TutorialBeak({
    required this.left,
    required this.top,
    required this.pointsUp,
  });
}

/// A card rect plus the beak that hangs off it, or no beak when the card is
/// not attached to a spotlight.
class TutorialCardPlacement {
  final Rect card;
  final TutorialBeak? beak;

  const TutorialCardPlacement({required this.card, this.beak});
}

/// `Card placement` (`391:117`) — "14 px clear of the spotlight, horizontally
/// centred on it, clamped 12 px from the screen edge. It flips above or below
/// when there is no room."
///
/// Shared by the tour and the standalone page tips so the two never drift.
/// [hole] is the cut-out, i.e. the target already inflated by
/// [TutorialMetrics.spotlightInset]; pass null to centre the card with no beak.
TutorialCardPlacement placeTutorialCard({
  required Size screen,
  required EdgeInsets safeArea,
  required Rect? hole,
  required Size cardSize,
}) {
  const edge = TutorialMetrics.screenEdge;
  final minX = edge;
  final maxX = math.max(edge, screen.width - edge);
  final minY = math.max(edge, safeArea.top + edge);
  final maxY = math.max(minY, screen.height - safeArea.bottom - edge);

  final width = math.min(cardSize.width, maxX - minX);
  final height = math.min(cardSize.height, maxY - minY);

  if (hole == null) {
    return TutorialCardPlacement(
      card: Rect.fromLTWH(
        ((screen.width - width) / 2)
            .clamp(minX, math.max(minX, maxX - width))
            .toDouble(),
        ((screen.height - height) / 2)
            .clamp(minY, math.max(minY, maxY - height))
            .toDouble(),
        width,
        height,
      ),
    );
  }

  final left = (hole.center.dx - width / 2)
      .clamp(minX, math.max(minX, maxX - width))
      .toDouble();

  final below = hole.bottom + TutorialMetrics.clearance;
  final above = hole.top - TutorialMetrics.clearance - height;

  double top;
  bool? pointsUp;
  if (below + height <= maxY) {
    top = below;
    pointsUp = true;
  } else if (above >= minY) {
    top = above;
    pointsUp = false;
  } else {
    // Neither side fits — sit the card wherever there is most room and drop
    // the beak rather than point it through the target.
    final roomBelow = maxY - hole.bottom;
    final roomAbove = hole.top - minY;
    top = roomBelow >= roomAbove ? math.max(minY, maxY - height) : minY;
    pointsUp = null;
  }

  final card = Rect.fromLTWH(left, top, width, height);
  if (pointsUp == null) return TutorialCardPlacement(card: card);

  // "The beak lands on the centre of the target, clamped 16 px inside the
  // card edge."
  const half = TutorialMetrics.beakWidth / 2;
  final minCenter = card.left + TutorialMetrics.beakEdgeClamp + half;
  final maxCenter = card.right - TutorialMetrics.beakEdgeClamp - half;
  final beakCenter = maxCenter <= minCenter
      ? card.center.dx
      : hole.center.dx.clamp(minCenter, maxCenter).toDouble();

  return TutorialCardPlacement(
    card: card,
    beak: TutorialBeak(
      left: beakCenter - half,
      // Overlaps the card's edge by 1 so the seam never shows.
      top: pointsUp
          ? card.top - TutorialMetrics.beakHeight + 1
          : card.bottom - 1,
      pointsUp: pointsUp,
    ),
  );
}

/// The scrim, ring and glow for one cut-out, as a single positioned layer.
/// [hole] is in the coordinate space of the stack this is dropped into.
class TutorialSpotlight extends StatelessWidget {
  final Rect? hole;
  final double radius;

  const TutorialSpotlight({super.key, required this.hole, required this.radius});

  /// How far past the hole the ring layer's box must reach to hold the glow's
  /// outer half.
  static const double ringOutset =
      TutorialMetrics.glowOffset + (TutorialMetrics.glowWidth / 2);

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: TutorialScrimPainter(
                spotlight: hole,
                radius: radius,
                color: TutorialColors.scrim,
              ),
            ),
          ),
        ),
        if (hole != null)
          Positioned.fromRect(
            rect: hole!.inflate(ringOutset),
            child: IgnorePointer(
              child: CustomPaint(
                painter: TutorialSpotlightRingPainter(
                  radius: radius,
                  color: TutorialColors.accentInk,
                  outset: ringOutset,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The 20 × 10 beak, positioned by [placeTutorialCard].
class TutorialBeakView extends StatelessWidget {
  final TutorialBeak beak;

  const TutorialBeakView({super.key, required this.beak});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(TutorialMetrics.beakWidth, TutorialMetrics.beakHeight),
      painter: TutorialBeakPainter(
        pointsUp: beak.pointsUp,
        fill: TutorialColors.card,
        border: TutorialColors.border,
      ),
    );
  }
}

/// The full-screen moments — `tut-welcome` and `tut-finish`.
///
/// "Welcome and Tour complete drop the cut-out, dim the whole screen and
/// centre a 330 px card. No beak." Same 18/20/18 padding and 10pt rhythm as
/// the coach card, with a 20/26 title and a footnote block the coach card
/// does not have.
class TutorialMomentCard extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String body;
  final String footnote;

  /// The finish card puts its footnote in the accent and washes the card;
  /// the welcome card keeps both neutral.
  final bool accented;

  final String secondaryLabel;
  final VoidCallback onSecondary;
  final String primaryLabel;
  final VoidCallback onPrimary;

  const TutorialMomentCard({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.footnote,
    required this.secondaryLabel,
    required this.onSecondary,
    required this.primaryLabel,
    required this.onPrimary,
    this.accented = false,
  });

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: TutorialCardShell(
        width: TutorialMetrics.fullScreenCardWidth,
        accented: accented,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(eyebrow, style: tutorialEyebrowStyle()),
            const SizedBox(height: TutorialMetrics.blockGap),
            Text(title, style: tutorialFullScreenTitleStyle()),
            const SizedBox(height: TutorialMetrics.blockGap),
            Text(body, style: tutorialBodyStyle()),
            const SizedBox(height: TutorialMetrics.blockGap),
            Text(
              footnote,
              style: tutorialFootnoteStyle(
                color: accented ? TutorialColors.accentInk : null,
              ),
            ),
            const SizedBox(height: TutorialMetrics.blockGap),
            SizedBox(
              height: TutorialMetrics.footerHeight,
              child: Row(
                children: [
                  // Same rule as the coach card's footer: the pill takes its
                  // natural width and the secondary control absorbs the rest,
                  // so a long label is never truncated to share flex space.
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TutorialSkipButton(
                        label: secondaryLabel,
                        onPressed: onSecondary,
                      ),
                    ),
                  ),
                  TutorialPillButton(
                    label: primaryLabel,
                    onPressed: onPrimary,
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
