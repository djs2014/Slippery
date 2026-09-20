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

// todo.md: "colors bright" / "colors modest" / "follow theme".
// bright = vivid chip colors (previous behaviour, dark-panel friendly).
// modest = muted chip colors for a calmer panel.
// follow-theme = no background styling at all, panel theme decides.
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

function chipStyle(colorMode, riskName, useHsp, hspThreshold) {
    if (colorMode === "follow-theme") return "";
    const pal = RISK_BG[colorMode] || RISK_BG.bright;
    const bg = pal[riskName] || "";
    if (!bg) return "";
    const fg = textColorFor(bg, useHsp, hspThreshold, riskName);
    const bold = (riskName === "CRITICAL") ? " font-weight: bold;" : "";
    return "background-color: " + bg + "; color: " + fg + ";" + bold;
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
    const surfT = pickHourly(hourly, ["surface_temperature"], n);
    const dewP = pickHourly(hourly, ["dewpoint_2m"], n);
    const hum = pickHourly(hourly, ["relativehumidity_2m"], n);
    const rain = pickHourly(hourly, ["rain"], n);
    const showers = pickHourly(hourly, ["showers"], n);
    const snow = pickHourly(hourly, ["snowfall"], n);
    const windS = pickHourly(hourly, ["wind_speed_10m"], n);
    const windG = pickHourly(hourly, ["wind_gusts_10m"], n);
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
        out.push({
            time: (typeof t === "number") ? new Date(t * 1000) : null,
            name: r.name,
            level: r.level,
            hazards: r.hazards,
            rain: rainCur,
            snow: snowCur,
            ice: hasIceHazard(r.hazards),
        });
    }
    return out;
}

function hourLabel(d, isNow) {
    if (isNow) return "now";
    if (!d) return "?";
    const h = d.getHours();
    return (h < 10 ? "0" + h : "" + h) + ":00";
}

// Mirrors BackgroundService.mc fetchOpenMeteoData(), plus
// apparent_temperature for the feels-like row.
function buildUrl(lat, lon) {
    const q = [
        "latitude=" + encodeURIComponent(lat),
        "longitude=" + encodeURIComponent(lon),
        "hourly=" + encodeURIComponent("temperature_2m,relativehumidity_2m,dewpoint_2m,apparent_temperature,showers,rain,snowfall,precipitation_probability,surface_temperature,wind_speed_10m,wind_gusts_10m,wind_direction_10m"),
        "past_hours=12",
        "forecast_hours=12",
        "timezone=auto",
        "timeformat=unixtime",
        "minutely_15=" + encodeURIComponent("rain,snowfall"),
        "forecast_minutely_15=4",
    ].join("&");
    return "https://api.open-meteo.com/v1/forecast?" + q;
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

        this.s = {};
        this.settings = new Settings.AppletSettings(this.s, UUID, instanceId);
        const keys = ["location-1-name", "location-1-coords",
            "location-2-name", "location-2-coords",
            "location-3-name", "location-3-coords",
            "location-4-name", "location-4-coords",
            "location-5-name", "location-5-coords",
            "refresh-minutes", "startup-delay-sec", "forecast-hours",
            "show-temperature", "color-mode", "use-hsp-text", "hsp-threshold",
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
        if (isNaN(h) || h < 1) h = 8;
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
        this._busy = true;
        this._fetchAll(locs, 0, [], (results) => {
            this._busy = false;
            this._lastResults = results;
            this._showAll(results);
        });
    },

    _fetchAll: function (locs, idx, acc, done) {
        if (idx >= locs.length) {
            done(acc);
            return;
        }
        const url = buildUrl(locs[idx].lat, locs[idx].lon);
        this._fetchJson(url, (err, data) => {
            if (err) {
                acc.push({ loc: locs[idx], parsed: null, error: err });
            } else {
                let parsed = null;
                try {
                    parsed = parseResponse(locs[idx].lat, data, Math.floor(Date.now() / 1000));
                } catch (e) {
                    parsed = null;
                }
                acc.push({ loc: locs[idx], parsed: parsed,
                           error: parsed ? null : "Empty response from Open-Meteo." });
            }
            this._fetchAll(locs, idx + 1, acc, done);
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

    _showAll: function (results) {
        const primary = results[0];
        if (!primary || !primary.parsed) {
            this._showError(primary && primary.error ? primary.loc.name + ": " + primary.error : "Empty response.");
            return;
        }
        const iceT = this._thresholds().ice;
        const hours = this._forecastHours();
        const colorMode = String(this.s["color-mode"] || "bright");
        const useHsp = !!this.s["use-hsp-text"];
        const hspT = this.s["hsp-threshold"];

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
                if (r.profile[h].ice) { r.iceAhead = true; break; }
            }
            // Surface-threshold ice in any coming hour also counts as ICE ahead.
            if (!r.iceAhead && r.parsed._data && r.parsed._data.hourly) {
                const st = pickHourly(r.parsed._data.hourly, ["surface_temperature"], 0);
                for (let h = r.parsed._targetIdx + 1;
                     h < Math.min(st.length, r.parsed._targetIdx + 1 + hours); h++) {
                    if (st[h] != null && st[h] <= iceT) { r.iceAhead = true; break; }
                }
            }
            if (r.iceNow || r.iceAhead) iceAnywhere = true;
            if (r.parsed.risk.level > worstLevel) {
                worstLevel = r.parsed.risk.level;
                worstName = r.parsed.risk.name;
            }
        }

        // --- Panel chip (primary location; ICE anywhere is a big warning) ---
        const p = primary.parsed;
        let label = SHORT_LABEL[p.risk.name] || "?";
        if (this.s["show-temperature"]) label += " " + Math.round(p.airTemp) + "°";
        if (iceAnywhere) label = "\u2744 " + label;
        this.set_applet_label(label);
        this.actor.set_style(chipStyle(colorMode, p.risk.name, useHsp, hspT));

        let tip = "Slippery: " + p.risk.name + " @ " + primary.loc.name +
            (p.risk.hazards.length > 0 ? "\n" + p.risk.hazards.join("\n") : "\nNo hazards") +
            "\nWind " + Math.round(p.windSpeed) + " km/h " + compass16(p.windDir) +
            ", gust " + Math.round(p.windGust) + " km/h" +
            " · rain 12h " + p.rain12.toFixed(1) + " mm";
        if (results.length > 1) tip += "\nWorst of " + results.length + " points: " + worstName;
        if (iceAnywhere) tip += "\n\u2744 ICE WARNING — check popup";
        this.set_applet_tooltip(tip);

        // --- Compact popup menu ---
        this.menu.removeAll();

        // todo.md: "ICE or ICE coming hours is big warning" — top banner.
        if (iceAnywhere) {
            this.menu.addMenuItem(new PopupMenu.PopupMenuItem(
                "\u2744 ICE — freezing surface now or coming", { reactive: false }));
            this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        }

        this.menu.addMenuItem(new PopupMenu.PopupMenuItem(
            primary.loc.name + ": " + p.risk.name + " — " + p.time.toLocaleString(), { reactive: false }));

        p.risk.hazards.forEach((hz) => {
            const iceMark = hasIceHazard([hz]) ? "\u2744 " : "\u26A0 ";
            this.menu.addMenuItem(new PopupMenu.PopupMenuItem(iceMark + hz, { reactive: false }));
        });
        p.risk.advice.forEach((ad) => {
            this.menu.addMenuItem(new PopupMenu.PopupMenuItem("\u2192 " + ad, { reactive: false }));
        });
        if (p.risk.hazards.length === 0 && p.risk.advice.length === 0) {
            this.menu.addMenuItem(new PopupMenu.PopupMenuItem("No hazards — good ride", { reactive: false }));
        }
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        // todo.md details in two rows: wind / temps (shown when relevant:
        // feels-like only if the API returned it, precip only when wet).
        this.menu.addMenuItem(new PopupMenu.PopupMenuItem(
            "Wind " + p.windSpeed.toFixed(0) + " " + compass16(p.windDir) +
            " (" + Math.round(p.windDir) + "°) · gust " + p.windGust.toFixed(0),
            { reactive: false }));
        let tempRow = "Air " + p.airTemp.toFixed(1) + "°";
        if (p.hasFeelsLike) tempRow += " (feels " + p.feelsLike.toFixed(1) + "°)";
        tempRow += " · sfc " + p.surfaceTemp.toFixed(1) + "° · dew " + p.dewPoint.toFixed(1) +
            "° · hum " + Math.round(p.humidity) + "%";
        this.menu.addMenuItem(new PopupMenu.PopupMenuItem(tempRow, { reactive: false }));
        if (p.rainCurrent >= RAIN_THRESHOLD || p.snowCurrent >= SNOW_THRESHOLD ||
            p.rain12 >= RAIN_THRESHOLD || p.snow12 >= SNOW_THRESHOLD ||
            p.immRain >= 0 || p.immSnow >= 0) {
            let prow = "Rain " + p.rainCurrent.toFixed(1) + " · 12h " + p.rain12.toFixed(1) + "mm";
            if (p.snowCurrent >= 0.05 || p.snow12 >= SNOW_THRESHOLD) {
                prow += " · snow " + p.snowCurrent.toFixed(1) + "/" + p.snow12.toFixed(1) + "cm";
            }
            if (p.immRain === 0) prow += " · rain NOW";
            else if (p.immRain > 0) prow += " · rain " + p.immRain + "min";
            if (p.immSnow === 0) prow += " · snow NOW";
            else if (p.immSnow > 0) prow += " · snow " + p.immSnow + "min";
            this.menu.addMenuItem(new PopupMenu.PopupMenuItem(prow, { reactive: false }));
        }

        // todo.md: "display coming x hours — risklevel + precipitation amount",
        // packed three hours per row to keep the popup compact.
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        this.menu.addMenuItem(new PopupMenu.PopupMenuItem(
            "Next " + hours + "h @ " + primary.loc.name + " (risk mm):", { reactive: false }));
        const blocks = primary.profile.map((h, idx) => {
            let b = hourLabel(h.time, idx === 0) + " " + (SHORT_LABEL[h.name] || "?") +
                " " + h.rain.toFixed(1);
            if (h.snow >= 0.05) b += "+" + h.snow.toFixed(1) + "s";
            if (h.ice) b = "\u2744" + b;
            return b;
        });
        for (let i = 0; i < blocks.length; i += 3) {
            this.menu.addMenuItem(new PopupMenu.PopupMenuItem(
                blocks.slice(i, i + 3).join(" · "), { reactive: false }));
        }

        // todo.md: "display current risklevels + precipitation from list of lat/lon".
        if (results.length > 1) {
            this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
            this.menu.addMenuItem(new PopupMenu.PopupMenuItem("Points now:", { reactive: false }));
            for (let i = 0; i < results.length; i++) {
                const r = results[i];
                if (!r.parsed) {
                    this.menu.addMenuItem(new PopupMenu.PopupMenuItem(
                        r.loc.name + ": " + (r.error || "no data"), { reactive: false }));
                    continue;
                }
                let row = r.loc.name + ": " + (SHORT_LABEL[r.parsed.risk.name] || "?") +
                    " " + Math.round(r.parsed.airTemp) + "° " +
                    r.parsed.rainCurrent.toFixed(1) + "mm";
                if (r.parsed.snowCurrent >= 0.05) row += "+" + r.parsed.snowCurrent.toFixed(1) + "s";
                if (r.iceNow) row = "\u2744 " + row + " ICE";
                else if (r.iceAhead) row = row + " (\u2744>)";
                this.menu.addMenuItem(new PopupMenu.PopupMenuItem(row, { reactive: false }));
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
