## Overview

**Yes—meaningful presets are feasible, but I would not expose every constant or simply replace them with existing `thresh*` fields.**

Currently, `RiskCalculator` computes the highest triggered risk and collects hazards/advice. Existing thresholds belong to `AlertStateAnalyzer`: they select the banner, not the risk level.

Recommended model:

- **Cautious:** earlier warnings and wider safety margins.
- **Normal:** exactly today’s calculation.
- **Relaxed:** fewer low/moderate warnings, without weakening serious ice/extreme-weather protection.
- **Custom:** bounded advanced adjustments.

“Relaxed” is preferable to “Risky”: the preset changes warning sensitivity, not whether conditions are objectively safe.

## 1. Which hardcoded values are useful settings?

Values below are from `the risk rules`.

| Area | Current values | Meaningful configuration |
|---|---|---|
| Wet-road ice | Surface ≤ **3°C** OR air ≤ **2°C**, plus precipitation evidence | **Ice safety margin**, ideally separate surface/air thresholds. Cautious can warn warmer; avoid allowing relaxed settings to suppress genuine freezing-wet-road warnings. |
| Frost | Surface ≤ **3°C**, surface–dew spread ≤ **2°C**, humidity ≥ **80%** | Surface temperature margin is useful. Humidity/dew gates are model calibration: advanced-only or fixed. |
| Bridge ice | Air **−1 to 3.5°C**; historical precipitation OR humidity > **88%** | Upper temperature margin is useful. Keep the lower bound separate; shifting the whole interval can remove warnings at colder temperatures. |
| Snow/slush | Historical snow ≥ **0.1 cm**; surface ≤ **0°C** OR air ≤ **1.5°C** | Snow amount and settling-temperature margin could be advanced controls. Do not tie these implicitly to the main ice setting. |
| Meaningful precipitation | Rain **0.1**, snow **0.1** | Primarily detection/model thresholds, not rider preference. Keep separate by precipitation type and accumulation period. |
| Rain severity | Slight **0.2**, Moderate **2.5**, High **7.5**, Critical **15 mm/h** | A **rain sensitivity** control is useful, particularly the lower tiers. Retain severe-downpour protection. |
| First-rain oil slick | Spring/summer; rain **0.1–<2.5 mm/h**; preceding dry streak ≥ **10 h** | **Dry-spell sensitivity** is useful; precipitation bounds should reuse relevant rain settings. Season gating should initially stay fixed. |
| Wet leaves | Autumn + current/historical precipitation above detection threshold | Keep enabled; share wetness detection. A threshold cannot infer actual leaf coverage. |
| Dew/wet road | Surface > **0°C**, humidity > **90%**, surface–dew spread ≤ **1°C** | Optional advanced **dew sensitivity**. Keep freezing point separate from preference margins. |
| Sustained wind | Slight **20**, Moderate **25**, High **35**, Critical **45 km/h** | Strong candidate for **wind sensitivity**, reflecting exposure, bike setup and rider stability. |
| Absolute gust | Moderate **35**, High **45**, Critical **60 km/h** | Strong candidate, but separate from sustained wind and directional crosswind. |
| Gust-ratio triggers | Moderate **1.3** with wind ≥ **18**; High **1.5** with ≥ **25**; Critical **1.7** with ≥ **35 km/h** | Preset-controlled or advanced-only. Always preserve minimum base-wind gates to avoid near-calm false alarms. |
| Imminent precipitation | Rain Moderate, upgraded to High when upcoming intensity ≥ **2.5 mm/h**; snow High | Share the steady-rain threshold. A separate **early-warning preference** is more meaningful than arbitrary severity editing. |

### Why not expose `ICE_T` directly?

It currently controls **five different temperature boundaries** through formulas:

- Wet-road surface: `ICE_T`
- Wet-road air: `ICE_T × 0.5 + 0.5`
- Bridge interval: `ICE_T − 4` to `ICE_T + 0.5`
- Snow-settling surface: `ICE_T − 3`
- Snow-settling air: `ICE_T − 1.5`

Increasing `ICE_T` therefore also changes snow-settling assumptions and moves the bridge interval. **Extract named boundaries first**, preserving their current defaults.

## 2. Can existing `thresh*` fields be reused?

From `settings loading`:

| Existing field | Reuse recommendation |
|---|---|
| `threshIceAlert` = **3°C** | Can represent a shared ice warning margin, but banner temperature alone must not replace risk-engine moisture/frost conditions. Explicitly opt into linking. |
| `threshSustainedWind` = **25 km/h** | Matches the Moderate sustained-wind boundary. A good shared candidate. |
| `threshHeavyWind` = **35 km/h** | Matches the High sustained-wind boundary. Reusable numerically, although banner and risk-tier names differ. |
| `threshCrossGust` / `threshHighCrosswind` = **18 / 25 km/h** | **Do not use as absolute gust thresholds.** These measure the lateral gust component relative to rider heading; risk calculation uses ambient wind/gust. |
| `threshPrecipAhead` = **0.5 mm/h** | Keep separate from **0.1** wetness detection. It controls significant forecast precipitation highlighting/banner warnings, not evidence that roads may be wet. |
| `threshHeadwind` / `threshHeatStress` | Keep banner/pacing/comfort-only; neither currently participates in the risk calculation. |

**Reuse the setting mechanism freely; reuse individual values only when their meaning matches.** Avoid making the risk engine depend directly on the banner analyzer.

## 3. Suggested initial presets

These are **starting proposals for testing**, not scientifically validated replacements.

| Control | Cautious | Normal | Relaxed |
|---|---:|---:|---:|
| Wet-road ice surface / air | 4 / 3°C | 3 / 2°C | Keep Normal protection |
| Bridge upper temperature | 4.5°C | 3.5°C | Keep Normal protection |
| Slight / Moderate rain | 0.1 / 2 mm/h | 0.2 / 2.5 mm/h | 0.5 / 3 mm/h |
| First-rain dry hours | 6 h | 10 h | 12 h |
| Slight / Moderate / High sustained wind | 18 / 22 / 30 km/h | 20 / 25 / 35 km/h | 22 / 28 / 35 km/h |
| Moderate gust threshold | 30 km/h | 35 km/h | 40 km/h |

Initially keep Critical thresholds, precipitation detection floors, frost moisture gates and gust-ratio safeguards unchanged. Do not apply one global multiplier: temperature, humidity, rain intensity and time need different treatment.

## 4. Implementation plan

1. **Extract one typed risk configuration.**  
   Replace literals with named fields; Normal must retain exact existing comparisons, hazard lists and severity results.

2. **Add preset plus limited custom settings.**  
   Use existing storage, `selection picker and numeric-menu patterns`. Add a “Risk sensitivity” section; keep banner thresholds clearly distinguished. Preserve existing user values during migration.

3. **Resolve configuration once when settings load.**  
   Validate numeric types, bounds and ascending severity thresholds. Report invalid settings explicitly. Avoid storage reads during every forecast-hour evaluation.

4. **Wire live, forecast and demo consistently.**  
   `RiskProjectionEngine` already calls the same calculator, but duplicates precipitation/dry-streak thresholds. `WeatherService` also duplicates them.

   Important: minutely precipitation uses **amount per 15-minute interval**, while hourly rain uses **mm/h**. Its current `0.1` detection threshold is not interchangeable without conversion. Historical sums also need accumulation units, not rate labels.

5. **Apply changes immediately to cached weather.**  
   `onSettingsChanged` currently only reloads settings. Recalculate and refresh the current assessment, forecast levels, ice flags and displayed advice; reparse cached data if detection settings affect derived metrics.

6. **Preserve separate visual semantics.**  
   Gust bars use `their own exposure calculation`, currently **22/32/45 km/h plus gust deltas**, not the thresholds claimed in some comments/documentation. Decide explicitly whether presets affect these bars; do not accidentally equate them with risk tiers.

7. **Test and document.**  
   Extend `existing risk tests` with boundary cases, Normal regression, preset monotonicity, live/forecast agreement, unit conversions, invalid settings, migration and immediate refresh. Update `the README’s fixed-threshold description`.

**Recommended first scope:** presets for ice margin, lower rain tiers, first-rain dry hours and wind sensitivity. Keep the remaining model constants internal until scenario tests justify exposing them.



------
hardcoded risk values or not?

show drawScoreBadges in connect IQ
-> show rules
function rateCyclingHour(hh, iceT) {
    let score = 10.0;
    const isIcy = hh.ice || (hh.surfaceTemp !== undefined && hh.surfaceTemp !== null && hh.surfaceTemp <= iceT);
    if (isIcy) return 0.0;

    const temp = hh.airTemp;
    if (temp !== undefined && temp !== null) {
        if (temp < 10) score -= Math.min(4.0, (10 - temp) * 0.4);
        else if (temp < 18) score -= (18 - temp) * 0.15;
        else if (temp > 30) score -= Math.min(5.0, (temp - 30) * 0.5);
        else if (temp > 24) score -= (temp - 24) * 0.05;
    }

    const precip = (hh.rain || 0) + (hh.snow || 0);
    if (precip >= 7.5) score -= 5.0;
    else if (precip >= 2.5) score -= 3.0;
    else if (precip > 0) score -= 1.5;

    if (hh.dewPoint > 18) score -= 1.5;
    else if (hh.dewPoint > 15) score -= 0.7;

    const wind = Math.max(hh.windSpeed || 0, hh.windGust || 0);
    if (wind >= 45) score -= 5.0;
    else if (wind >= 35) score -= 3.0;
    else if (wind >= 25) score -= 1.5;
    else if (wind >= 18) score -= 0.5;

    return Math.max(0, Math.min(10, Math.round(score * 10) / 10));
}


risk footer align large / one / small field

- linux taskbar app for local use
- weather app also same track heading mechanism / edgefield

52.352547, 4.852022
69.840043, 26.883803
64.66204068732797, -19.170883997217427 iceland
Girona
42.046663, 2.775519

list some lat/lon with interesting wheater situations for testing purpose


analyze bg service /numeric input etc.

panel chip locations
primare or high risk 

sparkline arrows larger
option bigger arrow
one field - no hazards -> higher forecast..

display best hour in graph
option what to display in the graph
- wind/ sun / etc


The change in riskCalculator.mc uses a fixed 3.0°C reference, the same as the applet:

Hazard	Was	Now
Black ice	surface ≤ 0 or air ≤ 0.5	surface ≤ 3 or air ≤ 2
Surface frost	surface ≤ 0	surface ≤ 3
Bridge ice	air 0 to 2.5	air −1 to 3.5
Snow/slush	surface ≤ 1 or air ≤ 1.5	surface ≤ 0 or air ≤ 1.5
This affects more than the ice warning. These hazards also feed the overall risk level, so Connect IQ will now show critical or high risk more often in near-freezing conditions, just as the applet does.

I also updated the hazard table in readme.md. In iceHazardForecastTest.mc I moved the existing tests to the new boundary values and added one using the Keesing 02:00 forecast values.

Two differences remain:

Time window: Connect IQ looks 12 hours ahead, while your applet ice chip uses 24 hours. Ice between 12 and 24 hours ahead will only show in the applet; tonight's ice starts at +10 h, so both catch it.
Your applet threshold setting: the applet always uses 3.0°C for these hazards and ignores your thresh-ice-alert setting of 1.5. Connect IQ now does the same with its threshIceAlert setting.


==>
alert settings config central
what are usefull settings for risk 
preset - cautius, normal, risky


analyse #sym:RiskCalculator list what values like ICE_T, RAIN tresholds and other hardcoded values in risk calculation can be configurable in a meaningfull way. Like presets: caution, normal, risky etc.
give overview and plan to make these as settings (can thresh* fields be used too?)