import 'package:flutter/foundation.dart';

import 'group_chat_service.dart' show GroupMessage;
import 'mock_data.dart';

/// Joint discussion channels — one per club.
///
/// Unlike a 1-on-1 DM with a club account, this is a many-to-many channel where
/// every member of the club can talk together. Messages carry the real sender's
/// user id so the conversation renders with member names / avatars, exactly like
/// a group chat. Seeded with sample discussions for the demo user's clubs.
class ClubChatService extends ChangeNotifier {
  final Map<String, List<GroupMessage>> _byClub = {};
  // Last-read timestamp per club (ms since epoch) for unread badges.
  final Map<String, int> _readAt = {};

  ClubChatService() {
    _seed();
  }

  List<GroupMessage> messagesFor(String clubId) =>
      List.unmodifiable(_byClub[clubId] ?? const []);

  GroupMessage? lastMessageFor(String clubId) {
    final list = _byClub[clubId];
    return (list == null || list.isEmpty) ? null : list.last;
  }

  /// Everyone who belongs to the club: admins + board + subscribers, plus
  /// anyone who has posted in the channel.
  List<String> memberIdsFor(String clubId) {
    final ids = <String>{};
    for (final c in clubs) {
      if (c.id == clubId) {
        ids.addAll(c.adminUserIds);
        ids.addAll(c.boardMemberIds);
        break;
      }
    }
    for (final u in users) {
      if (u.subscribedClubIds.contains(clubId)) ids.add(u.id);
    }
    for (final m in _byClub[clubId] ?? const <GroupMessage>[]) {
      ids.add(m.senderId);
    }
    return ids.toList();
  }

  void addMessage(String clubId, GroupMessage message) {
    (_byClub[clubId] ??= []).add(message);
    notifyListeners();
  }

  void markRead(String clubId) {
    _readAt[clubId] = DateTime.now().millisecondsSinceEpoch;
  }

  /// Count of messages newer than the last read, not sent by [myId].
  int unreadCount(String clubId, String myId) {
    final list = _byClub[clubId];
    if (list == null || list.isEmpty) return 0;
    final readMs = _readAt[clubId];
    final readAt =
        readMs != null ? DateTime.fromMillisecondsSinceEpoch(readMs) : null;
    return list
        .where((m) =>
            m.senderId != myId &&
            (readAt == null || m.sentAt.isAfter(readAt)))
        .length;
  }

  GroupMessage _m(String id, String sender, String content, Duration ago) =>
      GroupMessage(
        id: id,
        senderId: sender,
        content: content,
        sentAt: DateTime.now().subtract(ago),
      );

  void _seed() {
    // — Bilgisayar Kulübü / KUACM (c4): Hack-KU team formation —
    _byClub['c4'] = [
      _m('cc4_1', 'u1', 'Who\'s forming teams for Hack-KU 2026? 🚀',
          const Duration(hours: 3, minutes: 10)),
      _m('cc4_2', 'u3',
          'I\'m in! Looking for a teammate who\'s solid on backend.',
          const Duration(hours: 3)),
      _m('cc4_3', 'u5', 'I can take backend — FastAPI mostly. Count me in 🙌',
          const Duration(hours: 2, minutes: 50)),
      _m('cc4_4', 'u2', 'I\'ll cover the frontend then. Flutter or React?',
          const Duration(hours: 2, minutes: 40)),
      _m('cc4_5', 'u5', 'kuphoto:hackku_2026_poster.png',
          const Duration(hours: 2, minutes: 20)),
      _m('cc4_6', 'u1',
          'Perfect, that\'s a full team! Mixer is Friday 18:00 in the ACM lab 🎉',
          const Duration(hours: 1, minutes: 30)),
    ];

    // — Fenerbahçeliler Topluluğu (c11): derbi watch party —
    _byClub['c11'] = [
      _m('cc11_1', 'u11',
          '📺 Derbi izleme etkinliği bu Cumartesi! Kim geliyor? 💛💙',
          const Duration(days: 1, hours: 4)),
      _m('cc11_2', 'u4', 'Ben varım! Saat kaçta başlıyor?',
          const Duration(days: 1, hours: 3, minutes: 50)),
      _m('cc11_3', 'u11', '19:00, Sosyal Tesisler salonu. Erken gelin 🔥',
          const Duration(days: 1, hours: 3, minutes: 40)),
      _m('cc11_4', 'u5', 'Geliyorum, ön sıralardan yer kapalım 💛💙',
          const Duration(days: 1, hours: 3, minutes: 20)),
      _m('cc11_5', 'u11', 'kuvoice:0:12',
          const Duration(days: 1, hours: 3)),
    ];

    // — Ebru Kulübü (c9): marbling workshop —
    _byClub['c9'] = [
      _m('cc9_1', 'u6', 'Bu haftaki ebru atölyesi için çok heyecanlıyım 🎨',
          const Duration(days: 2, hours: 5)),
      _m('cc9_2', 'u8', 'İlk kez deneyeceğim! Malzeme getirmemiz gerekiyor mu?',
          const Duration(days: 2, hours: 4, minutes: 45)),
      _m('cc9_3', 'u5', 'Aynı soru bende de vardı 😅',
          const Duration(days: 2, hours: 4, minutes: 30)),
      _m('cc9_4', 'u6', 'Hiçbir şey getirmenize gerek yok, hepsi kulüpte ✨',
          const Duration(days: 2, hours: 4)),
    ];

    // — KU Gönüllüleri (c22): playground painting day —
    _byClub['c22'] = [
      _m('cc22_1', 'u2',
          'Cumartesi oyun parkı boyama etkinliği! Buluşma 09:30 ana kapı 🖌️',
          const Duration(hours: 6)),
      _m('cc22_2', 'u5', 'Kaydoldum! Yanımda fırça getireyim mi?',
          const Duration(hours: 5, minutes: 40)),
      _m('cc22_3', 'u7', 'Ben de geliyorum, harika bir etkinlik olacak 💪',
          const Duration(hours: 5, minutes: 20)),
      _m('cc22_4', 'u2', 'Fırça getirmenize gerek yok, hepsi bizde 😄',
          const Duration(hours: 4, minutes: 50)),
    ];
  }
}

final clubChatService = ClubChatService();
