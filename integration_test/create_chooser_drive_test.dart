import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_application_1/screens/main_nav_screen.dart';
import 'package:flutter_application_1/services/app_colors.dart';
import 'package:flutter_application_1/services/message_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';

/// The redesigned "Create" chooser a club admin sees from the central +.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Create chooser — copy + look', (tester) async {
    await messageService.initialize(); // initializes Hive for themeService
    await themeService.initialize();
    await themeService.setDark(true); // match the reported dark-mode screenshot

    var posted = false;
    var eventTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(
          backgroundColor: AppColors.background,
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showClubCreateSheet(
                  context,
                  onPost: () => posted = true,
                  onEvent: () => eventTapped = true,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 500));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('create-chooser');

    // New copy is present.
    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Update your community'), findsOneWidget);
    expect(find.text('Create something inspiring'), findsOneWidget);

    // Each option fires its callback and dismisses the sheet.
    await tester.tap(find.text('Post'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(posted, isTrue);
    expect(find.text('Update your community'), findsNothing); // sheet closed

    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Event'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(eventTapped, isTrue);

    expect(tester.takeException(), isNull);
  });
}
