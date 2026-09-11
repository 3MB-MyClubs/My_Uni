import 'dart:async' show unawaited;
import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../features/calendar/widgets/add_to_calendar_button.dart';
import '../models/chat_message.dart';
import '../models/event.dart';
import '../models/user.dart';
import '../services/app_colors.dart';
import '../services/app_strings.dart';
import '../services/account_switcher_service.dart';
import '../services/auth_service.dart';
import '../services/club_admin_access.dart';
import '../services/club_follow_helper.dart';
import '../services/content_store.dart';
import '../services/event_attendee_visibility.dart';
import '../services/locale_service.dart';
import '../services/media_delivery_service.dart';
import '../services/mock_data.dart';
import '../services/people_service.dart';
import '../services/rsvp_store.dart';
import '../services/supabase_event_service.dart';
import '../l10n/app_localizations.dart';
import '../services/checkin_store.dart';
import '../services/chat_store.dart';
import '../services/supabase_interaction_service.dart';
import '../services/theme_service.dart';
import '../services/user_prefs_service.dart';
import '../services/user_state.dart';
import '../services/view_tracker.dart';
import '../widgets/app_network_image.dart';
import '../widgets/club_avatar.dart';
import '../widgets/clubup_design.dart';
import '../widgets/loading_skeleton.dart';
import '../widgets/media_scrim.dart';
import '../widgets/event_cover_image.dart';
import '../widgets/event_share_sheet.dart';
import '../widgets/user_avatar.dart';
import 'club_profile_screen.dart';
import 'create_event_screen.dart';
import 'event_attendee_list_screen.dart';
import 'user_profile_screen.dart';
import '../services/content_visibility.dart';
import '../widgets/content_audience_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Event detail — recreation of the `Event new design light` / `…black` frames
// (`283:381` / `283:497`).
//
// A full-bleed hero photo that dissolves into the page, then one 20px column
// on a uniform 32px rhythm: title block, host, who is going, about, tags,
// speakers, programme schedule, bring friends and the registration CTA — with
// the RSVP / add-to-calendar bar floating over the bottom clearance.
//
// The frames paint their accent `#1DA1F2`; that is a leftover from the Figma
// template and the burgundy `ClubUpColors.accent` is used throughout instead,
// as in every other area redesigned from this handoff.
// ─────────────────────────────────────────────────────────────────────────────

/// Normalises a hand-typed link — a bare `linkedin.com/in/x` as readily as a
/// full URL — into something [launchUrl] will accept, or null when it cannot.
/// Shared by the registration action and the speaker cards on both the student
/// and the club-admin view, which all used to carry their own copy.
Uri? _externalUri(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final withScheme = trimmed.startsWith(RegExp(r'https?://'))
      ? trimmed
      : 'https://$trimmed';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || uri.host.isEmpty) return null;
  return uri;
}

bool _isRemoteEventImagePath(String path) =>
    path.startsWith('http://') || path.startsWith('https://');

Widget _eventHeroImage({required String path, required Color accent}) {
  if (_isRemoteEventImagePath(path)) {
    return AppNetworkImage(
      url: path,
      fit: BoxFit.cover,
      // Full-bleed hero — wider than a feed banner but still bounded well
      // under typical upload resolutions (up to 3840px).
      cacheWidth: 800,
      rendition: MediaRendition.screen,
      placeholderBuilder: (_) => const SkeletonBox(),
      errorBuilder: (_) => _GradientHero(color: accent),
    );
  }

  return Image.file(
    File(path),
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => _GradientHero(color: accent),
  );
}

class EventDetailScreen extends StatefulWidget {
  final Event event;
  final Color color;

  const EventDetailScreen({
    super.key,
    required this.event,
    required this.color,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  static const int _quickInviteSlotCount = 5;
  // The bare floating actions are 44 + 8 + 44 tall plus a 12pt bottom margin,
  // so 108 clears them; the rest is breathing room, as it was when this was a
  // docked bar.
  static const double _stickyCtaScrollClearance = 150;

  final Set<String> _invitedFriendIds = {};
  final List<String> _quickInviteFriendIds = [];
  List<User> _remoteAttendees = const [];
  bool _remoteAttendeesLoaded = false;

  Event get _event => events.firstWhere(
    (event) => event.id == widget.event.id,
    orElse: () => widget.event,
  );

  bool get _saved => userState.isSaved(_event.id);

  String get _currentAdminId => authService.currentAdmin?.id ?? '';

  String get _currentSessionId =>
      authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

  bool get _canDeleteEvent =>
      contentStore.canDeleteEvent(_event.id, _currentAdminId);

  // Both dedicated club logins and linked board accounts see the editable
  // management screen for the club account they currently represent.
  bool get _ownContent => currentAccountManagesClubId(_event.clubId);

  bool get _canUseStudentSocialActions =>
      authService.isStudentSession &&
      !accountSwitcherService.isClubAccountActive;

  bool get _isLive {
    final now = DateTime.now();
    return !_event.dateTime.isAfter(now) && _event.endTime.isAfter(now);
  }

  bool get _isPast => !_event.endTime.isAfter(DateTime.now());

  @override
  void initState() {
    super.initState();
    contentStore.addListener(_onContentChanged);
    final userId = authService.currentUser?.id ?? '';
    rsvpStore.seed(
      widget.event.id,
      widget.event.attendeeUserIds.contains(userId),
    );
    final viewerId =
        authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
    viewTracker.recordView(widget.event.id, viewerId);
    _loadPeople();
  }

  @override
  void dispose() {
    contentStore.removeListener(_onContentChanged);
    super.dispose();
  }

  void _onContentChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPeople() async {
    try {
      final attendees = await supabaseInteractionService.fetchEventAttendees(
        widget.event.id,
      );
      _remoteAttendees = attendees;
      _remoteAttendeesLoaded = true;
      supabaseEventRsvpCounts[widget.event.id] = attendees.length;
      await peopleService.hydrateProfilesByIds(
        attendees.isEmpty
            ? widget.event.attendeeUserIds
            : attendees.map((user) => user.id),
      );
      // Club accounts do not have friends and cannot send event invitations.
      // Only hydrate the broader suggestion pool for student sessions.
      if (_canUseStudentSocialActions && peopleService.cachedPeople.isEmpty) {
        await peopleService.fetchPeople(excludeId: _currentSessionId);
      }
    } catch (_) {
      // The cards keep their initials and local suggestions when offline.
    }
    if (mounted) setState(() {});
  }

  Map<String, User> get _knownPeopleById => {
    for (final user in users) user.id: user,
    for (final user in peopleService.cachedPeople) user.id: user,
    for (final user in _remoteAttendees) user.id: user,
    if (authService.currentUser != null)
      authService.currentUser!.id: authService.currentUser!,
  };

  List<User> get _attendees {
    final known = _knownPeopleById;
    final attendeeIds = _remoteAttendeesLoaded
        ? _remoteAttendees.map((user) => user.id).toSet()
        : _event.attendeeUserIds.toSet();
    if (rsvpStore.isAttending(_event.id) && _currentSessionId.isNotEmpty) {
      attendeeIds.add(_currentSessionId);
    } else {
      attendeeIds.remove(_currentSessionId);
    }
    return attendeeIds
        .map(
          (id) =>
              known[id] ??
              User(
                id: id,
                name: lookupAppLocalizations(
                  Locale(localeService.languageCode),
                ).studentProfile,
                email: '',
                password: '',
                role: 'student',
                subscribedClubIds: const [],
              ),
        )
        .toList(growable: false);
  }

  int get _rsvpCount => supabaseEventRsvpCounts[_event.id] ?? _attendees.length;

  List<User> get _suggestedFriends {
    final excludedIds = {
      _currentSessionId,
      ..._attendees.map((user) => user.id),
    };
    final realPeople = <String, User>{
      for (final person in peopleService.randomProfiles(
        excludeId: _currentSessionId,
      ))
        if (!excludedIds.contains(person.id)) person.id: person,
      for (final person in users)
        if (!excludedIds.contains(person.id)) person.id: person,
    }.values.toList(growable: false);

    if (realPeople.isNotEmpty) return realPeople;

    return [
      User(
        id: 'event-friend-ceren',
        name: 'Ceren Levent',
        email: '',
        password: '',
        role: 'student',
        subscribedClubIds: const [],
      ),
      User(
        id: 'event-friend-zeynep',
        name: 'Zeynep Arslan',
        email: '',
        password: '',
        role: 'student',
        subscribedClubIds: const [],
      ),
      User(
        id: 'event-friend-tolga',
        name: 'Tolga Kurt',
        email: '',
        password: '',
        role: 'student',
        subscribedClubIds: const [],
      ),
      User(
        id: 'event-friend-ece',
        name: 'Ece Yılmaz',
        email: '',
        password: '',
        role: 'student',
        subscribedClubIds: const [],
      ),
      User(
        id: 'event-friend-can',
        name: 'Can Kaya',
        email: '',
        password: '',
        role: 'student',
        subscribedClubIds: const [],
      ),
      User(
        id: 'event-friend-selin',
        name: 'Selin Aksoy',
        email: '',
        password: '',
        role: 'student',
        subscribedClubIds: const [],
      ),
    ];
  }

  /// Keeps the three quick-invite slots stable while an invitation animates.
  /// Invited profiles are replaced separately after their success motion ends.
  List<User> get _quickInviteFriends {
    final candidates = _suggestedFriends;
    final candidatesById = {
      for (final candidate in candidates) candidate.id: candidate,
    };
    _quickInviteFriendIds.removeWhere((id) => !candidatesById.containsKey(id));

    final assigned = _quickInviteFriendIds.toSet();
    for (final candidate in candidates) {
      if (_quickInviteFriendIds.length >= _quickInviteSlotCount) break;
      if (_invitedFriendIds.contains(candidate.id) ||
          !assigned.add(candidate.id)) {
        continue;
      }
      _quickInviteFriendIds.add(candidate.id);
    }

    return [for (final id in _quickInviteFriendIds) ?candidatesById[id]];
  }

  void _replaceInvitedQuickInviteSlots() {
    final candidates = _suggestedFriends;
    final candidatesById = {
      for (final candidate in candidates) candidate.id: candidate,
    };
    final reserved = <String>{
      for (final id in _quickInviteFriendIds)
        if (candidatesById.containsKey(id) && !_invitedFriendIds.contains(id))
          id,
    };

    for (var index = 0; index < _quickInviteFriendIds.length; index++) {
      final currentId = _quickInviteFriendIds[index];
      if (candidatesById.containsKey(currentId) &&
          !_invitedFriendIds.contains(currentId)) {
        continue;
      }

      User? replacement;
      for (final candidate in candidates) {
        if (_invitedFriendIds.contains(candidate.id) ||
            !reserved.add(candidate.id)) {
          continue;
        }
        replacement = candidate;
        break;
      }
      if (replacement != null) {
        _quickInviteFriendIds[index] = replacement.id;
      }
    }
  }

  Color get _accent {
    final accent = tryParseEventAccentColor(_event.accentColorHex);
    return accent == null ? widget.color : Color(accent);
  }

  // ── Actions ─────────────────────────────────────────────────────────────────
  void _toggleSaved() {
    if (!_canUseStudentSocialActions) return;

    setState(() => userState.toggleSave(_event.id));
    userPrefsService.save(_currentSessionId);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            _saved
                ? AppLocalizations.of(context)!.savedToEvents
                : AppLocalizations.of(context)!.removedFromSaved,
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _saved ? _accent : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      );
  }

  void _shareEvent() {
    if (!_canUseStudentSocialActions) return;
    _showEventShareSheet();
  }

  void _openAttendees() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventAttendeeListScreen(event: _event, color: _accent),
      ),
    );
  }

  void _inviteFriend(User friend) {
    _sendEventInvitations([friend], singleFriendName: friend.name);
  }

  void _sendEventInvitations(
    List<User> recipients, {
    String? singleFriendName,
  }) {
    final newRecipients = recipients
        .where((person) => !_invitedFriendIds.contains(person.id))
        .toList(growable: false);
    if (newRecipients.isEmpty) return;

    HapticFeedback.selectionClick();
    final senderId = _currentSessionId;
    for (final person in newRecipients) {
      final threadId = chatStore.ensureDirectThread(senderId, person.id);
      if (threadId == null) continue;
      chatStore.sendMessage(
        threadId: threadId,
        senderId: senderId,
        content: '${_event.title}\nkuclubs://event/${_event.id}',
        kind: ChatMessageKind.event,
        title: _event.title,
        eventId: _event.id,
      );
    }
    setState(() {
      _invitedFriendIds.addAll(newRecipients.map((person) => person.id));
    });
    Future<void>.delayed(const Duration(milliseconds: 620), () {
      if (!mounted) return;
      setState(_replaceInvitedQuickInviteSlots);
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            singleFriendName == null
                ? AppLocalizations.of(
                    context,
                  )!.eventInvitesSentCount(newRecipients.length)
                : AppLocalizations.of(
                    context,
                  )!.eventInviteSent(singleFriendName),
            style: TextStyle(
              color: AppColors.positive,
              fontWeight: FontWeight.w700,
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.positiveSurface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      );
  }

  void _showEventShareSheet() {
    showEventShareSheet(
      context: context,
      event: _event,
      people: _suggestedFriends,
      sentUserIds: _invitedFriendIds,
      onInvite: _sendEventInvitations,
    );
  }

  void _showAllSuggestedFriends() => _showEventShareSheet();

  void _confirmDelete() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        title: Text(
          AppLocalizations.of(context)!.deleteEvent,
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text),
        ),
        content: Text(
          AppLocalizations.of(context)!.deleteEventMsg,
          style: TextStyle(color: AppColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              AppLocalizations.of(context)!.cancel,
              style: TextStyle(color: AppColors.secondaryText),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed != true || !mounted) return;
      try {
        await supabaseEventService.deleteEvent(_event);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.couldNotDeleteEventSupabase,
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        return;
      }
      final ok = contentStore.deleteEvent(_event.id, _currentAdminId);
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context);
      } else {
        Navigator.popUntil(context, (r) => r.isFirst);
      }
    });
  }

  /// `time-badge` — the handoff's "Tonight · 7 PM - 11 PM". Day wording and
  /// clock format come from the app's locale helpers, so this reads correctly
  /// in Turkish where the mockup's 12-hour "7 PM" would be wrong.
  String _whenBadgeLabel() {
    final l10n = AppLocalizations.of(context)!;
    if (_isLive) return l10n.happeningNow;
    if (_isPast) return l10n.ended;

    final start = _event.dateTime;
    final diff = start.difference(DateTime.now());
    final day = diff.inDays == 0
        ? l10n.today
        : diff.inDays == 1
        ? l10n.tomorrow
        : DateFormat.MMMEd(localeService.languageCode).format(start);
    final clock = DateFormat.Hm(localeService.languageCode);
    return '$day · ${clock.format(start)} - ${clock.format(_event.endTime)}';
  }

  void _openClub() {
    final club = clubForId(_event.clubId);
    if (club == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClubProfileScreen(club: club, color: _accent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The owning club sees a dedicated, editable admin screen instead of the
    // student-facing detail.
    if (_ownContent) {
      return ClubEventAdminScreen(event: _event, accent: _accent);
    }

    final event = _event;
    final accent = _accent;
    final hasReg =
        event.registrationUrl != null &&
        event.registrationUrl!.trim().isNotEmpty;
    final hasProgramme = event.schedule != null && event.schedule!.isNotEmpty;
    final hasSpeakers = event.speakers.isNotEmpty;
    final canEngage = _canUseStudentSocialActions;
    final showCta = canEngage && !_isPast;

    return Scaffold(
      backgroundColor: ClubUpColors.background,
      body: Stack(
        children: [
          // ── Scrollable content ──────────────────────────────────────────
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                bottom: showCta ? _stickyCtaScrollClearance : 40,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero photo, nav actions and the audience badge
                  _Hero(
                    event: event,
                    accent: accent,
                    saved: _saved,
                    canDelete: _canDeleteEvent,
                    canEngage: canEngage,
                    onBack: () => Navigator.pop(context),
                    onToggleSaved: _toggleSaved,
                    onShare: _shareEvent,
                    onDelete: _confirmDelete,
                  ),

                  // `scrollable-content` 283:410 — one 20px column with a
                  // uniform 32px gap between every section, hairlines
                  // included, so each rule is 32px clear on both sides.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // `title-block` — time badge, event name, location
                        _EventTitleBlock(
                          event: event,
                          whenLabel: _whenBadgeLabel(),
                        ),

                        const _EventSectionRule(),

                        // `host-section` — the Follow pill is ours; the frames
                        // leave that half of the row empty.
                        _HostCard(
                          event: event,
                          accent: accent,
                          onView: _openClub,
                        ),

                        // `attendee-section` 294:5 — promoted from below the
                        // speakers to directly under the host.
                        //
                        // Its rule lives inside the builder, not beside it:
                        // there is nothing to show whenever the viewer can see
                        // no attendees — which is every session without
                        // Supabase, guest mode included — and a rule left
                        // behind by a collapsed section reads as a doubled
                        // hairline around an empty band.
                        ListenableBuilder(
                          listenable: rsvpStore,
                          builder: (_, _) {
                            // A student only ever learns about the attendees
                            // they follow each other with — names, faces and
                            // headcount alike. See [attendeeVisibilityFor].
                            final visibility = attendeeVisibilityFor(
                              _event,
                              attendeeIds: _attendees.map((user) => user.id),
                              totalCount: _rsvpCount,
                            );
                            if (visibility.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const _EventSectionRule(),
                                _AttendingCard(
                                  // The viewer's own RSVP counts towards
                                  // "going" but is not one of the people they
                                  // follow.
                                  followedUserIds: visibility.visibleIds
                                      .where((id) => id != _currentSessionId)
                                      .toList(growable: false),
                                  count: visibility.count,
                                  onTap: visibility.showsNames
                                      ? _openAttendees
                                      : null,
                                ),
                              ],
                            );
                          },
                        ),

                        const _EventSectionRule(),

                        // `about-section`
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SecHead(
                              AppLocalizations.of(context)!.aboutThisEvent,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              event.description,
                              style: figtree(
                                size: 15,
                                weight: FontWeight.w400,
                                color: ClubUpColors.muted,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),

                        if (event.tags.isNotEmpty) ...[
                          const _EventSectionRule(),
                          // `tags-row` — the leading chip carries the accent.
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (var i = 0; i < event.tags.length; i++)
                                _EventTag(
                                  label: event.tags[i],
                                  accented: i == 0,
                                ),
                            ],
                          ),
                        ],

                        // Speakers, programme and registration run
                        // divider-free: the last `Line` in the frames is
                        // `283:455`, above the speakers heading.
                        if (hasSpeakers) ...[
                          const _EventSectionRule(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: _SecHead(
                                  AppLocalizations.of(context)!.speakers,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _EventSpeakerCards(speakers: event.speakers),
                            ],
                          ),
                        ],

                        if (hasProgramme) ...[
                          if (hasSpeakers)
                            const SizedBox(height: _EventSectionRule.gap)
                          else
                            const _EventSectionRule(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: _SecHead(
                                  AppLocalizations.of(
                                    context,
                                  )!.programmeSchedule,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _EventProgramme(slots: event.schedule!),
                            ],
                          ),
                        ],

                        // Friend invitations belong to student accounts only,
                        // and are not in the frames — kept because nothing
                        // else on the screen invites anyone.
                        if (canEngage) ...[
                          const _EventSectionRule(),
                          _BringFriendsSection(
                            friends: _quickInviteFriends,
                            invitedFriendIds: _invitedFriendIds,
                            onInvite: _inviteFriend,
                            onSeeAll: _showAllSuggestedFriends,
                            onShare: _shareEvent,
                          ),
                        ],

                        // `registration-section` — the page's one filled CTA,
                        // last in the column.
                        if (hasReg) ...[
                          const SizedBox(height: _EventSectionRule.gap),
                          _EventRegistrationCta(
                            url: event.registrationUrl!.trim(),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ── Sticky CTA ──────────────────────────────────────────────────
          if (showCta)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _StickyCta(event: event, accent: accent),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Club admin event detail — editable management view shown when a club opens
// one of its OWN events. Mirrors the "Club Event Detail" design handoff.
// ─────────────────────────────────────────────────────────────────────────────

class ClubEventAdminScreen extends StatefulWidget {
  final Event event;
  final Color accent;

  const ClubEventAdminScreen({
    super.key,
    required this.event,
    required this.accent,
  });

  @override
  State<ClubEventAdminScreen> createState() => _ClubEventAdminScreenState();
}

class _ClubEventAdminScreenState extends State<ClubEventAdminScreen> {
  late Event _event = widget.event;
  List<User> _remoteAttendees = const [];
  bool _remoteAttendeesLoaded = false;

  String get _managementActorId => accountSwitcherService.actorId;

  bool get _isLive {
    final now = DateTime.now();
    return !_event.dateTime.isAfter(now) && _event.endTime.isAfter(now);
  }

  bool get _isPast => !_event.endTime.isAfter(DateTime.now());

  Color get _accent => _isLive ? const Color(0xFF2E9E5B) : widget.accent;

  @override
  void initState() {
    super.initState();
    _loadRemoteAttendees();
  }

  @override
  void didUpdateWidget(covariant ClubEventAdminScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event != widget.event) _event = widget.event;
  }

  Future<void> _loadRemoteAttendees() async {
    final attendees = await supabaseInteractionService.fetchEventAttendees(
      _event.id,
    );
    if (!mounted) return;
    setState(() {
      _remoteAttendees = attendees;
      _remoteAttendeesLoaded = true;
      supabaseEventRsvpCounts[_event.id] = attendees.length;
    });
  }

  int get _rsvpCount =>
      supabaseEventRsvpCounts[_event.id] ?? _event.attendeeUserIds.length;

  String _countdownLabel() {
    if (_isLive) return AppLocalizations.of(context)!.happeningNow;
    final diff = _event.dateTime.difference(DateTime.now());
    if (diff.isNegative) return AppLocalizations.of(context)!.ended;
    if (diff.inDays == 0) return AppLocalizations.of(context)!.today;
    if (diff.inDays == 1) return AppLocalizations.of(context)!.tomorrow;
    return AppLocalizations.of(context)!.inDaysCount(diff.inDays);
  }

  void _refresh() {
    final found = events.where((e) => e.id == _event.id).toList();
    if (found.isNotEmpty && mounted) setState(() => _event = found.first);
  }

  Future<void> _openEdit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreateEventScreen(existing: _event)),
    );
    _refresh();
  }

  void _confirmDelete() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        title: Text(
          AppLocalizations.of(context)!.deleteThisEventConfirm,
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text),
        ),
        content: Text(
          AppLocalizations.of(
            context,
          )!.deleteEventPermanentWarning(_event.title),
          style: TextStyle(color: AppColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              AppLocalizations.of(context)!.cancel,
              style: TextStyle(color: AppColors.secondaryText),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context)!.deleteEventButton),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed != true || !mounted) return;
      try {
        await supabaseEventService.deleteEvent(_event);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.couldNotDeleteEventSupabase,
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        return;
      }
      contentStore.deleteEvent(_event.id, _managementActorId);
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    final knownPeople = {
      for (final user in users) user.id: user,
      for (final user in peopleService.cachedPeople) user.id: user,
      for (final user in _remoteAttendees) user.id: user,
    };
    final attendees = _remoteAttendeesLoaded
        ? _remoteAttendees
        : _event.attendeeUserIds
              .map((id) => knownPeople[id])
              .whereType<User>()
              .toList();
    final hasReg = (_event.registrationUrl?.trim().isNotEmpty) ?? false;
    final hasProgramme = _event.schedule != null && _event.schedule!.isNotEmpty;
    final hasSpeakers = _event.speakers.isNotEmpty;
    final hasCapacity = _event.capacity != null && _event.capacity! > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 150),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AdminHero(
                    event: _event,
                    accent: accent,
                    isLive: _isLive,
                    onBack: () => Navigator.pop(context),
                    onEdit: _openEdit,
                    onDelete: _confirmDelete,
                  ),

                  // RSVP stat strip
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                        border: Border.all(color: AppColors.divider),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Column(
                        children: [
                          Icon(
                            Icons.people_alt_outlined,
                            size: 20,
                            color: accent,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$_rsvpCount',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isPast
                                ? AppLocalizations.of(context)!.attendedBadge
                                : AppLocalizations.of(context)!.rsvpsBadge,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Ticket-style date / time / location (+ capacity)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _TicketCard(
                      event: _event,
                      accent: accent,
                      countdown: _countdownLabel(),
                      showCapacity: hasCapacity,
                      takenSeats: _rsvpCount,
                    ),
                  ),

                  // Registration link
                  if (hasReg)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _RegistrationCard(
                        url: _event.registrationUrl!.trim(),
                        accent: accent,
                      ),
                    ),

                  // Attendees
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                    child: _AdminAttendees(
                      event: _event,
                      attendees: attendees,
                      accent: accent,
                    ),
                  ),

                  // About + tags
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AdminSecHead(
                          AppLocalizations.of(context)!.aboutThisEvent,
                          onEdit: _openEdit,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _event.description,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.65,
                            color: AppColors.text.withValues(alpha: 0.86),
                          ),
                        ),
                        if (_event.tags.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final tag in _event.tags)
                                _Tag(label: tag, accent: accent),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Programme / agenda
                  if (hasProgramme)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _AdminSecHead(
                            AppLocalizations.of(context)!.agenda,
                            onEdit: _openEdit,
                          ),
                          const SizedBox(height: 12),
                          _ProgrammeTimeline(
                            slots: _event.schedule!,
                            accent: accent,
                          ),
                        ],
                      ),
                    ),

                  // Speakers
                  if (hasSpeakers) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                      child: _AdminSecHead(
                        AppLocalizations.of(context)!.speakers,
                        onEdit: _openEdit,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SpeakersRow(speakers: _event.speakers),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Sticky Edit / Delete CTA
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _openEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: Text(
                        AppLocalizations.of(context)!.editEventButton,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.accent,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: _confirmDelete,
                      icon: const Icon(Icons.delete_outline_rounded, size: 17),
                      label: Text(
                        AppLocalizations.of(context)!.deleteEventButton,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(
                          color: Colors.red.withValues(alpha: 0.4),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(13)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hero for the admin event view: poster/gradient, a MANAGING pill, and
/// edit / delete glass buttons.
class _AdminHero extends StatelessWidget {
  final Event event;
  final Color accent;
  final bool isLive;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AdminHero({
    required this.event,
    required this.accent,
    required this.isLive,
    required this.onBack,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.background;
    final hasImage = event.imagePath != null && event.imagePath!.isNotEmpty;
    final topInset = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: SizedBox(
        height: 340,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage)
              _eventHeroImage(path: event.imagePath!, accent: accent)
            else
              _GradientHero(color: accent),

            // Scrim
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.24, 0.5, 0.86, 1.0],
                      colors: [
                        Colors.black.withValues(alpha: 0.45),
                        Colors.transparent,
                        Colors.transparent,
                        bg.withValues(alpha: 0.86),
                        bg,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Nav row: back · MANAGING · edit/delete
            Positioned(
              top: topInset + 8,
              left: 14,
              right: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _GlassButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: onBack,
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(9, 5, 12, 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                      border: Border.all(color: accent.withValues(alpha: 0.45)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          AppLocalizations.of(context)!.managingBadge,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      _GlassButton(icon: Icons.edit_outlined, onTap: onEdit),
                      const SizedBox(width: 9),
                      _GlassButton(
                        icon: Icons.delete_outline_rounded,
                        onTap: onDelete,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Status pill + title
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isLive ? accent : accent.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                      ),
                      child: Text(
                        isLive
                            ? AppLocalizations.of(context)!.happeningNowBadge
                            : AppLocalizations.of(context)!.upcomingBadge,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: isLive ? Colors.white : accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 11),
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.8,
                        height: 1.12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Attendees card for the admin view — initials, name, department.
class _AdminAttendees extends StatelessWidget {
  final Event event;
  final List<User> attendees;
  final Color accent;

  const _AdminAttendees({
    required this.event,
    required this.attendees,
    required this.accent,
  });

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    checkinStore.hydrate(event.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              AppLocalizations.of(context)!.attendees,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
                letterSpacing: -0.2,
              ),
            ),
            const Spacer(),
            ListenableBuilder(
              listenable: checkinStore,
              builder: (_, _) => Text(
                '${AppLocalizations.of(context)!.checkedInCounter(checkinStore.countFor(event.id), attendees.length)} · ${AppLocalizations.of(context)!.totalCount(attendees.length)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.all(Radius.circular(16)),
            border: Border.all(color: AppColors.divider),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: attendees.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  child: Center(
                    child: Text(
                      AppLocalizations.of(context)!.noRsvpsYet,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (final user in attendees)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserProfileScreen(user: user),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.33),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  _initials(user.name),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.text,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userState.displayNameFor(
                                        user.id,
                                        user.name,
                                      ),
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.text,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if ((userState.majors[user.id] ?? '')
                                        .isNotEmpty)
                                      Text(
                                        userState.majors[user.id]!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.secondaryText,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // Manual door check-in toggle
                              ListenableBuilder(
                                listenable: checkinStore,
                                builder: (_, _) {
                                  final checked = checkinStore.isCheckedIn(
                                    event.id,
                                    user.id,
                                  );
                                  return GestureDetector(
                                    onTap: () => checkinStore.toggle(
                                      eventId: event.id,
                                      userId: user.id,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: checked
                                            ? accent
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(100),
                                        ),
                                        border: Border.all(
                                          color: checked
                                              ? accent
                                              : AppColors.divider,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            checked
                                                ? Icons.check_rounded
                                                : Icons
                                                      .radio_button_unchecked_rounded,
                                            size: 13,
                                            color: checked
                                                ? Colors.white
                                                : AppColors.secondaryText,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            AppLocalizations.of(
                                              context,
                                            )!.checkedIn,
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: checked
                                                  ? Colors.white
                                                  : AppColors.secondaryText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.secondaryText,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Section heading with an inline "Edit" affordance (admin view).
class _AdminSecHead extends StatelessWidget {
  final String title;
  final VoidCallback onEdit;

  const _AdminSecHead(this.title, {required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
            letterSpacing: -0.2,
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: onEdit,
          icon: Icon(
            Icons.edit_outlined,
            size: 14,
            color: AppColors.secondaryText,
          ),
          label: Text(
            AppLocalizations.of(context)!.edit,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.secondaryText,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero
// ─────────────────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  final Event event;
  final Color accent;
  final bool saved;
  final bool canDelete;
  final bool canEngage;
  final VoidCallback onBack;
  final VoidCallback onToggleSaved;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const _Hero({
    required this.event,
    required this.accent,
    required this.saved,
    required this.canDelete,
    required this.canEngage,
    required this.onBack,
    required this.onToggleSaved,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;

    // `hero-container` 283:382 — 420 tall on the 402-wide frame, so the crop
    // scales straight off the width instead of the old `width - 40` basis.
    // The taller photo is what gives `hero-bottom-fade` room to melt into the
    // page without swallowing the title block.
    final heroHeight = (MediaQuery.sizeOf(context).width * 1.0448).clamp(
      240.0,
      460.0,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: SizedBox(
        height: heroHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            EventCoverImage(
              event: event,
              color: accent,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.zero,
            ),
            // `top-scrim` 283:384 — a 100px band, not the full height: the
            // frame only darkens the status bar and the glass buttons, and a
            // full-height scrim would fight `hero-bottom-fade` below. The
            // gradient itself stays [MediaScrim]'s semantic ramp (a little
            // stronger than the frame's flat 60% black, and high-contrast
            // aware) rather than a literal copy.
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 100,
                child: MediaScrim(position: MediaScrimPosition.top),
              ),
            ),
            // `hero-bottom-fade` 656:4 / 656:12 — the photo dissolves into the
            // page over the last 140px so there is no hard edge between the
            // cover and the content. Theme-aware: it has to land on exactly
            // the colour the page is painted.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        ClubUpColors.background.withValues(alpha: 0),
                        ClubUpColors.background,
                      ],
                      stops: const [0.25, 0.75],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: topPad,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _HeroGlassButton(
                      icon: Icons.arrow_back_rounded,
                      iconSize: 20,
                      onTap: onBack,
                      semanticLabel: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                    ),
                    Row(
                      children: [
                        if (canEngage) ...[
                          _HeroGlassButton(
                            key: const ValueKey('event-share-action'),
                            icon: Icons.ios_share_rounded,
                            onTap: onShare,
                            semanticLabel: AppLocalizations.of(
                              context,
                            )!.shareAction,
                          ),
                          const SizedBox(width: 8),
                          _HeroGlassButton(
                            icon: saved
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            onTap: onToggleSaved,
                            semanticLabel: AppLocalizations.of(context)!.save,
                          ),
                        ],
                        if (canDelete) ...[
                          if (canEngage) const SizedBox(width: 8),
                          _HeroGlassButton(
                            icon: Icons.delete_outline_rounded,
                            onTap: onDelete,
                            semanticLabel: AppLocalizations.of(context)!.delete,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Nothing else rides the hero. The audience mark moved down to
            // the time badge in `_EventTitleBlock`, where it sits beside the
            // date the way it does on every card that leads here — and off a
            // cover photo that `hero-bottom-fade` half-dissolves anyway.
          ],
        ),
      ),
    );
  }
}

/// `back-button` / `bookmark-button` — a translucent blurred disc so the
/// control reads over any photo.
///
/// The two frames disagree here on purpose. `283:400` (light) frosts the disc
/// almost opaque — `rgba(255,255,255,0.7)` behind an 8px blur, a 40% white
/// hairline and a `#18181B` glyph — while `283:516` (dark) keeps the dim
/// `rgba(255,255,255,0.2)` disc and a white glyph. So this is one of the few
/// spots on the screen where the *treatment*, not just the token, is
/// theme-dependent.
class _HeroGlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? semanticLabel;
  final double iconSize;

  const _HeroGlassButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.semanticLabel,
    this.iconSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    final dark = themeService.isDark;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: dark ? 6 : 8,
              sigmaY: dark ? 6 : 8,
            ),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: dark ? 0.2 : 0.7),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: dark ? 0.2 : 0.4),
                ),
              ),
              child: Icon(
                icon,
                size: iconSize,
                color: dark ? Colors.white : const Color(0xFF18181B),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `title-block` — the time badge, the event name and the location row that
/// the handoff moved off the photo and into the scrolling content.
class _EventTitleBlock extends StatelessWidget {
  final Event event;
  final String whenLabel;

  const _EventTitleBlock({required this.event, required this.whenLabel});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                // `time-badge` — a 10% wash in light, doubled to 20% in dark so
                // the pill still separates from the `#121212` page.
                color: ClubUpColors.accent.withValues(
                  alpha: themeService.isDark ? 0.2 : 0.1,
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                whenLabel,
                style: figtree(
                  size: 12,
                  weight: FontWeight.w700,
                  color: ClubUpColors.accentText,
                ),
              ),
            ),
            const SizedBox(width: 2),
            // A restricted event says so next to its date here too, so the
            // card and the page it opens answer the question the same way.
            ContentAudienceIcon(
              key: ValueKey('content-audience-icon-${event.id}'),
              audience: audienceForEvent(event),
              color: ClubUpColors.accentText,
            ),
          ],
        ),
        const SizedBox(height: 16),
        // `event-title` — the frames set this in Figtree Black (900). Only
        // 400–800 are bundled, so w800 is both the closest weight and the one
        // Flutter would resolve w900 to anyway.
        Text(
          event.title,
          style: figtree(
            size: 34,
            weight: FontWeight.w800,
            color: ClubUpColors.text,
            height: 1.1,
          ),
        ),
        if (event.location.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ClubUpColors.chip,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.place_outlined,
                  size: 16,
                  color: ClubUpColors.muted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  event.location,
                  style: figtree(
                    size: 14,
                    weight: FontWeight.w500,
                    color: ClubUpColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The hairline the handoff puts between sections of the detail screen, with
/// the 32px of air the frames give it on each side baked in.
///
/// `scrollable-content` 283:410 is a 32px-gap flex whose hairlines are just
/// more children, so a rule always sits 32px clear of the section above and
/// below it. Carrying the spacing here keeps that invariant in one place
/// instead of at every call site.
class _EventSectionRule extends StatelessWidget {
  /// The gap above and below every section boundary.
  static const double gap = 32;

  const _EventSectionRule();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(height: gap),
      Divider(height: 1, thickness: 1, color: ClubUpColors.border),
      const SizedBox(height: gap),
    ],
  );
}

/// `tag-*` — a student-side copy. The shared [_Tag] is also used by the club
/// admin event screen, whose design has not been reviewed yet.
///
/// The frames draw the first chip accent-tinted and the rest neutral. Real
/// [Event.tags] are free text, so [accented] is driven purely by position —
/// the leading tag reads as the event's category — rather than by matching
/// words, which would only ever work for English tags.
class _EventTag extends StatelessWidget {
  final String label;
  final bool accented;

  const _EventTag({required this.label, this.accented = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: accented
            ? ClubUpColors.accent.withValues(alpha: 0.08)
            : ClubUpColors.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accented
              ? ClubUpColors.accent.withValues(alpha: 0.2)
              : ClubUpColors.border,
        ),
      ),
      child: Text(
        label,
        style: figtree(
          size: 13,
          weight: FontWeight.w700,
          color: accented ? ClubUpColors.accentText : ClubUpColors.text,
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.42),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _GradientHero extends StatelessWidget {
  final Color color;
  const _GradientHero({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, Color.lerp(color, Colors.black, 0.4)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -40, right: -40, child: _circle(180, 0.07)),
          Positioned(bottom: 30, left: -30, child: _circle(120, 0.05)),
          Positioned(top: 80, left: 90, child: _circle(60, 0.04)),
        ],
      ),
    );
  }

  Widget _circle(double size, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: alpha),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Ticket-style date / time / location card (+ capacity)
// ─────────────────────────────────────────────────────────────────────────────

class _TicketCard extends StatelessWidget {
  final Event event;
  final Color accent;
  final String countdown;
  final bool showCapacity;
  final int takenSeats;

  const _TicketCard({
    required this.event,
    required this.accent,
    required this.countdown,
    required this.showCapacity,
    required this.takenSeats,
  });

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dt = event.dateTime;
    final bg = AppColors.background;
    final hairB = AppColors.divider.withValues(alpha: isDark ? 1 : 0.9);
    final timeStr =
        '${_two(dt.hour)}:${_two(dt.minute)} – '
        '${_two(event.endTime.hour)}:${_two(event.endTime.minute)}';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: AppColors.divider),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        children: [
          // Date stub + info, with vertical tear + perforations
          Stack(
            clipBehavior: Clip.none,
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Date block
                    SizedBox(
                      width: 90,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat.MMM(
                                localeService.languageCode,
                              ).format(dt).toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: accent,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${dt.day}',
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                color: AppColors.text,
                                height: 1,
                                letterSpacing: -1.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat.EEEE(
                                localeService.languageCode,
                              ).format(dt),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Tear line
                    CustomPaint(
                      size: const Size(1, double.infinity),
                      painter: _DashedVLinePainter(color: hairB),
                    ),
                    // Time + location
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _IconLine(
                              icon: Icons.schedule_rounded,
                              accent: accent,
                              title: timeStr,
                              subtitle: '$countdown · ${dt.year}',
                            ),
                            const SizedBox(height: 12),
                            _IconLine(
                              icon: Icons.place_outlined,
                              accent: accent,
                              title: event.location,
                              subtitle: null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Perforation notches on the tear line
              Positioned(left: 81, top: -9, child: _Notch(color: bg)),
              Positioned(left: 81, bottom: -9, child: _Notch(color: bg)),
            ],
          ),

          // Capacity
          if (showCapacity) ...[
            Divider(height: 1, color: AppColors.divider),
            _CapacityBar(
              taken: takenSeats,
              capacity: event.capacity!,
              accent: accent,
            ),
          ],
        ],
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String? subtitle;
  const _IconLine({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: accent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: subtitle == null ? 13.5 : 15,
                  fontWeight: subtitle == null
                      ? FontWeight.w700
                      : FontWeight.w800,
                  color: AppColors.text,
                  letterSpacing: -0.3,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 1),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Notch extends StatelessWidget {
  final Color color;
  const _Notch({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _DashedVLinePainter extends CustomPainter {
  final Color color;
  _DashedVLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    const dash = 4.0, gap = 4.0;
    double y = 6;
    while (y < size.height - 6) {
      canvas.drawLine(Offset(0.5, y), Offset(0.5, y + dash), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedVLinePainter old) => old.color != color;
}

class _CapacityBar extends StatelessWidget {
  final int taken;
  final int capacity;
  final Color accent;
  const _CapacityBar({
    required this.taken,
    required this.capacity,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (capacity == 0 ? 0 : (taken / capacity * 100))
        .clamp(0, 100)
        .round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 13, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                AppLocalizations.of(context)!.seatsTaken(taken, capacity),
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.text.withValues(alpha: 0.8),
                ),
              ),
              const Spacer(),
              Text(
                AppLocalizations.of(context)!.percentFull(pct),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(99)),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 6,
              backgroundColor: AppColors.divider.withValues(alpha: 0.6),
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Host card
// ─────────────────────────────────────────────────────────────────────────────

class _HostCard extends StatelessWidget {
  final Event event;
  final Color accent;
  final VoidCallback onView;

  const _HostCard({
    required this.event,
    required this.accent,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final club = clubForId(event.clubId);
    if (club == null) return const SizedBox.shrink();
    final following = userState.isFollowing(club.id);

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onView,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                ClubAvatar(
                  clubId: club.id,
                  clubName: club.name,
                  color: accent,
                  imageUrl: club.logoUrl,
                  size: 40,
                  fontSize: 16,
                  shape: 'circle',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.hostedBy,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: figtree(
                          size: 11,
                          weight: FontWeight.w600,
                          color: ClubUpColors.muted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        club.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: figtree(
                          size: 14,
                          weight: FontWeight.w700,
                          color: ClubUpColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => handleFollowTap(context, club.id, () {}),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: ClubUpColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: ClubUpColors.accent.withValues(alpha: 0.15),
              ),
            ),
            child: Text(
              following ? l10n.followingCheckLabel : l10n.follow,
              style: figtree(
                size: 12,
                weight: FontWeight.w700,
                color: ClubUpColors.accentText,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RegistrationCard extends StatelessWidget {
  final String url;
  final Color accent;
  const _RegistrationCard({required this.url, required this.accent});

  String get _pretty => url.replaceFirst(RegExp(r'^https?://'), '');

  Future<void> _open(BuildContext context) async {
    final uri = _externalUri(url);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.couldNotOpenRegistrationForm,
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: accent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _open(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.all(Radius.circular(16)),
          border: Border.all(color: accent.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: Icon(Icons.link_rounded, color: accent, size: 19),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        AppLocalizations.of(context)!.registration,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.open_in_new_rounded,
                        size: 12,
                        color: AppColors.secondaryText,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppLocalizations.of(context)!.signUpOnClubForm(_pretty),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: accent, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────────────

/// The 18px ExtraBold section heading the frames use for "About the event",
/// "Speakers" and "Programme Schedule". Student-side only — the admin screen
/// has its own [_AdminSecHead].
class _SecHead extends StatelessWidget {
  final String text;
  const _SecHead(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: figtree(
        size: 18,
        weight: FontWeight.w800,
        color: ClubUpColors.text,
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color accent;
  const _Tag({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: accent,
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Programme timeline
// ─────────────────────────────────────────────────────────────────────────────

class _ProgrammeTimeline extends StatelessWidget {
  final List<EventSlot> slots;
  final Color accent;
  const _ProgrammeTimeline({required this.slots, required this.accent});

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Stack(
        children: [
          // Vertical rail
          Positioned(
            left: 5,
            top: 10,
            bottom: 16,
            child: Container(width: 2, color: AppColors.divider),
          ),
          Column(
            children: [
              for (final slot in slots)
                _SlotRow(slot: slot, accent: accent, fmt: _fmt),
            ],
          ),
        ],
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  final EventSlot slot;
  final Color accent;
  final String Function(DateTime) fmt;
  const _SlotRow({required this.slot, required this.accent, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final key = slot.isHighlighted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dot
          SizedBox(
            width: 12,
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Center(
                child: Container(
                  width: key ? 12 : 9,
                  height: key ? 12 : 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: key ? accent : AppColors.background,
                    border: Border.all(
                      color: key
                          ? accent
                          : AppColors.divider.withValues(alpha: 0.9),
                      width: 2,
                    ),
                    boxShadow: key
                        ? [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.13),
                              blurRadius: 0,
                              spreadRadius: 4,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 40,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                fmt(slot.time),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: key ? accent : AppColors.secondaryText,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: key ? FontWeight.w800 : FontWeight.w600,
                    color: AppColors.text,
                    letterSpacing: -0.2,
                  ),
                ),
                if (slot.subtitle != null && slot.subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    slot.subtitle!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Speakers row
// ─────────────────────────────────────────────────────────────────────────────

class _SpeakersRow extends StatelessWidget {
  final List<EventSpeaker> speakers;
  const _SpeakersRow({required this.speakers});

  static const List<int> _hues = [220, 300, 35, 155, 265, 10];

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return parts.take(2).map((w) => w[0].toUpperCase()).join();
  }

  Future<void> _openLinkedIn(BuildContext context, EventSpeaker s) async {
    final uri = _externalUri(s.linkedin ?? '');
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.couldNotOpenLinkedIn(s.name),
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        itemCount: speakers.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final s = speakers[i];
          final hue = _hues[i % _hues.length].toDouble();
          final avatarBg = HSLColor.fromAHSL(1, hue, 0.45, 0.9).toColor();
          final avatarFg = HSLColor.fromAHSL(1, hue, 0.5, 0.38).toColor();
          final hasLink = s.linkedin != null && s.linkedin!.trim().isNotEmpty;
          return GestureDetector(
            onTap: hasLink ? () => _openLinkedIn(context, s) : null,
            child: Container(
              width: 110,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.all(Radius.circular(15)),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: avatarBg,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _initials(s.name),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: avatarFg,
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    s.name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                      height: 1.2,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (s.role.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      s.role,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Student-side speakers, programme and registration.
//
// The shared [_SpeakersRow], [_ProgrammeTimeline] and [_RegistrationCard]
// above are also mounted by [ClubEventAdminScreen], whose design has not been
// reviewed — so the new frames get their own copies here rather than restyling
// widgets two screens depend on. Same call the file already made for
// [_EventTag] vs [_Tag].
// ─────────────────────────────────────────────────────────────────────────────

/// The lift under a `speaker-card`: `0 6px 9px rgba(0,0,0,0.05)` in light,
/// deepened to `0 10px 12px rgba(0,0,0,0.25)` on the `#121212` page.
List<BoxShadow> _eventCardShadow() => [
  BoxShadow(
    color: themeService.isDark
        ? const Color(0x40000000)
        : const Color(0x0D000000),
    offset: Offset(0, themeService.isDark ? 10 : 6),
    blurRadius: themeService.isDark ? 12 : 9,
  ),
];

/// `speakers-section` 328:4 — one full-width card per speaker, stacked.
///
/// Replaces the old 110px-wide horizontal carousel: the frames give each
/// speaker the whole column width, which is what makes room for the LinkedIn
/// address to be shown in full rather than as a tappable avatar.
class _EventSpeakerCards extends StatelessWidget {
  final List<EventSpeaker> speakers;

  const _EventSpeakerCards({required this.speakers});

  Future<void> _openLinkedIn(BuildContext context, EventSpeaker s) async {
    final uri = _externalUri(s.linkedin ?? '');
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.couldNotOpenLinkedIn(s.name),
            ),
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < speakers.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _EventSpeakerCard(
            speaker: speakers[i],
            onOpenLink: () => _openLinkedIn(context, speakers[i]),
          ),
        ],
      ],
    );
  }
}

class _EventSpeakerCard extends StatelessWidget {
  final EventSpeaker speaker;
  final VoidCallback onOpenLink;

  const _EventSpeakerCard({required this.speaker, required this.onOpenLink});

  @override
  Widget build(BuildContext context) {
    final link = speaker.linkedin?.trim() ?? '';
    final hasLink = link.isNotEmpty;

    return GestureDetector(
      onTap: hasLink ? onOpenLink : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ClubUpColors.card,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          border: Border.all(color: ClubUpColors.border),
          boxShadow: _eventCardShadow(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              speaker.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: figtree(
                size: 16,
                weight: FontWeight.w800,
                color: ClubUpColors.text,
              ),
            ),
            if (speaker.role.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                speaker.role,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: figtree(
                  size: 13,
                  weight: FontWeight.w400,
                  color: ClubUpColors.muted,
                ),
              ),
            ],
            if (hasLink) ...[
              const SizedBox(height: 6),
              // `speaker-link` 328:12 — the light frame wraps the address in a
              // bordered chip; the dark frame leaves it as a bare row. The chip
              // is the finished treatment, so both themes get it.
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: ClubUpColors.background,
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    border: Border.all(color: ClubUpColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Material ships no LinkedIn mark. The event wizard
                      // settled on this glyph for the same field in the same
                      // handoff, so the two views stay consistent.
                      Icon(
                        Icons.business_center_outlined,
                        size: 14,
                        color: ClubUpColors.muted,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          link,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: figtree(
                            size: 13,
                            weight: FontWeight.w400,
                            color: ClubUpColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// `programme-section` 328:16 — a flat list of sessions, each a dot, a title
/// and a right-aligned clock, separated by hairlines. No vertical rail: the
/// frames dropped the rail the admin timeline still draws.
class _EventProgramme extends StatelessWidget {
  final List<EventSlot> slots;

  const _EventProgramme({required this.slots});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < slots.length; i++)
          _EventSessionRow(
            slot: slots[i],
            // `session-row` 328:19 carries the hairline, 328:27 does not — the
            // rule sits between rows, never under the last one.
            showDivider: i < slots.length - 1,
          ),
      ],
    );
  }
}

class _EventSessionRow extends StatelessWidget {
  final EventSlot slot;
  final bool showDivider;

  const _EventSessionRow({required this.slot, required this.showDivider});

  /// 24-hour, as the rest of the app formats event times. The frames read
  /// `7:00 PM`, but Turkish is a 24-hour locale and the wizard that produced
  /// these slots writes them the same way.
  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final subtitle = slot.subtitle?.trim() ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: ClubUpColors.border))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // `timeline-dot` — 10px, nudged down so it centres on the title's
          // first line rather than the top of the row.
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ClubUpColors.accent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: figtree(
                    size: 15,
                    weight: FontWeight.w800,
                    color: ClubUpColors.text,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: figtree(
                      size: 13,
                      weight: FontWeight.w400,
                      color: ClubUpColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 14,
                color: ClubUpColors.muted,
              ),
              const SizedBox(height: 4),
              Text(
                _fmt(slot.time),
                style: figtree(
                  size: 13,
                  weight: FontWeight.w700,
                  color: ClubUpColors.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// `registration-section` 328:35 — the external sign-up link, promoted from a
/// tinted row to the page's one filled call to action.
///
/// Still only mounted when the event actually carries a `registrationUrl`; a
/// button that opens nothing would be worse than no button.
class _EventRegistrationCta extends StatelessWidget {
  final String url;

  const _EventRegistrationCta({required this.url});

  Future<void> _open(BuildContext context) async {
    final uri = _externalUri(url);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.couldNotOpenRegistrationForm,
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: ClubUpColors.accent,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Deliberately smaller than the 18px section heads — the frames label
        // this one at 14px, letting the button itself carry the weight.
        Text(
          l10n.registration,
          style: figtree(
            size: 14,
            weight: FontWeight.w700,
            color: ClubUpColors.text,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          key: const ValueKey('event-registration-cta'),
          onTap: () => _open(context),
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ClubUpColors.accent,
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              boxShadow: [
                BoxShadow(
                  color: ClubUpColors.accent.withValues(alpha: 0.2),
                  offset: const Offset(0, 10),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link_rounded, size: 16, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  l10n.reserveMySpot,
                  style: figtree(
                    size: 15,
                    weight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Event social sections — attendees and friend invitations
// ─────────────────────────────────────────────────────────────────────────────

/// The "friends going" row on the student event detail.
///
/// [followedUserIds] are the attendees this viewer may see — everyone else is
/// already filtered out by [attendeeVisibilityFor]. A student is shown no
/// number at all here, only the faces and the label, so [count] survives
/// purely as the fallback for a viewer with no faces to show: a club that gets
/// the headcount alone, or a student who is the one person they can see going.
/// Faces are therefore only ever present for a student — the hosting club
/// never reaches this widget, since `build` hands it `ClubEventAdminScreen`.
/// [onTap] is null when the list cannot be opened, which also drops the
/// chevron.
class _AttendingCard extends StatelessWidget {
  const _AttendingCard({
    required this.followedUserIds,
    required this.count,
    required this.onTap,
  });

  final List<String> followedUserIds;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (count == 0 && followedUserIds.isEmpty) return const SizedBox.shrink();

    final hasFaces = followedUserIds.isNotEmpty;

    return GestureDetector(
      key: const ValueKey('event-attending-card'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (hasFaces) _DetailAvatarStack(userIds: followedUserIds),
          // `going-count` 294:12 — the label moved off the bare row and into a
          // bordered chip pinned to the trailing edge.
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: ClubUpColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ClubUpColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      hasFaces
                          ? (followedUserIds.length == 1
                                ? S.oneFriendGoingLabel
                                : S.friendsGoingLabel)
                          : l10n.goingCount(count),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: figtree(
                        size: 13,
                        weight: hasFaces ? FontWeight.w700 : FontWeight.w600,
                        // Primary text, not the accent the frame draws: white
                        // on the dark card, and still legible on the light
                        // one, where a literal white would vanish.
                        color: hasFaces
                            ? ClubUpColors.text
                            : ClubUpColors.muted,
                      ),
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 14,
                      color: ClubUpColors.muted,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Best-known display name for an attendee id — checks the people directory
/// and the seeded user list before falling back to the raw id, so the avatar
/// always has an initial to draw.
String _attendeeDisplayName(String userId) {
  final person =
      peopleService.cachedPeople.cast<User?>().firstWhere(
        (u) => u?.id == userId,
        orElse: () => null,
      ) ??
      users.cast<User?>().firstWhere(
        (u) => u?.id == userId,
        orElse: () => null,
      );
  return userState.displayNameFor(userId, person?.name ?? userId);
}

/// `attendee-avatars` 294:6 — up to five 32px discs, each pulled 10px over the
/// one before it.
class _DetailAvatarStack extends StatelessWidget {
  final List<String> userIds;

  /// Disc diameter and the step between two neighbours; the 10px difference is
  /// the overlap the frame draws with `mr-[-10px]`.
  static const double _size = 32;
  static const double _step = 22;

  const _DetailAvatarStack({required this.userIds});

  @override
  Widget build(BuildContext context) {
    final shown = userIds.take(5).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: _size,
      width: _size + (shown.length - 1) * _step,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * _step,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ClubUpColors.background, width: 2),
                ),
                child: UserAvatar(
                  userId: shown[i],
                  name: _attendeeDisplayName(shown[i]),
                  size: _size,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BringFriendsSection extends StatelessWidget {
  const _BringFriendsSection({
    required this.friends,
    required this.invitedFriendIds,
    required this.onInvite,
    required this.onSeeAll,
    required this.onShare,
  });

  final List<User> friends;
  final Set<String> invitedFriendIds;
  final ValueChanged<User> onInvite;
  final VoidCallback onSeeAll;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (friends.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ClubUpColors.chip,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.send_rounded,
                size: 16,
                color: ClubUpColors.muted,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.shareWithFriends,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: figtree(
                  size: 16,
                  weight: FontWeight.w700,
                  color: ClubUpColors.text,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // `quick-send-row` — one tap per friend, the row scrolls sideways.
        SizedBox(
          height: 86,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: friends.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final friend = friends[i];
              final invited = invitedFriendIds.contains(friend.id);
              return SizedBox(
                width: 64,
                child: AnimatedSwitcher(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 420),
                  reverseDuration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    alignment: Alignment.topCenter,
                    children: [...previousChildren, ?currentChild],
                  ),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.32, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: ScaleTransition(
                        scale: Tween<double>(
                          begin: 0.92,
                          end: 1,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                  ),
                  child: _QuickInviteFriend(
                    key: ValueKey('event-invite-${friend.id}'),
                    friend: friend,
                    invited: invited,
                    onInvite: () => onInvite(friend),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // `btn-send-to-more-friends` — opens the full invite list, which is
        // the `event-detail-invite` frame.
        GestureDetector(
          onTap: onSeeAll,
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ClubUpColors.card,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: ClubUpColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.send_outlined, size: 18, color: ClubUpColors.text),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    l10n.sendToMoreFriends,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: figtree(
                      size: 13,
                      weight: FontWeight.w700,
                      color: ClubUpColors.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickInviteFriend extends StatefulWidget {
  const _QuickInviteFriend({
    super.key,
    required this.friend,
    required this.invited,
    required this.onInvite,
  });

  final User friend;
  final bool invited;
  final VoidCallback onInvite;

  @override
  State<_QuickInviteFriend> createState() => _QuickInviteFriendState();
}

class _QuickInviteFriendState extends State<_QuickInviteFriend>
    with SingleTickerProviderStateMixin {
  late final AnimationController _inviteController;
  late final Animation<double> _inviteScale;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _inviteController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
      value: widget.invited ? 1 : 0,
    );
    _inviteScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.90,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 24,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.90,
          end: 1.07,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 36,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.07,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 40,
      ),
    ]).animate(_inviteController);
  }

  @override
  void didUpdateWidget(covariant _QuickInviteFriend oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.invited && widget.invited) {
      _inviteController.forward(from: 0);
    } else if (oldWidget.invited && !widget.invited) {
      _inviteController.value = 0;
    }
  }

  @override
  void dispose() {
    _inviteController.dispose();
    super.dispose();
  }

  void _setPressed(bool pressed) {
    if (_pressed == pressed || widget.invited) return;
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 360);
    final displayName = userState.displayNameFor(
      widget.friend.id,
      widget.friend.name,
    );
    final firstName = displayName.split(' ').first;

    final avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          key: ValueKey('event-quick-invite-avatar-${widget.friend.id}'),
          duration: duration,
          curve: Curves.easeOutCubic,
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.invited ? ClubUpColors.accent : Colors.transparent,
              width: 2,
            ),
            boxShadow: widget.invited
                ? [
                    BoxShadow(
                      color: ClubUpColors.accent.withValues(alpha: 0.18),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : const [],
          ),
          child: AnimatedScale(
            scale: widget.invited ? 0.90 : 1,
            duration: duration,
            curve: Curves.easeOutCubic,
            child: IgnorePointer(
              child: UserAvatar(
                userId: widget.friend.id,
                name: displayName,
                size: 56,
                fontSize: 20,
              ),
            ),
          ),
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: AnimatedSwitcher(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 420),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.2, end: 1).animate(animation),
                child: child,
              ),
            ),
            child: widget.invited
                ? Container(
                    key: const ValueKey('invited-check'),
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ClubUpColors.accent,
                      border: Border.all(
                        color: ClubUpColors.background,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 11,
                      color: Colors.white,
                    ),
                  )
                : const SizedBox(
                    key: ValueKey('invite-check-placeholder'),
                    width: 20,
                    height: 20,
                  ),
          ),
        ),
      ],
    );

    return SizedBox(
      width: 64,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Semantics(
          button: true,
          enabled: !widget.invited,
          label: widget.invited ? l10n.invited : displayName,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: widget.invited ? null : (_) => _setPressed(true),
            onTapCancel: widget.invited ? null : () => _setPressed(false),
            onTapUp: widget.invited ? null : (_) => _setPressed(false),
            onTap: widget.invited ? null : widget.onInvite,
            child: AnimatedScale(
              scale: _pressed ? 0.94 : 1,
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 120),
              curve: Curves.easeOutCubic,
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _inviteScale,
                    child: avatar,
                    builder: (_, child) => Transform.scale(
                      scale: reduceMotion ? 1 : _inviteScale.value,
                      child: child,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 16,
                    child: AnimatedSwitcher(
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 320),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.28),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: Text(
                        widget.invited ? l10n.invited : firstName,
                        key: ValueKey(widget.invited),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: figtree(
                          size: 12,
                          weight: FontWeight.w600,
                          color: widget.invited
                              ? ClubUpColors.accentText
                              : ClubUpColors.text,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StickyCta extends StatefulWidget {
  final Event event;
  final Color accent;
  const _StickyCta({required this.event, required this.accent});

  @override
  State<_StickyCta> createState() => _StickyCtaState();
}

class _StickyCtaState extends State<_StickyCta> {
  bool _remind = false;

  void _toggleRemind() {
    HapticFeedback.selectionClick();
    setState(() => _remind = !_remind);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            _remind
                ? AppLocalizations.of(context)!.reminderSetMsg
                : AppLocalizations.of(context)!.reminderRemoved,
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _remind ? widget.accent : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final userId =
        authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

    // The three actions float as a bare block — no panel, no fill, no blur and
    // no shadow behind them. Each pill carries its own opaque fill and
    // hairline, so they stay legible over whatever scrolls past. Inset to the
    // page's own 20pt gutter so they line up with the content above.
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(
          key: const ValueKey('event-sticky-actions'),
          mainAxisSize: MainAxisSize.min,
          children: [
            ListenableBuilder(
              listenable: rsvpStore,
              builder: (_, _) {
                final attending = rsvpStore.isAttending(widget.event.id);
                final pending = rsvpStore.isPending(widget.event.id);
                return GestureDetector(
                  onTap: pending || userId.isEmpty
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          unawaited(
                            rsvpStore.toggle(
                              widget.event.id,
                              userId,
                              event: widget.event,
                            ),
                          );
                        },
                  child: AnimatedContainer(
                    key: const ValueKey('event-rsvp-action'),
                    duration: const Duration(milliseconds: 180),
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      // The "Going" state was transparent, which read
                      // as the old bar's own fill behind it. With no
                      // panel there it has to paint that fill itself,
                      // or the page shows through the pill.
                      color: attending
                          ? ClubUpColors.card
                          : ClubUpColors.accent,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: attending
                            ? ClubUpColors.accent
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      attending ? l10n.going : l10n.imGoing,
                      style: figtree(
                        size: 14,
                        weight: FontWeight.w700,
                        color: attending
                            ? ClubUpColors.accentText
                            : Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: AddToCalendarButton(
                    key: const ValueKey('event-add-to-calendar-action'),
                    event: widget.event,
                    color: widget.accent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SecondaryActionButton(
                    key: const ValueKey('event-reminder-action'),
                    icon: _remind
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_none_rounded,
                    label: l10n.remindMe,
                    active: _remind,
                    onTap: _toggleRemind,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// `btn-add-to-calendar` / `btn-remind-me` — compact outlined pills under the
/// main CTA.
class _SecondaryActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SecondaryActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ClubUpColors.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: active ? ClubUpColors.accent : ClubUpColors.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: active ? ClubUpColors.accentText : ClubUpColors.text,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: figtree(
                  size: 12,
                  weight: FontWeight.w700,
                  color: active ? ClubUpColors.accentText : ClubUpColors.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
