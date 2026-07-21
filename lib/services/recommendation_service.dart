import 'package:flutter/widgets.dart' show Locale;

import '../l10n/app_localizations.dart';
import '../models/recommendation.dart';
import '../models/event.dart';
import '../models/club.dart';
import 'auth_service.dart';
import 'locale_service.dart';
import 'mock_data.dart';
import 'personalization_service.dart';
import 'user_state.dart';

class RecommendationService {
  // No BuildContext is available this deep in the service layer; these
  // recommendation reason/subtitle strings are resolved here via the
  // current locale.
  AppLocalizations get _l10n =>
      lookupAppLocalizations(Locale(localeService.languageCode));

  List<Recommendation>? _cached;
  DateTime? _cachedAt;

  // "Happening Now" is already only accurate to within minutes, so a short
  // TTL avoids rescanning events/clubs/users on every call (e.g. every
  // AdminDashboard/feed rebuild) without risking noticeably stale picks.
  static const _cacheTtl = Duration(seconds: 30);

  /// Returns up to three recommendations — one per slot:
  ///   1. Happening Now (live event)
  ///   2. Best for You This Week (scored upcoming event or club)
  ///   3. You Might Like (person or club to follow)
  List<Recommendation> getRecommendations() {
    final now = DateTime.now();
    final cached = _cached;
    final cachedAt = _cachedAt;
    if (cached != null &&
        cachedAt != null &&
        now.difference(cachedAt) < _cacheTtl) {
      return cached;
    }
    final result = _computeRecommendations();
    _cached = result;
    _cachedAt = now;
    return result;
  }

  List<Recommendation> _computeRecommendations() {
    final myId =
        authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
    final hidden = personalizationService.hiddenIds;
    final result = <Recommendation>[];

    final nowRec = _getHappeningNow(myId, hidden);
    if (nowRec != null) result.add(nowRec);

    final usedIds = {if (nowRec != null) nowRec.id};
    final weekRec = _getBestThisWeek(myId, hidden, usedIds);
    if (weekRec != null) result.add(weekRec);

    final allUsed = {for (final r in result) r.id};
    final followRec = _getSuggestFollow(myId, hidden, allUsed);
    if (followRec != null) result.add(followRec);

    return result;
  }

  // ── Slot 1: Happening Now ─────────────────────────────────────────────────

  Recommendation? _getHappeningNow(String myId, Set<String> hidden) {
    final now = DateTime.now();
    final live = events
        .where(
          (e) =>
              !hidden.contains(e.id) &&
              !e.dateTime.isAfter(now) &&
              e.endTime.isAfter(now),
        )
        .toList();

    if (live.isEmpty) return null;

    live.sort((a, b) => _scoreEvent(b).compareTo(_scoreEvent(a)));
    final top = live.first;
    final club = _clubFor(top.clubId);
    final isFollowing = userState.followedClubIds.contains(top.clubId);

    final reason = isFollowing
        ? _l10n.liveNowFollowingClub(_shortName(club.name))
        : _l10n.liveNowOnCampus;

    return Recommendation(
      type: RecType.happeningNow,
      targetType: RecTargetType.event,
      id: top.id,
      title: top.title,
      subtitle: _shortName(club.name),
      reason: reason,
      data: top,
    );
  }

  // ── Slot 2: Best for You This Week ────────────────────────────────────────

  Recommendation? _getBestThisWeek(
    String myId,
    Set<String> hidden,
    Set<String> exclude,
  ) {
    final now = DateTime.now();
    final weekEnd = now.add(const Duration(days: 7));

    final candidates = events
        .where(
          (e) =>
              !hidden.contains(e.id) &&
              !exclude.contains(e.id) &&
              e.dateTime.isAfter(now) &&
              e.dateTime.isBefore(weekEnd) &&
              !e.attendeeUserIds.contains(myId),
        )
        .toList();

    if (candidates.isEmpty) {
      return _getBestUnfollowedClub(myId, hidden, exclude);
    }

    candidates.sort((a, b) => _scoreEvent(b).compareTo(_scoreEvent(a)));
    final top = candidates.first;
    final club = _clubFor(top.clubId);
    final daysAway = top.dateTime.difference(now).inDays;
    final timeLabel = daysAway == 0
        ? _l10n.today
        : daysAway == 1
        ? _l10n.tomorrow
        : _l10n.inDaysCount(daysAway);

    return Recommendation(
      type: RecType.bestThisWeek,
      targetType: RecTargetType.event,
      id: top.id,
      title: top.title,
      subtitle: '${_shortName(club.name)} · $timeLabel',
      reason: _buildEventReason(top, club, myId),
      data: top,
    );
  }

  Recommendation? _getBestUnfollowedClub(
    String myId,
    Set<String> hidden,
    Set<String> exclude,
  ) {
    final myClubs = userState.followedClubIds;
    final candidates = clubs
        .where(
          (c) =>
              !myClubs.contains(c.id) &&
              !hidden.contains(c.id) &&
              !exclude.contains(c.id),
        )
        .toList();

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      final diff =
          personalizationService.interestMatchCount(b.id) -
          personalizationService.interestMatchCount(a.id);
      if (diff != 0) return diff;
      return _memberCount(b.id).compareTo(_memberCount(a.id));
    });

    final top = candidates.first;
    final count = _memberCount(top.id);
    final tags = personalizationService.interestsForClub(top.id);
    final matchedTag = tags.firstWhere(
      (t) => personalizationService.interests.contains(t),
      orElse: () => '',
    );

    final reason = matchedTag.isNotEmpty
        ? _l10n.matchesYourInterest(matchedTag)
        : _l10n.studentsAreMembersCount(count);

    return Recommendation(
      type: RecType.bestThisWeek,
      targetType: RecTargetType.club,
      id: top.id,
      title: _shortName(top.name),
      subtitle: _l10n.membersCount(count),
      reason: reason,
      data: top,
    );
  }

  // ── Slot 3: You Might Like (person or club) ───────────────────────────────

  Recommendation? _getSuggestFollow(
    String myId,
    Set<String> hidden,
    Set<String> exclude,
  ) {
    final myFollowing = userState.followedUserIds;
    final myClubs = userState.followedClubIds;

    final peopleCandidates = users
        .where(
          (u) =>
              u.id != myId &&
              !myFollowing.contains(u.id) &&
              !hidden.contains(u.id) &&
              !exclude.contains(u.id),
        )
        .toList();

    if (peopleCandidates.isEmpty) {
      return _getBestUnfollowedClub(myId, hidden, exclude);
    }

    peopleCandidates.sort((a, b) {
      final aOverlap = a.subscribedClubIds.where(myClubs.contains).length;
      final bOverlap = b.subscribedClubIds.where(myClubs.contains).length;
      return bOverlap.compareTo(aOverlap);
    });

    final top = peopleCandidates.first;
    final sharedClubIds = top.subscribedClubIds
        .where(myClubs.contains)
        .toList();

    String reason;
    String subtitle;
    if (sharedClubIds.isNotEmpty) {
      final sharedClub = _clubFor(sharedClubIds.first);
      reason = _l10n.bothInClub(_shortName(sharedClub.name));
      final n = sharedClubIds.length;
      subtitle = _l10n.clubsInCommonCount(n);
    } else {
      reason = _l10n.youMayKnowThemKuStudent;
      subtitle = top.role == 'student' ? _l10n.kuStudentLabel : 'KU';
    }

    return Recommendation(
      type: RecType.suggestFollow,
      targetType: RecTargetType.person,
      id: top.id,
      title: top.name,
      subtitle: subtitle,
      reason: reason,
      data: top,
    );
  }

  // ── Scoring helpers ──────────────────────────────────────────────────────

  double _scoreEvent(Event e) {
    double score = 0;
    if (userState.followedClubIds.contains(e.clubId)) score += 3.0;
    score += e.attendeeUserIds.length * 0.5;
    score += personalizationService.interestMatchCount(e.clubId) * 2.0;
    return score;
  }

  String _buildEventReason(Event event, Club club, String myId) {
    final followersGoing = event.attendeeUserIds
        .where((id) => userState.followedUserIds.contains(id))
        .length;
    if (followersGoing > 0) {
      return _l10n.peopleYouFollowGoing;
    }
    if (userState.followedClubIds.contains(event.clubId)) {
      return _l10n.becauseYouFollowClub(_shortName(club.name));
    }
    final tags = personalizationService.interestsForClub(event.clubId);
    final matchedTag = tags.firstWhere(
      (t) => personalizationService.interests.contains(t),
      orElse: () => '',
    );
    if (matchedTag.isNotEmpty) return _l10n.matchesYourInterest(matchedTag);
    return _l10n.popularOnCampus;
  }

  // ── Utility ──────────────────────────────────────────────────────────────

  Club _clubFor(String clubId) =>
      clubs.firstWhere((c) => c.id == clubId, orElse: () => clubs.first);

  int _memberCount(String clubId) =>
      users.where((u) => u.subscribedClubIds.contains(clubId)).length;

  /// Strips the Turkish abbreviation in parentheses for shorter display.
  String _shortName(String name) {
    final i = name.indexOf(' (');
    return i > 0 ? name.substring(0, i) : name;
  }
}

final recommendationService = RecommendationService();
