import 'package:flutter/widgets.dart';

/// Shared registry of [GlobalKey]s used to anchor interactive tutorial steps to
/// the real on-screen elements they describe.
///
/// Screens attach a key to a widget with `key: tutorialAnchors.keyFor('id')`,
/// and the tutorial step list references the same id. Because each id maps to a
/// single, stable [GlobalKey] for the lifetime of the app, the same instance is
/// shared between the widget and the overlay's measurement code — no keys need
/// to be threaded through constructors.
///
/// Each id must label exactly one widget that is mounted at a time. List items
/// (which would collide) anchor only their first element (index 0).
class TutorialAnchors {
  final Map<String, GlobalKey> _keys = {};

  /// Returns the stable key for [id], creating it on first use.
  GlobalKey keyFor(String id) => _keys.putIfAbsent(id, () => GlobalKey());

  // ── Anchor ids ────────────────────────────────────────────────────────────
  // Kept as constants so the screens and the step list can't drift apart.
  static const String navBar = 'nav.bar';
  static const String homeFeedToggle = 'home.feedToggle';
  static const String eventsRsvp = 'events.rsvp';
  static const String searchField = 'search.field';
  static const String alertsMarkAllRead = 'alerts.markAllRead';
  static const String profileHeader = 'profile.header';
  static const String profileSettings = 'profile.settings';
}

final tutorialAnchors = TutorialAnchors();
