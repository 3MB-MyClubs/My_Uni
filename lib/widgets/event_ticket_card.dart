import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../services/apple_wallet_ticket_service.dart';
import '../services/event_ticket_service.dart';
import '../services/pkpass_ticket_service.dart';

/// The holder's ticket, or staff controls for a single RSVP attendee.
class EventTicketCard extends StatefulWidget {
  const EventTicketCard({
    super.key,
    required this.eventId,
    required this.profileId,
    this.manage = false,
    this.service,
    this.onChanged,
  });
  final String eventId;
  final String profileId;
  final bool manage;
  final EventTicketService? service;
  final ValueChanged<EventTicket?>? onChanged;
  @override
  State<EventTicketCard> createState() => _EventTicketCardState();
}

class _EventTicketCardState extends State<EventTicketCard>
    with WidgetsBindingObserver {
  EventTicket? _ticket;
  bool _busy = true;
  bool _walletAvailable = false;
  bool _addingToWallet = false;
  String? _error;
  int _generation = 0;
  EventTicketService get _service => widget.service ?? eventTicketService;
  bool get _pkpassWallet => pkpassTicketService.supportedPlatform;

  void _showQr(String payload) {
    showDialog<void>(
      context: context,
      useSafeArea: false,
      builder: (context) => _ExpandedTicketQr(
        payload: payload,
        title: AppLocalizations.of(context)!.ticketTitle,
        hint: AppLocalizations.of(context)!.ticketPrivateHint,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _checkWalletAvailability();
  }

  Future<void> _checkWalletAvailability() async {
    try {
      // Android can always save the pass file, even without a wallet installed.
      // Google Wallet is intentionally hidden until it is offered again.
      final available =
          _pkpassWallet || await appleWalletTicketService.canAddPasses();
      if (mounted) setState(() => _walletAvailable = available);
    } catch (_) {
      // Ticket display is still usable if the native Wallet API is unavailable.
    }
  }

  Future<void> _addToWallet(String ticketId) async {
    setState(() => _addingToWallet = true);
    try {
      if (_pkpassWallet) {
        await pkpassTicketService.addTicket(ticketId);
      } else {
        await appleWalletTicketService.addTicket(ticketId);
      }
    } catch (error, stackTrace) {
      assert(() {
        debugPrint('Wallet ticket failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        return true;
      }());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _pkpassWallet
                  ? AppLocalizations.of(context)!.walletPassTicketFailed
                  : AppLocalizations.of(context)!.appleWalletTicketFailed,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _addingToWallet = false);
    }
  }

  @override
  void didUpdateWidget(EventTicketCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventId != widget.eventId ||
        oldWidget.profileId != widget.profileId) {
      _ticket = null;
      _load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) _load();
  }

  Future<void> _load() => _run(() async {
    return _service.fetch(widget.eventId, widget.profileId);
  });

  Future<void> _run(
    Future<EventTicket?> Function() action, {
    bool notifyChange = false,
  }) async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ticket = await action().timeout(const Duration(seconds: 15));
      if (mounted && generation == _generation) {
        setState(() => _ticket = ticket);
        if (notifyChange) widget.onChanged?.call(ticket);
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          // Never keep a stale QR after a failed refresh/mutation.
          _ticket = null;
          _error = error is PostgrestException && error.code == '42501'
              ? l10n.ticketUnauthorized
              : l10n.ticketOperationFailed;
        });
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ticket = _ticket;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.confirmation_number_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.ticketTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: _busy ? null : _load,
                  icon: const Icon(Icons.refresh),
                  tooltip: l10n.ticketRefresh,
                ),
              ],
            ),
            if (_busy)
              const LinearProgressIndicator()
            else if (_error != null)
              Text(_error!, key: const ValueKey('ticket-error'))
            else ...[
              Text(
                ticket == null
                    ? l10n.ticketNotIssued
                    : ticket.revokedAt != null
                    ? l10n.ticketRevoked
                    : ticket.usedAt != null
                    ? l10n.ticketAlreadyUsed
                    : l10n.ticketReady,
              ),
              if (!widget.manage && ticket?.isActive == true) ...[
                const SizedBox(height: 12),
                InkWell(
                  key: const ValueKey('admission-ticket-qr-action'),
                  onTap: () => _showQr(ticket.qrPayload),
                  child: QrImageView(
                    key: const ValueKey('admission-ticket-qr'),
                    data: ticket!.qrPayload,
                    size: 220,
                    backgroundColor: Colors.white,
                    semanticsLabel: l10n.ticketTitle,
                  ),
                ),
                Text(l10n.ticketPrivateHint, textAlign: TextAlign.center),
                if (_walletAvailable) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: ValueKey(
                      _pkpassWallet ? 'add-to-wallet' : 'add-to-apple-wallet',
                    ),
                    style: _pkpassWallet
                        ? OutlinedButton.styleFrom(
                            minimumSize: const Size(200, 48),
                          )
                        : null,
                    onPressed: _addingToWallet
                        ? null
                        : () => _addToWallet(ticket.id),
                    icon: const Icon(Icons.account_balance_wallet_outlined),
                    label: Text(
                      _pkpassWallet ? l10n.addToWallet : l10n.addToAppleWallet,
                    ),
                  ),
                  if (_pkpassWallet)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        l10n.walletPassHint,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ],
              if (widget.manage)
                Wrap(
                  spacing: 8,
                  children: [
                    if (ticket == null)
                      FilledButton(
                        onPressed: () => _run(
                          () =>
                              _service.issue(widget.eventId, widget.profileId),
                          notifyChange: true,
                        ),
                        child: Text(l10n.ticketIssue),
                      ),
                    if (ticket != null && ticket.revokedAt == null)
                      TextButton(
                        onPressed: () => _run(() async {
                          await _service.revoke(widget.eventId, ticket.id);
                          return _service.fetch(
                            widget.eventId,
                            widget.profileId,
                          );
                        }, notifyChange: true),
                        child: Text(l10n.ticketRevoke),
                      ),
                    if (ticket != null)
                      FilledButton(
                        onPressed: () => _run(
                          () => _service.issue(
                            widget.eventId,
                            widget.profileId,
                            reissue: true,
                          ),
                          notifyChange: true,
                        ),
                        child: Text(l10n.ticketReissue),
                      ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExpandedTicketQr extends StatefulWidget {
  const _ExpandedTicketQr({
    required this.payload,
    required this.title,
    required this.hint,
  });

  final String payload;
  final String title;
  final String hint;

  @override
  State<_ExpandedTicketQr> createState() => _ExpandedTicketQrState();
}

class _ExpandedTicketQrState extends State<_ExpandedTicketQr>
    with WidgetsBindingObserver {
  static const _brightnessChannel = MethodChannel('ku_app/ticket_brightness');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setBrightness(true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setBrightness(true);
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _setBrightness(false);
    }
  }

  Future<void> _setBrightness(bool enabled) async {
    try {
      await _brightnessChannel.invokeMethod<void>(
        enabled ? 'maximize' : 'restore',
      );
    } on MissingPluginException {
      // Desktop and web still show the enlarged QR.
    } on PlatformException {
      // Brightness controls can be unavailable on some devices.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setBrightness(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData.light(),
    child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Text(widget.title),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final qrSize = (constraints.biggest.shortestSide - 48).clamp(
                0.0,
                520.0,
              );
              return Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      QrImageView(
                        key: const ValueKey('admission-ticket-qr-expanded'),
                        data: widget.payload,
                        size: qrSize,
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.white,
                        semanticsLabel: widget.title,
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          widget.hint,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}
