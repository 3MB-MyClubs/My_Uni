import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_colors.dart';
import '../services/app_bootstrap.dart';
import '../services/auth_service.dart';
import '../services/app_strings.dart';
import '../services/club_passcode_auth_service.dart';
import '../l10n/app_localizations.dart';
import 'forgot_password_screen.dart';

class ClubAdminAuthScreen extends StatefulWidget {
  final VoidCallback onAdminLogin;
  const ClubAdminAuthScreen({super.key, required this.onAdminLogin});

  @override
  State<ClubAdminAuthScreen> createState() => _ClubAdminAuthScreenState();
}

class _ClubAdminAuthScreenState extends State<ClubAdminAuthScreen> {
  final _clubEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _error;

  bool _isLoading = false;

  static String _localPart(String email) {
    final at = email.indexOf('@');
    return at < 0 ? email : email.substring(0, at);
  }

  String _errorMessage(ClubPasscodeAuthError code) {
    final l10n = AppLocalizations.of(context)!;
    switch (code) {
      case ClubPasscodeAuthError.missingCredentials:
        return l10n.clubEmailPasscodeRequired;
      case ClubPasscodeAuthError.invalidPasscodeFormat:
        return l10n.passcodeMustBe8Digits;
      case ClubPasscodeAuthError.invalidCredentials:
        return l10n.invalidClubCredentials;
      case ClubPasscodeAuthError.notLinkedToClub:
        return l10n.clubNotLinked;
      case ClubPasscodeAuthError.linkedClubNotFound:
        return l10n.linkedClubNotFound;
      case ClubPasscodeAuthError.notConfigured:
        return l10n.clubLoginNotReady;
      case ClubPasscodeAuthError.banned:
        return S.bannedFromApp;
    }
  }

  Future<void> _handleAdminLogin() async {
    final localPart = _localPart(_clubEmailController.text.trim());
    final passcode = _passwordController.text.trim();
    if (localPart.isEmpty || passcode.isEmpty) {
      setState(
        () => _error = AppLocalizations.of(context)!.clubEmailPasscodeRequired,
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

    // Post-login screens read Hive boxes that open in the background after
    // first paint; by the time credentials are typed this is a no-op.
    await appBootstrap.ready;
    final result = await clubPasscodeAuthService.login(
      email: '${localPart.toLowerCase()}@ku.edu.tr',
      passcode: passcode,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success && result.admin != null) {
      authService.setClubAdmin(result.admin!);
      widget.onAdminLogin();
    } else {
      setState(
        () => _error = result.errorCode != null
            ? _errorMessage(result.errorCode!)
            : AppLocalizations.of(context)!.invalidClubCredentials,
      );
    }
  }

  Future<void> _openForgotPasscode() async {
    final localPart = _localPart(_clubEmailController.text.trim());
    final initialEmail = localPart.isEmpty
        ? ''
        : '${localPart.toLowerCase()}@ku.edu.tr';
    final resetEmail = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(
          initialEmail: initialEmail,
          passwordLength: 8,
          passwordNoun: 'passcode',
        ),
      ),
    );
    if (!mounted || resetEmail == null || resetEmail.isEmpty) return;
    setState(() {
      _clubEmailController.text = _localPart(resetEmail);
      _passwordController.clear();
      _error = null;
    });
  }

  @override
  void dispose() {
    _clubEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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

              // Shield badge
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.lightRed,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                child: Center(
                  child: Icon(
                    Icons.admin_panel_settings,
                    color: AppColors.primaryRed,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                AppLocalizations.of(context)!.clubAdminLoginTitle,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.clubAdminLoginSubtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              _buildField(
                controller: _clubEmailController,
                label: AppLocalizations.of(context)!.clubEmailLabel,
                hint: 'clubname',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.text,
                suffixText: '@ku.edu.tr',
                inputFormatters: [_NoDomainFormatter()],
                errorText: _error,
              ),
              const SizedBox(height: 14),

              // Password
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
                onSubmitted: (_) => _handleAdminLogin(),
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(
                    context,
                  )!.eightDigitPasscodeLabel,
                  hintText: AppLocalizations.of(context)!.eightDigitsHint,
                  prefixIcon: Icon(
                    Icons.lock_outline,
                    color: AppColors.secondaryText,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.secondaryText,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
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
                    borderSide: BorderSide(color: AppColors.divider, width: 1),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Forgot passcode
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading ? null : _openForgotPasscode,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.forgotPasscode,
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
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleAdminLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                    ),
                    elevation: 2,
                    shadowColor: AppColors.primaryRed.withValues(alpha: 0.4),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          AppLocalizations.of(context)!.logIn,
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

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? suffixText,
    List<TextInputFormatter>? inputFormatters,
    String? errorText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffixText,
        prefixIcon: Icon(icon, color: AppColors.secondaryText),
        errorText: errorText,
        filled: true,
        fillColor: Colors.transparent,
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
          borderSide: BorderSide(color: AppColors.divider, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: AppColors.primaryRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
    );
  }
}

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
