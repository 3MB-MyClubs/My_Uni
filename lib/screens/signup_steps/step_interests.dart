import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/signup_service.dart';
import 'signup_theme.dart';

const int kMinInterests = 3;

class StepInterests extends StatefulWidget {
  final List<String> selected;
  final Future<List<SignupLookupItem>> Function() loadInterests;
  final Future<String?> Function(List<String> interestIds) onNext;
  final VoidCallback onSkip;

  const StepInterests({
    super.key,
    this.selected = const [],
    required this.loadInterests,
    required this.onNext,
    required this.onSkip,
  });

  @override
  State<StepInterests> createState() => _StepInterestsState();
}

class _StepInterestsState extends State<StepInterests> {
  late Set<String> _selected;
  List<SignupLookupItem> _interests = const [];
  String? _error;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selected);
    _loadInterests();
  }

  Future<void> _loadInterests() async {
    try {
      final interests = await widget.loadInterests();
      if (!mounted) return;
      setState(() {
        _interests = interests;
        _isLoading = false;
        if (interests.isEmpty) {
          _error = AppLocalizations.of(context)!.couldNotLoadInterests;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = AppLocalizations.of(context)!.couldNotLoadInterests;
      });
    }
  }

  void _toggle(String interestId) {
    setState(() {
      if (_selected.contains(interestId)) {
        _selected.remove(interestId);
      } else {
        _selected.add(interestId);
      }
      if (_selected.length >= kMinInterests) {
        _error = null;
      }
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_selected.length < kMinInterests) {
      setState(
        () => _error = AppLocalizations.of(
          context,
        )!.pickAtLeastNInterests(kMinInterests),
      );
      return;
    }
    setState(() {
      _error = null;
      _isSubmitting = true;
    });
    final error = await widget.onNext(_selected.toList());
    if (!mounted) return;
    setState(() {
      _error = error;
      _isSubmitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selCount = _selected.length;
    return Column(
      children: [
        // ── Scrollable content ──────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.whatsYourScene,
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
                        text: AppLocalizations.of(context)!.pickFewMatchHint,
                      ),
                      TextSpan(
                        text: AppLocalizations.of(
                          context,
                        )!.selectedOfMinCount(selCount, kMinInterests),
                        style: TextStyle(
                          color: selCount >= kMinInterests
                              ? SC.burgundy
                              : SC.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (_isLoading)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(color: SC.burgundy),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _interests.map((interest) {
                      final sel = _selected.contains(interest.id);
                      return GestureDetector(
                        onTap: () => _toggle(interest.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: sel ? SC.burgundy : SC.card,
                            borderRadius: BorderRadius.all(
                              Radius.circular(100),
                            ),
                            border: Border.all(
                              color: sel ? SC.burgundy : SC.hair,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (sel) ...[
                                Text(
                                  '✓',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 5),
                              ],
                              Text(
                                interest.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: sel ? Colors.white : SC.ink,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(color: SC.burgundy, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ),

        // ── Finish setup — pinned to bottom ─────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading || _isSubmitting ? null : _submit,
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
                  : Text(AppLocalizations.of(context)!.finishSetupButton),
            ),
          ),
        ),
      ],
    );
  }
}
