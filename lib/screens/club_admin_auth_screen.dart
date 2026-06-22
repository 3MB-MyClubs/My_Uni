import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/club_passcode_auth_service.dart';

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

  Future<void> _handleAdminLogin() async {
    final localPart = _localPart(_clubEmailController.text.trim());
    final passcode = _passwordController.text.trim();
    if (localPart.isEmpty || passcode.isEmpty) {
      setState(() => _error = 'Club email and passcode are required');
      return;
    }
    if (!authService.isValidClubPassword(passcode)) {
      setState(() => _error = 'Passcode must be exactly 8 digits');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

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
      setState(() => _error = result.error ?? 'Invalid club email or passcode');
    }
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
                  borderRadius: BorderRadius.circular(16),
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
                'Club Admin Login',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the club email and 8 digit passcode to manage your club.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              _buildField(
                controller: _clubEmailController,
                label: 'Club Email',
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
                  labelText: '8 digit passcode',
                  hintText: '8 digits',
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
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.divider, width: 1),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleAdminLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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
                          'Sign In as Admin',
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
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.divider, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primaryRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
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
