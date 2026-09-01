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

  /// The whole floating bar. `tut-home-nav` spotlights the bar as one shape
  /// rather than a single tab, so it needs its own anchor.
  static const String navBar = 'nav.bar';

  static const String homeFeedToggle = 'home.feedToggle';

  /// The This Week search field (`tut-events-filters`).
  static const String eventsSearch = 'events.search';
  static const String eventsRsvp = 'events.rsvp';
  static const String searchField = 'search.field';
  static const String chatsCompose = 'chats.compose';

  /// The Clubs / Friends lane pill in the Chats header (`tut-chats-tabs`).
  static const String chatsLaneDropdown = 'chats.laneDropdown';

  /// The student profile's identity card (`tut-profile-hero`) and the
  /// My Clubs section under it (`tut-profile-clubs`).
  static const String profileHero = 'profile.hero';
  static const String profileClubs = 'profile.clubs';

  /// The pinned-announcements panel inside a club chat. Not a tour stop — it
  /// anchors the standalone page tip (`tut-announcements`).
  static const String announcements = 'chats.announcements';

  // Club-admin-only anchors (see clubAdminSteps in onboarding_steps.dart).
  static const String clubCreateButton = 'club.createButton';
  static const String clubQuickComposer = 'club.quickComposer';
  static const String clubProfileTabs = 'club.profileTabs';
  static const String clubProfileSettings = 'club.profileSettings';
}

final onboardingAnchors = OnboardingAnchors();
