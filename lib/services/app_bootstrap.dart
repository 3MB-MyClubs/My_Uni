/// Handle to the deferred part of app startup.
///
/// The branded launch screen needs no plugin-backed state. Remaining Hive
/// boxes open after runApp; callers must await [ready] and check
/// [localDataReady] before using a box-backed service.
class AppBootstrap {
  Future<void> ready = Future.value();
  bool localDataReady = false;
}

final appBootstrap = AppBootstrap();
