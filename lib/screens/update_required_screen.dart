import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';

class UpdateRequiredScreen extends StatefulWidget {
  const UpdateRequiredScreen({
    required this.storeUrl,
    required this.onRetry,
    super.key,
  });

  final String storeUrl;
  final Future<void> Function() onRetry;

  @override
  State<UpdateRequiredScreen> createState() => _UpdateRequiredScreenState();
}

class _UpdateRequiredScreenState extends State<UpdateRequiredScreen> {
  bool _isOpeningStore = false;
  bool _isChecking = false;
  String? _storeError;

  Future<void> _openStore() async {
    final uri = Uri.tryParse(widget.storeUrl);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      setState(() => _storeError = '');
      return;
    }

    setState(() {
      _isOpeningStore = true;
      _storeError = null;
    });
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        setState(() => _storeError = '');
      }
    } catch (_) {
      if (mounted) setState(() => _storeError = '');
    } finally {
      if (mounted) setState(() => _isOpeningStore = false);
    }
  }

  Future<void> _retry() async {
    if (_isChecking) return;
    setState(() {
      _isChecking = true;
      _storeError = null;
    });
    try {
      await widget.onRetry();
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final hasStoreUrl = widget.storeUrl.isNotEmpty;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.system_update_rounded,
                        size: 42,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      l10n.updateRequiredTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.updateRequiredMessage,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 28),
                    if (hasStoreUrl)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isOpeningStore ? null : _openStore,
                          icon: _isOpeningStore
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.open_in_new_rounded),
                          label: Text(l10n.updateRequiredButton),
                        ),
                      ),
                    if (_storeError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        l10n.updateRequiredStoreError,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _isChecking ? null : _retry,
                      child: _isChecking
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.updateRequiredRetry),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
