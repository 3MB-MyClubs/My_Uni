import 'package:flutter/material.dart';
import '../services/app_colors.dart';
import '../services/presence_service.dart';
import '../services/theme_service.dart';
import 'user_avatar.dart';

/// Shared messaging primitives recreated from the UniHub Messaging design:
/// grouped chat bubbles, date / info dividers, voice-note & photo bubbles,
/// read-receipt ticks, reaction chips, an in-thread typing indicator and the
/// morphing composer. Used by both the DM and the group conversation screens.

/// Online presence green (design used #2E9E5B light / #3FC477 dark).
Color get kOnlineGreen =>
    themeService.isDark ? const Color(0xFF3FC477) : const Color(0xFF2E9E5B);

// ─── Content protocol ─────────────────────────────────────────────────────────
// Special message payloads share the existing `prefix:` convention used for
// shared posts/events so plain text stays untouched.
//   kuvoice:<m:ss>          → voice note bubble (waveform synthesised from id)
//   kuphoto:<label-or-path> → photo bubble (striped placeholder + label)

bool isVoiceContent(String c) => c.startsWith('kuvoice:');
bool isPhotoContent(String c) => c.startsWith('kuphoto:');
String voiceDuration(String c) => c.substring('kuvoice:'.length);
String photoLabel(String c) => c.substring('kuphoto:'.length);

/// Deterministic 24-bar waveform from a seed (so a voice note always looks the
/// same). A tiny LCG keeps it stable without Math.random.
List<double> waveformFor(String seed) {
  var h = seed.hashCode & 0x7fffffff;
  final bars = <double>[];
  for (var i = 0; i < 24; i++) {
    h = (1103515245 * h + 12345) & 0x7fffffff;
    bars.add((h % 19 + 5).toDouble()); // 5..23 px
  }
  return bars;
}

// ─── Read-receipt ticks ─────────────────────────────────────────────────────
class ReadTicks extends StatelessWidget {
  /// 'sent' (single), 'delivered' (double muted), 'read' (double brand).
  final String status;
  final double size;
  const ReadTicks({super.key, required this.status, this.size = 15});

  @override
  Widget build(BuildContext context) {
    final read = status == 'read';
    final color = read ? AppColors.primaryRed : AppColors.secondaryText;
    return SizedBox(
      width: size + 4,
      height: size,
      child: CustomPaint(
        painter: _TicksPainter(color: color, showSecond: status != 'sent'),
      ),
    );
  }
}

class _TicksPainter extends CustomPainter {
  final Color color;
  final bool showSecond;
  _TicksPainter({required this.color, required this.showSecond});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final h = size.height;
    final w = size.width;
    // First check
    final path1 = Path()
      ..moveTo(w * 0.02, h * 0.55)
      ..lineTo(w * 0.22, h * 0.82)
      ..lineTo(w * 0.55, h * 0.18);
    canvas.drawPath(path1, p);
    if (showSecond) {
      final path2 = Path()
        ..moveTo(w * 0.42, h * 0.82)
        ..lineTo(w * 0.50, h * 0.92)
        ..lineTo(w * 0.92, h * 0.18);
      canvas.drawPath(path2, p);
    }
  }

  @override
  bool shouldRepaint(covariant _TicksPainter old) =>
      old.color != color || old.showSecond != showSecond;
}

// ─── Date / info divider ────────────────────────────────────────────────────
class ChatDivider extends StatelessWidget {
  final String label;
  final bool info; // info = pill style, otherwise hairline-with-label
  const ChatDivider({super.key, required this.label, this.info = false});

  @override
  Widget build(BuildContext context) {
    if (info) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: AppColors.divider)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: AppColors.secondaryText,
              ),
            ),
          ),
          Expanded(child: Container(height: 1, color: AppColors.divider)),
        ],
      ),
    );
  }
}

// ─── Voice-note bubble ──────────────────────────────────────────────────────
class VoiceBubble extends StatefulWidget {
  final String seed;
  final String duration;
  final bool mine;
  const VoiceBubble({
    super.key,
    required this.seed,
    required this.duration,
    required this.mine,
  });

  @override
  State<VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<VoiceBubble> {
  bool _playing = false;

  @override
  Widget build(BuildContext context) {
    final bars = waveformFor(widget.seed);
    final fg = widget.mine ? Colors.white : AppColors.text;
    final active = widget.mine ? Colors.white : AppColors.primaryRed;
    final dim = widget.mine
        ? Colors.white.withValues(alpha: 0.4)
        : AppColors.secondaryText;
    final played = _playing ? (bars.length * 0.55).round() : 0;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 172),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _playing = !_playing),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.mine
                    ? Colors.white.withValues(alpha: 0.18)
                    : AppColors.primaryRed,
              ),
              child: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 11),
          SizedBox(
            height: 30,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (var i = 0; i < bars.length; i++) ...[
                  Container(
                    width: 2.5,
                    height: bars[i].clamp(4, 28),
                    decoration: BoxDecoration(
                      color: i < played ? active : dim,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  if (i != bars.length - 1) const SizedBox(width: 2.5),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            widget.duration,
            style: TextStyle(
              fontSize: 11.5,
              color: fg.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Photo bubble ───────────────────────────────────────────────────────────
class PhotoBubble extends StatelessWidget {
  final String label;
  const PhotoBubble({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    const w = 200.0;
    const h = w * 0.72;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_outlined,
              size: 28,
              color: AppColors.secondaryText,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Chat bubble (grouped) ──────────────────────────────────────────────────
class ChatBubble extends StatelessWidget {
  final String messageId;
  final String content;
  final bool mine;
  final String time;
  final String? status; // mine only: sent | delivered | read
  final bool isGroup;
  final bool showName; // group, theirs: first of a run
  final bool showAvatar; // group, theirs: last of a run
  final String senderName;
  final Color senderColor;
  final String senderUserId;

  const ChatBubble({
    super.key,
    required this.messageId,
    required this.content,
    required this.mine,
    required this.time,
    this.status,
    this.isGroup = false,
    this.showName = true,
    this.showAvatar = true,
    this.senderName = '',
    this.senderColor = AppColors.primaryRed,
    this.senderUserId = '',
  });

  void _openReactionPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (final emoji in ReactionStore.palette)
              GestureDetector(
                onTap: () {
                  reactionStore.toggleReaction(messageId, emoji);
                  Navigator.pop(context);
                },
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(emoji, style: const TextStyle(fontSize: 26)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMedia = isPhotoContent(content);
    final showThemAvatar = !mine && isGroup;

    return Padding(
      padding: EdgeInsets.only(top: showName ? 8 : 2),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (showThemAvatar)
            showAvatar
                ? UserAvatar(
                    userId: senderUserId,
                    name: senderName,
                    size: 28,
                    fontSize: 11,
                  )
                : const SizedBox(width: 28),
          if (showThemAvatar) const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: mine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (showName && !mine && isGroup)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: Text(
                      senderName,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: senderColor,
                      ),
                    ),
                  ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.76,
                  ),
                  child: GestureDetector(
                    onLongPress: () => _openReactionPicker(context),
                    child: ListenableBuilder(
                      listenable: reactionStore,
                      builder: (context, _) {
                        final reaction = reactionStore.reactionFor(messageId);
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: isMedia
                                  ? const EdgeInsets.all(5)
                                  : const EdgeInsets.symmetric(
                                      horizontal: 13,
                                      vertical: 9,
                                    ),
                              decoration: BoxDecoration(
                                gradient: mine
                                    ? LinearGradient(
                                        colors: [
                                          AppColors.primaryRed,
                                          AppColors.darkRed,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                color: mine ? null : AppColors.card,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(20),
                                  topRight: const Radius.circular(20),
                                  bottomLeft: Radius.circular(mine ? 20 : 6),
                                  bottomRight: Radius.circular(mine ? 6 : 20),
                                ),
                                border: mine
                                    ? null
                                    : Border.all(color: AppColors.divider),
                                boxShadow: [
                                  BoxShadow(
                                    color: mine
                                        ? AppColors.primaryRed.withValues(
                                            alpha: 0.20,
                                          )
                                        : Colors.black.withValues(alpha: 0.05),
                                    blurRadius: mine ? 10 : 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: _bubbleContent(),
                            ),
                            if (reaction != null)
                              Positioned(
                                bottom: -11,
                                left: mine ? 8 : null,
                                right: mine ? null : 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.card,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: AppColors.divider,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.12,
                                        ),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    reaction,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                ListenableBuilder(
                  listenable: reactionStore,
                  builder: (context, _) {
                    final hasReaction =
                        reactionStore.reactionFor(messageId) != null;
                    return Padding(
                      padding: EdgeInsets.only(
                        top: hasReaction ? 13 : 4,
                        left: 3,
                        right: 3,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: AppColors.secondaryText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (mine && status != null) ...[
                            const SizedBox(width: 5),
                            ReadTicks(status: status!),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubbleContent() {
    if (isVoiceContent(content)) {
      return VoiceBubble(
        seed: messageId,
        duration: voiceDuration(content),
        mine: mine,
      );
    }
    if (isPhotoContent(content)) {
      return PhotoBubble(label: photoLabel(content));
    }
    return Text(
      content,
      style: TextStyle(
        color: mine ? Colors.white : AppColors.text,
        fontSize: 14.5,
        height: 1.45,
        letterSpacing: -0.1,
      ),
    );
  }
}

// ─── In-thread typing indicator ─────────────────────────────────────────────
class TypingBubble extends StatefulWidget {
  final bool isGroup;
  final String senderUserId;
  final String senderName;
  const TypingBubble({
    super.key,
    this.isGroup = false,
    this.senderUserId = '',
    this.senderName = '',
  });

  @override
  State<TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (widget.isGroup) ...[
            UserAvatar(
              userId: widget.senderUserId,
              name: widget.senderName,
              size: 28,
              fontSize: 11,
            ),
            const SizedBox(width: 8),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(6),
              ),
              border: Border.all(color: AppColors.divider),
            ),
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final t = (_c.value + i * 0.18) % 1.0;
                    final lift = t < 0.3
                        ? (t / 0.3)
                        : (t < 0.6 ? (1 - (t - 0.3) / 0.3) : 0.0);
                    return Padding(
                      padding: EdgeInsets.only(right: i == 2 ? 0 : 4),
                      child: Transform.translate(
                        offset: Offset(0, -3 * lift),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.secondaryText.withValues(
                              alpha: 0.45 + 0.55 * lift,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Composer ───────────────────────────────────────────────────────────────
class ChatComposer extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onCamera;
  final VoidCallback onMic;
  final String hint;

  const ChatComposer({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onAttach,
    required this.onCamera,
    required this.onMic,
    this.hint = 'Message…',
  });

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
  }

  void _sync() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 14,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Attach
            _circleBtn(
              icon: Icons.add_rounded,
              color: AppColors.primaryRed,
              filled: false,
              onTap: widget.onAttach,
            ),
            const SizedBox(width: 9),
            // Field + camera
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.only(left: 16, right: 6),
                decoration: BoxDecoration(
                  color: AppColors.lightGray,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: widget.controller,
                        minLines: 1,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: widget.hint,
                          hintStyle: TextStyle(color: AppColors.secondaryText),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 11,
                          ),
                        ),
                        onSubmitted: (_) => widget.onSend(),
                      ),
                    ),
                    GestureDetector(
                      onTap: widget.onCamera,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.photo_camera_outlined,
                          size: 22,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 9),
            // Mic ↔ Send morph
            GestureDetector(
              onTap: _hasText ? widget.onSend : widget.onMic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _hasText
                      ? LinearGradient(
                          colors: [AppColors.primaryRed, AppColors.darkRed],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: _hasText ? null : AppColors.surfaceAlt,
                  border: _hasText
                      ? null
                      : Border.all(color: AppColors.divider),
                  boxShadow: _hasText
                      ? [
                          BoxShadow(
                            color: AppColors.primaryRed.withValues(alpha: 0.33),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  _hasText ? Icons.send_rounded : Icons.mic_none_rounded,
                  size: 21,
                  color: _hasText ? Colors.white : AppColors.primaryRed,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleBtn({
    required IconData icon,
    required Color color,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? color : AppColors.surfaceAlt,
          border: filled ? null : Border.all(color: AppColors.divider),
        ),
        child: Icon(icon, size: 20, color: filled ? Colors.white : color),
      ),
    );
  }
}

/// Shared "attach" action sheet — lets photo & voice bubbles be reached
/// interactively (they render as designed states, per the prototype).
Future<String?> showAttachSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 6),
            _attachTile(context, Icons.image_outlined, 'Photo', 'photo'),
            _attachTile(context, Icons.mic_none_rounded, 'Voice note', 'voice'),
            const SizedBox(height: 6),
          ],
        ),
      ),
    ),
  );
}

Widget _attachTile(
  BuildContext context,
  IconData icon,
  String label,
  String value,
) {
  return ListTile(
    leading: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.lightRed,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: AppColors.primaryRed, size: 21),
    ),
    title: Text(
      label,
      style: TextStyle(
        color: AppColors.text,
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
    ),
    onTap: () => Navigator.pop(context, value),
  );
}

// ─── Date-label helper shared by both conversation screens ──────────────────
String chatDateLabel(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff < 7) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dt.weekday - 1];
  }
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[dt.month - 1]} ${dt.day}';
}

/// Short clock label (HH:mm) for a bubble's meta line.
String chatClock(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
