import 'package:flutter/material.dart';
import '../models/event.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/calendar_rsvp_helper.dart';
import '../services/rsvp_store.dart';

class RsvpButton extends StatefulWidget {
  final String eventId;
  final Color color;
  final bool isPast;
  final bool compact;
  final Event? event;

  const RsvpButton({
    super.key,
    required this.eventId,
    required this.color,
    this.isPast = false,
    this.compact = false,
    this.event,
  });

  @override
  State<RsvpButton> createState() => _RsvpButtonState();
}

class _RsvpButtonState extends State<RsvpButton> {
  String get _userId =>
      authService.isStudentSession ? authService.currentUser?.id ?? '' : '';

  void _syncCalendar(BuildContext context) {
    if (widget.event == null) return;
    syncRsvpToDeviceCalendar(context, widget.event!);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isPast || _userId.isEmpty) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: rsvpStore,
      builder: (ctx, _) {
        final attending = rsvpStore.isAttending(widget.eventId);
        final pending = rsvpStore.isPending(widget.eventId);

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: ScaleTransition(
              scale: Tween<double>(
                begin: 0.97,
                end: 1.0,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
              child: child,
            ),
          ),
          child: _build(ctx, attending, pending),
        );
      },
    );
  }

  Widget _build(BuildContext context, bool attending, bool pending) {
    void onToggle() {
      final wasAttending = rsvpStore.isAttending(widget.eventId);
      rsvpStore.toggle(widget.eventId, _userId);
      if (!wasAttending && widget.event != null) {
        _syncCalendar(context);
      }
    }

    // ── Compact ───────────────────────────────────────────────────────────────
    if (widget.compact) {
      if (attending) {
        return Row(
          key: const ValueKey('compact-attending'),
          mainAxisSize: MainAxisSize.min,
          children: [
            _CompactChip(
              label: '✓ Going',
              icon: Icons.check_circle_rounded,
              active: true,
              enabled: true,
              color: widget.color,
              onTap: onToggle,
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onToggle,
              child: AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 150),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.close,
                        size: 12,
                        color: AppColors.secondaryText,
                      ),
                      SizedBox(width: 3),
                      Text(
                        'Not Coming',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      }
      return _CompactChip(
        key: const ValueKey('compact-rsvp'),
        label: 'RSVP',
        icon: Icons.how_to_reg_rounded,
        active: false,
        enabled: true,
        color: widget.color,
        onTap: onToggle,
      );
    }

    // ── Full — attending ──────────────────────────────────────────────────────
    if (attending) {
      return SizedBox(
        key: const ValueKey('full-attending'),
        height: 56,
        // stretch → both the status pill and the Cancel button fill the full
        // 56px height (without this the pill collapses to its text height).
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // "You're going" status pill
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.color,
                      Color.lerp(widget.color, Colors.black, 0.15)!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.30),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          "You're going",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: 10),

            // "Cancel" secondary action
            GestureDetector(
              onTap: onToggle,
              child: Container(
                width: 96,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  border: Border.all(color: AppColors.divider, width: 1.5),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppColors.secondaryText,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── Full — not attending ──────────────────────────────────────────────────
    return SizedBox(
      key: const ValueKey('full-rsvp'),
      height: 56,
      width: double.infinity,
      child: GestureDetector(
        onTap: onToggle,
        child: AnimatedOpacity(
          opacity: 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.color,
                  Color.lerp(widget.color, Colors.black, 0.18)!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.all(Radius.circular(16)),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.how_to_reg_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'RSVP',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Compact chip ─────────────────────────────────────────────────────────────

class _CompactChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final bool enabled;
  final Color color;
  final VoidCallback onTap;

  const _CompactChip({
    super.key,
    required this.label,
    required this.icon,
    required this.active,
    required this.enabled,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled ? color : color.withValues(alpha: 0.45);

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: active
              ? LinearGradient(
                  colors: [color, Color.lerp(color, Colors.black, 0.15)!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: active ? null : Colors.transparent,
          borderRadius: BorderRadius.all(Radius.circular(20)),
          border: Border.all(color: effectiveColor, width: 1.5),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? Colors.white : effectiveColor),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : effectiveColor,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
