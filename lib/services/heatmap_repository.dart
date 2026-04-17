import 'package:hive/hive.dart';
import '../models/weekly_density_bucket.dart';

/// Abstract interface for reading and writing heatmap contribution data.
///
/// v1 uses [LocalHeatmapRepository] which stores data on-device only.
///
/// BACKEND INTEGRATION POINT:
/// When a shared backend is added, implement a `RemoteHeatmapRepository` that:
///   • uploads anonymous bucket increments (weekday + timeBlock only, no coordinates)
///   • fetches aggregated weekly density for the campus
///   • enforces a minimum-user anonymity threshold (e.g. k-anonymity ≥ 5) before
///     contributing a cell's crowd data to the public heatmap
/// Replace the [LocalHeatmapRepository] injection in [CampusPulseService]
/// with the remote implementation to instantly enable live multi-user data.
abstract class HeatmapRepository {
  /// Returns the locally stored contribution count for a given cell.
  /// Returns 0 when no contribution has been recorded.
  int getContribution(int weekday, TimeBlock block);

  /// Increments the contribution counter for a cell by one.
  Future<void> incrementContribution(int weekday, TimeBlock block);

  /// Clears all locally stored contributions for the current user.
  Future<void> clearContributions();

  /// True if any contribution has been recorded locally.
  bool get hasAnyContribution;
}

// ── Local (on-device only) implementation ────────────────────────────────────

/// Stores each user's own opted-in campus activity as hit-counts per
/// (weekday, timeBlock) cell.  Nothing more granular is ever persisted.
///
/// NOTE: This is single-device data.  It represents the current device
/// owner's recent on-campus activity pattern, NOT a crowd signal.
/// The UI labels this honestly as "Based on events + your activity".
class LocalHeatmapRepository implements HeatmapRepository {
  static const _boxName = 'campus_pulse_buckets';
  Box<dynamic>? _box;

  Future<void> initialize() async {
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  String _key(int weekday, TimeBlock block) => 'b_${weekday}_${block.index}';

  @override
  int getContribution(int weekday, TimeBlock block) =>
      (_box?.get(_key(weekday, block), defaultValue: 0) as int?) ?? 0;

  @override
  Future<void> incrementContribution(int weekday, TimeBlock block) async {
    final current = getContribution(weekday, block);
    await _box?.put(_key(weekday, block), current + 1);
  }

  @override
  Future<void> clearContributions() async {
    if (_box == null) return;
    final keysToRemove = _box!.keys
        .where((k) => (k as String).startsWith('b_'))
        .toList();
    await _box!.deleteAll(keysToRemove);
  }

  @override
  bool get hasAnyContribution {
    if (_box == null) return false;
    return _box!.keys.any((k) => (k as String).startsWith('b_'));
  }
}

final localHeatmapRepository = LocalHeatmapRepository();
