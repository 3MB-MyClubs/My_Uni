import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/news_post.dart';
import 'content_safety_service.dart';
import 'auth_service.dart';
import 'lazy_content_loader.dart';
import 'supabase_config.dart';
import 'supabase_interaction_service.dart';

class SupabasePostService {
  static const _imageBucket = 'post-images';

  SupabaseClient? get _client {
    if (!SupabaseConfig.isConfigured) return null;
    return Supabase.instance.client;
  }

  bool get isAvailable => _client != null;

  Future<void> deletePost(NewsPost post) async {
    final client = _client;
    if (client == null || !_looksLikeUuid(post.id)) return;

    final deletedRows = await client
        .from('club_posts')
        .delete()
        .eq('id', post.id)
        .select('id');
    if (deletedRows.isEmpty) {
      throw StateError('Post was not deleted.');
    }
    await _deleteStoredImage(post.imagePath);
    lazyContentLoader.invalidateContent();
    supabaseInteractionService.invalidatePostCaches(post.id);
  }

  Future<NewsPost> createPost({
    required String clubId,
    required String authorId,
    required String content,
    required List<String> taggedClubIds,
    required List<String> taggedUserIds,
    String? imagePath,
    PollData? poll,
    bool isAnnouncement = false,
  }) async {
    final safetyMessage = contentSafetyService.rejectionMessage([
      content,
      if (poll != null) poll.question,
      if (poll != null) ...poll.options,
    ]);
    if (safetyMessage != null) throw ContentSafetyException(safetyMessage);

    final client = _client;
    if (client == null) {
      return _localPost(
        clubId: clubId,
        authorId: authorId,
        content: content,
        taggedClubIds: taggedClubIds,
        taggedUserIds: taggedUserIds,
        imagePath: imagePath,
        poll: poll,
        isAnnouncement: isAnnouncement,
      );
    }

    final uploadedImage = imagePath == null
        ? null
        : await _uploadImage(clubId: clubId, imagePath: imagePath);
    final payload = <String, dynamic>{'club_id': clubId, 'content': content};
    if (uploadedImage != null) {
      payload['image_path'] = uploadedImage.path;
      payload['image_url'] = uploadedImage.publicUrl;
    }
    // Linked club accounts are still authenticated student profiles, so their
    // actor can be recorded in `author_id`. Dedicated club-auth sessions use
    // an auth.users UUID that has no matching public.profiles row; attaching
    // that value would violate the nullable foreign key and reject the post.
    if (authService.isStudentSession && _looksLikeUuid(authorId)) {
      payload['author_id'] = authorId;
    }
    if (isAnnouncement) payload['is_announcement'] = true;

    final row = await client
        .from('club_posts')
        .insert(payload)
        .select(
          'id, club_id, author_id, content, image_path, image_url, created_at',
        )
        .single();

    final data = Map<String, dynamic>.from(row);
    final postId = data['id']?.toString() ?? '';

    if (poll != null && postId.isNotEmpty) {
      try {
        await client.from('polls').insert({
          'post_id': postId,
          'question': poll.question,
          'options': poll.options,
        });
      } catch (_) {
        // Poll table missing or offline — the poll still lives on the local
        // NewsPost and votes stay local.
      }
    }

    lazyContentLoader.invalidateContent();

    return NewsPost(
      id: postId,
      clubId: data['club_id']?.toString() ?? clubId,
      authorId: data['author_id']?.toString() ?? authorId,
      content: data['content']?.toString() ?? content,
      createdAt:
          DateTime.tryParse(data['created_at']?.toString() ?? '') ??
          DateTime.now(),
      taggedClubIds: taggedClubIds,
      taggedUserIds: taggedUserIds,
      imagePath:
          data['image_url']?.toString() ??
          uploadedImage?.publicUrl ??
          data['image_path']?.toString(),
      poll: poll,
      isAnnouncement: isAnnouncement,
    );
  }

  Future<_UploadedPostImage> _uploadImage({
    required String clubId,
    required String imagePath,
  }) async {
    final client = _client;
    if (client == null) {
      return _UploadedPostImage(path: imagePath, publicUrl: imagePath);
    }

    final file = File(imagePath);
    final bytes = await file.readAsBytes();
    final objectPath = 'club_posts/$clubId/${const Uuid().v4()}.jpg';

    await client.storage
        .from(_imageBucket)
        .uploadBinary(
          objectPath,
          bytes,
          fileOptions: const FileOptions(
            upsert: false,
            contentType: 'image/jpeg',
            cacheControl: '31536000',
          ),
        );

    return _UploadedPostImage(
      path: objectPath,
      publicUrl: client.storage.from(_imageBucket).getPublicUrl(objectPath),
    );
  }

  NewsPost _localPost({
    required String clubId,
    required String authorId,
    required String content,
    required List<String> taggedClubIds,
    required List<String> taggedUserIds,
    String? imagePath,
    PollData? poll,
    bool isAnnouncement = false,
  }) {
    return NewsPost(
      id: 'p_${DateTime.now().millisecondsSinceEpoch}',
      clubId: clubId,
      authorId: authorId,
      content: content,
      createdAt: DateTime.now(),
      taggedClubIds: taggedClubIds,
      taggedUserIds: taggedUserIds,
      imagePath: imagePath,
      poll: poll,
      isAnnouncement: isAnnouncement,
    );
  }

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
    if (!text.startsWith('http://') && !text.startsWith('https://')) {
      return text;
    }

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

final supabasePostService = SupabasePostService();

class _UploadedPostImage {
  final String path;
  final String publicUrl;

  const _UploadedPostImage({required this.path, required this.publicUrl});
}
