import 'package:flutter/material.dart';
import 'signup_theme.dart';

class StepEmail extends StatefulWidget {
  final String initialValue;
  final String? externalError;
  final ValueChanged<String> onNext;

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

  static final _emailRegex =
      RegExp(r'^[a-zA-Z0-9_.+-]+@ku\.edu\.tr$');

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

  void _submit() {
    final val = _controller.text.trim();
    if (val.isEmpty) {
      setState(() => _error = 'Please enter your university email.');
      return;
    }
    if (!_emailRegex.hasMatch(val)) {
      setState(() => _error = 'Only @ku.edu.tr addresses are accepted.');
      return;
    }
    setState(() => _error = null);
    widget.onNext(val);
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
                  "What's your\nschool email?",
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
                  "We'll send a code to confirm you're a Koç student.",
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
                  onSubmitted: (_) => _submit(),
                  style: TextStyle(
                      color: SC.ink, fontSize: 16, letterSpacing: -0.1),
                  decoration: SC.fieldDecoration(
                    label: 'University email',
                    hint: 'you@ku.edu.tr',
                    suffixText: '@ku.edu.tr',
                    errorText: _error,
                  ),
                ),
                const SizedBox(height: 10),

                // Info box — circular "i" icon
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: SC.burgundyTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: SC.burgundy,
                        ),
                        child: Center(
                          child: Text(
                            'i',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: SC.burgundyDeep,
                              fontSize: 12,
                              height: 1.4,
                            ),
                            children: [
                              TextSpan(text: 'Only '),
                              TextSpan(
                                text: '@ku.edu.tr',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              TextSpan(
                                text:
                                    " addresses are accepted. Personal emails won't work.",
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
              onPressed: _submit,
              style: SC.primaryButtonStyle(),
              child: Text('Continue'),
            ),
          ),
        ),
      ],
    );
  }
}
