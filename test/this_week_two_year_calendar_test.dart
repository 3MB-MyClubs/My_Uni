import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/screens/this_week_screen.dart';

void main() {
  testWidgets('event date filter scrolls through two years', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ThisWeekScreen())),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('next month'), findsNothing);
    await tester.tap(find.text('Any date'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final now = DateTime.now();
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final endMonthLabel = '${monthNames[now.month - 1]} ${now.year + 2}';
    final calendar = find.byKey(
      const PageStorageKey('two-year-event-date-picker'),
    );
    final calendarScrollable = find
        .descendant(of: calendar, matching: find.byType(Scrollable))
        .first;

    expect(calendar, findsOneWidget);
    expect(calendarScrollable, findsOneWidget);
    var weekStart = DateTime(now.year, now.month, now.day + (8 - now.weekday));
    while (weekStart.add(const Duration(days: 6)).month != weekStart.month) {
      weekStart = weekStart.add(const Duration(days: 7));
    }
    final weekDates = List.generate(
      7,
      (index) => weekStart.add(Duration(days: index)),
    );
    final weekCells = [
      for (final date in weekDates)
        find.byKey(
          ValueKey('event-date-${date.year}-${date.month}-${date.day}'),
        ),
    ];
    await tester.ensureVisible(weekCells.first);
    await tester.pump();
    final drag = await tester.startGesture(tester.getCenter(weekCells.first));
    await drag.moveTo(
      tester.getCenter(weekCells.last),
      timeStamp: const Duration(milliseconds: 480),
    );
    await drag.up();
    await tester.pump();
    expect(find.text('Show events for 7 selected dates'), findsOneWidget);

    final scrollState = tester.state<ScrollableState>(calendarScrollable);
    scrollState.position.jumpTo(scrollState.position.maxScrollExtent);
    await tester.pump();

    expect(find.text(endMonthLabel), findsOneWidget);
  });
}
