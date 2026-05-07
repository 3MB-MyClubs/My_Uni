import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'signup_steps/signup_theme.dart';
import 'signup_steps/step_email.dart';
import 'signup_steps/step_verify.dart';
import 'signup_steps/step_profile.dart';
import 'signup_steps/step_interests.dart';
import 'signup_steps/step_done.dart';

/// 6-screen signup flow: Welcome → Email → Verify → Profile → Interests → Done.
/// Drop-in replacement — same class name, same constructor signature.
class SignUpScreen extends StatefulWidget {
  final VoidCallback onSignUp;
  final VoidCallback? onBack;
  const SignUpScreen({super.key, required this.onSignUp, this.onBack});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Pages: 0=Welcome, 1=Email, 2=Verify, 3=Profile, 4=Interests, 5=Done
  static const int _totalPages = 6;
  // Steps with visible progress header: pages 1-4
  static const int _totalVisibleSteps = 4;

  // ── Shared form state ─────────────────────────────────────────
  String _email    = '';
  String _name     = '';
  String _major    = '';
  String _year     = '';
  String _password = '';
  List<String> _interests = [];
  String? _signUpError;

  // ── Navigation ────────────────────────────────────────────────
  void _goNext() {
    if (_currentStep < _totalPages - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _goBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOutCubic,
      );
    } else {
      widget.onBack?.call();
    }
  }

  void _handleFinish() {
    setState(() => _signUpError = null);
    final success = authService.signUp(_name, _email, _password);
    if (success) {
      widget.onSignUp();
    } else {
      setState(() {
        _signUpError = 'An account with this email already exists.';
        _currentStep = 1; // back to email step
      });
      _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ── Header logic ──────────────────────────────────────────────
  // Only pages 1-4 show the progress header
  bool get _showHeader =>
      _currentStep >= 1 && _currentStep <= _totalVisibleSteps;

  int get _visibleStep => _currentStep; // 1=Email(1/4) … 4=Interests(4/4)

  String? get _rightLabel {
    if (_currentStep == 1) return 'Help';
    if (_currentStep == 4) return 'Skip';
    return null;
  }

  VoidCallback? get _onRight {
    if (_currentStep == 4) return () => _handleFinish(); // skip interests
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: SC.lightTheme(),
      child: Scaffold(
        backgroundColor: SC.bg,
        body: SafeArea(
          child: Column(
            children: [
              // ── Progress header (pages 1-4 only) ─────────────
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: _showHeader
                    ? _SignupHeader(
                        step: _visibleStep,
                        total: _totalVisibleSteps,
                        onBack: _goBack,
                        rightLabel: _rightLabel,
                        onRight: _onRight,
                      )
                    : const SizedBox.shrink(),
              ),

              // ── Pages ─────────────────────────────────────────
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    // Page 0: Welcome
                    _WelcomePage(
                      onCreateAccount: _goNext,
                      onHaveAccount: () => widget.onBack?.call(),
                    ),
                    // Page 1: Email
                    StepEmail(
                      initialValue: _email,
                      externalError: _signUpError,
                      onNext: (email) {
                        setState(() => _email = email);
                        _goNext();
                      },
                    ),
                    // Page 2: Verify
                    StepVerify(
                      email: _email,
                      onNext: _goNext,
                      onResend: () {/* wire to real email service */},
                    ),
                    // Page 3: Profile
                    StepProfile(
                      initialName: _name,
                      initialMajor: _major,
                      initialYear: _year,
                      initialPassword: _password,
                      onNext: (name, major, year, password) {
                        setState(() {
                          _name     = name;
                          _major    = major;
                          _year     = year;
                          _password = password;
                        });
                        _goNext();
                      },
                    ),
                    // Page 4: Interests
                    StepInterests(
                      selected: _interests,
                      onNext: (interests) {
                        setState(() => _interests = interests);
                        _goNext();
                      },
                      onSkip: _goNext,
                    ),
                    // Page 5: Done
                    StepDone(
                      name: _name,
                      onFinish: _handleFinish,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Welcome page ──────────────────────────────────────────────────────────────
class _WelcomePage extends StatelessWidget {
  final VoidCallback onCreateAccount;
  final VoidCallback onHaveAccount;

  const _WelcomePage({
    required this.onCreateAccount,
    required this.onHaveAccount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Hero area ─────────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // KU shield badge + name
                Row(
                  children: [
                    _KuShield(),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EST. 1993',
                          style: TextStyle(
                            fontSize: 11,
                            color: SC.muted,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Koç University',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: SC.ink,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const Spacer(),

                // Hero text
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      color: SC.ink,
                      height: 1.05,
                      letterSpacing: -1.4,
                    ),
                    children: [
                      TextSpan(text: 'Your campus,\n'),
                      TextSpan(
                        text: 'in your pocket.',
                        style: TextStyle(color: SC.burgundy),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Class schedules, dining, events, and the\npeople who make Koç University home.',
                  style: TextStyle(
                    fontSize: 16,
                    color: SC.body,
                    height: 1.45,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),

        // ── CTA area ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: onCreateAccount,
                  style: SC.primaryButtonStyle(),
                  child: Text('Create account'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: onHaveAccount,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SC.ink,
                    side: BorderSide(color: SC.hairStrong, width: 1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    textStyle: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.1),
                  ),
                  child: Text('I already have one'),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'By continuing you agree to our Terms\nand acknowledge the Privacy Policy.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11, color: SC.muted, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── KU shield badge ───────────────────────────────────────────────────────────
class _KuShield extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _ShieldClipper(),
      child: Container(
        width: 44,
        height: 50,
        color: SC.burgundy,
        alignment: const Alignment(0, 0.15),
        child: Text(
          'KU',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _ShieldClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) {
    final path = Path();
    const r = 5.0;
    path.moveTo(r, 0);
    path.lineTo(s.width - r, 0);
    path.quadraticBezierTo(s.width, 0, s.width, r);
    path.lineTo(s.width, s.height * 0.55);
    path.quadraticBezierTo(s.width * 0.5, s.height, 0, s.height * 0.55);
    path.lineTo(0, r);
    path.quadraticBezierTo(0, 0, r, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_) => false;
}

// ── Progress header ───────────────────────────────────────────────────────────
class _SignupHeader extends StatelessWidget {
  final int step;
  final int total;
  final VoidCallback onBack;
  final String? rightLabel;
  final VoidCallback? onRight;

  const _SignupHeader({
    required this.step,
    required this.total,
    required this.onBack,
    this.rightLabel,
    this.onRight,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Nav row
        SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back
                GestureDetector(
                  onTap: onBack,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Text('‹',
                          style: TextStyle(
                              fontSize: 22,
                              color: SC.burgundy,
                              height: 1)),
                      SizedBox(width: 2),
                      Text('Back',
                          style: TextStyle(
                              fontSize: 17, color: SC.burgundy)),
                    ],
                  ),
                ),
                // Step counter
                Text(
                  '$step / $total',
                  style: TextStyle(
                    fontSize: 11,
                    color: SC.muted,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                // Right action / spacer
                SizedBox(
                  width: 52,
                  child: rightLabel != null
                      ? GestureDetector(
                          onTap: onRight,
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            rightLabel!,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 17,
                                color: SC.muted),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
        // Thin progress bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: step / total,
              backgroundColor: SC.hair,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(SC.burgundy),
              minHeight: 3,
            ),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}
