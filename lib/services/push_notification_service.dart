import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_service.dart';
import 'locale_service.dart';
import 'supabase_config.dart';

class PushNotificationTarget {
  const PushNotificationTarget({
    required this.type,
    this.notificationType,
    this.targetId,
    this.notificationId,
  });

  /// Navigation destination such as `post`, `event`, `user`, or `message`.
  final String type;

  /// The event that produced the notification, such as `group_message`.
  final String? notificationType;
  final String? targetId;
  final String? notificationId;

  factory PushNotificationTarget.fromData(Map<String, dynamic> data) {
    String? value(String key) {
      final text = data[key]?.toString().trim() ?? '';
      return text.isEmpty ? null : text;
    }

    return PushNotificationTarget(
      // `type` describes the event (for example `club_post`), while
      // `target_type` is the screen the user should be sent to.
      type: value('target_type') ?? value('type') ?? 'notification',
      notificationType: value('type'),
      targetId: value('target_id'),
      notificationId: value('notification_id'),
    );
  }
}

class PushNotificationService extends ChangeNotifier {
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool _initialized = false;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<Map<String, dynamic>>? _localTapSubscription;
  PushNotificationTarget? _pendingTarget;

  PushNotificationTarget? takePendingTarget() {
    final target = _pendingTarget;
    _pendingTarget = null;
    return target;
  }

  Future<void> initialize() async {
    if (_initialized || !isSupported) return;
    _initialized = true;

    await notificationService.initialize();
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: false,
          badge: false,
          sound: false,
        );

    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleOpenedMessage,
    );
    _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) => unawaited(_upsertToken(token)),
    );
    _localTapSubscription = notificationService.remoteNotificationTaps.listen(
      _queueTarget,
    );
    localeService.addListener(_handleLocaleChanged);

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _handleOpenedMessage(initialMessage);
  }

  Future<void> activateForCurrentUser() async {
    if (!isSupported || !SupabaseConfig.isConfigured) return;
    await initialize();

    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) return;

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final hasApnsToken = await _waitForApnsToken();
      if (!hasApnsToken) return;
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;
    if (kDebugMode) debugPrint('ClubUp FCM token: $token');
    await _upsertToken(token);
  }

  Future<bool> _waitForApnsToken() async {
    for (var attempt = 0; attempt < 12; attempt++) {
      if (await FirebaseMessaging.instance.getAPNSToken() != null) return true;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return false;
  }

  Future<void> _upsertToken(String token) async {
    if (!SupabaseConfig.isConfigured) return;
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    try {
      await client.from('push_devices').upsert({
        'user_id': user.id,
        'fcm_token': token,
        'platform': defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
        'notifications_enabled': true,
        'locale': localeService.languageCode == 'tr' ? 'tr' : 'en',
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'fcm_token');
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Could not register this device for push: $error');
      }
    }
  }

  void _handleLocaleChanged() => unawaited(_refreshCurrentTokenLocale());

  Future<void> _refreshCurrentTokenLocale() async {
    if (!isSupported || !SupabaseConfig.isConfigured) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;
    await _upsertToken(token);
  }

  Future<void> unregisterCurrentDevice() async {
    if (!isSupported || !SupabaseConfig.isConfigured || !_initialized) return;
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await client
          .from('push_devices')
          .delete()
          .eq('user_id', user.id)
          .eq('fcm_token', token);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Could not unregister this device from push: $error');
      }
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final remoteNotification = message.notification;
    final title =
        remoteNotification?.title ?? message.data['title']?.toString();
    final body = remoteNotification?.body ?? message.data['body']?.toString();
    if (title == null || body == null) return;

    await notificationService.showRemoteNotification(
      id:
          message.messageId?.hashCode ??
          DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title: title,
      body: body,
      data: message.data,
    );
  }

  void _handleOpenedMessage(RemoteMessage message) =>
      _queueTarget(message.data);

  void _queueTarget(Map<String, dynamic> data) {
    _pendingTarget = PushNotificationTarget.fromData(data);
    notifyListeners();
  }

  @override
  void dispose() {
    localeService.removeListener(_handleLocaleChanged);
    unawaited(_foregroundSubscription?.cancel());
    unawaited(_openedSubscription?.cancel());
    unawaited(_tokenSubscription?.cancel());
    unawaited(_localTapSubscription?.cancel());
    super.dispose();
  }
}

final pushNotificationService = PushNotificationService();
