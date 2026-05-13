import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'signup_steps/signup_theme.dart';
import 'signup_steps/step_email.dart';
import 'signup_steps/step_verify.dart';
import 'signup_steps/step_profile.dart';
import 'signup_steps/step_interests.dart';
import 'signup_steps/step_done.dart';

/// 5-screen signup flow: Email → Verify → Profile → Interests → Done.
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

  // Pages: 0=Email, 1=Verify, 2=Profile, 3=Interests, 4=Done
  static const int _totalPages = 5;
  // Steps with visible progress header: pages 0-3
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
        _currentStep = 0; // back to email step
      });
      _pageController.animateToPage(
        0,
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
  // Only pages 0-3 show the progress header
  bool get _showHeader => _currentStep < _totalVisibleSteps;

  int get _visibleStep => _currentStep + 1; // 1=Email(1/4) … 4=Interests(4/4)

  String? get _rightLabel {
    if (_currentStep == 0) return 'Help';
    if (_currentStep == 3) return 'Skip';
    return null;
  }

  VoidCallback? get _onRight {
    if (_currentStep == 3) return () => _handleFinish(); // skip interests
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
              // ── Progress header (pages 0-3 only) ─────────────
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
                    // Page 0: Email
                    StepEmail(
                      initialValue: _email,
                      externalError: _signUpError,
                      onNext: (email) {
                        setState(() => _email = email);
                        _goNext();
                      },
                    ),
                    // Page 1: Verify
                    StepVerify(
                      email: _email,
                      onNext: _goNext,
                      onResend: () {/* wire to real email service */},
                    ),
                    // Page 2: Profile
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
                    // Page 3: Interests
                    StepInterests(
                      selected: _interests,
                      onNext: (interests) {
                        setState(() => _interests = interests);
                        _goNext();
                      },
                      onSkip: _goNext,
                    ),
                    // Page 4: Done
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
