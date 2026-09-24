/*
 * Slippery — Cinnamon panel applet.
 *
 * Same data + same checks as the Slippery Connect IQ data field:
 *  - Open-Meteo request mirrors source/background/BackgroundService.mc
 *    (hourly vars + apparent_temperature, past_hours=12,
 *     forecast_hours=12, unixtime, minutely_15)
 *  - evaluateRisk() is a direct port of source/weatherrisks/riskCalculator.mc
 *  - seasons mirror source/weatherrisks/helpers.mc
 *  - user thresholds mirror SlipperyApp.mc / AlertStateAnalyzer.mc
 *    (ice, winds, heat, precip-ahead); the ice threshold drives the big
 *    ICE banner, the rest stay configurable without cluttering the popup.
 *    The core risk engine itself stays stock so node tests
 *    (nodetest/slipperycheck.js) keep covering this logic.
 *  - HSP text-color check mirrors source/utils/color_utils.mc
 *    (sqrt(0.299 R^2 + 0.587 G^2 + 0.114 B^2), configurable breakpoint).
 *
 * Node has no role here: Cinnamon applets run on GJS, so HTTP goes through
 * `curl` (preinstalled on Mint) via Gio.Subprocess — this also avoids the
 * Soup 2 vs 3 API split between Cinnamon versions.
 */

const Applet = imports.ui.applet;
const Mainloop = imports.mainloop;
const Settings = imports.ui.settings;
const PopupMenu = imports.ui.popupMenu;
const Gio = imports.gi.Gio;
const GLib = imports.gi.GLib;
let St = null;
try {
    St = imports.gi.St;
} catch (e) { St = null; }
let ByteArray = null;
try {
    ByteArray = imports.byteArray;
} catch (e) { ByteArray = null; }

const UUID = "slippery@local";

// ---------------------------------------------------------------------------
// Pure risk engine (no Cinnamon dependencies — kept identical to
// nodetest/slipperycheck.js so node tests cover this logic).
// ---------------------------------------------------------------------------

const RAIN_THRESHOLD = 0.1;
const SNOW_THRESHOLD = 0.1;

const RiskLevel = { NO_DATA: 0, SAFE: 1, SLIGHT: 2, MODERATE: 3, HIGH: 4, CRITICAL: 5 };
const RISK_NAMES = ["NO_DATA", "SAFE", "SLIGHT", "MODERATE", "HIGH", "CRITICAL"];
const SHORT_LABEL = { NO_DATA: "-", SAFE: "Ok", SLIGHT: "Low", MODERATE: "Mod", HIGH: "Hig", CRITICAL: "Crt" };

// todo.md: "colors bright" / "colors modest". "follow-theme" was removed:
// the new "color-min-level = Never" covers it (chip stays unstyled).
const RISK_BG = {
    bright: {
        NO_DATA: "#9e9e9e",
        SAFE: "#4caf50",
        SLIGHT: "#ffff00",
        MODERATE: "#ffa500",
        HIGH: "#ff4500",
        CRITICAL: "#ff0000",
    },
    modest: {
        NO_DATA: "#777777",
        SAFE: "#2e7d32",
        SLIGHT: "#8f8500",
        MODERATE: "#9c6b00",
        HIGH: "#a83a00",
        CRITICAL: "#a00000",
    },
};
// Fixed fallback text colors when the HSP check is switched off.
const RISK_TEXT_FIXED = {
    NO_DATA: "#fff",
    SAFE: "#fff",
    SLIGHT: "#000",
    MODERATE: "#000",
    HIGH: "#fff",
    CRITICAL: "#fff",
};

// Hazards that count as ICE (big warning, here and in the coming hours).
const ICE_HAZARDS = ["Black Ice / Freezing Wet Road", "Road Surface Frost", "Ice On Bridges"];

const Hazards = {
    BLACK_ICE: "Black Ice / Freezing Wet Road",
    SNOW_SLUSH: "Snow Or Slush Accumulation",
    FROST: "Road Surface Frost",
    WET_LEAVES: "Wet Leaf Coverage",
    FIRST_RAIN: "First Rain Releasing Dirt / Oils",
    BRIDGE_ICE: "Ice On Bridges",
    WET_ASPHALT: "Wet Asphalt Surface",
    HEAVY_RAIN: "Heavy Rain / Hydroplaning",
    CROSSWIND: "Strong Crosswinds",
    GALE: "Gale Force Winds",
    IMMINENT_SNOW: "Immin Snow",
    IMMINENT_RAIN: "Immin Rain",
};

const Advice = {
    AVOID_RIDING: "Avoid Riding",
    LOWER_TIRE_PRESSURE: "Lower Tire Pressure",
    TRACTION_LOSS_TURNS: "Loss Of Traction In Turns",
    TREAD_REQUIRED: "Tread Pattern Required",
    WATCH_SHADED: "Watch Shaded Areas, Bridges, Tree-Lined Roads",
    AVOID_BRAKING: "Avoid Sudden Braking",
    SLIP_CORNERING: "Extreme Slip Hazard On Cornering Lines",
    ASPHALT_SLIPPERY: "Asphalt Slippery After Dry Spell",
    TRACTION_AFTER_RAIN: "Traction Improves After Heavier Rain",
    BRAKING_DISTANCE: "Increase Braking Distance",
    LEAN_ANGLE: "Reduce Cornering Lean Angle",
    SPEED_GRIP: "Reduce Speed And Increase Grip Margin",
    HOLD_BARS: "Hold Handlebars Firmly",
    OPEN_FIELDS: "Beware Of Open Fields And Bridges",
    LOWER_PROFILE_WHEELS: "Consider Lower Profile Wheels",
    RAIN_NOW: "Rain Starting Now",
    SNOW_NOW: "Snow Starting Now",
};

function getSeason(lat, date) {
    const month = date.getUTCMonth() + 1;
    let season;
    if (month >= 3 && month <= 5) season = "spring";
    else if (month >= 6 && month <= 8) season = "summer";
    else if (month >= 9 && month <= 11) season = "autumn";
    else season = "winter";
    if (lat < 0) {
        const inv = { spring: "autumn", summer: "winter", autumn: "spring", winter: "summer" };
        season = inv[season];
    }
    return season;
}

// Exact port of RiskCalculator.evaluateRisk(). All thresholds match.
function evaluateRisk(p) {
    let riskLevel = RiskLevel.SAFE;
    const hazards = [];
    const advice = [];
    const upgrade = (l) => { if (l > riskLevel) riskLevel = l; };
    const addH = (h) => { if (hazards.indexOf(h) === -1) hazards.push(h); };
    const addA = (a) => { if (advice.indexOf(a) === -1) advice.push(a); };

    if ((p.surfaceTemp <= 0.0 || p.airTemp <= 0.5) &&
        (p.runningRain12h >= RAIN_THRESHOLD || p.rainCurrent >= RAIN_THRESHOLD ||
         p.runningSnow12h >= SNOW_THRESHOLD || p.snowCurrent >= SNOW_THRESHOLD)) {
        upgrade(RiskLevel.CRITICAL);
        addH(Hazards.BLACK_ICE); addA(Advice.AVOID_RIDING); addA(Advice.LOWER_TIRE_PRESSURE);
    }
    if (p.surfaceTemp <= 0.0 && p.surfaceDewSpread <= 2.0 && p.humidity >= 80) {
        upgrade(RiskLevel.CRITICAL);
        addH(Hazards.FROST); addA(Advice.WATCH_SHADED); addA(Advice.AVOID_BRAKING);
    }
    if (p.airTemp >= 0.0 && p.airTemp <= 2.5 &&
        (p.runningRain12h >= RAIN_THRESHOLD || p.humidity > 88 || p.runningSnow12h >= SNOW_THRESHOLD)) {
        upgrade(RiskLevel.HIGH);
        addH(Hazards.BRIDGE_ICE); addA(Advice.WATCH_SHADED);
    }
    if (p.runningSnow12h >= SNOW_THRESHOLD && (p.surfaceTemp <= 1.0 || p.airTemp <= 1.5)) {
        upgrade(RiskLevel.HIGH);
        addH(Hazards.SNOW_SLUSH); addA(Advice.TRACTION_LOSS_TURNS); addA(Advice.TREAD_REQUIRED);
    }
    if (p.rainCurrent >= 15.0) {
        upgrade(RiskLevel.CRITICAL);
        addH(Hazards.HEAVY_RAIN); addA(Advice.SPEED_GRIP); addA(Advice.BRAKING_DISTANCE);
    } else if (p.rainCurrent >= 7.5) {
        upgrade(RiskLevel.HIGH);
        addH(Hazards.HEAVY_RAIN); addA(Advice.BRAKING_DISTANCE); addA(Advice.SPEED_GRIP);
    } else if ((p.season === "summer" || p.season === "spring") &&
               p.rainCurrent >= 0.1 && p.rainCurrent < 2.5 && p.dryStreak >= 10) {
        upgrade(RiskLevel.MODERATE);
        addH(Hazards.FIRST_RAIN); addA(Advice.ASPHALT_SLIPPERY); addA(Advice.TRACTION_AFTER_RAIN);
    } else if (p.rainCurrent >= 2.5) {
        upgrade(RiskLevel.MODERATE);
        addH(Hazards.WET_ASPHALT); addA(Advice.BRAKING_DISTANCE); addA(Advice.LEAN_ANGLE);
    } else if (p.rainCurrent >= 0.2) {
        upgrade(RiskLevel.SLIGHT);
        addH(Hazards.WET_ASPHALT); addA(Advice.BRAKING_DISTANCE);
    }
    if (p.season === "autumn" &&
        (p.runningRain12h >= RAIN_THRESHOLD || p.runningSnow12h >= SNOW_THRESHOLD ||
         p.rainCurrent >= RAIN_THRESHOLD || p.snowCurrent >= SNOW_THRESHOLD)) {
        upgrade(RiskLevel.MODERATE);
        addH(Hazards.WET_LEAVES); addA(Advice.SLIP_CORNERING); addA(Advice.LEAN_ANGLE);
    }
    if (p.surfaceTemp > 0.0 && p.humidity > 90 && p.surfaceDewSpread <= 1.0) {
        upgrade(RiskLevel.SLIGHT);
        addH(Hazards.WET_ASPHALT); addA(Advice.WATCH_SHADED); addA(Advice.LEAN_ANGLE);
    }

    const gustRatio = p.windSpeed > 1.0 ? p.windGust / p.windSpeed : 1.0;
    if (p.windSpeed >= 45.0 || p.windGust >= 60.0 || (p.windSpeed >= 35.0 && gustRatio >= 1.7)) {
        upgrade(RiskLevel.CRITICAL);
        addH(Hazards.GALE); addA(Advice.OPEN_FIELDS); addA(Advice.HOLD_BARS); addA(Advice.LOWER_PROFILE_WHEELS);
    } else if (p.windSpeed >= 35.0 || p.windGust >= 45.0 || (p.windSpeed >= 25.0 && gustRatio >= 1.5)) {
        upgrade(RiskLevel.HIGH);
        addH(Hazards.CROSSWIND); addA(Advice.OPEN_FIELDS); addA(Advice.HOLD_BARS);
    } else if (p.windSpeed >= 25.0 || p.windGust >= 35.0 || (p.windSpeed >= 18.0 && gustRatio >= 1.3)) {
        upgrade(RiskLevel.MODERATE);
        addH(Hazards.CROSSWIND); addA(Advice.HOLD_BARS);
    } else if (p.windSpeed >= 20.0) {
        upgrade(RiskLevel.SLIGHT);
        addH(Hazards.CROSSWIND); addA(Advice.HOLD_BARS);
    }

    if (p.immediateRain >= 0 && p.rainCurrent < RAIN_THRESHOLD) {
        upgrade(RiskLevel.HIGH);
        addH(Hazards.IMMINENT_RAIN);
        addA(p.immediateRain === 0 ? Advice.RAIN_NOW : "Rain in " + p.immediateRain + " min");
    }
    if (p.immediateSnow >= 0 && p.snowCurrent < SNOW_THRESHOLD) {
        upgrade(RiskLevel.HIGH);
        addH(Hazards.IMMINENT_SNOW);
        addA(p.immediateSnow === 0 ? Advice.SNOW_NOW : "Snow in " + p.immediateSnow + " min");
    }
    return { level: riskLevel, name: RISK_NAMES[riskLevel], hazards: hazards, advice: advice };
}

function pickHourly(hourly, keys, n) {
    for (let k = 0; k < keys.length; k++) {
        if (Array.isArray(hourly[keys[k]])) return hourly[keys[k]];
    }
    return new Array(n).fill(0);
}

function checkImminent(arr) {
    if (!arr || arr.length === 0) return -1;
    const n = Math.min(arr.length, 4);
    for (let i = 0; i < n; i++) {
        if (arr[i] != null && arr[i] >= 0.1) return i * 15;
    }
    return -1;
}

// --- HSP luminance (port of source/utils/color_utils.mc) -------------------
// HSP 0 = black, 255 = white. Backgrounds brighter than the breakpoint get
// black text, darker ones get white text. Breakpoint is user-configurable.
function hexToRgb(hex) {
    let h = String(hex || "").replace("#", "");
    if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
    if (h.length !== 6) return [0, 0, 0];
    const v = parseInt(h, 16);
    if (isNaN(v)) return [0, 0, 0];
    return [(v >> 16) & 0xff, (v >> 8) & 0xff, v & 0xff];
}

function hspOfHex(hex) {
    const c = hexToRgb(hex);
    return Math.sqrt(0.299 * c[0] * c[0] + 0.587 * c[1] * c[1] + 0.114 * c[2] * c[2]);
}

function textColorFor(bgHex, useHsp, threshold, riskName) {
    if (!useHsp) return RISK_TEXT_FIXED[riskName] || "#fff";
    let t = parseFloat(threshold);
    if (isNaN(t) || t < 0 || t > 255) t = 127; // desktop default, not a Garmin screen
    return hspOfHex(bgHex) > t ? "#000" : "#fff";
}

function chipStyle(colorMode, minLevel, levelNum, riskName, useHsp, hspThreshold) {
    // Old installs may still have color-mode=follow-theme stored: treat as never.
    if (colorMode === "follow-theme") return "";
    if (!colorPassesMinLevel(minLevel, levelNum)) return "";
    const pal = RISK_BG[colorMode] || RISK_BG.bright;
    const bg = pal[riskName] || "";
    if (!bg) return "";
    const fg = textColorFor(bg, useHsp, hspThreshold, riskName);
    const bold = (riskName === "CRITICAL") ? " font-weight: bold;" : "";
    return "background-color: " + bg + "; color: " + fg + ";" + bold;
}

// Panel chip is only colored when the current risk reaches the configured
// minimum. "always" = every level, "never" = theme decides (old follow-theme).
function colorPassesMinLevel(minLevel, levelNum) {
    const m = String(minLevel || "always");
    if (m === "always") return true;
    if (m === "never") return false;
    const need = { slight: 2, moderate: 3, high: 4, critical: 5 }[m];
    if (need === undefined) return true;
    return (levelNum || 0) >= need;
}

// Panel-chip alert gate: "Primary + first alert" appends the first other
// location at/above this level (setting panel-chip-alert-level,
// default HIGH). Shares the RiskLevel numbering with colorPassesMinLevel.
function chipAlertLevelNum(v) {
    const need = { slight: 2, moderate: 3, high: 4, critical: 5 }[String(v || "high")];
    return need === undefined ? RiskLevel.HIGH : need;
}

// Wind direction as a unicode arrow (meteorological: where the wind goes to).
function windArrow(deg) {
    const d = parseFloat(deg);
    if (isNaN(d)) return "?";
    const norm = ((d % 360) + 360) % 360;
    const arrows = ["\u2193", "\u2199", "\u2190", "\u2196", "\u2191", "\u2197", "\u2192", "\u2198"];
    return arrows[Math.round(norm / 45) % 8];
}

// todo.md popup: only mention a detail group when it is relevant, i.e. at or
// near (10% below / small margin above) its threshold. Returns
// { cold, heat, wind, precip, tempRow, windRow } with prebuilt
// compact row strings (null when nothing in that group is relevant).
// profile (optional, from calculateProfile) is used so an ICE-ahead banner
// always has a visible temperature explanation: when a coming hour drops
// near the ice threshold, cold becomes true and tempRow gains the forecast
// low (air + surface + hour), even if the current hour is warm.
function relevantDetails(p, t, profile) {
    const feels = p.hasFeelsLike ? p.feelsLike : p.airTemp;
    const lows = forecastLows(profile);
    const coldNow = (p.airTemp <= t.ice + 2.0) || (p.surfaceTemp <= t.ice + 2.0);
    const coldAhead = !!lows && ((lows.minAir <= t.ice + 2.0) || (lows.minSfc <= t.ice + 2.0));
    const cold = coldNow || coldAhead;
    const heat = feels >= t.heat - 3.0;
    const windGate = Math.min(
        Math.max(t.crossGust, 1), Math.max(t.highCross, 1),
        Math.max(t.heavy, 1), Math.max(t.sustained, 1)) * 0.9;
    const windHaz = p.risk.hazards.indexOf(Hazards.CROSSWIND) !== -1 ||
        p.risk.hazards.indexOf(Hazards.GALE) !== -1;
    const wind = windHaz || p.windSpeed >= windGate || p.windGust >= 31.5;
    const precip = (p.rainCurrent >= RAIN_THRESHOLD || p.snowCurrent >= SNOW_THRESHOLD ||
        p.rain12 >= RAIN_THRESHOLD || p.snow12 >= SNOW_THRESHOLD ||
        p.immRain >= 0 || p.immSnow >= 0 ||
        p.rainCurrent >= t.precip * 0.9);

    let tempRow = null;
    if (cold || heat) {
        tempRow = "Air " + p.airTemp.toFixed(1) + "°";
        if (p.hasFeelsLike) tempRow += " (feels " + p.feelsLike.toFixed(1) + "°)";
        tempRow += " · sfc " + p.surfaceTemp.toFixed(1) + "°";
        // When the ICE banner comes from a coming hour (current looks warm),
        // append the forecast low so the popup explains the warning.
        if (lows && coldAhead) {
            tempRow += " → low air " + lows.minAir.toFixed(1) + "°" +
                (lows.minAirTime ? " @" + hourLabel(lows.minAirTime, false) : "") +
                " · sfc " + lows.minSfc.toFixed(1) + "°" +
                (lows.minSfcTime ? " @" + hourLabel(lows.minSfcTime, false) : "");
        }
    }
    let windRow = null;
    if (wind) {
        // Blow-to arrow (same convention as CurrentWindWidget.mc:
        // N wind (0°) blows toward the south, shown as ↓).
        windRow = "Wind " + windArrow(p.windDir) + " " +
            p.windSpeed.toFixed(0) + " " + compass16(p.windDir) +
            " (" + Math.round(p.windDir) + "°) · gust " + p.windGust.toFixed(0);
    }
    return { cold: cold, heat: heat, wind: wind,
             precip: precip, tempRow: tempRow, windRow: windRow };
}

function compass16(deg) {
    const dirs = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                  "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"];
    let d = parseFloat(deg);
    if (isNaN(d)) return "?";
    d = ((d % 360) + 360) % 360;
    return dirs[Math.round(d / 22.5) % 16];
}

function hasIceHazard(hazards) {
    if (!hazards) return false;
    for (let i = 0; i < hazards.length; i++) {
        if (ICE_HAZARDS.indexOf(hazards[i]) !== -1) return true;
    }
    return false;
}

function parseNum(v) {
    if (v === null || v === undefined || v === "") return NaN;
    return parseFloat(String(v).replace(",", "."));
}

// Parses one "lat, lon" configuration field. Accepts a Google Maps paste
// ("52.387520877358256, 4.7199631014777") as well as space/semicolon
// separated pairs and Dutch decimal commas ("52,3875, 4,7199").
// Returns { lat, lon } or null (empty/invalid = location disabled).
function parseCoordField(str) {
    if (str === null || str === undefined) return null;
    const s = String(str).trim();
    if (!s) return null;
    let parts;
    if (s.indexOf(";") !== -1) {
        parts = s.split(";");
    } else {
        const ws = s.split(/\s+/).filter((x) => x.length > 0);
        if (ws.length === 2) parts = ws;
        else if (s.indexOf(",") !== -1) parts = s.split(",");
        else parts = ws;
    }
    parts = parts.map((x) => x.trim()).filter((x) => x.length > 0);
    const num = (t) => {
        const v = parseFloat(String(t).replace(",", "."));
        return isNaN(v) ? NaN : v;
    };
    let lat = NaN, lon = NaN;
    if (parts.length === 2) {
        lat = num(parts[0]);
        lon = num(parts[1]);
    } else if (parts.length === 4) {
        // decimal-comma pair without whitespace: "52,3875,4,7199"
        lat = num(parts[0] + "." + parts[1]);
        lon = num(parts[2] + "." + parts[3]);
    } else {
        return null;
    }
    if (isNaN(lat) || isNaN(lon)) return null;
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;
    return { lat: lat, lon: lon };
}

// Mirrors weatherService.mc parseOpenMeteoResponse().
function parseResponse(lat, data, nowSec) {
    if (!data || !data.hourly || !data.hourly.time || data.hourly.time.length === 0) return null;
    const hourly = data.hourly;
    const times = hourly.time;
    let targetIdx = 0;
    for (let i = 0; i < times.length; i++) {
        if (times[i] <= nowSec) targetIdx = i;
        else break;
    }
    const at = (arr, i) => (i < arr.length && arr[i] != null ? arr[i] : 0);
    const airT = pickHourly(hourly, ["temperature_2m"], times.length);
    const feelT = pickHourly(hourly, ["apparent_temperature"], times.length);
    const surfT = pickHourly(hourly, ["surface_temperature"], times.length);
    const dewP = pickHourly(hourly, ["dewpoint_2m"], times.length);
    const hum = pickHourly(hourly, ["relativehumidity_2m"], times.length);
    const rain = pickHourly(hourly, ["rain"], times.length);
    const showers = pickHourly(hourly, ["showers"], times.length);
    const snow = pickHourly(hourly, ["snowfall"], times.length);
    const prob = pickHourly(hourly, ["precipitation_probability"], times.length);
    const windS = pickHourly(hourly, ["wind_speed_10m"], times.length);
    const windG = pickHourly(hourly, ["wind_gusts_10m"], times.length);
    const windD = pickHourly(hourly, ["wind_direction_10m"], times.length);

    let rain12 = 0, snow12 = 0;
    for (let j = Math.max(0, targetIdx - 12); j <= targetIdx; j++) {
        rain12 += at(rain, j) + at(showers, j);
        snow12 += at(snow, j);
    }
    let dry = 0;
    for (let k = targetIdx - 1; k >= 0 && dry < 24; k--) {
        if (at(rain, k) + at(showers, k) <= RAIN_THRESHOLD && at(snow, k) <= SNOW_THRESHOLD) dry++;
        else break;
    }
    const airTemp = at(airT, targetIdx);
    const surfaceTemp = at(surfT, targetIdx);
    const dewPoint = at(dewP, targetIdx);
    const rainCurrent = at(rain, targetIdx) + at(showers, targetIdx);
    const snowCurrent = at(snow, targetIdx);
    let immR = -1, immS = -1;
    if (data.minutely_15) {
        immR = checkImminent((data.minutely_15.rain || []).slice(0, 4));
        immS = checkImminent((data.minutely_15.snowfall || []).slice(0, 4));
    }
    const season = getSeason(lat, new Date(nowSec * 1000));
    const r = evaluateRisk({
        airTemp: airTemp,
        surfaceTemp: surfaceTemp,
        dewPoint: dewPoint,
        humidity: at(hum, targetIdx),
        rainCurrent: rainCurrent,
        runningRain12h: rain12,
        runningSnow12h: snow12,
        dryStreak: dry,
        season: season,
        windSpeed: at(windS, targetIdx),
        windGust: at(windG, targetIdx),
        immediateRain: immR,
        immediateSnow: immS,
        surfaceDewSpread: surfaceTemp - dewPoint,
        snowCurrent: snowCurrent,
    });
    return {
        risk: r,
        season: season,
        airTemp: airTemp,
        feelsLike: at(feelT, targetIdx),
        hasFeelsLike: Array.isArray(hourly["apparent_temperature"]),
        surfaceTemp: surfaceTemp,
        dewPoint: dewPoint,
        humidity: at(hum, targetIdx),
        rainCurrent: rainCurrent,
        snowCurrent: snowCurrent,
        precipProb: at(prob, targetIdx),
        windSpeed: at(windS, targetIdx),
        windGust: at(windG, targetIdx),
        windDir: at(windD, targetIdx),
        rain12: rain12,
        snow12: snow12,
        dryStreak: dry,
        immRain: immR,
        immSnow: immS,
        time: new Date(times[targetIdx] * 1000),
        // Kept for the forecast projection + precip-ahead alerts.
        _data: data,
        _targetIdx: targetIdx,
        _lat: lat,
    };
}

// Port of RiskProjectionEngine.calculate12HourRiskProfile(): current hour +
// up to 12 forecast hours, each with risk + precipitation (for the
// "coming x hours: risklevel + precipitation amount" rows and the ICE-ahead
// banner). Hazards per hour are included so ICE hours can be flagged.
function calculateProfile(parsed, maxHours) {
    const out = [];
    if (!parsed || !parsed._data || !parsed._data.hourly) return out;
    const hourly = parsed._data.hourly;
    const n = (hourly.time || []).length;
    const at = (arr, i) => (i < arr.length && arr[i] != null ? arr[i] : 0);
    const airT = pickHourly(hourly, ["temperature_2m"], n);
    const feelT = pickHourly(hourly, ["apparent_temperature"], n);
    const surfT = pickHourly(hourly, ["surface_temperature"], n);
    const dewP = pickHourly(hourly, ["dewpoint_2m"], n);
    const hum = pickHourly(hourly, ["relativehumidity_2m"], n);
    const rain = pickHourly(hourly, ["rain"], n);
    const showers = pickHourly(hourly, ["showers"], n);
    const snow = pickHourly(hourly, ["snowfall"], n);
    const windS = pickHourly(hourly, ["wind_speed_10m"], n);
    const windG = pickHourly(hourly, ["wind_gusts_10m"], n);
    const windD = pickHourly(hourly, ["wind_direction_10m"], n);
    const sun = pickHourly(hourly, ["sunshine_duration"], n);
    const start = parsed._targetIdx;
    const count = Math.min(n, start + 1 + Math.max(0, maxHours));
    for (let h = start; h < count; h++) {
        const airTemp = at(airT, h);
        const surfaceTemp = at(surfT, h);
        const dewPoint = at(dewP, h);
        const rainCur = at(rain, h) + at(showers, h);
        const snowCur = at(snow, h);
        let rain12 = 0, snow12 = 0;
        for (let k = Math.max(0, h - 12); k <= h; k++) {
            rain12 += at(rain, k) + at(showers, k);
            snow12 += at(snow, k);
        }
        let dry = 0;
        for (let d = h - 1; d >= 0 && dry < 24; d--) {
            if (at(rain, d) + at(showers, d) <= RAIN_THRESHOLD && at(snow, d) <= SNOW_THRESHOLD) dry++;
            else break;
        }
        let immR = -1;
        if (rainCur >= RAIN_THRESHOLD) immR = 0;
        else if (h + 1 < n && at(rain, h + 1) + at(showers, h + 1) >= RAIN_THRESHOLD) immR = 60;
        let immS = -1;
        if (snowCur >= SNOW_THRESHOLD) immS = 0;
        else if (h + 1 < n && at(snow, h + 1) >= SNOW_THRESHOLD) immS = 60;
        const r = evaluateRisk({
            airTemp: airTemp,
            surfaceTemp: surfaceTemp,
            dewPoint: dewPoint,
            humidity: at(hum, h),
            rainCurrent: rainCur,
            runningRain12h: rain12,
            runningSnow12h: snow12,
            dryStreak: dry,
            season: parsed.season,
            windSpeed: at(windS, h),
            windGust: at(windG, h),
            immediateRain: immR,
            immediateSnow: immS,
            surfaceDewSpread: surfaceTemp - dewPoint,
            snowCurrent: snowCur,
        });
        const t = hourly.time[h];
        const wS = at(windS, h), wG = at(windG, h), wD = at(windD, h);
        const dewV = at(dewP, h), humV = at(hum, h);
        out.push({
            time: (typeof t === "number") ? new Date(t * 1000) : null,
            name: r.name,
            level: r.level,
            hazards: r.hazards,
            rain: rainCur,
            snow: snowCur,
            ice: hasIceHazard(r.hazards),
            windSpeed: wS,
            windGust: wG,
            windDir: wD,
            airTemp: airTemp,
            surfaceTemp: surfaceTemp,
            feelsLike: at(feelT, h),
            dewPoint: dewV,
            humidity: humV,
            sun: at(sun, h),
        });
    }
    return out;
}

// Coldest air/surface temps over the coming forecast hours (profile[1..],
// current hour excluded). Returns null when there are no coming hours.
// Used so the popup can explain an ICE-ahead banner even when the current
// hour looks warm.
function forecastLows(profile) {
    if (!profile || profile.length < 2) return null;
    let minAir = null, minSfc = null, minAirTime = null, minSfcTime = null;
    for (let i = 1; i < profile.length; i++) {
        const hh = profile[i];
        if (hh.airTemp !== undefined && hh.airTemp !== null &&
            (minAir === null || hh.airTemp < minAir)) {
            minAir = hh.airTemp;
            minAirTime = hh.time || null;
        }
        if (hh.surfaceTemp !== undefined && hh.surfaceTemp !== null &&
            (minSfc === null || hh.surfaceTemp < minSfc)) {
            minSfc = hh.surfaceTemp;
            minSfcTime = hh.time || null;
        }
    }
    if (minAir === null && minSfc === null) return null;
    return { minAir: minAir, minSfc: minSfc,
             minAirTime: minAirTime, minSfcTime: minSfcTime };
}

function hourLabel(d, isNow) {
    if (isNow) return "now";
    if (!d) return "?";
    const h = d.getHours();
    return (h < 10 ? "0" + h : "" + h) + ":00";
}

// Coming-hours summary for the popup: totals over the forecast hours after
// the current one. Each segment is only shown when relevant, i.e. above 80%
// of its threshold (rain vs precip-ahead, snow vs snow threshold, gust vs the
// lowest wind threshold, max risk vs SLIGHT, ice whenever an ICE hour lands
// in the window). Segments that breach a full warning threshold get a
// warning glyph, so threshold hits stand out even with popup colors off:
//   ❄ ice hours (hazard ICE hour, or surface temp at/below the ice
//     threshold — same rule as the ICE-ahead banner),
//   ⚠ rain when the peak hourly rate reaches the engine HIGH rule (7.5 mm/h),
//   ⚠ snow when the peak hourly rate reaches 0.5 cm/h,
//   ⚠ max when the peak coming risk is HIGH or worse,
//   ⚠ gust when the peak gust reaches the heavy-wind threshold.
// Returns "" when there are no coming hours or nothing is relevant.
function comingSummary(profile, t) {
    if (!profile || profile.length < 2) return "";
    // Thresholds come from _thresholds(); fall back to its defaults when t
    // is missing so the helper stays safe to call standalone.
    const numOr = (v, dflt) => {
        const x = parseNum(v);
        return isNaN(x) ? dflt : x;
    };
    const iceT = numOr(t && t.ice, 3.0);
    const heavyGust = Math.max(numOr(t && t.heavy, 35.0), 1);
    let rain = 0, snow = 0, ice = 0, gust = 0, maxLvl = 0, maxName = "SAFE";
    let maxRainHour = 0, maxSnowHour = 0;
    for (let i = 1; i < profile.length; i++) {
        const hh = profile[i];
        rain += hh.rain || 0;
        snow += hh.snow || 0;
        if (hh.ice || (hh.surfaceTemp !== undefined && hh.surfaceTemp !== null && hh.surfaceTemp <= iceT)) ice++;
        if ((hh.windGust || 0) > gust) gust = hh.windGust;
        if ((hh.level || 0) > maxLvl) { maxLvl = hh.level; maxName = hh.name; }
        if ((hh.rain || 0) > maxRainHour) maxRainHour = hh.rain;
        if ((hh.snow || 0) > maxSnowHour) maxSnowHour = hh.snow;
    }
    const n = profile.length - 1;
    const segs = [];
    const precipGate = Math.max(numOr(t && t.precip, 0.5), 0.01) * 0.8;
    if (maxRainHour >= precipGate) segs.push((maxRainHour >= 7.5 ? "⚠ rain " : "rain ") + rain.toFixed(1) + "mm");
    if (maxSnowHour >= SNOW_THRESHOLD * 0.8) segs.push((maxSnowHour >= 0.5 ? "⚠ snow " : "snow ") + snow.toFixed(1) + "cm");
    if (ice > 0) segs.push("❄ ice " + ice + "h");
    if (maxLvl >= RiskLevel.SLIGHT) segs.push((maxLvl >= RiskLevel.HIGH ? "⚠ max " : "max ") + maxName);
    const windGate = Math.min(
        Math.max(numOr(t && t.crossGust, 18.0), 1), Math.max(numOr(t && t.highCross, 25.0), 1),
        Math.max(numOr(t && t.heavy, 35.0), 1), Math.max(numOr(t && t.sustained, 25.0), 1)) * 0.8;
    if (gust >= windGate) segs.push((gust >= heavyGust ? "⚠ gust " : "gust ") + Math.round(gust));
    if (segs.length === 0) return "";
    return "Next " + n + "h: " + segs.join(" | ");
}

// Highest risk level over the coming forecast hours (profile[1..], i.e.
// without the current hour). Returns null when there are no coming hours,
// otherwise { level, name, time } with the earliest hour at the peak level.
function peakComingRisk(profile) {
    if (!profile || profile.length < 2) return null;
    let best = null;
    for (let i = 1; i < profile.length; i++) {
        const hh = profile[i];
        if (!best || (hh.level || 0) > best.level) {
            best = { level: hh.level || 0, name: hh.name || "SAFE", time: hh.time || null };
        }
    }
    return best;
}

// One-line label for the peak risk, e.g. "Peak next 8h: HIGH @ 14:00".
function peakComingText(profile, peak) {
    if (!peak) return "";
    const n = profile.length - 1;
    let at = "";
    if (peak.time) at = " @ " + hourLabel(peak.time, false);
    return "Peak next " + n + "h: " + peak.name + at;
}

// SVG graph (port of nodetest/graph.js — same layout: risk columns, rain bars,
// gust dots, top W row with blow-to arrow + speed, legend below the hours).
// Pure string building, no Cinnamon dependencies, so node tests cover it.
const GRAPH_FILL = {
    NO_DATA: "#9e9e9e",
    SAFE: "#4caf50",
    SLIGHT: "#ffeb3b",
    MODERATE: "#ffa500",
    HIGH: "#ff4500",
    CRITICAL: "#ff0000",
};
const GRAPH_NUM = { NO_DATA: 0, SAFE: 1, SLIGHT: 2, MODERATE: 3, HIGH: 4, CRITICAL: 5 };

function escXml(s) {
    return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

// Greedy wrap of advice items into at most 2 lines of max chars.
function wrapAdviceLines(items, max) {
    const lines = [];
    let cur = "";
    for (let k = 0; k < items.length; k++) {
        const add = cur ? "; " + items[k] : items[k];
        if (cur && (cur + add).length > max) {
            lines.push(cur);
            cur = items[k];
        } else {
            cur = cur + add;
        }
    }
    if (cur) lines.push(cur);
    if (lines.length > 2) return [lines[0], lines[1] + " …"];
    return lines;
}

// o: { title, subtitle, hours: [{time, name, rain, snow, wind, gust, wdir,
//      sun (sec), temp, dew, humidity, ice}], advice: [...] }.
// Layout: one column per hour, bars close together; rain (blue) + snow
// (pale) as a stacked column from the bottom; a risk-color strip directly
// under each column, then the hour label; overlaid traces: temp = red
// solid, dewpoint = grey solid, sun = yellow solid, wind = white dotted,
// humidity = cyan dashed. ICE hours get a snowflake marker above the
// column plus a cyan outline around the risk strip.
function buildGraphSvg(o) {
    const hours = (o && o.hours) || [];
    const n = hours.length;
    if (n === 0) return "";
    const W = 780, H = 446, padL = 46, padR = 14, padT = 88, padB = 96;
    const plotW = W - padL - padR, plotH = H - padT - padB;
    const base = padT + plotH;
    const slot = plotW / n, barW = Math.min(52, slot * 0.85);
    const stripH = 8, stripY = base + 4, hourY = stripY + stripH + 14;
    let maxRain = 2.0, maxSnow = 1.0, maxWind = 10;
    let tMin = null, tMax = null;
    for (let i = 0; i < n; i++) {
        const hh = hours[i];
        if ((hh.rain || 0) > maxRain) maxRain = hh.rain;
        if ((hh.snow || 0) > maxSnow) maxSnow = hh.snow;
        const g = Math.max(hh.gust || 0, hh.wind || 0);
        if (g > maxWind) maxWind = g;
        const ts = [hh.temp, hh.dew];
        for (let k = 0; k < ts.length; k++) {
            if (ts[k] === null || ts[k] === undefined || isNaN(ts[k])) continue;
            if (tMin === null || ts[k] < tMin) tMin = ts[k];
            if (tMax === null || ts[k] > tMax) tMax = ts[k];
        }
    }
    if (tMin === null) { tMin = 0; tMax = 10; }
    if (tMax - tMin < 5) { const m = (tMax + tMin) / 2; tMin = m - 2.5; tMax = m + 2.5; }
    else { tMin -= 1; tMax += 1; }
    const barMaxH = plotH * 0.55;
    const tempY = (t) => padT + (1 - (t - tMin) / (tMax - tMin)) * plotH;
    const humY = (h) => padT + (1 - Math.max(0, Math.min(100, h || 0)) / 100) * plotH;
    const windY = (w) => padT + (1 - (w || 0) / maxWind) * plotH;
    const sunY = (sec) => padT + (1 - Math.max(0, Math.min(3600, sec || 0)) / 3600) * plotH;
    const cxOf = (i) => padL + slot * i + slot / 2;
    const linePath = (fn) => {
        let d = "";
        for (let i = 0; i < n; i++) {
            const cx = cxOf(i), y = fn(i);
            d += (i === 0 ? "M" : "L") + cx.toFixed(1) + " " + y.toFixed(1);
        }
        return d;
    };
    const hasTemp = hours.some((hh) => hh.temp !== null && hh.temp !== undefined);
    const hasDew = hours.some((hh) => hh.dew !== null && hh.dew !== undefined);
    const hasHum = hours.some((hh) => hh.humidity !== null && hh.humidity !== undefined);
    const hasSun = hours.some((hh) => (hh.sun || 0) > 0);
    let s = "";
    s += '<svg xmlns="http://www.w3.org/2000/svg" width="' + W + '" height="' + H + '" font-family="sans-serif">\n';
    s += '<rect width="' + W + '" height="' + H + '" fill="#111"/>\n';
    s += '<text x="' + padL + '" y="24" fill="#fff" font-size="17" font-weight="bold">' + escXml(o.title || "") + '</text>\n';
    s += '<text x="' + padL + '" y="44" fill="#bbb" font-size="12">' + escXml(o.subtitle || "") + '</text>\n';
    s += '<text x="' + (padL - 5) + '" y="' + (tempY(tMax) + 4).toFixed(1) + '" fill="#999" font-size="10" text-anchor="end">' + tMax.toFixed(0) + '°</text>\n';
    s += '<text x="' + (padL - 5) + '" y="' + (tempY((tMin + tMax) / 2) + 4).toFixed(1) + '" fill="#999" font-size="10" text-anchor="end">' + ((tMin + tMax) / 2).toFixed(0) + '°</text>\n';
    s += '<text x="' + (padL - 5) + '" y="' + (tempY(tMin) + 4).toFixed(1) + '" fill="#999" font-size="10" text-anchor="end">' + tMin.toFixed(0) + '°</text>\n';
    s += '<text x="' + (W - padR) + '" y="' + (padT + 10) + '" fill="#3377ff" font-size="10" text-anchor="end">' + maxRain.toFixed(0) + 'mm</text>\n';
    for (let i = 0; i < n; i++) {
        const cx = cxOf(i);
        const hh = hours[i];
        const rh = ((hh.rain || 0) / maxRain) * barMaxH;
        const sh = ((hh.snow || 0) / maxSnow) * barMaxH * 0.6;
        const x = (cx - barW / 2).toFixed(1);
        if (rh > 0.5) {
            s += '<rect x="' + x + '" y="' + (base - rh).toFixed(1) + '" width="' + barW.toFixed(1) +
                '" height="' + rh.toFixed(1) + '" fill="#3377ff"/>\n';
        }
        if (sh > 0.5) {
            const sy = base - rh - sh;
            s += '<rect x="' + x + '" y="' + sy.toFixed(1) + '" width="' + barW.toFixed(1) +
                '" height="' + sh.toFixed(1) + '" fill="#b3e5fc"/>\n';
        }
        const rc = GRAPH_FILL[hh.name] || GRAPH_FILL.NO_DATA;
        s += '<rect x="' + x + '" y="' + stripY + '" width="' + barW.toFixed(1) + '" height="' + stripH + '" fill="' + rc + '"' +
            (hh.ice ? ' stroke="#4dd0e1" stroke-width="1.5"' : '') + '/>\n';
        s += '<text x="' + cx.toFixed(1) + '" y="' + hourY + '" fill="#999" font-size="10" text-anchor="middle">' + escXml(hourLabel(hh.time, i === 0)) + '</text>\n';
        if ((hh.rain || 0) >= 0.1 || (hh.snow || 0) >= 0.1) {
            let pv = "";
            if ((hh.rain || 0) >= 0.1) pv += (hh.rain).toFixed(1);
            if ((hh.snow || 0) >= 0.1) pv += (pv ? "+" : "") + (hh.snow).toFixed(1) + "s";
            s += '<text x="' + cx.toFixed(1) + '" y="' + (base - rh - sh - 5).toFixed(1) + '" fill="#9ec1ff" font-size="9" text-anchor="middle">' + pv + '</text>\n';
        }
        if (hh.ice) {
            s += '<text x="' + cx.toFixed(1) + '" y="' + (padT - 6) + '" fill="#4dd0e1" font-size="13" text-anchor="middle">❄</text>\n';
        }
        // Top W row: blow-to arrow + speed per hour (same convention as
        // CurrentWindWidget.mc: N wind blows toward the south, shown as ↓).
        // Size mirrors the dart tiers (18/25/35 km/h) so strong wind stands
        // out like on the watch.
        const wdirV = (hh.wdir === undefined || hh.wdir === null) ? hh.windDir : hh.wdir;
        const wArr = (wdirV === undefined || wdirV === null) ? "" : windArrow(wdirV);
        const wSpd = Math.round(hh.wind || 0);
        const wSize = (hh.wind || 0) >= 35 || (hh.gust || 0) >= 45 ? 15 :
            ((hh.wind || 0) >= 25 || (hh.gust || 0) >= 35 ? 13 :
            ((hh.wind || 0) >= 18 ? 12 : 11));
        s += '<text x="' + cx.toFixed(1) + '" y="' + (padT - 28) + '" fill="#fff" font-size="' + wSize + '" text-anchor="middle">' +
            escXml(wArr + wSpd) + '</text>\n';
    }
    if (hasHum) s += '<path d="' + linePath((i) => humY(hours[i].humidity)) + '" fill="none" stroke="#4dd0e1" stroke-width="1.5" stroke-dasharray="6,3"/>\n';
    s += '<path d="' + linePath((i) => windY(Math.max(hours[i].wind || 0, hours[i].gust || 0))) + '" fill="none" stroke="#fff" stroke-width="1.5" stroke-dasharray="2,3"/>\n';
    if (hasSun) s += '<path d="' + linePath((i) => sunY(hours[i].sun)) + '" fill="none" stroke="#ffd24a" stroke-width="2"/>\n';
    if (hasDew) s += '<path d="' + linePath((i) => tempY(hours[i].dew)) + '" fill="none" stroke="#9e9e9e" stroke-width="2"/>\n';
    if (hasTemp) s += '<path d="' + linePath((i) => tempY(hours[i].temp)) + '" fill="none" stroke="#ff5252" stroke-width="2"/>\n';
    const ly1 = hourY + 22;
    s += '<text x="' + padL + '" y="' + ly1 + '" fill="#bbb" font-size="11">' +
        '<tspan fill="#ff5252">— temp</tspan> · <tspan fill="#9e9e9e">— dewpoint</tspan> · ' +
        '<tspan fill="#ffd24a">— sun</tspan> · <tspan fill="#fff">┄ wind</tspan> · ' +
        '<tspan fill="#4dd0e1">┄ humidity</tspan> · <tspan fill="#3377ff">blue = rain mm/h</tspan> · ' +
        '<tspan fill="#b3e5fc">pale = snow cm/h</tspan> · strip = risk · ❄ = ICE · W row = wind arrow + speed</text>\n';
    const advItems = (o.advice && o.advice.length) ? o.advice : ["—"];
    const advLines = wrapAdviceLines(advItems, 100);
    for (let k = 0; k < advLines.length; k++) {
        s += '<text x="' + padL + '" y="' + (ly1 + 15 + k * 13) + '" fill="#888" font-size="10">' +
            (k === 0 ? "advice: " : "") + escXml(advLines[k]) + '</text>\n';
    }
    s += "</svg>\n";
    return s;
}

// Mirrors BackgroundService.mc fetchOpenMeteoData(), plus
// apparent_temperature for the feels-like row. Multiple locations are sent
// as comma-separated latitude/longitude lists so Open-Meteo returns all
// forecasts in one response (a JSON array, one object per coordinate).
function buildUrl(locs) {
    const lats = locs.map((l) => l.lat).join(",");
    const lons = locs.map((l) => l.lon).join(",");
    const q = [
        "latitude=" + encodeURIComponent(lats),
        "longitude=" + encodeURIComponent(lons),
        "hourly=" + encodeURIComponent("temperature_2m,relativehumidity_2m,dewpoint_2m,apparent_temperature,showers,rain,snowfall,precipitation_probability,surface_temperature,wind_speed_10m,wind_gusts_10m,wind_direction_10m,sunshine_duration"),
        "past_hours=12",
        "forecast_hours=12",
        "timezone=auto",
        "timeformat=unixtime",
        "minutely_15=" + encodeURIComponent("rain,snowfall"),
        "forecast_minutely_15=4",
    ].join("&");
    return "https://api.open-meteo.com/v1/forecast?" + q;
}

// One-shot demo forecast: 12 past hours + current + 12 future, with varied
// values so every graph trace moves — warm start, cold snap with ICE hours
// (wet + sub-zero surface), rain turning to snow, gusty wind, sunny midday.
// Returns an Open-Meteo-shaped object so parseResponse()/calculateProfile()
// run the real engine over it. Pure (no Cinnamon deps) for node testing.
function buildDemoResponse(nowSec) {
    const N = 25, startIdx = 12;
    const t0 = nowSec - startIdx * 3600;
    const time = [], air = [], feel = [], sfc = [], dew = [], hum = [],
        rain = [], showers = [], snow = [], prob = [],
        windS = [], windG = [], windD = [], sun = [];
    // Warm afternoon -> evening cold snap -> morning recovery.
    const airProf = [9, 8.5, 7.5, 6.5, 5, 4, 3, 2, 1, 0.5, 0, -0.5, -1,
        -1.5, -2, -2.5, -2, -1, 0, 1, 2.5, 4, 5.5, 7, 8];
    const rainProf = [0, 0, 0.2, 0.8, 2.5, 5, 8, 4, 1.5, 0.4, 0.1, 0, 0,
        0, 0, 0, 0, 0.2, 0.6, 0.3, 0, 0, 0, 0, 0];
    const snowProf = [0, 0, 0, 0, 0, 0, 0, 0.3, 0.8, 1.5, 2, 1.2, 0.6,
        0.3, 0.1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    const windProf = [12, 14, 16, 20, 25, 30, 34, 38, 35, 30, 26, 22, 18,
        16, 14, 12, 11, 12, 14, 16, 15, 13, 12, 11, 10];
    const gustProf = [18, 22, 26, 34, 42, 50, 58, 65, 55, 46, 38, 30, 24,
        22, 20, 18, 16, 18, 22, 24, 22, 20, 18, 16, 14];
    const sunProf = [0, 0, 0, 0, 0, 0, 100, 600, 1500, 2400, 3200, 3600, 3400,
        3000, 2200, 1200, 400, 0, 0, 0, 0, 0, 0, 0, 0];
    for (let i = 0; i < N; i++) {
        time.push(t0 + i * 3600);
        const a = airProf[i % airProf.length];
        air.push(a);
        feel.push(a - 1.5);
        sfc.push(a - 1.0);
        dew.push(a - 0.6);
        hum.push(a <= 1.0 ? 95 : 82);
        rain.push(rainProf[i % rainProf.length]);
        showers.push(0);
        snow.push(snowProf[i % snowProf.length]);
        prob.push((rainProf[i % rainProf.length] > 0.2 || snowProf[i % snowProf.length] > 0.1) ? 80 : 5);
        windS.push(windProf[i % windProf.length]);
        windG.push(gustProf[i % gustProf.length]);
        windD.push((250 + i * 7) % 360);
        sun.push(sunProf[i % sunProf.length]);
    }
    return {
        hourly: {
            time: time, temperature_2m: air, apparent_temperature: feel,
            surface_temperature: sfc, dewpoint_2m: dew,
            relativehumidity_2m: hum, rain: rain, showers: showers,
            snowfall: snow, precipitation_probability: prob,
            wind_speed_10m: windS, wind_gusts_10m: windG,
            wind_direction_10m: windD, sunshine_duration: sun,
        },
        minutely_15: { rain: [0.4, 0.2, 0, 0], snowfall: [0, 0.3, 0.8, 0.5] },
    };
}

// ---------------------------------------------------------------------------
// Applet shell (Cinnamon-specific, thin wrapper around the engine above).
// ---------------------------------------------------------------------------

function SlipperyApplet(metadata, orientation, panelHeight, instanceId) {
    this._init(metadata, orientation, panelHeight, instanceId);
}

SlipperyApplet.prototype = {
    __proto__: Applet.TextApplet.prototype,

    _init: function (metadata, orientation, panelHeight, instanceId) {
        Applet.TextApplet.prototype._init.call(this, orientation, panelHeight, instanceId);

        // Install folder of this applet (for shipped pictures like warning.png).
        this._appletPath = (metadata && metadata.path) ? metadata.path : "";
        this.s = {};
        this.settings = new Settings.AppletSettings(this.s, UUID, instanceId);
        const keys = ["location-1-name", "location-1-coords",
            "location-2-name", "location-2-coords",
            "location-3-name", "location-3-coords",
            "location-4-name", "location-4-coords",
            "location-5-name", "location-5-coords",
            "refresh-minutes", "startup-delay-sec", "forecast-hours",
            "show-temperature", "color-mode", "color-min-level",
            "use-hsp-text", "hsp-threshold",
            "show-advice", "show-peak-risk", "panel-chip-locations",
            "panel-chip-alert-level", "demo-mode",
            "thresh-ice-alert", "thresh-high-crosswind", "thresh-cross-gust",
            "thresh-heavy-wind", "thresh-sustained-wind", "thresh-headwind",
            "thresh-heat-stress", "thresh-precip-ahead"];
        for (let i = 0; i < keys.length; i++) {
            try {
                this.settings.bind(keys[i], keys[i], this._onSettingsChanged.bind(this));
            } catch (e) { /* unknown key on old Cinnamon: ignore */ }
        }

        this.menuManager = new PopupMenu.PopupMenuManager(this);
        this.menu = new Applet.AppletPopupMenu(this, orientation);
        this.menuManager.addMenu(this.menu);

        this._timeoutId = 0;
        this._busy = false;
        this._startupId = 0;
        this._lastResults = null;
        this._chipBox = null;
        this.set_applet_label("…");
        this.set_applet_tooltip("Slippery: fetching Open-Meteo…");
        this._schedule();
        // Fetch right away on (re)load. The extra delayed fetch below only
        // covers login before the network is up (see startup-delay-sec).
        this.refresh();
        const delay = this._startupDelaySec();
        if (delay > 0) {
            this._startupId = Mainloop.timeout_add_seconds(delay, () => {
                this._startupId = 0;
                this.refresh();
                return false;
            });
        }
    },

    _onSettingsChanged: function () {
        if (this._startupId > 0) {
            Mainloop.source_remove(this._startupId);
            this._startupId = 0;
        }
        this._schedule();
        this.refresh();
    },

    _schedule: function () {
        if (this._timeoutId > 0) {
            Mainloop.source_remove(this._timeoutId);
            this._timeoutId = 0;
        }
        let mins = parseInt(this.s["refresh-minutes"], 10);
        if (isNaN(mins) || mins < 5) mins = 15;
        this._timeoutId = Mainloop.timeout_add_seconds(mins * 60, () => {
            this.refresh();
            return true;
        });
    },

    _startupDelaySec: function () {
        let d = parseInt(this.s["startup-delay-sec"], 10);
        if (isNaN(d) || d < 0) d = 0;
        if (d > 300) d = 300;
        return d;
    },

    _forecastHours: function () {
        let h = parseInt(this.s["forecast-hours"], 10);
        if (isNaN(h) || h < 1) h = 12;
        if (h > 12) h = 12;
        return h;
    },

    _thresholds: function () {
        // Mirror SlipperyApp.mc / AlertStateAnalyzer.mc defaults. Only the
        // ice threshold drives the popup (big ICE banner); the rest stay
        // configurable like the Connect IQ app without cluttering the popup.
        const f = (key, dflt) => {
            const v = parseNum(this.s[key]);
            return isNaN(v) ? dflt : v;
        };
        return {
            ice: f("thresh-ice-alert", 3.0),
            highCross: f("thresh-high-crosswind", 25.0),
            crossGust: f("thresh-cross-gust", 18.0),
            heavy: f("thresh-heavy-wind", 35.0),
            sustained: f("thresh-sustained-wind", 25.0),
            head: f("thresh-headwind", 12.0),
            heat: f("thresh-heat-stress", 32.0),
            precip: f("thresh-precip-ahead", 0.5),
        };
    },

    // todo.md: one paste-friendly "lat, lon" field per point (max 5).
    // Empty/invalid coordinates = slot disabled.
    _locations: function () {
        const locs = [];
        for (let n = 1; n <= 5; n++) {
            let nm = String(this.s["location-" + n + "-name"] || "").trim();
            if (!nm) nm = (n === 1) ? "Home" : ("Point " + n);
            const c = parseCoordField(this.s["location-" + n + "-coords"]);
            if (c) locs.push({ name: nm, lat: c.lat, lon: c.lon });
        }
        return locs;
    },

    on_applet_clicked: function () {
        this.menu.toggle();
    },

    on_applet_removed_from_panel: function () {
        if (this._chipBox) {
            try { this._chipBox.destroy(); } catch (e) { /* ignore */ }
            this._chipBox = null;
        }
        if (this._timeoutId > 0) {
            Mainloop.source_remove(this._timeoutId);
            this._timeoutId = 0;
        }
        if (this._startupId > 0) {
            Mainloop.source_remove(this._startupId);
            this._startupId = 0;
        }
        if (this.settings) this.settings.finalize();
    },

    refresh: function () {
        if (this._busy) return;
        const locs = this._locations();
        if (locs.length === 0) {
            this._showError("No valid location: paste lat, lon in settings (e.g. 52.3875, 4.7199).");
            return;
        }
        // Demo switch: one refresh from canned values, then back OFF.
        if (this.s["demo-mode"]) {
            this._busy = true;
            try {
                const demo = buildDemoResponse(Math.floor(Date.now() / 1000));
                const acc = [];
                for (let i = 0; i < locs.length; i++) {
                    let parsed = null;
                    try {
                        parsed = parseResponse(locs[i].lat, demo, Math.floor(Date.now() / 1000));
                    } catch (e) { parsed = null; }
                    acc.push({ loc: locs[i], parsed: parsed,
                               error: parsed ? null : "Demo data error." });
                }
                this._busy = false;
                this._lastResults = acc;
                this._showAll(acc, true);
            } catch (e) {
                this._busy = false;
                this._showError("Demo failed: " + e.message);
            }
            this._disableDemoFlag();
            return;
        }
        this._busy = true;
        this._fetchAll(locs, (results) => {
            this._busy = false;
            this._lastResults = results;
            this._showAll(results);
        });
    },

    // Demo is one-shot: switch the setting back OFF after the demo refresh
    // so the next cycle fetches live data again. Tries the persistent
    // settings API first, falls back to the in-memory copy.
    _disableDemoFlag: function () {
        this.s["demo-mode"] = false;
        const attempts = ["setValue", "set_value", "setBoolean"];
        for (let i = 0; i < attempts.length; i++) {
            try {
                const fn = this.settings && this.settings[attempts[i]];
                if (typeof fn === "function") {
                    if (attempts[i] === "setBoolean") fn.call(this.settings, "demo-mode", false);
                    else fn.call(this.settings, "demo-mode", false);
                    break;
                }
            } catch (e) { /* try next */ }
        }
    },

    // One request for all points: Open-Meteo answers with a JSON array, one
    // forecast object per coordinate (a single location stays a flat object).
    _fetchAll: function (locs, done) {
        const url = buildUrl(locs);
        this._fetchJson(url, (err, data) => {
            if (err) {
                done(locs.map((loc) => ({ loc: loc, parsed: null, error: err })));
                return;
            }
            const parts = Array.isArray(data) ? data : [data];
            const acc = [];
            for (let i = 0; i < locs.length; i++) {
                let parsed = null;
                try {
                    parsed = parseResponse(locs[i].lat, parts[i], Math.floor(Date.now() / 1000));
                } catch (e) {
                    parsed = null;
                }
                acc.push({ loc: locs[i], parsed: parsed,
                           error: parsed ? null : "Empty response from Open-Meteo." });
            }
            done(acc);
        });
    },

    _fetchJson: function (url, cb) {
        let proc;
        try {
            proc = Gio.Subprocess.new(
                ["curl", "-sS", "--max-time", "25", url],
                Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE
            );
        } catch (e) {
            cb("Cannot start curl: " + e.message, null);
            return;
        }
        proc.communicate_utf8_async(null, null, (p, res) => {
            try {
                const [, stdout] = p.communicate_utf8_finish(res);
                cb(null, JSON.parse(stdout));
            } catch (e) {
                cb("Fetch failed: " + e.message, null);
            }
        });
    },

    _showError: function (msg) {
        this.set_applet_label("n/a");
        this.actor.set_style("");
        this.set_applet_tooltip("Slippery: " + msg);
        this.menu.removeAll();
        this.menu.addMenuItem(new PopupMenu.PopupMenuItem("Slippery: " + msg, { reactive: false }));
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        const item = new PopupMenu.PopupMenuItem("Refresh now");
        item.connect("activate", () => this.refresh());
        this.menu.addMenuItem(item);
    },

    // Renders the full-size SVG graph (same layout as nodetest/graph.js) from
    // the already-fetched forecast, writes it to the temp dir and opens it
    // in the default image viewer. No network, no npm, no extra packages.
    _openGraph: function (entry) {
        try {
            if (!entry || !entry.parsed || !entry.profile) return;
            const parsed = entry.parsed;
            const hours = entry.profile.map((h) => ({
                time: h.time, name: h.name,
                rain: h.rain || 0, snow: h.snow || 0,
                wind: h.windSpeed || 0, gust: h.windGust || 0,
                wdir: (h.windDir === undefined) ? null : h.windDir,
                sun: h.sun || 0,
                temp: (h.airTemp === undefined) ? null : h.airTemp,
                dew: (h.dewPoint === undefined) ? null : h.dewPoint,
                humidity: (h.humidity === undefined) ? null : h.humidity,
                ice: !!h.ice,
            }));
            const svg = buildGraphSvg({
                title: entry.loc.name + ": " + parsed.risk.name + " — " +
                    (parsed.risk.hazards.join(" + ") || "No hazards"),
                subtitle: parsed.time.toLocaleString() + " · lat " + entry.loc.lat + ", lon " + entry.loc.lon +
                    " · season " + parsed.season +
                    " · wind " + Math.round(parsed.windSpeed) + " km/h, gust " + Math.round(parsed.windGust) + " km/h",
                hours: hours,
                advice: parsed.risk.advice,
            });
            if (!svg || !ByteArray) return;
            const path = GLib.build_filenamev([GLib.get_tmp_dir(), "slippery-graph.svg"]);
            Gio.File.new_for_path(path).replace_contents(
                ByteArray.fromString(svg), null, false,
                Gio.FileCreateFlags.REPLACE_DESTINATION, null);
            Gio.AppInfo.launch_default_for_uri("file://" + path, null);
        } catch (e) {
            try {
                this.set_applet_tooltip("Slippery: cannot open graph: " + e.message);
            } catch (e2) { /* ignore */ }
        }
    },

    // Picture row in the popup (yes, pictures are possible): a custom
    // PopupBaseMenuItem holding an St.Icon plus bold text. Tries the shipped
    // picture file first (this._appletPath + "/" + fileName, e.g. warning.png),
    // then a stock theme icon, and returns false so the caller can fall back
    // to a plain text row when neither works.
    _addBannerWithIcon: function (text, fileName, stockIcon) {
        if (!St || !PopupMenu.PopupBaseMenuItem) return false;
        let icon = null;
        if (this._appletPath && fileName) {
            try {
                const f = Gio.icon_new_for_string(this._appletPath + "/" + fileName);
                icon = new St.Icon({ gicon: f, icon_size: 28 });
            } catch (e) { icon = null; }
        }
        if (!icon) {
            try {
                icon = new St.Icon({ icon_name: stockIcon || "dialog-warning", icon_size: 24 });
            } catch (e) { return false; }
        }
        if (!icon) return false;
        const item = new PopupMenu.PopupBaseMenuItem({ reactive: false });
        const box = new St.BoxLayout({ style: "spacing: 8px;" });
        box.add_actor(icon);
        box.add_actor(new St.Label({ text: text, style: "font-weight: bold;" }));
        item.addActor(box, { span: -1, expand: true });
        this.menu.addMenuItem(item);
        return true;
    },

    // Colored popup row: the risk background color (same settings as the
    // panel chip: bright/modest palette, color-min-level, HSP text color)
    // behind the location name + risk label. Returns false when St is not
    // available so callers can fall back to a plain text row.
    _addRiskRow: function (text, levelNum, riskName, opts) {
        if (!St) return false;
        const css = chipStyle(opts.colorMode, opts.minLevel, levelNum, riskName,
            opts.useHsp, opts.hspT);
        try {
            const item = new PopupMenu.PopupBaseMenuItem({ reactive: false });
            const box = new St.BoxLayout({ style: css || "" });
            box.add_actor(new St.Label({ text: text }));
            item.addActor(box, { span: -1, expand: true });
            this.menu.addMenuItem(item);
        } catch (e) {
            return false;
        }
        return true;
    },

    // Panel chip in single-point mode: the stock TextApplet label with one
    // risk background on the whole chip. Clears any multi-segment box first.
    _renderChipSingle: function (label, levelNum, riskName, opts) {
        this._clearChipBox();
        this.set_applet_label(label);
        this.actor.set_style(chipStyle(opts.colorMode, opts.minLevel, levelNum,
            riskName, opts.useHsp, opts.hspT));
    },

    _clearChipBox: function () {
        if (this._chipBox) {
            try { this._chipBox.destroy(); } catch (e) { /* ignore */ }
            this._chipBox = null;
        }
        try { if (this._applet_label) this._applet_label.show(); } catch (e) { /* ignore */ }
    },

    // Panel chip in all-points mode: one segment per location, each with its
    // own risk background (e.g. H SAFE|I CRITICAL). Hides the stock label
    // and builds a box of per-segment labels instead. A segment flagged
    // plain:true stays on the theme background (no risk color) — used so a
    // calm first point stays plain next to a critical one. Returns false
    // (caller falls back to the single-point chip) when custom actors fail.
    _renderChipMulti: function (segments, opts) {
        if (!St) return false;
        try {
            this._clearChipBox();
            if (this._applet_label) this._applet_label.hide();
            this.actor.set_style("");
            const box = new St.BoxLayout({ style: "spacing: 0px;" });
            for (let i = 0; i < segments.length; i++) {
                if (i > 0) box.add_actor(new St.Label({ text: "|", style: "padding: 0 1px;" }));
                let css;
                if (segments[i].plain) {
                    css = "padding: 0 4px;";
                } else {
                    css = chipStyle(opts.colorMode, opts.minLevel,
                        segments[i].level, segments[i].name, opts.useHsp, opts.hspT);
                    css += (css && css.charAt(css.length - 1) !== ";" ? ";" : "") + "padding: 0 4px;";
                }
                box.add_actor(new St.Label({ text: segments[i].text, style: css }));
            }
            this.actor.add_actor(box);
            this._chipBox = box;
            return true;
        } catch (e) {
            this._clearChipBox();
            return false;
        }
    },

    // Per-location block: compact status row (extra points only — the
    // primary point's full status is already in the above section), then a
    // graph button labelled with location name + risk level, then the short
    // coming-hours summary (or a calm placeholder so every point has one).
    // A summary whose peak coming risk reaches SLIGHT is highlighted with
    // the risk background color (same settings as the panel chip); the calm
    // placeholder stays plain. Warning glyphs inside the summary text (from
    // comingSummary) carry the alert even when colors are off.
    _addLocationBlock: function (r, idx, th, hours, opts) {
        if (!r.parsed) {
            this.menu.addMenuItem(new PopupMenu.PopupMenuItem(
                r.loc.name + ": " + (r.error || "no data"), { reactive: false }));
            return;
        }
        // if (idx > 0) {
        //     let row = r.loc.name + ": " + (SHORT_LABEL[r.parsed.risk.name] || "?") +
        //         " " + Math.round(r.parsed.airTemp) + "° " +
        //         r.parsed.rainCurrent.toFixed(1) + "mm";
        //     if (r.parsed.snowCurrent >= 0.05) row += "+" + r.parsed.snowCurrent.toFixed(1) + "s";
        //     if (r.iceNow) row = "\u2744 " + row + " ICE";
        //     else if (r.iceAhead) row = row + " (\u2744>)";
        //     const rowOk = this._addRiskRow(row, r.parsed.risk.level, r.parsed.risk.name, opts);
        //     if (!rowOk) {
        //         this.menu.addMenuItem(new PopupMenu.PopupMenuItem(row, { reactive: false }));
        //     }
        // }
        const gi = new PopupMenu.PopupMenuItem(
            r.loc.name + ": " + r.parsed.risk.name + " — Hourly graph");
        gi.connect("activate", ((entry) => () => this._openGraph(entry))(r));
        this.menu.addMenuItem(gi);
        const sum = comingSummary(r.profile, th);
        if (sum) {
            let highlighted = false;
            const peak = peakComingRisk(r.profile);
            if (peak && peak.level >= RiskLevel.SLIGHT) {
                highlighted = this._addRiskRow(sum, peak.level, peak.name, opts);
            }
            if (!highlighted) {
                this.menu.addMenuItem(new PopupMenu.PopupMenuItem(sum, { reactive: false }));
            }
        } else {
            const n = (r.profile && r.profile.length > 1) ? (r.profile.length - 1) : hours;
            this.menu.addMenuItem(new PopupMenu.PopupMenuItem(
                "Next " + n + "h: calm", { reactive: false }));
        }
    },

    _showAll: function (results, isDemo) {
        const primary = results[0];
        if (!primary || !primary.parsed) {
            this._showError(primary && primary.error ? primary.loc.name + ": " + primary.error : "Empty response.");
            return;
        }
        const th = this._thresholds();
        const iceT = th.ice;
        const hours = this._forecastHours();
        const colorMode = String(this.s["color-mode"] || "bright");
        const colorMin = String(this.s["color-min-level"] || "always");
        const useHsp = !!this.s["use-hsp-text"];
        const hspT = this.s["hsp-threshold"];
        // Hazards are always shown (the show-hazards setting was removed).
        const showAdv = this.s["show-advice"] !== false;
        const showPeak = this.s["show-peak-risk"] !== false;

        // Enrich every location: forecast profile + ICE flags.
        let iceAnywhere = false;
        let worstLevel = primary.parsed.risk.level;
        let worstName = primary.parsed.risk.name;
        for (let i = 0; i < results.length; i++) {
            const r = results[i];
            if (!r.parsed) continue;
            r.profile = calculateProfile(r.parsed, hours);
            r.iceNow = hasIceHazard(r.parsed.risk.hazards) || r.parsed.surfaceTemp <= iceT;
            r.iceAhead = false;
            for (let h = 1; h < r.profile.length; h++) {
                // Hazard-based ICE hour, or surface-temp margin (<= ice threshold)
                // in a coming hour — same rule as iceNow, projected forward.
                if (r.profile[h].ice) { r.iceAhead = true; break; }
                const stH = r.profile[h].surfaceTemp;
                if (stH !== undefined && stH !== null && stH <= iceT) { r.iceAhead = true; break; }
            }
            // Fallback for profiles without surface temps (should not happen
            // anymore): scan the raw hourly array directly.
            if (!r.iceAhead && r.profile.length === 0 && r.parsed._data && r.parsed._data.hourly) {
                const st = pickHourly(r.parsed._data.hourly, ["surface_temperature"], 0);
                for (let h = r.parsed._targetIdx + 1;
                     h < Math.min(st.length, r.parsed._targetIdx + 1 + hours); h++) {
                    if (st[h] != null && st[h] <= iceT) { r.iceAhead = true; break; }
                }
            }
            r.lows = forecastLows(r.profile);
            if (r.iceNow || r.iceAhead) iceAnywhere = true;
            if (r.parsed.risk.level > worstLevel) {
                worstLevel = r.parsed.risk.level;
                worstName = r.parsed.risk.name;
            }
        }

        // --- Panel chip (short risk labels: Ok/Low/Mod/Hig/Crt) ---
        // At most two segments, so the chip stays narrow: location 1 plus
        // one more point.
        // "primary" (default): location 1; ICE anywhere prefixes a
        // snowflake. The FIRST other location at/above the alert level
        // (setting panel-chip-alert-level, default HIGH) is appended
        // (H Ok|I Crt): the calm part stays plain, the alert part gets
        // its risk background.
        // "all": location 1 plus the highest-risk point, each with its own
        // risk background, e.g. H Ok|I Crt.
        // With show-peak-risk, segments show the peak of the coming hours.
        const p = primary.parsed;
        const chipMode = String(this.s["panel-chip-locations"] || "primary");
        const chipOpts = { colorMode: colorMode, minLevel: colorMin,
                           useHsp: useHsp, hspT: hspT };
        const chipSegs = [];
        for (let ci = 0; ci < results.length; ci++) {
            const cr = results[ci];
            const initial = ((cr.loc.name || "?").trim().charAt(0) || "?").toUpperCase();
            if (!cr.parsed) {
                chipSegs.push({ text: initial + " n/a", level: RiskLevel.NO_DATA, name: "NO_DATA" });
                continue;
            }
            const pk = showPeak ? peakComingRisk(cr.profile) : null;
            const nm = pk ? pk.name : cr.parsed.risk.name;
            const lv = pk ? pk.level : cr.parsed.risk.level;
            let tx = initial + " " + (SHORT_LABEL[nm] || nm);
            if (this.s["show-temperature"]) tx += " " + Math.round(cr.parsed.airTemp) + "°";
            if (cr.iceNow || cr.iceAhead) tx = "❄ " + tx;
            chipSegs.push({ text: tx, level: lv, name: nm });
        }
        if (chipMode === "all" && chipSegs.length > 0) {
            // Chip shows the 1st point plus the one other point with the
            // highest risk level (first one wins ties) — never every point,
            // so the chip stays narrow enough for the panel.
            const topSegs = [chipSegs[0]];
            let best = -1;
            for (let mi = 1; mi < chipSegs.length; mi++) {
                if (best === -1 || chipSegs[mi].level > chipSegs[best].level) best = mi;
            }
            if (best !== -1) topSegs.push(chipSegs[best]);
            const multiOk = this._renderChipMulti(topSegs, chipOpts);
            if (!multiOk) {
                // Fallback when custom actors fail: joined single label with
                // the worst background.
                const joined = topSegs.map((s) => s.text).join("|");
                this._renderChipSingle(joined, worstLevel, worstName, chipOpts);
            }
        } else {
            // Location 1 plus the FIRST other location at/above the alert
            // level (default HIGH): the calm part stays on the theme
            // background while the alert part gets its risk background
            // (per-part rendering via _renderChipMulti, with a plain
            // single-label fallback carrying the worst background).
            const peakPrimary = showPeak ? peakComingRisk(primary.profile) : null;
            const shownName = peakPrimary ? peakPrimary.name : p.risk.name;
            const shownLevel = peakPrimary ? peakPrimary.level : p.risk.level;
            const locInitial = ((primary.loc.name || "?").trim().charAt(0) || "?").toUpperCase();
            let label = locInitial + " " + (SHORT_LABEL[shownName] || shownName);
            if (this.s["show-temperature"]) label += " " + Math.round(p.airTemp) + "°";
            if (iceAnywhere) label = "❄ " + label;
            let chipLevel = shownLevel, chipName = shownName;
            const alertNeed = chipAlertLevelNum(this.s["panel-chip-alert-level"]);
            let alertIdx = -1;
            for (let ai = 1; ai < chipSegs.length; ai++) {
                if (chipSegs[ai].level >= alertNeed) { alertIdx = ai; break; }
            }
            if (alertIdx === -1) {
                this._renderChipSingle(label, chipLevel, chipName, chipOpts);
            } else {
                // Segment texts carry their own "❄ " prefix when icy;
                // strip it here, the chip-wide marker above already
                // covers ice.
                label += "|" + chipSegs[alertIdx].text.replace(/^❄ /, "");
                if (chipSegs[alertIdx].level > chipLevel) {
                    chipLevel = chipSegs[alertIdx].level;
                    chipName = chipSegs[alertIdx].name;
                }
                const alertSegs = [
                    { text: chipSegs[0].text, level: chipSegs[0].level,
                      name: chipSegs[0].name,
                      plain: chipSegs[0].level < alertNeed },
                    { text: chipSegs[alertIdx].text, level: chipSegs[alertIdx].level,
                      name: chipSegs[alertIdx].name, plain: false },
                ];
                if (!this._renderChipMulti(alertSegs, chipOpts)) {
                    this._renderChipSingle(label, chipLevel, chipName, chipOpts);
                }
            }
        }

        let tip = "Slippery: " + p.risk.name + " @ " + primary.loc.name +
            (p.risk.hazards.length > 0 ? "\n" + p.risk.hazards.join("\n") : "\nNo hazards") +
            "\nWind " + windArrow(p.windDir) + " " + Math.round(p.windSpeed) + " km/h " + compass16(p.windDir) +
            ", gust " + Math.round(p.windGust) + " km/h" +
            " · rain 12h " + p.rain12.toFixed(1) + " mm";
        if (showPeak) {
            const peakPrimary = peakComingRisk(primary.profile);
            if (peakPrimary) tip += "\n" + peakComingText(primary.profile, peakPrimary);
        }
        if (results.length > 1) tip += "\nWorst of " + results.length + " points: " + worstName;
        if (iceAnywhere) tip += "\n\u2744 ICE WARNING — check popup";
        if (isDemo) tip += "\nDEMO values (switch auto-off)";
        // Hover details for extra points (the primary point is detailed
        // above), so the tooltip covers all locations, not just the first.
        // Only points reaching "Show colors only when risk is above" are
        // listed — the same gate as the chip colors. Errors are always
        // shown so a dead point is never silently hidden.
        for (let ti = 1; ti < results.length; ti++) {
            const tr = results[ti];
            if (!tr.parsed) {
                tip += "\n" + tr.loc.name + ": " + (tr.error || "no data");
                continue;
            }
            const tipPeak = showPeak ? peakComingRisk(tr.profile) : null;
            const tipLevel = tipPeak ? tipPeak.level : tr.parsed.risk.level;
            if (!colorPassesMinLevel(colorMin, tipLevel)) continue;
            tip += "\n" + tr.loc.name + ": " + tr.parsed.risk.name +
                " — air " + tr.parsed.airTemp.toFixed(1) + "° sfc " +
                tr.parsed.surfaceTemp.toFixed(1) + "°" +
                " · gust " + Math.round(tr.parsed.windGust) + " km/h" +
                " · rain 12h " + tr.parsed.rain12.toFixed(1) + " mm";
            if (tr.parsed.risk.hazards.length > 0) {
                tip += "\n  " + tr.parsed.risk.hazards.join("; ");
            }
            if (tr.iceNow || tr.iceAhead) tip += " ❄";
        }
        this.set_applet_tooltip(tip);

        // --- Compact popup menu ---
        // Above section: general warning for all locations (ICE banner +
        // per-icy-point temps), then hazards and threshold warnings.
        this.menu.removeAll();

        if (isDemo) {
            this.menu.addMenuItem(new PopupMenu.PopupMenuItem(
                "DEMO values — live data resumes next refresh", { reactive: false }));
            this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        }

        // todo.md: "ICE or ICE coming hours is big warning" — top banner.
        // The banner used to be generic ("now or coming") while the details
        // below only showed the current hour, so a cold forecast hour
        // triggered ICE with no visible low temperature. Now each icy point
        // gets its own temperature explanation row right under the banner.
        if (iceAnywhere) {
            let bannerOk = false;
            try {
                bannerOk = this._addBannerWithIcon("ICE — freezing surface now or coming",
                    "warning.png", "dialog-warning");
            } catch (e) { bannerOk = false; }
            if (!bannerOk) {
                this.menu.addMenuItem(new PopupMenu.PopupMenuItem(
                    "\u2744 ICE — freezing surface now or coming", { reactive: false }));
            }
            for (let i = 0; i < results.length; i++) {
                const r = results[i];
                if (!r.parsed || (!r.iceNow && !r.iceAhead)) continue;
                let line = "\u2744 " + r.loc.name + ": sfc " +
                    r.parsed.surfaceTemp.toFixed(1) + "° · air " +
                    r.parsed.airTemp.toFixed(1) + "°";
                if (r.iceNow) line += " — now";
                if (r.iceAhead && r.lows &&
                    (r.lows.minSfc !== null || r.lows.minAir !== null)) {
                    line += (r.iceNow ? "; " : " → ") + "low sfc " +
                        (r.lows.minSfc !== null ? r.lows.minSfc.toFixed(1) + "°" : "?") +
                        (r.lows.minSfcTime ? " @" + hourLabel(r.lows.minSfcTime, false) : "") +
                        " · air " +
                        (r.lows.minAir !== null ? r.lows.minAir.toFixed(1) + "°" : "?") +
                        (r.lows.minAirTime ? " @" + hourLabel(r.lows.minAirTime, false) : "");
                } else if (r.iceAhead) {
                    line += " → colder coming hours";
                }
                this.menu.addMenuItem(new PopupMenu.PopupMenuItem(line, { reactive: false }));
            }
            this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        }

        const primaryText = primary.loc.name + ": " + p.risk.name + " — " + p.time.toLocaleString();
        const primaryRowOk = this._addRiskRow(primaryText, p.risk.level, p.risk.name,
            { colorMode: colorMode, minLevel: colorMin, useHsp: useHsp, hspT: hspT });
        if (!primaryRowOk) {
            this.menu.addMenuItem(new PopupMenu.PopupMenuItem(primaryText, { reactive: false }));
        }

        p.risk.hazards.forEach((hz) => {
            const iceMark = hasIceHazard([hz]) ? "\u2744 " : "\u26A0 ";
            this.menu.addMenuItem(new PopupMenu.PopupMenuItem(iceMark + hz, { reactive: false }));
        });
        if (showAdv) {
            p.risk.advice.forEach((ad) => {
                this.menu.addMenuItem(new PopupMenu.PopupMenuItem("\u2192 " + ad, { reactive: false }));
            });
        }
        if (p.risk.hazards.length === 0 && (!showAdv || p.risk.advice.length === 0)) {
            this.menu.addMenuItem(new PopupMenu.PopupMenuItem("No hazards — good ride", { reactive: false }));
        }
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        // todo.md: short summary, each group only when relevant (near thresholds).
        // Pass the forecast profile so a warm current hour with a cold night
        // ahead still shows the temperature row (with forecast low).
        const det = relevantDetails(p, th, primary.profile);
        let shownDetail = false;
        if (det.windRow) {
            this.menu.addMenuItem(new PopupMenu.PopupMenuItem(det.windRow, { reactive: false }));
            shownDetail = true;
        }
        if (det.tempRow) {
            this.menu.addMenuItem(new PopupMenu.PopupMenuItem(det.tempRow, { reactive: false }));
            shownDetail = true;
        }
        if (det.precip) {
            let prow = "Rain " + p.rainCurrent.toFixed(1) + " \u00b7 12h " + p.rain12.toFixed(1) + "mm";
            if (p.snowCurrent >= 0.05 || p.snow12 >= SNOW_THRESHOLD) {
                prow += " \u00b7 snow " + p.snowCurrent.toFixed(1) + "/" + p.snow12.toFixed(1) + "cm";
            }
            if (p.immRain === 0) prow += " \u00b7 rain NOW";
            else if (p.immRain > 0) prow += " \u00b7 rain " + p.immRain + "min";
            if (p.immSnow === 0) prow += " \u00b7 snow NOW";
            else if (p.immSnow > 0) prow += " \u00b7 snow " + p.immSnow + "min";
            this.menu.addMenuItem(new PopupMenu.PopupMenuItem(prow, { reactive: false }));
            shownDetail = true;
        }
        if (!shownDetail) {
            this.menu.addMenuItem(new PopupMenu.PopupMenuItem(
                "Details calm \u2014 nothing near thresholds", { reactive: false }));
        }

        // --- Per active location: graph button (name + risk level) -------
        // followed by the short coming-hours summary.
        // (The per-hour rows were removed; the full graph covers them.)
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        this._addLocationBlock(primary, 0, th, hours,
            { colorMode: colorMode, minLevel: colorMin, useHsp: useHsp, hspT: hspT });

        // Remaining points, one block each (results[0] is the primary
        // location shown above, so start at 1).
        if (results.length > 1) {
            for (let i = 1; i < results.length; i++) {
                this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
                this._addLocationBlock(results[i], i, th, hours,
                    { colorMode: colorMode, minLevel: colorMin, useHsp: useHsp, hspT: hspT });
            }
        }

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        const item = new PopupMenu.PopupMenuItem("Refresh now");
        item.connect("activate", () => this.refresh());
        this.menu.addMenuItem(item);
    },
};

function main(metadata, orientation, panelHeight, instanceId) {
    return new SlipperyApplet(metadata, orientation, panelHeight, instanceId);
}
