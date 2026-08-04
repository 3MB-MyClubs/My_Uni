import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/event.dart';
import '../l10n/app_localizations.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/calendar_rsvp_helper.dart';
import '../services/rsvp_store.dart';
import 'app_pressable.dart';

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

class _RsvpButtonState extends State<RsvpButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confirmationController;
  late final Animation<double> _confirmationPulse;
  bool? _lastAttending;

  String get _userId =>
      authService.isStudentSession ? authService.currentUser?.id ?? '' : '';

  @override
  void initState() {
    super.initState();
    _confirmationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 440),
      value: 1,
    );
    _confirmationPulse =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1, end: 1.055), weight: 34),
          TweenSequenceItem(tween: Tween(begin: 1.055, end: 0.985), weight: 28),
          TweenSequenceItem(tween: Tween(begin: 0.985, end: 1), weight: 38),
        ]).animate(
          CurvedAnimation(
            parent: _confirmationController,
            curve: Curves.easeOut,
          ),
        );
  }

  void _syncCalendar(BuildContext context) {
    if (widget.event == null) return;
    syncRsvpToDeviceCalendar(context, widget.event!);
  }

  void _playConfirmationMotion() {
    if (!mounted ||
        _confirmationController.isAnimating ||
        MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    _confirmationController.forward(from: 0);
  }

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isPast || _userId.isEmpty) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: rsvpStore,
      builder: (ctx, _) {
        final attending = rsvpStore.isAttending(widget.eventId);
        final pending = rsvpStore.isPending(widget.eventId);
        final newlyConfirmed = _lastAttending == false && attending;
        _lastAttending = attending;
        if (newlyConfirmed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && rsvpStore.isAttending(widget.eventId)) {
              _playConfirmationMotion();
            }
          });
        }

        return AnimatedBuilder(
          animation: _confirmationPulse,
          child: AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 220),
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
          ),
          builder: (context, child) => Transform.scale(
            key: const ValueKey('rsvp-confirmation-pulse'),
            scale: MediaQuery.disableAnimationsOf(context)
                ? 1
                : _confirmationPulse.value,
            child: child,
          ),
        );
      },
    );
  }

  Widget _build(BuildContext context, bool attending, bool pending) {
    void onToggle() {
      final wasAttending = rsvpStore.isAttending(widget.eventId);
      if (!wasAttending) {
        HapticFeedback.lightImpact();
        _playConfirmationMotion();
      } else {
        HapticFeedback.selectionClick();
      }
      unawaited(rsvpStore.toggle(widget.eventId, _userId));
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
              label: '✓ ${AppLocalizations.of(context)!.going}',
              icon: Icons.check_circle_rounded,
              active: true,
              enabled: true,
              color: widget.color,
              onTap: onToggle,
            ),
            const SizedBox(width: 6),
            AppPressable(
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
                        AppLocalizations.of(context)!.notComing,
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
        label: AppLocalizations.of(context)!.rsvp,
        icon: Icons.how_to_reg_rounded,
        active: false,
        enabled: true,
        color: widget.color,
        onTap: onToggle,
      );
    }

    // ── Full — attending ──────────────────────────────────────────────────────
    // Cancel-only: once you're in, the affirmation is redundant — the one thing
    // left to do here is back out, so the slot becomes a single quiet button.
    if (attending) {
      return SizedBox(
        key: const ValueKey('full-attending'),
        height: 56,
        width: double.infinity,
        child: AppPressable(
          onTap: onToggle,
          pressedScale: 0.98,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.all(Radius.circular(16)),
              border: Border.all(color: AppColors.divider, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.secondaryText,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    AppLocalizations.of(context)!.cancel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondaryText,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── Full — not attending ──────────────────────────────────────────────────
    return SizedBox(
      key: const ValueKey('full-rsvp'),
      height: 56,
      width: double.infinity,
      child: AppPressable(
        onTap: onToggle,
        pressedScale: 0.98,
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
                const Icon(
                  Icons.how_to_reg_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    AppLocalizations.of(context)!.rsvp,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      // words, not an acronym — tight tracking, per the design
                      letterSpacing: -0.2,
                    ),
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

    return AppPressable(
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
