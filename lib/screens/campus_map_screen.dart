import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/app_colors.dart';
import '../services/mock_data.dart';
import '../models/event.dart';
import 'event_detail_screen.dart';

// ── Campus zones with approximate coordinates ─────────────────────────────────

class _Zone {
  final String id;
  final String name;
  final String shortName;
  final LatLng position;
  final List<String> locationKeywords;

  const _Zone({
    required this.id,
    required this.name,
    required this.shortName,
    required this.position,
    required this.locationKeywords,
  });
}

const _zones = [
  _Zone(
    id: 'sos',
    name: 'SOS Building',
    shortName: 'SOS',
    position: LatLng(41.2047, 29.0713),
    locationKeywords: ['SOS'],
  ),
  _Zone(
    id: 'eng',
    name: 'Engineering',
    shortName: 'ENG',
    position: LatLng(41.2024, 29.0731),
    locationKeywords: ['ENG'],
  ),
  _Zone(
    id: 'sci',
    name: 'Science',
    shortName: 'SCI',
    position: LatLng(41.2018, 29.0724),
    locationKeywords: ['SCI'],
  ),
  _Zone(
    id: 'library',
    name: 'Library',
    shortName: 'LIB',
    position: LatLng(41.2035, 29.0706),
    locationKeywords: ['Library', 'AKMER', 'Kütüphane'],
  ),
  _Zone(
    id: 'sports',
    name: 'Sports Facilities',
    shortName: 'GYM',
    position: LatLng(41.2012, 29.0695),
    locationKeywords: ['Sports', 'Gym', 'Field', 'Stadium'],
  ),
  _Zone(
    id: 'cafeteria',
    name: 'Cafeteria',
    shortName: 'CAF',
    position: LatLng(41.2042, 29.0700),
    locationKeywords: ['Cafeteria', 'Kafeterya', 'Dining'],
  ),
  _Zone(
    id: 'gate',
    name: 'Main Gate',
    shortName: 'GATE',
    position: LatLng(41.1999, 29.0719),
    locationKeywords: ['Main Gate', 'Ana Giriş', 'main gate'],
  ),
  _Zone(
    id: 'arts',
    name: 'Arts Building',
    shortName: 'ARTS',
    position: LatLng(41.2053, 29.0718),
    locationKeywords: ['Arts', 'Atölye', 'Studio', 'Atelier'],
  ),
  _Zone(
    id: 'dorms',
    name: 'Dormitories',
    shortName: 'DORM',
    position: LatLng(41.2062, 29.0710),
    locationKeywords: ['Dormitory', 'Yurt', 'KY'],
  ),
];

// ── Screen ───────────────────────────────────────────────────────────────────

class CampusMapScreen extends StatefulWidget {
  const CampusMapScreen({super.key});

  @override
  State<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends State<CampusMapScreen>
    with SingleTickerProviderStateMixin {
  _Zone? _selectedZone;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  static const _center = LatLng(41.2031, 29.0717);

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.3,
      end: 0.8,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Activity scoring ──────────────────────────────────────────────────────

  double _score(_Zone zone) {
    final now = DateTime.now();
    double s = 0;
    for (final e in events) {
      final matches = zone.locationKeywords.any(
        (kw) => e.location.toLowerCase().contains(kw.toLowerCase()),
      );
      if (!matches) { continue; }

      final isLive = !e.dateTime.isAfter(now) && e.endTime.isAfter(now);
      final daysAway = e.dateTime.difference(now).inDays;

      if (isLive) {
        s += 3.0 + e.attendeeUserIds.length * 0.4;
      } else if (daysAway >= 0 && daysAway == 0) {
        s += 1.5 + e.attendeeUserIds.length * 0.2;
      } else if (daysAway > 0 && daysAway <= 7) {
        s += 0.6 + e.attendeeUserIds.length * 0.1;
      }
    }
    return s.clamp(0, 6);
  }

  bool _isLive(_Zone zone) {
    final now = DateTime.now();
    return events.any((e) {
      return zone.locationKeywords.any(
            (kw) => e.location.toLowerCase().contains(kw.toLowerCase()),
          ) &&
          !e.dateTime.isAfter(now) &&
          e.endTime.isAfter(now);
    });
  }

  List<Event> _zoneEvents(_Zone zone) {
    final now = DateTime.now();
    return events
        .where((e) {
          final ok = zone.locationKeywords.any(
            (kw) => e.location.toLowerCase().contains(kw.toLowerCase()),
          );
          if (!ok) { return false; }
          return e.dateTime.difference(now).inDays >= 0 ||
              (!e.dateTime.isAfter(now) && e.endTime.isAfter(now));
        })
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Color _circleColor(double score, bool live) {
    if (score == 0) return Colors.transparent;
    final alpha = (0.18 + score / 6 * 0.72).clamp(0.0, 0.9);
    return live
        ? Colors.red.withValues(alpha: alpha)
        : AppColors.primaryRed.withValues(alpha: alpha);
  }

  double _circleRadius(double score) => 30 + score * 9;

  List<CircleMarker> _buildCircles(double pulseValue) {
    final markers = <CircleMarker>[];
    for (final z in _zones) {
      final score = _score(z);
      final live = _isLive(z);
      final selected = z == _selectedZone;
      if (live) {
        markers.add(CircleMarker(
          point: z.position,
          radius: _circleRadius(score) + 18 + pulseValue * 14,
          useRadiusInMeter: false,
          color: Colors.red.withValues(alpha: 0.07 * pulseValue),
          borderStrokeWidth: 0,
          borderColor: Colors.transparent,
        ));
      }
      if (score > 0 || selected) {
        markers.add(CircleMarker(
          point: z.position,
          radius: _circleRadius(score),
          useRadiusInMeter: false,
          color: _circleColor(score, live),
          borderStrokeWidth: selected ? 2.5 : live ? 1.5 : 0,
          borderColor: selected
              ? Colors.white
              : live
              ? Colors.red.withValues(alpha: 0.8)
              : Colors.transparent,
        ));
      }
    }
    return markers;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hasAnyLive = _zones.any(_isLive);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Campus Activity Map',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (hasAnyLive)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(
                child: AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (ctx, child) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12 + _pulseAnim.value * 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'Live now',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Map ───────────────────────────────────────────────────────────
          Expanded(
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (ctx, child) {
                return FlutterMap(
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 15.6,
                    minZoom: 14.5,
                    maxZoom: 18.0,
                    onTap: (tapPos, point) => setState(() => _selectedZone = null),
                  ),
                  children: [
                    // Dark CartoDB tiles
                    TileLayer(
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'edu.ku.campusapp',
                      retinaMode: MediaQuery.of(context).devicePixelRatio > 1,
                    ),

                    // Heatmap circles
                    CircleLayer(
                      circles: _buildCircles(_pulseAnim.value),
                    ),

                    // Zone label markers
                    MarkerLayer(
                      markers: _zones.map((z) {
                        final score = _score(z);
                        final live = _isLive(z);
                        final selected = z == _selectedZone;
                        return Marker(
                          point: z.position,
                          width: 72,
                          height: 28,
                          child: GestureDetector(
                            onTap: () => setState(
                              () => _selectedZone = (z == _selectedZone) ? null : z,
                            ),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: live
                                      ? Colors.red
                                      : selected
                                      ? AppColors.primaryRed
                                      : score > 0
                                      ? AppColors.card.withValues(alpha: 0.92)
                                      : AppColors.card.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(7),
                                  border: Border.all(
                                    color: live
                                        ? Colors.red
                                        : selected
                                        ? Colors.white
                                        : score > 0
                                        ? AppColors.primaryRed.withValues(alpha: 0.5)
                                        : AppColors.divider.withValues(alpha: 0.5),
                                    width: selected ? 1.5 : 1,
                                  ),
                                ),
                                child: Text(
                                  z.shortName,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: live || selected
                                        ? Colors.white
                                        : score > 0
                                        ? AppColors.text
                                        : AppColors.secondaryText,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    // Attribution
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('© OpenStreetMap contributors'),
                        TextSourceAttribution('© CARTO'),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),

          // ── Legend ────────────────────────────────────────────────────────
          Container(
            color: AppColors.card,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Text(
                  'Quiet',
                  style: TextStyle(fontSize: 10, color: AppColors.secondaryText),
                ),
                const SizedBox(width: 4),
                ...List.generate(5, (i) {
                  return Container(
                    width: 18,
                    height: 10,
                    margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withValues(alpha: 0.18 + i * 0.17),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
                const SizedBox(width: 4),
                Text(
                  'Busy',
                  style: TextStyle(fontSize: 10, color: AppColors.secondaryText),
                ),
                const Spacer(),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Live event',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Zone detail panel ─────────────────────────────────────────────
          if (_selectedZone != null)
            _ZonePanel(
              zone: _selectedZone!,
              events: _zoneEvents(_selectedZone!),
              onEventTap: (e) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EventDetailScreen(
                    event: e,
                    color: AppColors.primaryRed,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Zone detail panel ─────────────────────────────────────────────────────────

class _ZonePanel extends StatelessWidget {
  final _Zone zone;
  final List<Event> events;
  final void Function(Event) onEventTap;

  const _ZonePanel({
    required this.zone,
    required this.events,
    required this.onEventTap,
  });

  String _fmtDate(DateTime dt) {
    final now = DateTime.now();
    final isLive = !dt.isAfter(now);
    if (isLive) return 'Now';
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    if (isToday) return 'Today $h:$m';
    final diff = dt.difference(now).inDays;
    if (diff == 1) return 'Tomorrow';
    return 'In ${diff}d';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.lightRed,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  zone.shortName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryRed,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                zone.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'No upcoming events this week',
                style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
              ),
            )
          else
            ...events.take(4).map((e) {
              final live = !e.dateTime.isAfter(now) && e.endTime.isAfter(now);
              return GestureDetector(
                onTap: () => onEventTap(e),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 8, top: 1),
                        decoration: BoxDecoration(
                          color: live ? Colors.red : AppColors.primaryRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${_fmtDate(e.dateTime)} · ${e.title}',
                          style: TextStyle(
                            fontSize: 12,
                            color: live ? AppColors.text : AppColors.secondaryText,
                            fontWeight: live ? FontWeight.w500 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (live)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Live',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        const Icon(
                          Icons.chevron_right,
                          size: 14,
                          color: AppColors.secondaryText,
                        ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
