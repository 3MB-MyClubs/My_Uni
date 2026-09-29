import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../services/checkin_store.dart';
import '../services/event_ticket_service.dart';
import '../services/media_delivery_service.dart';
import '../widgets/app_network_image.dart';

class EventTicketScanScreen extends StatefulWidget {
  const EventTicketScanScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
    this.service,
    this.scannerBuilder,
  });
  final String eventId;
  final String eventTitle;
  final EventTicketService? service;

  /// Allows camera-independent tests of duplicate detection and network failure.
  final Widget Function(void Function(String) onScan)? scannerBuilder;
  @override
  State<EventTicketScanScreen> createState() => _EventTicketScanScreenState();
}

class _EventTicketScanScreenState extends State<EventTicketScanScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool? _authorized;
  bool _busy = false;
  TicketScanResult? _result;
  TicketPerson? _person;
  bool _personLoading = false;
  String? _error;
  EventTicketService get _service => widget.service ?? eventTicketService;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _authorize();
  }

  Future<void> _authorize() async {
    setState(() {
      _authorized = null;
      _error = null;
    });
    try {
      final authorized = await _service
          .canManage(widget.eventId)
          .timeout(const Duration(seconds: 15));
      if (mounted) setState(() => _authorized = authorized);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = AppLocalizations.of(context)!.ticketConnectionFailed,
        );
      }
    }
  }

  Future<void> _scan(String payload) => _admit(
    () => _service.scan(widget.eventId, payload),
    (result) => _service.personForScan(widget.eventId, payload, result),
  );

  Future<void> _submitCode() async {
    final code = EventTicketService.normalizeDisplayCode(_codeController.text);
    if (code == null) return;
    FocusScope.of(context).unfocus();
    await _admit(
      () => _service.scanCode(widget.eventId, code),
      (result) => _service.personForCode(widget.eventId, code, result),
    );
  }

  Future<void> _admit(
    Future<TicketScanResult> Function() checkIn,
    Future<TicketPerson?> Function(TicketScanResult) findPerson,
  ) async {
    if (_busy || _result != null || _error != null || _authorized != true) {
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await checkIn().timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        _result = result;
        _personLoading =
            result.status != TicketScanStatus.invalid &&
            result.status != TicketScanStatus.wrongEvent;
      });
      if (result.status != TicketScanStatus.invalid &&
          result.status != TicketScanStatus.wrongEvent) {
        try {
          final person = await findPerson(
            result,
          ).timeout(const Duration(seconds: 15));
          if (mounted) setState(() => _person = person);
        } catch (_) {
          // Admission status remains authoritative even if profile loading fails.
        } finally {
          if (mounted) setState(() => _personLoading = false);
        }
      }
      if (result.status == TicketScanStatus.checkedIn ||
          result.status == TicketScanStatus.alreadyUsed) {
        unawaited(checkinStore.hydrate(widget.eventId, force: true));
      }
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = error is PostgrestException && error.code == '42501'
            ? AppLocalizations.of(context)!.ticketUnauthorized
            : AppLocalizations.of(context)!.ticketConnectionFailed,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _reset() {
    _codeController.clear();
    setState(() {
      _result = null;
      _person = null;
      _personLoading = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final status = _result?.status;
    final message =
        _error ??
        switch (status) {
          TicketScanStatus.checkedIn => l10n.ticketCheckedIn,
          TicketScanStatus.alreadyUsed => l10n.ticketAlreadyUsed,
          TicketScanStatus.revoked => l10n.ticketRevoked,
          TicketScanStatus.wrongEvent => l10n.ticketWrongEvent,
          TicketScanStatus.invalid => l10n.ticketInvalid,
          null => l10n.ticketScanHint,
        };
    return Scaffold(
      appBar: _result == null && _error == null
          ? AppBar(title: Text(l10n.ticketScan))
          : null,
      body: SafeArea(
        child: _result != null || _error != null
            ? _buildScanResult(context, message)
            : Column(
                children: [
                  if (!keyboardOpen)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        widget.eventTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  if (!keyboardOpen)
                    Expanded(
                      flex: 3,
                      child: _authorized != true
                          ? Center(
                              child: _error != null || _authorized == false
                                  ? Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(_error ?? l10n.ticketUnauthorized),
                                        TextButton(
                                          onPressed: _authorize,
                                          child: Text(l10n.ticketRefresh),
                                        ),
                                      ],
                                    )
                                  : const CircularProgressIndicator(),
                            )
                          : Stack(
                              fit: StackFit.expand,
                              children: [
                                widget.scannerBuilder?.call(_scan) ??
                                    MobileScanner(
                                      // The widget owns camera lifecycle, permission transitions, and disposal.
                                      onDetect: (capture) {
                                        for (final barcode
                                            in capture.barcodes) {
                                          final value = barcode.rawValue;
                                          if (value != null) {
                                            _scan(value);
                                            break;
                                          }
                                        }
                                      },
                                      errorBuilder: (context, error) => Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              l10n.ticketCameraUnavailable,
                                              textAlign: TextAlign.center,
                                            ),
                                            TextButton(
                                              onPressed: openAppSettings,
                                              child: Text(
                                                l10n.ticketCameraSettings,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                IgnorePointer(
                                  child: Center(
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        final size =
                                            constraints.biggest.shortestSide *
                                            0.78;
                                        return Container(
                                          key: const ValueKey(
                                            'ticket-scan-frame',
                                          ),
                                          width: size,
                                          height: size,
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 3,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Colors.black54,
                                                blurRadius: 12,
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  Expanded(
                    key: const ValueKey('ticket-scan-footer'),
                    flex: 2,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          if (_authorized == true)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextField(
                                    key: const ValueKey(
                                      'ticket-manual-code-input',
                                    ),
                                    controller: _codeController,
                                    maxLength: 6,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    textInputAction: TextInputAction.done,
                                    autocorrect: false,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[A-Za-z0-9]'),
                                      ),
                                      LengthLimitingTextInputFormatter(6),
                                      TextInputFormatter.withFunction(
                                        (oldValue, newValue) =>
                                            newValue.copyWith(
                                              text: newValue.text.toUpperCase(),
                                            ),
                                      ),
                                    ],
                                    decoration: InputDecoration(
                                      labelText: l10n.ticketEnterCode,
                                      hintText: l10n.ticketCodeHint,
                                      border: const OutlineInputBorder(),
                                    ),
                                    onSubmitted: (_) => _submitCode(),
                                  ),
                                  ValueListenableBuilder<TextEditingValue>(
                                    valueListenable: _codeController,
                                    builder: (context, value, _) =>
                                        FilledButton.icon(
                                          key: const ValueKey(
                                            'ticket-manual-code-submit',
                                          ),
                                          onPressed:
                                              !_busy &&
                                                  EventTicketService.normalizeDisplayCode(
                                                        value.text,
                                                      ) !=
                                                      null
                                              ? _submitCode
                                              : null,
                                          icon: const Icon(
                                            Icons.keyboard_alt_outlined,
                                          ),
                                          label: Text(l10n.ticketCheckInCode),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                if (_busy)
                                  const LinearProgressIndicator()
                                else
                                  Semantics(
                                    liveRegion: true,
                                    child: Row(
                                      children: [
                                        Icon(
                                          status == TicketScanStatus.checkedIn
                                              ? Icons.check_circle
                                              : Icons.info_outline,
                                          color:
                                              status ==
                                                  TicketScanStatus.checkedIn
                                              ? Colors.green
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            message,
                                            key: const ValueKey(
                                              'ticket-scan-result',
                                            ),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (_result != null &&
                                    status != TicketScanStatus.invalid &&
                                    status != TicketScanStatus.wrongEvent) ...[
                                  const SizedBox(height: 16),
                                  if (_personLoading)
                                    const CircularProgressIndicator()
                                  else
                                    Row(
                                      key: const ValueKey('ticket-scan-person'),
                                      children: [
                                        _ScannedPersonAvatar(person: _person),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _person?.fullName.isNotEmpty == true
                                                ? _person!.fullName
                                                : l10n.unknownUser,
                                            key: const ValueKey(
                                              'ticket-scan-person-name',
                                            ),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleLarge,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                                if ((_result != null || _error != null) &&
                                    _authorized == true)
                                  FilledButton(
                                    onPressed: _reset,
                                    child: Text(l10n.ticketScanNext),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildScanResult(BuildContext context, String message) {
    final l10n = AppLocalizations.of(context)!;
    final status = _result?.status;
    final color = switch (status) {
      TicketScanStatus.checkedIn => Colors.green,
      TicketScanStatus.alreadyUsed => Colors.amber.shade800,
      TicketScanStatus.revoked => Colors.red,
      _ => Theme.of(context).colorScheme.error,
    };
    final warning = switch (status) {
      TicketScanStatus.alreadyUsed => l10n.ticketScanAlreadyCheckedIn,
      TicketScanStatus.revoked => l10n.ticketScanCancelled,
      _ => message,
    };
    final person = _person;
    final usedAt = person?.usedAt;
    final locale = Localizations.localeOf(context).toString();
    return Container(
      key: const ValueKey('ticket-scan-fullscreen-result'),
      width: double.infinity,
      height: double.infinity,
      color: color.withValues(alpha: 0.09),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  children: [
                    Icon(
                      status == TicketScanStatus.checkedIn
                          ? Icons.check_circle_rounded
                          : status == TicketScanStatus.alreadyUsed ||
                                status == TicketScanStatus.revoked
                          ? Icons.warning_rounded
                          : Icons.error_rounded,
                      key: const ValueKey('ticket-scan-status-icon'),
                      color: color,
                      size: 88,
                    ),
                    const SizedBox(height: 20),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        warning,
                        key: const ValueKey('ticket-scan-result'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(widget.eventTitle, textAlign: TextAlign.center),
                    if (_result != null &&
                        status != TicketScanStatus.invalid &&
                        status != TicketScanStatus.wrongEvent) ...[
                      const SizedBox(height: 42),
                      if (_personLoading)
                        const CircularProgressIndicator()
                      else ...[
                        _ScannedPersonAvatar(person: person, radius: 56),
                        const SizedBox(height: 20),
                        Text(
                          person?.fullName.isNotEmpty == true
                              ? person!.fullName
                              : l10n.unknownUser,
                          key: const ValueKey('ticket-scan-person-name'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (person?.major?.isNotEmpty == true) ...[
                          const SizedBox(height: 8),
                          Text(
                            person!.major!,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                        if (usedAt != null) ...[
                          const SizedBox(height: 26),
                          Text(l10n.ticketCheckInTime),
                          const SizedBox(height: 6),
                          Text(
                            DateFormat(
                              'd MMM y, HH:mm',
                              locale,
                            ).format(usedAt.toLocal()),
                            key: const ValueKey('ticket-scan-checkin-time'),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _reset,
                child: Text(l10n.ticketScanNext),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannedPersonAvatar extends StatelessWidget {
  const _ScannedPersonAvatar({required this.person, this.radius = 28});

  final TicketPerson? person;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final name = person?.fullName ?? '';
    final url = person?.avatarUrl;
    final fallback = CircleAvatar(
      radius: radius,
      child: Text(name.isEmpty ? '?' : name[0].toUpperCase()),
    );
    if (url == null || url.isEmpty) return fallback;
    return ClipOval(
      child: AppNetworkImage(
        key: const ValueKey('ticket-scan-person-avatar'),
        url: url,
        rendition: MediaRendition.thumbnail,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_) => fallback,
      ),
    );
  }
}
