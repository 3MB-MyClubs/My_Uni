// ─────────────────────────────────────────────────────────────────────────────
//  CampusHeatmap — React Component
//
//  PUBLIC VIEW  : canvas heatmap (color intensity only, no labels)
//  HOVER        : zone name tooltip only
//  CLICK VIEW   : zone event panel showing this week's events
// ─────────────────────────────────────────────────────────────────────────────

import React, {
  useRef,
  useEffect,
  useState,
  useCallback,
  useMemo,
} from "react";
import type {
  FC,
  CSSProperties,
  MouseEvent as ReactMouseEvent,
  KeyboardEvent as ReactKeyboardEvent,
} from "react";
import {
  ZONES,
  CampusEvent,
  HeatPoint,
  ZoneClickResult,
  getEventCounts,
  normalizeCounts,
  generateHeatPoints,
  handleZoneClick,
} from "./heatmapLogic";

// ── Canvas rendering constants ────────────────────────────────────────────────

const CANVAS_W = 280;
const CANVAS_H = 200;
const SIGMA    = 13;

// ── Color map: transparent → blue → cyan → orange → red ──────────────────────

function heatToRGBA(t: number): [number, number, number, number] {
  if (t <= 0) return [0, 0, 0, 0];
  const v = Math.min(t, 1);

  let r: number, g: number, b: number;

  if (v < 0.25) {
    const f = v / 0.25;
    r = 0; g = 0; b = Math.round(130 + 125 * f);
  } else if (v < 0.5) {
    const f = (v - 0.25) / 0.25;
    r = 0; g = Math.round(180 * f); b = 255;
  } else if (v < 0.75) {
    const f = (v - 0.5) / 0.25;
    r = Math.round(255 * f);
    g = Math.round(180 - 60 * f);
    b = Math.round(255 * (1 - f));
  } else {
    const f = (v - 0.75) / 0.25;
    r = 255; g = Math.round(120 * (1 - f)); b = 0;
  }

  return [r, g, b, Math.round(50 + 205 * v)];
}

// ── Gaussian heatmap renderer ─────────────────────────────────────────────────

function drawHeatmap(canvas: HTMLCanvasElement, points: HeatPoint[]): void {
  const ctx = canvas.getContext("2d");
  if (!ctx) return;

  const W  = CANVAS_W;
  const H  = CANVAS_H;

  // Always clear first so removing all events wipes the canvas
  ctx.clearRect(0, 0, W, H);
  if (points.length === 0) return;

  const s2  = 2 * SIGMA * SIGMA;
  const img = ctx.createImageData(W, H);
  const buf = img.data;
  const raw = new Float32Array(W * H);
  let max   = 0;

  for (let row = 0; row < H; row++) {
    const gy = (row / (H - 1)) * 100;
    for (let col = 0; col < W; col++) {
      const gx = (col / (W - 1)) * 100;
      let h = 0;
      for (const p of points) {
        const dx = gx - p.x;
        const dy = gy - p.y;
        h += p.intensity * Math.exp(-(dx * dx + dy * dy) / s2);
      }
      raw[row * W + col] = h;
      if (h > max) { max = h; }
    }
  }

  for (let i = 0; i < W * H; i++) {
    const norm = max > 0 ? raw[i] / max : 0;
    const [r, g, b, a] = heatToRGBA(norm);
    const idx = i * 4;
    buf[idx]     = r;
    buf[idx + 1] = g;
    buf[idx + 2] = b;
    buf[idx + 3] = a;
  }

  ctx.putImageData(img, 0, 0);
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function fmtDate(d: Date): string {
  return d.toLocaleDateString([], { weekday: "short", month: "short", day: "numeric" });
}

function fmtTime(d: Date): string {
  return d.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}

// ── Props ─────────────────────────────────────────────────────────────────────

export interface CampusHeatmapProps {
  events: CampusEvent[];
  /** Container width in px. Default 700. */
  width?: number;
  /** Map height in px. Default 500. */
  height?: number;
  className?: string;
  style?: CSSProperties;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Component
// ─────────────────────────────────────────────────────────────────────────────

const CampusHeatmap: FC<CampusHeatmapProps> = ({
  events,
  width  = 700,
  height = 500,
  className,
  style,
}) => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const mapRef    = useRef<HTMLDivElement>(null);

  const [tooltip, setTooltip] = useState<{
    visible: boolean;
    x: number;
    y: number;
    name: string;
  }>({ visible: false, x: 0, y: 0, name: "" });

  const [selected, setSelected] = useState<ZoneClickResult | null>(null);

  // ── Heat data ─────────────────────────────────────────────────────────────

  const heatPoints = useMemo<HeatPoint[]>(() => {
    const counts = getEventCounts(events);
    const norm   = normalizeCounts(counts);
    return generateHeatPoints(ZONES, norm);
  }, [events]);

  // Re-render canvas when heat data changes
  useEffect(() => {
    if (canvasRef.current) {
      drawHeatmap(canvasRef.current, heatPoints);
    }
  }, [heatPoints]);

  // Keep the selected panel in sync when the events prop changes
  useEffect(() => {
    if (selected !== null) {
      setSelected(handleZoneClick(selected.zoneId, events));
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [events]);

  // ── Interaction handlers ──────────────────────────────────────────────────

  const onZoneEnter = useCallback((zoneId: number, e: ReactMouseEvent) => {
    const rect = mapRef.current?.getBoundingClientRect();
    if (!rect) return;
    setTooltip({
      visible: true,
      x: e.clientX - rect.left,
      y: e.clientY - rect.top,
      name: ZONES[zoneId]?.name ?? "",
    });
  }, []);

  const onZoneMove = useCallback((e: ReactMouseEvent) => {
    const rect = mapRef.current?.getBoundingClientRect();
    if (!rect) return;
    setTooltip((prev: typeof tooltip) =>
      prev.visible
        ? { ...prev, x: e.clientX - rect.left, y: e.clientY - rect.top }
        : prev
    );
  }, []);

  const onZoneLeave = useCallback(() => {
    setTooltip((prev: typeof tooltip) => ({ ...prev, visible: false }));
  }, []);

  const onZoneClick = useCallback(
    (zoneId: number) => {
      setSelected((prev: ZoneClickResult | null) =>
        prev?.zoneId === zoneId ? null : handleZoneClick(zoneId, events)
      );
    },
    [events]
  );

  // ── Render ────────────────────────────────────────────────────────────────

  return (
    <div
      className={className}
      style={{
        fontFamily: "-apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
        width,
        ...style,
      }}
    >
      {/* ── MAP AREA ─────────────────────────────────────────────────────── */}
      <div
        ref={mapRef}
        style={{
          position:     "relative",
          width:        "100%",
          height,
          borderRadius: 14,
          overflow:     "hidden",
          background:   "#06060e",
          boxShadow:    "0 4px 32px rgba(0,0,0,0.6)",
        }}
      >
        {/* Canvas — PUBLIC VIEW: color only, no labels */}
        <canvas
          ref={canvasRef}
          width={CANVAS_W}
          height={CANVAS_H}
          style={{
            position: "absolute",
            top:      0,
            left:     0,
            right:    0,
            bottom:   0,
            width:    "100%",
            height:   "100%",
          }}
        />

        {/* Invisible zone hit areas */}
        {Object.entries(ZONES).map(([id, zone]) => {
          const zoneId     = Number(id);
          const isSelected = selected?.zoneId === zoneId;
          const isActive   = heatPoints.some((p: HeatPoint) => p.zoneId === zoneId);

          return (
            <div
              key={id}
              role="button"
              aria-label={zone.name}
              tabIndex={0}
              onMouseEnter={(e: ReactMouseEvent) => onZoneEnter(zoneId, e)}
              onMouseMove={onZoneMove}
              onMouseLeave={onZoneLeave}
              onClick={() => onZoneClick(zoneId)}
              onKeyDown={(e: ReactKeyboardEvent) => { if (e.key === "Enter" || e.key === " ") { onZoneClick(zoneId); } }}
              style={{
                position:     "absolute",
                left:         `${zone.x}%`,
                top:          `${zone.y}%`,
                width:        52,
                height:       52,
                transform:    "translate(-50%, -50%)",
                borderRadius: "50%",
                cursor:       "pointer",
                outline:      "none",
                transition:   "border 0.15s, background 0.15s, box-shadow 0.15s",
                border:       isSelected
                  ? "2px solid rgba(255,255,255,0.85)"
                  : isActive
                  ? "1.5px solid rgba(255,255,255,0.18)"
                  : "1px solid rgba(255,255,255,0.05)",
                background:   isSelected ? "rgba(255,255,255,0.12)" : "transparent",
                boxShadow:    isSelected ? "0 0 20px rgba(255,255,255,0.18)" : "none",
              }}
            />
          );
        })}

        {/* Hover tooltip — zone name ONLY */}
        {tooltip.visible && (
          <div
            aria-hidden="true"
            style={{
              position:      "absolute",
              left:          tooltip.x,
              top:           tooltip.y - 40,
              transform:     "translateX(-50%)",
              pointerEvents: "none",
              background:    "rgba(8,8,18,0.90)",
              color:         "#fff",
              fontSize:      12,
              fontWeight:    600,
              letterSpacing: "0.3px",
              padding:       "5px 11px",
              borderRadius:  8,
              whiteSpace:    "nowrap",
              border:        "1px solid rgba(255,255,255,0.1)",
              zIndex:        30,
            }}
          >
            {tooltip.name}
          </div>
        )}

        {/* Legend */}
        <div
          aria-hidden="true"
          style={{
            position:    "absolute",
            bottom:      10,
            left:        12,
            display:     "flex",
            alignItems:  "center",
            gap:         6,
            background:  "rgba(6,6,14,0.80)",
            borderRadius: 8,
            padding:     "5px 10px",
            border:      "1px solid rgba(255,255,255,0.06)",
          }}
        >
          <span style={{ fontSize: 10, color: "rgba(255,255,255,0.38)" }}>Low</span>
          <div
            style={{
              width:        76,
              height:       7,
              borderRadius: 4,
              background:   "linear-gradient(to right, #0000cc, #00b4ff, #ff8000, #ff0000)",
            }}
          />
          <span style={{ fontSize: 10, color: "rgba(255,255,255,0.38)" }}>High</span>
        </div>
      </div>

      {/* ── ZONE EVENT PANEL ─────────────────────────────────────────────── */}
      {selected && (
        <div
          style={{
            marginTop:    10,
            background:   "rgba(8,8,16,0.98)",
            borderRadius: 12,
            border:       "1px solid rgba(255,255,255,0.08)",
            overflow:     "hidden",
          }}
        >
          {/* Header */}
          <div
            style={{
              display:        "flex",
              justifyContent: "space-between",
              alignItems:     "center",
              padding:        "12px 16px",
              borderBottom:   "1px solid rgba(255,255,255,0.06)",
            }}
          >
            <div>
              <div
                style={{
                  fontSize:      10,
                  color:         "rgba(255,255,255,0.38)",
                  textTransform: "uppercase",
                  letterSpacing: "1.2px",
                  marginBottom:  3,
                }}
              >
                This Week
              </div>
              <div style={{ fontSize: 15, fontWeight: 700, color: "#fff" }}>
                {selected.zoneName}
              </div>
            </div>

            <button
              onClick={() => setSelected(null)}
              aria-label="Close panel"
              style={{
                background:    "rgba(255,255,255,0.06)",
                border:        "1px solid rgba(255,255,255,0.08)",
                color:         "rgba(255,255,255,0.5)",
                width:         28,
                height:        28,
                borderRadius:  "50%",
                cursor:        "pointer",
                fontSize:      18,
                lineHeight:    "1",
                display:       "flex",
                alignItems:    "center",
                justifyContent: "center",
                padding:       0,
              }}
            >
              ×
            </button>
          </div>

          {/* Events */}
          <div style={{ padding: "10px 16px 16px" }}>
            {selected.events.length === 0 ? (
              <p
                style={{
                  color:     "rgba(255,255,255,0.28)",
                  fontSize:  13,
                  textAlign: "center",
                  margin:    "24px 0",
                }}
              >
                No events scheduled this week
              </p>
            ) : (
              <div
                style={{
                  display:             "grid",
                  gridTemplateColumns: "repeat(auto-fill, minmax(200px, 1fr))",
                  gap:                 8,
                  marginTop:           8,
                }}
              >
                {selected.events.map((ev) => (
                  <div
                    key={ev.id}
                    style={{
                      background:   "rgba(255,255,255,0.04)",
                      borderRadius: 9,
                      padding:      "10px 13px",
                      border:       "1px solid rgba(255,255,255,0.07)",
                    }}
                  >
                    <div
                      style={{
                        fontSize:     13,
                        fontWeight:   600,
                        color:        "#fff",
                        marginBottom: 5,
                        lineHeight:   "1.3",
                      }}
                    >
                      {ev.title}
                    </div>
                    <div style={{ fontSize: 11, color: "rgba(255,255,255,0.4)" }}>
                      {fmtDate(ev.startTime)}&nbsp;&middot;&nbsp;
                      {fmtTime(ev.startTime)}–{fmtTime(ev.endTime)}
                    </div>
                    {ev.description && (
                      <div
                        style={{
                          fontSize:   11,
                          color:      "rgba(255,255,255,0.28)",
                          marginTop:  5,
                          lineHeight: "1.45",
                        }}
                      >
                        {ev.description}
                      </div>
                    )}
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
};

export default CampusHeatmap;
