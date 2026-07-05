import 'package:flutter/material.dart';

import '../models/news_post.dart';
import '../services/app_colors.dart';
import '../services/app_strings.dart';
import '../services/auth_service.dart';
import '../services/poll_store.dart';

/// Poll attached to a feed post: tappable options before voting, percentage
/// bars (plain filled containers, no chart lib) once the viewer has voted.
/// Tapping another option changes the vote.
class PollCard extends StatelessWidget {
  final NewsPost post;
  final Color accent;

  const PollCard({super.key, required this.post, required this.accent});

  @override
  Widget build(BuildContext context) {
    final poll = post.poll;
    if (poll == null) return const SizedBox.shrink();
    final userId = authService.currentUser?.id ?? '';
    final canVote = authService.isStudentSession && userId.isNotEmpty;

    return ListenableBuilder(
      listenable: pollStore,
      builder: (_, _) {
        pollStore.hydrate(post.id);
        final myVote = userId.isEmpty
            ? null
            : pollStore.myVote(post.id, userId);
        final total = pollStore.totalVotes(post.id);
        final showResults = myVote != null;

        return Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.all(Radius.circular(14)),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.poll_outlined, size: 16, color: accent),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      poll.question,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < poll.options.length; i++)
                _option(
                  context,
                  index: i,
                  label: poll.options[i],
                  votes: pollStore.votesForOption(post.id, i),
                  total: total,
                  isMine: myVote == i,
                  showResults: showResults,
                  onTap: canVote
                      ? () => pollStore.vote(
                          post: post,
                          userId: userId,
                          optionIndex: i,
                        )
                      : null,
                ),
              const SizedBox(height: 2),
              Text(
                S.pollVotes(total),
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _option(
    BuildContext context, {
    required int index,
    required String label,
    required int votes,
    required int total,
    required bool isMine,
    required bool showResults,
    VoidCallback? onTap,
  }) {
    final fraction = (showResults && total > 0) ? votes / total : 0.0;
    final percent = (fraction * 100).round();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.all(Radius.circular(10)),
          border: Border.all(
            color: isMine ? accent : AppColors.divider,
            width: isMine ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (showResults)
              FractionallySizedBox(
                widthFactor: fraction.clamp(0.0, 1.0),
                heightFactor: 1,
                child: Container(
                  color: accent.withValues(alpha: isMine ? 0.28 : 0.13),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  if (isMine) ...[
                    Icon(Icons.check_circle_rounded, size: 15, color: accent),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isMine ? FontWeight.w700 : FontWeight.w500,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  if (showResults)
                    Text(
                      '$percent%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isMine ? accent : AppColors.secondaryText,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
