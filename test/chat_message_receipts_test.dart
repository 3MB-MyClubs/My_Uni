import 'package:flutter_application_1/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'group status advances only after every recipient reaches each state',
    () {
      final now = DateTime(2026, 8, 4, 12);
      ChatMessage messageWith(List<MessageReceipt> receipts) => ChatMessage(
        id: 'message-1',
        threadId: 'group:group-1',
        senderId: 'sender',
        content: 'Hello group',
        createdAt: now,
        receipts: receipts,
      );

      const members = ['sender', 'recipient-1', 'recipient-2'];
      expect(
        messageWith(const []).groupStatusForMembers(members),
        MessageDeliveryStatus.sent,
      );
      expect(
        messageWith([
          MessageReceipt(userId: 'recipient-1', deliveredAt: now),
        ]).groupStatusForMembers(members),
        MessageDeliveryStatus.sent,
      );
      expect(
        messageWith([
          MessageReceipt(userId: 'recipient-1', deliveredAt: now),
          MessageReceipt(userId: 'recipient-2', deliveredAt: now),
        ]).groupStatusForMembers(members),
        MessageDeliveryStatus.delivered,
      );
      expect(
        messageWith([
          MessageReceipt(userId: 'recipient-1', deliveredAt: now, seenAt: now),
          MessageReceipt(userId: 'recipient-2', deliveredAt: now),
        ]).groupStatusForMembers(members),
        MessageDeliveryStatus.delivered,
      );
      expect(
        messageWith([
          MessageReceipt(userId: 'recipient-1', deliveredAt: now, seenAt: now),
          MessageReceipt(userId: 'recipient-2', deliveredAt: now, seenAt: now),
        ]).groupStatusForMembers(members),
        MessageDeliveryStatus.seen,
      );
    },
  );
}
