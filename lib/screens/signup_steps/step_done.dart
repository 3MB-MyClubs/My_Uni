import 'dart:ui';
import 'package:flutter/material.dart';
import 'signup_theme.dart';

class StepDone extends StatefulWidget {
  final String name;
  final VoidCallback onFinish;

  const StepDone({
    super.key,
    required this.name,
    required this.onFinish,
  });

  @override
  State<StepDone> createState() => _StepDoneState();
}

class _StepDoneState extends State<StepDone>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _firstName {
    final parts = widget.name.trim().split(' ');
    return parts.isNotEmpty && parts.first.isNotEmpty
        ? parts.first
        : 'there';
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Stack(
          children: [
            // ── Dark base ───────────────────────────────────────
            Positioned.fill(
              child: Container(color: const Color(0xFF0B0B0C)),
            ),

            // ── Radial burgundy wash from top ───────────────────
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -1.0),
                    radius: 1.2,
                    colors: [
                      Color(0xFF8C1D40), // burgundy at top
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.65],
                  ),
                ),
              ),
            ),

            // ── Content ─────────────────────────────────────────
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(32, 52, 32, 0),
                      child: Column(
                        children: [
                          // KU seal
                          _KuSeal(),
                          const SizedBox(height: 28),

                          const Text(
                            'WELCOME TO KOÇ',
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 2.0,
                              color: Color(0x99FFFFFF),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),

                          Text(
                            "You're in,\n$_firstName.",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.05,
                              letterSpacing: -1.4,
                            ),
                          ),
                          const SizedBox(height: 16),

                          const Text(
                            'Your schedule, dining hours, and\n12 nearby events are ready.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xB3FFFFFF),
                              height: 1.5,
                              letterSpacing: -0.1,
                            ),
                          ),
                          const SizedBox(height: 36),

                          // ── Frosted glass preview card ──────────
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                  sigmaX: 20, sigmaY: 20),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0x0FFFFFFF), // ~6% white
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0x1AFFFFFF),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'NEXT UP · TODAY',
                                      style: TextStyle(
                                        fontSize: 10,
                                        letterSpacing: 1.5,
                                        color: Color(0x80FFFFFF),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'CS 240 · Algorithms',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Hadley Hall 105 · 11:00 AM',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0x99FFFFFF)),
                                    ),
                                    const Divider(
                                      height: 24,
                                      color: Color(0x1AFFFFFF),
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Robotics Club · Tonight 7pm',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Color(0xB3FFFFFF)),
                                        ),
                                        Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 4),
                                          decoration: BoxDecoration(
                                            color:
                                                const Color(0x24FFFFFF),
                                            borderRadius:
                                                BorderRadius.circular(100),
                                          ),
                                          child: const Text(
                                            'RSVP',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── "Take me to campus" — white button ──────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: widget.onFinish,
                        style: SC.primaryButtonStyle(
                          bg: Colors.white,
                          fg: const Color(0xFF0B0B0C),
                        ),
                        child: const Text('Take me to campus'),
                      ),
                    ),
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

// ── KU Seal ───────────────────────────────────────────────────────────────────
class _KuSeal extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: SC.burgundy.withValues(alpha: 0.5),
            blurRadius: 40,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          'KU',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: SC.burgundy,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}
