import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/comment.dart';
import '../models/news_post.dart';
import 'auth_service.dart';
import 'club_notification_service.dart';
import 'content_store.dart';
import 'mock_data.dart';
import 'supabase_interaction_service.dart';

/// Central comment state store.
///
/// Mirrors RSVP/like behavior: optimistic local update first, Supabase write
/// in the background, and local rollback if the Supabase write fails. Comments
/// on seed content (non-UUID post ids) stay local-only by design.
class CommentStore extends ChangeNotifier {
  final Set<String> _hydratedPostIds = {};

  static final _uuidRe = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  bool _looksLikeUuid(String value) => _uuidRe.hasMatch(value);

  List<Comment> commentsFor(String postId) =>
      comments.where((c) => c.postId == postId).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  int countFor(String postId) =>
      comments.where((c) => c.postId == postId).length;

  /// Merges remote comments for [postId] over the local list (once per post
  /// per session; pass [force] to refresh).
  Future<void> hydrate(String postId, {bool force = false}) async {
    if (!force && _hydratedPostIds.contains(postId)) return;
    _hydratedPostIds.add(postId);
    if (!_looksLikeUuid(postId)) return;

    try {
      final remote = await supabaseInteractionService.fetchComments(postId);
      if (remote.isEmpty) return;
      final localIds = comments.map((c) => c.id).toSet();
      var added = false;
      for (final comment in remote) {
        if (localIds.contains(comment.id)) continue;
        comments.add(comment);
        added = true;
      }
      if (added) {
        unawaited(contentStore.saveComments());
        notifyListeners();
      }
    } catch (error) {
      debugPrint('Comment hydrate failed for $postId: $error');
      _hydratedPostIds.remove(postId);
    }
  }

  /// Optimistically adds a comment; Supabase write in the background with the
  /// local row swapped for the server row (or kept local-only on failure).
  Future<void> add({required NewsPost post, required String content}) async {
    final trimmed = content.trim();
    final userId =
        authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
    if (trimmed.isEmpty || userId.isEmpty) return;

    final local = Comment(
      id: 'local_${DateTime.now().microsecondsSinceEpoch}_$userId',
      postId: post.id,
      userId: userId,
      content: trimmed,
      createdAt: DateTime.now(),
    );
    comments.add(local);
    unawaited(contentStore.saveComments());
    notifyListeners();

    clubNotificationService.notifyClubAboutComment(
      post: post,
      actorUserId: userId,
    );

    // Seed posts / mock sessions can't be written remotely — stay local.
    if (!_looksLikeUuid(post.id) || !_looksLikeUuid(userId)) return;

    try {
      final remote = await supabaseInteractionService.addComment(
        postId: post.id,
        profileId: userId,
        content: trimmed,
      );
      if (remote == null) return;
      final idx = comments.indexWhere((c) => c.id == local.id);
      if (idx != -1) comments[idx] = remote;
      unawaited(contentStore.saveComments());
      notifyListeners();
    } catch (error) {
      debugPrint('Comment supabase write failed: $error');
      comments.removeWhere((c) => c.id == local.id);
      unawaited(contentStore.saveComments());
      notifyListeners();
    }
  }

  /// Removes a comment locally and remotely (best-effort).
  Future<void> remove(Comment comment) async {
    comments.removeWhere((c) => c.id == comment.id);
    unawaited(contentStore.saveComments());
    notifyListeners();

    if (!_looksLikeUuid(comment.id)) return;
    try {
      await supabaseInteractionService.deleteComment(comment.id);
    } catch (error) {
      debugPrint('Comment supabase delete failed: $error');
    }
  }
}

final commentStore = CommentStore();
