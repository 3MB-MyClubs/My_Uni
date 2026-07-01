import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_application_1/screens/this_week_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/message_service.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/user_prefs_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester t, String name) async {
    await t.pump(const Duration(milliseconds: 350));
    await binding.takeScreenshot(name);
  }

  testWidgets('Date sheet — drag range-select and tap toggle both work',
      (tester) async {
    await messageService.initialize();
    await userPrefsService.initialize();
    await contentStore.initialize();
    await themeService.initialize();
    contentStore.applyToLists();
    authService.login('htuncay23@ku.edu.tr');
    await themeService.setDark(false);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: ThisWeekScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();

    // Open the date filter pill to bring up the sheet.
    await tester.tap(find.text('Any date'));
    await tester.pump(const Duration(milliseconds: 400));
    await shot(tester, 'ds-01-opened');

    // Use offsets from the *next* Monday (not literal day-of-month strings,
    // and not "today+N") so the test doesn't depend on which real-world date
    // it happens to run on. Anchoring to a Monday guarantees Mon..Fri of that
    // week sit in a single calendar row, so a straight-line drag between them
    // can't be thrown off by a mid-drag row wrap.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thisWeekMonday = today.subtract(Duration(days: today.weekday - 1));
    final nextMonday = thisWeekMonday.add(const Duration(days: 7));
    String labelFor(int offsetDaysFromNextMonday) => nextMonday
        .add(Duration(days: offsetDaysFromNextMonday))
        .day
        .toString();

    Finder dayText(String d) => find.text(d);

    // Drag Monday->Friday of next week — should select every day the finger
    // crosses (drag range-select), not just the two endpoints.
    final startCenter = tester.getCenter(dayText(labelFor(0)).first);
    final endCenter = tester.getCenter(dayText(labelFor(4)).first);

    final gesture = await tester.startGesture(startCenter);
    await tester.pump(const Duration(milliseconds: 16));
    const steps = 60;
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      final pos = Offset.lerp(startCenter, endCenter, t)!;
      await gesture.moveTo(pos);
      await tester.pump(const Duration(milliseconds: 8));
    }
    // Sit at the end point briefly so the final cell is registered.
    await gesture.moveTo(endCenter);
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));
    await shot(tester, 'ds-02-after-drag-select');

    // Mon..Fri of next week (5 days) should now be selected. We can't read
    // the private sheet's state directly, so verify via the CTA label.
    expect(find.textContaining('selected'), findsOneWidget);
    String currentLabel() =>
        tester.widget<Text>(find.textContaining('selected').first).data ?? '';

    final afterDrag = currentLabel();
    debugPrint('LABEL AFTER DRAG: $afterDrag');
    expect(afterDrag.contains('5 selected'), true,
        reason:
            'drag across Mon..Fri should select 5 dates, got: $afterDrag');

    // Tap next Monday again — should deselect just that one cell (tap-toggle
    // still works independently of the drag handler).
    await tester.tap(dayText(labelFor(0)).first);
    await tester.pump(const Duration(milliseconds: 300));
    await shot(tester, 'ds-03-after-tap-toggle-off');
    final afterTapOff = currentLabel();
    debugPrint('LABEL AFTER TAP TOGGLE OFF: $afterTapOff');
    expect(afterTapOff.contains('4 selected'), true,
        reason:
            'tapping next Monday should deselect it, leaving 4, got: $afterTapOff');

    // Tap an unselected day (next Sunday) — should add it back via simple tap.
    await tester.tap(dayText(labelFor(6)).first);
    await tester.pump(const Duration(milliseconds: 300));
    await shot(tester, 'ds-04-after-tap-add');
    final afterTapOn = currentLabel();
    debugPrint('LABEL AFTER TAP ADD: $afterTapOn');
    expect(afterTapOn.contains('5 selected'), true,
        reason:
            'tapping next Sunday should add it, back to 5, got: $afterTapOn');
  });
}
