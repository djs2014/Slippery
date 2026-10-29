/**
 * Slippery graph generator — dependency-free SVG, no npm packages needed.
 *
 * Usage:
 *   node graph.js                        # live data, Amsterdam (52.18895, 4.549666)
 *   node graph.js --lat 47.08 --lon 12.84
 *   node graph.js --fixture ./moderaterisk --at 12   # local fixture, hour index 12 = "now"
 *   node graph.js --demo                 # canned demo values (cold snap + ICE), no network
 *   node graph.js --out risk.svg
 *   node graph.js --demo --no-daynight   # single background (see --day-bg)
 *   node graph.js --demo --day-bg '#1e2733' --night-bg '#111111'
 *   node graph.js --demo --reset-colors    # ignore custom --day-bg/--night-bg, use defaults
 *   node graph.js --demo --imperial        # °F, mph, inches (engine stays metric)
 *   node graph.js --demo --no-temp --no-sfc --no-dew --no-sun --no-wind --no-hum --no-prob --no-precip
 *   node graph.js --demo --values=peak-day  # max+min per metric, per calendar day
 *   node graph.js --demo --values=alternate  # wind + rain/snow numbers every other hour
  *   node graph.js --demo --day-labels=weekday   # date|weekday|both day row, centered over each day
 *
 * Output: SVG with the 13-hour risk profile (current hour + 12 forecast hours):
 * one column per hour (bars close together), rain (blue) + snow (pale) as a
 * stacked column, risk-color strip directly under each column, then the hour
 * label; wind markers (blow-to arrow + speed) ride just above the white
 * dotted wind+gust-max curve so their height shows the strength;
 * overlaid traces: temp red solid, surface temp orange solid, dewpoint grey
 * solid, sun yellow solid, wind+gust max white dotted, humidity cyan dashed,
 * precipitation probability blue dotted (0-100% shares the humidity scale,
 * labels right);
 * wind markers (blow-to arrow + speed) ride just above the dotted line; ICE hours get a ❄ marker,
 * plus the first ICE hour gets a cyan start line + top banner (ice in Xh @ HH:00 / ICE now).
 * Every trace/columns can be hidden (--no-*) and per-hour numbers set to
 * all, peak+low, per-day peak+low, every-other-hour or none (--values);
 * peak modes label the max + min of every trace metric on its curve
 * (global for peak, per calendar day for peak-day; rain/snow keep only
 * the wettest hour, sun skips zero hours). The legend lists only what is
 * drawn.
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

// Day-row label, centered over the visible hours of its calendar day
// (mirrors applet.js dayRowLabel): date = "D/M", weekday = full weekday
// name, both = both.
const WD_FULL = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
function dayRowLabel(d, mode) {
  const m = String(mode || 'date');
  const date = `${d.getDate()}/${d.getMonth() + 1}`;
  if (m === 'weekday') return WD_FULL[d.getDay()];
  if (m === 'both') return `${WD_FULL[d.getDay()]} ${date}`;
  return date;
}

// Day/night test for one graph hour (mirrors applet.js graphIsDay):
// sunshine (>0s) always means day, otherwise 07:00-19:00 local = day.
function isDayHour(hh) {
  if (!hh) return true;
  const sun = Number(hh.sun);
  if (!isNaN(sun) && sun > 0) return true;
  const t = hh.time;
  if (t instanceof Date && !isNaN(t)) {
    const h = t.getHours();
    return h >= 7 && h < 19;
  }
  return true;
}

// Display units (mirrors applet.js — engine data stays metric, only labels
// convert). Imperial: °F, mph, inches.
function isImperial(u) { return String(u || 'metric') === 'imperial'; }
function speedUnit(u) { return isImperial(u) ? 'mph' : 'km/h'; }
function fmtSpeedNum(v, u) {
  const x = parseFloat(v);
  if (isNaN(x)) return '?';
  return String(Math.round(isImperial(u) ? x * 0.621371 : x));
}
function rainRateUnit(u) { return isImperial(u) ? 'in/h' : 'mm/h'; }
function snowRateUnit(u) { return isImperial(u) ? 'in/h' : 'cm/h'; }
function tempScaleUnit(u) { return isImperial(u) ? '°F' : '°C'; }
function tempAxisUnit(u) { return isImperial(u) ? '°F' : '°'; }
function fmtTemp1(v, u) {
  const x = parseFloat(v);
  if (isNaN(x)) return '?';
  return isImperial(u) ? (x * 9 / 5 + 32).toFixed(1) + '°F' : x.toFixed(1) + '°';
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
  // Day/night background (mirrors the Cinnamon "Graph image" settings page).
  // --reset-colors forces the defaults, mirroring the applet's one-shot
  // "Reset graph day/night colors" switch.
  const dayNightOff = a['no-daynight'] === true || a.daynight === false ||
    a.daynight === 'false' || a.daynight === '0';
  const resetColors = a['reset-colors'] === true || a['reset-colors'] === 'true' || a['reset-colors'] === '1';
  const dayBg = (resetColors || typeof a['day-bg'] !== 'string' || !a['day-bg']) ? '#1e2733' : a['day-bg'];
  const nightBg = (resetColors || typeof a['night-bg'] !== 'string' || !a['night-bg']) ? '#111111' : a['night-bg'];
  if (resetColors) console.log('Resetting graph day/night colors to defaults.');
  const dnEnabled = !dayNightOff;
  const units = (a.imperial === true || a.imperial === 'true' || a.imperial === '1') ? 'imperial' : 'metric';
  if (units === 'imperial') console.log('Imperial units (°F, mph, in).');
  // Trace visibility (mirror the applet's Graph image page — all shown
  // unless passed as --no-temp/--no-sfc/--no-dew/--no-sun/--no-wind/
  // --no-hum/--no-prob/--no-precip) and value labels (--values=all|peak|none).
  const noFlag = (name) => a[name] === true || a[name] === 'true' || a[name] === '1';
  const showTemp = !noFlag('no-temp'), showSfc = !noFlag('no-sfc'),
    showDew = !noFlag('no-dew'), showSun = !noFlag('no-sun'),
    showWind = !noFlag('no-wind'), showHum = !noFlag('no-hum'),
    showProb = !noFlag('no-prob'), showPrecip = !noFlag('no-precip');
  const valuesMode = ['all', 'peak', 'peak-day', 'alternate', 'none'].includes(a.values) ? a.values : 'all';
  // Day-row labels under each midnight (mirrors the applet's
  // graph-day-labels setting): date, weekday or both.
  const dayLabelsMode = ['date', 'weekday', 'both'].includes(a['day-labels']) ? a['day-labels'] : 'date';
  if (dayLabelsMode !== 'date') console.log(`Day labels: ${dayLabelsMode}.`);

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
  const probs = pickHourly(h, ['precipitation_probability']);
  const times = h.time || [];

  const ICE_NAMES = ['Black Ice / Freezing Wet Road', 'Road Surface Frost', 'Ice On Bridges', 'Snow Or Slush Accumulation'];
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
        upcomingRainAndShower: at(rains, j + 1) + at(showers, j + 1),
        iceT: 3.0,
      });
      ice = (r.hazards || []).some((hz) => ICE_NAMES.indexOf(hz) !== -1);
    } catch (e) { ice = false; }
    const t = times[j];
    const d = typeof t === 'number' ? new Date(t * 1000) : new Date(t);
    hours.push({
      time: d, name: parsed.hourlyRiskProfile[i],
      rain: rainCur, snow: snowCur,
      wind: at(winds, j), gust: at(gusts, j), wdir: at(wdirs, j),
      sun: at(suns, j), temp: airTemp, sfc: sfc, dew: dew, humidity: hum,
      prob: (j < probs.length && probs[j] != null) ? probs[j] : null,
      ice: ice,
    });
  }

  // --- layout: columns close together, precip column, risk strip, hour ---
  // (each hour label has a thin connector line up to its risk strip).
  // Wind markers ride just above the white dotted wind+gust-max curve so
  // their height shows the strength (strong hours high, calm hours low).
  // Traces: temp red solid, surface temp orange solid, dewpoint grey solid,
  // sun yellow solid, wind+gust max white dotted, humidity cyan dashed,
  // precip probability blue dotted (shares the 0-100% humidity scale).
  // ICE hours get a ❄ marker.
  const H = 446;
  const padL = 46;
  const padR = 14;
  const padT = 88;
  const padB = 96;
  // Wider columns (mirrors the Cinnamon applet): grow the canvas once slots
  // would get narrower than MIN_SLOT so long windows keep breathing room.
  const n = N;
  const MIN_SLOT = 8;
  const W = Math.max(900, padL + padR + n * MIN_SLOT);
  const plotW = W - padL - padR;
  const plotH = H - padT - padB;
  const base = padT + plotH;
  const slot = plotW / n;
  const barW = Math.min(52, slot * 0.85);
  const stripH = 8, stripY = base + 4, hourY = stripY + stripH + 14, dayY = hourY + 12;
  const barMaxH = plotH * 0.55;

  const maxRain = Math.max(2.0, ...hours.map((x) => x.rain));
  const maxSnow = Math.max(1.0, ...hours.map((x) => x.snow));
  const maxWind = Math.max(10, ...hours.map((x) => Math.max(x.wind, x.gust)));
  let tMin = Math.min(...hours.map((x) => Math.min(x.temp, x.sfc, x.dew)));
  let tMax = Math.max(...hours.map((x) => Math.max(x.temp, x.sfc, x.dew)));
  if (!isFinite(tMin) || !isFinite(tMax)) { tMin = 0; tMax = 10; }
  if (tMax - tMin < 5) { const m = (tMax + tMin) / 2; tMin = m - 2.5; tMax = m + 2.5; }
  else { tMin -= 1; tMax += 1; }
  const tempY = (t) => padT + (1 - (t - tMin) / (tMax - tMin)) * plotH;
  const humY = (x) => padT + (1 - Math.max(0, Math.min(100, x)) / 100) * plotH;
  // Precipitation probability shares the 0-100% humidity scale.
  const probY = (p) => padT + (1 - Math.max(0, Math.min(100, p || 0)) / 100) * plotH;
  const windY = (w) => padT + (1 - w / maxWind) * plotH;
  // Anchor for the wind markers: 16px above the dotted wind+gust-max curve.
  const windMarkY = (i) => Math.max(16, windY(Math.max(hours[i].wind || 0, hours[i].gust || 0)) - 16);
  const sunY = (sec) => padT + (1 - Math.max(0, Math.min(3600, sec)) / 3600) * plotH;
  const cxOf = (i) => padL + slot * i + slot / 2;
  const linePath = (fn) => hours.map((_, i) => `${i === 0 ? 'M' : 'L'}${cxOf(i).toFixed(1)} ${fn(i).toFixed(1)}`).join('');
  // First ICE hour in this window (hours[0] = now). -1 when no ice.
  // Marks where ice starts ("ice in Xh @ HH:00" / "ICE now").
  let iceStartIdx = -1;
  for (let fi = 0; fi < n; fi++) {
    if (hours[fi] && hours[fi].ice) { iceStartIdx = fi; break; }
  }
  const iceStartLabel = () => {
    if (iceStartIdx < 0) return '';
    if (iceStartIdx === 0) return '❄ ICE now ▼';
    const t = hours[iceStartIdx].time;
    const when = (t instanceof Date && !isNaN(t))
      ? ' @ ' + String(t.getHours()).padStart(2, '0') + ':00' : '';
    return `❄ ice in ${iceStartIdx}h${when} ▼`;
  };

  let s = '';
  s += `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" font-family="sans-serif">\n`;
  s += `<rect width="${W}" height="${H}" fill="${esc(dayBg)}"/>\n`;
  if (dnEnabled) {
    for (let bi = 0; bi < n; bi++) {
      if (!isDayHour(hours[bi])) {
        const bx = (padL + slot * bi).toFixed(1);
        s += `<rect x="${bx}" y="${padT}" width="${slot.toFixed(1)}" height="${plotH}" fill="${esc(nightBg)}"/>\n`;
      }
    }
  }
  s += `<text x="${padL}" y="24" fill="#fff" font-size="17" font-weight="bold">${esc(parsed.riskLevel)} — ${esc(parsed.hazards.join(' + ') || 'No hazards')}</text>\n`;
  s += `<text x="${padL}" y="44" fill="#bbb" font-size="12">${esc(parsed.timestamp)} · lat ${lat}, lon ${lon} · season ${esc(parsed.season)} · wind ${fmtSpeedNum(parsed.weatherSummary.windKmh, units)} ${speedUnit(units)}, gust ${fmtSpeedNum(parsed.weatherSummary.gustKmh, units)} ${speedUnit(units)}</text>\n`;
  const axTemp = (v) => `${(isImperial(units) ? v * 9 / 5 + 32 : v).toFixed(0)}${tempAxisUnit(units)}`;
  s += `<text x="${padL - 5}" y="${tempY(tMax) + 4}" fill="#999" font-size="10" text-anchor="end">${axTemp(tMax)}</text>\n`;
  s += `<text x="${padL - 5}" y="${tempY((tMin + tMax) / 2) + 4}" fill="#999" font-size="10" text-anchor="end">${axTemp((tMin + tMax) / 2)}</text>\n`;
  s += `<text x="${padL - 5}" y="${tempY(tMin) + 4}" fill="#999" font-size="10" text-anchor="end">${axTemp(tMin)}</text>\n`;
  s += `<text x="${W - padR}" y="${padT + 10}" fill="#3377ff" font-size="10" text-anchor="end">${isImperial(units) ? (maxRain / 25.4).toFixed(2) + 'in' : maxRain.toFixed(0) + 'mm'}</text>\n`;
  // Right-side % axis for humidity + precipitation probability (shared
  // 0-100% scale, full plot height). The top 100% tick is skipped so it
  // never collides with the rain max label above.
  const hasHumTrace = hours.some((hh) => hh.humidity !== null && hh.humidity !== undefined);
  const hasProbTrace = hours.some((hh) => hh.prob !== null && hh.prob !== undefined && !isNaN(hh.prob));
  const PROB_COLOR = '#5b9bff';
  // Trace visibility + value labels (mirror the applet's Graph image page).
  const SFC_COLOR = '#ffa040';
  const drawTemp = showTemp && hours.some((hh) => hh.temp !== null && hh.temp !== undefined);
  const drawSfc = showSfc && hours.some((hh) => hh.sfc !== null && hh.sfc !== undefined);
  const drawDew = showDew && hours.some((hh) => hh.dew !== null && hh.dew !== undefined);
  const drawSun = showSun && hours.some((hh) => (hh.sun || 0) > 0);
  const drawWind = showWind;
  const drawHum = showHum && hasHumTrace;
  const drawProb = showProb && hasProbTrace;
  const drawPrecip = showPrecip;
  const showVals = valuesMode !== 'none';
  const peakVals = valuesMode === 'peak' || valuesMode === 'peak-day';
  const dailyPeakVals = valuesMode === 'peak-day';
  const alternateVals = valuesMode === 'alternate';
  const numOrNull = (v) => (v === null || v === undefined || isNaN(v)) ? null : v;
  const dayKeyOf = (idx) => {
    const t = hours[idx] && hours[idx].time;
    if (t instanceof Date && !isNaN(t)) {
      return `${t.getFullYear()}-${t.getMonth()}-${t.getDate()}`;
    }
    return 'all';
  };
  let peakWindIdx = -1, peakRainIdx = -1, peakSnowIdx = -1;
  let minTempIdx = -1, minSfcIdx = -1;
  let peakWindSet = {}, minWindSet = {}, peakRainSet = {}, peakSnowSet = {};
  let maxTempSet = {}, minTempSet = {}, maxSfcSet = {}, minSfcSet = {};
  let maxDewSet = {}, minDewSet = {}, maxSunSet = {}, minSunSet = {};
  let maxHumSet = {}, minHumSet = {}, maxProbSet = {}, minProbSet = {};
  if (peakVals && !dailyPeakVals) {
    let wMax = -1, wMaxIdx = -1, wMin = null, wMinIdx = -1;
    let pr = -1, prIdx = -1, ps = -1, psIdx = -1;
    let tMax = null, tMaxIdx = -1, tMin = null, tMinIdx = -1;
    let fMax = null, fMaxIdx = -1, fMin = null, fMinIdx = -1;
    let dMax = null, dMaxIdx = -1, dMin = null, dMinIdx = -1;
    let sunMax = -1, sunMaxIdx = -1, sunMin = null, sunMinIdx = -1;
    let hMax = null, hMaxIdx = -1, hMin = null, hMinIdx = -1;
    let pMax = null, pMaxIdx = -1, pMin = null, pMinIdx = -1;
    for (let pi = 0; pi < n; pi++) {
      const g = Math.max(hours[pi].wind || 0, hours[pi].gust || 0);
      if (g > wMax) { wMax = g; wMaxIdx = pi; }
      if (wMin === null || g < wMin) { wMin = g; wMinIdx = pi; }
      if ((hours[pi].rain || 0) > pr) { pr = hours[pi].rain || 0; prIdx = pi; }
      if ((hours[pi].snow || 0) > ps) { ps = hours[pi].snow || 0; psIdx = pi; }
      const t = numOrNull(hours[pi].temp);
      if (t !== null && (tMax === null || t > tMax)) { tMax = t; tMaxIdx = pi; }
      if (t !== null && (tMin === null || t < tMin)) { tMin = t; tMinIdx = pi; }
      const f = numOrNull(hours[pi].sfc);
      if (f !== null && (fMax === null || f > fMax)) { fMax = f; fMaxIdx = pi; }
      if (f !== null && (fMin === null || f < fMin)) { fMin = f; fMinIdx = pi; }
      const dw = numOrNull(hours[pi].dew);
      if (dw !== null && (dMax === null || dw > dMax)) { dMax = dw; dMaxIdx = pi; }
      if (dw !== null && (dMin === null || dw < dMin)) { dMin = dw; dMinIdx = pi; }
      const sv = hours[pi].sun || 0;
      if (sv > sunMax) { sunMax = sv; sunMaxIdx = pi; }
      if (sv > 0 && (sunMin === null || sv < sunMin)) { sunMin = sv; sunMinIdx = pi; }
      const hv = numOrNull(hours[pi].humidity);
      if (hv !== null && (hMax === null || hv > hMax)) { hMax = hv; hMaxIdx = pi; }
      if (hv !== null && (hMin === null || hv < hMin)) { hMin = hv; hMinIdx = pi; }
      const pv = numOrNull(hours[pi].prob);
      if (pv !== null && (pMax === null || pv > pMax)) { pMax = pv; pMaxIdx = pi; }
      if (pv !== null && (pMin === null || pv < pMin)) { pMin = pv; pMinIdx = pi; }
    }
    if (wMaxIdx >= 0 && wMax > 0) { peakWindSet[wMaxIdx] = true; peakWindIdx = wMaxIdx; }
    if (wMinIdx >= 0) minWindSet[wMinIdx] = true;
    if (prIdx >= 0 && pr >= 0.1) { peakRainSet[prIdx] = true; peakRainIdx = prIdx; }
    if (psIdx >= 0 && ps >= 0.1) { peakSnowSet[psIdx] = true; peakSnowIdx = psIdx; }
    if (tMaxIdx >= 0) maxTempSet[tMaxIdx] = true;
    if (tMinIdx >= 0) { minTempSet[tMinIdx] = true; minTempIdx = tMinIdx; }
    if (fMaxIdx >= 0) maxSfcSet[fMaxIdx] = true;
    if (fMinIdx >= 0) { minSfcSet[fMinIdx] = true; minSfcIdx = fMinIdx; }
    if (dMaxIdx >= 0) maxDewSet[dMaxIdx] = true;
    if (dMinIdx >= 0) minDewSet[dMinIdx] = true;
    if (sunMaxIdx >= 0 && sunMax > 0) maxSunSet[sunMaxIdx] = true;
    if (sunMinIdx >= 0) minSunSet[sunMinIdx] = true;
    if (hMaxIdx >= 0) maxHumSet[hMaxIdx] = true;
    if (hMinIdx >= 0) minHumSet[hMinIdx] = true;
    if (pMaxIdx >= 0) maxProbSet[pMaxIdx] = true;
    if (pMinIdx >= 0) minProbSet[pMinIdx] = true;
  } else if (dailyPeakVals) {
    const newDay = () => ({ wMax: -1, wMaxIdx: -1, wMin: null, wMinIdx: -1,
      pr: -1, prIdx: -1, ps: -1, psIdx: -1,
      tMax: null, tMaxIdx: -1, tMin: null, tMinIdx: -1,
      fMax: null, fMaxIdx: -1, fMin: null, fMinIdx: -1,
      dMax: null, dMaxIdx: -1, dMin: null, dMinIdx: -1,
      sunMax: -1, sunMaxIdx: -1, sunMin: null, sunMinIdx: -1,
      hMax: null, hMaxIdx: -1, hMin: null, hMinIdx: -1,
      pMax: null, pMaxIdx: -1, pMin: null, pMinIdx: -1 });
    const perDay = {};
    for (let pi = 0; pi < n; pi++) {
      const key = dayKeyOf(pi);
      if (!perDay[key]) perDay[key] = newDay();
      const d = perDay[key];
      const g = Math.max(hours[pi].wind || 0, hours[pi].gust || 0);
      if (g > d.wMax) { d.wMax = g; d.wMaxIdx = pi; }
      if (d.wMin === null || g < d.wMin) { d.wMin = g; d.wMinIdx = pi; }
      if ((hours[pi].rain || 0) > d.pr) { d.pr = hours[pi].rain || 0; d.prIdx = pi; }
      if ((hours[pi].snow || 0) > d.ps) { d.ps = hours[pi].snow || 0; d.psIdx = pi; }
      const t = numOrNull(hours[pi].temp);
      if (t !== null && (d.tMax === null || t > d.tMax)) { d.tMax = t; d.tMaxIdx = pi; }
      if (t !== null && (d.tMin === null || t < d.tMin)) { d.tMin = t; d.tMinIdx = pi; }
      const f = numOrNull(hours[pi].sfc);
      if (f !== null && (d.fMax === null || f > d.fMax)) { d.fMax = f; d.fMaxIdx = pi; }
      if (f !== null && (d.fMin === null || f < d.fMin)) { d.fMin = f; d.fMinIdx = pi; }
      const dw = numOrNull(hours[pi].dew);
      if (dw !== null && (d.dMax === null || dw > d.dMax)) { d.dMax = dw; d.dMaxIdx = pi; }
      if (dw !== null && (d.dMin === null || dw < d.dMin)) { d.dMin = dw; d.dMinIdx = pi; }
      const sv = hours[pi].sun || 0;
      if (sv > d.sunMax) { d.sunMax = sv; d.sunMaxIdx = pi; }
      if (sv > 0 && (d.sunMin === null || sv < d.sunMin)) { d.sunMin = sv; d.sunMinIdx = pi; }
      const hv = numOrNull(hours[pi].humidity);
      if (hv !== null && (d.hMax === null || hv > d.hMax)) { d.hMax = hv; d.hMaxIdx = pi; }
      if (hv !== null && (d.hMin === null || hv < d.hMin)) { d.hMin = hv; d.hMinIdx = pi; }
      const pv = numOrNull(hours[pi].prob);
      if (pv !== null && (d.pMax === null || pv > d.pMax)) { d.pMax = pv; d.pMaxIdx = pi; }
      if (pv !== null && (d.pMin === null || pv < d.pMin)) { d.pMin = pv; d.pMinIdx = pi; }
    }
    for (const key of Object.keys(perDay)) {
      const d = perDay[key];
      if (d.wMaxIdx >= 0 && d.wMax > 0) { peakWindSet[d.wMaxIdx] = true; if (peakWindIdx < 0) peakWindIdx = d.wMaxIdx; }
      if (d.wMinIdx >= 0) minWindSet[d.wMinIdx] = true;
      if (d.prIdx >= 0 && d.pr >= 0.1) { peakRainSet[d.prIdx] = true; if (peakRainIdx < 0) peakRainIdx = d.prIdx; }
      if (d.psIdx >= 0 && d.ps >= 0.1) { peakSnowSet[d.psIdx] = true; if (peakSnowIdx < 0) peakSnowIdx = d.psIdx; }
      if (d.tMaxIdx >= 0) maxTempSet[d.tMaxIdx] = true;
      if (d.tMinIdx >= 0) { minTempSet[d.tMinIdx] = true; if (minTempIdx < 0) minTempIdx = d.tMinIdx; }
      if (d.fMaxIdx >= 0) maxSfcSet[d.fMaxIdx] = true;
      if (d.fMinIdx >= 0) { minSfcSet[d.fMinIdx] = true; if (minSfcIdx < 0) minSfcIdx = d.fMinIdx; }
      if (d.dMaxIdx >= 0) maxDewSet[d.dMaxIdx] = true;
      if (d.dMinIdx >= 0) minDewSet[d.dMinIdx] = true;
      if (d.sunMaxIdx >= 0 && d.sunMax > 0) maxSunSet[d.sunMaxIdx] = true;
      if (d.sunMinIdx >= 0) minSunSet[d.sunMinIdx] = true;
      if (d.hMaxIdx >= 0) maxHumSet[d.hMaxIdx] = true;
      if (d.hMinIdx >= 0) minHumSet[d.hMinIdx] = true;
      if (d.pMaxIdx >= 0) maxProbSet[d.pMaxIdx] = true;
      if (d.pMinIdx >= 0) minProbSet[d.pMinIdx] = true;
    }
  }
  if (drawHum || drawProb) {
    s += `<text x="${W - padR}" y="${(humY(50) + 4).toFixed(1)}" fill="${PROB_COLOR}" font-size="10" text-anchor="end">50%</text>\n`;
    s += `<text x="${W - padR}" y="${(humY(0) + 4).toFixed(1)}" fill="${PROB_COLOR}" font-size="10" text-anchor="end">0%</text>\n`;
  }

  // Hour labels (mirrors the Cinnamon applet): every hour while the window
  // is short, thinned to ~12 grid labels for long windows. Displayed hour
  // texts are placed by priority ("now", then midnights, then grid) so any
  // two are at least ~40px apart — 00:00 always has breathing room.
  const isNewDayAt = (idx) => {
    if (idx <= 0 || idx >= n) return false;
    const a = hours[idx - 1].time, b = hours[idx].time;
    if (!(a instanceof Date) || isNaN(a) || !(b instanceof Date) || isNaN(b)) return false;
    return a.getFullYear() !== b.getFullYear() ||
      a.getMonth() !== b.getMonth() || a.getDate() !== b.getDate();
  };
  let labelEvery = 1;
  if (n > 24) {
    labelEvery = Math.ceil(n / 12);
    const pxEvery = Math.ceil(50 / Math.max(slot, 1));
    if (pxEvery > labelEvery) labelEvery = pxEvery;
  }
  const shownList = [0];
  const collidesShown = (idx) => {
    for (let c = 0; c < shownList.length; c++) {
      if (Math.abs(idx - shownList[c]) * slot < 40) return true;
    }
    return false;
  };
  const midnightHourHidden = {};
  for (let m = 1; m < n; m++) {
    if (!isNewDayAt(m)) continue;
    if (collidesShown(m)) { midnightHourHidden[m] = true; }
    else { shownList.push(m); }
  }
  for (let g = 1; g < n; g++) {
    if (isNewDayAt(g) || midnightHourHidden[g]) continue;
    if (n > 24 && (g % labelEvery !== 0)) continue;
    if (!collidesShown(g)) shownList.push(g);
  }
  const isShownLabel = (idx) => shownList.indexOf(idx) !== -1;

  for (let i = 0; i < n; i++) {
    const cx = cxOf(i);
    const x = (cx - barW / 2).toFixed(1);
    const hh = hours[i];
    const rh = (hh.rain / maxRain) * barMaxH;
    const sh = (hh.snow / maxSnow) * barMaxH * 0.6;
    if (drawPrecip && rh > 0.5) {
      s += `<rect x="${x}" y="${(base - rh).toFixed(1)}" width="${barW.toFixed(1)}" height="${rh.toFixed(1)}" fill="#3377ff"/>\n`;
    }
    if (drawPrecip && sh > 0.5) {
      s += `<rect x="${x}" y="${(base - rh - sh).toFixed(1)}" width="${barW.toFixed(1)}" height="${sh.toFixed(1)}" fill="#b3e5fc"/>\n`;
    }
    s += `<rect x="${x}" y="${stripY}" width="${barW.toFixed(1)}" height="${stripH}" fill="${RISK_FILL[hh.name]}"${hh.ice ? ` stroke="#4dd0e1" stroke-width="${i === iceStartIdx ? '2.5' : '1.5'}"` : ''}/>\n`;
    // When the coming hours cross midnight, a vertical separator marks the
    // boundary (mirrors the applet). The day label itself
    // (date/weekday/both, see --day-labels) sits on its own row
    // underneath, centered over the visible hours of its calendar day.
    const isNewDay = isNewDayAt(i);
    if (isNewDay) {
      const sepX = (cx - slot / 2).toFixed(1);
      s += `<line x1="${sepX}" y1="${padT}" x2="${sepX}" y2="${base}" stroke="#555" stroke-width="1" stroke-dasharray="4,3"/>\n`;
    }
    // Cyan start line at the left edge of the first ICE hour.
    if (i === iceStartIdx && iceStartIdx > 0) {
      const ix = (cx - slot / 2).toFixed(1);
      s += `<line x1="${ix}" y1="${padT}" x2="${ix}" y2="${base}" stroke="#4dd0e1" stroke-width="2" stroke-dasharray="6,3"/>\n`;
    }
    const showLabel = isShownLabel(i);
    const lbl = i === 0 ? 'now' : `${String(hh.time.getHours()).padStart(2, '0')}:00`;
    // Connector from each displayed hour label up to its risk strip, so the
    // label unambiguously points at its block (mirrors applet.js).
    if (showLabel) {
      s += `<line x1="${cx.toFixed(1)}" y1="${stripY + stripH}" x2="${cx.toFixed(1)}" y2="${hourY - 3}" stroke="#888" stroke-width="1"/>\n`;
    }
    s += `<text x="${cx.toFixed(1)}" y="${hourY}" fill="#999" font-size="10" text-anchor="middle">${showLabel ? esc(lbl) : ''}</text>\n`;
    if (showVals && drawPrecip && (hh.rain >= 0.1 || hh.snow >= 0.1)) {
      let pv = '';
      if (hh.rain >= 0.1 && (!peakVals ? (!alternateVals || i % 2 === 0) : peakRainSet[i])) pv += isImperial(units) ? (hh.rain / 25.4).toFixed(2) : hh.rain.toFixed(1);
      if (hh.snow >= 0.1 && (!peakVals ? (!alternateVals || i % 2 === 0) : peakSnowSet[i])) pv += (pv ? '+' : '') + (isImperial(units) ? (hh.snow / 2.54).toFixed(2) : hh.snow.toFixed(1)) + 's';
      if (pv) s += `<text x="${cx.toFixed(1)}" y="${(base - rh - sh - 5).toFixed(1)}" fill="#9ec1ff" font-size="9" text-anchor="middle">${pv}</text>\n`;
    }
    if (hh.ice) {
      s += `<text x="${cx.toFixed(1)}" y="${padT - 6}" fill="#4dd0e1" font-size="13" text-anchor="middle">❄</text>\n`;
    }
    // Wind markers ride just above the white dotted wind+gust-max curve
    // (same convention as CurrentWindWidget.mc). Size mirrors the dart
    // tiers (18/25/35 km/h metric — tiers stay metric, only the shown
    // number converts). Height = strength: strong hours sit high,
    // calm hours sink low. Hidden with --no-wind, --values=none, or —
    // with --values=peak/peak-day — everywhere except the labeled max/min
    // hour(s); with --values=alternate only on even hours.
    const wSize = (hh.wind >= 35 || hh.gust >= 45) ? 15 :
      ((hh.wind >= 25 || hh.gust >= 35) ? 13 : (hh.wind >= 18 ? 12 : 11));
    const wY = windMarkY(i);
    if (drawWind && showVals && (peakVals ? (peakWindSet[i] || minWindSet[i]) : (!alternateVals || i % 2 === 0))) {
      s += `<text x="${cx.toFixed(1)}" y="${wY.toFixed(1)}" fill="#fff" font-size="${wSize}" text-anchor="middle" stroke="#000" stroke-opacity="0.7" stroke-width="3" paint-order="stroke">${esc(windArrow(hh.wdir) + fmtSpeedNum(hh.wind, units))}</text>\n`;
    }
  }
  // Day-row labels, one per visible calendar-day segment, centered over
  // that day's columns (middle of the day) so it is obvious which columns
  // belong to which day. Partial edge days are centered over their visible
  // hours; days without timestamps are skipped.
  const daySegs = [];
  for (let di = 0; di < n; di++) {
    const key = dayKeyOf(di);
    const last = daySegs.length ? daySegs[daySegs.length - 1] : null;
    const t = hours[di] && hours[di].time;
    const valid = (t instanceof Date && !isNaN(t)) ? t : null;
    if (last && last.key === key) {
      last.end = di;
      if (!last.time && valid) last.time = valid;
    } else {
      daySegs.push({ key, start: di, end: di, time: valid });
    }
  }
  for (const seg of daySegs) {
    if (!seg.time) continue;
    const cx = (cxOf(seg.start) + cxOf(seg.end)) / 2;
    s += `<text x="${cx.toFixed(1)}" y="${dayY}" fill="#fff" font-size="10" text-anchor="middle" font-weight="bold">${esc(dayRowLabel(seg.time, dayLabelsMode))}</text>\n`;
  }
  // Top banner for the ice start, clamped inside the canvas.
  if (iceStartIdx >= 0) {
    const iceCx = cxOf(iceStartIdx);
    const iceTx = Math.min(Math.max(iceCx, padL + 80), W - padR - 80);
    s += `<text x="${iceTx.toFixed(1)}" y="${padT - 26}" fill="#4dd0e1" font-size="13" font-weight="bold" text-anchor="middle" stroke="#000" stroke-opacity="0.7" stroke-width="3" paint-order="stroke">${esc(iceStartLabel())}</text>\n`;
  }
  if (drawHum) s += `<path d="${linePath((i) => humY(hours[i].humidity))}" fill="none" stroke="#4dd0e1" stroke-width="1.5" stroke-dasharray="6,3"/>\n`;
  if (drawProb) s += `<path d="${linePath((i) => probY(hours[i].prob))}" fill="none" stroke="${PROB_COLOR}" stroke-width="1.5" stroke-dasharray="1,3" stroke-linecap="round"/>\n`;
  if (drawWind) s += `<path d="${linePath((i) => windY(Math.max(hours[i].wind, hours[i].gust)))}" fill="none" stroke="#fff" stroke-width="1.5" stroke-dasharray="2,3"/>\n`;
  if (drawSun) s += `<path d="${linePath((i) => sunY(hours[i].sun))}" fill="none" stroke="#ffd24a" stroke-width="2"/>\n`;
  if (drawDew) s += `<path d="${linePath((i) => tempY(hours[i].dew))}" fill="none" stroke="#9e9e9e" stroke-width="2"/>\n`;
  if (drawSfc) s += `<path d="${linePath((i) => tempY(hours[i].sfc))}" fill="none" stroke="${SFC_COLOR}" stroke-width="2"/>\n`;
  if (drawTemp) s += `<path d="${linePath((i) => tempY(hours[i].temp))}" fill="none" stroke="#ff5252" stroke-width="2"/>\n`;
  // Peak modes: label the max + min of every trace metric on its curve
  // (max above its point, min below). "peak" = global extremes,
  // "peak-day" = each day's extremes. Rain/snow keep only the wettest-hour
  // column numbers; sun skips zero hours. Mirrors the Cinnamon applet.
  // Labels are clamped inside the plot.
  if (peakVals && showVals) {
    const clampY = (y) => Math.min(Math.max(y, 12), base - 2);
    const extLabel = (idx, y, color, size, txt) => {
      s += `<text x="${cxOf(idx).toFixed(1)}" y="${clampY(y).toFixed(1)}" fill="${color}" font-size="${size}" font-weight="bold" text-anchor="middle" stroke="#000" stroke-opacity="0.7" stroke-width="3" paint-order="stroke">${esc(txt)}</text>\n`;
    };
    const fmtPct = (v) => `${Math.round(v)}%`;
    const fmtSun = (v) => `${Math.round(v / 60)}m`;
    const extDefs = [
      { set: maxTempSet, color: '#ff5252', size: 11, dy: -8, need: drawTemp,
        yOf: (ii) => tempY(hours[ii].temp), vOf: (ii) => hours[ii].temp, f: (vv) => fmtTemp1(vv, units) },
      { set: minTempSet, color: '#ff5252', size: 11, dy: -8, need: drawTemp,
        yOf: (ii) => tempY(hours[ii].temp), vOf: (ii) => hours[ii].temp, f: (vv) => fmtTemp1(vv, units) },
      { set: maxSfcSet, color: SFC_COLOR, size: 11, dy: 14, need: drawSfc,
        yOf: (ii) => tempY(hours[ii].sfc), vOf: (ii) => hours[ii].sfc, f: (vv) => fmtTemp1(vv, units) },
      { set: minSfcSet, color: SFC_COLOR, size: 11, dy: 14, need: drawSfc,
        yOf: (ii) => tempY(hours[ii].sfc), vOf: (ii) => hours[ii].sfc, f: (vv) => fmtTemp1(vv, units) },
      { set: maxDewSet, color: '#9e9e9e', size: 10, dy: -20, need: drawDew,
        yOf: (ii) => tempY(hours[ii].dew), vOf: (ii) => hours[ii].dew, f: (vv) => fmtTemp1(vv, units) },
      { set: minDewSet, color: '#9e9e9e', size: 10, dy: 26, need: drawDew,
        yOf: (ii) => tempY(hours[ii].dew), vOf: (ii) => hours[ii].dew, f: (vv) => fmtTemp1(vv, units) },
      { set: maxSunSet, color: '#ffd24a', size: 10, dy: -8, need: drawSun,
        yOf: (ii) => sunY(hours[ii].sun), vOf: (ii) => hours[ii].sun, f: (vv) => fmtSun(vv) },
      { set: minSunSet, color: '#ffd24a', size: 10, dy: 14, need: drawSun,
        yOf: (ii) => sunY(hours[ii].sun), vOf: (ii) => hours[ii].sun, f: (vv) => fmtSun(vv) },
      { set: maxHumSet, color: '#4dd0e1', size: 10, dy: -8, need: drawHum,
        yOf: (ii) => humY(hours[ii].humidity), vOf: (ii) => hours[ii].humidity, f: (vv) => fmtPct(vv) },
      { set: minHumSet, color: '#4dd0e1', size: 10, dy: 14, need: drawHum,
        yOf: (ii) => humY(hours[ii].humidity), vOf: (ii) => hours[ii].humidity, f: (vv) => fmtPct(vv) },
      { set: maxProbSet, color: PROB_COLOR, size: 10, dy: -20, need: drawProb,
        yOf: (ii) => probY(hours[ii].prob), vOf: (ii) => hours[ii].prob, f: (vv) => fmtPct(vv) },
      { set: minProbSet, color: PROB_COLOR, size: 10, dy: 26, need: drawProb,
        yOf: (ii) => probY(hours[ii].prob), vOf: (ii) => hours[ii].prob, f: (vv) => fmtPct(vv) },
    ];
    for (const D of extDefs) {
      if (!D.need) continue;
      for (let ei = 0; ei < n; ei++) {
        if (!D.set[ei]) continue;
        const vv = D.vOf(ei);
        if (vv === null || vv === undefined || isNaN(vv)) continue;
        extLabel(ei, D.yOf(ei) + D.dy, D.color, D.size, D.f(vv));
      }
    }
  }

  // Legend in its own rows below the hour numbers, so it never covers
  // them. Line 1 = every overlaid trace actually drawn, line 2 =
  // columns, risk strip, markers, background.
  const ly1 = hourY + 28;
  const traceSegs = [];
  if (drawTemp) traceSegs.push(`<tspan fill="#ff5252">— temp air ${tempScaleUnit(units)}</tspan>`);
  if (drawSfc) traceSegs.push(`<tspan fill="${SFC_COLOR}">— temp sfc ${tempScaleUnit(units)}</tspan>`);
  if (drawDew) traceSegs.push('<tspan fill="#9e9e9e">— dewpoint</tspan>');
  if (drawSun) traceSegs.push('<tspan fill="#ffd24a">— sun</tspan>');
  if (drawWind) traceSegs.push(`<tspan fill="#fff">┄ wind+gust max (${speedUnit(units)})</tspan>`);
  if (drawHum) traceSegs.push('<tspan fill="#4dd0e1">┄ humidity %</tspan>');
  if (drawProb) traceSegs.push(`<tspan fill="${PROB_COLOR}">… precip prob %</tspan>`);
  s += `<text x="${padL}" y="${ly1}" fill="#bbb" font-size="11">${traceSegs.join(' · ')}<tspan fill="#bbb"> (left ${tempScaleUnit(units)} temp scale · right % humidity/prob scale)</tspan></text>\n`;
  const colSegs = [];
  if (drawPrecip) {
    colSegs.push(`<tspan fill="#3377ff">blue column = rain ${rainRateUnit(units)}</tspan>`);
    colSegs.push(`<tspan fill="#b3e5fc">pale column = snow ${snowRateUnit(units)}</tspan>`);
  }
  colSegs.push('strip = risk level');
  colSegs.push('❄ = ICE hour + cyan strip outline');
  colSegs.push('▼ = ice starts');
  if (drawWind && showVals) colSegs.push('wind markers ride dotted line (higher = stronger)');
  if (peakVals && showVals) colSegs.push(dailyPeakVals ? 'max + min labeled per day' : 'max + min labeled');
  if (dnEnabled) colSegs.push('<tspan fill="#8fa3bf">shaded = night</tspan>');
  const ly2 = ly1 + 14;
  s += `<text x="${padL}" y="${ly2}" fill="#bbb" font-size="11">${colSegs.join(' · ')}</text>\n`;
  const advItems = (parsed.advice && parsed.advice.length) ? parsed.advice : ['—'];
  wrapAdvice(advItems, 100).forEach((ln, k) => {
    s += `<text x="${padL}" y="${ly2 + 15 + k * 13}" fill="#888" font-size="10">${k === 0 ? 'advice: ' : ''}${esc(ln)}</text>\n`;
  });
  s += '</svg>\n';

  fs.writeFileSync(outFile, s);
  console.log(`Wrote ${outFile} (${N} hours, current risk ${parsed.riskLevel}). Open it in a browser.`);
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
