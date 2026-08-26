import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/screens/explore_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/locale_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/people_service.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_application_1/widgets/user_avatar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const signedInId = 'recommendation-animation-viewer';
  const peerIds = [
    'recommendation-animation-peer-1',
    'recommendation-animation-peer-2',
    'recommendation-animation-peer-3',
    'recommendation-animation-peer-4',
  ];

  setUp(() async {
    authService.logout();
    await localeService.setLanguage('en');

    users.add(
      User(
        id: signedInId,
        name: 'Animation Viewer',
        email: 'animation.viewer@ku.edu.tr',
        password: '135790',
        role: 'student',
        subscribedClubIds: [],
      ),
    );
    for (var i = 0; i < peerIds.length; i++) {
      peopleService.cacheRegisteredUser(
        User(
          id: peerIds[i],
          name: 'Suggested Student ${i + 1}',
          email: 'suggested.student.${i + 1}@ku.edu.tr',
          password: '',
          role: 'student',
          subscribedClubIds: const [],
        ),
      );
    }

    expect(authService.login('animation.viewer@ku.edu.tr', '135790'), isTrue);
    userState.replaceFollowedClubs(const []);
    userState.replaceFollowedUsers(const []);
  });

  tearDown(() {
    authService.logout();
    userState.replaceFollowedClubs(const []);
    userState.replaceFollowedUsers(const []);
    users.removeWhere((user) => user.id == signedInId);
  });

  testWidgets(
    'explicit scope is exclusive and reset restores unified search',
    (tester) async {
      final scopeClub = Club(
        id: 'scope-only-club',
        name: 'Suggested Student Club',
        description: '',
        adminUserIds: const [],
      );
      clubs.add(scopeClub);
      supabaseClubMemberCounts[scopeClub.id] = 25;
      addTearDown(() {
        clubs.removeWhere((club) => club.id == scopeClub.id);
        supabaseClubMemberCounts.remove(scopeClub.id);
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ExploreScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byKey(const ValueKey('search-filter-button')));
      await tester.pumpAndSettle();

      final resetButton = find.byKey(
        const ValueKey('clear-people-major-filter'),
      );
      expect(resetButton, findsOneWidget);
      final resetSemantics = tester.widget<Semantics>(
        find
            .descendant(of: resetButton, matching: find.byType(Semantics))
            .first,
      );
      expect(resetSemantics.properties.button, isTrue);

      await tester.tap(find.byKey(const ValueKey('search-scope-students')));
      await tester.tap(find.byKey(const ValueKey('search-filters-apply')));
      await tester.pumpAndSettle();

      expect(find.text(scopeClub.name), findsNothing);
      for (var i = 0; i < peerIds.length; i++) {
        expect(find.text('Suggested Student ${i + 1}'), findsOneWidget);
      }

      await tester.enterText(find.byType(TextField), 'Suggested Student 1');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('search-filter-button')));
      await tester.pumpAndSettle();
      await tester.tap(resetButton);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('search-discovery-list')),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        '',
      );
      expect(find.text(scopeClub.name), findsOneWidget);
      expect(find.text('Trending Clubs'), findsOneWidget);
      expect(find.text('Suggested Profiles'), findsOneWidget);
      expect(find.byType(UserAvatar), findsWidgets);

      // Reset returns to an unscoped directory search: one query must search
      // both club names and student profile names.
      await tester.enterText(find.byType(TextField), 'Suggested Student');
      await tester.pump();

      expect(
        find.byKey(const ValueKey('combined-search-results')),
        findsOneWidget,
      );
      expect(find.text(scopeClub.name), findsOneWidget);
      expect(find.text('Suggested Student 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'club discovery includes joined clubs and defaults to member order',
    (tester) async {
      final rankedClubs = [
        for (var i = 0; i < 6; i++)
          Club(
            id: 'member-ranked-club-$i',
            name: 'Member Ranked Club ${i + 1}',
            description: '',
            adminUserIds: const [],
          ),
      ];
      clubs.addAll(rankedClubs);
      for (var i = 0; i < rankedClubs.length; i++) {
        supabaseClubMemberCounts[rankedClubs[i].id] = 600 - (i * 100);
      }
      userState.joinClub(rankedClubs.first.id);

      addTearDown(() {
        clubs.removeWhere((club) => club.id.startsWith('member-ranked-club-'));
        for (final club in rankedClubs) {
          supabaseClubMemberCounts.remove(club.id);
        }
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ExploreScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      for (final club in rankedClubs) {
        expect(find.text(club.name), findsOneWidget);
      }

      final firstPosition = tester.getTopLeft(find.text(rankedClubs[0].name));
      final secondPosition = tester.getTopLeft(find.text(rankedClubs[1].name));
      final thirdPosition = tester.getTopLeft(find.text(rankedClubs[2].name));
      final fourthPosition = tester.getTopLeft(find.text(rankedClubs[3].name));
      final fifthPosition = tester.getTopLeft(find.text(rankedClubs[4].name));
      final sixthPosition = tester.getTopLeft(find.text(rankedClubs[5].name));

      expect(firstPosition.dx, lessThan(secondPosition.dx));
      expect(secondPosition.dx, lessThan(thirdPosition.dx));
      expect(fourthPosition.dy, greaterThan(firstPosition.dy));
      expect(fourthPosition.dy, lessThan(fifthPosition.dy));
      expect(fifthPosition.dy, lessThan(sixthPosition.dy));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a followed suggestion animates its replacement in the slot', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ExploreScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final slot = find.byKey(const ValueKey('suggested-profile-slot-0'));
    final stationarySlots = [
      find.byKey(const ValueKey('suggested-profile-slot-1')),
      find.byKey(const ValueKey('suggested-profile-slot-2')),
    ];
    expect(slot, findsOneWidget);
    for (final stationarySlot in stationarySlots) {
      expect(stationarySlot, findsOneWidget);
    }

    Set<String> recommendationKeys(Finder targetSlot) {
      return find
          .descendant(
            of: targetSlot,
            matching: find.byWidgetPredicate((widget) {
              final key = widget.key;
              return key is ValueKey<String> &&
                  key.value.startsWith('suggested-profile-') &&
                  !key.value.startsWith('suggested-profile-slot-');
            }),
          )
          .evaluate()
          .map((element) => (element.widget.key! as ValueKey<String>).value)
          .toSet();
    }

    final originalKeys = recommendationKeys(slot);
    final stationaryKeys = [
      for (final stationarySlot in stationarySlots)
        recommendationKeys(stationarySlot),
    ];
    expect(originalKeys, hasLength(1));

    final originalId = originalKeys.single.replaceFirst(
      'suggested-profile-',
      '',
    );
    userState.toggleFollowUser(originalId);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    final transitioningKeys = recommendationKeys(slot);
    expect(transitioningKeys, hasLength(2));
    expect(transitioningKeys, containsAll(originalKeys));
    for (var i = 0; i < stationarySlots.length; i++) {
      expect(recommendationKeys(stationarySlots[i]), stationaryKeys[i]);
    }

    await tester.pump(const Duration(milliseconds: 240));
    final settledKeys = recommendationKeys(slot);
    expect(settledKeys, hasLength(1));
    expect(settledKeys, isNot(equals(originalKeys)));
    expect(tester.takeException(), isNull);
  });
}
