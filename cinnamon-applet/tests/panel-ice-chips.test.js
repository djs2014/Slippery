const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

class Widget {
    constructor(options = {}) {
        Object.assign(this, options);
        this.children = [];
    }
    add_actor(child) { this.children.push(child); }
    set_style(style) { this.style = style; }
    destroy() {}
    hide() {}
    show() {}
    connect() {}
}

const context = vm.createContext({
    Date,
    imports: {
        ui: {
            applet: { TextApplet: function () {} },
            settings: {},
            popupMenu: { PopupMenuItem: Widget, PopupSeparatorMenuItem: Widget },
        },
        mainloop: {},
        gi: { Gio: {}, GLib: {}, St: { BoxLayout: Widget, Label: Widget } },
        byteArray: {},
    },
});
vm.runInContext(fs.readFileSync(
    path.join(__dirname, "../slippery@local/applet.js"), "utf8"
), context);

const ICE_COLOR = "#abcdef";
const calm = {};
const frost = { air: -2, surface: 0, dew: -2, humidity: 80 };
const bridge = { air: 3, surface: 8, humidity: 90 };
const gale = { wind: 45, gust: 60 };

function entry(name, weather = calm) {
    const now = Math.floor(Date.now() / 3600000) * 3600;
    const fill = (value) => Array(14).fill(value);
    const data = {
        hourly: {
            time: Array.from({ length: 14 }, (_, i) => now + (i - 12) * 3600),
            temperature_2m: fill(weather.air ?? 20),
            surface_temperature: fill(weather.surface ?? 20),
            dewpoint_2m: fill(weather.dew ?? 10),
            relativehumidity_2m: fill(weather.humidity ?? 50),
            rain: fill(0), showers: fill(0), snowfall: fill(0),
            wind_speed_10m: fill(weather.wind ?? 5),
            wind_gusts_10m: fill(weather.gust ?? 7),
        },
    };
    return { loc: { name, lat: 0, lon: 0 }, parsed: context.parseResponse(0, data, now) };
}

function applet(settings = {}, fallback = false) {
    const value = Object.create(context.SlipperyApplet.prototype);
    value.s = {
        "panel-chip-locations": "all",
        "panel-chip-alert-level": "high",
        "popup-display-mode": "buttons-only",
        "ice-chip-enabled": true,
        "ice-chip-color": ICE_COLOR,
        "ice-chip-hours": 24,
        "forecast-hours": 12,
        "forecast-days": 0,
        "show-peak-risk": false,
        ...settings,
    };
    value.actor = new Widget();
    value._applet_label = new Widget();
    value.menu = { removeAll() {}, addMenuItem() {} };
    value.set_applet_label = (label) => { value.label = label; };
    value.set_applet_tooltip = () => {};
    value._panelAlertsToday = () => true;
    value.locationStyles = [];
    value._addLocationBlock = (result, idx, thresholds, hours, days, options) => {
        value.locationStyles.push(options.iceChip.hasIce);
    };
    if (fallback) value._renderChipMulti = () => false;
    return value;
}

function chips(value) {
    return value._chipBox.children.filter((child) => child.text !== "|");
}

function isIce(widget) {
    return widget.style.includes("background-color: " + ICE_COLOR + ";");
}

test("the selected best secondary chip uses its own ice forecast", () => {
    const value = applet();
    value._showAll([entry("Primary"), entry("Calm"), entry("Frozen", frost)]);
    const shown = chips(value);
    assert.equal(shown.length, 2);
    assert.match(shown[1].text, /F /);
    assert.deepEqual(shown.map(isIce), [false, true]);
});

test("primary ice does not color an ice-free secondary chip", () => {
    const value = applet();
    value._showAll([entry("Primary", frost), entry("Calm")]);
    assert.deepEqual(chips(value).map(isIce), [true, false]);
});

test("ice in an unselected secondary location does not color displayed chips", () => {
    const value = applet();
    value._showAll([entry("Primary"), entry("Bridge", bridge), entry("Windy", gale)]);
    const shown = chips(value);
    assert.match(shown[1].text, /W /);
    assert.deepEqual(shown.map(isIce), [false, false]);
});

test("a missing secondary forecast does not inherit primary ice", () => {
    const value = applet();
    value._showAll([entry("Primary", frost), { loc: { name: "Missing" }, error: "No data" }]);
    assert.deepEqual(chips(value).map(isIce), [true, false]);
});

test("primary-mode alert segments retain their location-specific ice flags", () => {
    const value = applet({ "panel-chip-locations": "primary" });
    value._showAll([entry("Primary"), entry("Frozen", frost)]);
    assert.deepEqual(chips(value).map(isIce), [false, true]);
});

for (const mode of ["all", "primary"]) {
    test(mode + " single-chip fallback includes ice from the displayed secondary", () => {
        const value = applet({ "panel-chip-locations": mode }, true);
        value._showAll([entry("Primary"), entry("Frozen", frost)]);
        assert.ok(isIce(value.actor));
        assert.deepEqual(value.locationStyles, [false, true]);
    });
}

test("single-chip fallback ignores ice from unselected locations", () => {
    const value = applet({}, true);
    value._showAll([entry("Primary"), entry("Bridge", bridge), entry("Windy", gale)]);
    assert.equal(isIce(value.actor), false);
});

test("disabling ice colors preserves normal per-location risk colors", () => {
    const value = applet({ "ice-chip-enabled": false });
    value._showAll([entry("Primary"), entry("Frozen", frost)]);
    assert.deepEqual(chips(value).map(isIce), [false, false]);
    assert.match(chips(value)[1].style, /background-color: #ff0000;/);
});

test("follow-theme mode still suppresses custom chip colors", () => {
    const value = applet({ "color-mode": "follow-theme" });
    value._showAll([entry("Primary"), entry("Frozen", frost)]);
    assert.deepEqual(chips(value).map(isIce), [false, false]);
});
