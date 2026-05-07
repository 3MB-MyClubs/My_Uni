import 'package:flutter/material.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/rsvp_store.dart';

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

  String get _userId =>
      authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

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

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.97, end: 1.0).animate(
                CurvedAnimation(parent: anim, curve: Curves.easeOut),
              ),
              child: child,
            ),
          ),
          child: _build(attending, pending, onToggle),
        );
      },
    );
  }

  Widget _build(bool attending, bool pending, VoidCallback onToggle) {
    // ── Past ─────────────────────────────────────────────────────────────────
    if (isPast) {
      if (compact) {
        return _CompactChip(
          key: const ValueKey('past-c'),
          label: 'Ended',
          icon: Icons.event_busy_rounded,
          active: false,
          enabled: false,
          color: AppColors.secondaryText,
          onTap: () {},
        );
      }
      return _FullPastBar(key: const ValueKey('past-f'));
    }

    // ── Compact ───────────────────────────────────────────────────────────────
    if (compact) {
      if (attending) {
        return Row(
          key: const ValueKey('compact-attending'),
          mainAxisSize: MainAxisSize.min,
          children: [
            _CompactChip(
              label: '✓ Going',
              icon: Icons.check_circle_rounded,
              active: true,
              enabled: !pending,
              color: color,
              onTap: onToggle,
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: pending ? null : onToggle,
              child: AnimatedOpacity(
                opacity: pending ? 0.4 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close, size: 12, color: AppColors.secondaryText),
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
        enabled: !pending,
        color: color,
        onTap: onToggle,
      );
    }

    // ── Full — attending ──────────────────────────────────────────────────────
    if (attending) {
      return SizedBox(
        key: const ValueKey('full-attending'),
        height: 56,
        child: Row(
          children: [
            // "You are attending" pill
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color,
                      Color.lerp(color, Colors.black, 0.15)!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.30),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: Colors.white, size: 19),
                    SizedBox(width: 8),
                    Text(
                      'You are attending',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 10),

            // "Not Coming" secondary action
            SizedBox(
              width: 88,
              height: 56,
              child: GestureDetector(
                onTap: pending ? null : onToggle,
                child: AnimatedOpacity(
                  opacity: pending ? 0.4 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.divider,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.close_rounded,
                          size: 17,
                          color: AppColors.secondaryText,
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Not Coming',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryText,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
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
        onTap: pending ? null : onToggle,
        child: AnimatedOpacity(
          opacity: pending ? 0.65 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color,
                  Color.lerp(color, Colors.black, 0.18)!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.how_to_reg_rounded,
                    color: Colors.white, size: 20),
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

// ─── Past bar ─────────────────────────────────────────────────────────────────

class _FullPastBar extends StatelessWidget {
  const _FullPastBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy_rounded,
              size: 18, color: AppColors.secondaryText),
          SizedBox(width: 8),
          Text(
            'This event has passed',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryText,
            ),
          ),
        ],
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
    final effectiveColor =
        enabled ? color : color.withValues(alpha: 0.45);

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: active
              ? LinearGradient(
                  colors: [color, Color.lerp(color, Colors.black, 0.15)!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: active ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: effectiveColor, width: 1.5),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: active ? Colors.white : effectiveColor),
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
