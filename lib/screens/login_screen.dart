import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_colors.dart';
import '../services/app_bootstrap.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import 'club_admin_auth_screen.dart';
import 'forgot_password_screen.dart';

/// Combined brand + sign-in entry screen (recreated from the
/// "Login Screen v2" design handoff). It is the app's root: a centered crest
/// under a radial accent glow, the ClubUp wordmark, neutral auth fields with a
/// fixed "@ku.edu.tr" suffix, and a bottom action stack (gradient "Log in",
/// outlined "Sign up", quiet club-admin link). "Sign up" hands off to the
/// multi-step sign-up flow.
class LoginScreen extends StatefulWidget {
  final VoidCallback onLogin;
  final VoidCallback onSignUp;
  final VoidCallback onAdminLogin;
  final VoidCallback? onBack;
  final String initialEmail;
  const LoginScreen({
    super.key,
    required this.onLogin,
    required this.onSignUp,
    required this.onAdminLogin,
    this.onBack,
    this.initialEmail = '',
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _error;

  bool get _canSubmit =>
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty;

  /// The campus-email field holds only the local part; "@ku.edu.tr" is a fixed
  /// suffix, so strip any domain off an incoming value (e.g. a pre-filled email
  /// after sign-up).
  static String _localPart(String email) {
    final at = email.indexOf('@');
    return at < 0 ? email : email.substring(0, at);
  }

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(
      text: _localPart(widget.initialEmail),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_isSubmitting) return;
    final localPart = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (localPart.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter your email and password');
      return;
    }
    // Users type only the local part (e.g. "htuncay23"); the "@ku.edu.tr"
    // domain is appended automatically. Lower-cased so any casing logs in.
    final email = '${localPart.toLowerCase()}@ku.edu.tr';
    if (!authService.isValidStudentPassword(password)) {
      setState(() => _error = 'Student password must be exactly 6 digits.');
      return;
    }
    setState(() {
      _error = null;
      _isSubmitting = true;
    });
    // Post-login screens read Hive boxes that open in the background after
    // first paint; by the time credentials are typed this is a no-op.
    await appBootstrap.ready;
    final success = await authService.loginStudent(email, password);
    if (!mounted) return;
    if (success) {
      widget.onLogin();
    } else {
      setState(() {
        _isSubmitting = false;
        _error = 'Incorrect email or password';
      });
    }
  }

  Future<void> _openForgotPassword() async {
    final resetEmail = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) =>
            ForgotPasswordScreen(initialEmail: _emailController.text.trim()),
      ),
    );
    if (resetEmail != null && resetEmail.isNotEmpty) {
      _emailController.text = resetEmail;
      _passwordController.clear();
      setState(() => _error = null);
    }
  }

  void _openClubAdmin() {
    Navigator.of(context).push(
      _fadeSlideRoute(
        ClubAdminAuthScreen(
          onAdminLogin: () {
            Navigator.of(context).pop();
            widget.onAdminLogin();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeService.isDark;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        // Radial accent glow bleeding down from the top edge (design's
        // "radial-gradient(120% 60% at 50% -10%, accentDeep, transparent)").
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -1.25),
            radius: 1.3,
            colors: [
              AppColors.darkRed.withValues(alpha: isDark ? 0.42 : 0.18),
              AppColors.darkRed.withValues(alpha: 0),
            ],
            stops: const [0, 0.62],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.onBack != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8, top: 4),
                            child: BackButton(
                              color: AppColors.text,
                              onPressed: widget.onBack,
                            ),
                          ),
                        ),

                      // ── Brand header: crest + university + wordmark ───────
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          widget.onBack != null ? 12 : 40,
                          24,
                          0,
                        ),
                        child: Column(
                          children: [
                            const _Crest(size: 60),
                            const SizedBox(height: 18),
                            Text(
                              'KOÇ UNIVERSITY',
                              style: TextStyle(
                                fontSize: 10.5,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Menlo',
                                color: AppColors.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'ClubUp',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Sign in to pick up where you left off.',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.text.withValues(alpha: 0.76),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Form ─────────────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 30, 22, 0),
                        child: _EntrySlide(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _AuthField(
                                label: 'Campus email',
                                controller: _emailController,
                                hint: 'yourname',
                                icon: Icons.mail_outline_rounded,
                                keyboardType: TextInputType.text,
                                suffixText: '@ku.edu.tr',
                                inputFormatters: [_NoDomainFormatter()],
                                onChanged: (_) => setState(() => _error = null),
                                onSubmitted: (_) => _handleLogin(),
                              ),
                              const SizedBox(height: 14),
                              _AuthField(
                                label: 'Password',
                                controller: _passwordController,
                                hint: '6-digit PIN',
                                icon: Icons.lock_outline_rounded,
                                obscureText: _obscurePassword,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(6),
                                ],
                                onChanged: (_) => setState(() => _error = null),
                                onSubmitted: (_) => _handleLogin(),
                                trailing: GestureDetector(
                                  onTap: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                  child: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 19,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _openForgotPassword,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 4,
                                    ),
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Forgot password?',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryRed,
                                    ),
                                  ),
                                ),
                              ),

                              // Inline error (kept from the previous screen —
                              // the design has no failure state of its own).
                              if (_error != null) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline_rounded,
                                      size: 15,
                                      color: AppColors.primaryRed,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: AppColors.primaryRed,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const Spacer(),

                      // ── Bottom action area ───────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SubmitButton(
                              enabled: _canSubmit,
                              submitting: _isSubmitting,
                              onTap: _handleLogin,
                            ),
                            Container(
                              height: 1,
                              color: AppColors.divider,
                              margin: const EdgeInsets.only(
                                top: 22,
                                bottom: 16,
                              ),
                            ),
                            Text(
                              'New to Koç University?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: AppColors.text.withValues(alpha: 0.76),
                              ),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton(
                              onPressed: widget.onSignUp,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                                side: BorderSide(
                                  color: AppColors.divider,
                                  width: 1.5,
                                ),
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(15),
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Sign up',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                      color: AppColors.text,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 17,
                                    color: AppColors.text,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Running a club? ',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _openClubAdmin,
                                  child: Text(
                                    'Club admin sign in',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.text.withValues(
                                        alpha: 0.76,
                                      ),
                                      decoration: TextDecoration.underline,
                                      decorationColor: AppColors.text
                                          .withValues(alpha: 0.4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
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
    );
  }
}

// ─── Gradient crest with "KU" initials (design's Crest component) ──────────────
class _Crest extends StatelessWidget {
  final double size;
  const _Crest({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryRed, AppColors.darkRed],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryRed.withValues(alpha: 0.4),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        'KU',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.36,
          letterSpacing: -0.6,
        ),
      ),
    );
  }
}

// ─── One-shot entry slide (design's .au-sheet / fadeUp keyframes) ──────────────
class _EntrySlide extends StatefulWidget {
  final Widget child;
  const _EntrySlide({required this.child});

  @override
  State<_EntrySlide> createState() => _EntrySlideState();
}

class _EntrySlideState extends State<_EntrySlide> {
  bool _in = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _in = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _in ? Offset.zero : const Offset(0, 0.05),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _in ? 1 : 0,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ─── Neutral text field (label + rounded box + leading icon) ──────────────────
// The surface, border, label and icon deliberately have no focused/hovered
// visual state. Only the entered text and neutral cursor change while editing.
class _AuthField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final Widget? trailing;
  final TextInputType? keyboardType;
  final String? suffixText;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const _AuthField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.trailing,
    this.keyboardType,
    this.suffixText,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = themeService.isDark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DefaultTextStyle(
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: AppColors.secondaryText,
          ),
          child: Text(label.toUpperCase()),
        ),
        const SizedBox(height: 7),
        Container(
          key: ValueKey<String>('login-field-$label'),
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.transparent,
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            border: Border.all(color: AppColors.divider, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(icon, size: 19, color: AppColors.secondaryText),
              const SizedBox(width: 10),
              Expanded(
                child: Theme(
                  data: Theme.of(context).copyWith(
                    focusColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    textSelectionTheme: TextSelectionThemeData(
                      cursorColor: AppColors.text,
                      selectionColor: Colors.transparent,
                      selectionHandleColor: Colors.transparent,
                    ),
                  ),
                  child: TextField(
                    controller: controller,
                    obscureText: obscureText,
                    keyboardType: keyboardType,
                    inputFormatters: inputFormatters,
                    autocorrect: false,
                    enableSuggestions: false,
                    onChanged: onChanged,
                    onSubmitted: onSubmitted,
                    cursorColor: AppColors.text,
                    cursorErrorColor: AppColors.text,
                    style: TextStyle(
                      fontSize: 15.5,
                      color: AppColors.text,
                      letterSpacing: -0.2,
                    ),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      filled: false,
                      fillColor: Colors.transparent,
                      focusColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      hintText: hint,
                      hintStyle: TextStyle(
                        fontSize: 15.5,
                        color: AppColors.secondaryText,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
              ),
              if (suffixText != null)
                Text(
                  suffixText!,
                  style: TextStyle(
                    fontSize: 15.5,
                    color: AppColors.secondaryText,
                    letterSpacing: -0.2,
                  ),
                ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Email local-part formatter: drop anything from "@" onward ─────────────────
class _NoDomainFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final at = newValue.text.indexOf('@');
    if (at < 0) return newValue;
    final text = newValue.text.substring(0, at);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

// ─── Gradient submit button (enabled / disabled / submitting) ─────────────────
class _SubmitButton extends StatelessWidget {
  final bool enabled;
  final bool submitting;
  final VoidCallback onTap;

  const _SubmitButton({
    required this.enabled,
    required this.submitting,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = enabled || submitting;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(15)),
          gradient: active
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.darkRed, AppColors.primaryRed],
                )
              : null,
          color: active ? null : AppColors.surfaceAlt,
          border: Border.all(
            color: active ? Colors.transparent : AppColors.divider,
            width: 1.5,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppColors.primaryRed.withValues(alpha: 0.30),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: submitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (enabled) ...[
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    'Log in',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: active ? Colors.white : AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─── Shared fade+slide route (matches the old auth-choice transition) ──────────
Route _fadeSlideRoute(Widget page) => PageRouteBuilder(
  pageBuilder: (context, animation, secondaryAnimation) => page,
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(position: slide, child: child),
    );
  },
  transitionDuration: const Duration(milliseconds: 320),
);
