import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../l10n/app_localizations.dart';
import '../models/event.dart';
import '../models/user.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/people_service.dart';
import '../services/theme_service.dart';
import '../services/user_state.dart';
import 'user_avatar.dart';

Future<void> showEventShareSheet({
  required BuildContext context,
  required Event event,
  required List<User> people,
  required Set<String> sentUserIds,
  required ValueChanged<List<User>> onInvite,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    barrierColor: themeService.isDark
        ? Colors.black.withValues(alpha: 0.72)
        : Colors.black.withValues(alpha: 0.46),
    builder: (_) => EventShareSheet(
      event: event,
      people: people,
      sentUserIds: sentUserIds,
      onInvite: onInvite,
    ),
  );
}

class EventShareSheet extends StatefulWidget {
  const EventShareSheet({
    super.key,
    required this.event,
    required this.people,
    required this.sentUserIds,
    required this.onInvite,
  });

  final Event event;
  final List<User> people;
  final Set<String> sentUserIds;
  final ValueChanged<List<User>> onInvite;

  @override
  State<EventShareSheet> createState() => _EventShareSheetState();
}

class _EventShareSheetState extends State<EventShareSheet> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedIds = {};
  late final Set<String> _sentIds = {...widget.sentUserIds};
  Timer? _feedbackTimer;
  String _query = '';
  String? _feedback;

  String get _eventLink => 'kuclubs://event/${widget.event.id}';

  List<User> get _filteredPeople {
    final normalized = _query.trim().toLowerCase();
    if (normalized.isEmpty) return widget.people;
    return widget.people
        .where((person) {
          final name = userState
              .displayNameFor(person.id, person.name)
              .toLowerCase();
          return name.contains(normalized);
        })
        .toList(growable: false);
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _showFeedback(String message) {
    _feedbackTimer?.cancel();
    setState(() => _feedback = message);
    _feedbackTimer = Timer(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      setState(() => _feedback = null);
    });
  }

  void _showQrCode() {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => ListenableBuilder(
        listenable: themeService,
        builder: (context, _) => AlertDialog(
          key: const ValueKey('event-share-qr-dialog'),
          backgroundColor: AppColors.card,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
          titlePadding: const EdgeInsets.fromLTRB(22, 18, 10, 4),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.qrCodeAction,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('event-share-qr-close'),
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close_rounded),
                color: AppColors.text,
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 224,
                height: 224,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.all(Radius.circular(18)),
                  border: Border.all(color: AppColors.divider),
                ),
                child: QrImageView(
                  data: _eventLink,
                  version: QrVersions.auto,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                l10n.scanToOpenEvent,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _togglePerson(User person) {
    if (_sentIds.contains(person.id)) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selectedIds.add(person.id)) _selectedIds.remove(person.id);
    });
  }

  void _sendInvites() {
    if (_selectedIds.isEmpty) return;
    final selectedPeople = widget.people
        .where((person) => _selectedIds.contains(person.id))
        .toList(growable: false);
    if (selectedPeople.isEmpty) return;

    widget.onInvite(selectedPeople);
    HapticFeedback.mediumImpact();
    setState(() {
      _sentIds.addAll(_selectedIds);
      _selectedIds.clear();
    });
    _showFeedback(
      AppLocalizations.of(
        context,
      )!.eventInvitesSentCount(selectedPeople.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.96,
        snap: true,
        snapSizes: const [0.5, 0.9],
        builder: (context, scrollController) => Material(
          key: const ValueKey('event-share-sheet'),
          color: AppColors.card,
          elevation: 18,
          shadowColor: Colors.black.withValues(
            alpha: themeService.isDark ? 0.56 : 0.2,
          ),
          clipBehavior: Clip.antiAlias,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              _SheetHeader(onClose: () => Navigator.pop(context)),
              Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: CustomScrollView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                      sliver: SliverList.list(
                        children: [
                          _EventSummaryCard(
                            event: widget.event,
                            eventLink: _eventLink,
                            onQrTap: _showQrCode,
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: _feedback == null
                                ? const SizedBox(
                                    key: ValueKey('event-share-feedback-empty'),
                                    height: 12,
                                  )
                                : Container(
                                    key: ValueKey(_feedback),
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(top: 12),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 9,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.positiveSurface,
                                      borderRadius: const BorderRadius.all(
                                        Radius.circular(11),
                                      ),
                                    ),
                                    child: Text(
                                      _feedback!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppColors.positive,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        height: 1.25,
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            key: const ValueKey('event-share-search'),
                            controller: _searchController,
                            onChanged: (value) =>
                                setState(() => _query = value),
                            textInputAction: TextInputAction.search,
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(
                                context,
                              )!.searchPeopleOnCampus,
                              hintStyle: TextStyle(
                                color: AppColors.secondaryText,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: AppColors.secondaryText,
                                size: 21,
                              ),
                              suffixIcon: _query.isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _query = '');
                                      },
                                      icon: const Icon(Icons.close_rounded),
                                      color: AppColors.secondaryText,
                                      tooltip: MaterialLocalizations.of(
                                        context,
                                      ).closeButtonTooltip,
                                    ),
                              filled: true,
                              fillColor: AppColors.surfaceAlt,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(15),
                                ),
                                borderSide: BorderSide(
                                  color: AppColors.divider,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(15),
                                ),
                                borderSide: BorderSide(
                                  color: AppColors.divider,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(15),
                                ),
                                borderSide: BorderSide(
                                  color: AppColors.positive,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    if (_filteredPeople.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Text(
                              AppLocalizations.of(context)!.noPeopleMatchSearch,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.secondaryText,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                        sliver: SliverList.separated(
                          itemCount: _filteredPeople.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            indent: 58,
                            color: AppColors.divider,
                          ),
                          itemBuilder: (context, index) {
                            final person = _filteredPeople[index];
                            return _PersonInviteRow(
                              person: person,
                              selected: _selectedIds.contains(person.id),
                              sent: _sentIds.contains(person.id),
                              onTap: () => _togglePerson(person),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              _InviteFooter(
                count: _selectedIds.length,
                onPressed: _selectedIds.isEmpty ? null : _sendInvites,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 9),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.borderStrong,
            borderRadius: const BorderRadius.all(Radius.circular(99)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 10, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.shareThisEvent,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.45,
                  ),
                ),
              ),
              IconButton.filled(
                key: const ValueKey('event-share-close'),
                onPressed: onClose,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceAlt,
                  foregroundColor: AppColors.text,
                ),
                icon: const Icon(Icons.close_rounded, size: 21),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EventSummaryCard extends StatelessWidget {
  const _EventSummaryCard({
    required this.event,
    required this.eventLink,
    required this.onQrTap,
  });

  final Event event;
  final String eventLink;
  final VoidCallback onQrTap;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final month = DateFormat(
      'MMM',
      locale,
    ).format(event.dateTime).toUpperCase();
    final day = DateFormat('d', locale).format(event.dateTime);
    final time =
        '${DateFormat('EEE, MMM d', locale).format(event.dateTime)} · '
        '${DateFormat.jm(locale).format(event.dateTime)}';

    return Container(
      key: const ValueKey('event-share-summary'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.positiveSurface,
              borderRadius: const BorderRadius.all(Radius.circular(13)),
              border: Border.all(
                color: AppColors.positive.withValues(alpha: 0.28),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  month,
                  style: TextStyle(
                    color: AppColors.positive,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
                Text(
                  day,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  time,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 13,
                      color: AppColors.secondaryText,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        event.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Semantics(
            button: true,
            label: AppLocalizations.of(context)!.qrCodeAction,
            child: Material(
              key: const ValueKey('event-share-summary-qr'),
              color: Colors.white,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.all(Radius.circular(11)),
                side: BorderSide(color: AppColors.divider),
              ),
              child: InkWell(
                onTap: onQrTap,
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: QrImageView(
                    data: eventLink,
                    version: QrVersions.auto,
                    size: 54,
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonInviteRow extends StatelessWidget {
  const _PersonInviteRow({
    required this.person,
    required this.selected,
    required this.sent,
    required this.onTap,
  });

  final User person;
  final bool selected;
  final bool sent;
  final VoidCallback onTap;

  String _contextDetail(BuildContext context) {
    final academic = userState.academicSummaryFor(person.id);
    if (academic.isNotEmpty) return academic;

    final currentUser = authService.currentUser;
    if (currentUser != null) {
      final myClubs = currentUser.subscribedClubIds.toSet();
      final theirClubs = {
        ...person.subscribedClubIds,
        ...peopleService.clubIdsFor(person.id),
      };
      final mutualCount = myClubs.intersection(theirClubs).length;
      if (mutualCount > 0) {
        return AppLocalizations.of(context)!.mutualClubsCount(mutualCount);
      }
    }
    return AppLocalizations.of(context)!.suggestedForYou;
  }

  @override
  Widget build(BuildContext context) {
    final displayName = userState.displayNameFor(person.id, person.name);
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          UserAvatar(
            userId: person.id,
            name: displayName,
            size: 42,
            fontSize: 14,
            backgroundColor: AppColors.lightRed,
            textColor: AppColors.primaryRed,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _contextDetail(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 36,
            child: OutlinedButton.icon(
              key: ValueKey('event-share-invite-${person.id}'),
              onPressed: sent ? null : onTap,
              icon: selected
                  ? const Icon(Icons.check_rounded, size: 15)
                  : const SizedBox.shrink(),
              label: Text(sent ? l10n.sentAction : l10n.invite),
              style: OutlinedButton.styleFrom(
                foregroundColor: selected ? AppColors.positive : AppColors.text,
                disabledForegroundColor: AppColors.positive,
                backgroundColor: selected
                    ? AppColors.positiveSurface
                    : Colors.transparent,
                disabledBackgroundColor: AppColors.positiveSurface,
                side: BorderSide(
                  color: selected || sent
                      ? AppColors.positive.withValues(alpha: 0.72)
                      : AppColors.borderStrong,
                ),
                padding: EdgeInsets.symmetric(horizontal: selected ? 10 : 13),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(11)),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteFooter extends StatelessWidget {
  const _InviteFooter({required this.count, required this.onPressed});

  final int count;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: themeService.isDark ? 0.26 : 0.07,
            ),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.zero,
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            key: const ValueKey('event-share-send-invites'),
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.positive,
              foregroundColor: AppColors.onPositive,
              disabledBackgroundColor: AppColors.surfaceAlt,
              disabledForegroundColor: AppColors.secondaryText,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(15)),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: Text(
                AppLocalizations.of(context)!.inviteFriendsCount(count),
                key: ValueKey(count),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
