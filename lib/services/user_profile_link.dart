import '../models/user.dart';
import 'auth_service.dart';
import 'mock_data.dart';
import 'people_service.dart';
import 'user_state.dart';

/// A user deep link found inside a larger block of message text.
class UserProfileLinkMatch {
  const UserProfileLinkMatch({
    required this.start,
    required this.end,
    required this.link,
    required this.userIdentifier,
  });

  final int start;
  final int end;
  final String link;
  final String userIdentifier;
}

/// Creates and recognises the in-app links used when a profile is shared.
abstract final class UserProfileLink {
  static final RegExp _candidatePattern = RegExp(
    r'kuclubs://user/[^\s<>\[\]{}]+',
    caseSensitive: false,
  );
  static final RegExp _trailingPunctuation = RegExp(r'[.,!?;:)]+$');

  /// Uses the stable profile id so a link works on another person's device.
  static String build(String userId) {
    final id = userId.trim();
    if (id.isEmpty) throw ArgumentError.value(userId, 'userId');
    return Uri(scheme: 'kuclubs', host: 'user', pathSegments: [id]).toString();
  }

  /// Returns the id (or the handle used by older links) encoded in [link].
  static String? userIdentifierFrom(String link) {
    final uri = Uri.tryParse(link);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'kuclubs' ||
        uri.host.toLowerCase() != 'user' ||
        uri.pathSegments.length != 1) {
      return null;
    }
    final identifier = uri.pathSegments.single.trim();
    return identifier.isEmpty ? null : identifier;
  }

  static List<UserProfileLinkMatch> matchesIn(String text) {
    final matches = <UserProfileLinkMatch>[];
    for (final candidate in _candidatePattern.allMatches(text)) {
      final raw = candidate.group(0)!;
      final link = raw.replaceFirst(_trailingPunctuation, '');
      final identifier = userIdentifierFrom(link);
      if (identifier == null) continue;
      matches.add(
        UserProfileLinkMatch(
          start: candidate.start,
          end: candidate.start + link.length,
          link: link,
          userIdentifier: identifier,
        ),
      );
    }
    return matches;
  }

  /// Whether [match] is the entire visible message, apart from whitespace.
  static bool isStandalone(String text, UserProfileLinkMatch match) =>
      text.trim() == match.link;
}

User? _knownUserById(String userId) {
  final currentUser = authService.currentUser;
  if (currentUser?.id == userId) return currentUser;
  for (final user in peopleService.cachedPeople) {
    if (user.id == userId) return user;
  }
  for (final user in users) {
    if (user.id == userId) return user;
  }
  return null;
}

/// Resolves both current id-based links and legacy handle-based links.
Future<User?> resolveUserProfileLink(String userIdentifier) async {
  final identifier = userIdentifier.trim();
  if (identifier.isEmpty) return null;

  final directMatch = _knownUserById(identifier);
  if (directMatch != null) return directMatch;

  final normalizedHandle = identifier.startsWith('@')
      ? identifier.substring(1).toLowerCase()
      : identifier.toLowerCase();
  for (final entry in userState.usernames.entries) {
    if (entry.value.toLowerCase() == normalizedHandle) {
      final handleMatch = _knownUserById(entry.key);
      if (handleMatch != null) return handleMatch;
      await peopleService.hydrateProfilesByIds([entry.key]);
      return _knownUserById(entry.key);
    }
  }

  // New links contain the profile id. Hydrate it directly so opening a link
  // does not depend on the recipient having visited the people directory.
  await peopleService.hydrateProfilesByIds([identifier]);
  return _knownUserById(identifier);
}
