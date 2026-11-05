/*
 * Slippery Desklet — Cinnamon desklet for per-location severity visualization.
 * Compatible with Cinnamon 6.6+
 */

const Desklet = imports.ui.desklet;
const St = imports.gi.St;
const Settings = imports.ui.settings;
const Soup = imports.gi.Soup;
const Mainloop = imports.mainloop;
const GLib = imports.gi.GLib;

const UUID = "slippery@desklet";
const _httpSession = new Soup.Session();

// Risk levels
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

// Hazards
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

// Advice
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

function evaluateRisk(p) {
    let riskLevel = RiskLevel.SAFE;
    const hazards = [];
    const advice = [];
    const upgrade = (l) => { if (l > riskLevel) riskLevel = l; };
    const addH = (h) => { if (hazards.indexOf(h) === -1) hazards.push(h); };
    const addA = (a) => { if (advice.indexOf(a) === -1) advice.push(a); };

    if ((p.surfaceTemp <= 0.0 || p.airTemp <= 0.5) &&
        (p.runningRain12h >= 0.1 || p.rainCurrent >= 0.1 ||
         p.runningSnow12h >= 0.1 || p.snowCurrent >= 0.1)) {
        upgrade(RiskLevel.CRITICAL);
        addH(Hazards.BLACK_ICE); addA(Advice.AVOID_RIDING); addA(Advice.LOWER_TIRE_PRESSURE);
    }
    if (p.surfaceTemp <= 0.0 && p.surfaceDewSpread <= 2.0 && p.humidity >= 80) {
        upgrade(RiskLevel.CRITICAL);
        addH(Hazards.FROST); addA(Advice.WATCH_SHADED); addA(Advice.AVOID_BRAKING);
    }
    if (p.airTemp >= 0.0 && p.airTemp <= 2.5 &&
        (p.runningRain12h >= 0.1 || p.humidity > 88 || p.runningSnow12h >= 0.1)) {
        upgrade(RiskLevel.HIGH);
        addH(Hazards.BRIDGE_ICE); addA(Advice.WATCH_SHADED);
    }
    if (p.runningSnow12h >= 0.1 && (p.surfaceTemp <= 1.0 || p.airTemp <= 1.5)) {
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
        (p.runningRain12h >= 0.1 || p.runningSnow12h >= 0.1 ||
         p.rainCurrent >= 0.1 || p.snowCurrent >= 0.1)) {
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

    if (p.immediateRain >= 0 && p.rainCurrent < 0.1) {
        if ((p.upcomingRain || 0) >= 2.5) {
            upgrade(RiskLevel.HIGH);
        } else {
            upgrade(RiskLevel.MODERATE);
        }
        addH(Hazards.IMMINENT_RAIN);
        addA(p.immediateRain === 0 ? Advice.RAIN_NOW : "Rain in " + p.immediateRain + " min");
    }
    if (p.immediateSnow >= 0 && p.snowCurrent < 0.1) {
        upgrade(RiskLevel.HIGH);
        addH(Hazards.IMMINENT_SNOW);
        addA(p.immediateSnow === 0 ? Advice.SNOW_NOW : "Snow in " + p.immediateSnow + " min");
    }
    return { level: riskLevel, name: RISK_NAMES[riskLevel], hazards: hazards, advice: advice };
}

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
    if (isNaN(t) || t < 0 || t > 255) t = 127;
    return hspOfHex(bgHex) > t ? "#000" : "#fff";
}

function colorPassesMinLevel(minLevel, levelNum) {
    const m = String(minLevel || "always");
    if (m === "always") return true;
    if (m === "never") return false;
    const need = { slight: 2, moderate: 3, high: 4, critical: 5 }[m];
    if (need === undefined) return true;
    return (levelNum || 0) >= need;
}

function chipStyle(colorMode, minLevel, levelNum, riskName, useHsp, hspThreshold) {
    if (colorMode === "follow-theme") return "";
    if (!colorPassesMinLevel(minLevel, levelNum)) return "";
    const pal = RISK_BG[colorMode] || RISK_BG.bright;
    const bg = pal[riskName] || "";
    if (!bg) return "";
    const fg = textColorFor(bg, useHsp, hspThreshold, riskName);
    const bold = (riskName === "CRITICAL") ? " font-weight: bold;" : "";
    return "background-color: " + bg + "; color: " + fg + ";" + bold;
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

function fetchWeather(lat, lon, fetchSuccess, fetchFailure) {
    const baseUrl = "https://api.open-meteo.com/v1/forecast";
    const requestUrl = baseUrl + 
        "?latitude=" + encodeURIComponent(lat) +
        "&longitude=" + encodeURIComponent(lon) +
        "&hourly=temperature_2m,apparent_temperature,surface_temperature,dewpoint_2m,relativehumidity_2m,rain,showers,snowfall,wind_speed_10m,wind_gusts_10m,wind_direction_10m,precipitation_probability" +
        "&minutely_15=rain,snowfall" +
        "&timezone=auto";
    
    const message = Soup.Message.new('GET', requestUrl);

    _httpSession.send_and_read_async(message, GLib.PRIORITY_DEFAULT, null, (session, result) => {
        try {
            const bytes = session.send_and_read_finish(result);
            if (message.status_code === 200) {
                const decoder = new TextDecoder('utf-8');
                const responseString = decoder.decode(bytes.get_data());
                const data = JSON.parse(responseString);
                fetchSuccess(data);
            } else {
                fetchFailure(new Error("HTTP " + message.status_code));
            }
        } catch (e) {
            fetchFailure(e);
        }
    });
}

class SlipperyDesklet extends Desklet.Desklet {
    constructor(metadata, deskletId) {
        super(metadata, deskletId);
        this._initUi();

        this._settings = new Settings.DeskletSettings(this, metadata.uuid, deskletId);
        this._locations = [];
        this._currentData = {};
        this._colorMode = "bright";
        this._useHsp = true;
        this._hspThreshold = 127;
        this._minLevel = "always";

        this._loadSettings();
        this._fetchAllLocations();

        this._timeoutId = Mainloop.timeout_add_seconds(900, () => {
            this._fetchAllLocations();
            return true;
        });
    }

    _initUi() {
        this._mainBox = new St.BoxLayout({
            vertical: true,
            style_class: "slippery-desklet-box"
        });
        this.setContent(this._mainBox);

        this._headerLabel = new St.Label({
            text: "Slippery Desklet",
            style_class: "title"
        });
        this._mainBox.add_actor(this._headerLabel);

        this._locationsBox = new St.BoxLayout({
            vertical: true
        });
        this._mainBox.add_actor(this._locationsBox);

        this._addNoDataView();
    }

    _addNoDataView() {
        if (!this._noDataLabel) {
            this._noDataLabel = new St.Label({
                text: "No locations configured",
                style_class: "dim-label"
            });
            this._locationsBox.add_actor(this._noDataLabel);
        }
    }

    _loadSettings() {
        try {
            this._settings.bind("color-mode", "colorMode", () => {});
            this._settings.bind("use-hsp-text", "useHsp", () => {});
            this._settings.bind("hsp-threshold", "hspThreshold", () => {});
            this._settings.bind("color-min-level", "minLevel", () => {});
            
            this._loadLocationsFromSettings();
        } catch (e) {
            global.log("Slippery Desklet: could not load settings, using defaults");
        }
    }

    _loadLocationsFromSettings() {
        this._locations = [];
        for (let i = 1; i <= 5; i++) {
            const nameKey = "location-" + i + "-name";
            const coordsKey = "location-" + i + "-coords";
            const enabledKey = "location-" + i + "-enabled";
            
            let name = this._settings.getValue(nameKey) || "";
            let coords = this._settings.getValue(coordsKey) || "";
            let enabled = this._settings.getValue(enabledKey);
            
            if (enabled && name && coords) {
                let parsed = parseCoordField(coords);
                if (parsed) {
                    this._locations.push({ id: i, name: name, lat: parsed.lat, lon: parsed.lon, enabled: true });
                }
            }
        }
        this._updateDisplay();
    }

    _fetchAllLocations() {
        if (this._locations.length === 0) return;
        
        let loaded = 0;
        let total = this._locations.length;
        this._currentData = {};
        
        for (let loc of this._locations) {
            fetchWeather(loc.lat, loc.lon, (data) => {
                loaded++;
                this._processWeatherData(loc.id, data);
                if (loaded >= total) {
                    this._updateDisplay();
                }
            }, (error) => {
                loaded++;
                global.log("Slippery Desklet: fetch error for location " + loc.id + ": " + error.message);
                if (loaded >= total) {
                    this._updateDisplay();
                }
            });
        }
    }

    _processWeatherData(locId, data) {
        if (!data || !data.hourly || !data.hourly.time || data.hourly.time.length === 0) {
            this._currentData[locId] = null;
            return;
        }

        const hourly = data.hourly;
        const times = hourly.time;
        let targetIdx = 0;
        const nowSec = Date.now() / 1000;
        
        for (let i = 0; i < times.length; i++) {
            let tSec = Math.floor(new Date(times[i]).getTime() / 1000);
            if (tSec <= nowSec) targetIdx = i;
            else break;
        }

        const at = (arr, i) => (i < arr.length && arr[i] != null ? arr[i] : 0);

        const airT = at(hourly.temperature_2m, targetIdx);
        const feelT = at(hourly.apparent_temperature, targetIdx);
        const surfT = at(hourly.surface_temperature, targetIdx);
        const dewP = at(hourly.dewpoint_2m, targetIdx);
        const hum = at(hourly.relativehumidity_2m, targetIdx);
        const rain = at(hourly.rain, targetIdx);
        const showers = at(hourly.showers, targetIdx);
        const snow = at(hourly.snowfall, targetIdx);
        const windS = at(hourly.wind_speed_10m, targetIdx);
        const windG = at(hourly.wind_gusts_10m, targetIdx);
        const windD = at(hourly.wind_direction_10m, targetIdx);

        let rain12 = 0, snow12 = 0;
        for (let j = Math.max(0, targetIdx - 12); j <= targetIdx; j++) {
            rain12 += at(hourly.rain, j) + at(hourly.showers, j);
            snow12 += at(hourly.snowfall, j);
        }
        
        let dry = 0;
        for (let k = targetIdx - 1; k >= 0 && dry < 24; k--) {
            if (at(hourly.rain, k) + at(hourly.showers, k) <= 0.1 && at(hourly.snowfall, k) <= 0.1) dry++;
            else break;
        }

        let locObj = this._locations.find(l => l.id === locId);
        const season = getSeason(locObj ? locObj.lat : 0, new Date());

        const r = evaluateRisk({
            airTemp: airT,
            surfaceTemp: surfT,
            dewPoint: dewP,
            humidity: hum,
            rainCurrent: rain + showers,
            runningRain12h: rain12,
            runningSnow12h: snow12,
            dryStreak: dry,
            season: season,
            windSpeed: windS,
            windGust: windG,
            immediateRain: -1,
            immediateSnow: -1,
            surfaceDewSpread: surfT - dewP,
            snowCurrent: snow,
            upcomingRain: 0,
        });

        this._currentData[locId] = {
            risk: r,
            season: season,
            airTemp: airT,
            surfaceTemp: surfT,
            feelsLike: feelT,
            dewPoint: dewP,
            humidity: hum,
            rainCurrent: rain + showers,
            snowCurrent: snow,
            windSpeed: windS,
            windGust: windG,
            windDir: windD,
            rain12: rain12,
            snow12: snow12,
            dryStreak: dry
        };
    }

    _updateDisplay() {
        while (this._locationsBox.get_n_children() > 0) {
            this._locationsBox.remove_child(this._locationsBox.get_child_at_index(0));
        }

        if (this._locations.length === 0) {
            this._addNoDataView();
            return;
        }

        this._noDataLabel = null;
        for (let loc of this._locations) {
            if (!this._currentData[loc.id]) continue;
            this._addLocationChip(loc);
        }
    }

    _addLocationChip(loc) {
        const data = this._currentData[loc.id];
        if (!data || !data.risk) return;

        const risk = data.risk;
        const chip = new St.BoxLayout({
            vertical: false,
            style_class: "slippery-chip"
        });

        const chipStyleStr = chipStyle(this._colorMode, this._minLevel, risk.level, risk.name, this._useHsp, this._hspThreshold);
        if (chipStyleStr) {
            chip.set_style(chipStyleStr);
        }

        const riskLabel = new St.Label({
            text: SHORT_LABEL[risk.name] || risk.name,
            style_class: "slippery-risk-label"
        });
        chip.add_actor(riskLabel);

        let tempText = data.airTemp !== undefined ? " " + data.airTemp.toFixed(1) + "°C" : "";
        const tempLabel = new St.Label({
            text: tempText,
            style_class: "slippery-temp-label"
        });
        chip.add_actor(tempLabel);

        if (risk.hazards && risk.hazards.length > 0) {
            const hazardsText = risk.hazards.slice(0, 3).map(h => h.split(" ")[0]).join(" + ");
            const hazardsLabel = new St.Label({
                text: " [" + hazardsText + "]",
                style_class: "slippery-hazards-label"
            });
            chip.add_actor(hazardsLabel);
        }

        this._locationsBox.add_actor(chip);
    }

    on_desklet_removed() {
        if (this._timeoutId) {
            Mainloop.source_remove(this._timeoutId);
            this._timeoutId = null;
        }
    }
}

function main(metadata, deskletId) {
    return new SlipperyDesklet(metadata, deskletId);
}