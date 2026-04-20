import 'package:flutter/material.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/rsvp_store.dart';

/// Shared RSVP button widget — identical behavior across every screen.
///
/// [compact] = true  → inline chip row (feed cards, action bars)
/// [compact] = false → full-height bar (event detail bottom nav, modals)
///
/// States:
///   • isPast=true         → disabled "This event has passed" (full) or "Passed" chip
///   • attending=false     → "RSVP" (tappable)
///   • attending=true      → "✓ You are attending" indicator + "Not Coming" button
///
/// All reads come from [rsvpStore]; widget rebuilds automatically on any change.
class RsvpButton extends StatelessWidget {
  final String eventId;
  final Color color;
  final bool isPast;
  final bool compact;

  const RsvpButton({
    super.key,
    required this.eventId,
    required this.color,
    this.isPast = false,
    this.compact = false,
  });

  String get _userId => authService.currentUser?.id ?? '';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: rsvpStore,
      builder: (context, _) {
        final attending = rsvpStore.isAttending(eventId);
        final pending = rsvpStore.isPending(eventId);

        void onToggle() {
          if (pending) return;
          rsvpStore.toggle(eventId, _userId);
        }

        // ── Past ─────────────────────────────────────────────────────────────
        if (isPast) {
          if (compact) {
            return _Chip(
              label: 'Passed',
              icon: Icons.event_busy_rounded,
              filled: false,
              enabled: false,
              color: AppColors.secondaryText,
              onTap: () {},
            );
          }
          return SizedBox(
            height: 52,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: null,
              style: ElevatedButton.styleFrom(
                disabledBackgroundColor: AppColors.surfaceAlt,
                disabledForegroundColor: AppColors.secondaryText,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('This event has passed',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          );
        }

        // ── Compact mode ─────────────────────────────────────────────────────
        if (compact) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Chip(
                label: attending ? '✓ Going' : 'RSVP',
                icon: attending
                    ? Icons.check_circle_rounded
                    : Icons.how_to_reg_rounded,
                filled: attending,
                enabled: !pending && !attending,
                color: color,
                onTap: attending ? () {} : onToggle,
              ),
              if (attending) ...[
                const SizedBox(width: 6),
                _Chip(
                  label: 'Not Coming',
                  icon: Icons.cancel_outlined,
                  filled: false,
                  enabled: !pending,
                  color: AppColors.secondaryText,
                  onTap: onToggle,
                ),
              ],
            ],
          );
        }

        // ── Full mode — attending ─────────────────────────────────────────────
        if (attending) {
          return Row(
            children: [
              Expanded(
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '✓ You are attending',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: color),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: pending ? null : onToggle,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.secondaryText,
                    side: const BorderSide(color: AppColors.divider),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  child: const Text('Not Coming',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          );
        }

        // ── Full mode — not attending ─────────────────────────────────────────
        return SizedBox(
          height: 52,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: pending ? null : onToggle,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: const Text('RSVP',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }
}

// ─── Compact chip ──────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final bool enabled;
  final Color color;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.icon,
    required this.filled,
    required this.enabled,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled ? color : color.withValues(alpha: 0.5);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: filled ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: effectiveColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: filled ? Colors.white : effectiveColor),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: filled ? Colors.white : effectiveColor),
            ),
          ],
        ),
      ),
    );
  }
}
