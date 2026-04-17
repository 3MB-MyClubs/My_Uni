import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';

/// Manages location permission state for Campus Pulse.
///
/// Wraps [Geolocator] permission APIs and tracks whether the in-app
/// explainer sheet has already been shown, to avoid nagging the user.
class LocationPermissionService {
  static const _boxName = 'campus_pulse_prefs';
  Box<dynamic>? _box;

  Future<void> initialize() async {
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  // ── Explainer / consent tracking ─────────────────────────────────────────

  String _prefKey(String userId) => 'explainer_shown_$userId';

  bool wasExplainerShown(String userId) =>
      (_box?.get(_prefKey(userId), defaultValue: false) as bool?) ?? false;

  Future<void> markExplainerShown(String userId) async =>
      _box?.put(_prefKey(userId), true);

  // ── Permission queries ────────────────────────────────────────────────────

  /// Current system permission status.
  Future<LocationPermission> currentPermission() =>
      Geolocator.checkPermission();

  /// Whether the user has granted at-least while-in-use access.
  Future<bool> isGranted() async {
    final p = await currentPermission();
    return p == LocationPermission.whileInUse || p == LocationPermission.always;
  }

  /// Whether the user has permanently denied (needs OS settings to change).
  Future<bool> isPermanentlyDenied() async {
    final p = await currentPermission();
    return p == LocationPermission.deniedForever;
  }

  /// Request while-in-use permission.  Returns the resulting status.
  /// Only call this after showing the in-app explainer.
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  /// Opens the OS app settings page so the user can change location access.
  Future<void> openSettings() => Geolocator.openAppSettings();
}

final locationPermissionService = LocationPermissionService();
