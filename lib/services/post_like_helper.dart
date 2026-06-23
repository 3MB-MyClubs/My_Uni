import 'dart:async';

import '../models/like.dart';
import '../models/news_post.dart';
import 'auth_service.dart';
import 'club_notification_service.dart';
import 'content_store.dart';
import 'mock_data.dart';
import 'supabase_interaction_service.dart';
import 'user_state.dart';

Future<void> togglePostLike(String postId) async {
  final userId = authService.currentUser?.id ?? authService.currentAdmin?.id;
  if (userId == null || userId.isEmpty || postId.isEmpty) return;

  final wasLiked = userState.isLiked(postId);
  final previousCount = supabasePostLikeCounts[postId];

  userState.toggleLike(postId);
  if (previousCount != null) {
    supabasePostLikeCounts[postId] = (previousCount + (wasLiked ? -1 : 1))
        .clamp(0, 1 << 31);
  }

  if (wasLiked) {
    likes.removeWhere((like) => like.postId == postId && like.userId == userId);
  } else {
    likes.add(
      Like(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        postId: postId,
        userId: userId,
      ),
    );
  }
  unawaited(contentStore.saveLikes());

  try {
    final studentUserId = authService.currentUser?.id;
    if (studentUserId != null && studentUserId.isNotEmpty) {
      await supabaseInteractionService.setPostLiked(
        profileId: studentUserId,
        postId: postId,
        liked: !wasLiked,
      );
      if (!wasLiked) {
        NewsPost? post;
        for (final candidate in newsPosts) {
          if (candidate.id == postId) {
            post = candidate;
            break;
          }
        }
        if (post != null) {
          clubNotificationService.notifyClubAboutPostLike(
            post: post,
            actorUserId: studentUserId,
          );
        }
      }
    }
  } catch (_) {
    userState.toggleLike(postId);
    if (previousCount != null) {
      supabasePostLikeCounts[postId] = previousCount;
    }
    if (wasLiked) {
      likes.add(
        Like(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          postId: postId,
          userId: userId,
        ),
      );
    } else {
      likes.removeWhere(
        (like) => like.postId == postId && like.userId == userId,
      );
    }
    unawaited(contentStore.saveLikes());
  }
}

Future<void> ensurePostLiked(String postId) async {
  if (userState.isLiked(postId)) return;
  await togglePostLike(postId);
}
