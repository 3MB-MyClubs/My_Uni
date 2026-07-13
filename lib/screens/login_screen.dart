import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_colors.dart';
import '../services/app_bootstrap.dart';
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
                child: Column(
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
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.2,
                          height: 1.08,
                          color: AppColors.text,
                        ),
                        children: [
                          const TextSpan(text: 'Welcome back to\n'),
                          TextSpan(
                            text: 'campus',
                            style: TextStyle(color: AppColors.primaryRed),
                          ),
                        ],
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
                    const SizedBox(height: 12),
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
                    // Sign up → hands off to the sign-up flow
                    GestureDetector(
                      onTap: widget.onSignUp,
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(15)),
                          border: Border.all(
                            color: AppColors.divider,
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
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

// ─── Focus-ring text field (label + rounded box + leading icon) ────────────────
class _AuthField extends StatefulWidget {
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
            borderRadius: BorderRadius.all(Radius.circular(14)),
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
                  inputFormatters: widget.inputFormatters,
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
              if (widget.suffixText != null)
                Text(
                  widget.suffixText!,
                  style: TextStyle(
                    fontSize: 15.5,
                    color: AppColors.secondaryText,
                    letterSpacing: -0.2,
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
          borderRadius: BorderRadius.all(Radius.circular(16)),
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
                  Text(
                    'Log in',
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
