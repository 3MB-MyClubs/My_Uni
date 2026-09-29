import 'dart:async';

import 'package:app_links/app_links.dart' as native_links;
import 'package:flutter/foundation.dart';

import 'app_links.dart';

/// Links printed in event share QR codes and sent in event chat messages.
abstract final class EventShareLink {
  static final _eventIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

  static String forEvent(String eventId) => '${AppLinks.webApp}/event/$eventId';

  static String? eventIdFrom(Uri uri) {
    if (uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    final isWebLink =
        uri.scheme == 'https' &&
        uri.host == Uri.parse(AppLinks.webApp).host &&
        uri.pathSegments.length == 2 &&
        uri.pathSegments.first == 'event';
    final isLegacyLink =
        uri.scheme == 'kuclubs' &&
        uri.host == 'event' &&
        uri.pathSegments.length == 1;
    if (!isWebLink && !isLegacyLink) return null;
    final eventId = uri.pathSegments.last;
    return _eventIdPattern.hasMatch(eventId) ? eventId : null;
  }
}

/// Keeps an incoming event link until the app has finished login and startup.
class EventLinkCoordinator extends ChangeNotifier {
  StreamSubscription<Uri>? _subscription;
  String? _pendingEventId;

  String? get pendingEventId => _pendingEventId;

  void start() {
    if (kIsWeb || _subscription != null) return;
    _subscription = native_links.AppLinks().uriLinkStream.listen(
      receive,
      onError: (Object _) {},
    );
  }

  void receive(Uri uri) {
    final eventId = EventShareLink.eventIdFrom(uri);
    if (eventId == null || eventId == _pendingEventId) return;
    _pendingEventId = eventId;
    notifyListeners();
  }

  String? takePendingEventId() {
    final eventId = _pendingEventId;
    _pendingEventId = null;
    return eventId;
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

final eventLinkCoordinator = EventLinkCoordinator();
