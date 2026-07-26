import 'package:flutter/material.dart';

import '../models/club.dart';
import '../models/user.dart';
import '../services/app_colors.dart';
import '../services/app_strings.dart';
import '../services/locale_service.dart';
import '../services/mock_data.dart';
import '../services/moderation_service.dart';
import '../services/people_service.dart';
import '../services/user_state.dart';
import '../widgets/club_avatar.dart';
import '../widgets/user_avatar.dart';

class BlockedAccountsScreen extends StatelessWidget {
  const BlockedAccountsScreen({super.key});

  User? _userFor(String id) {
    final all = <String, User>{
      for (final user in users) user.id: user,
      for (final user in peopleService.cachedPeople) user.id: user,
    };
    return all[id];
  }

  Club? _clubFor(String id) {
    for (final club in clubs) {
      if (club.id == id) return club;
    }
    return null;
  }

  Future<void> _confirmUnblock(
    BuildContext context, {
    required String name,
    required Future<void> Function() unblock,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(S.unblockQuestion(name)),
        content: Text(S.unblockExplanation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(S.unblock),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await unblock();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(S.unblockFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: ListenableBuilder(
        listenable: Listenable.merge([localeService, moderationService]),
        builder: (context, _) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(
              S.blockedAccounts,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: AppColors.card,
            surfaceTintColor: Colors.transparent,
            bottom: TabBar(
              indicatorColor: AppColors.primaryRed,
              labelColor: AppColors.primaryRed,
              unselectedLabelColor: AppColors.secondaryText,
              tabs: [
                Tab(text: S.people),
                Tab(text: S.clubsLabel),
              ],
            ),
          ),
          body: TabBarView(
            children: [_blockedPeople(context), _blockedClubs(context)],
          ),
        ),
      ),
    );
  }

  Widget _blockedPeople(BuildContext context) {
    final ids = moderationService.blockedUserIds.toList();
    ids.sort((a, b) {
      final aName = _userFor(a)?.name ?? a;
      final bName = _userFor(b)?.name ?? b;
      return aName.toLowerCase().compareTo(bName.toLowerCase());
    });
    if (ids.isEmpty) {
      return _EmptyState(message: S.noBlockedPeople);
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: ids.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, indent: 72, color: AppColors.divider),
      itemBuilder: (context, index) {
        final id = ids[index];
        final user = _userFor(id);
        final name = user == null
            ? S.people
            : userState.displayNameFor(id, user.name);
        return ListTile(
          leading: UserAvatar(userId: id, name: name, size: 44),
          title: Text(
            name,
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: OutlinedButton(
            onPressed: () => _confirmUnblock(
              context,
              name: name,
              unblock: () => moderationService.unblockUser(id),
            ),
            child: Text(S.unblock),
          ),
        );
      },
    );
  }

  Widget _blockedClubs(BuildContext context) {
    final ids = moderationService.blockedClubIds.toList();
    ids.sort((a, b) {
      final aName = _clubFor(a)?.name ?? a;
      final bName = _clubFor(b)?.name ?? b;
      return aName.toLowerCase().compareTo(bName.toLowerCase());
    });
    if (ids.isEmpty) {
      return _EmptyState(message: S.noBlockedClubs);
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: ids.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, indent: 72, color: AppColors.divider),
      itemBuilder: (context, index) {
        final id = ids[index];
        final club = _clubFor(id);
        final name = club?.name ?? S.clubsLabel;
        return ListTile(
          leading: ClubAvatar(
            clubId: id,
            clubName: name,
            color: AppColors.primaryRed,
            imageUrl: club?.logoUrl,
            size: 44,
          ),
          title: Text(
            name,
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: OutlinedButton(
            onPressed: () => _confirmUnblock(
              context,
              name: name,
              unblock: () => moderationService.unblockClub(id),
            ),
            child: Text(S.unblock),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.block_outlined,
              size: 48,
              color: AppColors.secondaryText,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}
