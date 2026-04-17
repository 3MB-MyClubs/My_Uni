import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

// ── Interest & time labels ────────────────────────────────────────────────────

const List<String> kInterests = [
  'Tech',
  'Arts',
  'Music',
  'Sports',
  'Academic',
  'Career',
  'Wellness',
  'Social Impact',
];

const List<String> kTimeSlots = ['Morning', 'Afternoon', 'Evening', 'Weekend'];

// ── Club → interest category mapping ─────────────────────────────────────────

const Map<String, List<String>> kClubInterestMap = {
  'c3': ['Academic'],
  'c4': ['Tech', 'Career'],
  'c5': ['Sports'],
  'c6': ['Arts', 'Social Impact'],
  'c7': ['Academic', 'Career'],
  'c8': ['Academic'],
  'c9': ['Arts'],
  'c10': ['Academic'],
  'c11': ['Sports'],
  'c12': ['Arts'],
  'c13': ['Arts'],
  'c14': ['Academic'],
  'c15': ['Career', 'Tech'],
  'c16': ['Wellness'],
  'c17': ['Academic', 'Career'],
  'c18': ['Career'],
  'c19': ['Social Impact', 'Wellness'],
  'c20': ['Tech', 'Career', 'Social Impact'],
  'c21': ['Tech', 'Academic'],
  'c22': ['Social Impact'],
  'c23': ['Sports'],
  'c24': ['Social Impact'],
  'c25': ['Arts', 'Academic'],
  'c26': ['Tech'],
  'c27': ['Academic'],
  'c28': ['Music'],
  'c29': ['Music', 'Arts'],
  'c30': ['Academic', 'Wellness'],
  'c31': ['Music'],
  'c32': ['Career'],
  'c33': ['Arts', 'Music'],
  'c34': ['Arts'],
  'c35': ['Arts'],
  'c36': ['Social Impact'],
  'c37': ['Academic'],
  'c38': ['Wellness', 'Academic'],
  'c39': ['Arts'],
  'c40': ['Academic'],
  'c41': ['Music', 'Arts'],
};

// ── Service ───────────────────────────────────────────────────────────────────

class PersonalizationService extends ChangeNotifier {
  static const _boxName = 'personalization';
  Box<dynamic>? _box;

  bool onboardingComplete = false;
  Set<String> interests = {};
  Set<String> timePrefs = {};
  Set<String> hiddenIds = {};
  Set<String> remindedEventIds = {};

  Future<void> initialize() async {
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  // ── Load ────────────────────────────────────────────────────────────────────

  void load(String userId) {
    if (_box == null) return;
    onboardingComplete = _box!.get('ob_$userId', defaultValue: false) as bool;
    interests = _restoreSet(_box!.get('int_$userId'));
    timePrefs = _restoreSet(_box!.get('tp_$userId'));
    hiddenIds = _restoreSet(_box!.get('hid_$userId'));
    remindedEventIds = _restoreSet(_box!.get('rem_$userId'));
    notifyListeners();
  }

  // ── Save ────────────────────────────────────────────────────────────────────

  Future<void> save(String userId) async {
    if (_box == null) return;
    await _box!.putAll({
      'ob_$userId': onboardingComplete,
      'int_$userId': interests.toList(),
      'tp_$userId': timePrefs.toList(),
      'hid_$userId': hiddenIds.toList(),
      'rem_$userId': remindedEventIds.toList(),
    });
  }

  // ── Mutations ───────────────────────────────────────────────────────────────

  Future<void> completeOnboarding(
    String userId,
    Set<String> selectedInterests,
    Set<String> selectedTimePrefs,
  ) async {
    onboardingComplete = true;
    interests = Set.of(selectedInterests);
    timePrefs = Set.of(selectedTimePrefs);
    notifyListeners();
    await save(userId);
  }

  Future<void> hideItem(String userId, String id) async {
    hiddenIds.add(id);
    notifyListeners();
    await save(userId);
  }

  Future<void> remindEvent(String userId, String eventId) async {
    remindedEventIds.add(eventId);
    notifyListeners();
    await save(userId);
  }

  Future<void> unremindEvent(String userId, String eventId) async {
    remindedEventIds.remove(eventId);
    notifyListeners();
    await save(userId);
  }

  // ── Queries ─────────────────────────────────────────────────────────────────

  bool isHidden(String id) => hiddenIds.contains(id);
  bool isReminded(String id) => remindedEventIds.contains(id);

  /// Returns interest tags for the given club ID.
  List<String> interestsForClub(String clubId) =>
      kClubInterestMap[clubId] ?? [];

  /// How many of the user's selected interests match a given club.
  int interestMatchCount(String clubId) =>
      interestsForClub(clubId).where(interests.contains).length;

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Set<String> _restoreSet(dynamic raw) =>
      raw != null ? Set<String>.from(raw as List) : {};
}

final personalizationService = PersonalizationService();
