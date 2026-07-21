import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'signup_theme.dart';

class StepDone extends StatefulWidget {
  final String name;
  final VoidCallback onFinish;

  const StepDone({super.key, required this.name, required this.onFinish});

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
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        widget.onFinish();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _firstName(BuildContext context) {
    final parts = widget.name.trim().split(' ');
    return parts.isNotEmpty && parts.first.isNotEmpty
        ? parts.first
        : AppLocalizations.of(context)!.fallbackNameGreeting;
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
            Positioned.fill(child: Container(color: const Color(0xFF0B0B0C))),

            // ── Radial burgundy wash from top ───────────────────
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
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

                          Text(
                            AppLocalizations.of(context)!.welcomeToKoc,
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 2.0,
                              color: Color(0x99FFFFFF),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),

                          Text(
                            AppLocalizations.of(
                              context,
                            )!.youreInName(_firstName(context)),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.05,
                              letterSpacing: -1.4,
                            ),
                          ),
                          const SizedBox(height: 16),

                          Text(
                            AppLocalizations.of(context)!.accountReadyRedirecting,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xB3FFFFFF),
                              height: 1.5,
                              letterSpacing: -0.1,
                            ),
                          ),
                          const SizedBox(height: 36),
                          SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                        ],
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
      child: Center(
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
