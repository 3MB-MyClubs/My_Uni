import 'package:flutter/widgets.dart';

/// Shared registry of [GlobalKey]s used to anchor onboarding tour stops to the
/// real on-screen elements they describe.
///
/// Screens attach a key with `key: onboardingAnchors.keyFor(OnboardingAnchors.id)`
/// and the step list references the same id, so one stable [GlobalKey] is
/// shared between the widget and the spotlight's measurement code — no keys
/// need to be threaded through constructors.
///
/// Each id must label exactly one widget that is mounted at a time. List items
/// (which would collide) anchor only their first element (index 0).
class OnboardingAnchors {
  final Map<String, GlobalKey> _keys = {};

  /// Returns the stable key for [id], creating it on first use.
  GlobalKey keyFor(String id) => _keys.putIfAbsent(id, () => GlobalKey());

  // ── Anchor ids ────────────────────────────────────────────────────────────
  // Kept as constants so the screens and the step list can't drift apart.
  static const String navHome = 'nav.home';
  static const String navEvents = 'nav.events';
  static const String navSearch = 'nav.search';
  static const String navChats = 'nav.chats';
  static const String navProfile = 'nav.profile';
  static const String homeFeedToggle = 'home.feedToggle';
  static const String eventsRsvp = 'events.rsvp';
  static const String searchField = 'search.field';
  static const String chatsCompose = 'chats.compose';

  // Club-admin-only anchors (see clubAdminSteps in onboarding_steps.dart).
  static const String clubCreateButton = 'club.createButton';
  static const String clubQuickComposer = 'club.quickComposer';
  static const String clubProfileTabs = 'club.profileTabs';
  static const String clubProfileSettings = 'club.profileSettings';
}

final onboardingAnchors = OnboardingAnchors();
