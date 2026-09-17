Slippery

Evaluates real-time weather and surface dynamics to compute cycling-specific hazard levels, hazard types, and actionable safety advice. 
Designed for high-performance Connect IQ head units, it translates raw atmospheric metrics into instant situational awareness on the bike.

Source of weather data is (Open Meteo)[https://open-meteo.com]

Can show if the road is slippery for cycling.

List of checks (with shortened text):

- Black Ice / Freezing Wet Road | Ice
- Hoarfrost / Freezing Fog | Frost
- Gale-Force Winds / Severe Gusts | Gale Wind
- Torrential Downpour / Heavy rain | Pouring
- Bridge Deck Freeze | Bridge Ice
- Snow / Slush Accumulation | Snow/Slush
- Strong Crosswinds | Crosswind
- Imminent Rain / Snow | Snow
- First Rain ("Oil Slick") | Slick rain
- Autumn Wet Leaves | Leaves
- Sweating Road (Dew Point) | Wet Road

| Condition / Hazard | Trigger Criteria | Risk Level | Primary Advice |
| --- | --- | --- | --- |
| Black Ice / Freezing Wet Road | Surface ≤0.0∘C or Air ≤0.5∘C + Precip | CRITICAL | Avoid riding; lower tire pressure |
| Hoarfrost / Freezing Fog | Surface ≤0.0∘C + Surface-Dew Spread ≤2.0∘C | CRITICAL | Watch shaded areas/bridges; no sudden braking |
| Gale-Force Winds / Severe Gusts | Wind ≥45km/h, Gust ≥60km/h, or Speed ≥35 & Ratio ≥1.7 | CRITICAL | Hold bars firmly; use lower-profile wheels |
| Torrential Downpour | Current Rain ≥15.0mm/h | CRITICAL | Reduce speed; increase grip margin |
| Bridge Deck Freeze | Air 0.0 to 2.5∘C + Precip or Humidity >88% | HIGH | Watch exposed structure surfaces |
| Snow / Slush Accumulation | 12h Snow Accumulation >0.0mm | HIGH | Loss of traction in turns; tread required |
| Strong Crosswinds | Wind ≥35km/h, Gust ≥45km/h, or Speed ≥25 & Ratio ≥1.5 | HIGH | Beware open fields and bridges |
| Imminent Rain / Snow | Minutely precip forecast alert within immediate window | HIGH | Prepare foul weather gear |
| First Rain ("Oil Slick") | Spring/Summer + Rain 0.1–2.5mm/h after ≥10h dry streak | MODERATE | Extreme slip hazard; wait out or exercise caution |
| Autumn Wet Leaves | Autumn + (Precip >0 or Humidity >90%) | MODERATE | Reduce cornering lean angle |
| Sweating Road (Dew Point) | Surface >0∘C, Humidity >90%, Surface-Dew Spread ≤1.0∘C | SLIGHT | Reduce lean angle on shaded descents |


Key Features

Multi-Factor Hazard Aggregation: Combines surface thermals, dew spread, wind gust ratios, and precipitation history in a single evaluation pass.
Spring/Summer Oil-Slick Detection: Identifies low-volume rain following dry spells ($\ge 10\text{h}$) when embedded road oils surface before being washed away.
Deep Wind Profiling: Dynamic gust-to-sustained ratios balance steady drag against sudden steering forces on deep-section rims.
Cascading Safety Hierarchy: Evaluates compound risks simultaneously to upgrade global RiskLevel while queueing targeted Hazard flags and Advice strings.

Settings

Background

- Set minimal GPS
- Set check interval

Alerts

- Beep
- Show toast message

Advanced

- Show forecast hours in the bars.
- HSP breakpoint 
    Breakpoint to determines if back color is dark/light, so the text will be light/dark.
- Effective Cross Gust
    Show effective cross gust instead of gust only.
- Hide Risk Advice
    Only show the hazards.

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