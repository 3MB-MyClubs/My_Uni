import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_colors.dart';
import '../services/app_bootstrap.dart';
import '../services/auth_service.dart';
import '../services/locale_service.dart';
import '../services/theme_service.dart';
import '../l10n/app_localizations.dart';
import '../widgets/language_toggle.dart';
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

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _emailController;
  late final AnimationController _entranceController;
  late final Animation<double> _brandEntrance;
  late final Animation<double> _formEntrance;
  late final Animation<double> _actionsEntrance;
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _error;
  bool _entranceConfigured = false;
  double _languageContentOpacity = 1;
  bool _isSwitchingLanguage = false;

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
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _brandEntrance = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0, 0.55, curve: Curves.easeOutCubic),
    );
    _formEntrance = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.18, 0.78, curve: Curves.easeOutCubic),
    );
    _actionsEntrance = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.42, 1, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entranceConfigured) return;
    _entranceConfigured = true;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _entranceController.value = 1;
    } else {
      _entranceController.forward();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_isSubmitting) return;
    final localPart = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (localPart.isEmpty || password.isEmpty) {
      setState(
        () => _error = AppLocalizations.of(context)!.enterEmailAndPassword,
      );
      return;
    }
    // Users type only the local part (e.g. "htuncay23"); the "@ku.edu.tr"
    // domain is appended automatically. Lower-cased so any casing logs in.
    final email = '${localPart.toLowerCase()}@ku.edu.tr';
    if (!authService.isValidStudentPassword(password)) {
      setState(
        () =>
            _error = AppLocalizations.of(context)!.studentPasswordMustBe6Digits,
      );
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
        _error = AppLocalizations.of(context)!.incorrectEmailOrPassword;
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

  Future<void> _switchLanguage(String code) async {
    if (_isSwitchingLanguage || code == localeService.languageCode) return;
    _isSwitchingLanguage = true;
    setState(() => _languageContentOpacity = 0);
    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;
    await localeService.setLanguage(code);
    if (!mounted) return;
    setState(() => _languageContentOpacity = 1);
    await Future<void>.delayed(const Duration(milliseconds: 260));
    _isSwitchingLanguage = false;
  }

  Widget _languageTransition({required Widget child}) {
    return AnimatedOpacity(
      opacity: _languageContentOpacity,
      duration: Duration(
        milliseconds: _languageContentOpacity == 0 ? 140 : 260,
      ),
      curve: _languageContentOpacity == 0
          ? Curves.easeInCubic
          : Curves.easeOutCubic,
      child: child,
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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                        child: Row(
                          children: [
                            if (widget.onBack != null)
                              BackButton(
                                color: AppColors.text,
                                onPressed: widget.onBack,
                              ),
                            const Spacer(),
                            LanguageToggle(onLanguageSelected: _switchLanguage),
                          ],
                        ),
                      ),

                      // ── Brand header: crest + university + wordmark ───────
                      _languageTransition(
                        child: _MotionEntrance(
                          animation: _brandEntrance,
                          begin: const Offset(0, -0.035),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(24, 18, 24, 0),
                            child: Column(
                              children: [
                                const _Crest(size: 60),
                                const SizedBox(height: 18),
                                Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.kocUniversityWordmark,
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
                                  AppLocalizations.of(
                                    context,
                                  )!.signInToContinueSubtitle,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.text.withValues(
                                      alpha: 0.76,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // ── Form ─────────────────────────────────────────────
                      _languageTransition(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(22, 30, 22, 0),
                          child: _MotionEntrance(
                            animation: _formEntrance,
                            begin: const Offset(0, 0.045),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _AuthField(
                                  label: AppLocalizations.of(
                                    context,
                                  )!.campusEmailLabel,
                                  controller: _emailController,
                                  hint: AppLocalizations.of(
                                    context,
                                  )!.usernameHint,
                                  icon: Icons.mail_outline_rounded,
                                  keyboardType: TextInputType.text,
                                  suffixText: '@ku.edu.tr',
                                  inputFormatters: [_NoDomainFormatter()],
                                  onChanged: (_) =>
                                      setState(() => _error = null),
                                  onSubmitted: (_) => _handleLogin(),
                                ),
                                const SizedBox(height: 14),
                                _AuthField(
                                  label: AppLocalizations.of(
                                    context,
                                  )!.passwordFieldLabel,
                                  controller: _passwordController,
                                  hint: AppLocalizations.of(
                                    context,
                                  )!.digitPinHint(6),
                                  icon: Icons.lock_outline_rounded,
                                  obscureText: _obscurePassword,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(6),
                                  ],
                                  onChanged: (_) =>
                                      setState(() => _error = null),
                                  onSubmitted: (_) => _handleLogin(),
                                  trailing: GestureDetector(
                                    onTap: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
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
                                      AppLocalizations.of(
                                        context,
                                      )!.forgotPassword,
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
                      ),

                      const Spacer(),

                      // ── Bottom action area ───────────────────────────────
                      _languageTransition(
                        child: _MotionEntrance(
                          animation: _actionsEntrance,
                          begin: const Offset(0, 0.06),
                          child: Padding(
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
                                  AppLocalizations.of(
                                    context,
                                  )!.newToKocUniversity,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: AppColors.text.withValues(
                                      alpha: 0.76,
                                    ),
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
                                        AppLocalizations.of(context)!.signUp,
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
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  children: [
                                    Text(
                                      '${AppLocalizations.of(context)!.runningAClub} ',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.secondaryText,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: _openClubAdmin,
                                      child: Text(
                                        AppLocalizations.of(
                                          context,
                                        )!.clubAdminSignIn,
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

// ─── Coordinated entrance motion for the screen's visual hierarchy ───────────
class _MotionEntrance extends StatelessWidget {
  final Animation<double> animation;
  final Offset begin;
  final Widget child;

  const _MotionEntrance({
    required this.animation,
    required this.begin,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: begin,
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}

// ─── Responsive text field (label + animated surface + leading icon) ──────────
// Focus gently lifts and highlights the active input without shifting layout.
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
  late final FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (mounted) setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    final controller = widget.controller;
    final hint = widget.hint;
    final icon = widget.icon;
    final obscureText = widget.obscureText;
    final trailing = widget.trailing;
    final keyboardType = widget.keyboardType;
    final suffixText = widget.suffixText;
    final inputFormatters = widget.inputFormatters;
    final onChanged = widget.onChanged;
    final onSubmitted = widget.onSubmitted;
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
        AnimatedScale(
          scale: _focused ? 1.012 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            key: ValueKey<String>('login-field-$label'),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: _focused
                  ? AppColors.primaryRed.withValues(
                      alpha: isDark ? 0.10 : 0.045,
                    )
                  : isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.transparent,
              borderRadius: const BorderRadius.all(Radius.circular(14)),
              border: Border.all(
                color: _focused ? AppColors.primaryRed : AppColors.divider,
                width: _focused ? 1.8 : 1.5,
              ),
              boxShadow: _focused
                  ? [
                      BoxShadow(
                        color: AppColors.primaryRed.withValues(alpha: 0.13),
                        blurRadius: 16,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                TweenAnimationBuilder<Color?>(
                  tween: ColorTween(
                    end: _focused
                        ? AppColors.primaryRed
                        : AppColors.secondaryText,
                  ),
                  duration: const Duration(milliseconds: 180),
                  builder: (context, color, _) =>
                      Icon(icon, size: 19, color: color),
                ),
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
                      focusNode: _focusNode,
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
                    suffixText,
                    style: TextStyle(
                      fontSize: 15.5,
                      color: AppColors.secondaryText,
                      letterSpacing: -0.2,
                    ),
                  ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing],
              ],
            ),
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
class _SubmitButton extends StatefulWidget {
  final bool enabled;
  final bool submitting;
  final VoidCallback onTap;

  const _SubmitButton({
    required this.enabled,
    required this.submitting,
    required this.onTap,
  });

  @override
  State<_SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<_SubmitButton> {
  bool _pressed = false;

  void _release() {
    if (_pressed) setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled || widget.submitting;
    final interactive = widget.enabled && !widget.submitting;
    return GestureDetector(
      onTapDown: interactive ? (_) => setState(() => _pressed = true) : null,
      onTapUp: interactive ? (_) => _release() : null,
      onTapCancel: interactive ? _release : null,
      onTap: interactive
          ? () {
              HapticFeedback.lightImpact();
              widget.onTap();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
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
                      blurRadius: _pressed ? 10 : 20,
                      offset: Offset(0, _pressed ? 3 : 6),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: widget.submitting
                ? const SizedBox(
                    key: ValueKey('login-progress'),
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    key: const ValueKey('login-label'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.enabled) ...[
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        AppLocalizations.of(context)!.logIn,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: active
                              ? Colors.white
                              : AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
          ),
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
