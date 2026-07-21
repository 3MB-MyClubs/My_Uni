import 'package:flutter/material.dart';

import '../services/app_colors.dart';
import '../l10n/app_localizations.dart';

class ModerationReason {
  final String value;

  const ModerationReason(this.value);
}

const moderationReasons = [
  ModerationReason('harassment'),
  ModerationReason('hate_or_discrimination'),
  ModerationReason('sexual_content'),
  ModerationReason('violence_or_danger'),
  ModerationReason('spam_or_scam'),
  ModerationReason('other'),
];

Future<String?> showModerationReasonSheet(
  BuildContext context, {
  required String title,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: const BorderRadius.all(Radius.circular(999)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              AppLocalizations.of(context)!.chooseReportReason,
              style: TextStyle(color: AppColors.secondaryText, height: 1.4),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 12),
              itemCount: moderationReasons.length,
              itemBuilder: (context, index) {
                final reason = moderationReasons[index];
                return ListTile(
                  leading: Icon(
                    Icons.flag_outlined,
                    color: AppColors.primaryRed,
                  ),
                  title: Text(
                    AppLocalizations.of(
                      context,
                    )!.moderationReasonLabel(reason.value),
                    style: TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    AppLocalizations.of(
                      context,
                    )!.moderationReasonDetail(reason.value),
                    style: TextStyle(color: AppColors.secondaryText),
                  ),
                  onTap: () => Navigator.pop(sheetContext, reason.value),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
