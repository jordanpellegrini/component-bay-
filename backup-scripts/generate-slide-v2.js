#!/usr/bin/env node
/**
 * Components Bay — Slide Generator v2
 * Layout: dark sidebar + full-height table, dark theme, professional look
 */

const pptxgen = require("pptxgenjs");
const https   = require("https");
const http    = require("http");
const path    = require("path");
const fs      = require("fs");

// ─── Supabase ──────────────────────────────────────────────────────────────
const SUPABASE_URL = "https://nwidtkiteamvnomewjux.supabase.co";
const SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im53aWR0a2l0ZWFtdm5vbWV3anV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEzMTM3MDAsImV4cCI6MjA4Njg4OTcwMH0.fvKwq5B8Bdr2Hv67yvB6JRKA2Gu3xTIEgPmcmJj0nvI";

// ─── Output path ───────────────────────────────────────────────────────────
const today   = new Date().toISOString().slice(0, 10);
let OUTPUT_DIR = "C:\\Users\\jpellegrini\\Desktop\\APP 5.5";
if (!fs.existsSync(OUTPUT_DIR)) OUTPUT_DIR = "C:\\ComponentsBay_Logs";
if (!fs.existsSync(OUTPUT_DIR)) OUTPUT_DIR = path.join(__dirname, ".");
const OUTPUT  = path.join(OUTPUT_DIR, `Component_Bay_Slide_${today}.pptx`);

// ─── Design tokens ─────────────────────────────────────────────────────────
const C = {
  bg:       "0F1623",   // deep navy background
  sidebar:  "141D2B",   // slightly lighter sidebar
  accent1:  "C0392B",   // red  — unserviceable
  accent2:  "E8A000",   // amber — due soon
  white:    "FFFFFF",
  offwhite: "E8ECF0",
  muted:    "8899AA",
  rowAlt:   "192030",   // alternate row bg
  rowBase:  "0F1623",   // base row bg
  hdrBg:    "1E2A3B",   // header row bg
  red:      "E74C3C",
  orange:   "F39C12",
  green:    "27AE60",
  border:   "2A3A50",
};

// Slide uses LAYOUT_WIDE = 13.3" × 7.5"
const W = 13.33, H = 7.5;

// Sidebar strip (left)
const SB_W   = 2.5;     // sidebar width
const SB_X   = 0;
// Table area (right of sidebar)
const TBL_X  = SB_W + 0.18;
const TBL_W  = W - TBL_X - 0.18;  // ~10.47"
const TBL_Y  = 0.5;
const TBL_H  = H - TBL_Y - 0.25;

// ─── HTTP fetch ─────────────────────────────────────────────────────────────
function fetchJson(url) {
  return new Promise((resolve, reject) => {
    const lib = url.startsWith("https") ? https : http;
    lib.get(url, {
      headers: {
        "apikey": SUPABASE_KEY,
        "Authorization": `Bearer ${SUPABASE_KEY}`
      }
    }, res => {
      let data = "";
      res.on("data", d => data += d);
      res.on("end", () => {
        try { resolve(JSON.parse(data)); }
        catch(e) { reject(e); }
      });
    }).on("error", reject);
  });
}

async function fetchTable(table) {
  const rows = await fetchJson(`${SUPABASE_URL}/rest/v1/${table}?select=*`);
  return rows.map(r => {
    let d = r.data || {};
    if (typeof d === "string") d = JSON.parse(d);
    return d;
  });
}

// ─── Helpers ─────────────────────────────────────────────────────────────────
function daysLeft(dateStr) {
  if (!dateStr) return null;
  const d = new Date(String(dateStr).slice(0, 10));
  const diff = Math.round((d - new Date()) / 86400000);
  return isNaN(diff) ? null : diff;
}

function dayColor(d) {
  if (d === null) return C.white;
  if (d <= 0)  return C.red;
  if (d <= 30) return C.red;
  if (d <= 60) return C.orange;
  return C.green;
}

function trunc(s, n = 32) {
  s = String(s || "");
  return s.length > n ? s.slice(0, n) + "…" : s;
}

// ─── Slide builder ─────────────────────────────────────────────────────────
function makeShadow() {
  return { type: "outer", color: "000000", blur: 8, offset: 2, angle: 135, opacity: 0.25 };
}

/**
 * Build a full slide: dark background + sidebar + header bar + table
 * @param {pptxgen} prs
 * @param {string}  title      Main title (e.g. "Other Parts")
 * @param {string}  subtitle   Sub-label (e.g. "NEED TO BE C/OUT")
 * @param {string}  accentColor hex color for sidebar & header
 * @param {string}  headerLabel Full header text
 * @param {number}  count       Item count
 * @param {string[]} headers    Column headers
 * @param {Array}   rows        Data rows (array of arrays)
 * @param {number[]} colW       Column widths in inches (must sum to TBL_W)
 * @param {number}  daysColIdx  Index of "DAYS LEFT" column (or -1)
 */
function buildSlide(prs, { title, subtitle, accentColor, headerLabel, count, headers, rows, colW, daysColIdx = -1 }) {
  const slide = prs.addSlide();

  // ── Dark background ──────────────────────────────────────────────────────
  slide.background = { color: C.bg };

  // ── Left sidebar ─────────────────────────────────────────────────────────
  // Main sidebar block
  slide.addShape(prs.shapes.RECTANGLE, {
    x: 0, y: 0, w: SB_W, h: H,
    fill: { color: C.sidebar },
    line: { color: C.sidebar },
  });

  // Colored accent stripe on the left edge
  slide.addShape(prs.shapes.RECTANGLE, {
    x: 0, y: 0, w: 0.06, h: H,
    fill: { color: accentColor },
    line: { color: accentColor },
  });

  // ── Sidebar text ─────────────────────────────────────────────────────────
  // Big count number
  slide.addText(String(count), {
    x: 0.1, y: 0.3, w: SB_W - 0.2, h: 1.2,
    fontSize: 72, bold: true, color: accentColor,
    align: "center", valign: "middle", fontFace: "Calibri",
  });

  // Horizontal separator
  slide.addShape(prs.shapes.RECTANGLE, {
    x: 0.2, y: 1.55, w: SB_W - 0.4, h: 0.025,
    fill: { color: accentColor },
    line: { color: accentColor },
  });

  // Title
  slide.addText(title, {
    x: 0.1, y: 1.65, w: SB_W - 0.2, h: 1.1,
    fontSize: 22, bold: true, color: C.white,
    align: "center", valign: "middle", fontFace: "Calibri",
    wrap: true,
  });

  // Subtitle tag
  slide.addShape(prs.shapes.RECTANGLE, {
    x: 0.2, y: 2.9, w: SB_W - 0.4, h: 0.52,
    fill: { color: accentColor },
    line: { color: accentColor },
    shadow: makeShadow(),
  });
  slide.addText(subtitle, {
    x: 0.2, y: 2.9, w: SB_W - 0.4, h: 0.52,
    fontSize: 11, bold: true, color: C.white,
    align: "center", valign: "middle", fontFace: "Calibri",
    margin: 0,
  });

  // Date stamp at bottom of sidebar
  slide.addText(today, {
    x: 0.1, y: H - 0.45, w: SB_W - 0.2, h: 0.35,
    fontSize: 9, color: C.muted,
    align: "center", fontFace: "Calibri",
  });

  // ── Header bar ───────────────────────────────────────────────────────────
  const BAR_H = 0.38;
  slide.addShape(prs.shapes.RECTANGLE, {
    x: TBL_X, y: TBL_Y, w: TBL_W, h: BAR_H,
    fill: { color: accentColor },
    line: { color: accentColor },
  });
  slide.addText(`⚠  ${headerLabel}`, {
    x: TBL_X + 0.12, y: TBL_Y, w: TBL_W - 1.5, h: BAR_H,
    fontSize: 10, bold: true, color: C.white,
    align: "left", valign: "middle", fontFace: "Calibri",
    margin: 0,
  });
  slide.addText(String(count), {
    x: TBL_X + TBL_W - 1.4, y: TBL_Y, w: 1.3, h: BAR_H,
    fontSize: 13, bold: true, color: C.white,
    align: "right", valign: "middle", fontFace: "Calibri",
    margin: 0,
  });

  // ── Column headers ───────────────────────────────────────────────────────
  const HDR_Y = TBL_Y + BAR_H;
  const HDR_H = 0.30;
  let cx = TBL_X;
  headers.forEach((h, i) => {
    slide.addShape(prs.shapes.RECTANGLE, {
      x: cx, y: HDR_Y, w: colW[i], h: HDR_H,
      fill: { color: C.hdrBg },
      line: { color: C.border, width: 0.5 },
    });
    slide.addText(h, {
      x: cx + 0.04, y: HDR_Y, w: colW[i] - 0.08, h: HDR_H,
      fontSize: 8, bold: true, color: C.accent2,
      align: "left", valign: "middle", fontFace: "Calibri",
      margin: 0, charSpacing: 1,
    });
    cx += colW[i];
  });

  // ── Data rows ────────────────────────────────────────────────────────────
  const DATA_Y = HDR_Y + HDR_H;
  const DATA_H = H - DATA_Y - 0.2;
  const nRows  = rows.length;
  const rowH   = Math.min(DATA_H / nRows, 0.26);

  rows.forEach((row, ri) => {
    const ry      = DATA_Y + ri * rowH;
    const rowBg   = ri % 2 === 0 ? C.rowBase : C.rowAlt;
    cx = TBL_X;

    row.forEach((cell, ci) => {
      const cellText = String(cell || "");
      let textColor  = C.offwhite;

      // Color DAYS LEFT column
      if (ci === daysColIdx && cellText) {
        const d = parseInt(cellText);
        textColor = dayColor(isNaN(d) ? null : d);
      }

      // Cell background
      slide.addShape(prs.shapes.RECTANGLE, {
        x: cx, y: ry, w: colW[ci], h: rowH,
        fill: { color: rowBg },
        line: { color: C.border, width: 0.3 },
      });

      // Cell text
      slide.addText(cellText, {
        x: cx + 0.04, y: ry, w: colW[ci] - 0.08, h: rowH,
        fontSize: 7.5, color: textColor, fontFace: "Calibri",
        align: "left", valign: "middle",
        margin: 0, shrinkText: true,
      });

      cx += colW[ci];
    });
  });

  // Bottom border line
  slide.addShape(prs.shapes.RECTANGLE, {
    x: TBL_X, y: DATA_Y + nRows * rowH, w: TBL_W, h: 0.02,
    fill: { color: accentColor },
    line: { color: accentColor },
  });

  return slide;
}

// ─── Main ──────────────────────────────────────────────────────────────────
async function main() {
  console.log("=".repeat(55));
  console.log("  Components Bay — Slide Generator v2");
  console.log(`  ${today}`);
  console.log("=".repeat(55));

  console.log("\nLoading Supabase data...");
  let efs, efsCyl, liferafts, maint, comp, avio, eng, rotor, iaft, pol, tools, troop;
  try {
    [efs, efsCyl, liferafts, maint, comp, avio, eng, rotor, iaft, pol, tools, troop] = await Promise.all([
      fetchTable("efs"),
      fetchTable("efs_cylinders"),
      fetchTable("liferafts"),
      fetchTable("maintenance"),
      fetchTable("composite"),
      fetchTable("avionic"),
      fetchTable("engine"),
      fetchTable("rotorbay"),
      fetchTable("iafteaft"),
      fetchTable("pol"),
      fetchTable("tools"),
      fetchTable("troopseats"),
    ]);
  } catch(e) {
    console.error("Supabase error:", e.message);
    process.exit(1);
  }

  // ── Slide 1: Other Parts U/S ──────────────────────────────────────────
  const s1rows = [];
  const modules = [
    ["Maintenance", maint], ["Composite", comp], ["Avionic", avio],
    ["Engine", eng], ["Rotor Bay", rotor], ["IAFT/EAFT", iaft],
    ["POL", pol], ["Tools", tools], ["Troop Seat", troop],
    ["EFS Float", efs], ["EFS Cyl.", efsCyl],
  ];
  for (const [modName, items] of modules) {
    for (const it of items) {
      if (it.serviceability === "Unserviceable") {
        const pn = it.pnWheel || it.partNumber || "";
        s1rows.push([
          modName,
          trunc(it.designation || "", 28),
          trunc(pn, 18),
          it.serialNumber || "",
          trunc(it.reason || "Unserviceable", 28),
        ]);
      }
    }
  }

  // ── Slide 2: Life Raft U/S ────────────────────────────────────────────
  const s2rows = [];
  for (const it of liferafts) {
    if (it.serviceability === "Unserviceable") {
      s2rows.push([
        it.partNumber || "",
        it.serialNumber || "",
        trunc(it.reason || "Unserviceable", 36),
      ]);
    }
  }

  // ── Slide 3: EFS due within 90d ───────────────────────────────────────
  const s3rows = [];
  for (const it of efs) {
    if (it.serviceability === "Unserviceable") continue;
    let best = 999;
    for (const f of ["next18M", "next36M"]) {
      const d = daysLeft(it[f]);
      if (d !== null && d >= 0 && d <= 90 && d < best) best = d;
    }
    if (best < 999) {
      s3rows.push([
        it.hc || "",
        trunc(it.designation || "", 22),
        it.partNumber || "",
        it.serialNumber || "",
        it.next18M || "",
        it.next36M || "",
        `${best}d`,
      ]);
    }
  }
  s3rows.sort((a, b) => parseInt(a[6]) - parseInt(b[6]));

  // ── Slide 4: EFS Cylinders due within 90d ────────────────────────────
  const s4rows = [];
  for (const it of efsCyl) {
    if (it.serviceability === "Unserviceable") continue;
    let best = 999;
    for (const f of ["next18M", "next60M"]) {
      const d = daysLeft(it[f]);
      if (d !== null && d >= 0 && d <= 90 && d < best) best = d;
    }
    if (best < 999) {
      s4rows.push([
        it.hc || "",
        trunc(it.designation || "", 22),
        it.partNumber || "",
        it.serialNumber || "",
        it.next18M || "",
        it.next60M || "",
        `${best}d`,
      ]);
    }
  }
  s4rows.sort((a, b) => parseInt(a[6]) - parseInt(b[6]));

  console.log(`  Slide 1 — Other Parts U/S:       ${s1rows.length} items`);
  console.log(`  Slide 2 — Life Raft U/S:          ${s2rows.length} items`);
  console.log(`  Slide 3 — EFS due <90d:           ${s3rows.length} items`);
  console.log(`  Slide 4 — EFS Cylinders due <90d: ${s4rows.length} items`);

  // ── Build presentation ────────────────────────────────────────────────
  const prs = new pptxgen();
  prs.layout = "LAYOUT_WIDE";
  prs.title  = `Components Bay — ${today}`;
  prs.author = "ASM";

  // Column widths (must sum to TBL_W ≈ 10.47")
  // Slide 1: MODULE | DESIGNATION | P/N | S/N | REASON
  const cw1 = [1.4, 2.4, 2.1, 1.1, 3.47];

  // Slide 2: P/N | S/N | REASON  (no MODULE col — always Life Raft)
  const cw2 = [2.2, 3.4, 4.87];

  // Slides 3 & 4: H/C | DESIGNATION | P/N | S/N | NEXT18M | NEXT36M | DAYS
  const cw34 = [1.5, 2.2, 2.0, 0.85, 1.45, 1.45, 1.02];

  buildSlide(prs, {
    title: "Other Parts",
    subtitle: "NEED TO BE C/OUT",
    accentColor: C.accent1,
    headerLabel: "ALL UNSERVICEABLE ITEMS (ORDERED)",
    count: s1rows.length,
    headers: ["MODULE", "DESIGNATION", "P/N", "S/N", "REASON"],
    rows: s1rows,
    colW: cw1,
    daysColIdx: -1,
  });

  buildSlide(prs, {
    title: "Life Raft",
    subtitle: "NEED TO BE C/OUT",
    accentColor: C.accent1,
    headerLabel: "LIFE RAFT — NEED TO BE C/OUT",
    count: s2rows.length,
    headers: ["P/N", "S/N", "REASON"],
    rows: s2rows,
    colW: cw2,
    daysColIdx: -1,
  });

  buildSlide(prs, {
    title: "EFS",
    subtitle: "DUE WITHIN 90 DAYS",
    accentColor: C.accent2,
    headerLabel: "SERVICEABLE EFS — DUE WITHIN 90 DAYS",
    count: s3rows.length,
    headers: ["H/C", "DESIGNATION", "P/N", "S/N", "NEXT 18M", "NEXT 36M", "DAYS"],
    rows: s3rows,
    colW: cw34,
    daysColIdx: 6,
  });

  buildSlide(prs, {
    title: "EFS Cylinders",
    subtitle: "DUE WITHIN 90 DAYS",
    accentColor: C.accent2,
    headerLabel: "SERVICEABLE EFS CYLINDERS — DUE WITHIN 90 DAYS",
    count: s4rows.length,
    headers: ["H/C", "DESIGNATION", "P/N", "S/N", "NEXT 18M", "NEXT 60M", "DAYS"],
    rows: s4rows,
    colW: cw34,
    daysColIdx: 6,
  });

  await prs.writeFile({ fileName: OUTPUT });
  console.log(`\n✅ Generated: ${OUTPUT}`);
  console.log("=".repeat(55));
}

main().catch(e => { console.error("FATAL:", e); process.exit(1); });
