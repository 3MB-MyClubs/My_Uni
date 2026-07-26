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
    return _eventFromRow(data, fallback: event, uploadedImage: uploadedImage);
  }

  Future<Event> updateEvent(Event event, {String? previousImagePath}) async {
    final client = _client;
    if (client == null || !_looksLikeUuid(event.id)) return event;

    final uploadedImage = event.imagePath == null
        ? null
        : _isRemoteImageValue(event.imagePath!)
        ? null
        : await _uploadImage(clubId: event.clubId, imagePath: event.imagePath!);

    final payload = <String, dynamic>{
      'title': event.title,
      'description': event.description,
      'location': event.location,
      'event_date': _dateOnly(event.dateTime),
      'starts_at': event.dateTime.toUtc().toIso8601String(),
      'ends_at': event.endTime.toUtc().toIso8601String(),
      'tags': event.tags,
      'registration_url': event.registrationUrl,
      'schedule': event.schedule?.map((slot) => slot.toMap()).toList(),
      'speakers': event.speakers.map((speaker) => speaker.toMap()).toList(),
    };
    if (uploadedImage != null) {
      payload['image_path'] = uploadedImage.path;
      payload['image_url'] = uploadedImage.publicUrl;
    } else if (event.imagePath == null || event.imagePath!.trim().isEmpty) {
      payload['image_path'] = null;
      payload['image_url'] = null;
    }

    final row = await client
        .from('events')
        .update(payload)
        .eq('id', event.id)
        .select(
          'id, club_id, title, description, location, event_date, starts_at, ends_at, image_path, image_url, created_by_user_id, tags, registration_url, schedule, speakers',
        )
        .single();

    if (uploadedImage != null && previousImagePath != uploadedImage.publicUrl) {
      await _deleteStoredImage(previousImagePath);
    }

    final data = Map<String, dynamic>.from(row);
    return _eventFromRow(data, fallback: event, uploadedImage: uploadedImage);
  }

  Future<void> deleteEvent(Event event) async {
    final client = _client;
    if (client == null || !_looksLikeUuid(event.id)) return;

    await client.from('events').delete().eq('id', event.id);
    await _deleteStoredImage(event.imagePath);
  }

  Event _eventFromRow(
    Map<String, dynamic> data, {
    required Event fallback,
    _UploadedEventImage? uploadedImage,
  }) {
    return Event(
      id: data['id']?.toString() ?? fallback.id,
      clubId: data['club_id']?.toString() ?? fallback.clubId,
      title: data['title']?.toString() ?? fallback.title,
      description: data['description']?.toString() ?? fallback.description,
      location: data['location']?.toString() ?? fallback.location,
      dateTime: tryParseEventDateTime(data['starts_at']) ?? fallback.dateTime,
      endTime: tryParseEventDateTime(data['ends_at']) ?? fallback.endTime,
      attendeeUserIds: fallback.attendeeUserIds,
      rsvpTimestamps: fallback.rsvpTimestamps,
      imagePath:
          data['image_url']?.toString() ??
          uploadedImage?.publicUrl ??
          _publicUrlForObjectPath(data['image_path']?.toString()),
      createdByUserId:
          data['created_by_user_id']?.toString() ?? fallback.createdByUserId,
      tags: _stringList(data['tags']),
      schedule: _scheduleFromRaw(data['schedule']) ?? fallback.schedule,
      registrationUrl:
          data['registration_url']?.toString() ?? fallback.registrationUrl,
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

  String? _publicUrlForObjectPath(String? imagePath) {
    final client = _client;
    final value = imagePath?.trim() ?? '';
    if (value.isEmpty) return null;
    if (_isRemoteImageValue(value) || client == null) return value;
    return client.storage.from(_imageBucket).getPublicUrl(value);
  }

  bool _isRemoteImageValue(String value) =>
      value.startsWith('http://') || value.startsWith('https://');

  Future<void> _deleteStoredImage(String? imagePath) async {
    final client = _client;
    final objectPath = _objectPathFromImageValue(imagePath);
    if (client == null || objectPath == null) return;

    try {
      await client.storage.from(_imageBucket).remove([objectPath]);
    } catch (_) {
      // Non-critical: the database row no longer points at this image.
    }
  }

  String? _objectPathFromImageValue(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;

    final bucketPrefix = '$_imageBucket/';
    if (text.startsWith(bucketPrefix)) {
      return text.substring(bucketPrefix.length);
    }
    if (!_isRemoteImageValue(text)) return text;

    final uri = Uri.tryParse(text);
    if (uri == null) return null;
    final segments = uri.pathSegments;
    final bucketIndex = segments.indexOf(_imageBucket);
    if (bucketIndex < 0 || bucketIndex + 1 >= segments.length) return null;
    return segments.skip(bucketIndex + 1).map(Uri.decodeComponent).join('/');
  }

  bool _looksLikeUuid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }
}

final supabaseEventService = SupabaseEventService();

class _UploadedEventImage {
  final String path;
  final String publicUrl;

  const _UploadedEventImage({required this.path, required this.publicUrl});
}
