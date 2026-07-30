import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/news_post.dart';
import '../models/share.dart';
import '../services/app_colors.dart';
import '../services/app_strings.dart';
import '../services/chat_store.dart';
import '../services/content_store.dart';
import '../services/mock_data.dart';
import '../services/people_service.dart';
import '../services/user_state.dart';
import 'group_avatar_stack.dart';
import 'user_avatar.dart';

/// Conversation picker used by post cards. Club announcement channels are not
/// included: sharing is deliberately limited to private DMs and user-created
/// groups, matching the post author's intent and avoiding accidental broadcast.
class PostShareSheet extends StatelessWidget {
  const PostShareSheet({
    super.key,
    required this.post,
    required this.currentUserId,
    required this.onShared,
  });

  final NewsPost post;
  final String currentUserId;
  final VoidCallback onShared;

  String _nameForUser(String userId) {
    final cached = peopleService.cachedPeople.where(
      (user) => user.id == userId,
    );
    final known = users.where((user) => user.id == userId);
    final fallback = cached.isNotEmpty
        ? cached.first.name
        : (known.isNotEmpty ? known.first.name : '');
    return userState.displayNameFor(userId, fallback);
  }

  String _titleFor(ChatThreadSummary thread) {
    if (thread.isGroup) {
      return chatStore.groupDisplayName(thread.threadId, currentUserId);
    }
    return _nameForUser(thread.peerId ?? '');
  }

  void _share(BuildContext context, ChatThreadSummary thread) {
    final sent = chatStore.sendMessage(
      threadId: thread.threadId,
      senderId: currentUserId,
      content: post.content.trim(),
      kind: ChatMessageKind.postShare,
      sharedPostId: post.id,
    );
    if (sent == null) return;

    if (!shares.any(
      (share) => share.targetId == post.id && share.userId == currentUserId,
    )) {
      shares.add(
        Share(
          id: sent.id,
          targetId: post.id,
          userId: currentUserId,
          createdAt: sent.createdAt,
        ),
      );
      contentStore.scheduleSave('shares');
    }
    onShared();
    Navigator.pop(context, thread.threadId);
  }

  @override
  Widget build(BuildContext context) {
    final threads = chatStore
        .threadsFor(currentUserId)
        .where((thread) => !thread.isClub)
        .toList(growable: false);
    return SafeArea(
      child: Container(
        key: const ValueKey('post-share-sheet'),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      S.sharePostToChat,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.secondaryText,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.divider),
            if (threads.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 34, 28, 44),
                child: Column(
                  children: [
                    Icon(
                      Icons.forum_outlined,
                      size: 42,
                      color: AppColors.secondaryText,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      S.noStudentChatsYet,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: threads.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, indent: 76, color: AppColors.divider),
                  itemBuilder: (context, index) {
                    final thread = threads[index];
                    final title = _titleFor(thread);
                    final memberIds = thread.isGroup
                        ? chatStore
                              .groupParticipants(thread.threadId)
                              .where((id) => id != currentUserId)
                              .toList(growable: false)
                        : const <String>[];
                    return ListTile(
                      key: ValueKey('share-post-thread-${thread.threadId}'),
                      onTap: () => _share(context, thread),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      leading: thread.isGroup
                          ? GroupAvatarStack(
                              memberIds: memberIds,
                              nameForUser: _nameForUser,
                              photoPath: chatStore
                                  .groupForThread(thread.threadId)
                                  ?.photoUrl,
                              size: 44,
                            )
                          : UserAvatar(
                              userId: thread.peerId ?? '',
                              name: title,
                              size: 44,
                              fontSize: 16,
                            ),
                      title: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      trailing: Icon(
                        Icons.send_rounded,
                        color: AppColors.primaryRed,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
