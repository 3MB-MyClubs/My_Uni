import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../models/event.dart';
import '../services/app_strings.dart';
import '../services/apple_wallet_ticket_service.dart';
import '../services/event_ticket_service.dart';
import '../services/google_wallet_ticket_service.dart';
import '../services/locale_service.dart';
import '../services/theme_service.dart';
import 'clubup_design.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Student ticket — the `ticket-section` of `Event Detail - Light/Dark`
// (`750:5` / `750:34`) and the `Ticket pop-up light/dark` sheet
// (`753:1408` / `753:1711`).
//
// Tickets are free admissions the organiser issues by hand after an RSVP, so
// the section can exist before the student holds one: the sheet then shows a
// pending state in place of the QR. The frames' `#1DA1F2` is the handoff's
// template leftover; the burgundy accent is used instead.
// ─────────────────────────────────────────────────────────────────────────────

/// Sheet-only surfaces. Everything else reuses [ClubUpColors].
class EventTicketColors {
  EventTicketColors._();

  static bool get _dark => themeService.isDark;

  /// `Ticket sheet` — `#FFFFFF` / `#1E1E1E`.
  static Color get sheet => ClubUpColors.card;

  /// `Grabber` — `#D4D4D8` / `#52525B`.
  static Color get grabber =>
      _dark ? const Color(0xFF52525B) : const Color(0xFFD4D4D8);

  /// `Close`, icon containers and identity tiles — `#F4F4F5` / `#27272A`.
  static Color get tile =>
      _dark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5);

  /// `Event details` box — `#FAFAFA` over `#E4E4E7` / `#18181A` over `#323238`.
  static Color get detailFill =>
      _dark ? const Color(0xFF18181A) : const Color(0xFFFAFAFA);
  static Color get detailBorder =>
      _dark ? const Color(0xFF323238) : const Color(0xFFE4E4E7);

  /// `Refresh QR code` disc — `#FFFFFF` over `#E4E4E7` / `#252525` over `#3F3F46`.
  static Color get refreshFill =>
      _dark ? const Color(0xFF252525) : Colors.white;
  static Color get refreshBorder =>
      _dark ? const Color(0xFF3F3F46) : const Color(0xFFE4E4E7);

  /// `Confirmation` pill — `#25B879` on `#EAF8F2` / `#123328`.
  static const Color positive = Color(0xFF25B879);
  static Color get positiveWash =>
      _dark ? const Color(0xFF123328) : const Color(0xFFEAF8F2);

  /// The frames draw only the confirmed state; used and revoked borrow the
  /// same pill in amber and red.
  static const Color warning = Color(0xFFD97706);
  static Color get warningWash =>
      _dark ? const Color(0xFF33260F) : const Color(0xFFFEF3E2);
  static const Color danger = Color(0xFFDC2626);
  static Color get dangerWash =>
      _dark ? const Color(0xFF3A1515) : const Color(0xFFFDECEC);

  /// `Dim overlay` — `rgba(9,9,11,0.6)` / `rgba(0,0,0,0.72)`.
  static Color get barrier =>
      _dark ? const Color(0xB8000000) : const Color(0x9909090B);
}

enum _TicketPhase { loading, error, pending, active, used, revoked }

_TicketPhase _phaseFor(EventTicket? ticket) {
  if (ticket == null) return _TicketPhase.pending;
  if (ticket.revokedAt != null) return _TicketPhase.revoked;
  if (ticket.usedAt != null) return _TicketPhase.used;
  return _TicketPhase.active;
}

String _ticketErrorMessage(BuildContext context, Object error) {
  final l10n = AppLocalizations.of(context)!;
  return error is PostgrestException && error.code == '42501'
      ? l10n.ticketUnauthorized
      : l10n.ticketOperationFailed;
}

/// `ticket-section` — the "Get my ticket" heading with its status pill and the
/// admission card whose button opens [showEventTicketSheet].
class EventTicketSection extends StatefulWidget {
  const EventTicketSection({
    super.key,
    required this.event,
    required this.profileId,
    required this.attendeeName,
    required this.goingCount,
    this.service,
  });

  final Event event;
  final String profileId;
  final String attendeeName;

  /// RSVPs so far, for the "N tickets remaining" row when the event has a
  /// seat cap.
  final int goingCount;
  final EventTicketService? service;

  @override
  State<EventTicketSection> createState() => _EventTicketSectionState();
}

class _EventTicketSectionState extends State<EventTicketSection> {
  EventTicket? _ticket;
  _TicketPhase _phase = _TicketPhase.loading;
  int _generation = 0;

  EventTicketService get _service => widget.service ?? eventTicketService;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(EventTicketSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.id != widget.event.id ||
        oldWidget.profileId != widget.profileId) {
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    try {
      final ticket = await _service
          .fetch(widget.event.id, widget.profileId)
          .timeout(const Duration(seconds: 15));
      if (!mounted || generation != _generation) return;
      setState(() {
        _ticket = ticket;
        _phase = _phaseFor(ticket);
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _ticket = null;
        _phase = _TicketPhase.error;
      });
    }
  }

  Future<void> _open() async {
    HapticFeedback.selectionClick();
    await showEventTicketSheet(
      context: context,
      event: widget.event,
      profileId: widget.profileId,
      attendeeName: widget.attendeeName,
      initialTicket: _phase == _TicketPhase.error ? null : _ticket,
      initiallyLoaded:
          _phase != _TicketPhase.loading && _phase != _TicketPhase.error,
      service: widget.service,
    );
    if (mounted) _load();
  }

  String? get _statusLabel => switch (_phase) {
    _TicketPhase.loading || _TicketPhase.error => null,
    _TicketPhase.pending => S.ticketStatusPending,
    _TicketPhase.active => S.ticketStatusActive,
    _TicketPhase.used => S.ticketStatusUsed,
    _TicketPhase.revoked => S.ticketStatusRevoked,
  };

  @override
  Widget build(BuildContext context) {
    final capacity = widget.event.capacity;
    final remaining = capacity == null
        ? null
        : (capacity - widget.goingCount).clamp(0, capacity);
    final status = _statusLabel;
    final muted = _phase == _TicketPhase.used || _phase == _TicketPhase.revoked;

    return Column(
      key: const ValueKey('event-ticket-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // `ticket-header` 750:6
        Row(
          children: [
            Expanded(
              child: Text(
                S.ticketSectionTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: figtree(
                  size: 16,
                  weight: FontWeight.w700,
                  color: ClubUpColors.text,
                ),
              ),
            ),
            if (status != null) ...[
              const SizedBox(width: 12),
              // `ticket-status` 750:8 — 8% accent wash, a 20% hairline in dark.
              Container(
                key: const ValueKey('event-ticket-status'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: muted
                      ? ClubUpColors.chip
                      : ClubUpColors.accent.withValues(
                          alpha: themeService.isDark ? 0.16 : 0.08,
                        ),
                  borderRadius: BorderRadius.circular(14),
                  border: themeService.isDark && !muted
                      ? Border.all(
                          color: ClubUpColors.accent.withValues(alpha: 0.4),
                        )
                      : null,
                ),
                child: Text(
                  status,
                  style: figtree(
                    size: 11,
                    weight: FontWeight.w700,
                    color: muted ? ClubUpColors.muted : ClubUpColors.accentText,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        // `ticket-card` 750:10
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ClubUpColors.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: ClubUpColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                offset: Offset(0, 6),
                blurRadius: 18,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // `ticket-summary` 750:11
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _LabelledValue(
                      label: S.ticketTypeLabel,
                      value: S.ticketTypeFree,
                      valueSize: 16,
                      valueWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _LabelledValue(
                    label: S.ticketPriceLabel,
                    value: S.ticketPriceFree,
                    valueSize: 18,
                    valueWeight: FontWeight.w800,
                    end: true,
                  ),
                ],
              ),
              if (remaining != null) ...[
                const SizedBox(height: 12),
                Divider(height: 1, thickness: 1, color: ClubUpColors.border),
                const SizedBox(height: 12),
                // `availability-row` 750:20 — the frame's perks row has no
                // field behind it and is not drawn.
                _IconRow(
                  key: const ValueKey('event-ticket-remaining'),
                  icon: Icons.confirmation_number_outlined,
                  label: S.ticketsRemaining(remaining),
                ),
              ],
              const SizedBox(height: 12),
              // `get-ticket-button` 750:30
              Semantics(
                button: true,
                child: GestureDetector(
                  key: const ValueKey('event-get-ticket'),
                  onTap: _open,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ClubUpColors.accent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      S.ticketGetButton,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: figtree(
                        size: 14,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LabelledValue extends StatelessWidget {
  const _LabelledValue({
    required this.label,
    required this.value,
    required this.valueSize,
    required this.valueWeight,
    this.end = false,
  });

  final String label;
  final String value;
  final double valueSize;
  final FontWeight valueWeight;
  final bool end;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: figtree(
          size: 11,
          weight: FontWeight.w600,
          color: ClubUpColors.muted,
          letterSpacing: 0,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: figtree(
          size: valueSize,
          weight: valueWeight,
          color: ClubUpColors.text,
        ),
      ),
    ],
  );
}

class _IconRow extends StatelessWidget {
  const _IconRow({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ClubUpColors.chip,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: ClubUpColors.muted),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          label,
          style: figtree(
            size: 13,
            weight: FontWeight.w600,
            color: ClubUpColors.text,
          ),
        ),
      ),
    ],
  );
}

/// `Ticket pop-up light/dark` — the student's ticket as a bottom sheet.
Future<void> showEventTicketSheet({
  required BuildContext context,
  required Event event,
  required String profileId,
  required String attendeeName,
  EventTicket? initialTicket,
  bool initiallyLoaded = false,
  EventTicketService? service,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: EventTicketColors.barrier,
    builder: (_) => EventTicketSheet(
      event: event,
      profileId: profileId,
      attendeeName: attendeeName,
      initialTicket: initialTicket,
      initiallyLoaded: initiallyLoaded,
      service: service,
    ),
  );
}

class EventTicketSheet extends StatefulWidget {
  const EventTicketSheet({
    super.key,
    required this.event,
    required this.profileId,
    required this.attendeeName,
    this.initialTicket,
    this.initiallyLoaded = false,
    this.service,
  });

  final Event event;
  final String profileId;
  final String attendeeName;
  final EventTicket? initialTicket;

  /// Whether [initialTicket] is a fresh answer (null then means "not issued")
  /// rather than "not fetched yet".
  final bool initiallyLoaded;
  final EventTicketService? service;

  @override
  State<EventTicketSheet> createState() => _EventTicketSheetState();
}

class _EventTicketSheetState extends State<EventTicketSheet>
    with WidgetsBindingObserver {
  static const _brightnessChannel = MethodChannel('ku_app/ticket_brightness');

  EventTicket? _ticket;
  late _TicketPhase _phase;
  String? _error;
  bool _refreshing = false;
  bool _walletAvailable = false;
  bool _addingToWallet = false;
  bool _brightnessRaised = false;
  int _generation = 0;

  EventTicketService get _service => widget.service ?? eventTicketService;
  bool get _googleWallet => googleWalletTicketService.supportedPlatform;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticket = widget.initialTicket;
    _phase = widget.initiallyLoaded
        ? _phaseFor(widget.initialTicket)
        : _TicketPhase.loading;
    _syncBrightness();
    _load();
    _checkWalletAvailability();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_brightnessRaised) _setBrightness(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncBrightness();
      _load();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (_brightnessRaised) {
        _brightnessRaised = false;
        _setBrightness(false);
      }
    }
  }

  /// "Keep screen brightness up for a quick scan" — raised only while a
  /// scannable QR is on screen.
  void _syncBrightness() {
    final want = _phase == _TicketPhase.active;
    if (want == _brightnessRaised) return;
    _brightnessRaised = want;
    _setBrightness(want);
  }

  Future<void> _setBrightness(bool enabled) async {
    try {
      await _brightnessChannel.invokeMethod<void>(
        enabled ? 'maximize' : 'restore',
      );
    } on MissingPluginException {
      // Desktop, web and tests have no brightness channel.
    } on PlatformException {
      // Brightness controls can be unavailable on some devices.
    }
  }

  Future<void> _checkWalletAvailability() async {
    try {
      final available = _googleWallet
          ? await googleWalletTicketService.canAddPasses()
          : await appleWalletTicketService.canAddPasses();
      if (mounted) setState(() => _walletAvailable = available);
    } catch (_) {
      // The QR still admits the holder without a native Wallet.
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      final ticket = await _service
          .fetch(widget.event.id, widget.profileId)
          .timeout(const Duration(seconds: 15));
      if (!mounted || generation != _generation) return;
      setState(() {
        _ticket = ticket;
        _phase = _phaseFor(ticket);
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        // Never keep a stale QR after a failed refresh.
        _ticket = null;
        _phase = _TicketPhase.error;
        _error = _ticketErrorMessage(context, error);
      });
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _refreshing = false);
        _syncBrightness();
      }
    }
  }

  Future<void> _addToWallet(String ticketId) async {
    setState(() => _addingToWallet = true);
    try {
      if (_googleWallet) {
        await googleWalletTicketService.addTicket(ticketId);
      } else {
        await appleWalletTicketService.addTicket(ticketId);
      }
    } catch (_) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _googleWallet
                  ? l10n.googleWalletTicketFailed
                  : l10n.appleWalletTicketFailed,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _addingToWallet = false);
    }
  }

  String get _whenValue {
    final lang = localeService.languageCode;
    final start = widget.event.dateTime;
    final end = widget.event.endTime;
    final clock = DateFormat.Hm(lang);
    final sameDay =
        start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
    final day = DateFormat.MMMEd(lang).format(start);
    return sameDay
        ? '$day · ${clock.format(start)}–${clock.format(end)}'
        : '$day · ${clock.format(start)} – '
              '${DateFormat.MMMEd(lang).format(end)} · ${clock.format(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final ticket = _ticket;
    final active = _phase == _TicketPhase.active && ticket != null;

    return Container(
      key: const ValueKey('event-ticket-sheet'),
      decoration: BoxDecoration(
        color: EventTicketColors.sheet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: themeService.isDark
                ? const Color(0x80000000)
                : const Color(0x29000000),
            offset: const Offset(0, -10),
            blurRadius: 32,
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 18 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // `Grabber`
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: EventTicketColors.grabber,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 19),
            // `Sheet header`
            SizedBox(
              height: 36,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      S.ticketSheetTitle,
                      style: figtree(
                        size: 16,
                        weight: FontWeight.w800,
                        color: ClubUpColors.text,
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: MaterialLocalizations.of(context).closeButtonTooltip,
                    child: GestureDetector(
                      key: const ValueKey('event-ticket-close'),
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: EventTicketColors.tile,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 17,
                          color: ClubUpColors.muted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // `Ticket heading`
            if (_badge case final badge?) ...[
              Center(child: badge),
              const SizedBox(height: 4),
            ],
            Text(
              widget.event.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: figtree(
                size: 22,
                weight: FontWeight.w800,
                color: ClubUpColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              S.ticketTypeFree,
              textAlign: TextAlign.center,
              style: figtree(
                size: 12,
                weight: FontWeight.w600,
                color: ClubUpColors.muted,
              ),
            ),
            const SizedBox(height: 19),
            _QrBlock(
              phase: _phase,
              payload: active ? ticket.qrPayload : null,
              refreshing: _refreshing,
              onRefresh: _refreshing ? null : _load,
            ),
            const SizedBox(height: 19),
            // `Scan instruction`
            _Instruction(phase: _phase, error: _error),
            const SizedBox(height: 18),
            // `Event details`
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: EventTicketColors.detailFill,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: EventTicketColors.detailBorder),
              ),
              child: Column(
                children: [
                  _SheetDetailRow(
                    icon: Icons.calendar_month_outlined,
                    label: S.ticketDateTimeLabel,
                    value: _whenValue,
                  ),
                  if (widget.event.location.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: EventTicketColors.detailBorder,
                    ),
                    const SizedBox(height: 8),
                    _SheetDetailRow(
                      icon: Icons.place_outlined,
                      label: S.ticketVenueLabel,
                      value: widget.event.location.trim(),
                    ),
                  ],
                ],
              ),
            ),
            // `Ticket identification` — only once a ticket exists.
            if (ticket != null) ...[
              const SizedBox(height: 19),
              Row(
                children: [
                  Expanded(
                    child: _IdentityTile(
                      label: S.ticketAttendeeLabel,
                      value: widget.attendeeName,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _IdentityTile(
                      key: const ValueKey('event-ticket-code'),
                      label: S.ticketIdLabel,
                      value: ticket.displayCode ?? '—',
                      selectable: ticket.displayCode != null,
                    ),
                  ),
                ],
              ),
            ],
            // `Wallet action`
            if (active && _walletAvailable) ...[
              const SizedBox(height: 18),
              _WalletButton(
                google: _googleWallet,
                busy: _addingToWallet,
                onTap: () => _addToWallet(ticket.id),
              ),
            ],
            const SizedBox(height: 19),
            // `Done`
            Semantics(
              button: true,
              child: GestureDetector(
                key: const ValueKey('event-ticket-done'),
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: EventTicketColors.detailBorder),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.done,
                    style: figtree(
                      size: 14,
                      weight: FontWeight.w700,
                      color: ClubUpColors.text,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? get _badge => switch (_phase) {
    _TicketPhase.loading || _TicketPhase.error => null,
    _TicketPhase.active => _StatusBadge(
      icon: Icons.check_circle_outline_rounded,
      label: S.ticketOnTheList,
      color: EventTicketColors.positive,
      wash: EventTicketColors.positiveWash,
    ),
    _TicketPhase.pending => _StatusBadge(
      icon: Icons.hourglass_empty_rounded,
      label: S.ticketPendingBadge,
      color: ClubUpColors.muted,
      wash: EventTicketColors.tile,
    ),
    _TicketPhase.used => _StatusBadge(
      icon: Icons.task_alt_rounded,
      label: S.ticketUsedBadge,
      color: EventTicketColors.warning,
      wash: EventTicketColors.warningWash,
    ),
    _TicketPhase.revoked => _StatusBadge(
      icon: Icons.block_rounded,
      label: S.ticketRevokedBadge,
      color: EventTicketColors.danger,
      wash: EventTicketColors.dangerWash,
    ),
  };
}

/// `Confirmation` — the uppercase status pill above the event name.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.wash,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color wash;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('event-ticket-badge'),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: wash,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: figtree(
              size: 11,
              weight: FontWeight.w700,
              color: color,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    ),
  );
}

/// `QR code card` 206×206 with the `Refresh QR code` disc riding its top-right
/// corner 8pt outside the card.
class _QrBlock extends StatelessWidget {
  const _QrBlock({
    required this.phase,
    required this.payload,
    required this.refreshing,
    required this.onRefresh,
  });

  static const double _card = 206;

  final _TicketPhase phase;
  final String? payload;
  final bool refreshing;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final qr = payload;
    final Widget body;
    if (qr != null) {
      body = QrImageView(
        key: const ValueKey('event-ticket-qr'),
        data: qr,
        size: 168,
        padding: EdgeInsets.zero,
        backgroundColor: Colors.white,
        semanticsLabel: l10n.ticketTitle,
      );
    } else if (phase == _TicketPhase.loading) {
      body = SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: ClubUpColors.muted,
        ),
      );
    } else {
      body = Icon(
        switch (phase) {
          _TicketPhase.used => Icons.task_alt_rounded,
          _TicketPhase.revoked => Icons.block_rounded,
          _TicketPhase.error => Icons.wifi_off_rounded,
          _ => Icons.hourglass_empty_rounded,
        },
        size: 44,
        color: ClubUpColors.muted,
      );
    }

    return SizedBox(
      height: _card,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardLeft = (constraints.maxWidth - _card) / 2;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: cardLeft,
                top: 0,
                child: Container(
                  width: _card,
                  height: _card,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    // A live code is always black on white, whatever the
                    // theme — scanners need the contrast.
                    color: qr != null ? Colors.white : EventTicketColors.tile,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: qr != null
                        ? const [
                            BoxShadow(
                              color: Color(0x1A000000),
                              offset: Offset(0, 8),
                              blurRadius: 20,
                            ),
                          ]
                        : null,
                  ),
                  child: body,
                ),
              ),
              Positioned(
                left: cardLeft + _card + 8,
                top: 3,
                child: Semantics(
                  button: true,
                  label: l10n.ticketRefresh,
                  child: GestureDetector(
                    key: const ValueKey('event-ticket-refresh'),
                    onTap: onRefresh,
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: EventTicketColors.refreshFill,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: EventTicketColors.refreshBorder,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1F000000),
                            offset: Offset(0, 3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: refreshing && phase != _TicketPhase.loading
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: ClubUpColors.accentText,
                              ),
                            )
                          : Icon(
                              Icons.sync_rounded,
                              size: 18,
                              color: ClubUpColors.accentText,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Instruction extends StatelessWidget {
  const _Instruction({required this.phase, required this.error});

  final _TicketPhase phase;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (title, body) = switch (phase) {
      _TicketPhase.active => (S.ticketPresentAtDoor, S.ticketBrightnessHint),
      _TicketPhase.pending => (S.ticketPendingTitle, l10n.ticketNotIssued),
      _TicketPhase.used => (l10n.ticketAlreadyUsed, S.ticketUsedBody),
      _TicketPhase.revoked => (l10n.ticketRevoked, S.ticketRevokedBody),
      _TicketPhase.error => (error ?? l10n.ticketOperationFailed, null),
      _TicketPhase.loading => (S.ticketLoading, null),
    };
    return Column(
      key: const ValueKey('event-ticket-instruction'),
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: figtree(
            size: 13,
            weight: FontWeight.w700,
            color: ClubUpColors.text,
          ),
        ),
        if (body != null) ...[
          const SizedBox(height: 2),
          Text(
            body,
            textAlign: TextAlign.center,
            style: figtree(
              size: 11,
              weight: FontWeight.w400,
              color: ClubUpColors.muted,
            ),
          ),
        ],
      ],
    );
  }
}

class _SheetDetailRow extends StatelessWidget {
  const _SheetDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: EventTicketColors.tile,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: ClubUpColors.accentText),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: figtree(
                size: 10,
                weight: FontWeight.w600,
                color: ClubUpColors.muted,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: figtree(
                size: 13,
                weight: FontWeight.w700,
                color: ClubUpColors.text,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _IdentityTile extends StatelessWidget {
  const _IdentityTile({
    super.key,
    required this.label,
    required this.value,
    this.selectable = false,
  });

  final String label;
  final String value;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final style = figtree(
      size: 12,
      weight: FontWeight.w700,
      color: ClubUpColors.text,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: EventTicketColors.tile,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: figtree(
              size: 10,
              weight: FontWeight.w600,
              color: ClubUpColors.muted,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 3),
          // The door can check a holder in by this code when the QR will not
          // scan, so it has to be copyable.
          if (selectable)
            SelectableText(value, maxLines: 1, style: style)
          else
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
        ],
      ),
    );
  }
}

/// `Wallet action` — black in both themes, as the platform wallets require.
class _WalletButton extends StatelessWidget {
  const _WalletButton({
    required this.google,
    required this.busy,
    required this.onTap,
  });

  final bool google;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      button: true,
      enabled: !busy,
      child: GestureDetector(
        key: ValueKey(google ? 'add-to-google-wallet' : 'add-to-apple-wallet'),
        onTap: busy ? null : onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: busy ? 0.6 : 1,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  google ? Icons.account_balance_wallet_outlined : Icons.apple,
                  size: 20,
                  color: Colors.white,
                ),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    google ? l10n.addToGoogleWallet : l10n.addToAppleWallet,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: figtree(
                      size: 15,
                      weight: FontWeight.w700,
                      color: Colors.white,
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
