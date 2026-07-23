import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/app_localizations.dart';
import 'signup_theme.dart';

class StepVerify extends StatefulWidget {
  final String email;
  final Future<String?> Function(String code) onNext;
  final Future<String?> Function() onResend;

  const StepVerify({
    super.key,
    required this.email,
    required this.onNext,
    required this.onResend,
  });

  @override
  State<StepVerify> createState() => _StepVerifyState();
}

class _StepVerifyState extends State<StepVerify> {
  static const int _codeLength = 6;
  final List<TextEditingController> _controllers = List.generate(
    _codeLength,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    _codeLength,
    (_) => FocusNode(),
  );
  String? _error;
  String? _message;
  bool _isVerifying = false;
  bool _isResending = false;

  // Resend countdown
  Timer? _timer;
  int _secondsLeft = 60;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _onDigitChanged(int index, String val) {
    if (val.length == 1 && index < _codeLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_controllers.every((c) => c.text.isNotEmpty)) {
      _verify();
    }
  }

  void _onKeyBackspace(int index) {
    if (_controllers[index].text.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
    }
  }

  Future<void> _verify() async {
    if (_isVerifying) return;
    final code = _controllers.map((c) => c.text).join();
    if (code.length < _codeLength) {
      setState(() {
        _message = null;
        _error = AppLocalizations.of(context)!.enterFullSixDigitCode;
      });
      return;
    }
    setState(() {
      _error = null;
      _message = null;
      _isVerifying = true;
    });
    final error = await widget.onNext(code);
    if (!mounted) return;
    setState(() {
      _error = error;
      _isVerifying = false;
    });
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0 || _isResending) return;
    setState(() {
      _error = null;
      _message = null;
      _isResending = true;
    });
    final error = await widget.onResend();
    if (!mounted) return;
    if (error == null) {
      for (final controller in _controllers) {
        controller.clear();
      }
      _focusNodes.first.requestFocus();
    }
    setState(() {
      _error = error;
      _message = error == null
          ? AppLocalizations.of(context)!.newCodeSent
          : null;
      _isResending = false;
    });
    if (error == null) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _timerLabel {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final displayEmail = widget.email.isNotEmpty
        ? widget.email
        : AppLocalizations.of(context)!.yourEmailFallback;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.checkYourInboxTitle,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: SC.ink,
                    height: 1.1,
                    letterSpacing: -0.9,
                  ),
                ),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 15,
                      color: SC.body,
                      height: 1.45,
                      letterSpacing: -0.1,
                    ),
                    children: [
                      TextSpan(
                        text: AppLocalizations.of(context)!.weSentCodeToPrefix,
                      ),
                      TextSpan(
                        text: displayEmail,
                        style: TextStyle(
                          color: SC.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // OTP boxes
                Row(
                  children: List.generate(_codeLength, (i) {
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: i < _codeLength - 1 ? 8 : 0,
                        ),
                        child: _OtpBox(
                          controller: _controllers[i],
                          focusNode: _focusNodes[i],
                          onChanged: (v) => _onDigitChanged(i, v),
                          onBackspace: () => _onKeyBackspace(i),
                        ),
                      ),
                    );
                  }),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: TextStyle(color: SC.burgundy, fontSize: 13),
                  ),
                ],
                if (_message != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _message!,
                    style: TextStyle(
                      color: SC.burgundyDeep,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.didntGetCode,
                      style: TextStyle(fontSize: 14, color: SC.muted),
                    ),
                    GestureDetector(
                      onTap: _resend,
                      child: Text(
                        _isResending
                            ? AppLocalizations.of(context)!.sendingEllipsis
                            : _secondsLeft > 0
                            ? AppLocalizations.of(
                                context,
                              )!.resendInTime(_timerLabel)
                            : AppLocalizations.of(context)!.resendCodeButton,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _secondsLeft > 0 || _isResending
                              ? SC.muted
                              : SC.burgundy,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Verify button — pinned to bottom
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isVerifying ? null : _verify,
              style: SC.primaryButtonStyle(),
              child: _isVerifying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(AppLocalizations.of(context)!.verifyButton),
            ),
          ),
        ),
      ],
    );
  }
}

// ── OTP digit box ─────────────────────────────────────────────────────────────
class _OtpBox extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onBackspace,
  });

  @override
  State<_OtpBox> createState() => _OtpBoxState();
}

class _OtpBoxState extends State<_OtpBox> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() => _focused = widget.focusNode.hasFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace) {
          widget.onBackspace();
        }
      },
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: SC.card,
          borderRadius: BorderRadius.all(Radius.circular(12)),
          border: Border.all(
            color: _focused ? SC.burgundy : SC.hairStrong,
            width: _focused ? 1.5 : 1,
          ),
          boxShadow: _focused
              ? [
                  BoxShadow(
                    color: SC.burgundyTint,
                    spreadRadius: 3,
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(1),
          ],
          onChanged: widget.onChanged,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: SC.ink,
            letterSpacing: -0.5,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}
