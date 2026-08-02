import 'dart:io' show Platform;

bool get platformIsFlutterTestHost =>
    Platform.environment['FLUTTER_TEST'] == 'true';
