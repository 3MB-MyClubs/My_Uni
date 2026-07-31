import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_colors.dart';
import '../services/password_reset_service.dart';
import '../l10n/app_localizations.dart';

enum _ResetStep { email, code, password, done }

class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;

  /// Required digit count for the new credential (6 for students, 8 for clubs).
  final int passwordLength;

  /// What the credential is called in the copy ('password' or 'passcode').
  final String passwordNoun;

  /// Club accounts can use an approved external address. Student accounts
  /// remain restricted to the university domain.
  final bool allowExternalEmail;

  const ForgotPasswordScreen({
    super.key,
    this.initialEmail = '',
    this.passwordLength = 6,
    this.passwordNoun = 'password',
    this.allowExternalEmail = false,
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _emailController;
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  _ResetStep _step = _ResetStep.email;
  String _email = '';
  String? _error;
  String? _message;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  static final _emailRegex = RegExp(r'^[a-zA-Z0-9_.+-]+@ku\.edu\.tr$');
  static final _generalEmailRegex = RegExp(
    r'^[a-zA-Z0-9.!#$%&\x27*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
  );

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _isExactLength =>
      _passwordController.text.trim().length == widget.passwordLength;
  bool get _hasOnlyNumbers =>
      RegExp(r'^[0-9]+$').hasMatch(_passwordController.text.trim());

  Future<void> _sendCode() async {
    if (_isSubmitting) return;
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = AppLocalizations.of(context)!.pleaseEnterKuEmail);
      return;
    }
    final isValidEmail = widget.allowExternalEmail
        ? _generalEmailRegex.hasMatch(email)
        : _emailRegex.hasMatch(email);
    if (!isValidEmail) {
      setState(
        () => _error = widget.allowExternalEmail
            ? AppLocalizations.of(context)!.useValidEmailAddress
            : AppLocalizations.of(context)!.useKuEmailAddress,
      );
      return;
    }
    setState(() {
      _email = email;
      _error = null;
      _message = null;
      _isSubmitting = true;
    });
    final result = await passwordResetService.sendCode(email);
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _error = result.error;
        _isSubmitting = false;
      });
      return;
    }
    setState(() {
      _error = null;
      _message = null;
      _step = _ResetStep.code;
      _isSubmitting = false;
    });
  }

  Future<void> _resendCode() async {
    if (_isSubmitting) return;
    setState(() {
      _error = null;
      _message = null;
      _isSubmitting = true;
    });
    final result = await passwordResetService.sendCode(_email);
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _error = result.error;
        _isSubmitting = false;
      });
      return;
    }
    _codeController.clear();
    setState(() {
      _message = AppLocalizations.of(context)!.newCodeSent;
      _isSubmitting = false;
    });
  }

  Future<void> _verifyCode() async {
    if (_isSubmitting) return;
    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() {
        _message = null;
        _error = AppLocalizations.of(context)!.enterSixDigitCode;
      });
      return;
    }
    setState(() {
      _error = null;
      _message = null;
      _isSubmitting = true;
    });
    final result = await passwordResetService.verifyCode(
      email: _email,
      code: code,
    );
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _error = result.error;
        _isSubmitting = false;
      });
      return;
    }
    setState(() {
      _error = null;
      _message = null;
      _step = _ResetStep.password;
      _isSubmitting = false;
    });
  }

  Future<void> _updatePassword() async {
    if (_isSubmitting) return;
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();
    if (!_isExactLength) {
      setState(() {
        _message = null;
        _error = AppLocalizations.of(
          context,
        )!.credentialMustBeNDigits(widget.passwordNoun, widget.passwordLength);
      });
      return;
    }
    if (!_hasOnlyNumbers) {
      setState(() {
        _message = null;
        _error = AppLocalizations.of(
          context,
        )!.credentialNumbersOnly(widget.passwordNoun);
      });
      return;
    }
    if (password != confirm) {
      setState(() {
        _message = null;
        _error = AppLocalizations.of(context)!.passwordsDoNotMatch;
      });
      return;
    }
    setState(() {
      _error = null;
      _message = null;
      _isSubmitting = true;
    });
    final result = await passwordResetService.updatePassword(
      email: _email,
      password: password,
    );
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _error = result.error;
        _isSubmitting = false;
      });
      return;
    }
    setState(() {
      _error = null;
      _message = null;
      _step = _ResetStep.done;
      _isSubmitting = false;
    });
  }

  void _finish() {
    Navigator.of(context).pop(_email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.text,
        leading: BackButton(onPressed: () => Navigator.of(context).maybePop()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              _KuBadge(),
              const SizedBox(height: 28),
              Text(
                _title,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 36),
              _body,
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _buttonAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _buttonText,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _title {
    final l10n = AppLocalizations.of(context)!;
    switch (_step) {
      case _ResetStep.email:
        return l10n.resetCredentialTitle(widget.passwordNoun);
      case _ResetStep.code:
        return l10n.checkYourEmailTitle;
      case _ResetStep.password:
        return l10n.createNewCredentialTitle(widget.passwordNoun);
      case _ResetStep.done:
        return l10n.credentialUpdatedTitle(widget.passwordNoun);
    }
  }

  String get _subtitle {
    final l10n = AppLocalizations.of(context)!;
    switch (_step) {
      case _ResetStep.email:
        return widget.allowExternalEmail
            ? l10n.enterAccountEmailSubtitle
            : l10n.enterKuEmailSubtitle;
      case _ResetStep.code:
        return l10n.enterCodeSubtitle(_email);
      case _ResetStep.password:
        return l10n.newCredentialSubtitle(
          widget.passwordNoun,
          widget.passwordLength,
        );
      case _ResetStep.done:
        return l10n.credentialUpdatedSubtitle(widget.passwordNoun);
    }
  }

  String get _buttonText {
    final l10n = AppLocalizations.of(context)!;
    switch (_step) {
      case _ResetStep.email:
        return l10n.sendCodeButton;
      case _ResetStep.code:
        return l10n.verifyCodeButton;
      case _ResetStep.password:
        return l10n.updateCredentialButton(widget.passwordNoun);
      case _ResetStep.done:
        return l10n.backToSignIn;
    }
  }

  VoidCallback get _buttonAction {
    switch (_step) {
      case _ResetStep.email:
        return _sendCode;
      case _ResetStep.code:
        return _verifyCode;
      case _ResetStep.password:
        return _updatePassword;
      case _ResetStep.done:
        return _finish;
    }
  }

  Widget get _body {
    switch (_step) {
      case _ResetStep.email:
        return TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          onSubmitted: (_) => _sendCode(),
          decoration: _fieldDecoration(
            label: AppLocalizations.of(context)!.kuEmailLabel,
            hint: 'you@ku.edu.tr',
            icon: Icons.email_outlined,
            errorText: _error,
          ),
        );
      case _ResetStep.code:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _codeController,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              onSubmitted: (_) => _verifyCode(),
              decoration: _fieldDecoration(
                label: AppLocalizations.of(context)!.oneTimeCodeLabel,
                hint: AppLocalizations.of(context)!.enterSixDigitCodeHint,
                icon: Icons.password_outlined,
                errorText: _error,
              ).copyWith(counterText: ''),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _isSubmitting ? null : _resendCode,
              child: Text(
                _isSubmitting
                    ? AppLocalizations.of(context)!.sendingEllipsis
                    : AppLocalizations.of(context)!.sendNewCode,
                style: TextStyle(color: AppColors.primaryRed),
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 4),
              Text(
                _message!,
                style: TextStyle(
                  color: AppColors.primaryRed,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        );
      case _ResetStep.password:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(widget.passwordLength),
              ],
              onChanged: (_) => setState(() => _error = null),
              decoration: _fieldDecoration(
                label: AppLocalizations.of(
                  context,
                )!.newCredentialLabel(widget.passwordNoun),
                hint: AppLocalizations.of(
                  context,
                )!.digitPinHint(widget.passwordLength),
                icon: Icons.lock_outline,
                errorText: _error,
                suffixIcon: _visibilityButton(
                  _obscurePassword,
                  () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(widget.passwordLength),
              ],
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _updatePassword(),
              decoration: _fieldDecoration(
                label: AppLocalizations.of(
                  context,
                )!.confirmCredentialLabel(widget.passwordNoun),
                hint: AppLocalizations.of(
                  context,
                )!.reenterDigitPinHint(widget.passwordLength),
                icon: Icons.lock_outline,
                suffixIcon: _visibilityButton(
                  _obscureConfirm,
                  () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
            ),
            const SizedBox(height: 18),
            _RuleRow(
              label: AppLocalizations.of(
                context,
              )!.exactlyNDigits(widget.passwordLength),
              passed: _isExactLength,
            ),
            _RuleRow(
              label: AppLocalizations.of(context)!.numbersOnly,
              passed: _hasOnlyNumbers,
            ),
          ],
        );
      case _ResetStep.done:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.lightRed,
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          child: Text(
            _email,
            style: TextStyle(
              color: AppColors.primaryRed,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
    }
  }

  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
    required IconData icon,
    String? errorText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.secondaryText),
      suffixIcon: suffixIcon,
      errorText: errorText,
      filled: true,
      fillColor: AppColors.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: AppColors.primaryRed, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: AppColors.primaryRed),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: AppColors.primaryRed, width: 2),
      ),
    );
  }

  Widget _visibilityButton(bool obscure, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(
        obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: AppColors.secondaryText,
        size: 20,
      ),
      onPressed: onPressed,
    );
  }
}

class _KuBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.lightRed,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Center(
        child: Text(
          'KU',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppColors.primaryRed,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  final String label;
  final bool passed;

  const _RuleRow({required this.label, required this.passed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            passed ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: passed ? AppColors.primaryRed : AppColors.secondaryText,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: passed ? AppColors.text : AppColors.secondaryText,
              fontWeight: passed ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
