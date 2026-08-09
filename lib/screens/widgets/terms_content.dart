import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../services/app_colors.dart';
import '../../services/app_links.dart';
import '../../services/locale_service.dart';

/// Reusable Terms content for the pre-authentication safety gate and sign-up.
/// The gate keeps its concise safety summary, while sign-up requests the full
/// in-app Terms through [includeFullTerms].
///
/// This is just the scrollable body — no Scaffold, header, checkbox, or action
/// button. Callers wrap it in their own scroll view and own acceptance state.
class TermsContent extends StatelessWidget {
  final bool includeFullTerms;

  const TermsContent({super.key, this.includeFullTerms = false});

  Future<void> _open(BuildContext context, String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.couldNotOpenThisPage),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (includeFullTerms) {
      return _fullTerms(context, l);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.communitySafetyTerms,
          style: TextStyle(
            color: AppColors.primaryRed,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 14),
        _term(Icons.shield_outlined, l.zeroTolerance, l.zeroToleranceBody),
        _term(
          Icons.flag_outlined,
          l.reportHarmfulContent,
          l.reportHarmfulContentBody,
        ),
        _term(
          Icons.block_rounded,
          l.blockAbusiveUsers,
          l.blockAbusiveUsersBody,
        ),
        _term(Icons.gavel_rounded, l.enforcement, l.enforcementBody),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: () => _open(
                context,
                localeService.languageCode == 'tr'
                    ? AppLinks.termsOfUseTurkish
                    : AppLinks.termsOfUse,
              ),
              child: Text(l.readFullTerms),
            ),
            TextButton(
              onPressed: () => _open(
                context,
                localeService.languageCode == 'tr'
                    ? AppLinks.privacyPolicyTurkish
                    : AppLinks.privacyPolicy,
              ),
              child: Text(l.privacyPolicy),
            ),
          ],
        ),
      ],
    );
  }

  Widget _fullTerms(BuildContext context, AppLocalizations l) {
    final sections = [
      (l.termsAgreementTitle, l.termsAgreementBody),
      (l.termsEligibilityTitle, l.termsEligibilityBody),
      (l.termsSafetyTitle, l.termsSafetyBody),
      (l.termsContentTitle, l.termsContentBody),
      (l.termsReportingTitle, l.termsReportingBody),
      (l.termsEnforcementTitle, l.termsEnforcementBody),
      (l.termsServiceTitle, l.termsServiceBody),
      (l.termsChangesTitle, l.termsChangesBody),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.termsOfUse,
          style: TextStyle(
            color: AppColors.text,
            fontSize: 26,
            height: 1.12,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l.termsReviewSummary,
          style: TextStyle(color: AppColors.secondaryText, height: 1.45),
        ),
        const SizedBox(height: 8),
        Text(
          l.termsEffectiveMetadata,
          style: TextStyle(
            color: AppColors.secondaryText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primaryRed.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            border: Border.all(
              color: AppColors.primaryRed.withValues(alpha: 0.22),
            ),
          ),
          child: Text(
            l.termsZeroToleranceNotice,
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 20),
        for (final section in sections) ...[
          Text(
            section.$1,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            section.$2,
            style: TextStyle(color: AppColors.secondaryText, height: 1.5),
          ),
          const SizedBox(height: 18),
        ],
        TextButton(
          onPressed: () => _open(
            context,
            localeService.languageCode == 'tr'
                ? AppLinks.privacyPolicyTurkish
                : AppLinks.privacyPolicy,
          ),
          child: Text(l.privacyPolicy),
        ),
      ],
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
