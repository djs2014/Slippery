Road Risk Engine evaluates real-time weather and surface dynamics to compute cycling-specific hazard levels, hazard types, and actionable safety advice. Designed for high-performance Connect IQ head units, it translates raw atmospheric metrics into instant situational awareness on the bike.


Condition / Hazard,Trigger Criteria,Risk Level,Primary Advice
Black Ice / Freezing Wet Road,Surface ≤0.0∘C or Air ≤0.5∘C + Precip,CRITICAL,Avoid riding; lower tire pressure
Hoarfrost / Freezing Fog,Surface ≤0.0∘C + Surface-Dew Spread ≤2.0∘C,CRITICAL,Watch shaded areas/bridges; no sudden braking
Gale-Force Winds / Severe Gusts,"Wind ≥45km/h, Gust ≥60km/h, or Speed ≥35 & Ratio ≥1.7",CRITICAL,Hold bars firmly; use lower-profile wheels
Torrential Downpour,Current Rain ≥15.0mm/h,CRITICAL,Reduce speed; increase grip margin
Bridge Deck Freeze,Air 0.0 to 2.5∘C + Precip or Humidity >88%,HIGH,Watch exposed structure surfaces
Snow / Slush Accumulation,12h Snow Accumulation >0.0mm,HIGH,Loss of traction in turns; tread required
Strong Crosswinds,"Wind ≥35km/h, Gust ≥45km/h, or Speed ≥25 & Ratio ≥1.5",HIGH,Beware open fields and bridges
Imminent Rain / Snow,Minutely precip forecast alert within immediate window,HIGH,Prepare foul weather gear
"First Rain (""Oil Slick"")",Spring/Summer + Rain 0.1–2.5mm/h after ≥10h dry streak,MODERATE,Extreme slip hazard; wait out or exercise caution
Autumn Wet Leaves,Autumn + (Precip >0 or Humidity >90%),MODERATE,Reduce cornering lean angle
Sweating Road (Dew Point),"Surface >0∘C, Humidity >90%, Surface-Dew Spread ≤1.0∘C",SLIGHT,Reduce lean angle on shaded descents


Key Features

Multi-Factor Hazard Aggregation: Combines surface thermals, dew spread, wind gust ratios, and precipitation history in a single evaluation pass.Spring/Summer Oil-Slick Detection: Identifies low-volume rain following dry spells ($\ge 10\text{h}$) when embedded road oils surface before being washed away.Deep Wind Profiling: Dynamic gust-to-sustained ratios balance steady drag against sudden steering forces on deep-section rims.Cascading Safety Hierarchy: Evaluates compound risks simultaneously to upgrade global RiskLevel while queueing targeted Hazard flags and Advice strings.