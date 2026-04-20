// ─────────────────────────────────────────────────────────────────────────────
//  Usage examples for CampusHeatmap
// ─────────────────────────────────────────────────────────────────────────────

// ── Example A: React ──────────────────────────────────────────────────────────

import React from "react";
import CampusHeatmap from "./CampusHeatmap";
import { CampusEvent } from "./heatmapLogic";

const sampleEvents: CampusEvent[] = [
  {
    id: "e1",
    zoneId: 2, // Omer Square
    title: "Spring Fair",
    description: "Annual spring fair with food, games and live music.",
    startTime: new Date(Date.now() + 1 * 3600_000),
    endTime:   new Date(Date.now() + 5 * 3600_000),
  },
  {
    id: "e2",
    zoneId: 2,
    title: "Club Expo",
    description: "Meet all campus clubs in one place.",
    startTime: new Date(Date.now() + 24 * 3600_000),
    endTime:   new Date(Date.now() + 28 * 3600_000),
  },
  {
    id: "e3",
    zoneId: 5, // Social Sciences Building
    title: "Debate Championship",
    description: "Inter-university debate finals.",
    startTime: new Date(Date.now() + 2 * 3600_000),
    endTime:   new Date(Date.now() + 5 * 3600_000),
  },
  {
    id: "e4",
    zoneId: 3, // Library
    title: "Coding Workshop",
    description: "Build a REST API with FastAPI.",
    startTime: new Date(Date.now() + 3 * 3600_000),
    endTime:   new Date(Date.now() + 6 * 3600_000),
  },
  {
    id: "e5",
    zoneId: 1, // Gym
    title: "Morning Run",
    description: "5 km campus loop. All paces welcome.",
    startTime: new Date(Date.now() + 8 * 3600_000),
    endTime:   new Date(Date.now() + 10 * 3600_000),
  },
  {
    id: "e6",
    zoneId: 9, // Student Center
    title: "Open Mic Night",
    description: "Singers, guitarists, poets — all welcome.",
    startTime: new Date(Date.now() + 48 * 3600_000),
    endTime:   new Date(Date.now() + 51 * 3600_000),
  },
];

export function App() {
  return (
    <div style={{ padding: 32 }}>
      <h2 style={{ marginBottom: 16, color: "#fff" }}>Campus Activity</h2>
      <CampusHeatmap
        events={sampleEvents}
        width={700}
        height={500}
      />
    </div>
  );
}

// ── Example B: Vanilla JS (no framework) ─────────────────────────────────────
//
//  import { CampusHeatmap } from "./CampusHeatmap.vanilla";
//  import { CampusEvent } from "./heatmapLogic";
//
//  const hm = new CampusHeatmap(document.getElementById("map")!, {
//    events: sampleEvents,
//    width:  700,
//    height: 500,
//    onZoneSelect: (result) => {
//      if (result) {
//        console.log(`${result.zoneName}: ${result.events.length} events this week`);
//      }
//    },
//  });
//
//  // Live update when data changes:
//  hm.setEvents(updatedEvents);
//
//  // Teardown:
//  hm.destroy();
