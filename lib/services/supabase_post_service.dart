import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/news_post.dart';
import 'supabase_config.dart';

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

    await client.from('club_posts').delete().eq('id', post.id);
    await _deleteStoredImage(post.imagePath);
  }

  Future<NewsPost> createPost({
    required String clubId,
    required String authorId,
    required String content,
    required List<String> taggedClubIds,
    required List<String> taggedUserIds,
    String? imagePath,
  }) async {
    final client = _client;
    if (client == null) {
      return _localPost(
        clubId: clubId,
        authorId: authorId,
        content: content,
        taggedClubIds: taggedClubIds,
        taggedUserIds: taggedUserIds,
        imagePath: imagePath,
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

    final row = await client
        .from('club_posts')
        .insert(payload)
        .select('id, club_id, content, image_path, image_url, created_at')
        .single();

    final data = Map<String, dynamic>.from(row);
    return NewsPost(
      id: data['id']?.toString() ?? '',
      clubId: data['club_id']?.toString() ?? clubId,
      authorId: authorId,
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
    final objectPath =
        'club_posts/$clubId/${DateTime.now().millisecondsSinceEpoch}.jpg';

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
