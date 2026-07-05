import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/comment.dart';
import '../models/news_post.dart';
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

  /// Comment creation is disabled app-wide. Keep this method as a no-op so
  /// older call sites and tests still compile while the feature is removed.
  Future<void> add({required NewsPost post, required String content}) async {
    return;
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
