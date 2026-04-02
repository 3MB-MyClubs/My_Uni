import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../models/message.dart';
import 'mock_data.dart';
import 'notification_service.dart';

class MessageService {
  static const String _boxName = 'messages';
  static const String _readBoxName = 'read_timestamps';
  late Box<Message> _messagesBox;
  late Box<int> _readBox;
  bool _initialized = false;
  String? _currentUserId;

  /// Initialize Hive and open the messages box
  Future<void> initialize() async {
    if (_initialized) return;

    final appDir = await getApplicationDocumentsDirectory();
    Hive.init(appDir.path);

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(MessageAdapter());
    }

    _messagesBox = await Hive.openBox<Message>(_boxName);
    _readBox = await Hive.openBox<int>(_readBoxName);
    _initialized = true;
  }

  /// Set the current user ID for notification filtering
  void setCurrentUserId(String userId) {
    _currentUserId = userId;
  }

  /// Get user name from ID
  String _getUserName(String userId) {
    try {
      final user = users.firstWhere((u) => u.id == userId);
      return user.name;
    } catch (e) {
      return 'Someone';
    }
  }

  /// Save a single message and show notification if it's from someone else
  Future<void> saveMessage(Message message) async {
    await _messagesBox.put(message.id, message);

    // Show notification if message is from someone else
    if (_currentUserId != null && message.senderId != _currentUserId) {
      final senderName = _getUserName(message.senderId);
      await notificationService.showMessageNotification(
        senderName: senderName,
        messageContent: message.content,
        senderId: message.senderId,
      );
    }
  }

  /// Get conversation between two users
  List<Message> getConversation(String userId1, String userId2) {
    final allMessages = _messagesBox.values.toList();
    return allMessages
        .where((m) =>
            (m.senderId == userId1 && m.receiverId == userId2) ||
            (m.senderId == userId2 && m.receiverId == userId1))
        .toList()
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
  }

  /// Get all messages
  List<Message> getAllMessages() {
    return _messagesBox.values.toList();
  }

  /// Mark a conversation as read for the given viewer up to now.
  Future<void> markAsRead(String viewerId, String otherId) async {
    final key = '${viewerId}_$otherId';
    await _readBox.put(key, DateTime.now().millisecondsSinceEpoch);
  }

  /// Returns true if there are unread messages from [senderId] for [receiverId].
  bool hasUnread(String receiverId, String senderId, List<Message> allMessages) {
    final key = '${receiverId}_$senderId';
    final lastReadMs = _readBox.get(key);
    final lastRead = lastReadMs != null
        ? DateTime.fromMillisecondsSinceEpoch(lastReadMs)
        : null;

    return allMessages.any((m) =>
        m.senderId == senderId &&
        m.receiverId == receiverId &&
        (lastRead == null || m.sentAt.isAfter(lastRead)));
  }

  /// Count of unread messages from [senderId] for [receiverId].
  int unreadCount(String receiverId, String senderId, List<Message> allMessages) {
    final key = '${receiverId}_$senderId';
    final lastReadMs = _readBox.get(key);
    final lastRead = lastReadMs != null
        ? DateTime.fromMillisecondsSinceEpoch(lastReadMs)
        : null;

    return allMessages.where((m) =>
        m.senderId == senderId &&
        m.receiverId == receiverId &&
        (lastRead == null || m.sentAt.isAfter(lastRead))).length;
  }

  /// Close the database (call on app shutdown)
  Future<void> close() async {
    await Hive.close();
  }

  /// Clear all messages (use with caution)
  Future<void> clearAll() async {
    await _messagesBox.clear();
  }
}

// Global instance
final messageService = MessageService();

