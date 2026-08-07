import 'package:flutter/material.dart';

import '../services/app_colors.dart';
import '../l10n/app_localizations.dart';
import '../services/locale_service.dart';
import 'widgets/terms_content.dart';

class TermsAcceptanceScreen extends StatefulWidget {
  final Future<void> Function() onAccepted;
  final Future<void> Function()? onRetryCheck;
  final bool verificationFailed;

  const TermsAcceptanceScreen({
    super.key,
    required this.onAccepted,
    this.onRetryCheck,
    this.verificationFailed = false,
  });

  @override
  State<TermsAcceptanceScreen> createState() => _TermsAcceptanceScreenState();
}

class _TermsAcceptanceScreenState extends State<TermsAcceptanceScreen> {
  bool _saving = false;
  bool _checking = false;
  bool _saveFailed = false;

  Future<void> _continue() async {
    if (_saving || _checking) return;
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      await widget.onAccepted();
    } catch (_) {
      if (mounted) {
        setState(() => _saveFailed = true);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.couldNotSaveChanges),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _retryCheck() async {
    final retry = widget.onRetryCheck;
    if (retry == null || _saving || _checking) return;
    setState(() => _checking = true);
    try {
      await retry();
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: false,
      child: Scaffold(
        key: const ValueKey('mandatory-terms-screen'),
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
                        borderRadius: const BorderRadius.all(
                          Radius.circular(12),
                        ),
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
                  l10n.updatedTermsTitle,
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
                  l10n.updatedTermsMessage,
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
                      child: TermsContent(includeFullTerms: true),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (widget.verificationFailed || _saveFailed) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withValues(alpha: 0.08),
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      border: Border.all(
                        color: AppColors.primaryRed.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Text(
                      _saveFailed
                          ? l10n.termsAcceptanceSaveFailed
                          : l10n.termsVerificationFailed,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (widget.verificationFailed &&
                      widget.onRetryCheck != null) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        key: const ValueKey('retry-terms-check'),
                        onPressed: _checking ? null : _retryCheck,
                        icon: _checking
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(l10n.retry),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    key: const ValueKey('accept-updated-terms'),
                    onPressed: !_saving && !_checking ? _continue : null,
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
                            l10n.iAccept,
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
      ),
    );
  }
}
