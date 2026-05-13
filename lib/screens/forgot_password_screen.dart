import 'dart:math';

import 'package:flutter/material.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';

enum _ResetStep { email, code, password, done }

class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

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
  String _code = '';
  String? _error;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  static final _emailRegex = RegExp(r'^[a-zA-Z0-9_.+-]+@ku\.edu\.tr$');

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

  bool get _hasMinLength => _passwordController.text.trim().length >= 8;
  bool get _hasOnlyNumbers =>
      RegExp(r'^[0-9]+$').hasMatch(_passwordController.text.trim());

  void _sendCode() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your KU email.');
      return;
    }
    if (!_emailRegex.hasMatch(email)) {
      setState(() => _error = 'Use your @ku.edu.tr email address.');
      return;
    }
    if (!authService.hasAccountEmail(email)) {
      setState(() => _error = 'No account found for this email.');
      return;
    }
    _email = email;
    _code = (100000 + Random().nextInt(900000)).toString();
    setState(() {
      _error = null;
      _step = _ResetStep.code;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Password reset code for $_email: $_code')),
    );
  }

  void _verifyCode() {
    if (_codeController.text.trim() != _code) {
      setState(() => _error = 'That code is not correct.');
      return;
    }
    setState(() {
      _error = null;
      _step = _ResetStep.password;
    });
  }

  void _updatePassword() {
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();
    if (!_hasMinLength) {
      setState(() => _error = 'Password must be at least 8 numbers.');
      return;
    }
    if (!_hasOnlyNumbers) {
      setState(() => _error = 'Password must contain numbers only.');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    final ok = authService.resetAccountPassword(_email, password);
    if (!ok) {
      setState(() => _error = 'Could not update this account.');
      return;
    }
    setState(() {
      _error = null;
      _step = _ResetStep.done;
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
                  onPressed: _buttonAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _buttonText,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
    switch (_step) {
      case _ResetStep.email:
        return 'Reset password';
      case _ResetStep.code:
        return 'Check your email';
      case _ResetStep.password:
        return 'Create new password';
      case _ResetStep.done:
        return 'Password updated';
    }
  }

  String get _subtitle {
    switch (_step) {
      case _ResetStep.email:
        return 'Enter the KU email for your account.';
      case _ResetStep.code:
        return 'Enter the one-time code sent to $_email.';
      case _ResetStep.password:
        return 'Use a numbers-only password for future sign-ins.';
      case _ResetStep.done:
        return 'You can now sign in with your new password.';
    }
  }

  String get _buttonText {
    switch (_step) {
      case _ResetStep.email:
        return 'Send code';
      case _ResetStep.code:
        return 'Verify code';
      case _ResetStep.password:
        return 'Update password';
      case _ResetStep.done:
        return 'Back to sign in';
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
            label: 'KU Email',
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
                label: 'One-time code',
                hint: 'Enter 6-digit code',
                icon: Icons.password_outlined,
                errorText: _error,
              ).copyWith(counterText: ''),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _sendCode,
              child: Text(
                'Send a new code',
                style: TextStyle(color: AppColors.primaryRed),
              ),
            ),
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
              onChanged: (_) => setState(() => _error = null),
              decoration: _fieldDecoration(
                label: 'New password',
                hint: 'Numbers only',
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
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _updatePassword(),
              decoration: _fieldDecoration(
                label: 'Confirm password',
                hint: 'Re-enter numbers only',
                icon: Icons.lock_outline,
                suffixIcon: _visibilityButton(
                  _obscureConfirm,
                  () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
            ),
            const SizedBox(height: 18),
            _RuleRow(label: 'At least 8 numbers', passed: _hasMinLength),
            _RuleRow(label: 'Numbers only', passed: _hasOnlyNumbers),
          ],
        );
      case _ResetStep.done:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.lightRed,
            borderRadius: BorderRadius.circular(14),
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
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.primaryRed, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.primaryRed),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
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
        borderRadius: BorderRadius.circular(16),
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
