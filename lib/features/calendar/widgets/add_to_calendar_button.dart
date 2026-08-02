import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/event.dart' as app;
import '../../../services/app_colors.dart';
import '../data/calendar_event_model.dart';
import '../providers/calendar_provider.dart';
import '../providers/calendar_state.dart';

class AddToCalendarButton extends ConsumerStatefulWidget {
  final app.Event event;
  final Color? color;

  const AddToCalendarButton({super.key, required this.event, this.color});

  @override
  ConsumerState<AddToCalendarButton> createState() =>
      _AddToCalendarButtonState();
}

class _AddToCalendarButtonState extends ConsumerState<AddToCalendarButton> {
  Color get _accent => widget.color ?? AppColors.primaryRed;

  @override
  Widget build(BuildContext context) {
    ref.listen<CalendarAddState>(calendarEventProvider(widget.event.id), (
      previous,
      next,
    ) {
      if (next is CalendarAddPermissionRequired) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _showPermissionDialog(next.permission),
        );
      } else if (next is CalendarAddFailure) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(next.error),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          );
      } else if (next is CalendarAddSuccess &&
          previous is! CalendarAddSuccess) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(
                      context,
                    )!.calendarAddedToCalendarSnackbar,
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF2E7D32),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          );
      }
    });

    final state = ref.watch(calendarEventProvider(widget.event.id));
    return _buildButton(state);
  }

  Widget _buildButton(CalendarAddState state) {
    final isSuccess = state is CalendarAddSuccess;
    final isLoading = state is CalendarAddLoading;
    final successColor = const Color(0xFF2E7D32);
    final successLight = const Color(0xFF4CAF50);

    return SizedBox(
      width: double.infinity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isSuccess
              ? successColor.withValues(alpha: 0.08)
              : _accent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.all(Radius.circular(14)),
          border: Border.all(
            color: isSuccess
                ? successLight.withValues(alpha: 0.5)
                : _accent.withValues(alpha: 0.25),
            width: 1.2,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            onTap: (isLoading || isSuccess)
                ? null
                : () {
                    final model = CalendarEventModel.fromAppEvent(widget.event);
                    ref
                        .read(calendarEventProvider(widget.event.id).notifier)
                        .add(model);
                  },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _accent,
                        strokeCap: StrokeCap.round,
                      ),
                    )
                  else
                    Icon(
                      isSuccess
                          ? Icons.check_circle_rounded
                          : Icons.calendar_today_rounded,
                      size: 16,
                      color: isSuccess ? successLight : _accent,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    isLoading
                        ? AppLocalizations.of(context)!.addingEllipsis
                        : isSuccess
                        ? AppLocalizations.of(
                            context,
                          )!.calendarAddedToCalendarButton
                        : AppLocalizations.of(context)!.addToCalendarButton,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isSuccess ? successLight : _accent,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPermissionDialog(CalendarPermissionState permission) {
    final isPermanent =
        permission == CalendarPermissionState.permanentlyDenied ||
        permission == CalendarPermissionState.restricted;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isPermanent
                    ? Colors.orange.withValues(alpha: 0.1)
                    : AppColors.primaryRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPermanent
                    ? Icons.lock_outline_rounded
                    : Icons.calendar_month_rounded,
                size: 32,
                color: isPermanent ? Colors.orange : AppColors.primaryRed,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isPermanent
                  ? AppLocalizations.of(context)!.calendarAccessDeniedTitle
                  : AppLocalizations.of(context)!.allowCalendarAccessTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              isPermanent
                  ? AppLocalizations.of(context)!.calendarAccessDeniedBody
                  : AppLocalizations.of(context)!.calendarAccessRequestBody,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.secondaryText,
                height: 1.55,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ref
                        .read(calendarEventProvider(widget.event.id).notifier)
                        .resetToIdle();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.secondaryText,
                    side: BorderSide(color: AppColors.divider),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.notNow,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (isPermanent) {
                      ref
                          .read(calendarEventProvider(widget.event.id).notifier)
                          .openSettings();
                    } else {
                      ref
                          .read(calendarEventProvider(widget.event.id).notifier)
                          .resetToIdle();
                      final model = CalendarEventModel.fromAppEvent(
                        widget.event,
                      );
                      ref
                          .read(calendarEventProvider(widget.event.id).notifier)
                          .add(model);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    isPermanent
                        ? AppLocalizations.of(context)!.openSettingsButton
                        : AppLocalizations.of(context)!.allowAccessButton,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
