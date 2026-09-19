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
 * same as RiskProjectionEngine), rain amount bars and wind gust markers.
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
  const times = h.time || [];

  const rainSlice = [];
  const gustSlice = [];
  const windSlice = [];
  const labelSlice = [];
  for (let i = 0; i < N; i++) {
    const j = start + i;
    rainSlice.push((rains[j] || 0) + (showers[j] || 0));
    gustSlice.push(gusts[j] || 0);
    windSlice.push(winds[j] || 0);
    const t = times[j];
    const d = typeof t === 'number' ? new Date(t * 1000) : new Date(t);
    labelSlice.push(`${String(d.getHours()).padStart(2, '0')}:00`);
  }

  // --- layout ---
  const W = 780;
  const H = 340;
  const padL = 46;
  const padR = 14;
  const padT = 64;
  const padB = 30;
  const plotW = W - padL - padR;
  const plotH = H - padT - padB;
  const n = N;
  const slot = plotW / n;
  const barW = Math.min(44, slot * 0.62);

  const maxRain = Math.max(2.0, ...rainSlice); // 2 mm/h floor, like SubSegmentedForecastBar
  const maxGust = Math.max(10, ...gustSlice, ...windSlice);

  const riskY = (name) => padT + plotH - ((RISK_LEVEL_NUM[name] / 5) * (plotH * 0.55));
  let s = '';
  s += `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" font-family="sans-serif">\n`;
  s += `<rect width="${W}" height="${H}" fill="#111"/>\n`;
  s += `<text x="${padL}" y="24" fill="#fff" font-size="17" font-weight="bold">${esc(parsed.riskLevel)} — ${esc(parsed.hazards.join(' + ') || 'No hazards')}</text>\n`;
  s += `<text x="${padL}" y="44" fill="#bbb" font-size="12">${esc(parsed.timestamp)} · lat ${lat}, lon ${lon} · season ${esc(parsed.season)} · wind ${parsed.weatherSummary.windKmh} km/h, gust ${parsed.weatherSummary.gustKmh} km/h</text>\n`;

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
    // rain bar (blue, from bottom)
    const rh = (rainSlice[i] / maxRain) * (plotH * 0.45);
    if (rh > 0.5) {
      s += `<rect x="${(cx - barW / 2).toFixed(1)}" y="${(padT + plotH - rh).toFixed(1)}" width="${barW.toFixed(1)}" height="${rh.toFixed(1)}" fill="#3377ff"/>\n`;
    }
    // risk bar (from risk baseline zone): block whose height encodes level
    const lvl = RISK_LEVEL_NUM[name];
    const bh = (lvl / 5) * (plotH * 0.55);
    const by = padT + plotH - (plotH * 0.45) - bh;
    s += `<rect x="${(cx - barW / 2).toFixed(1)}" y="${by.toFixed(1)}" width="${barW.toFixed(1)}" height="${Math.max(3, bh).toFixed(1)}" fill="${RISK_FILL[name]}" fill-opacity="${i === 0 ? 1 : 0.75}"/>\n`;
    // gust dot (white) + sustained tick
    const gy = padT + plotH - (plotH * 0.45) - (gustSlice[i] / maxGust) * (plotH * 0.55);
    const wy = padT + plotH - (plotH * 0.45) - (windSlice[i] / maxGust) * (plotH * 0.55);
    s += `<line x1="${(cx - 8).toFixed(1)}" y1="${wy.toFixed(1)}" x2="${(cx + 8).toFixed(1)}" y2="${wy.toFixed(1)}" stroke="#fff" stroke-width="2"/>\n`;
    s += `<circle cx="${cx.toFixed(1)}" cy="${gy.toFixed(1)}" r="3.2" fill="#fff"/>\n`;
    // hour label + rain value
    s += `<text x="${cx.toFixed(1)}" y="${padT + plotH + 14}" fill="#999" font-size="10" text-anchor="middle">${i === 0 ? 'now' : esc(labelSlice[i])}</text>\n`;
    if (rainSlice[i] >= 0.1) {
      s += `<text x="${cx.toFixed(1)}" y="${(padT + plotH - rh - 4).toFixed(1)}" fill="#9ec1ff" font-size="9" text-anchor="middle">${rainSlice[i].toFixed(1)}</text>\n`;
    }
  }

  // legend
  const ly = H - 12;
  s += `<text x="${padL}" y="${ly}" fill="#bbb" font-size="11">Risk bar color = level · <tspan fill="#3377ff">blue = rain mm/h</tspan> · <tspan fill="#fff">— sustained wind, ● gust</tspan> · advice: ${esc(parsed.advice.join('; ') || '—')}</text>\n`;
  s += '</svg>\n';

  fs.writeFileSync(outFile, s);
  console.log(`Wrote ${outFile} (${N} hours, current risk ${parsed.riskLevel}). Open it in a browser.`);
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
