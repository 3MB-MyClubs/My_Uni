import 'dart:io';

/// Memoizes `File(path).existsSync()` for avatar builds.
///
/// Avatars check whether a locally-picked photo file still exists inside
/// build() — a blocking stat() syscall per avatar per rebuild in member lists
/// and feeds. Photo paths change only through UserState's photo setters, which
/// call [invalidate], so a cached answer stays correct.
class PhotoFileCache {
  final Map<String, bool> _exists = {};

  bool existsSync(String path) =>
      _exists.putIfAbsent(path, () => File(path).existsSync());

  void invalidate(String? path) {
    if (path != null) _exists.remove(path);
  }
}

final photoFileCache = PhotoFileCache();
