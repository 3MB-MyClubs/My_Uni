import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'signup_theme.dart';

class StepEmail extends StatefulWidget {
  final String initialValue;
  final String? externalError;
  final Future<String?> Function(String email) onNext;

  const StepEmail({
    super.key,
    this.initialValue = '',
    this.externalError,
    required this.onNext,
  });

  @override
  State<StepEmail> createState() => _StepEmailState();
}

class _StepEmailState extends State<StepEmail> {
  late final TextEditingController _controller;
  String? _error;
  bool _isSubmitting = false;

  static const _domain = '@ku.edu.tr';
  static final _localPartRegex = RegExp(r'^[a-zA-Z0-9_.+-]+$');
  static final _emailRegex = RegExp(r'^[a-zA-Z0-9_.+-]+@ku\.edu\.tr$');

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(StepEmail old) {
    super.didUpdateWidget(old);
    if (widget.externalError != old.externalError) {
      setState(() => _error = widget.externalError);
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final input = _controller.text.trim().toLowerCase();
    if (input.isEmpty) {
      setState(
        () => _error = AppLocalizations.of(context)!.pleaseEnterUniversityEmail,
      );
      return;
    }

    final email = input.contains('@') ? input : '$input$_domain';
    if (!_emailRegex.hasMatch(email) ||
        !_localPartRegex.hasMatch(email.substring(0, email.indexOf('@')))) {
      setState(
        () => _error = AppLocalizations.of(context)!.onlyKuAddressesAccepted,
      );
      return;
    }
    setState(() {
      _error = null;
      _isSubmitting = true;
    });
    final error = await widget.onNext(email);
    if (!mounted) return;
    setState(() {
      _error = error;
      _isSubmitting = false;
    });
  }

  void _normalizePastedAddress(String value) {
    if (!value.toLowerCase().endsWith(_domain)) return;
    final localPart = value.substring(0, value.length - _domain.length);
    _controller.value = TextEditingValue(
      text: localPart,
      selection: TextSelection.collapsed(offset: localPart.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  AppLocalizations.of(context)!.whatsYourSchoolEmail,
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
                  AppLocalizations.of(context)!.sendCodeToConfirmKocStudent,
                  style: TextStyle(
                    fontSize: 15,
                    color: SC.body,
                    height: 1.45,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 28),

                // Email field
                TextField(
                  controller: _controller,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onChanged: _normalizePastedAddress,
                  onSubmitted: (_) => _submit(),
                  style: TextStyle(
                    color: SC.ink,
                    fontSize: 16,
                    letterSpacing: -0.1,
                  ),
                  decoration: SC.fieldDecoration(
                    label: AppLocalizations.of(context)!.universityEmailLabel,
                    hint: 'htuncay23',
                    suffixText: _domain,
                    errorText: _error,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Continue button — pinned to bottom
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: SC.primaryButtonStyle(),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(AppLocalizations.of(context)!.continueButton),
            ),
          ),
        ),
      ],
    );
  }
}
