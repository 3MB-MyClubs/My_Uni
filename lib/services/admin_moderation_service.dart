import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/admin_moderation_report.dart';
import '../models/app_admin.dart';
import 'mock_clubup_profile.dart';

/// Device-local moderation state for the development-only ClubUp profile.
///
/// The mock profile is not a Supabase Auth identity, so giving it direct read
/// access to the server moderation queue would also expose that queue to the
/// public client key. This store keeps the prototype safe: reports created on
/// this installation are reviewable here, while every administrative read and
/// write is guarded by the active ClubUp identity.
class AdminModerationService extends ChangeNotifier {
  static const _reportsKey = 'clubup_admin_moderation_reports_v1';
  static const _bannedUserIdsKey = 'clubup_admin_banned_user_ids_v1';
  static const _bannedUserEmailsKey = 'clubup_admin_banned_user_emails_v1';
  static const _bannedClubIdsKey = 'clubup_admin_banned_club_ids_v1';
  static const _bannedClubEmailsKey = 'clubup_admin_banned_club_emails_v1';

  final List<AdminModerationReport> _reports = [];
  final Set<String> _bannedUserIds = {};
  final Set<String> _bannedUserEmails = {};
  final Set<String> _bannedClubIds = {};
  final Set<String> _bannedClubEmails = {};
  bool _initialized = false;

  Future<void> initialize({bool force = false}) async {
    if (_initialized && !force) return;
    final preferences = await SharedPreferences.getInstance();

    _reports.clear();
    final encodedReports = preferences.getString(_reportsKey);
    if (encodedReports != null && encodedReports.isNotEmpty) {
      try {
        final decoded = jsonDecode(encodedReports);
        if (decoded is List) {
          _reports.addAll(
            decoded.whereType<Map>().map(
              (map) =>
                  AdminModerationReport.fromMap(Map<String, dynamic>.from(map)),
            ),
          );
        }
      } on FormatException {
        // A corrupt mock queue should not prevent the app from starting.
      }
    }
    _reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    _replaceSet(_bannedUserIds, preferences.getStringList(_bannedUserIdsKey));
    _replaceSet(
      _bannedUserEmails,
      preferences.getStringList(_bannedUserEmailsKey),
      normalize: true,
    );
    _replaceSet(_bannedClubIds, preferences.getStringList(_bannedClubIdsKey));
    _replaceSet(
      _bannedClubEmails,
      preferences.getStringList(_bannedClubEmailsKey),
      normalize: true,
    );
    _initialized = true;
    notifyListeners();
  }

  List<AdminModerationReport> reportsFor(AppAdmin? actor) {
    if (!isClubUpMockAdmin(actor)) return const [];
    return List.unmodifiable(_reports);
  }

  Set<String> bannedUserIdsFor(AppAdmin? actor) {
    if (!isClubUpMockAdmin(actor)) return const {};
    return Set.unmodifiable(_bannedUserIds);
  }

  Set<String> bannedClubIdsFor(AppAdmin? actor) {
    if (!isClubUpMockAdmin(actor)) return const {};
    return Set.unmodifiable(_bannedClubIds);
  }

  /// Any signed-in account may create a report, but only ClubUp can read it.
  Future<void> recordReport({
    required String reporterId,
    required String targetType,
    required String targetId,
    required String reason,
    String source = 'report',
    String? reportedUserId,
    String? reportedClubId,
    String? contentSnapshot,
  }) async {
    if (reporterId.isEmpty || targetId.isEmpty || reason.trim().isEmpty) return;
    await initialize();
    final now = DateTime.now();
    final snapshot = contentSnapshot?.trim() ?? '';
    _reports.insert(
      0,
      AdminModerationReport(
        id: '${now.microsecondsSinceEpoch}-$reporterId',
        reporterId: reporterId,
        targetType: targetType,
        targetId: targetId,
        reason: reason.trim(),
        source: source,
        reportedUserId: _optional(reportedUserId),
        reportedClubId: _optional(reportedClubId),
        contentSnapshot: snapshot.isEmpty
            ? null
            : snapshot.length > 2000
            ? snapshot.substring(0, 2000)
            : snapshot,
        createdAt: now,
      ),
    );
    await _persistReports();
    notifyListeners();
  }

  Future<bool> banUser({
    required AppAdmin? actor,
    required String userId,
    String? email,
  }) async {
    if (!isClubUpMockAdmin(actor) || userId == clubUpMockAdminId) return false;
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail == clubUpMockEmail) return false;
    if (userId.trim().isEmpty && normalizedEmail.isEmpty) return false;
    await initialize();
    if (userId.trim().isNotEmpty) _bannedUserIds.add(userId.trim());
    if (normalizedEmail.isNotEmpty) _bannedUserEmails.add(normalizedEmail);
    await _persistBans();
    notifyListeners();
    return true;
  }

  Future<bool> unbanUser({
    required AppAdmin? actor,
    required String userId,
    String? email,
  }) async {
    if (!isClubUpMockAdmin(actor)) return false;
    await initialize();
    final changed =
        _bannedUserIds.remove(userId.trim()) |
        _bannedUserEmails.remove(_normalizeEmail(email));
    if (changed) {
      await _persistBans();
      notifyListeners();
    }
    return changed;
  }

  Future<bool> banClub({
    required AppAdmin? actor,
    required String clubId,
    String? email,
  }) async {
    if (!isClubUpMockAdmin(actor) || clubId == clubUpMockAdminId) return false;
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail == clubUpMockEmail) return false;
    if (clubId.trim().isEmpty && normalizedEmail.isEmpty) return false;
    await initialize();
    if (clubId.trim().isNotEmpty) _bannedClubIds.add(clubId.trim());
    if (normalizedEmail.isNotEmpty) _bannedClubEmails.add(normalizedEmail);
    await _persistBans();
    notifyListeners();
    return true;
  }

  Future<bool> unbanClub({
    required AppAdmin? actor,
    required String clubId,
    String? email,
  }) async {
    if (!isClubUpMockAdmin(actor)) return false;
    await initialize();
    final changed =
        _bannedClubIds.remove(clubId.trim()) |
        _bannedClubEmails.remove(_normalizeEmail(email));
    if (changed) {
      await _persistBans();
      notifyListeners();
    }
    return changed;
  }

  Future<bool> isUserBanned({required String userId, String? email}) async {
    await initialize();
    return isUserBannedCached(userId: userId, email: email);
  }

  bool isUserBannedCached({required String userId, String? email}) {
    return _bannedUserIds.contains(userId.trim()) ||
        _bannedUserEmails.contains(_normalizeEmail(email));
  }

  Future<bool> isClubBanned({required String clubId, String? email}) async {
    await initialize();
    return isClubBannedCached(clubId: clubId, email: email);
  }

  bool isClubBannedCached({required String clubId, String? email}) {
    return _bannedClubIds.contains(clubId.trim()) ||
        _bannedClubEmails.contains(_normalizeEmail(email));
  }

  Future<void> _persistReports() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _reportsKey,
      jsonEncode([for (final report in _reports) report.toMap()]),
    );
  }

  Future<void> _persistBans() async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setStringList(_bannedUserIdsKey, _bannedUserIds.toList()),
      preferences.setStringList(
        _bannedUserEmailsKey,
        _bannedUserEmails.toList(),
      ),
      preferences.setStringList(_bannedClubIdsKey, _bannedClubIds.toList()),
      preferences.setStringList(
        _bannedClubEmailsKey,
        _bannedClubEmails.toList(),
      ),
    ]);
  }

  static void _replaceSet(
    Set<String> target,
    List<String>? values, {
    bool normalize = false,
  }) {
    target
      ..clear()
      ..addAll(
        (values ?? const <String>[])
            .map(
              (value) => normalize ? value.trim().toLowerCase() : value.trim(),
            )
            .where((value) => value.isNotEmpty),
      );
  }

  static String _normalizeEmail(String? email) =>
      email?.trim().toLowerCase() ?? '';

  static String? _optional(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

final adminModerationService = AdminModerationService();
