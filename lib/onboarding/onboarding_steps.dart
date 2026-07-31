import 'package:flutter/material.dart';

import '../services/app_strings.dart';
import 'onboarding_anchors.dart';

/// One stop on the campus tour.
class OnboardingStep {
  /// Resolved lazily so a live language switch mid-tour picks up the new copy.
  final String Function() guideLine;
  final IconData icon;
  final GlobalKey targetKey;

  /// The bottom-nav tab that must be selected for the target to be on screen.
  final int tabIndex;

  /// Whether a tap on the spotlit target is passed through to the real
  /// control. False for targets that push a route or open a sheet/keyboard —
  /// the tap still advances the tour, but the route must not cover it.
  final bool tapThrough;

  OnboardingStep({
    required this.guideLine,
    required this.icon,
    required this.targetKey,
    required this.tabIndex,
    this.tapThrough = true,
  });

  String get text => guideLine();
}

/// The student tour, in the order the tabs sit in the nav bar.
List<OnboardingStep> studentOnboardingSteps() => <OnboardingStep>[
  OnboardingStep(
    guideLine: () => S.onboardingStudentHome,
    icon: Icons.home_rounded,
    targetKey: onboardingAnchors.keyFor(OnboardingAnchors.navHome),
    tabIndex: 0,
  ),
  OnboardingStep(
    guideLine: () => S.onboardingStudentFeedToggle,
    icon: Icons.tune_rounded,
    targetKey: onboardingAnchors.keyFor(OnboardingAnchors.homeFeedToggle),
    tabIndex: 0,
  ),
  OnboardingStep(
    guideLine: () => S.onboardingStudentRsvp,
    icon: Icons.event_available_rounded,
    targetKey: onboardingAnchors.keyFor(OnboardingAnchors.eventsRsvp),
    tabIndex: 1,
  ),
  OnboardingStep(
    guideLine: () => S.onboardingStudentExplore,
    icon: Icons.search_rounded,
    targetKey: onboardingAnchors.keyFor(OnboardingAnchors.searchField),
    tabIndex: 2,
    // Passing the tap through would just pop the keyboard open mid-tour.
    tapThrough: false,
  ),
  OnboardingStep(
    guideLine: () => S.onboardingStudentCompose,
    icon: Icons.edit_square,
    targetKey: onboardingAnchors.keyFor(OnboardingAnchors.chatsCompose),
    tabIndex: 3,
    // Opens the new-chat sheet, which would cover the tour.
    tapThrough: false,
  ),
  OnboardingStep(
    guideLine: () => S.onboardingStudentProfile,
    icon: Icons.account_circle_rounded,
    targetKey: onboardingAnchors.keyFor(OnboardingAnchors.navProfile),
    tabIndex: 4,
  ),
];

/// The club-admin tour. Their nav has no Search tab and a center "+" button;
/// their Profile tab is the club's own management view.
List<OnboardingStep> clubAdminOnboardingSteps({
  bool usesModerationTab = false,
}) => <OnboardingStep>[
  OnboardingStep(
    guideLine: () => S.onboardingClubComposer,
    icon: Icons.campaign_rounded,
    targetKey: onboardingAnchors.keyFor(OnboardingAnchors.clubQuickComposer),
    tabIndex: 0,
    // Opens the Big Picture composer sheet.
    tapThrough: false,
  ),
  OnboardingStep(
    guideLine: () => S.onboardingClubCreateEvent,
    icon: Icons.add_circle_rounded,
    targetKey: onboardingAnchors.keyFor(OnboardingAnchors.clubCreateButton),
    tabIndex: 0,
    // Opens CreateEventScreen as a fullscreen dialog.
    tapThrough: false,
  ),
  OnboardingStep(
    guideLine: () =>
        usesModerationTab ? S.onboardingClubModeration : S.onboardingClubChats,
    icon: usesModerationTab ? Icons.shield_rounded : Icons.chat_bubble_rounded,
    targetKey: onboardingAnchors.keyFor(OnboardingAnchors.navChats),
    tabIndex: 3,
  ),
  OnboardingStep(
    guideLine: () => S.onboardingClubProfileTabs,
    icon: Icons.groups_rounded,
    targetKey: onboardingAnchors.keyFor(OnboardingAnchors.clubProfileTabs),
    tabIndex: 4,
  ),
  OnboardingStep(
    guideLine: () => S.onboardingClubSettings,
    icon: Icons.settings_rounded,
    targetKey: onboardingAnchors.keyFor(OnboardingAnchors.clubProfileSettings),
    tabIndex: 4,
    // Pushes the settings route.
    tapThrough: false,
  ),
];
