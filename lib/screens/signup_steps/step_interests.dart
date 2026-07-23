import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/signup_service.dart';
import '../widgets/terms_content.dart';
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
  bool _agreedToTerms = false;

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

  /// Presents the full Community Safety Terms in an in-app bottom sheet
  /// (rather than handing off to the external browser) so the student can
  /// review them without leaving the sign-up flow.
  void _showTermsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SC.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: SC.hair,
                  borderRadius: const BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
                child: const TermsContent(),
              ),
            ),
          ],
        ),
      ),
    );
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

        // ── Terms acceptance + Finish setup — pinned to bottom ──
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Checkbox(
                    value: _agreedToTerms,
                    activeColor: SC.burgundy,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (value) =>
                        setState(() => _agreedToTerms = value ?? false),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.agreeToSafetyTerms,
                          style: TextStyle(
                            fontSize: 13,
                            color: SC.body,
                            height: 1.35,
                          ),
                        ),
                        GestureDetector(
                          onTap: _showTermsSheet,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              AppLocalizations.of(context)!.readFullTerms,
                              style: TextStyle(
                                fontSize: 13,
                                color: SC.burgundy,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                                decoration: TextDecoration.underline,
                                decorationColor: SC.burgundy,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed:
                      _isLoading ||
                          _isSubmitting ||
                          _selected.length < kMinInterests ||
                          !_agreedToTerms
                      ? null
                      : _submit,
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
                      : Text(
                          AppLocalizations.of(context)!.finishSetupButton,
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
