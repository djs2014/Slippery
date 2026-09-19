Slippery

Evaluates real-time weather and surface dynamics to compute cycling-specific hazard levels, hazard types, and actionable safety advice.
Designed for high-performance Connect IQ head units, it translates raw atmospheric metrics into instant situational awareness on the bike.

Source of weather data is [Open-Meteo](https://open-meteo.com) (hourly + `minutely_15` forecast, fetched in background via phone).

Can show if the road is slippery for cycling.

How it works: two layers

1. Slip-risk engine (`RiskCalculator`, fixed physics thresholds, not user-configurable).
   Evaluates current hour + projects current hour + next 12 hours. Highest triggered rule wins
   (`Safe < Slight < Moderate < High < Critical`). Hazards and advice queue up simultaneously.
2. Alert banner (`AlertStateAnalyzer`, user-configurable thresholds, see Settings > Thresholds).
   Picks one dominant alert state for the data field (ice > crosswind > heavy wind > headwind >
   heat > rain/showers ahead). Escalates instantly, de-escalates after a ~30-cycle hold
   so the banner does not flicker.

Input signals used: air temp (`temperature_2m`), surface temp (`surface_temperature`),
dew point (`dewpoint_2m`), humidity, rain + showers (mm/h), snowfall (cm/h),
wind speed / gusts / direction (km/h), `precipitation_probability`,
`minutely_15` rain/snow (next 0/15/30/45 min), 12 h running sums, dry-streak counter, season.

List of checks (with shortened text):

- Black Ice / Freezing Wet Road | Ice
- Hoarfrost / Freezing Fog | Frost
- Gale-Force Winds / Severe Gusts | Gale Wind
- Torrential Downpour / Heavy rain / Steady rain / Drizzle | Pouring / Wet Road
- Bridge Deck Freeze | Bridge Ice
- Snow / Slush Accumulation | Snow/Slush
- Strong Crosswinds / Moderate Winds / Noticeable Breeze | Crosswind
- Imminent Rain | Imm. Rain
- Imminent Snow | Imm. Snow
- First Rain ("Oil Slick") | Slick Rain
- Autumn Wet Leaves | Leaves
- Sweating Road (Dew Point) | Wet Road

| Condition / Hazard | Trigger Criteria | Risk Level | Primary Advice |
| --- | --- | --- | --- |
| Black Ice / Freezing Wet Road | Surface ≤0.0°C or Air ≤0.5°C + rain/showers ≥0.1 mm/h (current or 12 h sum) or snow ≥0.1 cm/h | CRITICAL | Avoid riding; lower tire pressure |
| Hoarfrost / Freezing Fog | Surface ≤0.0°C + Surface-Dew spread ≤2.0°C + Humidity ≥80% | CRITICAL | Watch shaded areas/bridges; no sudden braking |
| Gale-Force Winds / Severe Gusts | Wind ≥45 km/h, Gust ≥60 km/h, or Wind ≥35 + Gust/Wind ratio ≥1.7 | CRITICAL | Hold bars firmly; use lower-profile wheels |
| Torrential Downpour | Current rain+showers ≥15.0 mm/h | CRITICAL | Reduce speed; increase grip margin, braking distance |
| Bridge Deck Freeze | Air 0.0 to 2.5°C + (12 h rain ≥0.1 mm/h or Humidity >88% or 12 h snow ≥0.1 cm) | HIGH | Watch exposed structure surfaces |
| Snow / Slush Accumulation | 12 h snow ≥0.1 cm + (Surface ≤1.0°C or Air ≤1.5°C) | HIGH | Loss of traction in turns; tread required |
| Heavy Rain / Standing Water | Current rain+showers ≥7.5 mm/h | HIGH | Reduce speed; increase braking distance |
| Strong Crosswinds / Heavy Gusts | Wind ≥35 km/h, Gust ≥45 km/h, or Wind ≥25 + ratio ≥1.5 | HIGH | Beware open fields and bridges |
| Imminent Rain | `minutely_15` rain ≥0.1 within 0/15/30/45 min, while currently dry | HIGH | Rain starting now / Rain in X min |
| Imminent Snow | `minutely_15` snow ≥0.1 within 0/15/30/45 min, while currently dry | HIGH | Snow starting now / Snow in X min |
| First Rain ("Oil Slick") | Spring/Summer + rain 0.1–2.5 mm/h after ≥10 h dry streak | MODERATE | Extreme slip hazard; traction improves after heavier rain |
| Steady Rain | Current rain+showers ≥2.5 mm/h | MODERATE | Increase braking distance; reduce lean angle |
| Autumn Wet Leaves | Autumn + any rain/snow current or 12 h sum ≥ threshold | MODERATE | Extreme slip on cornering lines; reduce lean |
| Moderate Winds / Gust Spikes | Wind ≥25 km/h, Gust ≥35 km/h, or Wind ≥18 + ratio ≥1.3 | MODERATE | Hold handlebars firmly |
| Light Rain / Drizzle | Current rain+showers ≥0.2 mm/h | SLIGHT | Increase braking distance |
| Sweating Road (Dew Point) | Surface >0°C, Humidity >90%, Surface-Dew spread ≤1.0°C | SLIGHT | Reduce lean angle on shaded descents |
| Noticeable Breeze | Wind ≥20 km/h | SLIGHT | Hold handlebars firmly |

Notes:

- Rain/showers are mm/h, snowfall is cm/h (Open-Meteo unit); 0.1 cm snow ≈ 0.1 mm water equivalent.
- `surfaceDewSpread = surfaceTemp - dewPoint`. Small spread = air near saturation = condensation/frost risk.
- Dry streak counts *preceding* dry hours (excludes current hour, capped at 24 h), so first-rain can fire while it is raining now.
- Seasons are meteorological by hemisphere (N: Mar–May spring, Jun–Aug summer, Sep–Nov autumn; S mirrored).
- Forecast bars use the same rules per hour (current + 12 h), so live badge and sparkline always agree.
- Gust bars warn one tier earlier (gust 45/35/25 km/h or ratio 1.7/1.5/1.3) than the risk upgrade: bars show exposure, the risk rule upgrades the ride.

Key Features

Multi-Factor Hazard Aggregation: Combines surface thermals, dew spread, wind gust ratios, and precipitation history in a single evaluation pass.
Spring/Summer Oil-Slick Detection: Identifies low-volume rain following dry spells ($\ge 10\text{h}$) when embedded road oils surface before being washed away.
Deep Wind Profiling: Dynamic gust-to-sustained ratios balance steady drag against sudden steering forces on deep-section rims.
Cascading Safety Hierarchy: Evaluates compound risks simultaneously to upgrade global RiskLevel while queueing targeted Hazard flags and Advice strings.

Settings

Open on-device via the data field settings menu (or Garmin Express / Connect IQ phone app):
Background, Alerts, Thresholds, Advanced, plus Demo and Reset to defaults.

Background

- Minimal GPS (0–4, default 3 = Usable): minimum position quality before a background fetch is allowed.
  0 Not available, 1 Last known, 2 Poor, 3 Usable, 4 Good. Higher = fewer stale-position fetches, but more skips indoors.
- Check interval minutes (default 5, minimum enforced 5): how often the background service polls Open-Meteo.
  Garmin background limits apply; lower = fresher data, higher battery/phone data use.
- Background timeout sec (default 0 = off): if the next scheduled fetch is overdue by more than this,
  the service reschedules itself. Leave 0 unless fetches stall.
- Background delay sec: grace delay used by the scheduling helper. Leave at default unless debugging.

Alerts

- Beep on alert: tone when a new risk-level alert fires.
- Toast message on alert: pop-up banner on new alerts.
- Beep on alert state change: tone whenever the dominant alert-banner state changes
  (e.g. Normal → Crosswind → Heavy Wind). Turn off for silent commuting.

Thresholds (alert banner only — slip-risk engine above uses fixed values)

All wind values in km/h, temps in °C, precipitation in mm/h. Editable range shown on the
numeric picker (e.g. `High Crosswind|0~100.0 (km/h)`).

| Setting | Default | Meaning |
| --- | --- | --- |
| Ice Alert | 3.0 °C | Banner shows ICE when surface temp ≤ this. Safety margin above 0 °C (sensor + bridge lag). Raise for margin, lower only if you trust the sensor. Range −10~10. |
| High Crosswind | 25.0 km/h | Banner shows HIGH CROSSWIND when lateral *effective cross gust* ≥ this. This is `gust × |sin(relative angle)|`, i.e. only the sideways component for your heading. |
| Cross Gust | 18.0 km/h | Banner shows MODERATE CROSSWIND when effective cross gust ≥ this. Early warning below High Crosswind. |
| Heavy Wind | 35.0 km/h | Banner shows HEAVY WIND when *sustained* wind (not gust, not lateral) ≥ this. Pure ambient push / pacing cost. |
| Sustained Wind | 25.0 km/h | Banner shows SUSTAINED WIND when sustained wind ≥ this. Below Heavy Wind; informational pacing warning. |
| Headwind | 12.0 km/h | Banner shows AERO HEADWIND when signed net headwind ≤ −12 km/h (stored positive, evaluated negative). Only the headwind component (`wind × cos`), so a 20 km/h quartering wind may not trigger. Raise (e.g. 15–18) to silence, lower (e.g. 8) if every drag matters. |
| Heat Stress | 32.0 °C | Banner shows HEAT when feels-like (apparent) temp ≥ this. Feels-like blends air temp + humidity + wind. Lower for heat-sensitive riders. |
| Precip Ahead | 0.5 mm/h | Banner shows RAIN/SHOWERS AHEAD when max forecast rain or showers ≥ this. Lower (0.2) for earlier warning, raise (1.0–2.0) to ignore drizzle. |

Priority order (highest wins): Ice > High Crosswind > Heavy Wind > Moderate Crosswind >
Sustained Wind > Headwind > Heat > Showers Ahead > Rain Ahead > Normal.
What is happening now always beats what is coming.

Advanced

- Forecast hours (None / Relative / Absolute, default Absolute): hour labels on the forecast bars.
  None hides them, Relative shows +1h/+2h…, Absolute shows clock hours.
- HSP breakpoint (default 180, range 0–255): luminance threshold that decides dark/light
  background text. Raise if light text stays unreadable, lower if dark text washes out.
- Show HSP value: debug overlay of the computed background brightness. Off for normal use.
- Effective Cross Gust (default ON): banner + field use `gust × |sin|` instead of `sustained × |sin|`.
  ON = reacts to peak sideways slam (recommended, especially deep rims). OFF = steadier baseline lean value.
- Feels Like Temperature (default ON): use apparent temperature for the heat alert/display.
  OFF shows raw air temp.
- Short Hazard (default OFF): show compact tags (`Ice`, `Gale Wind`, `Crosswind`, …) instead of
  full names (`Black Ice / Freezing Wet Road`, …). Useful on small Edge x40/x50 fields.
- Hide Risk Advice (default OFF): show only hazards, suppress the advice lines.
- Hide Units When Active (default ON): hide units (km/h, °C) while an alert is active to free pixels.
- Demo: loads a canned scenario once for layout testing, then auto-clears.
- Reset to defaults: re-seeds all settings above on next load.

Gust / Cross Gust

They measure the same *directional angle*, but `EffectiveCrossGust` uses the **peak gust speed** instead of the steady wind speed.

Here is the exact difference:

$$\text{Crosswind (Steady)} = \text{Sustained Wind Speed} \times \vert{}\sin(\theta)\vert{}$$

$$\text{Effective Cross Gust} = \text{Peak Gust Speed} \times \vert{}\sin(\theta)\vert{}$$

### Quick Comparison

| Metric | Speed Base Used | What It Measures | Cycling Context |
| --- | --- | --- | --- |
| **Crosswind** | Sustained Wind Speed | Constant side push | The continuous side-force forcing you to lean slightly into the wind. |
| **Effective Cross Gust** | Peak Gust Speed | Maximum sudden side force | **The peak sideways slam** that threatens to sweep your front wheel off line. |

### Practical Example

Imagine riding at a $90^\circ$ angle to the wind with a **$20\text{ km/h}$ base wind** and **$40\text{ km/h}$ gusts**:

* **Crosswind:** $20 \times \sin(90^\circ) = \mathbf{20\text{ km/h}}$ (Your continuous baseline side-load)
* **Effective Cross Gust:** $40 \times \sin(90^\circ) = \mathbf{40\text{ km/h}}$ (The peak lateral force hitting your deep-section front rim)

In short: **Crosswind** tells you how hard you need to lean; **Effective Cross Gust** tells you how violently you might get blown off course.

Threshold tuning examples

Defaults suit a fit rider on shallow alloy rims in mixed conditions. Adjust to your wheels,
fatigue, and route exposure. Only the alert banner changes — the Critical/High slip-risk
rules keep protecting you regardless.

| Scenario | Change from default | Why |
| --- | --- | --- |
| Deep-section rims (50–80 mm), TT bike | High Crosswind 25 → 18–20, Cross Gust 18 → 12–15, Heavy Wind 35 → 30, keep Effective Cross Gust ON | Side force scales with rim depth; a 30 km/h gust that is fine on 25 mm box rims can steer a 65 mm front wheel. Earlier banner = earlier grip on the drops. |
| Shallow rims, calm inland route | High Crosswind 25 → 28–30, Cross Gust 18 → 20–22, Sustained 25 → 28 | Fewer false alarms in sheltered terrain; risk engine still catches true gales (fixed 45/60 km/h Critical rule). |
| Tired / night / fast alpine descent / loaded touring | Ice Alert 3.0 → 4–5, Precip Ahead 0.5 → 0.2, High Crosswind −3 to −5, Headwind 12 → 8–10 | Reaction time is worse and braking distance longer; buy margin. Lower precip threshold warns before the road wets. |
| Winter commuting near 0 °C | Ice Alert → 4.0, keep risk engine as-is | Bridges freeze ~2 °C before roads; banner at 4 °C reminds you before the fixed Bridge-Freeze rule (0–2.5 °C) fires. |
| Heat-sensitive / midday summer | Heat Stress 32 → 28–30, Precip Ahead → 1.0 | Earlier heat warning; fewer drizzle banners when only thunderstorms matter. |
| Aero training (headwind intervals) | Headwind 12 → 8, Sustained 25 → 20 | Banner marks every useful drag stretch; combine with Effective Cross Gust OFF if you only care about steady push. |
| Gusty coastal / bridge commute | Cross Gust → 14–15, Heavy Wind → 30–32 | Gust-ratio spikes (e.g. 25 km/h gusting 40, ratio 1.6) trigger earlier; expect more MODERATE CROSSWIND holds (30-cycle hysteresis keeps it visible). |

Rule of thumb: move in 2–3 km/h (wind) or 1 °C (ice/heat) steps, ride one week, then adjust again.
If the banner nags constantly, you went too far — reset that one value, not everything.
Use Reset to defaults to restore the table above.
