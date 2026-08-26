import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/user.dart';
import '../services/app_colors.dart';
import '../services/user_profile_link.dart';
import '../services/user_state.dart';
import 'user_avatar.dart';

typedef SharedUserProfileResolver =
    Future<User?> Function(String userIdentifier);

/// Compact, tappable user preview rendered for profile links in chat messages.
class SharedUserProfileMessageCard extends StatefulWidget {
  const SharedUserProfileMessageCard({
    super.key,
    required this.userIdentifier,
    required this.onOpenProfile,
    this.onDarkBackground = false,
    this.resolveUser,
  });

  final String userIdentifier;
  final ValueChanged<String> onOpenProfile;
  final bool onDarkBackground;
  final SharedUserProfileResolver? resolveUser;

  @override
  State<SharedUserProfileMessageCard> createState() =>
      _SharedUserProfileMessageCardState();
}

class _SharedUserProfileMessageCardState
    extends State<SharedUserProfileMessageCard> {
  User? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant SharedUserProfileMessageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userIdentifier == widget.userIdentifier &&
        oldWidget.resolveUser == widget.resolveUser) {
      return;
    }
    _user = null;
    _isLoading = true;
    _resolve();
  }

  Future<void> _resolve() async {
    final requestedIdentifier = widget.userIdentifier;
    final resolver = widget.resolveUser ?? resolveUserProfileLink;
    User? user;
    try {
      user = await resolver(requestedIdentifier);
    } catch (_) {
      user = null;
    }
    if (!mounted || requestedIdentifier != widget.userIdentifier) return;
    setState(() {
      _user = user;
      _isLoading = false;
    });
  }

  String _handleFor(User user) {
    final username = userState.usernameFor(user.id)?.trim() ?? '';
    if (username.isNotEmpty) {
      return username.startsWith('@') ? username : '@$username';
    }
    final email = user.email.trim();
    final separator = email.indexOf('@');
    if (separator > 0) return '@${email.substring(0, separator)}';
    return '';
  }

  String _profileContext(User user) {
    final values = <String>[
      if ((userState.majors[user.id] ?? '').trim().isNotEmpty)
        userState.majors[user.id]!.trim(),
      if ((userState.years[user.id] ?? '').trim().isNotEmpty)
        userState.years[user.id]!.trim(),
    ];
    return values.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final foreground = widget.onDarkBackground ? Colors.white : AppColors.text;
    final secondary = widget.onDarkBackground
        ? Colors.white.withValues(alpha: 0.76)
        : AppColors.secondaryText;
    final background = widget.onDarkBackground
        ? Colors.white.withValues(alpha: 0.13)
        : AppColors.surfaceAlt;
    final border = widget.onDarkBackground
        ? Colors.white.withValues(alpha: 0.22)
        : AppColors.divider;
    final user = _user;

    if (user == null) {
      return Container(
        key: ValueKey(
          _isLoading
              ? 'shared-user-loading-${widget.userIdentifier}'
              : 'shared-user-unavailable-${widget.userIdentifier}',
        ),
        width: 250,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            if (_isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              )
            else
              Icon(Icons.person_off_outlined, size: 20, color: secondary),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.studentProfile,
                style: TextStyle(
                  color: foreground,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListenableBuilder(
      listenable: userState,
      builder: (context, _) {
        final displayName = user.name.trim().isEmpty
            ? userState.displayNameFor(user.id, user.name)
            : user.name.trim();
        final handle = _handleFor(user);
        final profileContext = _profileContext(user);
        final bio = (userState.bios[user.id] ?? '').trim();

        return Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('shared-user-card-${user.id}'),
            borderRadius: BorderRadius.circular(14),
            onTap: () => widget.onOpenProfile(widget.userIdentifier),
            child: Container(
              width: 250,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IgnorePointer(
                    child: UserAvatar(
                      userId: user.id,
                      name: displayName,
                      size: 48,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: foreground,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (handle.isNotEmpty || profileContext.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            [
                              if (handle.isNotEmpty) handle,
                              if (profileContext.isNotEmpty) profileContext,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: secondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (bio.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            bio,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: secondary,
                              fontSize: 11.5,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(Icons.chevron_right_rounded, size: 19, color: secondary),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
