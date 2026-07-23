import '../models/club.dart';
import 'content_store.dart';
import 'supabase_club_service.dart';
import 'user_state.dart';

typedef _SetRemoteBoardRole =
    Future<void> Function({
      required Club club,
      required String userId,
      String? title,
    });

typedef _RemoveRemoteBoardRole =
    Future<void> Function({required Club club, required String userId});

class StudentClubRoleService {
  final _SetRemoteBoardRole _setRemoteBoardRole;
  final _RemoveRemoteBoardRole _removeRemoteBoardRole;
  final Future<void> Function() _saveBoardMemberIds;
  final Future<void> Function() _saveBoardMemberTitles;
  final void Function() _notifyProfiles;

  StudentClubRoleService({
    Future<void> Function({
      required Club club,
      required String userId,
      String? title,
    })?
    setRemoteBoardRole,
    Future<void> Function({required Club club, required String userId})?
    removeRemoteBoardRole,
    Future<void> Function()? saveBoardMemberIds,
    Future<void> Function()? saveBoardMemberTitles,
    void Function()? notifyProfiles,
  }) : _setRemoteBoardRole =
           setRemoteBoardRole ?? supabaseClubService.setBoardMemberRole,
       _removeRemoteBoardRole =
           removeRemoteBoardRole ?? supabaseClubService.removeBoardMemberRole,
       _saveBoardMemberIds =
           saveBoardMemberIds ?? contentStore.saveBoardMemberIds,
       _saveBoardMemberTitles =
           saveBoardMemberTitles ?? contentStore.saveBoardMemberTitles,
       _notifyProfiles = notifyProfiles ?? userState.bumpClubInfo;

  /// Returns the student's visible board role, or null when they are not on
  /// this club's board. A board member without a custom title keeps a useful
  /// fallback label everywhere profiles are rendered.
  String? roleTitleFor(Club club, String userId) {
    if (!club.boardMemberIds.contains(userId)) return null;
    final title = club.boardMemberTitles[userId]?.trim() ?? '';
    return title.isEmpty ? 'Board Member' : title;
  }

  /// Builds the profile club list with every role club first, followed by the
  /// student's remaining followed clubs. Iterating [allClubs] makes ordering
  /// stable and using ids for membership prevents duplicates.
  List<Club> orderedProfileClubs({
    required String userId,
    required Iterable<String> followedClubIds,
    required Iterable<Club> allClubs,
  }) {
    final followedIds = followedClubIds.toSet();
    final roleClubs = <Club>[];
    final regularClubs = <Club>[];
    final seenClubIds = <String>{};

    for (final club in allClubs) {
      if (!seenClubIds.add(club.id)) continue;
      if (roleTitleFor(club, userId) != null) {
        roleClubs.add(club);
      } else if (followedIds.contains(club.id)) {
        regularClubs.add(club);
      }
    }

    return [...roleClubs, ...regularClubs];
  }

  /// Persists the remote role before changing local state, preventing a failed
  /// server update from leaving the student looking promoted only on-device.
  Future<void> setBoardMembership({
    required Club club,
    required String userId,
    required bool isBoardMember,
    String? title,
  }) async {
    final normalizedTitle = title?.trim();

    if (isBoardMember) {
      await _setRemoteBoardRole(
        club: club,
        userId: userId,
        title: normalizedTitle,
      );
    } else {
      await _removeRemoteBoardRole(club: club, userId: userId);
    }

    if (isBoardMember) {
      if (!club.boardMemberIds.contains(userId)) {
        club.boardMemberIds.add(userId);
      }
      if (normalizedTitle == null || normalizedTitle.isEmpty) {
        club.boardMemberTitles.remove(userId);
      } else {
        club.boardMemberTitles[userId] = normalizedTitle;
      }
    } else {
      club.boardMemberIds.remove(userId);
      club.boardMemberTitles.remove(userId);
    }

    await Future.wait([_saveBoardMemberIds(), _saveBoardMemberTitles()]);
    _notifyProfiles();
  }
}

final studentClubRoleService = StudentClubRoleService();
