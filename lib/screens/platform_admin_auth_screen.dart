import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../services/app_bootstrap.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/platform_admin_auth_service.dart';
import 'forgot_password_screen.dart';

class PlatformAdminAuthScreen extends StatefulWidget {
  final VoidCallback onAdminLogin;

  const PlatformAdminAuthScreen({super.key, required this.onAdminLogin});

  @override
  State<PlatformAdminAuthScreen> createState() =>
      _PlatformAdminAuthScreenState();
}

class _PlatformAdminAuthScreenState extends State<PlatformAdminAuthScreen> {
  final _emailController = TextEditingController();
  final _passcodeController = TextEditingController();
  bool _obscurePasscode = true;
  bool _isLoading = false;
  String? _error;

  String _errorMessage(PlatformAdminAuthError code) {
    final l10n = AppLocalizations.of(context)!;
    return switch (code) {
      PlatformAdminAuthError.missingCredentials =>
        l10n.adminCredentialsRequired,
      PlatformAdminAuthError.invalidPasscodeFormat =>
        l10n.passcodeMustBe8Digits,
      PlatformAdminAuthError.invalidCredentials => l10n.invalidAdminCredentials,
      PlatformAdminAuthError.unauthorized => l10n.notPlatformAdmin,
      PlatformAdminAuthError.notConfigured => l10n.supabaseNotConfigured,
    };
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;
    final email = _emailController.text.trim();
    final passcode = _passcodeController.text.trim();
    if (email.isEmpty || passcode.isEmpty) {
      setState(
        () => _error = AppLocalizations.of(context)!.adminCredentialsRequired,
      );
      return;
    }
    if (!authService.isValidClubPassword(passcode)) {
      setState(
        () => _error = AppLocalizations.of(context)!.passcodeMustBe8Digits,
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    await appBootstrap.ready;
    final result = await platformAdminAuthService.login(
      email: email,
      passcode: passcode,
    );

    if (!mounted) return;
    if (result.success && result.admin != null) {
      authService.setClubAdmin(result.admin!);
      widget.onAdminLogin();
      return;
    }

    setState(() {
      _isLoading = false;
      _error = _errorMessage(
        result.errorCode ?? PlatformAdminAuthError.invalidCredentials,
      );
    });
  }

  Future<void> _openForgotPasscode() async {
    final initialEmail = _emailController.text.trim().toLowerCase();
    final resetEmail = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(
          initialEmail: initialEmail,
          passwordLength: 8,
          passwordNoun: 'passcode',
          allowExternalEmail: true,
        ),
      ),
    );
    if (!mounted || resetEmail == null) return;
    _emailController.text = resetEmail;
    _passcodeController.clear();
    setState(() => _error = null);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passcodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      key: const ValueKey<String>('platform-admin-auth-screen'),
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.text,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primaryRed, AppColors.darkRed],
                  ),
                  borderRadius: const BorderRadius.all(Radius.circular(18)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryRed.withValues(alpha: 0.28),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.security_rounded,
                  color: Colors.white,
                  size: 29,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                l10n.platformAdminLoginTitle,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.platformAdminLoginSubtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                key: const ValueKey<String>('platform-admin-email'),
                controller: _emailController,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.email],
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                decoration: InputDecoration(
                  labelText: l10n.adminEmailLabel,
                  hintText: 'admin@example.com',
                  prefixIcon: Icon(
                    Icons.email_outlined,
                    color: AppColors.secondaryText,
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(14)),
                    borderSide: BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(14)),
                    borderSide: BorderSide(
                      color: AppColors.primaryRed,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey<String>('platform-admin-passcode'),
                controller: _passcodeController,
                obscureText: _obscurePasscode,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _handleLogin(),
                decoration: InputDecoration(
                  labelText: l10n.eightDigitPasscodeLabel,
                  hintText: l10n.eightDigitsHint,
                  errorText: _error,
                  prefixIcon: Icon(
                    Icons.password_rounded,
                    color: AppColors.secondaryText,
                  ),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePasscode = !_obscurePasscode),
                    icon: Icon(
                      _obscurePasscode
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.secondaryText,
                      size: 20,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(14)),
                    borderSide: BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(14)),
                    borderSide: BorderSide(
                      color: AppColors.primaryRed,
                      width: 1.4,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(14)),
                    borderSide: BorderSide(color: AppColors.primaryRed),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(14)),
                    borderSide: BorderSide(
                      color: AppColors.primaryRed,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading ? null : _openForgotPasscode,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    l10n.forgotPasscode,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryRed,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: const ValueKey<String>('platform-admin-login-button'),
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                    ),
                    elevation: 2,
                    shadowColor: AppColors.primaryRed.withValues(alpha: 0.4),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.admin_panel_settings_rounded),
                  label: Text(
                    l10n.logIn,
                    style: const TextStyle(
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
}
