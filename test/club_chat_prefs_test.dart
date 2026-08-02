import 'package:flutter_application_1/services/club_chat_prefs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('community presentation uses the fixed design', () {
    final prefs = ClubChatPrefs();

    expect(prefs.messageStyle, ClubMessageStyle.bubbles);
    expect(prefs.announcementEmphasis, ClubAnnouncementEmphasis.tinted);
    expect(prefs.showRoles, isTrue);
  });
}
