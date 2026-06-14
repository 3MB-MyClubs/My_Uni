import 'package:flutter/foundation.dart';

/// Lightweight presence layer for the messaging experience.
///
/// The prototype messaging design shows rich presence — "online now" dots,
/// live "typing…" indicators and "last seen" labels. The app has no real
/// presence backend, so this singleton supplies deterministic mock online
/// state plus a *live* typing set that the chat screens drive when they
/// simulate an incoming reply. Both the inbox and the open thread listen to
/// it, so a peer that starts "typing" lights up everywhere at once.
class PresenceService extends ChangeNotifier {
  /// Demo set of people who are "online now" (stable across a session).
  final Set<String> onlineUserIds = {'u1', 'u3', 'u6', 'u8', 'u11', 'u14'};

  /// Conversation peers currently showing a live typing indicator.
  /// Keyed by the peer id used to open the thread (userId / clubId / groupId).
  final Set<String> _typing = {};

  static const List<String> _lastSeenLabels = [
    '2h ago',
    'yesterday',
    '3h ago',
    'just now',
    '1d ago',
    '5h ago',
    '30m ago',
  ];

  bool isOnline(String id) => onlineUserIds.contains(id);

  bool isTyping(String id) => _typing.contains(id);

  /// Deterministic "last seen" label for an offline peer.
  String lastSeenFor(String id) =>
      _lastSeenLabels[id.hashCode.abs() % _lastSeenLabels.length];

  void startTyping(String id) {
    if (_typing.add(id)) notifyListeners();
  }

  void stopTyping(String id) {
    if (_typing.remove(id)) notifyListeners();
  }

  /// Removes a typing flag WITHOUT notifying — safe to call from a widget's
  /// dispose(), where a still-mounted listener must not rebuild mid-teardown.
  void clearTypingQuietly(String id) => _typing.remove(id);
}

final presenceService = PresenceService();

/// Stores emoji reactions on individual messages, keyed by message id.
/// Long-pressing a bubble in any conversation writes here and every bubble
/// listening rebuilds with its reaction chip.
class ReactionStore extends ChangeNotifier {
  final Map<String, String> _reactions = {};

  /// Common reactions offered in the picker.
  static const List<String> palette = ['❤️', '👍', '😂', '🎉', '😮', '😢'];

  String? reactionFor(String messageId) => _reactions[messageId];

  /// Sets (or with the same emoji, clears) the reaction on [messageId].
  void toggleReaction(String messageId, String emoji) {
    if (_reactions[messageId] == emoji) {
      _reactions.remove(messageId);
    } else {
      _reactions[messageId] = emoji;
    }
    notifyListeners();
  }

  void clearReaction(String messageId) {
    if (_reactions.remove(messageId) != null) notifyListeners();
  }
}

final reactionStore = ReactionStore();
