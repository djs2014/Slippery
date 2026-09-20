/**
 * Slippery graph generator — dependency-free SVG, no npm packages needed.
 *
 * Usage:
 *   node graph.js                        # live data, Amsterdam (52.18895, 4.549666)
 *   node graph.js --lat 47.08 --lon 12.84
 *   node graph.js --fixture ./moderaterisk --at 12   # local fixture, hour index 12 = "now"
 *   node graph.js --out risk.svg
 *
 * Output: an SVG with the 13-hour risk profile (current hour + 12 forecast hours,
 * same as RiskProjectionEngine), rain amount bars, wind gust markers and a top
 * wind row (blow-to arrow + sustained speed, no units).
 * Open the .svg in any browser. Convert to PNG with e.g.:
 *   cairosvg risk.svg -o risk.png   (pip install cairosvg)
 *   or: rsvg-convert risk.svg -o risk.png
 */
const fs = require('fs');
const sc = require('./slipperycheck.js');

const RISK_FILL = {
  NO_DATA: '#9e9e9e',
  SAFE: '#4caf50',
  SLIGHT: '#ffeb3b',
  MODERATE: '#ffa500',
  HIGH: '#ff4500',
  CRITICAL: '#ff0000',
};
const RISK_LEVEL_NUM = { NO_DATA: 0, SAFE: 1, SLIGHT: 2, MODERATE: 3, HIGH: 4, CRITICAL: 5 };

function args() {
  const out = {};
  const argv = process.argv.slice(2);
  for (let i = 0; i < argv.length; i++) {
    const m = argv[i].match(/^--([^=]+)(=(.*))?$/);
    if (!m) continue;
    if (m[3] !== undefined) {
      out[m[1]] = m[3];
    } else if (i + 1 < argv.length && !argv[i + 1].startsWith('--')) {
      out[m[1]] = argv[++i];
    } else {
      out[m[1]] = true;
    }
  }
  return out;
}

function loadFixture(path) {
  let raw = fs.readFileSync(path, 'utf8');
  raw = raw.slice(raw.indexOf('{'));
  const cut = raw.indexOf('RiskAssessment{');
  if (cut !== -1) raw = raw.slice(0, cut);
  // strip HTTP headers if present (lines before first '{' already removed)
  return JSON.parse(raw.trim());
}

function pickHourly(hourly, keys, fill = 0) {
  for (const k of keys) if (Array.isArray(hourly[k])) return hourly[k];
  const n = (hourly.time || []).length;
  return new Array(n).fill(fill);
}

function esc(s) {
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

// Blow-to arrow for a meteorological wind direction (same convention as the
// Cinnamon applet): N (0°) blows toward the south, shown as ↓.
function windArrow(deg) {
  if (deg === null || deg === undefined) return '';
  const d = parseFloat(deg);
  if (isNaN(d)) return '';
  const norm = ((d % 360) + 360) % 360;
  return ['↓', '↙', '←', '↖', '↑', '↗', '→', '↘'][Math.round(norm / 45) % 8];
}

// Greedy wrap of advice items ("a; b; c") into lines of at most max chars.
function wrapAdvice(items, max) {
  const lines = [];
  let cur = '';
  for (const it of items) {
    const add = cur ? '; ' + it : it;
    if (cur && (cur + add).length > max) {
      lines.push(cur);
      cur = it;
    } else {
      cur = cur + add;
    }
  }
  if (cur) lines.push(cur);
  if (lines.length > 2) return [lines[0], lines[1] + ' …'];
  return lines;
}

async function main() {
  const a = args();
  const lat = parseFloat(a.lat || '52.18895');
  const lon = parseFloat(a.lon || '4.549666');
  const outFile = a.out || 'slippery-graph.svg';

  let data;
  let nowSec;
  if (a.fixture) {
    data = loadFixture(a.fixture);
    const idx = parseInt(a.at || '12', 10);
    const t = data.hourly.time[idx];
    nowSec = typeof t === 'number' ? t : Math.floor(Date.parse(t) / 1000);
    console.log(`Fixture ${a.fixture}, using hour index ${idx} as now.`);
  } else {
    const url = sc.buildApiUrl(lat, lon, 12, 12);
    console.log('Fetching', url);
    const res = await fetch(url);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    data = await res.json();
    nowSec = Math.floor(Date.now() / 1000);
  }

  const parsed = sc.parseOpenMeteoResponse(lat, data, nowSec);
  if (!parsed) throw new Error('Could not parse response');
  const h = data.hourly;
  const start = parsed.targetIndex;
  const N = parsed.hourlyRiskProfile.length;

  const rains = pickHourly(h, ['rain']);
  const showers = pickHourly(h, ['showers']);
  const gusts = pickHourly(h, ['wind_gusts_10m', 'windgusts_10m']);
  const winds = pickHourly(h, ['wind_speed_10m', 'windspeed_10m']);
  const hasDir = Array.isArray(h['wind_direction_10m']);
  const windDirs = pickHourly(h, ['wind_direction_10m'], null);
  const suns = pickHourly(h, ['sunshine_duration']);
  const times = h.time || [];

  const rainSlice = [];
  const gustSlice = [];
  const windSlice = [];
  const wdirSlice = [];
  const sunSlice = [];
  const labelSlice = [];
  for (let i = 0; i < N; i++) {
    const j = start + i;
    rainSlice.push((rains[j] || 0) + (showers[j] || 0));
    gustSlice.push(gusts[j] || 0);
    windSlice.push(winds[j] || 0);
    wdirSlice.push(windDirs ? windDirs[j] : null);
    sunSlice.push(suns[j] || 0);
    const t = times[j];
    const d = typeof t === 'number' ? new Date(t * 1000) : new Date(t);
    labelSlice.push(`${String(d.getHours()).padStart(2, '0')}:00`);
  }

  // --- layout (wind row on top, legend in its own rows below the hours) ---
  // Only a slim bottom strip stays reserved for the blue rain bars; the risk
  // columns and the wind/gust markers span the rest and are anchored to the
  // bottom of that strip, so the bars no longer float in empty space with
  // stray risk-level lines dangling underneath.
  const W = 780;
  const H = 404;
  const padL = 46;
  const padR = 14;
  const padT = 90;
  const padB = 70;
  const plotW = W - padL - padR;
  const plotH = H - padT - padB;
  const rainH = Math.round(plotH * 0.18);
  const riskH = plotH - rainH;
  const base = padT + plotH - rainH;
  const n = N;
  const slot = plotW / n;
  const barW = Math.min(44, slot * 0.62);

  const maxRain = Math.max(2.0, ...rainSlice); // 2 mm/h floor, like SubSegmentedForecastBar
  const maxGust = Math.max(10, ...gustSlice, ...windSlice);

  const riskY = (name) => base - ((RISK_LEVEL_NUM[name] / 5) * riskH);
  let s = '';
  s += `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" font-family="sans-serif">\n`;
  s += `<rect width="${W}" height="${H}" fill="#111"/>\n`;
  s += `<text x="${padL}" y="24" fill="#fff" font-size="17" font-weight="bold">${esc(parsed.riskLevel)} — ${esc(parsed.hazards.join(' + ') || 'No hazards')}</text>\n`;
  s += `<text x="${padL}" y="44" fill="#bbb" font-size="12">${esc(parsed.timestamp)} · lat ${lat}, lon ${lon} · season ${esc(parsed.season)} · wind ${parsed.weatherSummary.windKmh} km/h, gust ${parsed.weatherSummary.gustKmh} km/h</text>\n`;

  // wind row (like layout.png "W"): blow-to arrow + sustained speed, no units
  const windRowY = padT - 14;
  s += `<text x="${padL - 5}" y="${windRowY + 4}" fill="#999" font-size="10" text-anchor="end">W</text>\n`;
  for (let i = 0; i < n; i++) {
    const cx = padL + slot * i + slot / 2;
    const arr = hasDir ? windArrow(wdirSlice[i]) : '';
    s += `<text x="${cx.toFixed(1)}" y="${windRowY}" fill="#ccc" font-size="10" text-anchor="middle">${arr}${Math.round(windSlice[i])}</text>\n`;
  }
  // sun row (±): sunshine minutes per hour, hidden when 0 (e.g. at night)
  const sunRowY = padT - 30;
  s += `<text x="${padL - 5}" y="${sunRowY + 4}" fill="#999" font-size="10" text-anchor="end">☀</text>\n`;
  for (let i = 0; i < n; i++) {
    const cx = padL + slot * i + slot / 2;
    const sunMin = Math.round(sunSlice[i] / 60);
    if (sunMin > 0) {
      s += `<text x="${cx.toFixed(1)}" y="${sunRowY}" fill="#ffd24a" font-size="10" text-anchor="middle">${sunMin}m</text>\n`;
    }
  }
  s += `<line x1="${padL}" y1="${padT - 4}" x2="${W - padR}" y2="${padT - 4}" stroke="#222"/>\n`;

  // gridlines + y labels (left: risk, right: mm/h)
  for (const [name, lvl] of Object.entries(RISK_LEVEL_NUM)) {
    if (name === 'NO_DATA') continue;
    const y = riskY(name);
    s += `<line x1="${padL}" y1="${y}" x2="${W - padR}" y2="${y}" stroke="#333"/>\n`;
    s += `<text x="${padL - 5}" y="${y + 4}" fill="${RISK_FILL[name]}" font-size="10" text-anchor="end">${name}</text>\n`;
  }

  for (let i = 0; i < n; i++) {
    const cx = padL + slot * i + slot / 2;
    const name = parsed.hourlyRiskProfile[i];
    // rain bar (blue, slim bottom strip)
    const rh = (rainSlice[i] / maxRain) * rainH;
    if (rh > 0.5) {
      s += `<rect x="${(cx - barW / 2).toFixed(1)}" y="${(padT + plotH - rh).toFixed(1)}" width="${barW.toFixed(1)}" height="${rh.toFixed(1)}" fill="#3377ff"/>\n`;
    }
    // risk bar (anchored to the bottom of the risk band): block whose height
    // encodes level, spanning the full band so there is no empty mid-plot gap
    const lvl = RISK_LEVEL_NUM[name];
    const bh = (lvl / 5) * riskH;
    const by = base - bh;
    s += `<rect x="${(cx - barW / 2).toFixed(1)}" y="${by.toFixed(1)}" width="${barW.toFixed(1)}" height="${Math.max(3, bh).toFixed(1)}" fill="${RISK_FILL[name]}" fill-opacity="${i === 0 ? 1 : 0.75}"/>\n`;
    // gust dot (white) + sustained tick (scaled over the same risk band)
    const gy = base - (gustSlice[i] / maxGust) * riskH;
    const wy = base - (windSlice[i] / maxGust) * riskH;
    s += `<line x1="${(cx - 8).toFixed(1)}" y1="${wy.toFixed(1)}" x2="${(cx + 8).toFixed(1)}" y2="${wy.toFixed(1)}" stroke="#fff" stroke-width="2"/>\n`;
    s += `<circle cx="${cx.toFixed(1)}" cy="${gy.toFixed(1)}" r="3.2" fill="#fff"/>\n`;
    // hour label + rain value
    s += `<text x="${cx.toFixed(1)}" y="${padT + plotH + 14}" fill="#999" font-size="10" text-anchor="middle">${i === 0 ? 'now' : esc(labelSlice[i])}</text>\n`;
    if (rainSlice[i] >= 0.1) {
      s += `<text x="${cx.toFixed(1)}" y="${(padT + plotH - rh - 4).toFixed(1)}" fill="#9ec1ff" font-size="9" text-anchor="middle">${rainSlice[i].toFixed(1)}</text>\n`;
    }
  }

  // legend in its own rows below the hour numbers, so it never covers them
  const ly1 = padT + plotH + 30;
  s += `<text x="${padL}" y="${ly1}" fill="#bbb" font-size="11">Risk color = level · <tspan fill="#3377ff">blue = rain mm/h</tspan> · <tspan fill="#fff">— sustained, ● gust</tspan> · <tspan fill="#ffd24a">☀ sun min/h</tspan> · W = blow-to arrow + speed</text>\n`;
  const advItems = (parsed.advice && parsed.advice.length) ? parsed.advice : ['—'];
  wrapAdvice(advItems, 100).forEach((ln, k) => {
    s += `<text x="${padL}" y="${ly1 + 15 + k * 13}" fill="#888" font-size="10">${k === 0 ? 'advice: ' : ''}${esc(ln)}</text>\n`;
  });
  s += '</svg>\n';

  fs.writeFileSync(outFile, s);
  console.log(`Wrote ${outFile} (${N} hours, current risk ${parsed.riskLevel}). Open it in a browser.`);
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
