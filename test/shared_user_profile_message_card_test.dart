import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_application_1/widgets/shared_user_profile_message_card.dart';

void main() {
  testWidgets('shows a brief profile and opens the shared user', (
    tester,
  ) async {
    const userId = 'shared-card-user';
    final user = User(
      id: userId,
      name: 'Elif Demir',
      email: 'elif.demir@ku.edu.tr',
      password: '',
      role: 'student',
      subscribedClubIds: const [],
    );
    userState.setUsername(userId, 'elifd');
    userState.setMajor(userId, 'Computer Engineering');
    userState.setYear(userId, '3rd Year');
    userState.setBio(userId, 'Rooftop regular and vinyl collector.');
    addTearDown(() {
      userState.usernames.remove(userId);
      userState.majors.remove(userId);
      userState.years.remove(userId);
      userState.bios.remove(userId);
    });
    String? openedIdentifier;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SharedUserProfileMessageCard(
              userIdentifier: userId,
              resolveUser: (_) async => user,
              onOpenProfile: (identifier) {
                openedIdentifier = identifier;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final card = find.byKey(const ValueKey('shared-user-card-$userId'));
    expect(card, findsOneWidget);
    expect(find.text('Elif Demir'), findsOneWidget);
    expect(
      find.text('@elifd · Computer Engineering · 3rd Year'),
      findsOneWidget,
    );
    expect(find.text('Rooftop regular and vinyl collector.'), findsOneWidget);

    await tester.tap(card);
    expect(openedIdentifier, userId);
  });
}
