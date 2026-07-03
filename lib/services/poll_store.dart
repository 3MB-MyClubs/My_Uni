import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/news_post.dart';
import 'supabase_interaction_service.dart';

/// Central poll-vote state store, keyed by post id.
///
/// Mirrors RSVP/like behavior: optimistic local vote first (Hive-persisted),
/// Supabase upsert in the background, rollback on failure. Votes on seed posts
/// (non-UUID ids) stay local.
class PollStore extends ChangeNotifier {
  static const _boxName = 'poll_votes_v1';

  /// postId → (voterId → optionIndex). Remote voters merge in on hydrate.
  final Map<String, Map<String, int>> _votes = {};
  final Set<String> _hydratedPostIds = {};
  Box<dynamic>? _box;

  static final _uuidRe = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  bool _looksLikeUuid(String value) => _uuidRe.hasMatch(value);

  Future<void> initialize() async {
    if (_box != null) return;
    _box = await Hive.openBox<dynamic>(_boxName);
    final raw = _box!.get('votes');
    if (raw is Map) {
      _votes.clear();
      raw.forEach((postId, voters) {
        _votes[postId.toString()] = {
          for (final e in (voters as Map).entries)
            e.key.toString(): e.value as int,
        };
      });
      notifyListeners();
    }
  }

  void _save() {
    final box = _box;
    if (box == null) return;
    unawaited(
      box.put('votes', {
        for (final e in _votes.entries) e.key: Map<String, int>.from(e.value),
      }),
    );
  }

  int? myVote(String postId, String userId) => _votes[postId]?[userId];

  int totalVotes(String postId) => _votes[postId]?.length ?? 0;

  int votesForOption(String postId, int optionIndex) =>
      _votes[postId]?.values.where((v) => v == optionIndex).length ?? 0;

  /// Merges remote votes for [postId] (once per session; [force] refreshes).
  Future<void> hydrate(String postId, {bool force = false}) async {
    if (!force && _hydratedPostIds.contains(postId)) return;
    _hydratedPostIds.add(postId);
    if (!_looksLikeUuid(postId)) return;

    try {
      final remote = await supabaseInteractionService.fetchPollVotes(postId);
      if (remote.isEmpty) return;
      final local = _votes.putIfAbsent(postId, () => {});
      local.addAll(remote);
      _save();
      notifyListeners();
    } catch (error) {
      debugPrint('Poll hydrate failed for $postId: $error');
      _hydratedPostIds.remove(postId);
    }
  }

  /// Optimistically records (or changes) [userId]'s vote.
  Future<void> vote({
    required NewsPost post,
    required String userId,
    required int optionIndex,
  }) async {
    final options = post.poll?.options ?? const [];
    if (userId.isEmpty || optionIndex < 0 || optionIndex >= options.length) {
      return;
    }

    final voters = _votes.putIfAbsent(post.id, () => {});
    final previous = voters[userId];
    if (previous == optionIndex) return;
    voters[userId] = optionIndex;
    _save();
    notifyListeners();

    if (!_looksLikeUuid(post.id) || !_looksLikeUuid(userId)) return;
    try {
      await supabaseInteractionService.upsertPollVote(
        postId: post.id,
        profileId: userId,
        optionIndex: optionIndex,
      );
    } catch (error) {
      debugPrint('Poll vote supabase write failed: $error');
      if (previous == null) {
        voters.remove(userId);
      } else {
        voters[userId] = previous;
      }
      _save();
      notifyListeners();
    }
  }
}

final pollStore = PollStore();
