import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_colors.dart';
import '../services/app_links.dart';
import '../services/app_strings.dart';
import '../services/locale_service.dart';

class TermsAcceptanceScreen extends StatefulWidget {
  final Future<void> Function() onAccepted;

  const TermsAcceptanceScreen({super.key, required this.onAccepted});

  @override
  State<TermsAcceptanceScreen> createState() => _TermsAcceptanceScreenState();
}

class _TermsAcceptanceScreenState extends State<TermsAcceptanceScreen> {
  bool _agreed = false;
  bool _saving = false;

  Future<void> _open(String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(S.couldNotOpenThisPage)));
    }
  }

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
                S.safetyHero,
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
                S.safetyIntro,
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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          S.communitySafetyTerms,
                          style: TextStyle(
                            color: AppColors.primaryRed,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.9,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _term(
                          Icons.shield_outlined,
                          S.zeroTolerance,
                          S.zeroToleranceBody,
                        ),
                        _term(
                          Icons.flag_outlined,
                          S.reportHarmfulContent,
                          S.reportHarmfulContentBody,
                        ),
                        _term(
                          Icons.block_rounded,
                          S.blockAbusiveUsers,
                          S.blockAbusiveUsersBody,
                        ),
                        _term(
                          Icons.gavel_rounded,
                          S.enforcement,
                          S.enforcementBody,
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: () => _open(
                                localeService.languageCode == 'tr'
                                    ? AppLinks.termsOfUseTurkish
                                    : AppLinks.termsOfUse,
                              ),
                              child: Text(S.readFullTerms),
                            ),
                            TextButton(
                              onPressed: () => _open(
                                localeService.languageCode == 'tr'
                                    ? AppLinks.privacyPolicyTurkish
                                    : AppLinks.privacyPolicy,
                              ),
                              child: Text(S.privacyPolicy),
                            ),
                          ],
                        ),
                      ],
                    ),
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
                            S.agreeToSafetyTerms,
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
                          S.agreeAndContinue,
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

  Widget _term(IconData icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryRed, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(color: AppColors.secondaryText, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
