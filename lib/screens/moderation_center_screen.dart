import 'package:flutter/material.dart';

import '../models/admin_moderation_report.dart';
import '../models/club.dart';
import '../models/user.dart';
import '../services/admin_moderation_service.dart';
import '../services/app_colors.dart';
import '../services/app_strings.dart';
import '../services/auth_service.dart';
import '../services/mock_clubup_profile.dart';
import '../services/mock_data.dart';
import '../services/people_service.dart';

class ModerationCenterScreen extends StatefulWidget {
  const ModerationCenterScreen({super.key});

  @override
  State<ModerationCenterScreen> createState() => _ModerationCenterScreenState();
}

class _ModerationCenterScreenState extends State<ModerationCenterScreen> {
  late final Future<void> _loadFuture = adminModerationService.initialize();

  bool get _isAuthorized => isClubUpMockAdmin(authService.currentAdmin);

  List<AdminModerationReport> get _reports =>
      adminModerationService.reportsFor(authService.currentAdmin);

  List<_ProfileTarget> get _profileTargets {
    final byId = <String, _ProfileTarget>{};
    void addUser(User user) {
      if (user.id.isEmpty || user.id == clubUpMockAdminId) return;
      byId[user.id] = _ProfileTarget(
        id: user.id,
        name: user.name.isEmpty ? user.email : user.name,
        email: user.email,
      );
    }

    for (final user in users) {
      addUser(user);
    }
    for (final user in peopleService.cachedPeople) {
      addUser(user);
    }
    for (final report in _reports) {
      final userId = report.reportedUserId;
      if (userId == null || userId.isEmpty || userId == clubUpMockAdminId) {
        continue;
      }
      byId.putIfAbsent(
        userId,
        () => _ProfileTarget(id: userId, name: S.unknownProfile, email: ''),
      );
    }

    final result = byId.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  List<_ClubTarget> get _clubTargets {
    final byId = <String, _ClubTarget>{};
    for (final club in clubs) {
      if (club.id.isEmpty || club.id == clubUpMockAdminId) continue;
      byId[club.id] = _ClubTarget.fromClub(club);
    }
    for (final report in _reports) {
      final clubId = report.reportedClubId;
      if (clubId == null || clubId.isEmpty || clubId == clubUpMockAdminId) {
        continue;
      }
      byId.putIfAbsent(
        clubId,
        () => _ClubTarget(id: clubId, name: S.unknownClub, email: ''),
      );
    }
    final result = byId.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  _ProfileTarget? _profileFor(String? id) {
    if (id == null) return null;
    for (final profile in _profileTargets) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  _ClubTarget? _clubFor(String? id) {
    if (id == null) return null;
    for (final club in _clubTargets) {
      if (club.id == id) return club;
    }
    return null;
  }

  String _reporterName(String reporterId) {
    final profile = _profileFor(reporterId);
    if (profile != null) return profile.name;
    for (final club in clubs) {
      if (club.id == reporterId) return club.name;
    }
    return reporterId;
  }

  String _targetName(AdminModerationReport report) {
    if (report.targetType == 'club') {
      return _clubFor(report.reportedClubId ?? report.targetId)?.name ??
          S.unknownClub;
    }
    if (report.targetType == 'profile') {
      return _profileFor(report.reportedUserId ?? report.targetId)?.name ??
          S.unknownProfile;
    }
    final profile = _profileFor(report.reportedUserId)?.name;
    final club = _clubFor(report.reportedClubId)?.name;
    final labels = <String>[];
    if (profile != null) labels.add(profile);
    if (club != null) labels.add(club);
    return labels.isEmpty ? report.targetId : labels.join(' · ');
  }

  String _friendlyReason(String reason) {
    final words = reason.replaceAll('_', ' ').trim();
    if (words.isEmpty) return '—';
    return '${words[0].toUpperCase()}${words.substring(1)}';
  }

  String _formattedDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}.${two(date.month)}.${date.year}  '
        '${two(date.hour)}:${two(date.minute)}';
  }

  Future<bool> _confirmAction({
    required String title,
    required bool removingBan,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(
              removingBan ? S.unbanConfirmation : S.banConfirmation,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(S.cancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: removingBan
                      ? AppColors.primaryRed
                      : Colors.red,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(removingBan ? S.unban : S.ban),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _toggleProfileBan(_ProfileTarget target) async {
    final banned = adminModerationService.isUserBannedCached(
      userId: target.id,
      email: target.email,
    );
    if (!await _confirmAction(
      title: banned ? S.unbanProfile : S.banProfile,
      removingBan: banned,
    )) {
      return;
    }
    final success = banned
        ? await adminModerationService.unbanUser(
            actor: authService.currentAdmin,
            userId: target.id,
            email: target.email,
          )
        : await adminModerationService.banUser(
            actor: authService.currentAdmin,
            userId: target.id,
            email: target.email,
          );
    if (!success && mounted) _showUnauthorizedMessage();
  }

  Future<void> _toggleClubBan(_ClubTarget target) async {
    final banned = adminModerationService.isClubBannedCached(
      clubId: target.id,
      email: target.email,
    );
    if (!await _confirmAction(
      title: banned ? S.unbanClub : S.banClub,
      removingBan: banned,
    )) {
      return;
    }
    final success = banned
        ? await adminModerationService.unbanClub(
            actor: authService.currentAdmin,
            clubId: target.id,
            email: target.email,
          )
        : await adminModerationService.banClub(
            actor: authService.currentAdmin,
            clubId: target.id,
            email: target.email,
          );
    if (!success && mounted) _showUnauthorizedMessage();
  }

  void _showUnauthorizedMessage() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(S.moderationActionFailed)));
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthorized) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: Text(S.moderationCenter)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              S.moderationAccessDenied,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryText, fontSize: 16),
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            S.moderationCenter,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.card,
          surfaceTintColor: Colors.transparent,
          bottom: TabBar(
            indicatorColor: AppColors.primaryRed,
            labelColor: AppColors.primaryRed,
            unselectedLabelColor: AppColors.secondaryText,
            tabs: [
              Tab(text: S.reports, icon: const Icon(Icons.flag_outlined)),
              Tab(text: S.profiles, icon: const Icon(Icons.people_outline)),
              Tab(text: S.clubsLabel, icon: const Icon(Icons.groups_outlined)),
            ],
          ),
        ),
        body: FutureBuilder<void>(
          future: _loadFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            return AnimatedBuilder(
              animation: adminModerationService,
              builder: (context, _) => TabBarView(
                children: [_buildReports(), _buildProfiles(), _buildClubs()],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildReports() {
    if (_reports.isEmpty) {
      return _EmptyState(icon: Icons.flag_outlined, message: S.noReports);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _reports.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _reportCard(_reports[index]),
    );
  }

  Widget _reportCard(AdminModerationReport report) {
    final profile = _profileFor(report.reportedUserId);
    final club = _clubFor(report.reportedClubId);
    return Card(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.lightRed,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.flag_outlined, color: AppColors.primaryRed),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _targetName(report),
                        style: TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${S.reportedBy}: ${_reporterName(report.reporterId)}',
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formattedDate(report.createdAt),
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '${S.reason}: ${_friendlyReason(report.reason)}',
              style: TextStyle(color: AppColors.text),
            ),
            if (report.contentSnapshot != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  report.contentSnapshot!,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
            if (profile != null || club != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (profile != null) _profileActionButton(profile),
                  if (club != null) _clubActionButton(club),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfiles() {
    final profiles = _profileTargets;
    if (profiles.isEmpty) {
      return _EmptyState(icon: Icons.people_outline, message: S.noProfiles);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: profiles.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final profile = profiles[index];
        final banned = adminModerationService.isUserBannedCached(
          userId: profile.id,
          email: profile.email,
        );
        return _accountTile(
          icon: Icons.person_outline,
          title: profile.name,
          subtitle: profile.email.isEmpty ? profile.id : profile.email,
          banned: banned,
          action: _profileActionButton(profile),
        );
      },
    );
  }

  Widget _buildClubs() {
    final clubTargets = _clubTargets;
    if (clubTargets.isEmpty) {
      return _EmptyState(
        icon: Icons.groups_outlined,
        message: S.noClubsForModeration,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: clubTargets.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final club = clubTargets[index];
        final banned = adminModerationService.isClubBannedCached(
          clubId: club.id,
          email: club.email,
        );
        return _accountTile(
          icon: Icons.groups_outlined,
          title: club.name,
          subtitle: club.email.isEmpty ? club.id : club.email,
          banned: banned,
          action: _clubActionButton(club),
        );
      },
    );
  }

  Widget _accountTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool banned,
    required Widget action,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.lightRed,
          foregroundColor: AppColors.primaryRed,
          child: Icon(icon),
        ),
        title: Text(
          title,
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              banned ? S.banned : S.active,
              style: TextStyle(
                color: banned ? Colors.red : Colors.green,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: action,
      ),
    );
  }

  Widget _profileActionButton(_ProfileTarget profile) {
    final banned = adminModerationService.isUserBannedCached(
      userId: profile.id,
      email: profile.email,
    );
    return _actionButton(
      banned: banned,
      onPressed: () => _toggleProfileBan(profile),
    );
  }

  Widget _clubActionButton(_ClubTarget club) {
    final banned = adminModerationService.isClubBannedCached(
      clubId: club.id,
      email: club.email,
    );
    return _actionButton(banned: banned, onPressed: () => _toggleClubBan(club));
  }

  Widget _actionButton({
    required bool banned,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: banned ? AppColors.primaryRed : Colors.red,
        visualDensity: VisualDensity.compact,
      ),
      onPressed: onPressed,
      child: Text(banned ? S.unban : S.ban),
    );
  }
}

class _ProfileTarget {
  final String id;
  final String name;
  final String email;

  const _ProfileTarget({
    required this.id,
    required this.name,
    required this.email,
  });
}

class _ClubTarget {
  final String id;
  final String name;
  final String email;

  const _ClubTarget({
    required this.id,
    required this.name,
    required this.email,
  });

  factory _ClubTarget.fromClub(Club club) =>
      _ClubTarget(id: club.id, name: club.name, email: club.email ?? '');
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: AppColors.secondaryText),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryText, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
