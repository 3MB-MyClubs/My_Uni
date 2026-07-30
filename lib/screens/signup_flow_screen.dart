import 'package:flutter/material.dart';
import '../services/signup_service.dart';
import '../services/terms_acceptance_service.dart';
import '../widgets/language_toggle.dart';
import 'signup_steps/signup_theme.dart';
import 'signup_steps/step_email.dart';
import 'signup_steps/step_verify.dart';
import 'signup_steps/step_password.dart';
import 'signup_steps/step_profile.dart';

class SignupFlowScreen extends StatefulWidget {
  final void Function(String email) onSignUp;
  final VoidCallback? onBack;

  const SignupFlowScreen({super.key, required this.onSignUp, this.onBack});

  @override
  State<SignupFlowScreen> createState() => _SignupFlowScreenState();
}

class _SignupFlowScreenState extends State<SignupFlowScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Shared state across steps
  String _email = '';
  String _name = '';
  String _majorId = '';
  String _major = '';
  String _academicYearId = '';
  String _year = '';
  String? _profileImagePath;
  String _password = '';

  static const int _totalSteps = 4; // email, verify, password, profile

  void _goTo(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  void _goBack() {
    if (_currentStep == 0) {
      (widget.onBack ?? () => Navigator.of(context).maybePop())();
    } else {
      _goTo(_currentStep - 1);
    }
  }

  Future<String?> _onEmailNext(String email) async {
    final result = await signupService.sendCode(email);
    if (!result.success) return result.error;
    _email = email;
    _goTo(1);
    return null;
  }

  Future<String?> _onVerifyNext(String code) async {
    final result = await signupService.verifyCode(email: _email, code: code);
    if (!result.success) return result.error;
    _goTo(2);
    return null;
  }

  Future<String?> _onResendCode() async {
    final result = await signupService.sendCode(_email);
    if (!result.success) return result.error;
    return null;
  }

  void _onPasswordNext(String password) {
    _password = password;
    _goTo(3);
  }

  Future<String?> _onProfileNext(
    String name,
    String majorId,
    String majorName,
    String academicYearId,
    String academicYearName,
    String? imagePath,
  ) async {
    _name = name;
    _majorId = majorId;
    _major = majorName;
    _academicYearId = academicYearId;
    _year = academicYearName;
    _profileImagePath = imagePath;

    final result = await signupService.completeSignup(
      email: _email,
      password: _password,
      fullName: _name,
      majorId: _majorId,
      academicYearId: _academicYearId,
      interestIds: const [],
      imagePath: _profileImagePath,
    );
    if (!result.success) return result.error;
    // The account now exists and the student ticked the Terms checkbox on this
    // step, so record acceptance of the current Terms version. This mirrors
    // what the old full-screen TermsAcceptanceScreen did on "Agree and
    // continue", keeping the returning-user re-accept gate working when the
    // version is bumped.
    await termsAcceptanceService.accept();
    widget.onSignUp(_email);
    return null;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      key: const ValueKey('signup-flow-theme'),
      data: SC.theme(),
      child: Scaffold(
        key: const ValueKey('signup-flow-scaffold'),
        backgroundColor: SC.bg,
        body: SafeArea(
          child: Column(
            children: [
              ...[
                // ── Nav bar ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: SC.burgundy,
                          size: 20,
                        ),
                        onPressed: _goBack,
                      ),
                      const Spacer(),
                      const LanguageToggle(),
                      const SizedBox(width: 14),
                      Text(
                        '${_currentStep + 1} / $_totalSteps',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.0,
                          color: SC.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
                // ── Progress bar ─────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                    child: LinearProgressIndicator(
                      value: (_currentStep + 1) / _totalSteps,
                      backgroundColor: SC.hair,
                      valueColor: AlwaysStoppedAnimation<Color>(SC.burgundy),
                      minHeight: 3,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],

              // ── Step pages ───────────────────────────────────────
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    // 0 — Email
                    StepEmail(initialValue: _email, onNext: _onEmailNext),
                    // 1 — Verify
                    StepVerify(
                      email: _email,
                      onNext: _onVerifyNext,
                      onResend: _onResendCode,
                    ),
                    // 2 — Password
                    StepPassword(
                      initialValue: _password,
                      onNext: _onPasswordNext,
                    ),
                    // 3 — Profile (final step: completes signup + Terms)
                    StepProfile(
                      initialName: _name,
                      initialMajor: _major,
                      initialYear: _year,
                      loadMajors: signupService.fetchMajors,
                      loadAcademicYears: signupService.fetchAcademicYears,
                      onNext: _onProfileNext,
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
