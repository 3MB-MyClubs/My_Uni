import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../services/app_colors.dart';
import '../../services/app_links.dart';
import '../../services/locale_service.dart';

/// The reusable Community Safety Terms body: the section heading, the four
/// safety-term rows, and the external links to the full Terms of Use / Privacy
/// Policy.
///
/// This is just the scrollable body — no Scaffold, header, checkbox, or action
/// button. Callers wrap it in their own scroll view: the full-screen re-accept
/// gate ([TermsAcceptanceScreen]) and the sign-up flow's in-app bottom sheet.
class TermsContent extends StatelessWidget {
  const TermsContent({super.key});

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
