import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// How message groups are laid out in a club community stream.
enum ClubMessageStyle { rows, bubbles, cards }

/// How much visual weight an officer announcement carries.
enum ClubAnnouncementEmphasis { subtle, tinted, bold }

/// Per-device display preferences for the club community screen.
///
/// Reading before [initialize] returns the defaults from the design
/// ("rows" + "tinted" + roles shown), so widget tests render without Hive.
class ClubChatPrefs extends ChangeNotifier {
  static const _boxName = 'club_chat_prefs_v1';

  Box<dynamic>? _box;

  ClubMessageStyle _messageStyle = ClubMessageStyle.rows;
  ClubAnnouncementEmphasis _emphasis = ClubAnnouncementEmphasis.tinted;
  bool _showRoles = true;
  final Set<String> _mutedThreadIds = {};

  /// Pinned strips the reader dismissed, by message id. Kept per device so a
  /// dismissed strip stays dismissed but a newly pinned notice comes back.
  final Set<String> _dismissedPinIds = {};

  ClubMessageStyle get messageStyle => _messageStyle;
  ClubAnnouncementEmphasis get announcementEmphasis => _emphasis;
  bool get showRoles => _showRoles;

  bool isMuted(String threadId) => _mutedThreadIds.contains(threadId);

  void setMuted(String threadId, bool muted) {
    final changed = muted
        ? _mutedThreadIds.add(threadId)
        : _mutedThreadIds.remove(threadId);
    if (!changed) return;
    _persist('mutedThreadIds', _mutedThreadIds.toList(growable: false));
  }

  bool isPinDismissed(String messageId) => _dismissedPinIds.contains(messageId);

  void dismissPin(String messageId) {
    if (!_dismissedPinIds.add(messageId)) return;
    _persist('dismissedPinIds', _dismissedPinIds.toList(growable: false));
  }

  Future<void> initialize() async {
    if (_box != null) return;
    _box = await Hive.openBox<dynamic>(_boxName);
    _messageStyle = _read(
      'messageStyle',
      ClubMessageStyle.values,
      _messageStyle,
    );
    _emphasis = _read(
      'announcementEmphasis',
      ClubAnnouncementEmphasis.values,
      _emphasis,
    );
    _showRoles = _box!.get('showRoles') as bool? ?? _showRoles;
    _mutedThreadIds
      ..clear()
      ..addAll(_readIds('mutedThreadIds'));
    _dismissedPinIds
      ..clear()
      ..addAll(_readIds('dismissedPinIds'));
    notifyListeners();
  }

  Iterable<String> _readIds(String key) =>
      (_box?.get(key) as List? ?? const []).map((id) => id.toString());

  T _read<T extends Enum>(String key, List<T> values, T fallback) {
    final stored = _box?.get(key)?.toString();
    for (final value in values) {
      if (value.name == stored) return value;
    }
    return fallback;
  }

  void setMessageStyle(ClubMessageStyle value) {
    if (_messageStyle == value) return;
    _messageStyle = value;
    _persist('messageStyle', value.name);
  }

  void setAnnouncementEmphasis(ClubAnnouncementEmphasis value) {
    if (_emphasis == value) return;
    _emphasis = value;
    _persist('announcementEmphasis', value.name);
  }

  void setShowRoles(bool value) {
    if (_showRoles == value) return;
    _showRoles = value;
    _persist('showRoles', value);
  }

  void _persist(String key, Object value) {
    final box = _box;
    if (box != null) unawaited(box.put(key, value));
    notifyListeners();
  }
}

final clubChatPrefs = ClubChatPrefs();
