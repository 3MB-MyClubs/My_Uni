import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/news_post.dart';
import 'content_safety_service.dart';
import 'lazy_content_loader.dart';
import 'original_media_bytes.dart';
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

    final result = Map<String, dynamic>.from(
      await client.rpc<Map<String, dynamic>>(
        'delete_club_post_transactional_v2',
        params: {'p_post_id': post.id, 'p_club_id': post.clubId},
      ),
    );
    if (result['deleted'] != true) {
      throw StateError('Post was not deleted.');
    }
    await _finishQueuedCleanup(
      cleanupId: result['cleanup_id']?.toString(),
      objectPath: result['cleanup_path']?.toString(),
    );
    lazyContentLoader.invalidateContent();
    supabaseInteractionService.invalidatePostCaches(post.id);
  }

  Future<NewsPost> createPost({
    String? reservedPostId,
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

    final postId = reservedPostId != null && _looksLikeUuid(reservedPostId)
        ? reservedPostId
        : const Uuid().v4();
    final uploadedImage = imagePath == null
        ? null
        : await _uploadImage(
            clubId: clubId,
            postId: postId,
            imagePath: imagePath,
          );
    dynamic response;
    try {
      response = await client
          .rpc(
            'create_club_post_transactional_v2',
            params: {
              'p_post_id': postId,
              'p_club_id': clubId,
              'p_content': content,
              'p_image_path': uploadedImage?.path,
              'p_image_url': uploadedImage?.publicUrl,
              'p_is_announcement': isAnnouncement,
              'p_mentioned_user_ids': taggedUserIds,
              'p_poll_question': poll?.question,
              'p_poll_options': poll?.options,
            },
          )
          .single();
    } catch (error, stackTrace) {
      if (uploadedImage != null) {
        await _registerAbandonedUpload(
          clubId: clubId,
          postId: postId,
          objectPath: uploadedImage.path,
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
    final row = Map<String, dynamic>.from(response);

    final data = row;
    final savedPostId = data['id']?.toString() ?? postId;

    lazyContentLoader.invalidateContent();

    return NewsPost(
      id: savedPostId,
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
    required String postId,
    required String imagePath,
  }) async {
    final client = _client;
    if (client == null) {
      return _UploadedPostImage(path: imagePath, publicUrl: imagePath);
    }

    final file = File(imagePath);
    final bytes = await readCanonicalMediaBytes(file);
    final objectPath = 'club_posts/$clubId/$postId/cover.jpg';

    await client.storage
        .from(_imageBucket)
        .uploadBinary(
          objectPath,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
            cacheControl: '31536000',
          ),
        );

    return _UploadedPostImage(
      path: objectPath,
      publicUrl: client.storage.from(_imageBucket).getPublicUrl(objectPath),
    );
  }

  Future<void> _registerAbandonedUpload({
    required String clubId,
    required String postId,
    required String objectPath,
  }) async {
    try {
      await _client?.rpc(
        'register_abandoned_content_upload_v2',
        params: {
          'p_bucket_id': _imageBucket,
          'p_object_path': objectPath,
          'p_entity_type': 'post',
          'p_entity_id': postId,
          'p_club_id': clubId,
        },
      );
    } catch (_) {
      // The stable path makes a later retry reuse the same object. The orphan
      // sweeper can also rediscover it without creating another object.
    }
  }

  Future<void> _finishQueuedCleanup({
    required String? cleanupId,
    required String? objectPath,
  }) async {
    final client = _client;
    if (client == null || cleanupId == null || objectPath == null) return;
    try {
      await client.storage.from(_imageBucket).remove([objectPath]);
      await client.rpc(
        'complete_storage_cleanup_v2',
        params: {'p_cleanup_id': cleanupId},
      );
    } catch (_) {
      // Database deletion is authoritative; the durable queue retries Storage.
    }
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
