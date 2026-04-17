import 'package:geolocator/geolocator.dart';
import '../models/weekly_density_bucket.dart';
import 'heatmap_repository.dart';

/// Samples the device's approximate location while the app is in the
/// foreground and opted in.  Converts each sample immediately into an
/// anonymous (weekday, timeBlock) bucket increment — raw coordinates are
/// never stored.
///
/// Privacy design:
///  • Only fires when [isActive] is true (user opted in + permission granted).
///  • Throttled: at most one sample every [_minIntervalMinutes] minutes.
///  • Uses [LocationAccuracy.low] (city-level accuracy, ~3 km).
///  • Only records a contribution when the device appears to be on/near KU campus.
///  • No movement trail, no path log, no precise coordinates are persisted.
///
/// NOTE (v1): contributions are stored locally only.  They represent the
/// device owner's personal campus presence pattern, not crowd data.
class LocationContributionService {
  // KU campus centre (Sarıyer, Istanbul) — approximate bounding box ±0.015°
  static const _kuLat = 41.2031;
  static const _kuLng = 29.0717;
  static const _maxDistanceMeters = 1800.0; // ~1.8 km radius covers campus

  static const _minIntervalMinutes = 5;

  DateTime? _lastSampleAt;
  bool isActive = false;

  final HeatmapRepository _repo;

  LocationContributionService(this._repo);

  /// Call when the app becomes active and the user has opted in.
  /// Attempts a single throttled sample.
  Future<void> maybeSample() async {
    if (!isActive) return;

    final now = DateTime.now();
    if (_lastSampleAt != null &&
        now.difference(_lastSampleAt!).inMinutes < _minIntervalMinutes) {
      return; // throttled
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      );

      final distanceM = Geolocator.distanceBetween(
        _kuLat,
        _kuLng,
        position.latitude,
        position.longitude,
      );

      if (distanceM <= _maxDistanceMeters) {
        // On campus — record bucket contribution (no coordinates stored).
        final weekday = now.weekday; // 1=Mon … 7=Sun
        final block = timeBlockForHour(now.hour);
        await _repo.incrementContribution(weekday, block);
      }

      _lastSampleAt = now;
    } catch (_) {
      // Location unavailable (e.g. simulator, airplane mode) — ignore silently.
    }
  }

  void deactivate() {
    isActive = false;
    _lastSampleAt = null;
  }
}
