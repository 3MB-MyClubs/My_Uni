import 'package:flutter/material.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLogin;
  final VoidCallback? onBack;
  const LoginScreen({super.key, required this.onLogin, this.onBack});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  String? _error;

  void _handleLogin() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email');
      return;
    }
    if (authService.login(email)) {
      widget.onLogin();
    } else {
      setState(() => _error = 'No account found for this email');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
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
              ),
              const SizedBox(height: 28),
              Text(
                'Welcome back',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your Koç University email to continue.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 36),

              // Email field
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                onSubmitted: (_) => _handleLogin(),
                decoration: InputDecoration(
                  labelText: 'KU Email',
                  hintText: 'you@ku.edu.tr',
                  prefixIcon: Icon(Icons.email_outlined,
                      color: AppColors.secondaryText),
                  errorText: _error,
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
                    borderSide: BorderSide(
                        color: AppColors.primaryRed, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: AppColors.primaryRed),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: AppColors.primaryRed, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Quick-fill chip
              GestureDetector(
                onTap: () {
                  _emailController.text = 'htuncay23@ku.edu.tr';
                  setState(() => _error = null);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.lightRed,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.primaryRed.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded,
                          size: 14, color: AppColors.primaryRed),
                      SizedBox(width: 5),
                      Text(
                        'htuncay23@ku.edu.tr',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Continue button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleLogin,
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
                  child: Text('Continue',
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
}
