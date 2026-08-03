import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/app_colors.dart';
import '../services/locale_service.dart';
import '../widgets/app_pressable.dart';

/// Shown when the authenticated account does not yet have a saved language.
class LanguageChoiceScreen extends StatefulWidget {
  final Future<void> Function(String code) onChoose;

  const LanguageChoiceScreen({super.key, required this.onChoose});

  @override
  State<LanguageChoiceScreen> createState() => _LanguageChoiceScreenState();
}

class _LanguageChoiceScreenState extends State<LanguageChoiceScreen> {
  late String _code = localeService.languageCode;
  bool _isSaving = false;

  void _select(String code) {
    setState(() => _code = code);
    localeService.setLanguage(code, persistToAccount: false);
  }

  Future<void> _continue() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await widget.onChoose(_code);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.couldNotSaveChanges),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.lightRed,
                  borderRadius: const BorderRadius.all(Radius.circular(18)),
                ),
                child: Icon(
                  Icons.translate_rounded,
                  color: AppColors.primaryRed,
                  size: 28,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.chooseYourLanguage,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.pickLanguageHint,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: _LanguagePreviewCard(
                      label: 'English',
                      flag: '🇬🇧',
                      selected: _code == 'en',
                      onTap: () => _select('en'),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _LanguagePreviewCard(
                      label: 'Türkçe',
                      flag: '🇹🇷',
                      selected: _code == 'tr',
                      onTap: () => _select('tr'),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              l10n.continueButton,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguagePreviewCard extends StatelessWidget {
  final String label;
  final String flag;
  final bool selected;
  final VoidCallback onTap;

  const _LanguagePreviewCard({
    required this.label,
    required this.flag,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      pressedScale: 0.98,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(26)),
          border: Border.all(
            color: selected ? AppColors.primaryRed : AppColors.divider,
            width: selected ? 2.5 : 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primaryRed.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Container(
              height: 168,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: const BorderRadius.all(Radius.circular(20)),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(flag, style: const TextStyle(fontSize: 52)),
                    const SizedBox(height: 14),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 18,
                    color: selected
                        ? AppColors.primaryRed
                        : AppColors.secondaryText,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: selected ? AppColors.primaryRed : AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
