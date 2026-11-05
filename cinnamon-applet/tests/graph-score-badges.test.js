const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const appletDir = path.join(__dirname, "../slippery@local");
const schema = JSON.parse(fs.readFileSync(path.join(appletDir, "settings-schema.json"), "utf8"));
const boundKeys = [];
const context = vm.createContext({
    Date,
    imports: {
        ui: {
            applet: {
                TextApplet: function () {},
                AppletPopupMenu: function () {},
            },
            settings: {
                AppletSettings: function (settings) {
                    this.bind = (key) => {
                        assert.ok(schema[key], "Bound setting exists: " + key);
                        boundKeys.push(key);
                        settings[key] = schema[key].default;
                    };
                },
            },
            popupMenu: {
                PopupMenuManager: function () { this.addMenu = () => {}; },
            },
        },
        mainloop: {},
        gi: { Gio: {}, GLib: {} },
        byteArray: {},
    },
});
context.imports.ui.applet.TextApplet.prototype._init = () => {};
vm.runInContext(fs.readFileSync(path.join(appletDir, "applet.js"), "utf8"), context);

const scores = [6, 9, 1, 8, 5, 2, 10, 4];
const hours = scores.map((score, i) => ({
    time: new Date(2026, 10, 3 + Math.floor(i / 4), i % 4),
    name: "SAFE",
    temp: 10,
    wind: 5,
    gust: 7,
    score,
}));
const render = (options = {}) => context.buildGraphSvg({ hours, ...options });
const badgePattern = /<text [^\n]*font-size="10" font-weight="bold" text-anchor="middle">([^<]+)<\/text>\n/g;
const badges = (svg) => Array.from(svg.matchAll(badgePattern), (match) => Number(match[1]));

test("score badge switch is listed, bound, default-on and passed to graph options", () => {
    assert.equal(schema["graph-show-score-badges"].type, "switch");
    assert.equal(schema["graph-show-score-badges"].default, true);
    assert.ok(schema.layout["section-graph-traces"].keys.includes("graph-show-score-badges"));
    const applet = Object.create(context.SlipperyApplet.prototype);
    for (const method of ["set_applet_label", "set_applet_tooltip", "_schedule", "refresh"]) {
        applet[method] = () => {};
    }
    applet._startupDelaySec = () => 0;
    applet._init({}, 0, 24, 1);
    assert.ok(boundKeys.includes("graph-show-score-badges"));
    assert.ok(boundKeys.includes("graph-score-badge-position"));
    assert.equal(schema["graph-score-badge-position"].default, "curve");
    assert.ok(schema.layout["section-graph-traces"].keys.includes("graph-score-badge-position"));
    assert.equal(applet._graphTracesOpts().scoreBadges, true);
    applet.s["graph-show-score-badges"] = false;
    assert.equal(applet._graphTracesOpts().scoreBadges, false);
    delete applet.s["graph-show-score-badges"];
    assert.equal(applet._graphTracesOpts().scoreBadges, true);
});

for (const [values, expected] of [
    ["all", scores],
    ["alternate", [6, 1, 5, 10]],
    ["peak", [1, 10]],
    ["peak-day", [9, 1, 2, 10]],
    ["none", []],
]) {
    test("score badges follow value-label mode: " + values, () => {
        assert.deepEqual(badges(render({ values })), expected);
    });

    test("bottom risk badges show every score regardless of value-label mode: " + values, () => {
        assert.deepEqual(badges(render({ values, scoreBadgePosition: "risk-strip" })), scores);
    });

    test("bottom placement has no effect when badges are hidden: " + values, () => {
        const traces = { scoreBadges: false };
        assert.equal(render({ values, traces, scoreBadgePosition: "risk-strip" }), render({ values, traces }));
    });

    test("hidden position hides only badges regardless of value-label mode: " + values, () => {
        assert.equal(schema["graph-score-badge-position"].options.Hidden, "hidden");
        const hidden = render({ values, scoreBadgePosition: "hidden" });
        assert.deepEqual(badges(hidden), []);
        assert.equal(hidden, render({ values, traces: { scoreBadges: false } }));
    });

    test("hiding badges preserves all other graph output: " + values, () => {
        const shown = render({ values });
        const hidden = render({ values, traces: { scoreBadges: false } });
        assert.deepEqual(badges(hidden), []);
        assert.equal(hidden, shown.replace(badgePattern, ""));
        assert.match(hidden, /ride score/);
        assert.equal((hidden.match(/<line data-trace="score"[^>]*stroke-width="3\.5"/g) || []).length, hours.length - 1);
    });
}

test("missing setting preserves hourly badges", () => {
    assert.deepEqual(badges(render()), scores);
});

test("tied score extrema select the first hour without duplicate badges", () => {
    const tied = hours.map((hour) => ({ ...hour, score: 0 }));
    assert.deepEqual(badges(render({ hours: tied, values: "peak" })), [0]);
    assert.deepEqual(badges(render({ hours: tied, values: "peak-day" })), [0, 0]);
});

test("missing scores are not rendered or selected as extrema", () => {
    const mixed = [null, undefined, NaN, 0, 10].map((score, i) => ({ ...hours[i], score }));
    for (const values of ["all", "peak", "peak-day"]) {
        assert.deepEqual(badges(render({ hours: mixed, values })), [0, 10]);
    }
});

test("empty forecast produces no graph", () => {
    assert.equal(render({ hours: [] }), "");
});

test("curve placement preserves default output", () => {
    assert.equal(render({ scoreBadgePosition: "curve" }), render());
});

test("bottom badges fit inside their risk rectangles without moving the score curve", () => {
    for (const count of [8, 48, 336]) {
        const forecast = Array.from({ length: count }, (_, i) => ({
            ...hours[i % hours.length],
            name: ["SAFE", "SLIGHT", "MODERATE", "HIGH", "CRITICAL", "NO_DATA"][i % 6],
            score: 10,
            ice: i === 0,
        }));
        const svg = render({ hours: forecast, scoreBadgePosition: "risk-strip" });
        const rects = Array.from(svg.matchAll(/<rect x="([^"]+)" y="800" width="([^"]+)" height="18"[^>]*>/g));
        const labels = Array.from(svg.matchAll(badgePattern));
        assert.equal(rects.length, count);
        assert.equal(labels.length, count);
        for (let i = 0; i < count; i++) {
            const label = labels[i][0];
            const x = Number(label.match(/ x="([^"]+)"/)[1]);
            const y = Number(label.match(/ y="([^"]+)"/)[1]);
            assert.ok(Math.abs(x - (Number(rects[i][1]) + Number(rects[i][2]) / 2)) < 0.15);
            assert.ok(y - 10 >= 800 && y <= 818);
            assert.match(label, /fill="#000"/);
            if (count > 48) {
                assert.ok(Number(label.match(/textLength="([^"]+)"/)[1]) < Number(rects[i][2]));
                assert.match(label, /lengthAdjust="spacingAndGlyphs"/);
            }
        }
        assert.match(rects[0][0], /stroke="#4dd0e1"/);
        assert.match(svg, /height="902"/);
        const curves = (output) => output.match(/<line data-trace="score"[^>]*\/>/g);
        assert.deepEqual(curves(svg), curves(render({ hours: forecast })));
        const textYs = Array.from(svg.matchAll(/<text [^>]*y="([^"]+)"/g), (match) => Number(match[1]));
        assert.ok(Math.max(...textYs) < 902);
    }
});

const weatherHours = hours.map((hour) => ({
    ...hour, temp: 20, sfc: 15, dew: 10, sun: 2160,
    wind: 5, gust: 7, humidity: 65, prob: 25,
}));
const attr = (svg, name) => {
    const match = svg.match(new RegExp(' ' + name + '="([^"]*)"'));
    return match ? match[1] : null;
};

test("weather traces and legend samples use matching, distinct styles", () => {
    const svg = render({ hours: weatherHours });
    const expected = [
        ["temp", "#ff5252", "2", null],
        ["sfc", "#ffa040", "2", "12,5"],
        ["dew", "#bdbdbd", "2", "4,4"],
        ["sun", "#ffd24a", "1.5", null],
        ["wind", "#fff", "1.5", "10,4,2,4"],
        ["hum", "#4dd0e1", "1.5", "12,6"],
        ["prob", "#5b9bff", "1.5", "0.1,5"],
    ];
    for (const [key, color, width, dash] of expected) {
        const trace = svg.match(new RegExp('<path data-trace="' + key + '"[^>]*>'))[0];
        const legend = svg.match(new RegExp('<g data-legend="' + key + '">([\\s\\S]*?)</g>'))[1];
        const sample = legend.match(/<line [^>]*>/)[0];
        for (const element of [trace, sample]) {
            assert.equal(attr(element, "stroke"), color);
            assert.equal(attr(element, "stroke-width"), width);
            assert.equal(attr(element, "stroke-dasharray"), dash);
            assert.equal(attr(element, "stroke-linecap"), "round");
        }
        if (key === "sun") assert.match(legend, /<circle /);
        if (key === "hum") assert.match(legend, /<rect /);
    }
    const score = svg.match(/<line data-trace="score"[^>]*>/)[0];
    assert.equal(attr(score, "stroke-width"), "3.5");
    assert.equal(attr(score, "stroke-linecap"), "round");
});

test("hidden traces have no paths, legend samples or endpoint labels", () => {
    const traces = { temp: false, sfc: false, dew: false, sun: false, wind: false, hum: false, prob: false };
    const svg = render({ hours: weatherHours, traces });
    assert.doesNotMatch(svg, /<path data-trace=|data-legend=|data-endpoint=|<circle /);
});

test("endpoint labels identify all separated weather traces even with value labels disabled", () => {
    const svg = render({ hours: weatherHours, values: "none" });
    const endpoints = Array.from(svg.matchAll(/<text data-endpoint="([^"]+)"[^>]*>[^<]*<\/text>/g));
    assert.deepEqual(endpoints.map((match) => match[1]).sort(), ["dew", "hum", "prob", "sfc", "sun", "temp", "wind"]);
    for (const endpoint of endpoints) {
        assert.ok(Number(attr(endpoint[0], "x")) > 1772);
        assert.ok(Number(attr(endpoint[0], "y")) >= 88);
        assert.ok(Number(attr(endpoint[0], "y")) <= 796);
    }
    assert.deepEqual(badges(svg), []);
});

test("crowded endpoints omit overlapping labels and invalid final values", () => {
    const crowded = weatherHours.map((hour) => ({
        ...hour, temp: 10, sfc: 10, dew: 10, humidity: 50, prob: 50,
    }));
    crowded[crowded.length - 1].dew = null;
    crowded[crowded.length - 1].sfc = NaN;
    const svg = render({ hours: crowded });
    assert.doesNotMatch(svg, /data-endpoint="dew"|data-endpoint="sfc"/);
    const ys = Array.from(svg.matchAll(/<text data-endpoint="[^"]+"[^>]*y="([^"]+)"/g), (match) => Number(match[1]));
    assert.ok(ys.length >= 2 && ys.length < 7);
    for (let i = 1; i < ys.length; i++) assert.ok(ys[i] - ys[i - 1] >= 16);
});

test("sunshine and humidity markers stay sparse on long forecasts", () => {
    const forecast = Array.from({ length: 336 }, (_, i) => ({ ...weatherHours[i % weatherHours.length] }));
    const svg = render({ hours: forecast });
    const plot = svg.slice(0, svg.indexOf('<g data-legend='));
    assert.equal((plot.match(/<circle /g) || []).length, 12);
    assert.equal((plot.match(/<rect [^>]*width="6" height="6"/g) || []).length, 12);
});

test("legend entries remain inside the SVG for either unit system", () => {
    for (const units of ["metric", "imperial"]) {
        const svg = render({ hours: weatherHours, units });
        const width = Number(attr(svg.match(/<svg [^>]*>/)[0], "width"));
        const legend = svg.slice(svg.indexOf("ride score (0–10)</text>"));
        for (const match of legend.matchAll(/<text x="([^"]+)"[^>]*>([^<]*)<\/text>/g)) {
            assert.ok(Number(match[1]) + match[2].length * 7 < width);
        }
    }
});

test("graph action passes saved badge placement and defaults to curve", () => {
    const applet = Object.create(context.SlipperyApplet.prototype);
    applet.s = {};
    applet._maybeResetGraphColors = () => {};
    applet._maybeResetIceChipColor = () => {};
    const entry = {
        loc: { name: "Test", lat: 0, lon: 0 },
        parsed: { risk: { name: "SAFE", hazards: [], advice: [] }, time: new Date(), windSpeed: 0, windGust: 0 },
        profile: [{ time: new Date(), score: 8 }],
    };
    const build = context.buildGraphSvg;
    let options;
    context.buildGraphSvg = (value) => { options = value; return ""; };
    try {
        applet._openGraph(entry);
        assert.equal(options.scoreBadgePosition, "curve");
        applet.s["graph-score-badge-position"] = "risk-strip";
        applet._openGraph(entry);
        assert.equal(options.scoreBadgePosition, "risk-strip");
    } finally {
        context.buildGraphSvg = build;
    }
});
