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

const List<String> kAcademicPrograms = [
  'Archaeology and History of Art',
  'Business Administration',
  'Chemical and Biological Engineering',
  'Chemistry',
  'Comparative Literature',
  'Computer Engineering',
  'Economics',
  'Electrical and Electronics Engineering',
  'History',
  'Industrial Engineering',
  'International Relations',
  'Law',
  'Mathematics',
  'Mechanical Engineering',
  'Media and Visual Arts',
  'Medicine',
  'Molecular Biology and Genetics',
  'Nursing',
  'Philosophy',
  'Physics',
  'Psychology',
  'Sociology',
];

/// Weekly lecture schedule for the current user (Hakan Tuncay).
/// days: 1=Mon 2=Tue 3=Wed 4=Thu 5=Fri
const List<Map<String, dynamic>> kCourseSchedule = [
  {
    'title': 'MFIN 304 · Investment Analysis',
    'room': 'CASE Z24',
    'startH': 8,
    'startM': 30,
    'endH': 9,
    'endM': 40,
    'days': [2, 4],
    'color': 0xFF7B1FA2,
  },
  {
    'title': 'INTL 380 · Comp. Political Economy',
    'room': 'SNA 157',
    'startH': 11,
    'startM': 30,
    'endH': 12,
    'endM': 40,
    'days': [1, 3],
    'color': 0xFF1565C0,
  },
  {
    'title': 'MATH 480 · Financial Mathematics',
    'room': 'CASE Z25',
    'startH': 13,
    'startM': 0,
    'endH': 14,
    'endM': 10,
    'days': [1, 3],
    'color': 0xFF2E7D32,
  },
  {
    'title': 'INTL 385 · Turkish Foreign Policy',
    'room': 'CASE B24',
    'startH': 14,
    'startM': 30,
    'endH': 15,
    'endM': 40,
    'days': [2, 4],
    'color': 0xFF283593,
  },
  {
    'title': 'HIST 300 · Hist. of Modern Turkey',
    'room': 'CASE B24',
    'startH': 16,
    'startM': 0,
    'endH': 17,
    'endM': 10,
    'days': [1, 3],
    'color': 0xFFBF360C,
  },
  {
    'title': 'UNIV 198 · AI Literacy',
    'room': 'SOS B07',
    'startH': 11,
    'startM': 30,
    'endH': 12,
    'endM': 40,
    'days': [4, 5],
    'color': 0xFF00695C,
  },
];

/// Faculty → departments map. Edit here to update the major picker.
const List<Map<String, dynamic>> kFaculties = [
  {'name': 'Engineering', 'departments': 'CS, EE, ME, IE, ChBE'},
  {'name': 'Sciences', 'departments': 'Physics, Chemistry, Math, MBG'},
  {'name': 'Business & Economics', 'departments': 'BA, Economics, IR'},
  {
    'name': 'Social Sciences & Humanities',
    'departments': 'Psychology, History, Media, Philosophy',
  },
  {'name': 'Law', 'departments': 'Hukuk Fakültesi'},
  {'name': 'Medicine', 'departments': 'Tıp Fakültesi'},
  {'name': 'Undecided', 'departments': 'Not sure yet'},
];

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

  /// Bump this when the onboarding flow changes structurally (new steps, etc.).
  /// Any user whose stored version doesn't match will be sent through onboarding
  /// again exactly once — their interests/times/major are NOT cleared.
  static const int _onboardingVersion = 1;

  Box<dynamic>? _box;

  bool onboardingComplete = false;
  Set<String> interests = {};
  Set<String> timePrefs = {};
  String major = '';
  Set<String> hiddenIds = {};
  Set<String> remindedEventIds = {};

  Future<void> initialize() async {
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  // ── Load ────────────────────────────────────────────────────────────────────

  void load(String userId) {
    if (_box == null) return;
    // If the stored onboarding version doesn't match the current one,
    // mark onboarding as incomplete so the user sees the new flow once.
    // Their existing interests/times/major are preserved.
    final storedVersion = _box!.get('obv_$userId', defaultValue: 0) as int;
    final versionMatch = storedVersion == _onboardingVersion;

    onboardingComplete =
        versionMatch && (_box!.get('ob_$userId', defaultValue: false) as bool);
    interests = _restoreSet(_box!.get('int_$userId'));
    timePrefs = _restoreSet(_box!.get('tp_$userId'));
    major = _box!.get('major_$userId', defaultValue: '') as String;
    hiddenIds = _restoreSet(_box!.get('hid_$userId'));
    remindedEventIds = _restoreSet(_box!.get('rem_$userId'));
    notifyListeners();
  }

  // ── Save ────────────────────────────────────────────────────────────────────

  Future<void> save(String userId) async {
    if (_box == null) return;
    await _box!.putAll({
      'ob_$userId': onboardingComplete,
      'obv_$userId': _onboardingVersion,
      'int_$userId': interests.toList(),
      'tp_$userId': timePrefs.toList(),
      'major_$userId': major,
      'hid_$userId': hiddenIds.toList(),
      'rem_$userId': remindedEventIds.toList(),
    });
  }

  // ── Mutations ───────────────────────────────────────────────────────────────

  Future<void> completeOnboarding(
    String userId,
    Set<String> selectedInterests,
    Set<String> selectedTimePrefs,
    String selectedMajor,
  ) async {
    onboardingComplete = true;
    interests = Set.of(selectedInterests);
    timePrefs = Set.of(selectedTimePrefs);
    major = selectedMajor;
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
