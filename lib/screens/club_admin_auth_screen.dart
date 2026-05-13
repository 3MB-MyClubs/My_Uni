import 'package:flutter/material.dart';
import '../services/app_colors.dart';
import '../services/mock_data.dart';
import '../services/auth_service.dart';

class ClubAdminAuthScreen extends StatefulWidget {
  final VoidCallback onAdminLogin;
  const ClubAdminAuthScreen({super.key, required this.onAdminLogin});

  @override
  State<ClubAdminAuthScreen> createState() => _ClubAdminAuthScreenState();
}

class _ClubAdminAuthScreenState extends State<ClubAdminAuthScreen> {
  final _clubNameController = TextEditingController();
  final _clubEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _error;

  void _handleAdminLogin() {
    final clubName = _clubNameController.text.trim();
    final clubEmail = _clubEmailController.text.trim();
    final password = _passwordController.text.trim();
    if (clubName.isEmpty || clubEmail.isEmpty || password.isEmpty) {
      setState(() => _error = 'All fields are required');
      return;
    }
    final allAdmins = [appAdmin, ...clubAdmins];
    final matched = allAdmins.any(
      (a) =>
          a.name == clubName && a.email == clubEmail && a.password == password,
    );
    if (matched) {
      authService.login(clubEmail, password);
      widget.onAdminLogin();
    } else {
      setState(() => _error = 'Invalid club admin credentials');
    }
  }

  @override
  void dispose() {
    _clubNameController.dispose();
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
                'Enter your club admin credentials to manage your club.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              _buildField(
                controller: _clubNameController,
                label: 'Club Name',
                hint: 'e.g. Robotics Club',
                icon: Icons.groups_outlined,
              ),
              const SizedBox(height: 14),
              _buildField(
                controller: _clubEmailController,
                label: 'Club Email',
                hint: 'club@ku.edu.tr',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                errorText: _error,
              ),
              const SizedBox(height: 14),

              // Password
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                keyboardType: TextInputType.number,
                onSubmitted: (_) => _handleAdminLogin(),
                decoration: InputDecoration(
                  labelText: 'Password',
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
                    borderSide: BorderSide(
                      color: AppColors.primaryRed,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleAdminLogin,
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
                  child: Text(
                    'Sign In as Admin',
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

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? errorText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.secondaryText),
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
      ),
    );
  }
}
