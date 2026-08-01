import 'package:flutter/cupertino.dart';

/// A route used only by the chats experience.
///
/// [CupertinoPageRoute] supplies an interactive leading-edge back gesture on
/// both iOS and Android. The page follows the user's finger and either pops or
/// settles back into place depending on the drag distance and velocity.
class ChatPageRoute<T> extends CupertinoPageRoute<T> {
  ChatPageRoute({required super.builder, super.settings, super.requestFocus});
}
