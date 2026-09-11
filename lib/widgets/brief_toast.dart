import 'dart:async';

import 'package:flutter/material.dart';

import '../services/theme_service.dart';
import 'clubup_design.dart';

/// The one bubble treatment in the app: a deep neutral in light, lifted off the
/// near-black page in dark. Shared with the content-audience mark's bubble so
/// every transient bubble reads as the same object.
Color bubbleSurfaceColor(bool dark) =>
    dark ? const Color(0xFF3B3B42) : const Color(0xF01B1B1F);

/// How long the whole bubble lasts, in and out included: **under a second**.
///
/// A `SnackBar` used to carry these confirmations and sat on screen for four
/// seconds — long enough to be read twice, dismissed by hand, or to cover the
/// composer while someone typed the next message. A copy confirmation is not
/// news; it only has to say the tap landed.
const Duration _toastFadeIn = Duration(milliseconds: 130);
const Duration _toastHold = Duration(milliseconds: 420);
const Duration _toastFadeOut = Duration(milliseconds: 160);

/// Pops a brief bubble over the current page — "Copied", and anything else that
/// only confirms a tap.
///
/// It is an [OverlayEntry] rather than a `SnackBar`: it floats above the page's
/// own chrome, never pushes layout around, and takes itself away. It also
/// ignores pointers entirely, so the next tap goes where the reader aimed it
/// instead of dismissing a bar.
void showBriefToast(
  BuildContext context,
  String label, {
  IconData? icon = Icons.check_rounded,
}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  late final OverlayEntry entry;
  var removed = false;
  entry = OverlayEntry(
    builder: (_) => _BriefToast(
      label: label,
      icon: icon,
      onDone: () {
        if (removed) return;
        removed = true;
        entry.remove();
        entry.dispose();
      },
    ),
  );
  overlay.insert(entry);
}

class _BriefToast extends StatefulWidget {
  const _BriefToast({
    required this.label,
    required this.icon,
    required this.onDone,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onDone;

  @override
  State<_BriefToast> createState() => _BriefToastState();
}

class _BriefToastState extends State<_BriefToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _toastFadeIn,
    reverseDuration: _toastFadeOut,
  );
  late final CurvedAnimation _pop = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeIn,
  );

  Timer? _hold;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _hold = Timer(_toastHold, () async {
      if (!mounted) return;
      await _controller.reverse();
      if (!mounted) return;
      widget.onDone();
    });
  }

  @override
  void dispose() {
    _hold?.cancel();
    _pop.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surface = bubbleSurfaceColor(themeService.isDark);
    return Positioned.fill(
      // Never in the way: the bubble is gone before a reader could aim at it,
      // and a swallowed tap on a chat composer is worse than no confirmation.
      child: IgnorePointer(
        child: Padding(
          // Ride above an open keyboard rather than hiding behind it.
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: SafeArea(
            child: Align(
              // Low enough to read as a response to something below, clear of
              // the composer a chat keeps at the very bottom.
              alignment: const Alignment(0, 0.74),
              child: FadeTransition(
                opacity: _controller,
                child: ScaleTransition(
                  scale: _pop,
                  child: Material(
                    // An overlay entry sits outside the page's `Material`, and
                    // a bare `Text` there inherits the framework's yellow debug
                    // underline.
                    type: MaterialType.transparency,
                    child: Container(
                      key: const ValueKey('brief-toast'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x30000000),
                            offset: Offset(0, 4),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon, size: 15, color: Colors.white),
                            const SizedBox(width: 7),
                          ],
                          Text(
                            widget.label,
                            style: figtree(
                              size: 12.5,
                              weight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
