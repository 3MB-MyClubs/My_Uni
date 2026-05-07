import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/app_colors.dart';
import '../services/mock_data.dart';
import '../models/event.dart';
import 'event_detail_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// 📍 BUILDING COORDINATES — FILL THESE IN
//
// How to get real coordinates:
//   1. Open Google Maps → find the building on campus
//   2. Right-click on the building → copy the first two numbers that appear
//   3. Paste them below as LatLng(latitude, longitude)
//      (latitude is the first number ~41.xx, longitude is the second ~29.xx)
//
// Also update _kMapCenter below to the middle of your campus.
// ═══════════════════════════════════════════════════════════════════════════════

// ── Map center — the camera starts here on open ──────────────────────────────
const _kMapCenter = LatLng(41.205314, 29.073231);

// ── Building pin coordinates ─────────────────────────────────────────────────
const _kSCI        = LatLng(41.206352, 29.075228); // Science Building
const _kENG        = LatLng(41.207009, 29.075530); // Engineering Building
const _kSNA        = LatLng(41.208207, 29.075522); // SNA
const _kHenry      = LatLng(41.204730, 29.072518); // Henry Ford Çimleri
const _kKurucular  = LatLng(41.205044, 29.073767); // Kurucular Salonu
const _kSOS        = LatLng(41.205891, 29.074844); // SOS Building
const _kOdeon      = LatLng(41.205670, 29.074322); // Odeon
const _kCASE       = LatLng(41.2030,   29.0742);   // CASE Building — update when known

// ═══════════════════════════════════════════════════════════════════════════════

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
    id: 'sci',
    name: 'Science Building',
    shortName: 'SCI',
    position: _kSCI,
    locationKeywords: ['SCI'],
  ),
  _Zone(
    id: 'eng',
    name: 'Engineering Building',
    shortName: 'ENG',
    position: _kENG,
    locationKeywords: ['ENG'],
  ),
  _Zone(
    id: 'sna',
    name: 'SNA',
    shortName: 'SNA',
    position: _kSNA,
    locationKeywords: ['SNA'],
  ),
  _Zone(
    id: 'henry',
    name: 'Henry Çimleri',
    shortName: 'Henry',
    position: _kHenry,
    locationKeywords: ['Henry'],
  ),
  _Zone(
    id: 'kurucular',
    name: 'Kurucular Salonu',
    shortName: 'KUR',
    position: _kKurucular,
    locationKeywords: ['Kurucular'],
  ),
  _Zone(
    id: 'sos',
    name: 'SOS Building',
    shortName: 'SOS',
    position: _kSOS,
    locationKeywords: ['SOS'],
  ),
  _Zone(
    id: 'odeon',
    name: 'Odeon',
    shortName: 'Odeon',
    position: _kOdeon,
    locationKeywords: ['Odeon'],
  ),
  _Zone(
    id: 'case',
    name: 'CASE Building',
    shortName: 'CASE',
    position: _kCASE,
    locationKeywords: ['CASE'],
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

  // Selected day for the heatmap (start-of-day, local time)
  late DateTime _selectedDay;

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDay.year == now.year &&
        _selectedDay.month == now.month &&
        _selectedDay.day == now.day;
  }

  static DateTime _startOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  static const _center = _kMapCenter;

  @override
  void initState() {
    super.initState();
    _selectedDay = _startOfDay(DateTime.now());
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

  /// Returns true if [e] falls on [_selectedDay] (starts or is live during that day).
  bool _onSelectedDay(Event e) {
    final dayStart = _selectedDay;
    final dayEnd = dayStart.add(const Duration(days: 1));
    // Event starts during the day OR is live (started before dayEnd, ends after dayStart)
    return e.dateTime.isBefore(dayEnd) && e.endTime.isAfter(dayStart);
  }

  /// Number of events at [zone] on the selected day.
  int _weekEventCount(_Zone zone) {
    return events.where((e) {
      final matches = zone.locationKeywords.any(
        (kw) => e.location.toLowerCase().contains(kw.toLowerCase()),
      );
      return matches && _onSelectedDay(e);
    }).length;
  }

  double _score(_Zone zone) {
    double s = 0;
    final now = DateTime.now();
    for (final e in events) {
      final matches = zone.locationKeywords.any(
        (kw) => e.location.toLowerCase().contains(kw.toLowerCase()),
      );
      if (!matches || !_onSelectedDay(e)) continue;

      final isLive = !e.dateTime.isAfter(now) && e.endTime.isAfter(now);
      if (isLive) {
        s += 3.0 + e.attendeeUserIds.length * 0.4;
      } else {
        s += 1.5 + e.attendeeUserIds.length * 0.2;
      }
    }
    return s.clamp(0, 6);
  }

  bool _isLive(_Zone zone) {
    final now = DateTime.now();
    return events.any((e) =>
        zone.locationKeywords.any(
          (kw) => e.location.toLowerCase().contains(kw.toLowerCase()),
        ) &&
        !e.dateTime.isAfter(now) &&
        e.endTime.isAfter(now) &&
        _onSelectedDay(e));
  }

  List<Event> _zoneEvents(_Zone zone) {
    return events
        .where((e) {
          final ok = zone.locationKeywords.any(
            (kw) => e.location.toLowerCase().contains(kw.toLowerCase()),
          );
          return ok && _onSelectedDay(e);
        })
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Returns an orange→red colour based on weekly event count.
  Color _heatColor(int count) {
    if (count >= 4) return const Color(0xFFD32F2F); // deep red
    if (count == 3) return const Color(0xFFE64A19); // red-orange
    if (count == 2) return const Color(0xFFF57C00); // orange
    return const Color(0xFFFFA000);                  // amber
  }

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

  // ── Day picker ────────────────────────────────────────────────────────────

  static const _dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const _monthNames = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  Widget _buildDayPicker() {
    final today = _startOfDay(DateTime.now());
    // Show today + next 6 days
    final days = List.generate(7, (i) => today.add(Duration(days: i)));

    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: days.map((day) {
            final isSelected = day == _selectedDay;
            final isToday = day == today;
            return GestureDetector(
              onTap: () => setState(() {
                _selectedDay = day;
                _selectedZone = null;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryRed : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryRed
                        : AppColors.secondaryText.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isToday ? 'Today' : _dayNames[day.weekday % 7],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white70 : AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${day.day} ${_monthNames[day.month - 1]}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
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
          // ── Day picker strip ──────────────────────────────────────────────
          _buildDayPicker(),

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
                        final dayCount = _weekEventCount(z);
                        return Marker(
                          point: z.position,
                          width: 72,
                          height: 44,
                          child: GestureDetector(
                            onTap: () => setState(
                              () => _selectedZone =
                                  (z == _selectedZone) ? null : z,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Count badge above the pill
                                if (dayCount > 0)
                                  Container(
                                    margin:
                                        const EdgeInsets.only(bottom: 2),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: live
                                          ? Colors.red
                                          : _heatColor(dayCount)
                                              .withValues(alpha: 0.9),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '$dayCount',
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        const Text('🔥',
                                            style:
                                                TextStyle(fontSize: 8)),
                                      ],
                                    ),
                                  ),
                                // Building name pill
                                Container(
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
                                                ? AppColors.card
                                                    .withValues(alpha: 0.92)
                                                : AppColors.card
                                                    .withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(7),
                                    border: Border.all(
                                      color: live
                                          ? Colors.red
                                          : selected
                                              ? Colors.white
                                              : score > 0
                                                  ? AppColors.primaryRed
                                                      .withValues(alpha: 0.5)
                                                  : AppColors.divider
                                                      .withValues(alpha: 0.5),
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
                              ],
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
              dayCount: _weekEventCount(_selectedZone!),
              isLive: _isLive(_selectedZone!),
              heatColor: _heatColor(_weekEventCount(_selectedZone!)),
              dayLabel: _isToday ? 'today' : '${_dayNames[_selectedDay.weekday % 7]} ${_selectedDay.day} ${_monthNames[_selectedDay.month - 1]}',
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
  final int dayCount;
  final bool isLive;
  final Color heatColor;
  final String dayLabel;
  final void Function(Event) onEventTap;

  const _ZonePanel({
    required this.zone,
    required this.events,
    required this.dayCount,
    required this.isLive,
    required this.heatColor,
    required this.dayLabel,
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

          // ── Heat indicator ─────────────────────────────────────────────
          Row(
            children: [
              // Flame dots
              ...List.generate(5, (i) {
                final filled = dayCount > 0 && i < (dayCount.clamp(1, 5));
                return Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: Icon(
                    Icons.local_fire_department_rounded,
                    size: 16,
                    color: filled
                        ? (isLive ? Colors.red : heatColor)
                        : AppColors.divider,
                  ),
                );
              }),
              const SizedBox(width: 6),
              Text(
                dayCount == 0
                    ? 'No events $dayLabel'
                    : dayCount == 1
                        ? '1 event $dayLabel'
                        : '$dayCount events $dayLabel',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: dayCount == 0
                      ? AppColors.secondaryText
                      : (isLive ? Colors.red : heatColor),
                ),
              ),
              if (isLive) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Live now',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.red,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'No events $dayLabel',
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
