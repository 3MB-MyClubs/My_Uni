import 'package:flutter/material.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';

class SignUpScreen extends StatefulWidget {
  final VoidCallback onSignUp;
  final VoidCallback? onBack;
  const SignUpScreen({super.key, required this.onSignUp, this.onBack});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _error;

  void _handleSignUp() {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    final emailRegex = RegExp(r'^[a-zA-Z0-9_.+-]+@ku\.edu\.tr$');
    if (email.isEmpty || password.isEmpty || name.isEmpty) {
      setState(() => _error = 'All fields are required');
      return;
    }
    if (!emailRegex.hasMatch(email)) {
      setState(() => _error = 'Please use your @ku.edu.tr email');
      return;
    }
    final success = authService.signUp(name, email, password);
    if (success) {
      widget.onSignUp();
    } else {
      setState(() => _error = 'An account with this email already exists');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
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
        leading: BackButton(
            onPressed:
                widget.onBack ?? () => Navigator.of(context).maybePop()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // KU badge
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.lightRed,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
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
              ),
              const SizedBox(height: 28),
              const Text(
                'Create your account',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Use your @ku.edu.tr email to join the Koç University community.',
                style: TextStyle(
                  fontSize: 14,
                  
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // Name
              _buildField(
                controller: _nameController,
                label: 'Full Name',
                hint: 'e.g. Ali Yılmaz',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 14),

              // Email
              _buildField(
                controller: _emailController,
                label: 'KU Email',
                hint: 'you@ku.edu.tr',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                errorText: _error,
              ),
              const SizedBox(height: 14),

              // Password
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                onSubmitted: (_) => _handleSignUp(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'At least 6 characters',
                  prefixIcon: Icon(Icons.lock_outline,
                      color: AppColors.secondaryText),
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
                    borderSide:
                        BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: AppColors.primaryRed, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleSignUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                    shadowColor:
                        AppColors.primaryRed.withValues(alpha: 0.4),
                  ),
                  child: const Text('Create Account',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
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
          borderSide:
              BorderSide(color: AppColors.primaryRed, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primaryRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: AppColors.primaryRed, width: 2),
        ),
      ),
    );
  }
}
