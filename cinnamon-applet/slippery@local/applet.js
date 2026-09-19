/*
 * Slippery — Cinnamon panel applet.
 *
 * Same data + same checks as the Slippery Connect IQ data field:
 *  - Open-Meteo request mirrors source/background/BackgroundService.mc
 *    (hourly vars, past_hours=12, forecast_hours=12, unixtime, minutely_15)
 *  - evaluateRisk() is a direct port of source/weatherrisks/riskCalculator.mc
 *  - seasons mirror source/weatherrisks/helpers.mc
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
// Panel chip colors (dark-panel friendly, same scale as the data field).
const RISK_STYLE = {
    NO_DATA: "",
    SAFE: "",
    SLIGHT: "background-color: #ffff00; color: #000;",
    MODERATE: "background-color: #ffa500; color: #000;",
    HIGH: "background-color: #ff4500; color: #fff;",
    CRITICAL: "background-color: #ff0000; color: #fff; font-weight: bold;",
};

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
    const surfT = pickHourly(hourly, ["surface_temperature"], times.length);
    const dewP = pickHourly(hourly, ["dewpoint_2m"], times.length);
    const hum = pickHourly(hourly, ["relativehumidity_2m"], times.length);
    const rain = pickHourly(hourly, ["rain"], times.length);
    const showers = pickHourly(hourly, ["showers"], times.length);
    const snow = pickHourly(hourly, ["snowfall"], times.length);
    const windS = pickHourly(hourly, ["wind_speed_10m"], times.length);
    const windG = pickHourly(hourly, ["wind_gusts_10m"], times.length);

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
    const rainCurrent = at(rain, targetIdx) + at(showers, targetIdx);
    const snowCurrent = at(snow, targetIdx);
    let immR = -1, immS = -1;
    if (data.minutely_15) {
        immR = checkImminent((data.minutely_15.rain || []).slice(0, 4));
        immS = checkImminent((data.minutely_15.snowfall || []).slice(0, 4));
    }
    const r = evaluateRisk({
        airTemp: airTemp,
        surfaceTemp: surfaceTemp,
        dewPoint: at(dewP, targetIdx),
        humidity: at(hum, targetIdx),
        rainCurrent: rainCurrent,
        runningRain12h: rain12,
        runningSnow12h: snow12,
        dryStreak: dry,
        season: getSeason(lat, new Date(nowSec * 1000)),
        windSpeed: at(windS, targetIdx),
        windGust: at(windG, targetIdx),
        immediateRain: immR,
        immediateSnow: immS,
        surfaceDewSpread: surfaceTemp - at(dewP, targetIdx),
        snowCurrent: snowCurrent,
    });
    return {
        risk: r,
        airTemp: airTemp,
        windSpeed: at(windS, targetIdx),
        windGust: at(windG, targetIdx),
        rain12: rain12,
        time: new Date(times[targetIdx] * 1000),
    };
}

// Mirrors BackgroundService.mc fetchOpenMeteoData().
function buildUrl(lat, lon) {
    const q = [
        "latitude=" + encodeURIComponent(lat),
        "longitude=" + encodeURIComponent(lon),
        "hourly=" + encodeURIComponent("temperature_2m,relativehumidity_2m,dewpoint_2m,showers,rain,snowfall,precipitation_probability,surface_temperature,wind_speed_10m,wind_gusts_10m,wind_direction_10m"),
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
        this.settings.bind("latitude", "latitude", this._onSettingsChanged.bind(this));
        this.settings.bind("longitude", "longitude", this._onSettingsChanged.bind(this));
        this.settings.bind("refresh-minutes", "refreshMinutes", this._onSettingsChanged.bind(this));
        this.settings.bind("show-temperature", "showTemperature", this._onSettingsChanged.bind(this));

        this.menuManager = new PopupMenu.PopupMenuManager(this);
        this.menu = new Applet.AppletPopupMenu(this, orientation);
        this.menuManager.addMenu(this.menu);

        this._timeoutId = 0;
        this._busy = false;
        this.set_applet_label("…");
        this.set_applet_tooltip("Slippery: fetching Open-Meteo…");
        this._schedule();
        this.refresh();
    },

    _onSettingsChanged: function () {
        this._schedule();
        this.refresh();
    },

    _schedule: function () {
        if (this._timeoutId > 0) {
            Mainloop.source_remove(this._timeoutId);
            this._timeoutId = 0;
        }
        let mins = parseInt(this.s.refreshMinutes, 10);
        if (isNaN(mins) || mins < 5) mins = 15;
        this._timeoutId = Mainloop.timeout_add_seconds(mins * 60, () => {
            this.refresh();
            return true;
        });
    },

    on_applet_clicked: function () {
        this.menu.toggle();
    },

    on_applet_removed_from_panel: function () {
        if (this._timeoutId > 0) {
            Mainloop.source_remove(this._timeoutId);
            this._timeoutId = 0;
        }
        if (this.settings) this.settings.finalize();
    },

    refresh: function () {
        if (this._busy) return;
        const lat = parseFloat(String(this.s.latitude).replace(",", "."));
        const lon = parseFloat(String(this.s.longitude).replace(",", "."));
        if (isNaN(lat) || isNaN(lon)) {
            this._showError("Invalid latitude/longitude in settings.");
            return;
        }
        this._busy = true;
        const url = buildUrl(lat, lon);
        let proc;
        try {
            proc = Gio.Subprocess.new(
                ["curl", "-sS", "--max-time", "25", url],
                Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE
            );
        } catch (e) {
            this._busy = false;
            this._showError("Cannot start curl: " + e.message);
            return;
        }
        proc.communicate_utf8_async(null, null, (p, res) => {
            this._busy = false;
            try {
                const [, stdout] = p.communicate_utf8_finish(res);
                const data = JSON.parse(stdout);
                const nowSec = Math.floor(Date.now() / 1000);
                const parsed = parseResponse(lat, data, nowSec);
                if (!parsed) this._showError("Empty response from Open-Meteo.");
                else this._showResult(parsed);
            } catch (e) {
                this._showError("Fetch failed: " + e.message);
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

    _showResult: function (parsed) {
        const r = parsed.risk;
        let label = SHORT_LABEL[r.name] || "?";
        if (this.s.showTemperature) label += " " + Math.round(parsed.airTemp) + "°";
        this.set_applet_label(label);
        this.actor.set_style(RISK_STYLE[r.name] || "");

        const tip = "Slippery: " + r.name +
            (r.hazards.length > 0 ? "\n" + r.hazards.join("\n") : "\nNo hazards") +
            "\nWind " + parsed.windSpeed + " km/h, gust " + parsed.windGust + " km/h" +
            " · rain 12h " + parsed.rain12.toFixed(1) + " mm";
        this.set_applet_tooltip(tip);

        this.menu.removeAll();
        const head = new PopupMenu.PopupMenuItem(
            r.name + " — " + parsed.time.toLocaleString(), { reactive: false });
        this.menu.addMenuItem(head);
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        r.hazards.forEach((hz) => {
            this.menu.addMenuItem(new PopupMenu.PopupMenuItem("⚠ " + hz, { reactive: false }));
        });
        r.advice.forEach((ad) => {
            this.menu.addMenuItem(new PopupMenu.PopupMenuItem("→ " + ad, { reactive: false }));
        });
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        this.menu.addMenuItem(new PopupMenu.PopupMenuItem(
            "Air " + parsed.airTemp.toFixed(1) + "°C · wind " +
            parsed.windSpeed + "/" + parsed.windGust + " km/h", { reactive: false }));
        const item = new PopupMenu.PopupMenuItem("Refresh now");
        item.connect("activate", () => this.refresh());
        this.menu.addMenuItem(item);
    },
};

function main(metadata, orientation, panelHeight, instanceId) {
    return new SlipperyApplet(metadata, orientation, panelHeight, instanceId);
}
