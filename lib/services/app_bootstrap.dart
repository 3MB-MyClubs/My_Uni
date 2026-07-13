/// Handle to the deferred part of app startup.
///
/// The first screen is always Login, which needs only the theme and locale
/// boxes to paint — the remaining Hive boxes open in the background after
/// runApp. Anything that reads those boxes must `await appBootstrap.ready`
/// first (the post-frame hydration in main.dart, and the login / club-admin
/// submit handlers — a login's network round-trip dwarfs the wait).
class AppBootstrap {
  Future<void> ready = Future.value();
}

final appBootstrap = AppBootstrap();
