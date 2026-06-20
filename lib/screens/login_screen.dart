import 'package:flutter/material.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import 'club_admin_auth_screen.dart';
import 'forgot_password_screen.dart';

/// Combined brand + sign-in entry screen (recreated from the
/// "Login Screen" design handoff). It is the app's root: the crest header,
/// hero copy, focus-ring fields and gradient submit all come from the design.
/// "Sign up" hands off to the multi-step sign-up flow, and a quiet club-admin
/// link is preserved at the bottom.
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
  bool _done = false;
  String? _error;

  bool get _canSubmit =>
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_isSubmitting || _done) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter your email and password');
      return;
    }
    setState(() {
      _error = null;
      _isSubmitting = true;
    });
    final success = await authService.loginStudent(email, password);
    if (!mounted) return;
    if (success) {
      // Brief success affirmation (matches the design's check-pop) before the
      // parent swaps this screen out for the main app.
      setState(() {
        _isSubmitting = false;
        _done = true;
      });
      await Future.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.onBack != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: BackButton(
                    color: AppColors.text,
                    onPressed: widget.onBack,
                  ),
                )
              else
                const SizedBox(height: 26),

              // ── Brand header ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
                child: Row(
                  children: [
                    _Crest(),
                    const SizedBox(width: 13),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'EST. 1993',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.6,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Koç University',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Hero ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 30, 28, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.4,
                          height: 1.05,
                          color: AppColors.text,
                        ),
                        children: [
                          const TextSpan(text: 'Your campus,\n'),
                          TextSpan(
                            text: 'in your pocket.',
                            style: TextStyle(color: AppColors.primaryRed),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 330),
                      child: Text(
                        'Sign in to pick up where you left off at Koç University.',
                        style: TextStyle(
                          fontSize: 15.5,
                          height: 1.45,
                          letterSpacing: -0.1,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Form ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AuthField(
                      label: 'Email',
                      controller: _emailController,
                      hint: 'you@ku.edu.tr',
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) => setState(() => _error = null),
                      onSubmitted: (_) => _handleLogin(),
                    ),
                    const SizedBox(height: 12),
                    _AuthField(
                      label: 'Password',
                      controller: _passwordController,
                      hint: 'Enter your password',
                      icon: Icons.lock_outline_rounded,
                      obscureText: _obscurePassword,
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

                    // Forgot password
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
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Forgot password?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryRed,
                          ),
                        ),
                      ),
                    ),

                    // Inline error
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
                    const SizedBox(height: 14),

                    // Submit
                    _SubmitButton(
                      enabled: _canSubmit,
                      submitting: _isSubmitting,
                      done: _done,
                      onTap: _handleLogin,
                    ),
                  ],
                ),
              ),

              // ── Footer ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 8),
                child: Column(
                  children: [
                    Container(height: 1, color: AppColors.divider),
                    const SizedBox(height: 18),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'New to campus? ',
                          style: TextStyle(
                            fontSize: 14.5,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        GestureDetector(
                          onTap: widget.onSignUp,
                          child: Text(
                            'Sign up',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.1,
                              color: AppColors.primaryRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: _openClubAdmin,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.secondaryText,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                      ),
                      child: Text(
                        'Club admin sign in',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Brand crest tile ─────────────────────────────────────────────────────────
class _Crest extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryRed, AppColors.darkRed],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryRed.withValues(alpha: 0.30),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Text(
        'KU',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 17,
          letterSpacing: -0.6,
        ),
      ),
    );
  }
}

// ─── Focus-ring text field (label + rounded box + leading icon) ────────────────
class _AuthField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final Widget? trailing;
  final TextInputType? keyboardType;
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
    this.onChanged,
    this.onSubmitted,
  });

  @override
  State<_AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<_AuthField> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: AppColors.secondaryText,
          ),
        ),
        const SizedBox(height: 7),
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 19, color: AppColors.secondaryText),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  obscureText: widget.obscureText,
                  keyboardType: widget.keyboardType,
                  autocorrect: false,
                  enableSuggestions: false,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  cursorColor: AppColors.primaryRed,
                  style: TextStyle(
                    fontSize: 15.5,
                    color: AppColors.text,
                    letterSpacing: -0.2,
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    filled: false,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    hintText: widget.hint,
                    hintStyle: TextStyle(
                      fontSize: 15.5,
                      color: AppColors.secondaryText,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: 8),
                widget.trailing!,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Gradient submit button (enabled / disabled / submitting / done) ───────────
class _SubmitButton extends StatelessWidget {
  final bool enabled;
  final bool submitting;
  final bool done;
  final VoidCallback onTap;

  const _SubmitButton({
    required this.enabled,
    required this.submitting,
    required this.done,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = enabled || submitting || done;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: active
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.darkRed, AppColors.primaryRed],
                )
              : null,
          color: active ? null : AppColors.card,
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
                  if (done) ...[
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.6, end: 1),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutBack,
                      builder: (_, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    done ? 'Welcome back!' : 'Log in',
                    style: TextStyle(
                      fontSize: 16,
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
