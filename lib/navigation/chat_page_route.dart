import 'package:flutter/cupertino.dart';

/// The route used by the chats experience.
///
/// This predates the app-wide slide transition and survives only because ~28
/// call sites name it. The gesture is no longer what makes it special -- every
/// route in the app now has the leading-edge back swipe, supplied by the
/// `pageTransitionsTheme` in `AppTheme.build`.
///
/// [CupertinoPageRoute] builds its own transition instead of reading
/// [ThemeData.pageTransitionsTheme], so the two overrides below are what keep
/// chat navigation indistinguishable from every other push in the app.
class ChatPageRoute<T> extends CupertinoPageRoute<T> {
  ChatPageRoute({required super.builder, super.settings, super.requestFocus});

  /// Drops to zero when the platform asks for reduced motion, matching the rest
  /// of the app. The back gesture keeps working: a drag writes the route
  /// controller's value directly rather than running this animation.
  @override
  Duration get transitionDuration =>
      (MediaQuery.maybeOf(navigator!.context)?.disableAnimations ?? false)
      ? Duration.zero
      : super.transitionDuration;

  /// Cupertino routes tint the page underneath and Material routes do not. Now
  /// that both slide the same way, that tint would be the only thing setting
  /// chat navigation apart.
  @override
  Color? get barrierColor => null;
}
