import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_application_1/services/user_profile_link.dart';
import 'package:flutter_application_1/widgets/user_profile_link_text.dart';

Iterable<TextSpan> _textSpans(InlineSpan span) sync* {
  if (span is! TextSpan) return;
  yield span;
  for (final child in span.children ?? const <InlineSpan>[]) {
    yield* _textSpans(child);
  }
}

void main() {
  group('UserProfileLink', () {
    test('builds a stable id-based deep link', () {
      const userId = '9df43e3c-45aa-4fb8-84be-739da815a5b7';

      final link = UserProfileLink.build(userId);

      expect(link, 'kuclubs://user/$userId');
      expect(UserProfileLink.userIdentifierFrom(link), userId);
    });

    test('recognises legacy handles and leaves sentence punctuation plain', () {
      const text = 'Meet Elif: kuclubs://user/elifd. Say hello!';

      final matches = UserProfileLink.matchesIn(text);

      expect(matches, hasLength(1));
      expect(matches.single.link, 'kuclubs://user/elifd');
      expect(matches.single.userIdentifier, 'elifd');
      expect(text.substring(matches.single.end), '. Say hello!');
      expect(UserProfileLink.isStandalone(text, matches.single), isFalse);
      expect(
        UserProfileLink.isStandalone(
          ' \n${matches.single.link}\t',
          matches.single,
        ),
        isTrue,
      );
    });

    test(
      'resolves id links and older handle links to the shared user',
      () async {
        final person = User(
          id: 'shared-profile-id',
          name: 'Elif Demir',
          email: 'elif@ku.edu.tr',
          password: '',
          role: 'student',
          subscribedClubIds: const [],
        );
        users.add(person);
        userState.setUsername(person.id, 'elifd');
        addTearDown(() {
          users.remove(person);
          userState.usernames.remove(person.id);
        });

        expect(await resolveUserProfileLink(person.id), same(person));
        expect(await resolveUserProfileLink('elifd'), same(person));
      },
    );
  });

  testWidgets('renders a user link as tappable message text', (tester) async {
    const link = 'kuclubs://user/u6';
    String? tappedIdentifier;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserProfileLinkText(
            text: 'Shared profile\n$link',
            style: const TextStyle(color: Colors.black),
            linkStyle: const TextStyle(
              color: Colors.red,
              decoration: TextDecoration.underline,
            ),
            onUserLinkTap: (identifier) => tappedIdentifier = identifier,
          ),
        ),
      ),
    );

    final richText = tester.widget<RichText>(find.byType(RichText));
    final rootSpan = richText.text as TextSpan;
    final linkSpan = _textSpans(
      rootSpan,
    ).singleWhere((span) => span.text == link);

    expect(linkSpan.style?.color, Colors.red);
    expect(linkSpan.recognizer, isA<TapGestureRecognizer>());
    (linkSpan.recognizer! as TapGestureRecognizer).onTap!();
    expect(tappedIdentifier, 'u6');
  });
}
