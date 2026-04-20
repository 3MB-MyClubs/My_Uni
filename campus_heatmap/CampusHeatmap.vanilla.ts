// ─────────────────────────────────────────────────────────────────────────────
//  CampusHeatmap — Vanilla TypeScript / JavaScript Implementation
//  Zero framework dependency. Drop into any HTML page.
//
//  Usage:
//    const hm = new CampusHeatmap(document.getElementById('map')!, {
//      events,
//      width: 700,
//      height: 500,
//      onZoneSelect: (result) => console.log(result),
//    });
//    hm.setEvents(updatedEvents); // live update
//    hm.destroy();                // cleanup
// ─────────────────────────────────────────────────────────────────────────────

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

// ── Rendering constants ───────────────────────────────────────────────────────

const CANVAS_W = 280;
const CANVAS_H = 200;
const SIGMA    = 13;

// ── Color map ─────────────────────────────────────────────────────────────────

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
    r = Math.round(255 * f); g = Math.round(180 - 60 * f); b = Math.round(255 * (1 - f));
  } else {
    const f = (v - 0.75) / 0.25;
    r = 255; g = Math.round(120 * (1 - f)); b = 0;
  }

  return [r, g, b, Math.round(50 + 205 * v)];
}

// ── Canvas renderer ───────────────────────────────────────────────────────────

function drawHeatmap(canvas: HTMLCanvasElement, points: HeatPoint[]): void {
  const ctx = canvas.getContext("2d");
  if (!ctx) return;

  const W  = CANVAS_W;
  const H  = CANVAS_H;
  const s2 = 2 * SIGMA * SIGMA;
  const img = ctx.createImageData(W, H);
  const buf = img.data;
  const raw = new Float32Array(W * H);
  let max = 0;

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
      if (h > max) max = h;
    }
  }

  for (let i = 0; i < W * H; i++) {
    const norm = max > 0 ? raw[i] / max : 0;
    const [r, g, b, a] = heatToRGBA(norm);
    const idx = i * 4;
    buf[idx] = r; buf[idx + 1] = g; buf[idx + 2] = b; buf[idx + 3] = a;
  }

  ctx.putImageData(img, 0, 0);
}

// ── Options ───────────────────────────────────────────────────────────────────

export interface HeatmapOptions {
  events: CampusEvent[];
  width?: number;
  height?: number;
  /** Called whenever the selected zone changes. Receives null on deselect. */
  onZoneSelect?: (result: ZoneClickResult | null) => void;
}

// ─────────────────────────────────────────────────────────────────────────────
//  CampusHeatmap class
// ─────────────────────────────────────────────────────────────────────────────

export class CampusHeatmap {
  private readonly root:     HTMLElement;
  private readonly mapWrap:  HTMLElement;
  private readonly canvas:   HTMLCanvasElement;
  private readonly tooltip:  HTMLElement;
  private readonly panel:    HTMLElement;
  private readonly zoneEls:  Map<number, HTMLElement> = new Map();

  private events:       CampusEvent[];
  private heatPoints:   HeatPoint[] = [];
  private selectedZone: ZoneClickResult | null = null;
  private onZoneSelect: ((r: ZoneClickResult | null) => void) | undefined;

  private readonly width:  number;
  private readonly height: number;

  constructor(container: HTMLElement, options: HeatmapOptions) {
    this.events       = options.events;
    this.width        = options.width  ?? 700;
    this.height       = options.height ?? 500;
    this.onZoneSelect = options.onZoneSelect;
    this.root         = container;

    // ── Outer wrapper ─────────────────────────────────────────────────────
    this.root.style.cssText = `
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      width: ${this.width}px;
    `;

    // ── Map wrapper ───────────────────────────────────────────────────────
    this.mapWrap = this._el("div", {
      position:     "relative",
      width:        "100%",
      height:       `${this.height}px`,
      borderRadius: "14px",
      overflow:     "hidden",
      background:   "#06060e",
      boxShadow:    "0 4px 32px rgba(0,0,0,0.6)",
    });
    this.root.appendChild(this.mapWrap);

    // ── Canvas (public heatmap view) ──────────────────────────────────────
    this.canvas = document.createElement("canvas");
    this.canvas.width  = CANVAS_W;
    this.canvas.height = CANVAS_H;
    Object.assign(this.canvas.style, {
      position: "absolute",
      inset:    "0",
      width:    "100%",
      height:   "100%",
    } as CSSProperties);
    this.mapWrap.appendChild(this.canvas);

    // ── Zone hit areas ────────────────────────────────────────────────────
    for (const [idStr, zone] of Object.entries(ZONES)) {
      const zoneId = Number(idStr);
      const el = this._el("div", {
        position:     "absolute",
        left:         `${zone.x}%`,
        top:          `${zone.y}%`,
        width:        "52px",
        height:       "52px",
        transform:    "translate(-50%, -50%)",
        borderRadius: "50%",
        cursor:       "pointer",
        transition:   "border 0.15s, background 0.15s",
        border:       "1px solid rgba(255,255,255,0.05)",
        background:   "transparent",
      });
      el.setAttribute("aria-label", zone.name);
      el.setAttribute("role", "button");
      el.setAttribute("title", "");

      el.addEventListener("mouseenter", (e) => this._onEnter(zoneId, e as MouseEvent));
      el.addEventListener("mousemove",  (e) => this._onMove(e as MouseEvent));
      el.addEventListener("mouseleave", () => this._onLeave());
      el.addEventListener("click",      () => this._onClick(zoneId));

      this.mapWrap.appendChild(el);
      this.zoneEls.set(zoneId, el);
    }

    // ── Tooltip (hover → zone name only) ─────────────────────────────────
    this.tooltip = this._el("div", {
      position:       "absolute",
      pointerEvents:  "none",
      background:     "rgba(8,8,18,0.90)",
      color:          "#fff",
      fontSize:       "12px",
      fontWeight:     "600",
      letterSpacing:  "0.3px",
      padding:        "5px 11px",
      borderRadius:   "8px",
      whiteSpace:     "nowrap",
      border:         "1px solid rgba(255,255,255,0.1)",
      backdropFilter: "blur(10px)",
      zIndex:         "30",
      display:        "none",
    });
    this.mapWrap.appendChild(this.tooltip);

    // ── Legend ────────────────────────────────────────────────────────────
    const legend = this._el("div", {
      position:       "absolute",
      bottom:         "10px",
      left:           "12px",
      display:        "flex",
      alignItems:     "center",
      gap:            "6px",
      background:     "rgba(6,6,14,0.72)",
      borderRadius:   "8px",
      padding:        "5px 10px",
      backdropFilter: "blur(8px)",
      border:         "1px solid rgba(255,255,255,0.06)",
    });
    legend.innerHTML = `
      <span style="font-size:10px;color:rgba(255,255,255,0.35)">Low</span>
      <div style="width:76px;height:7px;border-radius:4px;
        background:linear-gradient(to right,#0000cc,#00b4ff,#ff8000,#ff0000)"></div>
      <span style="font-size:10px;color:rgba(255,255,255,0.35)">High</span>
    `;
    this.mapWrap.appendChild(legend);

    // ── Event panel (click interaction view) ─────────────────────────────
    this.panel = this._el("div", {
      marginTop:    "10px",
      background:   "rgba(8,8,16,0.98)",
      borderRadius: "12px",
      border:       "1px solid rgba(255,255,255,0.08)",
      overflow:     "hidden",
      display:      "none",
    });
    this.root.appendChild(this.panel);

    // Initial render
    this._compute();
    this._render();
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /** Replace the event dataset and re-render the heatmap. */
  setEvents(events: CampusEvent[]): void {
    this.events = events;
    this._compute();
    this._render();
    // Refresh panel if a zone is selected
    if (this.selectedZone) {
      this._selectZone(this.selectedZone.zoneId);
    }
  }

  /** Remove all DOM nodes and event listeners added by this instance. */
  destroy(): void {
    this.root.innerHTML = "";
    this.zoneEls.clear();
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  private _compute(): void {
    const counts = getEventCounts(this.events);
    const norm   = normalizeCounts(counts);
    this.heatPoints = generateHeatPoints(ZONES, norm);
  }

  private _render(): void {
    drawHeatmap(this.canvas, this.heatPoints);
    this._updateZoneStyles();
  }

  private _updateZoneStyles(): void {
    for (const [zoneId, el] of this.zoneEls) {
      const isSelected = this.selectedZone?.zoneId === zoneId;
      const isActive   = this.heatPoints.some((p) => p.zoneId === zoneId);
      el.style.border = isSelected
        ? "2px solid rgba(255,255,255,0.85)"
        : isActive
        ? "1.5px solid rgba(255,255,255,0.18)"
        : "1px solid rgba(255,255,255,0.05)";
      el.style.background  = isSelected ? "rgba(255,255,255,0.12)" : "transparent";
      el.style.boxShadow   = isSelected ? "0 0 20px rgba(255,255,255,0.18)" : "none";
    }
  }

  private _onEnter(zoneId: number, e: MouseEvent): void {
    const rect = this.mapWrap.getBoundingClientRect();
    this.tooltip.textContent = ZONES[zoneId].name;
    this.tooltip.style.left    = `${e.clientX - rect.left}px`;
    this.tooltip.style.top     = `${e.clientY - rect.top - 40}px`;
    this.tooltip.style.transform = "translateX(-50%)";
    this.tooltip.style.display = "block";
  }

  private _onMove(e: MouseEvent): void {
    if (this.tooltip.style.display === "none") return;
    const rect = this.mapWrap.getBoundingClientRect();
    this.tooltip.style.left = `${e.clientX - rect.left}px`;
    this.tooltip.style.top  = `${e.clientY - rect.top - 40}px`;
  }

  private _onLeave(): void {
    this.tooltip.style.display = "none";
  }

  private _onClick(zoneId: number): void {
    if (this.selectedZone?.zoneId === zoneId) {
      this.selectedZone = null;
      this.panel.style.display = "none";
      this.onZoneSelect?.(null);
    } else {
      this._selectZone(zoneId);
    }
    this._updateZoneStyles();
  }

  private _selectZone(zoneId: number): void {
    const result = handleZoneClick(zoneId, this.events);
    this.selectedZone = result;
    this.onZoneSelect?.(result);
    this._renderPanel(result);
    this._updateZoneStyles();
  }

  private _renderPanel(result: ZoneClickResult): void {
    const eventsHTML =
      result.events.length === 0
        ? `<p style="color:rgba(255,255,255,0.28);font-size:13px;text-align:center;margin:24px 0">
             No events scheduled this week
           </p>`
        : `<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:8px;margin-top:8px">
            ${result.events
              .map(
                (ev) => `
              <div style="background:rgba(255,255,255,0.04);border-radius:9px;
                          padding:10px 13px;border:1px solid rgba(255,255,255,0.07)">
                <div style="font-size:13px;font-weight:600;color:#fff;margin-bottom:5px;line-height:1.3">
                  ${this._esc(ev.title)}
                </div>
                <div style="font-size:11px;color:rgba(255,255,255,0.4)">
                  ${this._fmtDate(ev.startTime)} &middot;
                  ${this._fmtTime(ev.startTime)}–${this._fmtTime(ev.endTime)}
                </div>
                ${
                  ev.description
                    ? `<div style="font-size:11px;color:rgba(255,255,255,0.28);margin-top:5px;line-height:1.45">
                         ${this._esc(ev.description)}
                       </div>`
                    : ""
                }
              </div>`
              )
              .join("")}
           </div>`;

    this.panel.innerHTML = `
      <div style="display:flex;justify-content:space-between;align-items:center;
                  padding:12px 16px;border-bottom:1px solid rgba(255,255,255,0.06)">
        <div>
          <div style="font-size:10px;color:rgba(255,255,255,0.38);
                      text-transform:uppercase;letter-spacing:1.2px;margin-bottom:3px">
            This Week
          </div>
          <div style="font-size:15px;font-weight:700;color:#fff">
            ${this._esc(result.zoneName)}
          </div>
        </div>
        <button id="hm-close" style="background:rgba(255,255,255,0.06);
          border:1px solid rgba(255,255,255,0.08);color:rgba(255,255,255,0.5);
          width:28px;height:28px;border-radius:50%;cursor:pointer;
          font-size:18px;line-height:1;display:flex;align-items:center;
          justify-content:center;padding:0" aria-label="Close">×</button>
      </div>
      <div style="padding:10px 16px 16px">${eventsHTML}</div>
    `;

    this.panel.style.display = "block";
    this.panel
      .querySelector<HTMLButtonElement>("#hm-close")
      ?.addEventListener("click", () => this._onClick(result.zoneId));
  }

  // ── DOM helpers ───────────────────────────────────────────────────────────

  private _el(tag: string, styles: Record<string, string>): HTMLElement {
    const el = document.createElement(tag);
    Object.assign(el.style, styles);
    return el;
  }

  private _esc(str: string): string {
    return str
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  private _fmtDate(d: Date): string {
    return d.toLocaleDateString([], { weekday: "short", month: "short", day: "numeric" });
  }

  private _fmtTime(d: Date): string {
    return d.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
  }
}

// Re-export CSSProperties shim for internal use (no React dep needed)
type CSSProperties = Partial<CSSStyleDeclaration>;
