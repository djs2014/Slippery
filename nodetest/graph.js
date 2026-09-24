/**
 * Slippery graph generator — dependency-free SVG, no npm packages needed.
 *
 * Usage:
 *   node graph.js                        # live data, Amsterdam (52.18895, 4.549666)
 *   node graph.js --lat 47.08 --lon 12.84
 *   node graph.js --fixture ./moderaterisk --at 12   # local fixture, hour index 12 = "now"
 *   node graph.js --demo                 # canned demo values (cold snap + ICE), no network
 *   node graph.js --out risk.svg
 *
 * Output: SVG with the 13-hour risk profile (current hour + 12 forecast hours):
 * one column per hour (bars close together), rain (blue) + snow (pale) as a
 * stacked column, risk-color strip directly under each column, then the hour
 * label; overlaid traces: temp red solid, dewpoint grey solid, sun yellow
 * solid, wind white dotted, humidity cyan dashed; top W row with blow-to
 * arrow + speed per hour; ICE hours get a ❄ marker.
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

// Canned demo window (25 hourly points, "now" = index 12): warm start,
// evening cold snap with ICE hours, rain turning to snow, gusty wind,
// sunny midday — so every graph trace moves. No network needed.
function buildDemoData() {
  const nowSec = Math.floor(Date.now() / 1000);
  const t0 = nowSec - 12 * 3600;
  const time = [];
  for (let i = 0; i < 25; i++) time.push(t0 + i * 3600);
  const air = [9, 8.5, 7.5, 6.5, 5, 4, 3, 2, 1, 0.5, 0, -0.5, -1, -1.5, -2, -2.5, -2, -1, 0, 1, 2.5, 4, 5.5, 7, 8];
  const rain = [0, 0, 0.2, 0.8, 2.5, 5, 8, 4, 1.5, 0.4, 0.1, 0, 0, 0, 0, 0, 0, 0.2, 0.6, 0.3, 0, 0, 0, 0, 0];
  const snow = [0, 0, 0, 0, 0, 0, 0, 0.3, 0.8, 1.5, 2, 1.2, 0.6, 0.3, 0.1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
  const wind = [12, 14, 16, 20, 25, 30, 34, 38, 35, 30, 26, 22, 18, 16, 14, 12, 11, 12, 14, 16, 15, 13, 12, 11, 10];
  const gust = [18, 22, 26, 34, 42, 50, 58, 65, 55, 46, 38, 30, 24, 22, 20, 18, 16, 18, 22, 24, 22, 20, 18, 16, 14];
  const sun = [0, 0, 0, 0, 0, 0, 100, 600, 1500, 2400, 3200, 3600, 3400, 3000, 2200, 1200, 400, 0, 0, 0, 0, 0, 0, 0, 0];
  const showers = new Array(25).fill(0);
  return {
    hourly: {
      time: time, temperature_2m: air, apparent_temperature: air.map((a) => a - 1.5),
      surface_temperature: air.map((a) => a - 1.0), dewpoint_2m: air.map((a) => a - 0.6),
      relativehumidity_2m: air.map((a) => (a <= 1.0 ? 95 : 82)),
      rain: rain, showers: showers, snowfall: snow,
      precipitation_probability: rain.map((r, i) => (r > 0.2 || snow[i] > 0.1 ? 80 : 5)),
      wind_speed_10m: wind, wind_gusts_10m: gust,
      wind_direction_10m: air.map((_, i) => (250 + i * 7) % 360),
      sunshine_duration: sun,
    },
    minutely_15: { rain: [0.4, 0.2, 0, 0], snowfall: [0, 0.3, 0.8, 0.5] },
  };
}

async function main() {
  const a = args();
  const lat = parseFloat(a.lat || '52.18895');
  const lon = parseFloat(a.lon || '4.549666');
  const outFile = a.out || 'slippery-graph.svg';

  let data;
  let nowSec;
  if (a.demo) {
    data = buildDemoData();
    nowSec = Math.floor(Date.now() / 1000);
    // Align "now" with the middle of the demo window (index 12).
    const t = data.hourly.time[12];
    nowSec = typeof t === 'number' ? t : Math.floor(Date.parse(t) / 1000);
    console.log('Demo values (cold snap + ICE), no network.');
  } else if (a.fixture) {
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
  const snows = pickHourly(h, ['snowfall']);
  const gusts = pickHourly(h, ['wind_gusts_10m', 'windgusts_10m']);
  const winds = pickHourly(h, ['wind_speed_10m', 'windspeed_10m']);
  const wdirs = pickHourly(h, ['wind_direction_10m', 'winddirection_10m', 'wind_direction']);
  const temps = pickHourly(h, ['temperature_2m']);
  const dews = pickHourly(h, ['dewpoint_2m', 'dew_point_2m']);
  const hums = pickHourly(h, ['relativehumidity_2m', 'relative_humidity_2m']);
  const surfT = pickHourly(h, ['surface_temperature']);
  const suns = pickHourly(h, ['sunshine_duration']);
  const times = h.time || [];

  const ICE_NAMES = ['Black Ice / Freezing Wet Road', 'Road Surface Frost', 'Ice On Bridges'];
  const at = (arr, j) => (j < arr.length && arr[j] != null ? arr[j] : 0);
  const hours = [];
  for (let i = 0; i < N; i++) {
    const j = start + i;
    const airTemp = at(temps, j), sfc = at(surfT, j), dew = at(dews, j), hum = at(hums, j);
    const rainCur = at(rains, j) + at(showers, j), snowCur = at(snows, j);
    let rain12 = 0, snow12 = 0;
    for (let k = Math.max(0, j - 12); k <= j; k++) {
      rain12 += at(rains, k) + at(showers, k);
      snow12 += at(snows, k);
    }
    let dry = 0;
    for (let d = j - 1; d >= 0 && dry < 24; d--) {
      if (at(rains, d) + at(showers, d) <= 0.1 && at(snows, d) <= 0.1) dry++;
      else break;
    }
    let immR = rainCur >= 0.1 ? 0 : ((at(rains, j + 1) + at(showers, j + 1) >= 0.1) ? 60 : -1);
    let immS = snowCur >= 0.1 ? 0 : (at(snows, j + 1) >= 0.1 ? 60 : -1);
    let ice = false;
    try {
      const r = sc.evaluateRisk({
        airTemp, surfaceTemp: sfc, dewPoint: dew, humidity: hum,
        rainAndShowerCurrent: rainCur, runningRainAndShower12h: rain12,
        runningSnow12h: snow12, runningDryStreak: dry, season: parsed.season,
        windSpeed: at(winds, j), windGust: at(gusts, j),
        immediateRainAndShower: immR, immediateSnow: immS,
        surfaceDewSpread: sfc - dew, snowCurrent: snowCur,
      });
      ice = (r.hazards || []).some((hz) => ICE_NAMES.indexOf(hz) !== -1);
    } catch (e) { ice = false; }
    const t = times[j];
    const d = typeof t === 'number' ? new Date(t * 1000) : new Date(t);
    hours.push({
      time: d, name: parsed.hourlyRiskProfile[i],
      rain: rainCur, snow: snowCur,
      wind: at(winds, j), gust: at(gusts, j), wdir: at(wdirs, j),
      sun: at(suns, j), temp: airTemp, dew: dew, humidity: hum, ice: ice,
    });
  }

  // --- layout: columns close together, precip column, risk strip, hour ---
  // Traces: temp red solid, dewpoint grey solid, sun yellow solid,
  // wind white dotted, humidity cyan dashed. ICE hours get a ❄ marker.
  const W = 780;
  const H = 446;
  const padL = 46;
  const padR = 14;
  const padT = 88;
  const padB = 96;
  const plotW = W - padL - padR;
  const plotH = H - padT - padB;
  const base = padT + plotH;
  const n = N;
  const slot = plotW / n;
  const barW = Math.min(52, slot * 0.85);
  const stripH = 8, stripY = base + 4, hourY = stripY + stripH + 14;
  const barMaxH = plotH * 0.55;

  const maxRain = Math.max(2.0, ...hours.map((x) => x.rain));
  const maxSnow = Math.max(1.0, ...hours.map((x) => x.snow));
  const maxWind = Math.max(10, ...hours.map((x) => Math.max(x.wind, x.gust)));
  let tMin = Math.min(...hours.map((x) => Math.min(x.temp, x.dew)));
  let tMax = Math.max(...hours.map((x) => Math.max(x.temp, x.dew)));
  if (!isFinite(tMin) || !isFinite(tMax)) { tMin = 0; tMax = 10; }
  if (tMax - tMin < 5) { const m = (tMax + tMin) / 2; tMin = m - 2.5; tMax = m + 2.5; }
  else { tMin -= 1; tMax += 1; }
  const tempY = (t) => padT + (1 - (t - tMin) / (tMax - tMin)) * plotH;
  const humY = (x) => padT + (1 - Math.max(0, Math.min(100, x)) / 100) * plotH;
  const windY = (w) => padT + (1 - w / maxWind) * plotH;
  const sunY = (sec) => padT + (1 - Math.max(0, Math.min(3600, sec)) / 3600) * plotH;
  const cxOf = (i) => padL + slot * i + slot / 2;
  const linePath = (fn) => hours.map((_, i) => `${i === 0 ? 'M' : 'L'}${cxOf(i).toFixed(1)} ${fn(i).toFixed(1)}`).join('');

  let s = '';
  s += `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" font-family="sans-serif">\n`;
  s += `<rect width="${W}" height="${H}" fill="#111"/>\n`;
  s += `<text x="${padL}" y="24" fill="#fff" font-size="17" font-weight="bold">${esc(parsed.riskLevel)} — ${esc(parsed.hazards.join(' + ') || 'No hazards')}</text>\n`;
  s += `<text x="${padL}" y="44" fill="#bbb" font-size="12">${esc(parsed.timestamp)} · lat ${lat}, lon ${lon} · season ${esc(parsed.season)} · wind ${parsed.weatherSummary.windKmh} km/h, gust ${parsed.weatherSummary.gustKmh} km/h</text>\n`;
  s += `<text x="${padL - 5}" y="${tempY(tMax) + 4}" fill="#999" font-size="10" text-anchor="end">${tMax.toFixed(0)}°</text>\n`;
  s += `<text x="${padL - 5}" y="${tempY((tMin + tMax) / 2) + 4}" fill="#999" font-size="10" text-anchor="end">${((tMin + tMax) / 2).toFixed(0)}°</text>\n`;
  s += `<text x="${padL - 5}" y="${tempY(tMin) + 4}" fill="#999" font-size="10" text-anchor="end">${tMin.toFixed(0)}°</text>\n`;
  s += `<text x="${W - padR}" y="${padT + 10}" fill="#3377ff" font-size="10" text-anchor="end">${maxRain.toFixed(0)}mm</text>\n`;

  for (let i = 0; i < n; i++) {
    const cx = cxOf(i);
    const x = (cx - barW / 2).toFixed(1);
    const hh = hours[i];
    const rh = (hh.rain / maxRain) * barMaxH;
    const sh = (hh.snow / maxSnow) * barMaxH * 0.6;
    if (rh > 0.5) {
      s += `<rect x="${x}" y="${(base - rh).toFixed(1)}" width="${barW.toFixed(1)}" height="${rh.toFixed(1)}" fill="#3377ff"/>\n`;
    }
    if (sh > 0.5) {
      s += `<rect x="${x}" y="${(base - rh - sh).toFixed(1)}" width="${barW.toFixed(1)}" height="${sh.toFixed(1)}" fill="#b3e5fc"/>\n`;
    }
    s += `<rect x="${x}" y="${stripY}" width="${barW.toFixed(1)}" height="${stripH}" fill="${RISK_FILL[hh.name]}"${hh.ice ? ' stroke="#4dd0e1" stroke-width="1.5"' : ''}/>\n`;
    const lbl = i === 0 ? 'now' : `${String(hh.time.getHours()).padStart(2, '0')}:00`;
    s += `<text x="${cx.toFixed(1)}" y="${hourY}" fill="#999" font-size="10" text-anchor="middle">${esc(lbl)}</text>\n`;
    if (hh.rain >= 0.1 || hh.snow >= 0.1) {
      let pv = '';
      if (hh.rain >= 0.1) pv += hh.rain.toFixed(1);
      if (hh.snow >= 0.1) pv += (pv ? '+' : '') + hh.snow.toFixed(1) + 's';
      s += `<text x="${cx.toFixed(1)}" y="${(base - rh - sh - 5).toFixed(1)}" fill="#9ec1ff" font-size="9" text-anchor="middle">${pv}</text>\n`;
    }
    if (hh.ice) {
      s += `<text x="${cx.toFixed(1)}" y="${padT - 6}" fill="#4dd0e1" font-size="13" text-anchor="middle">❄</text>\n`;
    }
    // Top W row: blow-to arrow + speed per hour (same convention as
    // CurrentWindWidget.mc). Size mirrors the dart tiers (18/25/35 km/h).
    const wSize = (hh.wind >= 35 || hh.gust >= 45) ? 15 :
      ((hh.wind >= 25 || hh.gust >= 35) ? 13 : (hh.wind >= 18 ? 12 : 11));
    s += `<text x="${cx.toFixed(1)}" y="${padT - 28}" fill="#fff" font-size="${wSize}" text-anchor="middle">${esc(windArrow(hh.wdir) + Math.round(hh.wind))}</text>\n`;
  }
  s += `<path d="${linePath((i) => humY(hours[i].humidity))}" fill="none" stroke="#4dd0e1" stroke-width="1.5" stroke-dasharray="6,3"/>\n`;
  s += `<path d="${linePath((i) => windY(Math.max(hours[i].wind, hours[i].gust)))}" fill="none" stroke="#fff" stroke-width="1.5" stroke-dasharray="2,3"/>\n`;
  s += `<path d="${linePath((i) => sunY(hours[i].sun))}" fill="none" stroke="#ffd24a" stroke-width="2"/>\n`;
  s += `<path d="${linePath((i) => tempY(hours[i].dew))}" fill="none" stroke="#9e9e9e" stroke-width="2"/>\n`;
  s += `<path d="${linePath((i) => tempY(hours[i].temp))}" fill="none" stroke="#ff5252" stroke-width="2"/>\n`;

  // legend in its own rows below the hour numbers, so it never covers them
  const ly1 = hourY + 22;
  s += `<text x="${padL}" y="${ly1}" fill="#bbb" font-size="11">— temp (red) · — dewpoint (grey) · — sun (yellow) · ┄ wind (white) · ┄ humidity (cyan) · <tspan fill="#3377ff">blue = rain mm/h</tspan> · <tspan fill="#b3e5fc">pale = snow cm/h</tspan> · strip = risk · ❄ = ICE · W row = wind arrow + speed</text>\n`;
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
