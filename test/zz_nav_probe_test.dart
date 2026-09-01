import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/app_admin.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/screens/main_nav_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final List<String> _errors = <String>[];

void _install() {
  FlutterError.onError = (details) {
    final buf = StringBuffer('EXC>> ${details.exceptionAsString()}');
    // toStringDeep() on these nodes dumps the whole render subtree and hangs
    // the test, so each node is flattened to one truncated line.
    for (final node
        in details.informationCollector?.call() ?? const <DiagnosticsNode>[]) {
      final line = node.toString().replaceAll('\n', ' ');
      buf.write('\n  >> ${line.length > 300 ? line.substring(0, 300) : line}');
    }
    final creator = details.context?.value;
    if (creator is List) {
      for (final entry in creator.take(14)) {
        final line = entry.toString().replaceAll('\n', ' ');
        buf.write('\n  CR ${line.length > 160 ? line.substring(0, 160) : line}');
      }
    }
    _errors.add(buf.toString());
  };
}

Widget _app(bool isAdmin) => ProviderScope(
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    darkTheme: ThemeData(brightness: Brightness.dark),
    themeMode: ThemeMode.dark,
    home: MainNavScreen(isAdmin: isAdmin),
  ),
);

void main() {
  testWidgets('desktop -> mobile transition, club admin', (tester) async {
    _errors.clear();
    _install();
    authService.logout();
    clubAdmins.add(
      AppAdmin(
        id: 'probe-admin',
        name: 'Probe Club',
        email: 'probe.club@ku.edu.tr',
        password: '11111111',
      ),
    );
    clubs.add(
      Club(
        id: 'probe-admin',
        name: 'Probe Club',
        description: 'probe',
        adminUserIds: const ['probe-admin'],
      ),
    );
    expect(authService.login('probe.club@ku.edu.tr', '11111111'), isTrue);
    addTearDown(authService.logout);
    addTearDown(() {
      clubAdmins.removeWhere((a) => a.id == 'probe-admin');
      clubs.removeWhere((c) => c.id == 'probe-admin');
    });

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_app(true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    debugPrint('=== after desktop mount: ${_errors.length}');

    tester.view.physicalSize = const Size(800, 600);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    debugPrint('=== after mobile resize: ${_errors.length}');
    if (_errors.isNotEmpty) debugPrint(_errors.join('\n'));

    // Report the measured bar geometry so any overflow can be traced by hand.
    final bar = find.byKey(const ValueKey<String>('mobile-bottom-navigation'));
    if (bar.evaluate().isNotEmpty) {
      debugPrint('=== bar size: ${tester.getSize(bar)}');
    }
    expect(_errors, isEmpty, reason: _errors.join('\n'));
  });
}
