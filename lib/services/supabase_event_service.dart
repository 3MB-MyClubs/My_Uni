import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/event.dart';
import 'supabase_config.dart';

class SupabaseEventService {
  static const _imageBucket = 'event-images';

  SupabaseClient? get _client {
    if (!SupabaseConfig.isConfigured) return null;
    return Supabase.instance.client;
  }

  Future<Event> createEvent(Event event) async {
    final client = _client;
    if (client == null) return event;

    final uploadedImage = event.imagePath == null
        ? null
        : await _uploadImage(clubId: event.clubId, imagePath: event.imagePath!);

    final payload = <String, dynamic>{
      'club_id': event.clubId,
      'title': event.title,
      'description': event.description,
      'location': event.location,
      'event_date': _dateOnly(event.dateTime),
      'starts_at': event.dateTime.toUtc().toIso8601String(),
      'ends_at': event.endTime.toUtc().toIso8601String(),
      'is_public': true,
      'created_by_user_id': event.createdByUserId,
      'tags': event.tags,
      'registration_url': event.registrationUrl,
      'schedule': event.schedule?.map((slot) => slot.toMap()).toList(),
      'speakers': event.speakers.map((speaker) => speaker.toMap()).toList(),
    };
    if (uploadedImage != null) {
      payload['image_path'] = uploadedImage.path;
      payload['image_url'] = uploadedImage.publicUrl;
    }

    final row = await client
        .from('events')
        .insert(payload)
        .select(
          'id, club_id, title, description, location, event_date, starts_at, ends_at, image_path, image_url, created_by_user_id, tags, registration_url, schedule, speakers',
        )
        .single();

    final data = Map<String, dynamic>.from(row);
    return Event(
      id: data['id']?.toString() ?? event.id,
      clubId: data['club_id']?.toString() ?? event.clubId,
      title: data['title']?.toString() ?? event.title,
      description: data['description']?.toString() ?? event.description,
      location: data['location']?.toString() ?? event.location,
      dateTime:
          DateTime.tryParse(data['starts_at']?.toString() ?? '') ??
          event.dateTime,
      endTime:
          DateTime.tryParse(data['ends_at']?.toString() ?? '') ?? event.endTime,
      attendeeUserIds: const [],
      imagePath:
          data['image_url']?.toString() ??
          uploadedImage?.publicUrl ??
          data['image_path']?.toString(),
      createdByUserId:
          data['created_by_user_id']?.toString() ?? event.createdByUserId,
      tags: _stringList(data['tags']),
      schedule: _scheduleFromRaw(data['schedule']) ?? event.schedule,
      registrationUrl:
          data['registration_url']?.toString() ?? event.registrationUrl,
      speakers: _speakersFromRaw(data['speakers']),
    );
  }

  Future<_UploadedEventImage> _uploadImage({
    required String clubId,
    required String imagePath,
  }) async {
    final client = _client;
    if (client == null) {
      return _UploadedEventImage(path: imagePath, publicUrl: imagePath);
    }

    final bytes = await File(imagePath).readAsBytes();
    final objectPath =
        'events/$clubId/${DateTime.now().millisecondsSinceEpoch}.jpg';

    await client.storage
        .from(_imageBucket)
        .uploadBinary(
          objectPath,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );

    return _UploadedEventImage(
      path: objectPath,
      publicUrl: client.storage.from(_imageBucket).getPublicUrl(objectPath),
    );
  }

  String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  List<String> _stringList(dynamic raw) {
    if (raw is List) return raw.map((value) => value.toString()).toList();
    return const [];
  }

  List<EventSlot>? _scheduleFromRaw(dynamic raw) {
    if (raw is! List) return null;
    return raw
        .whereType<Map>()
        .map((slot) => EventSlot.fromMap(Map<String, dynamic>.from(slot)))
        .toList();
  }

  List<EventSpeaker> _speakersFromRaw(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (speaker) => EventSpeaker.fromMap(Map<String, dynamic>.from(speaker)),
        )
        .toList();
  }
}

final supabaseEventService = SupabaseEventService();

class _UploadedEventImage {
  final String path;
  final String publicUrl;

  const _UploadedEventImage({required this.path, required this.publicUrl});
}
