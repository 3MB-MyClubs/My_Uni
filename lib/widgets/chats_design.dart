import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/theme_service.dart';
import '../theme/specialized_semantic_palettes.dart';
import 'clubup_design.dart';

/// The CHATS area of the ClubUp-Desings handoff (Figma section label `258:4`).
///
/// Frames this file draws, light id first:
///
/// * `chats-light` / `chats-dark` — `243:462` / `243:573` (dropdown open) and
///   `243:685` / `243:785` (closed). The `84:209` and `219:208` pairs are
///   older copies of the same two screens.
/// * `chat-dm` `102:7` / `102:65`, `chat-group` `102:123` / `102:207`,
///   `chats-clubs` `225:5` / `225:74`.
/// * `group-info` `104:6` / `104:94`, `edit-group-info` `107:6` / `107:84`,
///   `group-menu` `105:7` / `105:98`, `shared-media` `105:189` / `105:227`,
///   `add-member` `105:329` / `105:390`, `leave-group` `105:451` / `105:486`,
///   `member-actions` `108:7` / `108:89`, `search-results` `110:84` / `110:232`.
///
/// As in every other redesigned area these widgets are deliberately *local*:
/// nothing outside the chats screens draws them, so restyling here cannot
/// reach a screen whose design has not been reviewed. Typography comes from
/// [figtree]; colors do not — see [ChatsColors].

// ── tokens ───────────────────────────────────────────────────────────────────

/// Palette for the chat frames.
///
/// Light matches [ClubUpColors] exactly. Dark is a **third** ramp, distinct
/// from both [ClubUpColors] (`#121212` / `#1E1E1E` / `#2D2D2D`) and
/// `ProfileColors` (zinc-950 `#09090B` / `#18181B` / `#27272A`): the chat
/// frames put the page on `#121212`, cards on `#1A1A1A`, and use `#2D2D2D`
/// for both the hairline and every filled surface. Values sampled from the
/// frame PNGs rather than read off layer names.
///
/// One more divergence worth knowing: on these frames the small-caps section
/// labels *do* lift to `#E8A1A6` in dark, where the profile frames keep
/// `#800020`. Hence [accent] and [accentText] being separate tokens.
class ChatsColors {
  const ChatsColors._();

  /// Active-theme semantic pairings for new and migrated chat widgets.
  static SpecializedSemanticPalette of(BuildContext context) =>
      SpecializedSemanticPalettes.chats(Theme.of(context));

  static bool get _dark => themeService.isDark;

  /// Page background — `#FAF9F6` / `#121212`.
  static Color get background =>
      _dark ? const Color(0xFF121212) : const Color(0xFFFAF9F6);

  /// Card surface, and the bottom sheets — `#FFFFFF` / `#1A1A1A`.
  static Color get card => _dark ? const Color(0xFF1A1A1A) : Colors.white;

  /// Every filled surface: search bars, text inputs, incoming bubbles, the
  /// round quick-action buttons — `#EFEEEF` / `#2D2D2D`.
  static Color get fill =>
      _dark ? const Color(0xFF2D2D2D) : const Color(0xFFEFEEEF);

  /// Hairlines: card outlines, header rules, in-card dividers, the 1px line
  /// between inbox rows — `#E4E4E7` / `#2D2D2D`.
  static Color get border =>
      _dark ? const Color(0xFF2D2D2D) : const Color(0xFFE4E4E7);

  /// Primary text — `#18181B` / `#FAFAFA`.
  static Color get text =>
      _dark ? const Color(0xFFFAFAFA) : const Color(0xFF18181B);

  /// Secondary text: message previews, subtitles, placeholders, the day
  /// divider — `#71717A` / `#A1A1AA`.
  static Color get muted =>
      _dark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);

  /// The single accent. Outgoing bubbles, the send button, the unread badge,
  /// active tabs — `#800020` in **both** themes.
  static const Color accent = Color(0xFF800020);

  /// Accent *text and icons*, which lift in dark — `#800020` / `#E8A1A6`.
  static Color get accentText =>
      _dark ? const Color(0xFFE8A1A6) : const Color(0xFF800020);

  /// Back arrows stay neutral instead of borrowing the pink accent in dark
  /// mode. Light mode uses the primary ink so the icon remains visible.
  static Color get backIcon => _dark ? Colors.white : text;

  /// Text on [accent].
  static const Color onAccent = Colors.white;

  /// The faint wash behind an unread inbox row — `#F8F4F2` / `#1E1E1E`.
  static Color get unreadRow =>
      _dark ? const Color(0xFF1E1E1E) : const Color(0xFFF8F4F2);

  /// The wash a row shows for a beat when it matches the live search query.
  /// Not from the handoff — the frames are static — so it is deliberately the
  /// accent at a low alpha rather than a new hue. Dark uses [accentText]'s
  /// pink, because burgundy at 10% over `#121212` is invisible.
  static Color get searchFlash => _dark
      ? const Color(0xFFE8A1A6).withValues(alpha: 0.16)
      : const Color(0xFF800020).withValues(alpha: 0.10);

  /// Destructive rows and the leave-group button. This is a true red, not the
  /// brand burgundy — `#DC2626` / `#EF4444`.
  static Color get danger =>
      _dark ? const Color(0xFFEF4444) : const Color(0xFFDC2626);

  /// Modal scrim behind a dialog or sheet.
  static Color get scrim => Colors.black.withValues(alpha: _dark ? 0.55 : 0.32);
}

/// Per-speaker name colors above incoming group bubbles. The handoff cycles
/// amber / blue / emerald at the 600 weight in light and the 400 weight in
/// dark; the last three continue that pattern so a group larger than the
/// mock's three speakers keeps distinct names.
const List<Color> _senderAccentsLight = [
  Color(0xFFD97706), // amber-600
  Color(0xFF2563EB), // blue-600
  Color(0xFF059669), // emerald-600
  Color(0xFF7C3AED), // violet-600
  Color(0xFF0F766E), // teal-700
  Color(0xFF0891B2), // cyan-600
];

const List<Color> _senderAccentsDark = [
  Color(0xFFFBBF24), // amber-400
  Color(0xFF60A5FA), // blue-400
  Color(0xFF34D399), // emerald-400
  Color(0xFFA78BFA), // violet-400
  Color(0xFF2DD4BF), // teal-400
  Color(0xFF22D3EE), // cyan-400
];

/// A stable name color for [userId], so a busy group thread stays readable.
Color chatSenderAccent(String userId) {
  if (userId.isEmpty) return ChatsColors.muted;
  final palette = themeService.isDark
      ? _senderAccentsDark
      : _senderAccentsLight;
  return palette[userId.hashCode.abs() % palette.length];
}

/// One soft accent pulse on a row that matches the live search query, in the
/// spirit of Instagram's inbox search: the hit lights up for a beat as the
/// results settle, then fades back to the plain row.
///
/// [builder] receives the wash — [Colors.transparent] at rest — instead of
/// wrapping the row, because an inbox row already paints its own background
/// ([ChatsColors.unreadRow]) and the pulse has to blend *under* the ink and
/// the content rather than over them.
class ChatSearchFlash extends StatefulWidget {
  const ChatSearchFlash({
    super.key,
    required this.token,
    required this.active,
    required this.builder,
  });

  /// Changes whenever the row should pulse again. Callers combine the trimmed
  /// query with the row's own id, so a row pulses both when the query moves
  /// under it and when a new match slides into its slot.
  final String token;

  /// False when no search is running; the row then stays flat and no pulse is
  /// scheduled, so the plain inbox is untouched.
  final bool active;

  final Widget Function(BuildContext context, Color wash) builder;

  @override
  State<ChatSearchFlash> createState() => _ChatSearchFlashState();
}

class _ChatSearchFlashState extends State<ChatSearchFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 820),
  );

  /// Quick in, a short hold, a slow out — a keystroke lands before the fade
  /// starts, so typing reads as a sustained glow instead of a strobe.
  late final Animation<double> _pulse = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 20,
    ),
    TweenSequenceItem(tween: ConstantTween<double>(1), weight: 20),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 0,
      ).chain(CurveTween(curve: Curves.easeInCubic)),
      weight: 60,
    ),
  ]).animate(_controller);

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant ChatSearchFlash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active) {
      // Clearing the field drops the wash on the next frame anyway; stopping
      // the ticker keeps a half-finished pulse from burning frames behind it.
      _controller.stop();
      return;
    }
    if (widget.token != oldWidget.token || !oldWidget.active) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = widget.active ? _pulse.value : 0.0;
        return widget.builder(
          context,
          t == 0
              ? Colors.transparent
              : ChatsColors.searchFlash.withValues(
                  alpha: ChatsColors.searchFlash.a * t,
                ),
        );
      },
    );
  }
}

/// Corner radius shared by bubbles, cards and inputs across the area.
const double kChatBubbleRadius = 16;
const double kChatCardRadius = 12;
const double kChatSheetRadius = 24;
const double kChatDialogRadius = 22;

// ── chrome ───────────────────────────────────────────────────────────────────

/// The 48pt bar at the top of every pushed chat screen: a bare chevron, a
/// title, and an optional trailing action. `group-info` `104:17`.
class ChatsTopBar extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final VoidCallback? onBack;

  const ChatsTopBar({
    super.key,
    required this.title,
    this.trailing,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ChatsColors.of(context);
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.viewPaddingOf(context).top),
      color: colors.background,
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            const SizedBox(width: 16),
            Semantics(
              button: true,
              label: MaterialLocalizations.of(context).backButtonTooltip,
              child: GestureDetector(
                key: const ValueKey('chats-top-bar-back'),
                behavior: HitTestBehavior.opaque,
                onTap: onBack ?? () => Navigator.maybePop(context),
                child: SizedBox(
                  width: 24,
                  height: 48,
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: 24,
                    color: colors.onBackground,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: figtree(
                  size: 16,
                  weight: FontWeight.w700,
                  color: colors.onBackground,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
              const SizedBox(width: 16),
            ] else
              const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}

/// The small-caps label that opens each card — `Description`, `Members`,
/// `Group Name`. Accent-colored, and the one place [ChatsColors.accentText]
/// visibly differs from [ChatsColors.accent].
class ChatsSectionLabel extends StatelessWidget {
  final String text;

  const ChatsSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final colors = ChatsColors.of(context);
    return Text(
      text.toUpperCase(),
      style: figtree(
        size: 11,
        weight: FontWeight.w700,
        color: colors.brandForeground,
        letterSpacing: 0.7,
      ),
    );
  }
}

/// A white card with a hairline outline — `group-info` `104:49`.
class ChatsCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const ChatsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ChatsColors.of(context);
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(kChatCardRadius),
        border: Border.all(color: ChatsColors.border),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: colors.onSurface),
        child: IconTheme.merge(
          data: IconThemeData(color: colors.onSurface),
          child: child,
        ),
      ),
    );
  }
}

/// The 1px rule inside a card, between member rows or danger rows.
class ChatsCardDivider extends StatelessWidget {
  const ChatsCardDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: ChatsColors.border);
}

/// One of the three round quick actions under the group avatar — Mute,
/// Search, Media. `group-info` `104:37`.
class ChatsCircleAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  const ChatsCircleAction({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ChatsColors.of(context);
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active
                    ? colors.brand.withValues(alpha: 0.12)
                    : colors.subtleSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: colors.brandForeground),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: figtree(
                size: 11,
                weight: FontWeight.w600,
                color: colors.supporting,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A full-width accent button — `edit-group-info`'s Save Changes (`107:82`).
class ChatsPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const ChatsPrimaryButton({super.key, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final colors = ChatsColors.of(context);
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled ? colors.brand : colors.brand.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(kChatCardRadius),
          ),
          child: Text(
            label,
            style: figtree(
              size: 15,
              weight: FontWeight.w700,
              color: colors.onBrand,
            ),
          ),
        ),
      ),
    );
  }
}

/// The labelled input used by `edit-group-info` — a [ChatsColors.fill] box
/// with an optional trailing glyph.
class ChatsInputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final int? maxLength;
  final IconData? trailingIcon;
  final Key? fieldKey;
  final ValueChanged<String>? onChanged;

  const ChatsInputField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.maxLines = 1,
    this.maxLength,
    this.trailingIcon,
    this.fieldKey,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ChatsColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChatsSectionLabel(label),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          constraints: BoxConstraints(minHeight: maxLines > 1 ? 100 : 48),
          decoration: BoxDecoration(
            color: colors.subtleSurface,
            borderRadius: BorderRadius.circular(kChatCardRadius),
          ),
          child: Row(
            crossAxisAlignment: maxLines > 1
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  key: fieldKey,
                  controller: controller,
                  maxLines: maxLines,
                  minLines: 1,
                  maxLength: maxLength,
                  onChanged: onChanged,
                  textCapitalization: TextCapitalization.sentences,
                  style: figtree(
                    size: 14,
                    weight: FontWeight.w500,
                    color: colors.onSubtleSurface,
                    height: 1.45,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: figtree(
                      size: 14,
                      weight: FontWeight.w400,
                      color: colors.supporting,
                    ),
                    counterText: '',
                    isDense: true,
                    // The box already paints the fill; without this the global
                    // inputDecorationTheme stacks a second one on top.
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: maxLines > 1 ? 10 : 12,
                    ),
                  ),
                ),
              ),
              if (trailingIcon != null)
                Padding(
                  padding: EdgeInsets.only(top: maxLines > 1 ? 10 : 0),
                  child: Icon(trailingIcon, size: 16, color: colors.supporting),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── message list ─────────────────────────────────────────────────────────────

/// The centered `TODAY` rule between days — `102:31`.
class ChatDayDivider extends StatelessWidget {
  final String label;

  const ChatDayDivider({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = ChatsColors.of(context);
    return SizedBox(
      height: 37,
      child: Center(
        child: Text(
          label.toUpperCase(),
          style: figtree(
            size: 11,
            weight: FontWeight.w600,
            color: colors.supporting,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

/// Horizontal strip a bubble reserves beside its body for the tail. Every
/// bubble keeps the strip whether or not it draws a tail, so bubbles in a
/// sender run stay flush with each other and nothing has to overflow its box.
const double kChatBubbleTailWidth = 8;

/// How far up the bubble's side the tail flares before it sweeps out.
const double kChatBubbleTailRise = 13;

/// A message bubble with a small WhatsApp-style tail at the end of a sender
/// run. [showTail] is decided by the message list, because only the bottom
/// bubble in a consecutive run should point toward its sender.
///
/// Body and tail are one filled path, so the tail grows out of a squared-off
/// bottom corner exactly the way WhatsApp's does instead of floating beside a
/// rounded one.
class ChatBubbleShell extends StatelessWidget {
  final bool mine;
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final bool showTail;

  const ChatBubbleShell({
    super.key,
    required this.mine,
    required this.child,
    required this.maxWidth,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.showTail = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ChatsColors.of(context);
    final fill = mine ? colors.brand : colors.subtleSurface;
    final foreground = mine ? colors.onBrand : colors.onSubtleSurface;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return TweenAnimationBuilder<double>(
      // A null `begin` settles on `end` without animating, so the first build
      // paints its final shape and only later run changes are tweened.
      tween: Tween<double>(end: showTail ? 1 : 0),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      builder: (context, tail, _) => CustomPaint(
        painter: _ChatBubblePainter(color: fill, mine: mine, tail: tail),
        child: Padding(
          // The reserved tail strip sits on the sender's side.
          padding: mine
              ? const EdgeInsets.only(right: kChatBubbleTailWidth)
              : const EdgeInsets.only(left: kChatBubbleTailWidth),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: foreground),
            child: IconTheme.merge(
              data: IconThemeData(color: foreground),
              child: Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                padding: padding,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the bubble body and its tail as a single union'd path, so there is
/// no seam where the two meet and no gap left by the rounded corner.
class _ChatBubblePainter extends CustomPainter {
  const _ChatBubblePainter({
    required this.color,
    required this.mine,
    required this.tail,
  });

  final Color color;
  final bool mine;

  /// 0 = plain rounded bubble, 1 = fully extended tail.
  final double tail;

  @override
  void paint(Canvas canvas, Size size) {
    // Built in outgoing (tail on the right) coordinates and mirrored for
    // incoming bubbles, which keeps one description of the shape.
    if (!mine) {
      canvas
        ..save()
        ..translate(size.width, 0)
        ..scale(-1, 1);
    }
    canvas.drawPath(
      _shape(size),
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
    if (!mine) canvas.restore();
  }

  Path _shape(Size size) {
    final bodyWidth = size.width - kChatBubbleTailWidth;
    final height = size.height;
    const radius = Radius.circular(kChatBubbleRadius);
    // The tail's corner squares off as the tail grows, the way it does in
    // WhatsApp: the tail reads as the corner continuing outward.
    final body = RRect.fromLTRBAndCorners(
      0,
      0,
      bodyWidth,
      height,
      topLeft: radius,
      topRight: radius,
      bottomLeft: radius,
      bottomRight: Radius.circular(kChatBubbleRadius * (1 - tail)),
    );
    if (tail <= 0.001) return Path()..addRRect(body);

    // Short bubbles (a lone emoji, a one-line reply) must not have the tail
    // eat their whole side, so the flare is capped at half the height.
    final rise = math.min(kChatBubbleTailRise, height / 2);
    final tip = bodyWidth + kChatBubbleTailWidth * tail;
    // The wedge starts inside the body so the union has nothing to crack open.
    final base = bodyWidth - 3;
    final wedge = Path()
      ..moveTo(base, height - rise)
      ..cubicTo(
        bodyWidth,
        height - rise * 0.52,
        bodyWidth + (tip - bodyWidth) * 0.42,
        height - rise * 0.14,
        tip,
        height - 1.4,
      )
      // A hair of rounding on the tip, then flush along the bubble's baseline.
      ..quadraticBezierTo(tip, height, tip - 1.6, height)
      ..lineTo(base, height)
      ..close();
    return Path.combine(PathOperation.union, Path()..addRRect(body), wedge);
  }

  @override
  bool shouldRepaint(covariant _ChatBubblePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.mine != mine ||
      oldDelegate.tail != tail;
}

/// Body text inside a bubble — 14/20, and white on an outgoing bubble.
TextStyle chatBubbleTextStyle({required bool mine}) => figtree(
  size: 14,
  weight: FontWeight.w400,
  color: mine ? ChatsColors.onAccent : ChatsColors.text,
  height: 1.43,
);

/// The composer: paperclip, pill, send. 72pt tall with 36pt controls —
/// `102:54`.
class ChatComposerBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool enabled;
  final String hint;
  final VoidCallback? onAttach;
  final VoidCallback? onSend;

  /// When set, an empty pill shows a camera button in the trailing slot
  /// (a live capture), and it morphs into the send button as soon as a
  /// draft exists. When null the trailing slot is always the send button.
  final VoidCallback? onCameraCapture;
  final IconData attachIcon;
  final Widget? banner;

  const ChatComposerBar({
    super.key,
    required this.controller,
    required this.enabled,
    required this.hint,
    this.focusNode,
    this.onAttach,
    this.onSend,
    this.onCameraCapture,
    this.attachIcon = Icons.attach_file_rounded,
    this.banner,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ChatsColors.background,
        border: Border(top: BorderSide(color: ChatsColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (banner != null) ...[banner!, const SizedBox(height: 10)],
              Row(
                children: [
                  _CircleButton(
                    buttonKey: const ValueKey('chat-attach-button'),
                    icon: attachIcon,
                    iconSize: 18,
                    background: ChatsColors.fill,
                    iconColor: ChatsColors.accentText,
                    onTap: enabled ? onAttach : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 36),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: ChatsColors.fill,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Center(
                        child: TextField(
                          controller: controller,
                          focusNode: focusNode,
                          enabled: enabled,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: enabled ? (_) => onSend?.call() : null,
                          style: figtree(
                            size: 14,
                            weight: FontWeight.w400,
                            color: ChatsColors.text,
                          ),
                          decoration: InputDecoration(
                            hintText: hint,
                            hintStyle: figtree(
                              size: 14,
                              weight: FontWeight.w400,
                              color: ChatsColors.muted,
                            ),
                            isDense: true,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) {
                      final hasDraft =
                          enabled && controller.text.trim().isNotEmpty;
                      final send = _CircleButton(
                        buttonKey: const ValueKey('chat-send-button'),
                        icon: Icons.send_rounded,
                        iconSize: 16,
                        // `send-button` 102:60 is solid in every state on
                        // the frame; only the tap is gated.
                        background: ChatsColors.accent,
                        iconColor: hasDraft
                            ? ChatsColors.onAccent
                            : ChatsColors.onAccent.withValues(alpha: 0.55),
                        onTap: hasDraft ? onSend : null,
                      );
                      if (onCameraCapture == null) return send;
                      // One constant accent circle whose glyph swaps: a
                      // camera while the pill is empty, the send arrow once
                      // a draft exists. Only the glyph cross-fades, so the
                      // hand-off reads as the same button changing jobs.
                      return _ComposerTrailingSwap(
                        showSend: hasDraft,
                        send: send,
                        camera: _CircleButton(
                          buttonKey: const ValueKey('chat-camera-button'),
                          icon: Icons.photo_camera_rounded,
                          iconSize: 17,
                          background: ChatsColors.accent,
                          iconColor: enabled
                              ? ChatsColors.onAccent
                              : ChatsColors.onAccent.withValues(alpha: 0.55),
                          onTap: enabled ? onCameraCapture : null,
                        ),
                      );
                    },
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

/// The composer's trailing slot: cross-fades between the camera (empty pill)
/// and the send button (draft present) on one shared clock.
///
/// Both buttons stay mounted so each identity key exists at most once no
/// matter how quickly the draft toggles — an [AnimatedSwitcher] here would
/// briefly stack a second, still-fading copy of a button (and its test key)
/// when a send is followed by immediate retyping. The hidden side is kept
/// [Offstage] and behind [IgnorePointer], so it neither hit-tests nor shows
/// up in semantics or default finders.
class _ComposerTrailingSwap extends StatefulWidget {
  final bool showSend;
  final Widget send;
  final Widget camera;

  const _ComposerTrailingSwap({
    required this.showSend,
    required this.send,
    required this.camera,
  });

  @override
  State<_ComposerTrailingSwap> createState() => _ComposerTrailingSwapState();
}

class _ComposerTrailingSwapState extends State<_ComposerTrailingSwap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    value: widget.showSend ? 1 : 0,
  );

  @override
  void didUpdateWidget(covariant _ComposerTrailingSwap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showSend == oldWidget.showSend) return;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller.value = widget.showSend ? 1 : 0;
    } else if (widget.showSend) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // The active side is onstage from its first frame — even before its fade
  // has visibly started — so it is findable and tappable the moment the
  // draft state flips; only a fully faded *inactive* side leaves the stage.
  Widget _staged(Widget child, double visibility, bool active) => Offstage(
    offstage: !active && visibility == 0,
    child: IgnorePointer(
      ignoring: !active,
      child: Opacity(
        opacity: visibility,
        child: Transform.scale(scale: 0.7 + 0.3 * visibility, child: child),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        return Stack(
          alignment: Alignment.center,
          children: [
            _staged(widget.camera, 1 - t, !widget.showSend),
            _staged(widget.send, t, widget.showSend),
          ],
        );
      },
    );
  }
}

class _CircleButton extends StatefulWidget {
  final Key buttonKey;
  final IconData icon;
  final double iconSize;
  final Color background;
  final Color iconColor;
  final VoidCallback? onTap;

  const _CircleButton({
    required this.buttonKey,
    required this.icon,
    required this.iconSize,
    required this.background,
    required this.iconColor,
    this.onTap,
  });

  @override
  State<_CircleButton> createState() => _CircleButtonState();
}

class _CircleButtonState extends State<_CircleButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration = reduceMotion
        ? Duration.zero
        : _pressed
        ? const Duration(milliseconds: 70)
        : const Duration(milliseconds: 170);
    return GestureDetector(
      key: widget.buttonKey,
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
      onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
      onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1,
        duration: duration,
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.9 : 1,
          duration: duration,
          curve: Curves.easeOutCubic,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.background,
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.icon,
              size: widget.iconSize,
              color: widget.iconColor,
            ),
          ),
        ),
      ),
    );
  }
}

// ── sheets and dialogs ───────────────────────────────────────────────────────

/// One row of a chat bottom sheet.
class ChatsMenuAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  /// Draw a hairline immediately above this row. The handoff separates the
  /// destructive block from the rest of `group-menu` this way.
  final bool dividerAbove;
  final Key? rowKey;

  const ChatsMenuAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.dividerAbove = false,
    this.rowKey,
  });
}

/// The `group-menu` sheet (`105:59`) and the `member-actions` sheet
/// (`108:61`): a drag handle, an optional identity header, then 52pt rows
/// separated by hairlines.
Future<void> showChatsMenuSheet(
  BuildContext context, {
  required List<ChatsMenuAction> actions,
  Widget? header,
  Key? sheetKey,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: ChatsColors.scrim,
    // A member-actions sheet with every row on offer is ~340pt tall, which
    // overflows the default 9/16 cap on a short screen. Let it size itself and
    // scroll instead of clipping a destructive row off the bottom.
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
    ),
    builder: (sheetContext) => Container(
      key: sheetKey,
      decoration: BoxDecoration(
        color: ChatsColors.card,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(kChatSheetRadius),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: ChatsColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              if (header != null) ...[
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: header,
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const ChatsCardDivider(),
                ),
                const SizedBox(height: 16),
              ] else
                const SizedBox(height: 24),
              for (final action in actions) ...[
                if (action.dividerAbove)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: const ChatsCardDivider(),
                  ),
                _MenuRow(action: action),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    ),
  );
}

class _MenuRow extends StatelessWidget {
  final ChatsMenuAction action;

  const _MenuRow({required this.action});

  @override
  Widget build(BuildContext context) {
    final color = action.destructive
        ? ChatsColors.danger
        : ChatsColors.accentText;
    return InkWell(
      key: action.rowKey,
      onTap: () {
        Navigator.pop(context);
        action.onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              Icon(action.icon, size: 20, color: color),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: figtree(
                    size: 14,
                    weight: FontWeight.w600,
                    color: action.destructive
                        ? ChatsColors.danger
                        : ChatsColors.text,
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

/// The `leave-group` dialog (`105:474`): centered title and body, a solid
/// [ChatsColors.danger] confirm and an outlined cancel. Returns true when the
/// destructive action was chosen.
Future<bool> showChatsConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  required String cancelLabel,
  Key? confirmKey,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: ChatsColors.scrim,
    builder: (dialogContext) => Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Material(
          color: ChatsColors.card,
          borderRadius: BorderRadius.circular(kChatDialogRadius),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: figtree(
                    size: 18,
                    weight: FontWeight.w800,
                    color: ChatsColors.text,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: figtree(
                    size: 14,
                    weight: FontWeight.w400,
                    color: ChatsColors.muted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    key: confirmKey,
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(dialogContext, true),
                    child: Container(
                      height: 47,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: ChatsColors.danger,
                        borderRadius: BorderRadius.circular(kChatCardRadius),
                      ),
                      child: Text(
                        confirmLabel,
                        style: figtree(
                          size: 15,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(dialogContext, false),
                    child: Container(
                      height: 47,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: ChatsColors.card,
                        borderRadius: BorderRadius.circular(kChatCardRadius),
                        border: Border.all(color: ChatsColors.border),
                      ),
                      child: Text(
                        cancelLabel,
                        style: figtree(
                          size: 15,
                          weight: FontWeight.w700,
                          color: ChatsColors.muted,
                        ),
                      ),
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
  return result ?? false;
}
