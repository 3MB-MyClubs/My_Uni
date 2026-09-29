import 'package:flutter/material.dart';

import '../models/event.dart';
import '../services/app_strings.dart';
import '../services/supabase_content_service.dart';
import 'event_detail_screen.dart';

typedef SharedEventResolver = Future<Event?> Function(String eventId);

/// Resolves a shared event by ID before displaying its description screen.
class EventSharedLinkScreen extends StatefulWidget {
  const EventSharedLinkScreen({
    super.key,
    required this.eventId,
    this.resolveEvent,
  });

  final String eventId;
  final SharedEventResolver? resolveEvent;

  @override
  State<EventSharedLinkScreen> createState() => _EventSharedLinkScreenState();
}

class _EventSharedLinkScreenState extends State<EventSharedLinkScreen> {
  late Future<Event?> _event = _resolve();

  Future<Event?> _resolve() async {
    // A fresh server read applies the current account's RLS policy even if
    // another account previously cached this event on the same device.
    final resolver =
        widget.resolveEvent ??
        (id) => supabaseContentService.fetchEventById(id, forceRemote: true);
    final event = await resolver(widget.eventId);
    if (event != null && widget.resolveEvent == null) {
      try {
        await supabaseContentService.fetchClubById(event.clubId);
      } catch (_) {
        // The event description can still open without club metadata.
      }
    }
    return event;
  }

  @override
  void didUpdateWidget(covariant EventSharedLinkScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.eventId != oldWidget.eventId) _event = _resolve();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Event?>(
    future: _event,
    builder: (context, snapshot) {
      final event = snapshot.data;
      if (event != null) {
        final hex = event.accentColorHex?.trim() ?? '';
        final parsed = hex.length == 6
            ? int.tryParse('FF$hex', radix: 16)
            : null;
        return EventDetailScreen(
          event: event,
          color: parsed == null ? const Color(0xFF9E2045) : Color(parsed),
        );
      }
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: snapshot.connectionState == ConnectionState.waiting
              ? const CircularProgressIndicator()
              : Text(S.eventUnavailable),
        ),
      );
    },
  );
}
