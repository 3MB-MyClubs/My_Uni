import 'package:flutter/material.dart';
import 'signup_theme.dart';

class StepPassword extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onNext;

  const StepPassword({super.key, this.initialValue = '', required this.onNext});

  @override
  State<StepPassword> createState() => _StepPasswordState();
}

class _StepPasswordState extends State<StepPassword> {
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmController;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController(text: widget.initialValue);
    _confirmController = TextEditingController();
  }

  bool get _isExactlySix => _passwordController.text.trim().length == 6;
  bool get _hasOnlyNumbers =>
      RegExp(r'^[0-9]+$').hasMatch(_passwordController.text.trim());

  void _submit() {
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();
    if (!_hasOnlyNumbers || !_isExactlySix) {
      setState(() => _error = 'Password must be exactly 6 digits (numbers only).');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() => _error = null);
    widget.onNext(password);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final passedRules = [
      _isExactlySix,
      _hasOnlyNumbers,
    ].where((rule) => rule).length;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create a password.',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: SC.ink,
                    height: 1.1,
                    letterSpacing: -0.9,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Choose a 6-digit PIN — numbers only, no letters or symbols.",
                  style: TextStyle(
                    fontSize: 15,
                    color: SC.body,
                    height: 1.45,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() => _error = null),
                  style: TextStyle(color: SC.ink, fontSize: 16),
                  decoration: SC.fieldDecoration(
                    label: 'Password',
                    hint: '6-digit PIN',
                    prefixIcon: Icon(Icons.lock_outline, color: SC.muted),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: SC.muted,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    errorText: _error,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmController,
                  obscureText: _obscureConfirm,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  onChanged: (_) => setState(() => _error = null),
                  style: TextStyle(color: SC.ink, fontSize: 16),
                  decoration: SC.fieldDecoration(
                    label: 'Confirm password',
                    hint: 'Re-enter 6-digit PIN',
                    prefixIcon: Icon(Icons.lock_outline, color: SC.muted),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: SC.muted,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: passedRules / 2,
                    minHeight: 4,
                    backgroundColor: SC.hairStrong,
                    valueColor: AlwaysStoppedAnimation<Color>(SC.burgundy),
                  ),
                ),
                const SizedBox(height: 18),
                _RuleRow(label: 'Exactly 6 digits', passed: _isExactlySix),
                _RuleRow(label: 'Numbers only', passed: _hasOnlyNumbers),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _submit,
              style: SC.primaryButtonStyle(),
              child: Text('Set password'),
            ),
          ),
        ),
      ],
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
            color: passed ? SC.burgundy : SC.muted,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: passed ? SC.ink : SC.body,
              fontWeight: passed ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
