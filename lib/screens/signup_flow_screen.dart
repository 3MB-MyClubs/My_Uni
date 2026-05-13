import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/user_state.dart';
import 'signup_steps/signup_theme.dart';
import 'signup_steps/step_email.dart';
import 'signup_steps/step_verify.dart';
import 'signup_steps/step_password.dart';
import 'signup_steps/step_profile.dart';
import 'signup_steps/step_interests.dart';
import 'signup_steps/step_done.dart';

class SignupFlowScreen extends StatefulWidget {
  final VoidCallback onSignUp;
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
  String _major = '';
  String _year = '';
  String _password = '';
  String? _profileImagePath;
  List<String> _interests = [];

  static const int _totalSteps =
      5; // email, verify, password, profile, interests

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

  void _onEmailNext(String email) {
    _email = email;
    _goTo(1);
  }

  void _onVerifyNext() {
    _goTo(2);
  }

  void _onPasswordNext(String password) {
    _password = password;
    _goTo(3);
  }

  void _onProfileNext(
    String name,
    String major,
    String year,
    String? imagePath,
  ) {
    _name = name;
    _major = major;
    _year = year;
    _profileImagePath = imagePath;
    _goTo(4);
  }

  void _saveProfileDetails() {
    final userId = authService.currentUser?.id;
    if (userId == null) return;
    userState.setMajor(userId, _major);
    userState.setYear(userId, _year);
    final imagePath = _profileImagePath;
    if (imagePath != null && imagePath.isNotEmpty) {
      userState.setProfilePhoto(userId, imagePath);
    }
  }

  void _onInterestsNext(List<String> interests) {
    _interests = interests;
    final ok = authService.signUp(_name, _email, _password);
    if (!ok) {
      setState(() => _currentStep = 0);
      _pageController.jumpToPage(0);
      return;
    }
    _saveProfileDetails();
    _goTo(5);
  }

  void _onSkipInterests() {
    final ok = authService.signUp(_name, _email, _password);
    if (!ok) {
      setState(() => _currentStep = 0);
      _pageController.jumpToPage(0);
      return;
    }
    _saveProfileDetails();
    _goTo(5);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDoneStep = _currentStep == 5;

    return Theme(
      data: SC.lightTheme(),
      child: Scaffold(
        backgroundColor: SC.bg,
        body: SafeArea(
          child: Column(
            children: [
              if (!isDoneStep) ...[
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
                    borderRadius: BorderRadius.circular(2),
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
                      onResend: () {},
                    ),
                    // 2 — Password
                    StepPassword(
                      initialValue: _password,
                      onNext: _onPasswordNext,
                    ),
                    // 3 — Profile
                    StepProfile(
                      initialName: _name,
                      initialMajor: _major,
                      initialYear: _year,
                      onNext: _onProfileNext,
                    ),
                    // 4 — Interests
                    StepInterests(
                      selected: _interests,
                      onNext: _onInterestsNext,
                      onSkip: _onSkipInterests,
                    ),
                    // 5 — Done
                    StepDone(name: _name, onFinish: widget.onSignUp),
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
