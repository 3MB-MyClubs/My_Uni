import 'runtime_environment_stub.dart'
    if (dart.library.io) 'runtime_environment_io.dart';

bool get isFlutterTestHost => platformIsFlutterTestHost;
