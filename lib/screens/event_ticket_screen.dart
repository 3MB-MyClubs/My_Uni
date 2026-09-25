import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/event_ticket_service.dart';
import '../widgets/event_ticket_card.dart';

class EventTicketScreen extends StatelessWidget {
  const EventTicketScreen({
    super.key,
    required this.eventId,
    required this.profileId,
    this.service,
  });

  final String eventId;
  final String profileId;
  final EventTicketService? service;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(AppLocalizations.of(context)!.ticketTitle)),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          EventTicketCard(
            eventId: eventId,
            profileId: profileId,
            service: service,
          ),
        ],
      ),
    ),
  );
}
