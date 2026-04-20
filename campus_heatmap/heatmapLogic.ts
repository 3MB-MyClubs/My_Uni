// ─────────────────────────────────────────────────────────────────────────────
//  Campus Heatmap — Pure Logic
//  No framework dependency. Works with React, Vue, vanilla JS, or any runtime.
// ─────────────────────────────────────────────────────────────────────────────

// ── Types ─────────────────────────────────────────────────────────────────────

export interface Zone {
  name: string;
  x: number; // 0–100 grid coordinate
  y: number; // 0–100 grid coordinate
}

export interface CampusEvent {
  id: string;
  zoneId: number;
  title: string;
  description: string;
  startTime: Date;
  endTime: Date;
}

export interface HeatPoint {
  x: number;        // 0–100
  y: number;        // 0–100
  intensity: number; // 0–1 (normalized)
  zoneName: string;
  zoneId: number;
}

export interface ZoneClickResult {
  zoneId: number;
  zoneName: string;
  events: CampusEvent[];
}

// ── Zone definitions (0–100 spatial grid) ────────────────────────────────────

export const ZONES: Record<number, Zone> = {
  1: { name: "Gym",                      x: 30, y: 20 },
  2: { name: "Omer Square",              x: 50, y: 50 },
  3: { name: "Library",                  x: 50, y: 35 },
  4: { name: "Odeon",                    x: 65, y: 65 },
  5: { name: "Social Sciences Building", x: 65, y: 50 },
  6: { name: "SNA Building",             x: 70, y: 20 },
  7: { name: "Football Field",           x: 85, y: 10 },
  8: { name: "Henry Ford Lawn",          x: 40, y: 75 },
  9: { name: "Student Center",           x: 60, y: 75 },
};

// ── 1. Count events per zone ──────────────────────────────────────────────────

export function getEventCounts(events: CampusEvent[]): Record<number, number> {
  const counts: Record<number, number> = {};
  for (const id of Object.keys(ZONES)) {
    counts[Number(id)] = 0;
  }
  for (const event of events) {
    if (counts[event.zoneId] !== undefined) {
      counts[event.zoneId]++;
    }
  }
  return counts;
}

// ── 2. Normalize counts to [0, 1] ─────────────────────────────────────────────

export function normalizeCounts(
  counts: Record<number, number>
): Record<number, number> {
  const values = Object.values(counts);
  const max = values.length > 0 ? Math.max(...values) : 0;
  if (max === 0) {
    const out: Record<number, number> = {};
    for (const k of Object.keys(counts)) { out[Number(k)] = 0; }
    return out;
  }
  const out: Record<number, number> = {};
  for (const [k, v] of Object.entries(counts)) {
    out[Number(k)] = v / max;
  }
  return out;
}

// ── 3. Generate heat points for rendering ────────────────────────────────────
//  Zones with zero normalized intensity are excluded — they produce no heat.

export function generateHeatPoints(
  zones: Record<number, Zone>,
  normalizedCounts: Record<number, number>
): HeatPoint[] {
  const result: HeatPoint[] = [];
  for (const [id, zone] of Object.entries(zones)) {
    const intensity = normalizedCounts[Number(id)] ?? 0;
    if (intensity > 0) {
      result.push({
        x: zone.x,
        y: zone.y,
        intensity,
        zoneName: zone.name,
        zoneId: Number(id),
      });
    }
  }
  return result;
}

// ── 4. Get all events for a specific zone (unfiltered by time) ────────────────

export function getEventsForZone(
  zoneId: number,
  events: CampusEvent[]
): CampusEvent[] {
  return events.filter((e) => e.zoneId === zoneId);
}

// ── 5. Filter events for current week (today 00:00 → today+7 23:59:59) ───────
//  An event is included if any part of it falls within the window.
//  Fully past events (endTime before today 00:00) are excluded.

export function filterEventsForCurrentWeek(
  events: CampusEvent[]
): CampusEvent[] {
  const weekStart = new Date();
  weekStart.setHours(0, 0, 0, 0);

  const weekEnd = new Date(weekStart);
  weekEnd.setDate(weekEnd.getDate() + 7);
  weekEnd.setHours(23, 59, 59, 999);

  return events.filter(
    (e) => e.endTime >= weekStart && e.startTime <= weekEnd
  );
}

// ── Zone click handler ────────────────────────────────────────────────────────

export function handleZoneClick(
  zoneId: number,
  events: CampusEvent[]
): ZoneClickResult {
  const zoneEvents = getEventsForZone(zoneId, events);
  const filtered   = filterEventsForCurrentWeek(zoneEvents);
  return {
    zoneId,
    zoneName: ZONES[zoneId]?.name ?? "Unknown Zone",
    events: filtered,
  };
}
