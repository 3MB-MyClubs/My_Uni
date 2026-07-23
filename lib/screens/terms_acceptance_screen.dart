import 'package:flutter/material.dart';

import '../services/app_colors.dart';
import '../l10n/app_localizations.dart';
import '../services/locale_service.dart';
import 'widgets/terms_content.dart';

class TermsAcceptanceScreen extends StatefulWidget {
  final Future<void> Function() onAccepted;

  const TermsAcceptanceScreen({super.key, required this.onAccepted});

  @override
  State<TermsAcceptanceScreen> createState() => _TermsAcceptanceScreenState();
}

class _TermsAcceptanceScreenState extends State<TermsAcceptanceScreen> {
  bool _agreed = false;
  bool _saving = false;

  Future<void> _continue() async {
    if (!_agreed || _saving) return;
    setState(() => _saving = true);
    await widget.onAccepted();
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed,
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'CU',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'ClubUp',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      await localeService.setLanguage(
                        localeService.languageCode == 'tr' ? 'en' : 'tr',
                      );
                      if (mounted) setState(() {});
                    },
                    icon: Icon(
                      Icons.language_rounded,
                      size: 18,
                      color: AppColors.primaryRed,
                    ),
                    label: Text(
                      localeService.languageCode == 'tr' ? 'EN' : 'TR',
                      style: TextStyle(
                        color: AppColors.primaryRed,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Text(
                AppLocalizations.of(context)!.safetyHero,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 27,
                  height: 1.12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                AppLocalizations.of(context)!.safetyIntro,
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: const BorderRadius.all(Radius.circular(18)),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: const SingleChildScrollView(
                    padding: EdgeInsets.all(18),
                    child: TermsContent(),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: () => setState(() => _agreed = !_agreed),
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _agreed,
                        activeColor: AppColors.primaryRed,
                        onChanged: (value) =>
                            setState(() => _agreed = value ?? false),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 11),
                          child: Text(
                            AppLocalizations.of(context)!.agreeToSafetyTerms,
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _agreed && !_saving ? _continue : null,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          AppLocalizations.of(context)!.agreeAndContinue,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
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
