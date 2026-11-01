/*
 * Slippery — Cinnamon panel applet.
 *
 * Same data + same checks as the Slippery Connect IQ data field:
 *  - Open-Meteo request mirrors source/background/BackgroundService.mc
 *    (hourly vars + apparent_temperature, past_hours=12,
  *     forecast_hours=configurable 1..336h, unixtime, minutely_15)
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

const GRAPH_DAY_BG_DEFAULT = "#1e2733";
const GRAPH_NIGHT_BG_DEFAULT = "#111111";

const RAIN_THRESHOLD = 0.1;
const SNOW_THRESHOLD = 0.1;

const RiskLevel = { NO_DATA: 0, SAFE: 1, SLIGHT: 2, MODERATE: 3, HIGH: 4, CRITICAL: 5 };
const RISK_NAMES = ["NO_DATA", "SAFE", "SLIGHT", "MODERATE", "HIGH", "CRITICAL"];
const SHORT_LABEL = { NO_DATA: "-", SAFE: "Ok", SLIGHT: "Low", MODERATE: "Mod", HIGH: "Hig", CRITICAL: "Crt" };

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

const RISK_TEXT_FIXED = {
    NO_DATA: "#fff",
    SAFE: "#fff",
    SLIGHT: "#000",
    MODERATE: "#000",
    HIGH: "#fff",
    CRITICAL: "#fff",
};

const ICE_HAZARDS = ["Black Ice / Freezing Wet Road", "Road Surface Frost", "Ice On Bridges", "Snow Or Slush Accumulation"];

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

function evaluateRisk(p, iceT) {
    iceT = iceT !== undefined ? iceT : 3.0;
    let riskLevel = RiskLevel.SAFE;
    const hazards = [];
    const advice = [];
    const upgrade = (l) => { if (l > riskLevel) riskLevel = l; };
    const addH = (h) => { if (hazards.indexOf(h) === -1) hazards.push(h); };
    const addA = (a) => { if (advice.indexOf(a) === -1) advice.push(a); };

    if ((p.surfaceTemp <= iceT || p.airTemp <= iceT * 0.5 + 0.5) &&
        (p.runningRain12h >= RAIN_THRESHOLD || p.rainCurrent >= RAIN_THRESHOLD ||
            p.runningSnow12h >= SNOW_THRESHOLD || p.snowCurrent >= SNOW_THRESHOLD)) {
        upgrade(RiskLevel.CRITICAL);
        addH(Hazards.BLACK_ICE); addA(Advice.AVOID_RIDING); addA(Advice.LOWER_TIRE_PRESSURE);
    }
    if (p.surfaceTemp <= iceT && p.surfaceDewSpread <= 2.0 && p.humidity >= 80) {
        upgrade(RiskLevel.CRITICAL);
        addH(Hazards.FROST); addA(Advice.WATCH_SHADED); addA(Advice.AVOID_BRAKING);
    }
    if (p.airTemp >= iceT - 4.0 && p.airTemp <= iceT + 0.5 &&
        (p.runningRain12h >= RAIN_THRESHOLD || p.humidity > 88 || p.runningSnow12h >= SNOW_THRESHOLD)) {
        upgrade(RiskLevel.HIGH);
        addH(Hazards.BRIDGE_ICE); addA(Advice.WATCH_SHADED);
    }
    if (p.runningSnow12h >= SNOW_THRESHOLD && (p.surfaceTemp <= iceT - 3.0 || p.airTemp <= iceT - 1.5)) {
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
        if ((p.upcomingRain || 0) >= 2.5) {
            upgrade(RiskLevel.HIGH);
        } else {
            upgrade(RiskLevel.MODERATE);
        }
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

function hexToRgb(hex) {
    let h = String(hex || "").replace("#", "");
    if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
    if (h.length !== 6) return [0, 0, 0];
    const v = parseInt(h, 16);
    if (isNaN(v)) return [0, 0, 0];
    return [(v >> 16) & 0xff, (v >> 8) & 0xff, v & 0xff];
}

function hasIceInProfile(profile) {
    if (!profile || profile.length === 0) return false;
    for (let i = 0; i < profile.length; i++) {
        if (profile[i] && profile[i].ice) return true;
    }
    return false;
}

function hasIceWithinHours(profile, hours) {
    if (!profile || profile.length === 0 || !hours || hours <= 0) return false;
    const limit = Math.min(profile.length, Math.ceil(hours));
    for (let i = 0; i < limit; i++) {
        if (profile[i] && profile[i].ice) return true;
    }
    return false;
}

function hspOfHex(hex) {
    const c = hexToRgb(hex);
    return Math.sqrt(0.299 * c[0] * c[0] + 0.587 * c[1] * c[1] + 0.114 * c[2] * c[2]);
}

function textColorFor(bgHex, useHsp, threshold, riskName) {
    if (!useHsp) return RISK_TEXT_FIXED[riskName] || "#fff";
    let t = parseFloat(threshold);
    if (isNaN(t) || t < 0 || t > 255) t = 127;
    return hspOfHex(bgHex) > t ? "#000" : "#fff";
}

function chipStyle(colorMode, minLevel, levelNum, riskName, useHsp, hspThreshold, iceChipOpts) {
    if (colorMode === "follow-theme") return "";

    if (iceChipOpts && iceChipOpts.enabled && iceChipOpts.hasIce) {
        const bg = iceChipOpts.color || "#add8e6";
        const fg = textColorFor(bg, useHsp, hspThreshold, riskName);
        const bold = (riskName === "CRITICAL") ? " font-weight: bold;" : "";
        return "background-color: " + bg + "; color: " + fg + ";" + bold;
    }

    if (!colorPassesMinLevel(minLevel, levelNum)) return "";

    const pal = RISK_BG[colorMode] || RISK_BG.bright;
    const bg = pal[riskName] || "";
    if (!bg) return "";
    const fg = textColorFor(bg, useHsp, hspThreshold, riskName);
    const bold = (riskName === "CRITICAL") ? " font-weight: bold;" : "";
    return "background-color: " + bg + "; color: " + fg + ";" + bold;
}

function colorPassesMinLevel(minLevel, levelNum) {
    const m = String(minLevel || "always");
    if (m === "always") return true;
    if (m === "never") return false;
    const need = { slight: 2, moderate: 3, high: 4, critical: 5 }[m];
    if (need === undefined) return true;
    return (levelNum || 0) >= need;
}

function chipAlertLevelNum(v) {
    const need = { slight: 2, moderate: 3, high: 4, critical: 5 }[String(v || "high")];
    return need === undefined ? RiskLevel.HIGH : need;
}

function windArrow(deg) {
    const d = parseFloat(deg);
    if (isNaN(d)) return "?";
    const norm = ((d % 360) + 360) % 360;
    const arrows = ["\u2193", "\u2199", "\u2190", "\u2196", "\u2191", "\u2197", "\u2192", "\u2198"];
    return arrows[Math.round(norm / 45) % 8];
}

function relevantDetails(p, t, profile, u) {
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
        tempRow = "Air " + fmtTemp(p.airTemp, u);
        if (p.hasFeelsLike) tempRow += " (feels " + fmtTemp(p.feelsLike, u) + ")";
        tempRow += " · sfc " + fmtTemp(p.surfaceTemp, u);
        if (lows && coldAhead) {
            tempRow += " → low air " + fmtTemp(lows.minAir, u) +
                (lows.minAirTime ? " (" + fmtRelHours(Date.now(), lows.minAirTime.getTime()) + ")" : "") +
                " · sfc " + fmtTemp(lows.minSfc, u) +
                (lows.minSfcTime ? " (" + fmtRelHours(Date.now(), lows.minSfcTime.getTime()) + ")" : "");
        }
    }
    let windRow = null;
    if (wind) {
        windRow = "Wind " + windArrow(p.windDir) + " " +
            fmtSpeedNum(p.windSpeed, u) + " " + compass16(p.windDir) +
            " (" + Math.round(p.windDir) + "°) · gust " + fmtSpeedNum(p.windGust, u) +
            " " + speedUnit(u);
    }
    return {
        cold: cold, heat: heat, wind: wind,
        precip: precip, tempRow: tempRow, windRow: windRow
    };
}

function compass16(deg) {
    const dirs = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
        "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"];
    let d = parseFloat(deg);
    if (isNaN(d)) return "?";
    d = ((d % 360) + 360) % 360;
    return dirs[Math.round(d / 22.5) % 16];
}

function isImperial(u) { return String(u || "metric") === "imperial"; }
function speedUnit(u) { return isImperial(u) ? "mph" : "km/h"; }

function speedToU(v, u) {
    const x = parseFloat(v);
    if (isNaN(x)) return NaN;
    return isImperial(u) ? x * 0.621371 : x;
}

function fmtSpeedNum(v, u) {
    const x = speedToU(v, u);
    return isNaN(x) ? "?" : String(Math.round(x));
}

function fmtTemp(v, u, dec) {
    const d = (dec === undefined) ? 1 : dec;
    const x = parseFloat(v);
    if (isNaN(x)) return "?";
    if (isImperial(u)) return (x * 9 / 5 + 32).toFixed(d) + "°F";
    return x.toFixed(d) + "°";
}

function fmtTempInt(v, u) {
    const x = parseFloat(v);
    if (isNaN(x)) return "?";
    if (isImperial(u)) return String(Math.round(x * 9 / 5 + 32)) + "°F";
    return String(Math.round(x)) + "°";
}

function fmtRain(v, u) {
    const x = parseFloat(v);
    if (isNaN(x)) return "?";
    if (isImperial(u)) return (x / 25.4).toFixed(2) + "in";
    return x.toFixed(1) + "mm";
}

function fmtSnow(v, u) {
    const x = parseFloat(v);
    if (isNaN(x)) return "?";
    if (isImperial(u)) return (x / 2.54).toFixed(2) + "in";
    return x.toFixed(1) + "cm";
}

function rainRateUnit(u) { return isImperial(u) ? "in/h" : "mm/h"; }
function snowRateUnit(u) { return isImperial(u) ? "in/h" : "cm/h"; }
function tempScaleUnit(u) { return isImperial(u) ? "°F" : "°C"; }
function tempAxisUnit(u) { return isImperial(u) ? "°F" : "°"; }

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
        lat = num(parts[0] + "." + parts[1]);
        lon = num(parts[2] + "." + parts[3]);
    } else {
        return null;
    }
    if (isNaN(lat) || isNaN(lon)) return null;
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;
    return { lat: lat, lon: lon };
}

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
    const nextHourlyRain = at(rain, targetIdx + 1) + at(showers, targetIdx + 1);
    const maxMinutelyRain = (data.minutely_15 && data.minutely_15.rain || []).slice(0, 4).reduce((m, v) => Math.max(m, v || 0), 0);
    const upcomingRain = Math.max(nextHourlyRain, maxMinutelyRain * 4);
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
        upcomingRain: upcomingRain,
        iceT: 3.0,
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
        _data: data,
        _targetIdx: targetIdx,
        _lat: lat,
    };
}

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
    const prob = pickHourly(hourly, ["precipitation_probability"], n);
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
            upcomingRain: h + 1 < n ? at(rain, h + 1) + at(showers, h + 1) : 0,
            iceT: 3.0,
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
            prob: at(prob, h),
        });
    }
    return out;
}

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
    return {
        minAir: minAir, minSfc: minSfc,
        minAirTime: minAirTime, minSfcTime: minSfcTime
    };
}

function hourLabel(d, isNow) {
    if (isNow) return "now";
    if (!d) return "?";
    const h = d.getHours();
    return (h < 10 ? "0" + h : "" + h) + ":00";
}

function dayHourLabel(d) {
    return WD_SHORT[d.getDay()] + "-" + d.getDate() + " " + hourLabel(d, false);
}

function comingSummary(profile, t, u) {
    if (!profile || profile.length < 2) return "";
    const numOr = (v, dflt) => {
        const x = parseNum(v);
        return isNaN(x) ? dflt : x;
    };
    const iceT = numOr(t && t.ice, 3.0);
    const heavyGust = Math.max(numOr(t && t.heavy, 35.0), 1);
    
    let rainTotal = 0, snowTotal = 0, gust = 0, maxLvl = 0, maxName = "SAFE", maxTime = null;
    let maxRainHour = 0, maxSnowHour = 0;
    let firstIceIdx = -1;
    let firstRainIdx = -1;
    let firstSnowIdx = -1;
    let maxLvlIdx = -1;

    for (let i = 1; i < profile.length; i++) {
        const hh = profile[i];
        const r = hh.rain || 0;
        const s = hh.snow || 0;
        const isIce = hh.ice || (hh.surfaceTemp !== undefined && hh.surfaceTemp !== null && hh.surfaceTemp <= iceT);
        
        rainTotal += r;
        snowTotal += s;

        if (isIce && firstIceIdx === -1) firstIceIdx = i;
        if (r >= RAIN_THRESHOLD && firstRainIdx === -1) firstRainIdx = i;
        if (s >= SNOW_THRESHOLD && firstSnowIdx === -1) firstSnowIdx = i;

        if ((hh.windGust || 0) > gust) gust = hh.windGust;
        
        const lvl = hh.level || 0;
        if (lvl > maxLvl) { 
            maxLvl = lvl; 
            maxName = hh.name; 
            maxTime = hh.time || null; 
            maxLvlIdx = i;
        }
        if (r > maxRainHour) maxRainHour = r;
        if (s > maxSnowHour) maxSnowHour = s;
    }

    const n = profile.length - 1;
    const segs = [];
    const precipGate = Math.max(numOr(t && t.precip, 0.5), 0.01) * 0.8;

    // Format time helper relative to now or hours out
    const fmtOnset = (idx) => {
        if (idx === 0) return "now";
        const hh = profile[idx];
        if (hh && hh.time instanceof Date && !isNaN(hh.time)) {
            return fmtRelHours(Date.now(), hh.time.getTime());
        }
        return "in " + idx + "h";
    };

    if (firstIceIdx !== -1) {
        segs.push("❄ ice " + fmtOnset(firstIceIdx));
    }
    if (firstRainIdx !== -1 && rainTotal >= precipGate) {
        segs.push((maxRainHour >= 7.5 ? "⚠ rain " : "rain ") + fmtOnset(firstRainIdx) + " (tot " + fmtRain(rainTotal, u) + ")");
    }
    if (firstSnowIdx !== -1 && snowTotal >= SNOW_THRESHOLD * 0.8) {
        segs.push((maxSnowHour >= 0.5 ? "⚠ snow " : "snow ") + fmtOnset(firstSnowIdx) + " (tot " + fmtSnow(snowTotal, u) + ")");
    }
    if (maxLvl >= RiskLevel.SLIGHT && maxLvlIdx !== -1) {
        let maxSeg = (maxLvl >= RiskLevel.HIGH ? "⚠ max " : "max ") + maxName + " " + fmtOnset(maxLvlIdx);
        segs.push(maxSeg);
    }

    const windGate = Math.min(
        Math.max(numOr(t && t.crossGust, 18.0), 1), Math.max(numOr(t && t.highCross, 25.0), 1),
        Math.max(numOr(t && t.heavy, 35.0), 1), Math.max(numOr(t && t.sustained, 25.0), 1)) * 0.8;
    if (gust >= windGate) {
        segs.push((gust >= heavyGust ? "⚠ gust " : "gust ") + fmtSpeedNum(gust, u) + " " + speedUnit(u));
    }

    if (segs.length === 0) return "";
    return "Next " + n + "h: " + segs.join(" | ");
}

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

function peakComingText(profile, peak) {
    if (!peak) return "";
    const n = profile.length - 1;
    let at = "";
    if (peak.time) at = " (" + fmtRelHours(Date.now(), peak.time.getTime()) + ")";
    return "Peak next " + n + "h: " + peak.name + at;
}

function bestComingHour(profile) {
    if (!profile || profile.length < 2) return null;
    let best = null;
    for (let i = 0; i < profile.length; i++) {
        const hh = profile[i];
        const gust = Math.max(hh.windGust || 0, hh.windSpeed || 0);
        const precip = (hh.rain || 0) + (hh.snow || 0);
        const score = (hh.level || 0) * 10000 + gust * 10 + precip;
        if (!best || score < best.score) {
            best = {
                idx: i, score: score, level: hh.level || 0,
                name: hh.name || "SAFE", time: hh.time || null,
                gust: gust, rain: hh.rain || 0, snow: hh.snow || 0
            };
        }
    }
    return best;
}

function fmtRelHours(fromMs, toMs) {
    const mins = Math.round((toMs - fromMs) / 60000 / 5) * 5;
    if (mins <= 0) return "now";
    const h = Math.floor(mins / 60), m = mins % 60;
    const d = Math.floor(h / 24);
    const remainingH = h % 24;
    if (d > 0) {
        return "in " + d + "d" + (remainingH > 0 ? " " + remainingH + "h" : "") +
            (m > 0 ? " " + m + "min" : "");
    }
    if (remainingH > 0) {
        return "in " + remainingH + "h" + (m > 0 ? " " + m + "min" : "");
    }
    return "in " + m + "min";
}


function fmtHoursToDaysHours(hours) {
    const d = Math.floor(hours / 24);
    const h = hours % 24;
    let s = "";
    if (d > 0) s += d + "d";
    if (h > 0) s += (s ? " " : "") + h + "h";
    return s || "0h";
}

function bestHourText(profile, best, u) {
    if (!best) return "";
    const n = profile.length - 1;
    let at = "now";
    if (best.idx > 0) {
        if (best.time instanceof Date && !isNaN(best.time)) {
            at = "(" + fmtRelHours(Date.now(), best.time.getTime()) + ")";
        } else {
            at = "@ +" + best.idx + "h";
        }
    }
    let s = "Best next " + n + "h: " + best.name + " " + at +
        " · gust " + fmtSpeedNum(best.gust, u) + " " + speedUnit(u);
    if ((best.rain || 0) >= 0.1) s += " · rain " + fmtRain(best.rain, u);
    if ((best.snow || 0) >= 0.1) s += " · snow " + fmtSnow(best.snow, u);
    return s;
}

function groupComingByDay(profile, maxDays) {
    if (!profile || profile.length < 2 || !maxDays || maxDays < 1) return [];
    const WD = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    const groups = [];
    const byKey = {};
    for (let i = 1; i < profile.length; i++) {
        const hh = profile[i];
        let key, label;
        if (hh.time instanceof Date && !isNaN(hh.time)) {
            const d = hh.time;
            key = d.getFullYear() + "-" + d.getMonth() + "-" + d.getDate();
            label = WD[d.getDay()] + " " + d.getDate() + "/" + (d.getMonth() + 1);
        } else {
            const dayIdx = Math.floor((i - 1) / 24);
            key = "chunk-" + dayIdx;
            label = "Day +" + (dayIdx + 1);
        }
        if (!byKey[key]) {
            if (groups.length >= maxDays) break;
            const g = { key: key, label: label, hours: [] };
            byKey[key] = g;
            groups.push(g);
        }
        byKey[key].hours.push(hh);
    }
    return groups.slice(0, maxDays);
}

function summarizeDay(dayHours, iceT) {
    const s = {
        n: dayHours.length, rain: 0, snow: 0, ice: 0, gust: 0,
        maxLvl: 0, maxName: "SAFE", maxTime: null,
        minAir: null, minAirTime: null, minSfc: null, minSfcTime: null,
        maxRainHour: 0, maxSnowHour: 0
    };
    for (let i = 0; i < dayHours.length; i++) {
        const hh = dayHours[i];
        s.rain += hh.rain || 0;
        s.snow += hh.snow || 0;
        if ((hh.rain || 0) > s.maxRainHour) s.maxRainHour = hh.rain;
        if ((hh.snow || 0) > s.maxSnowHour) s.maxSnowHour = hh.snow;
        if (hh.ice || (hh.surfaceTemp !== undefined && hh.surfaceTemp !== null && hh.surfaceTemp <= iceT)) s.ice++;
        if ((hh.windGust || 0) > s.gust) s.gust = hh.windGust;
        if ((hh.level || 0) > s.maxLvl) { s.maxLvl = hh.level; s.maxName = hh.name || "SAFE"; s.maxTime = hh.time || null; }
        if (hh.airTemp !== undefined && hh.airTemp !== null &&
            (s.minAir === null || hh.airTemp < s.minAir)) { s.minAir = hh.airTemp; s.minAirTime = hh.time || null; }
        if (hh.surfaceTemp !== undefined && hh.surfaceTemp !== null &&
            (s.minSfc === null || hh.surfaceTemp < s.minSfc)) { s.minSfc = hh.surfaceTemp; s.minSfcTime = hh.time || null; }
    }
    return s;
}

function formatDailyRow(label, s, t, u) {
    const numOr = (v, dflt) => {
        const x = parseNum(v);
        return isNaN(x) ? dflt : x;
    };
    const precipGate = Math.max(numOr(t && t.precip, 0.5), 0.01) * 0.8;
    const heavyGust = Math.max(numOr(t && t.heavy, 35.0), 1);
    const segs = [];
    segs.push(s.maxLvl >= RiskLevel.HIGH ? "⚠ " + s.maxName : s.maxName);
    if (s.maxRainHour >= precipGate) segs.push((s.maxRainHour >= 7.5 ? "⚠ rain " : "rain ") + fmtRain(s.rain, u));
    if (s.maxSnowHour >= SNOW_THRESHOLD * 0.8) segs.push((s.maxSnowHour >= 0.5 ? "⚠ snow " : "snow ") + fmtSnow(s.snow, u));
    if (s.ice > 0) segs.push("❄ ice " + s.ice + "h");
    const windGate = Math.min(
        Math.max(numOr(t && t.crossGust, 18.0), 1), Math.max(numOr(t && t.highCross, 25.0), 1),
        Math.max(numOr(t && t.heavy, 35.0), 1), Math.max(numOr(t && t.sustained, 25.0), 1)) * 0.8;
    if (s.gust >= windGate) segs.push((s.gust >= heavyGust ? "⚠ gust " : "gust ") + fmtSpeedNum(s.gust, u) + " " + speedUnit(u));
    if (s.minSfc !== null && s.minSfc !== undefined) {
        let low = "low " + fmtTemp(s.minSfc, u) + "sfc";
        if (s.minSfcTime) low += " (" + fmtRelHours(Date.now(), s.minSfcTime.getTime()) + ")";
        segs.push(low);
    } else if (s.minAir !== null && s.minAir !== undefined) {
        let low = "low " + fmtTemp(s.minAir, u);
        if (s.minAirTime) low += " (" + fmtRelHours(Date.now(), s.minAirTime.getTime()) + ")";
        segs.push(low);
    }
    return label + ": " + segs.join(" · ");
}

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

const GRAPH_WD_FULL = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
const WD_SHORT = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

function dayRowLabel(d, mode) {
    const m = String(mode || "date");
    const date = d.getDate() + "/" + (d.getMonth() + 1);
    if (m === "weekday") return GRAPH_WD_FULL[d.getDay()];
    if (m === "both") return GRAPH_WD_FULL[d.getDay()] + " " + date;
    return date;
}

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

function graphIsDay(hh) {
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

function buildGraphSvg(o) {
    const hours = (o && o.hours) || [];
    const n = hours.length;
    if (n === 0) return "";
    const H = 892, padL = 46, padR = 14, padT = 88, padB = 96;
    const MIN_SLOT = 8;
    const W = Math.max(1800, padL + padR + n * MIN_SLOT);
    const plotW = W - padL - padR, plotH = H - padT - padB;
    const base = padT + plotH;
    const slot = plotW / n, barW = Math.min(52, slot * 0.85);
    const stripH = 8, stripY = base + 4, hourY = stripY + stripH + 14, dayY = hourY + 12;
    let maxRain = 2.0, maxSnow = 1.0, maxWind = 10;
    let tMin = null, tMax = null;
    for (let i = 0; i < n; i++) {
        const hh = hours[i];
        if ((hh.rain || 0) > maxRain) maxRain = hh.rain;
        if ((hh.snow || 0) > maxSnow) maxSnow = hh.snow;
        const g = Math.max(hh.gust || 0, hh.wind || 0);
        if (g > maxWind) maxWind = g;
        const ts = [hh.temp, hh.dew, hh.sfc];
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
    const probY = (p) => padT + (1 - Math.max(0, Math.min(100, p || 0)) / 100) * plotH;
    const windY = (w) => padT + (1 - (w || 0) / maxWind) * plotH;
    const windMarkY = (i) => Math.max(16, windY(Math.max(hours[i].wind || 0, hours[i].gust || 0)) - 16);
    const sunY = (sec) => padT + (1 - Math.max(0, Math.min(3600, sec || 0)) / 3600) * plotH;
    const cxOf = (i) => padL + slot * i + slot / 2;
    let iceStartIdx = -1;
    for (let fi = 0; fi < n; fi++) {
        if (hours[fi] && hours[fi].ice) { iceStartIdx = fi; break; }
    }
    const iceStartLabel = () => {
        if (iceStartIdx < 0) return "";
        if (iceStartIdx === 0) return "❄ ICE now";
        const d = Math.floor(iceStartIdx / 24);
        const h = iceStartIdx % 24;
        if (d > 0) {
            return "❄ ice in " + d + "d" + (h > 0 ? " " + h + "h" : "");
        }
        return "❄ ice in " + iceStartIdx + "h";
    };
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
    const hasSfc = hours.some((hh) => hh.sfc !== null && hh.sfc !== undefined);
    const hasHum = hours.some((hh) => hh.humidity !== null && hh.humidity !== undefined);
    const hasSun = hours.some((hh) => (hh.sun || 0) > 0);
    const hasProb = hours.some((hh) => hh.prob !== null && hh.prob !== undefined && !isNaN(hh.prob));
    const PROB_COLOR = "#5b9bff";
    const SFC_COLOR = "#ffa040";
    const tro = (o && o.traces) || {};
    const drawTemp = hasTemp && tro.temp !== false;
    const drawDew = hasDew && tro.dew !== false;
    const drawSfc = hasSfc && tro.sfc !== false;
    const drawSun = hasSun && tro.sun !== false;
    const drawWind = tro.wind !== false;
    const drawHum = hasHum && tro.hum !== false;
    const drawProb = hasProb && tro.prob !== false;
    const drawPrecip = tro.precip !== false;
    const valuesMode = String((o && o.values) || "all");
    const showVals = valuesMode !== "none";
    const peakVals = valuesMode === "peak" || valuesMode === "peak-day";
    const dailyPeakVals = valuesMode === "peak-day";
    const alternateVals = valuesMode === "alternate";
    const dayMode = String((o && o.dayLabels) || "date");
    const dayKeyOf = (idx) => {
        const t = hours[idx] && hours[idx].time;
        if (t instanceof Date && !isNaN(t)) {
            return t.getFullYear() + "-" + t.getMonth() + "-" + t.getDate();
        }
        return "all";
    };
    let peakWindIdx = -1, peakRainIdx = -1, peakSnowIdx = -1;
    let minTempIdx = -1, minSfcIdx = -1;
    const numOrNull = (v) => (v === null || v === undefined || isNaN(v)) ? null : v;
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
        const perDay = {};
        const newDay = () => ({
            wMax: -1, wMaxIdx: -1, wMin: null, wMinIdx: -1,
            pr: -1, prIdx: -1, ps: -1, psIdx: -1,
            tMax: null, tMaxIdx: -1, tMin: null, tMinIdx: -1,
            fMax: null, fMaxIdx: -1, fMin: null, fMinIdx: -1,
            dMax: null, dMaxIdx: -1, dMin: null, dMinIdx: -1,
            sunMax: -1, sunMaxIdx: -1, sunMin: null, sunMinIdx: -1,
            hMax: null, hMaxIdx: -1, hMin: null, hMinIdx: -1,
            pMax: null, pMaxIdx: -1, pMin: null, pMinIdx: -1
        });
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
        const keys = Object.keys(perDay);
        for (let k = 0; k < keys.length; k++) {
            const d = perDay[keys[k]];
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
    const dn = (o && o.dayNight) || {};
    const dnEnabled = dn.enabled === undefined || dn.enabled === null ? true : !!dn.enabled;
    const dayBg = (typeof dn.dayBg === "string" && dn.dayBg) ? dn.dayBg : "#1e2733";
    const nightBg = (typeof dn.nightBg === "string" && dn.nightBg) ? dn.nightBg : "#111111";
    const u = (o && o.units) || "metric";
    const axTemp = (v) => {
        const x = isImperial(u) ? v * 9 / 5 + 32 : v;
        return x.toFixed(0) + tempAxisUnit(u);
    };
    const axRainMax = isImperial(u) ? (maxRain / 25.4).toFixed(2) + "in" : maxRain.toFixed(0) + "mm";
    let s = "";
    s += '<svg xmlns="http://www.w3.org/2000/svg" width="' + W + '" height="' + H + '" font-family="sans-serif">\n';
    s += '<rect width="' + W + '" height="' + H + '" fill="' + escXml(dayBg) + '"/>\n';
    if (dnEnabled) {
        for (let bi = 0; bi < n; bi++) {
            if (!graphIsDay(hours[bi])) {
                const bx = (padL + slot * bi).toFixed(1);
                s += '<rect x="' + bx + '" y="' + padT + '" width="' + slot.toFixed(1) +
                    '" height="' + plotH + '" fill="' + escXml(nightBg) + '"/>\n';
            }
        }
    }
    s += '<text x="' + padL + '" y="24" fill="#fff" font-size="17" font-weight="bold">' + escXml(o.title || "") + '</text>\n';
    s += '<text x="' + padL + '" y="44" fill="#bbb" font-size="12">' + escXml(o.subtitle || "") + '</text>\n';
    s += '<text x="' + (padL - 5) + '" y="' + (tempY(tMax) + 4).toFixed(1) + '" fill="#999" font-size="10" text-anchor="end">' + axTemp(tMax) + '</text>\n';
    s += '<text x="' + (padL - 5) + '" y="' + (tempY((tMin + tMax) / 2) + 4).toFixed(1) + '" fill="#999" font-size="10" text-anchor="end">' + axTemp((tMin + tMax) / 2) + '</text>\n';
    s += '<text x="' + (padL - 5) + '" y="' + (tempY(tMin) + 4).toFixed(1) + '" fill="#999" font-size="10" text-anchor="end">' + axTemp(tMin) + '</text>\n';
    s += '<text x="' + (W - padR) + '" y="' + (padT + 10) + '" fill="#3377ff" font-size="10" text-anchor="end">' + axRainMax + '</text>\n';
    if (drawHum || drawProb) {
        s += '<text x="' + (W - padR) + '" y="' + (humY(50) + 4).toFixed(1) + '" fill="' + PROB_COLOR + '" font-size="10" text-anchor="end">50%</text>\n';
        s += '<text x="' + (W - padR) + '" y="' + (humY(0) + 4).toFixed(1) + '" fill="' + PROB_COLOR + '" font-size="10" text-anchor="end">0%</text>\n';
    }
    const isNewDayAt = function (idx) {
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
    const collidesShown = function (idx) {
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
    const isShownLabel = function (idx) {
        for (let c = 0; c < shownList.length; c++) {
            if (shownList[c] === idx) return true;
        }
        return false;
    };
    for (let i = 0; i < n; i++) {
        const cx = cxOf(i);
        const hh = hours[i];
        const rh = ((hh.rain || 0) / maxRain) * barMaxH;
        const sh = ((hh.snow || 0) / maxSnow) * barMaxH * 0.6;
        const x = (cx - barW / 2).toFixed(1);
        if (drawPrecip && rh > 0.5) {
            s += '<rect x="' + x + '" y="' + (base - rh).toFixed(1) + '" width="' + barW.toFixed(1) +
                '" height="' + rh.toFixed(1) + '" fill="#3377ff"/>\n';
        }
        if (drawPrecip && sh > 0.5) {
            const sy = base - rh - sh;
            s += '<rect x="' + x + '" y="' + sy.toFixed(1) + '" width="' + barW.toFixed(1) +
                '" height="' + sh.toFixed(1) + '" fill="#b3e5fc"/>\n';
        }
        const rc = GRAPH_FILL[hh.name] || GRAPH_FILL.NO_DATA;
        const isIceStart = (i === iceStartIdx);
        s += '<rect x="' + x + '" y="' + stripY + '" width="' + barW.toFixed(1) + '" height="' + stripH + '" fill="' + rc + '"' +
            (hh.ice ? ' stroke="#4dd0e1" stroke-width="' + (isIceStart ? "2.5" : "1.5") + '"' : '') + '/>\n';
        const isNewDay = isNewDayAt(i);
        if (isNewDay) {
            const sepX = (cx - slot / 2).toFixed(1);
            s += '<line x1="' + sepX + '" y1="' + padT + '" x2="' + sepX + '" y2="' + base + '" stroke="#555" stroke-width="1" stroke-dasharray="4,3"/>\n';
        }
        if (isIceStart && iceStartIdx > 0) {
            const ix = (cx - slot / 2).toFixed(1);
            s += '<line x1="' + ix + '" y1="' + padT + '" x2="' + ix + '" y2="' + base + '" stroke="#4dd0e1" stroke-width="2" stroke-dasharray="6,3"/>\n';
        }
        const showLabel = isShownLabel(i);
        if (showLabel) {
            s += '<line x1="' + cx.toFixed(1) + '" y1="' + (stripY + stripH) + '" x2="' + cx.toFixed(1) + '" y2="' + (hourY - 3) + '" stroke="#888" stroke-width="1"/>\n';
        }
        s += '<text x="' + cx.toFixed(1) + '" y="' + hourY + '" fill="#999" font-size="10" text-anchor="middle">' + (showLabel ? escXml(hourLabel(hh.time, i === 0)) : "") + '</text>\n';
        if (showVals && drawPrecip && ((hh.rain || 0) >= 0.1 || (hh.snow || 0) >= 0.1)) {
            let pv = "";
            if ((hh.rain || 0) >= 0.1 && (!peakVals ? (!alternateVals || i % 2 === 0) : peakRainSet[i])) pv += isImperial(u) ? (hh.rain / 25.4).toFixed(2) : (hh.rain).toFixed(1);
            if ((hh.snow || 0) >= 0.1 && (!peakVals ? (!alternateVals || i % 2 === 0) : peakSnowSet[i])) pv += (pv ? "+" : "") + (isImperial(u) ? (hh.snow / 2.54).toFixed(2) : (hh.snow).toFixed(1)) + "s";
            if (pv) s += '<text x="' + cx.toFixed(1) + '" y="' + (base - rh - sh - 5).toFixed(1) + '" fill="#9ec1ff" font-size="9" text-anchor="middle">' + pv + '</text>\n';
        }
        if (hh.ice) {
            s += '<text x="' + cx.toFixed(1) + '" y="' + (padT - 6) + '" fill="#4dd0e1" font-size="13" text-anchor="middle">❄</text>\n';
        }
        if (drawWind && showVals && (peakVals ? (peakWindSet[i] || minWindSet[i]) : (!alternateVals || i % 2 === 0))) {
            const wdirV = (hh.wdir === undefined || hh.wdir === null) ? hh.windDir : hh.wdir;
            const wArr = (wdirV === undefined || wdirV === null) ? "" : windArrow(wdirV);
            const wSpd = fmtSpeedNum(hh.wind || 0, u);
            const wSize = (hh.wind || 0) >= 35 || (hh.gust || 0) >= 45 ? 15 :
                ((hh.wind || 0) >= 25 || (hh.gust || 0) >= 35 ? 13 :
                    ((hh.wind || 0) >= 18 ? 12 : 11));
            const wY = windMarkY(i);
            s += '<text x="' + cx.toFixed(1) + '" y="' + wY.toFixed(1) + '" fill="#fff" font-size="' + wSize + '" text-anchor="middle" stroke="#000" stroke-opacity="0.7" stroke-width="3" paint-order="stroke">' +
                escXml(wArr + wSpd) + '</text>\n';
        }
    }
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
            daySegs.push({ key: key, start: di, end: di, time: valid });
        }
    }
    for (let si = 0; si < daySegs.length; si++) {
        const seg = daySegs[si];
        if (!seg.time) continue;
        const cx = (cxOf(seg.start) + cxOf(seg.end)) / 2;
        let iceMark = "";
        for (let hi = seg.start; hi <= seg.end; hi++) {
            if (hours[hi] && hours[hi].ice) {
                iceMark = "❄";
                break;
            }
        }
        s += '<text x="' + cx.toFixed(1) + '" y="' + dayY + '" fill="#fff" font-size="10" text-anchor="middle" font-weight="bold">' +
            iceMark + " " + escXml(dayRowLabel(seg.time, dayMode)) + '</text>\n';
    }
    if (iceStartIdx >= 0) {
        const iceCx = cxOf(iceStartIdx);
        const iceTx = Math.min(Math.max(iceCx, padL + 80), W - padR - 80);
        s += '<text x="' + iceTx.toFixed(1) + '" y="' + (padT - 26) + '" fill="#4dd0e1" font-size="13" font-weight="bold" text-anchor="middle" stroke="#000" stroke-opacity="0.7" stroke-width="3" paint-order="stroke">' +
            escXml(iceStartLabel()) + '</text>\n';
    }
    if (drawHum) s += '<path d="' + linePath((i) => humY(hours[i].humidity)) + '" fill="none" stroke="#4dd0e1" stroke-width="1.5" stroke-dasharray="6,3"/>\n';
    if (drawProb) s += '<path d="' + linePath((i) => probY(hours[i].prob)) + '" fill="none" stroke="' + PROB_COLOR + '" stroke-width="1.5" stroke-dasharray="1,3" stroke-linecap="round"/>\n';
    if (drawWind) s += '<path d="' + linePath((i) => windY(Math.max(hours[i].wind || 0, hours[i].gust || 0))) + '" fill="none" stroke="#fff" stroke-width="1.5" stroke-dasharray="2,3"/>\n';
    if (drawSun) s += '<path d="' + linePath((i) => sunY(hours[i].sun)) + '" fill="none" stroke="#ffd24a" stroke-width="2"/>\n';
    if (drawDew) s += '<path d="' + linePath((i) => tempY(hours[i].dew)) + '" fill="none" stroke="#9e9e9e" stroke-width="2"/>\n';
    if (drawSfc) s += '<path d="' + linePath((i) => tempY(hours[i].sfc)) + '" fill="none" stroke="' + SFC_COLOR + '" stroke-width="2"/>\n';
    if (drawTemp) s += '<path d="' + linePath((i) => tempY(hours[i].temp)) + '" fill="none" stroke="#ff5252" stroke-width="2"/>\n';
    if (peakVals && showVals) {
        const clampY = (y) => Math.min(Math.max(y, 12), base - 2);
        const extLabel = (idx, y, color, size, txt) => {
            s += '<text x="' + cxOf(idx).toFixed(1) + '" y="' + clampY(y).toFixed(1) + '" fill="' + color + '" font-size="' + size + '" font-weight="bold" text-anchor="middle" stroke="#000" stroke-opacity="0.7" stroke-width="3" paint-order="stroke">' +
                escXml(txt) + '</text>\n';
        };
        const fmtPct = (v) => String(Math.round(v)) + "%";
        const fmtSun = (v) => String(Math.round(v / 60)) + "m";
        const extDefs = [
            {
                set: maxTempSet, color: "#ff5252", size: 11, dy: -8, need: drawTemp,
                yOf: (ii) => tempY(hours[ii].temp), vOf: (ii) => hours[ii].temp, f: (vv) => fmtTemp(vv, u)
            },
            {
                set: minTempSet, color: "#ff5252", size: 11, dy: -8, need: drawTemp,
                yOf: (ii) => tempY(hours[ii].temp), vOf: (ii) => hours[ii].temp, f: (vv) => fmtTemp(vv, u)
            },
            {
                set: maxSfcSet, color: SFC_COLOR, size: 11, dy: 14, need: drawSfc,
                yOf: (ii) => tempY(hours[ii].sfc), vOf: (ii) => hours[ii].sfc, f: (vv) => fmtTemp(vv, u)
            },
            {
                set: minSfcSet, color: SFC_COLOR, size: 11, dy: 14, need: drawSfc,
                yOf: (ii) => tempY(hours[ii].sfc), vOf: (ii) => hours[ii].sfc, f: (vv) => fmtTemp(vv, u)
            },
            {
                set: maxDewSet, color: "#9e9e9e", size: 10, dy: -20, need: drawDew,
                yOf: (ii) => tempY(hours[ii].dew), vOf: (ii) => hours[ii].dew, f: (vv) => fmtTemp(vv, u)
            },
            {
                set: minDewSet, color: "#9e9e9e", size: 10, dy: 26, need: drawDew,
                yOf: (ii) => tempY(hours[ii].dew), vOf: (ii) => hours[ii].dew, f: (vv) => fmtTemp(vv, u)
            },
            {
                set: maxSunSet, color: "#ffd24a", size: 10, dy: -8, need: drawSun,
                yOf: (ii) => sunY(hours[ii].sun), vOf: (ii) => hours[ii].sun, f: (vv) => fmtSun(vv)
            },
            {
                set: minSunSet, color: "#ffd24a", size: 10, dy: 14, need: drawSun,
                yOf: (ii) => sunY(hours[ii].sun), vOf: (ii) => hours[ii].sun, f: (vv) => fmtSun(vv)
            },
            {
                set: maxHumSet, color: "#4dd0e1", size: 10, dy: -8, need: drawHum,
                yOf: (ii) => humY(hours[ii].humidity), vOf: (ii) => hours[ii].humidity, f: (vv) => fmtPct(vv)
            },
            {
                set: minHumSet, color: "#4dd0e1", size: 10, dy: 14, need: drawHum,
                yOf: (ii) => humY(hours[ii].humidity), vOf: (ii) => hours[ii].humidity, f: (vv) => fmtPct(vv)
            },
            {
                set: maxProbSet, color: PROB_COLOR, size: 10, dy: -20, need: drawProb,
                yOf: (ii) => probY(hours[ii].prob), vOf: (ii) => hours[ii].prob, f: (vv) => fmtPct(vv)
            },
            {
                set: minProbSet, color: PROB_COLOR, size: 10, dy: 26, need: drawProb,
                yOf: (ii) => probY(hours[ii].prob), vOf: (ii) => hours[ii].prob, f: (vv) => fmtPct(vv)
            },
        ];
        for (let di = 0; di < extDefs.length; di++) {
            const D = extDefs[di];
            if (!D.need) continue;
            for (let ei = 0; ei < n; ei++) {
                if (!D.set[ei]) continue;
                const vv = D.vOf(ei);
                if (vv === null || vv === undefined || isNaN(vv)) continue;
                extLabel(ei, D.yOf(ei) + D.dy, D.color, D.size, D.f(vv));
            }
        }
    }
    const ly1 = hourY + 28;
    const traceSegs = [];
    if (drawTemp) traceSegs.push('<tspan fill="#ff5252">— temp air ' + tempScaleUnit(u) + '</tspan>');
    if (drawSfc) traceSegs.push('<tspan fill="' + SFC_COLOR + '">— temp sfc ' + tempScaleUnit(u) + '</tspan>');
    if (drawDew) traceSegs.push('<tspan fill="#9e9e9e">— dewpoint</tspan>');
    if (drawSun) traceSegs.push('<tspan fill="#ffd24a">— sun</tspan>');
    if (drawWind) traceSegs.push('<tspan fill="#fff">┄ wind+gust max (' + speedUnit(u) + ')</tspan>');
    if (drawHum) traceSegs.push('<tspan fill="#4dd0e1">┄ humidity %</tspan>');
    if (drawProb) traceSegs.push('<tspan fill="' + PROB_COLOR + '">… precip prob %</tspan>');
    s += '<text x="' + padL + '" y="' + ly1 + '" fill="#bbb" font-size="11">' +
        traceSegs.join(' · ') +
        '<tspan fill="#bbb"> (left ' + tempScaleUnit(u) + ' temp scale · right % humidity/prob scale)</tspan></text>\n';
    const colSegs = [];
    if (drawPrecip) {
        colSegs.push('<tspan fill="#3377ff">blue column = rain ' + rainRateUnit(u) + '</tspan>');
        colSegs.push('<tspan fill="#b3e5fc">pale column = snow ' + snowRateUnit(u) + '</tspan>');
    }
    colSegs.push('strip = risk level');
    colSegs.push('❄ = ICE hour + cyan strip outline');
    if (drawWind && showVals) colSegs.push('wind markers ride dotted line (higher = stronger)');
    if (peakVals && showVals) colSegs.push(dailyPeakVals ? 'max + min labeled per day' : 'max + min labeled');
    if (dnEnabled) colSegs.push('<tspan fill="#8fa3bf">shaded = night</tspan>');
    const ly2 = ly1 + 14;
    s += '<text x="' + padL + '" y="' + ly2 + '" fill="#bbb" font-size="11">' +
        colSegs.join(' · ') + '</text>\n';
    const advItems = (o.advice && o.advice.length) ? o.advice : ["—"];
    const advLines = wrapAdviceLines(advItems, 100);
    for (let k = 0; k < advLines.length; k++) {
        s += '<text x="' + padL + '" y="' + (ly2 + 15 + k * 13) + '" fill="#888" font-size="10">' +
            (k === 0 ? "advice: " : "") + escXml(advLines[k]) + '</text>\n';
    }
    s += "</svg>\n";
    return s;
}

function buildUrl(locs, forecastHours) {
    const lats = locs.map((l) => l.lat).join(",");
    const lons = locs.map((l) => l.lon).join(",");
    let fh = parseInt(forecastHours, 10);
    if (isNaN(fh) || fh < 1) fh = 12;
    if (fh > 336) fh = 336;
    const q = [
        "latitude=" + encodeURIComponent(lats),
        "longitude=" + encodeURIComponent(lons),
        "hourly=" + encodeURIComponent("temperature_2m,relativehumidity_2m,dewpoint_2m,apparent_temperature,showers,rain,snowfall,precipitation_probability,surface_temperature,wind_speed_10m,wind_gusts_10m,wind_direction_10m,sunshine_duration"),
        "past_hours=12",
        "forecast_hours=" + fh,
        "timezone=auto",
        "timeformat=unixtime",
        "minutely_15=" + encodeURIComponent("rain,snowfall"),
        "forecast_minutely_15=4",
    ].join("&");
    return "https://api.open-meteo.com/v1/forecast?" + q;
}

// ---------------------------------------------------------------------------
// Applet shell
// ---------------------------------------------------------------------------

function SlipperyApplet(metadata, orientation, panelHeight, instanceId) {
    this._init(metadata, orientation, panelHeight, instanceId);
}

SlipperyApplet.prototype = {
    __proto__: Applet.TextApplet.prototype,

    _init: function (metadata, orientation, panelHeight, instanceId) {
        Applet.TextApplet.prototype._init.call(this, orientation, panelHeight, instanceId);

        this._appletPath = (metadata && metadata.path) ? metadata.path : "";
        this.s = {};
        this.settings = new Settings.AppletSettings(this.s, UUID, instanceId);
        const keys = ["location-1-name", "location-1-coords",
            "location-2-name", "location-2-coords", "location-2-enabled",
            "location-3-name", "location-3-coords", "location-3-enabled",
            "location-4-name", "location-4-coords", "location-4-enabled",
            "location-5-name", "location-5-coords", "location-5-enabled",
            "refresh-minutes", "startup-delay-sec", "forecast-hours",
            "forecast-days", "units",
            "show-temperature", "color-mode", "color-min-level",
            "use-hsp-text", "hsp-threshold",
            "popup-display-mode", "show-advice", "compact-advice", "show-details",
            "show-peak-risk", "panel-chip-locations",
            "panel-chip-alert-level", "panel-alert-mon", "panel-alert-tue",
            "panel-alert-wed", "panel-alert-thu", "panel-alert-fri",
            "panel-alert-sat", "panel-alert-sun", "panel-alert-current-day",
            "show-best-hour", "hide-calm-days",
            "ice-chip-enabled", "ice-chip-hours", "ice-chip-color", "ice-chip-color-reset",
            "graph-daynight", "graph-day-bg", "graph-night-bg",
            "graph-colors-reset", "graph-day-labels",
            "graph-show-temp", "graph-show-surface", "graph-show-dew",
            "graph-show-sun", "graph-show-wind", "graph-show-humidity",
            "graph-show-prob", "graph-show-precip", "graph-values",
            "thresh-ice-alert", "thresh-high-crosswind", "thresh-cross-gust",
            "thresh-heavy-wind", "thresh-sustained-wind", "thresh-headwind",
            "thresh-heat-stress", "thresh-precip-ahead"];
        for (let i = 0; i < keys.length; i++) {
            try {
                this.settings.bind(keys[i], keys[i], this._onSettingsChanged.bind(this));
            } catch (e) { /* ignore */ }
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
        if (h > 336) h = 336;
        return h;
    },

    _forecastDays: function () {
        let d = parseInt(this.s["forecast-days"], 10);
        if (isNaN(d) || d < 0) d = 0;
        if (d > 14) d = 14;
        return d;
    },

    _fetchHours: function () {
        const h = this._forecastHours();
        const d = this._forecastDays();
        return Math.min(336, Math.max(h, d * 24));
    },

    _thresholds: function () {
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

    _locations: function () {
        const locs = [];
        for (let n = 1; n <= 5; n++) {
            if (n > 1 && this.s["location-" + n + "-enabled"] === false) continue;
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
        this._maybeResetGraphColors();
        this._maybeResetIceChipColor();
        const locs = this._locations();
        if (locs.length === 0) {
            this._showError("No valid location: paste lat, lon in settings (e.g. 52.3875, 4.7199).");
            return;
        }
        this._busy = true;
        this._fetchAll(locs, (results) => {
            this._busy = false;
            this._lastResults = results;
            this._showAll(results);
        });
    },

    _persistSetting: function (key, value) {
        this.s[key] = value;
        const attempts = ["setValue", "set_value", "setString", "set_string", "setBoolean"];
        for (let i = 0; i < attempts.length; i++) {
            try {
                const fn = this.settings && this.settings[attempts[i]];
                if (typeof fn === "function") {
                    fn.call(this.settings, key, value);
                    break;
                }
            } catch (e) { /* try next */ }
        }
    },

    _maybeResetGraphColors: function () {
        if (!this.s["graph-colors-reset"]) return;
        this._persistSetting("graph-day-bg", GRAPH_DAY_BG_DEFAULT);
        this._persistSetting("graph-night-bg", GRAPH_NIGHT_BG_DEFAULT);
        this._persistSetting("graph-colors-reset", false);
    },

    _maybeResetIceChipColor: function () {
        if (!this.s["ice-chip-color-reset"]) return;
        this._persistSetting("ice-chip-color", "#add8e6");
        this._persistSetting("ice-chip-color-reset", false);
    },

    _fetchAll: function (locs, done) {
        const url = buildUrl(locs, this._fetchHours());
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
                acc.push({
                    loc: locs[i], parsed: parsed,
                    error: parsed ? null : "Empty response from Open-Meteo."
                });
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

    _graphDayNightOpts: function () {
        let enabled = this.s["graph-daynight"];
        if (enabled === undefined || enabled === null) enabled = true;
        return {
            enabled: !!enabled,
            dayBg: String(this.s["graph-day-bg"] || GRAPH_DAY_BG_DEFAULT),
            nightBg: String(this.s["graph-night-bg"] || GRAPH_NIGHT_BG_DEFAULT),
        };
    },

    _panelAlertsToday: function () {
        const days = ["panel-alert-sun", "panel-alert-mon", "panel-alert-tue",
            "panel-alert-wed", "panel-alert-thu", "panel-alert-fri",
            "panel-alert-sat"];
        return this.s[days[new Date().getDay()]] !== false;
    },

    _graphTracesOpts: function () {
        const on = (key) => this.s[key] !== false;
        return {
            temp: on("graph-show-temp"),
            sfc: on("graph-show-surface"),
            dew: on("graph-show-dew"),
            sun: on("graph-show-sun"),
            wind: on("graph-show-wind"),
            hum: on("graph-show-humidity"),
            prob: on("graph-show-prob"),
            precip: on("graph-show-precip"),
        };
    },

    _openGraph: function (entry) {
        try {
            if (!entry || !entry.parsed || !entry.profile) return;
            this._maybeResetGraphColors();
            this._maybeResetIceChipColor();
            const parsed = entry.parsed;
            const units = String(this.s["units"] || "metric");
            const hours = entry.profile.map((h) => ({
                time: h.time, name: h.name,
                rain: h.rain || 0, snow: h.snow || 0,
                wind: h.windSpeed || 0, gust: h.windGust || 0,
                wdir: (h.windDir === undefined) ? null : h.windDir,
                sun: h.sun || 0,
                temp: (h.airTemp === undefined) ? null : h.airTemp,
                sfc: (h.surfaceTemp === undefined) ? null : h.surfaceTemp,
                dew: (h.dewPoint === undefined) ? null : h.dewPoint,
                humidity: (h.humidity === undefined) ? null : h.humidity,
                prob: (h.prob === undefined || h.prob === null) ? null : h.prob,
                ice: !!h.ice,
            }));
            const svg = buildGraphSvg({
                title: entry.loc.name + ": " + parsed.risk.name + " — " +
                    (parsed.risk.hazards.join(" + ") || "No hazards"),
                subtitle: parsed.time.toLocaleString() + " · lat " + entry.loc.lat + ", lon " + entry.loc.lon +
                    " · season " + parsed.season +
                    " · wind " + fmtSpeedNum(parsed.windSpeed, units) + " " + speedUnit(units) +
                    ", gust " + fmtSpeedNum(parsed.windGust, units) + " " + speedUnit(units),
                hours: hours,
                advice: parsed.risk.advice,
                dayNight: this._graphDayNightOpts(),
                units: units,
                traces: this._graphTracesOpts(),
                values: String(this.s["graph-values"] || "all"),
                dayLabels: String(this.s["graph-day-labels"] || "date"),
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

    _addRiskRow: function (text, levelNum, riskName, opts) {
        if (!St) return false;
        const css = chipStyle(opts.colorMode, opts.minLevel, levelNum, riskName,
            opts.useHsp, opts.hspT, opts.iceChip);
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

    _renderChipSingle: function (label, levelNum, riskName, opts) {
        this._clearChipBox();
        this.set_applet_label(label);
        this.actor.set_style(chipStyle(opts.colorMode, opts.minLevel, levelNum,
            riskName, opts.useHsp, opts.hspT, opts.iceChip));
    },

    _clearChipBox: function () {
        if (this._chipBox) {
            try { this._chipBox.destroy(); } catch (e) { /* ignore */ }
            this._chipBox = null;
        }
        try { if (this._applet_label) this._applet_label.show(); } catch (e) { /* ignore */ }
    },

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
                        segments[i].level, segments[i].name, opts.useHsp, opts.hspT, opts.iceChip);
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

    _addLocationBlock: function (r, idx, th, hours, days, opts) {
        if (!r.parsed) {
            this.menu.addMenuItem(new PopupMenu.PopupMenuItem(
                r.loc.name + ": " + (r.error || "no data"), { reactive: false }));
            return;
        }

        const units = String(this.s["units"] || "metric");
        const currentRisk = r.parsed.risk.name;
        const peak = peakComingRisk(r.profile);
        const maxWarn = peak ? peak.name : currentRisk;
        const sum = comingSummary(r.profile, th, units) || "calm";

        const col1 = r.loc.name + " (" + currentRisk + ")";
        const col2 = sum;        
        const buttonText = col1 + " | " + col2;

        const gi = new PopupMenu.PopupMenuItem(buttonText);
        gi.connect("activate", ((entry) => () => this._openGraph(entry))(r));
        this.menu.addMenuItem(gi);

        const popupMode = String(this.s["popup-display-mode"] || "all");
        if (popupMode === "buttons-only") {
            return;
        }

        if (sum !== "calm") {
            let highlighted = false;
            if (peak && peak.level >= RiskLevel.SLIGHT) {
                highlighted = this._addRiskRow(sum, peak.level, peak.name, opts);
            }
            if (!highlighted) {
                this.menu.addMenuItem(new PopupMenu.PopupMenuItem(sum, { reactive: false }));
            }
        }

        if (popupMode !== "warnings-only" && this.s["show-best-hour"] !== false) {
            const bestText = bestHourText(r.profile, bestComingHour(r.profile), units);
            if (bestText) {
                this.menu.addMenuItem(new PopupMenu.PopupMenuItem(bestText, { reactive: false }));
            }
        }

        let nDays = parseInt(days, 10);
        if (!isNaN(nDays) && nDays > 0 && popupMode !== "warnings-only") {
            const groups = (r.daily && r.daily.length) ? r.daily :
                groupComingByDay(r.fullProfile || r.profile, nDays);
            const iceT = (th && th.ice !== undefined) ? th.ice : 3.0;
            for (let di = 0; di < groups.length; di++) {
                const g = groups[di];
                if (!g.hours || g.hours.length === 0) continue;
                const ds = summarizeDay(g.hours, iceT);
                if (this.s["hide-calm-days"] === true && ds.maxLvl < RiskLevel.SLIGHT) continue;
                const row = formatDailyRow(g.label, ds, th, units);
                if (ds.maxLvl >= RiskLevel.SLIGHT) {
                    if (!this._addRiskRow(row, ds.maxLvl, ds.maxName, opts)) {
                        this.menu.addMenuItem(new PopupMenu.PopupMenuItem(row, { reactive: false }));
                    }
                } else {
                    this.menu.addMenuItem(new PopupMenu.PopupMenuItem(row, { reactive: false }));
                }
            }
        }
    },

    _showAll: function (results) {
        const primary = results[0];
        if (!primary || !primary.parsed) {
            this._showError(primary && primary.error ? primary.loc.name + ": " + primary.error : "Empty response.");
            return;
        }
        const th = this._thresholds();
        const iceT = th.ice;
        const hours = this._forecastHours();
        const days = this._forecastDays();
        const fetchH = this._fetchHours();
        const colorMode = String(this.s["color-mode"] || "bright");
        const colorMin = String(this.s["color-min-level"] || "always");
        const useHsp = !!this.s["use-hsp-text"];
        const hspT = this.s["hsp-threshold"];
        const popupMode = String(this.s["popup-display-mode"] || "all");
        const showAdv = (popupMode !== "buttons-only") && (this.s["show-advice"] !== false);
        const showPeak = this.s["show-peak-risk"] !== false;
        const units = String(this.s["units"] || "metric");
        const iceChipEnabled = this.s["ice-chip-enabled"] === true;
        const iceChipHours = Math.max(1, parseInt(this.s["ice-chip-hours"] || 24));
        const iceChipColor = this.s["ice-chip-color"] || "#add8e6";

        let iceAnywhere = false;
        let iceTodayAnywhere = false;
        let worstLevel = primary.parsed.risk.level;
        let worstName = primary.parsed.risk.name;

        for (let i = 0; i < results.length; i++) {
            const r = results[i];
            if (!r.parsed) continue;
            r.fullProfile = calculateProfile(r.parsed, fetchH);
            r.profile = r.fullProfile.slice(0, Math.min(r.fullProfile.length, hours + 1));
            r.daily = groupComingByDay(r.fullProfile, days);
            r.iceNow = hasIceHazard(r.parsed.risk.hazards) || r.parsed.surfaceTemp <= iceT;
            r.iceAhead = false;

            r.hasIceInWindow = iceChipEnabled ? hasIceWithinHours(r.profile, iceChipHours) : false;

            for (let h = 1; h < r.fullProfile.length; h++) {
                if (r.fullProfile[h].ice) { r.iceAhead = true; break; }
                const stH = r.fullProfile[h].surfaceTemp;
                if (stH !== undefined && stH !== null && stH <= iceT) { r.iceAhead = true; break; }
            }
            if (!r.iceAhead && r.fullProfile.length === 0 && r.parsed._data && r.parsed._data.hourly) {
                const st = pickHourly(r.parsed._data.hourly, ["surface_temperature"], 0);
                for (let h = r.parsed._targetIdx + 1;
                    h < Math.min(st.length, r.parsed._targetIdx + 1 + fetchH); h++) {
                    if (st[h] != null && st[h] <= iceT) { r.iceAhead = true; break; }
                }
            }
            r.iceToday = !!r.iceNow;
            r.peakTodayLvl = 0;
            if (r.fullProfile.length > 0 &&
                r.fullProfile[0].time instanceof Date && !isNaN(r.fullProfile[0].time)) {
                const d0 = r.fullProfile[0].time;
                for (let h = 0; h < r.fullProfile.length; h++) {
                    const th = r.fullProfile[h].time;
                    if (!(th instanceof Date) || isNaN(th)) continue;
                    if (th.getFullYear() !== d0.getFullYear() ||
                        th.getMonth() !== d0.getMonth() || th.getDate() !== d0.getDate()) break;
                    if ((r.fullProfile[h].level || 0) > r.peakTodayLvl) {
                        r.peakTodayLvl = r.fullProfile[h].level;
                    }
                    if (!r.iceToday && h > 0) {
                        if (r.fullProfile[h].ice) { r.iceToday = true; continue; }
                        const stH = r.fullProfile[h].surfaceTemp;
                        if (stH !== undefined && stH !== null && stH <= iceT) { r.iceToday = true; }
                    }
                }
            }
            r.lows = forecastLows(r.fullProfile);
            if (r.iceNow || r.iceAhead) iceAnywhere = true;
            if (r.iceToday) iceTodayAnywhere = true;
            if (r.parsed.risk.level > worstLevel) {
                worstLevel = r.parsed.risk.level;
                worstName = r.parsed.risk.name;
            }
        }

        const p = primary.parsed;
        const chipMode = String(this.s["panel-chip-locations"] || "primary");
        const hasIceInWindow = primary.hasIceInWindow || false;
        const chipOpts = {
            colorMode: colorMode, minLevel: colorMin,
            useHsp: useHsp, hspT: hspT,
            iceChip: { enabled: iceChipEnabled, color: iceChipColor, hasIce: hasIceInWindow }
        };
        const alertNeed = chipAlertLevelNum(this.s["panel-chip-alert-level"]);
        let showAlerts = this._panelAlertsToday();
        if (!showAlerts && this.s["panel-alert-current-day"] !== false) {
            for (let qi = 0; qi < results.length; qi++) {
                const qr = results[qi];
                if (!qr.parsed) continue;
                if (qr.iceToday || (qr.peakTodayLvl || 0) >= alertNeed) { showAlerts = true; break; }
            }
        }
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
            if (this.s["show-temperature"]) tx += " " + fmtTempInt(cr.parsed.airTemp, units);
            if (cr.iceNow || cr.iceAhead) tx = "❄ " + tx;
            chipSegs.push({ text: tx, level: lv, name: nm });
        }

        // Properly scope alertIdx here so it's globally available inside _showAll
        let alertIdx = -1;
        for (let ai = 1; ai < chipSegs.length; ai++) {
            if (chipSegs[ai].level >= alertNeed) { alertIdx = ai; break; }
        }

        if (!showAlerts) {
            const locInitial = ((primary.loc.name || "?").trim().charAt(0) || "?").toUpperCase();
            let quiet = locInitial + " " + (SHORT_LABEL[p.risk.name] || p.risk.name);
            if (this.s["show-temperature"]) quiet += " " + fmtTempInt(p.airTemp, units);
            if (iceTodayAnywhere) quiet = "❄ " + quiet;
            this._renderChipSingle(quiet, 0, "NO_DATA",
                {
                    colorMode: chipOpts.colorMode, minLevel: "never",
                    useHsp: chipOpts.useHsp, hspT: chipOpts.hspT,
                    iceChip: chipOpts.iceChip
                });
        } else if (chipMode === "all" && chipSegs.length > 0) {
            const topSegs = [chipSegs[0]];
            let best = -1;
            for (let mi = 1; mi < chipSegs.length; mi++) {
                if (best === -1 || chipSegs[mi].level > chipSegs[best].level) best = mi;
            }
            if (best !== -1) topSegs.push(chipSegs[best]);
            const multiOk = this._renderChipMulti(topSegs, chipOpts);
            if (!multiOk) {
                const joined = topSegs.map((s) => s.text).join("|");
                this._renderChipSingle(joined, worstLevel, worstName, chipOpts);
            }
        } else {
            const peakPrimary = showPeak ? peakComingRisk(primary.profile) : null;
            const shownName = peakPrimary ? peakPrimary.name : p.risk.name;
            const shownLevel = peakPrimary ? peakPrimary.level : p.risk.level;
            const locInitial = ((primary.loc.name || "?").trim().charAt(0) || "?").toUpperCase();
            let label = locInitial + " " + (SHORT_LABEL[shownName] || shownName);
            if (this.s["show-temperature"]) label += " " + fmtTempInt(p.airTemp, units);
            if (iceAnywhere) label = "❄ " + label;
            let chipLevel = shownLevel, chipName = shownName;
            
            if (alertIdx === -1) {
                this._renderChipSingle(label, chipLevel, chipName, chipOpts);
            } else {
                label += "|" + chipSegs[alertIdx].text.replace(/^❄ /, "");
                if (chipSegs[alertIdx].level > chipLevel) {
                    chipLevel = chipSegs[alertIdx].level;
                    chipName = chipSegs[alertIdx].name;
                }
                const alertSegs = [
                    {
                        text: chipSegs[0].text, level: chipSegs[0].level,
                        name: chipSegs[0].name,
                        plain: chipSegs[0].level < alertNeed
                    },
                    {
                        text: chipSegs[alertIdx].text, level: chipSegs[alertIdx].level,
                        name: chipSegs[alertIdx].name, plain: false
                    },
                ];
                if (!this._renderChipMulti(alertSegs, chipOpts)) {
                    this._renderChipSingle(label, chipLevel, chipName, chipOpts);
                }
            }
        }

        // Simplified tooltip restricted to primary and chip/alert locations
        let tipParts = [];
        const primaryPeak = showPeak ? peakComingRisk(primary.profile) : null;
        const primarySummary = comingSummary(primary.profile, th, units);
        let primaryTipText = primary.loc.name + ": " + (primaryPeak ? primaryPeak.name : p.risk.name);
        if (primarySummary) primaryTipText += " — " + primarySummary;
        tipParts.push(primaryTipText);

        if (alertIdx !== -1 && alertIdx < results.length) {
            const alertRes = results[alertIdx];
            const alertPeak = showPeak ? peakComingRisk(alertRes.profile) : null;
            const alertSummary = comingSummary(alertRes.profile, th, units);
            let alertTipText = alertRes.loc.name + ": " + (alertPeak ? alertPeak.name : alertRes.parsed.risk.name);
            if (alertSummary) alertTipText += " — " + alertSummary;
            tipParts.push(alertTipText);
        } else if (results.length > 1 && chipMode === "all") {
            const secondaryRes = results[1];
            if (secondaryRes && secondaryRes.parsed) {
                const secPeak = showPeak ? peakComingRisk(secondaryRes.profile) : null;
                const secSummary = comingSummary(secondaryRes.profile, th, units);
                let secTipText = secondaryRes.loc.name + ": " + (secPeak ? secPeak.name : secondaryRes.parsed.risk.name);
                if (secSummary) secTipText += " — " + secSummary;
                tipParts.push(secTipText);
            }
        }

        if (iceAnywhere) {
            tipParts.unshift("❄ ICE WARNING — check popup");
        }

        this.set_applet_tooltip("Slippery:\n" + tipParts.join("\n"));

        this.menu.removeAll();

        if (iceAnywhere && popupMode !== "buttons-only") {
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
                    fmtTemp(r.parsed.surfaceTemp, units) + " · air " +
                    fmtTemp(r.parsed.airTemp, units);
                if (r.iceNow) line += " — now";
                if (r.iceAhead && r.lows &&
                    (r.lows.minSfc !== null || r.lows.minAir !== null)) {
                    line += (r.iceNow ? "; " : " → ") + "low sfc " +
                        (r.lows.minSfc !== null ? fmtTemp(r.lows.minSfc, units) : "?") +
                        (r.lows.minSfcTime ? " (" + fmtRelHours(Date.now(), r.lows.minSfcTime.getTime()) + ")" : "") +
                        " · air " +
                        (r.lows.minAir !== null ? fmtTemp(r.lows.minAir, units) : "?") +
                        (r.lows.minAirTime ? " (" + fmtRelHours(Date.now(), r.lows.minAirTime.getTime()) + ")" : "");
                } else if (r.iceAhead) {
                    line += " → colder coming hours";
                }
                this.menu.addMenuItem(new PopupMenu.PopupMenuItem(line, { reactive: false }));
            }
            this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        }

        if (popupMode !== "buttons-only") {
            const primaryText = primary.loc.name + ": " + p.risk.name + " — " +
                p.time.toLocaleDateString() + " " + hourLabel(p.time, false);
            const primaryRowOk = this._addRiskRow(primaryText, p.risk.level, p.risk.name,
                { colorMode: colorMode, minLevel: colorMin, useHsp: useHsp, hspT: hspT, iceChip: chipOpts.iceChip });
            if (!primaryRowOk) {
                this.menu.addMenuItem(new PopupMenu.PopupMenuItem(primaryText, { reactive: false }));
            }

            p.risk.hazards.forEach((hz) => {
                const iceMark = hasIceHazard([hz]) ? "\u2744 " : "\u26A0 ";
                this.menu.addMenuItem(new PopupMenu.PopupMenuItem(iceMark + hz, { reactive: false }));
            });
            if (showAdv) {
                if (this.s["compact-advice"] === true && p.risk.advice.length > 0) {
                    const advLines = wrapAdviceLines(p.risk.advice, 70);
                    for (let k = 0; k < advLines.length; k++) {
                        this.menu.addMenuItem(new PopupMenu.PopupMenuItem(
                            (k === 0 ? "\u2192 " : "   ") + advLines[k], { reactive: false }));
                    }
                } else {
                    p.risk.advice.forEach((ad) => {
                        this.menu.addMenuItem(new PopupMenu.PopupMenuItem("\u2192 " + ad, { reactive: false }));
                    });
                }
            }
            if (p.risk.hazards.length === 0 && (!showAdv || p.risk.advice.length === 0)) {
                this.menu.addMenuItem(new PopupMenu.PopupMenuItem("No hazards — good ride", { reactive: false }));
            }
            this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

            if (this.s["show-details"] !== false) {
                const det = relevantDetails(p, th, primary.profile, units);
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
                    let prow = "Rain " + fmtRain(p.rainCurrent, units) + " \u00b7 12h " + fmtRain(p.rain12, units);
                    if (p.snowCurrent >= 0.05 || p.snow12 >= SNOW_THRESHOLD) {
                        prow += " \u00b7 snow " + fmtSnow(p.snowCurrent, units) + "/" + fmtSnow(p.snow12, units);
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
            }
            this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        }

        for (let i = 0; i < results.length; i++) {
            const r = results[i];
            const locIceChipOpts = {
                enabled: iceChipEnabled,
                color: iceChipColor,
                hasIce: r.hasIceInWindow || false
            };
            const locOpts = {
                colorMode: colorMode,
                minLevel: colorMin,
                useHsp: useHsp,
                hspT: hspT,
                iceChip: locIceChipOpts
            };

            if (i > 0) {
                this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
            }
            this._addLocationBlock(r, i, th, hours, days, locOpts);
        }

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        const item = new PopupMenu.PopupMenuItem("Refresh now");
        item.connect("activate", () => this.refresh());
        this.menu.addMenuItem(item);
    }
};

function main(metadata, orientation, panelHeight, instanceId) {
    return new SlipperyApplet(metadata, orientation, panelHeight, instanceId);
}