Slippery - cycling road hazard data field
=============================================

Slippery watches live weather and road conditions and tells you, while you
ride, whether the road is slippery or dangerous for cycling. It turns raw
weather data into a simple risk level (Safe, Slight, Moderate, High,
Critical), the type of hazard (ice, crosswind, heavy rain, ...) and short
safety advice (reduce speed, hold the bars firmly, ...).

Weather data comes from Open-Meteo (https://open-meteo.com). Your phone
fetches the forecast in the background, so the data field needs a connected
phone and a GPS position.

How it works
------------

Slippery has two layers.

1. Slip-risk engine. Fixed safety rules that check the current hour and the
next 12 hours. The highest triggered rule sets the risk level: Safe, then
Slight, Moderate, High, up to Critical. Several hazards and advice lines can
show at once. These rules cannot be changed in the settings.

2. Alert banner. One dominant alert shown big on the data field, for example
ICE, CROSSWIND or RAIN AHEAD. You can tune when it appears in Settings,
Thresholds (see below). It reacts immediately when things get worse and holds
the warning a while before clearing, so it does not flicker.

What is checked
---------------

CRITICAL - Black ice / freezing wet road. Road surface at or below freezing
(0 C) or air at/below 0.5 C, plus recent or current rain or snow. Advice:
avoid riding, lower tire pressure.

CRITICAL - Hoarfrost / freezing fog. Frozen surface plus humid air close to
the dew point. Advice: watch shaded areas and bridges, no sudden braking.

CRITICAL - Gale-force winds / severe gusts. Sustained wind from 45 km/h,
gusts from 60 km/h, or strong gusty wind (35 km/h with gust factor 1.7).
Advice: hold the bars firmly, consider lower-profile wheels.

CRITICAL - Torrential downpour. More than 15 mm/h rain right now. Advice:
reduce speed, keep extra grip margin and braking distance.

HIGH - Bridge deck freeze. Air between 0 and 2.5 C with wet or humid
conditions. Bridges freeze before roads. Advice: watch exposed surfaces.

HIGH - Snow / slush. Snow in the last 12 hours with temperatures near
freezing. Advice: traction loss in turns, treaded tires needed.

HIGH - Heavy rain. From 7.5 mm/h rain right now. Advice: reduce speed,
increase braking distance.

HIGH - Strong crosswinds / heavy gusts. Wind from 35 km/h, gusts from
45 km/h, or gusty wind from 25 km/h. Advice: beware open fields and bridges.

HIGH - Rain or snow starting soon. Rain or snow detected in the next 0 to 45
minutes while it is still dry. Advice: rain/snow starting now or in X min.

MODERATE - First rain oil slick. In spring and summer, light rain
(0.1 to 2.5 mm/h) after 10 or more dry hours lifts oil and dirt off the road.
Advice: extremely slippery, traction improves after heavier rain.

MODERATE - Steady rain. From 2.5 mm/h rain right now. Advice: increase
braking distance, lean less in corners.

MODERATE - Autumn wet leaves. In autumn with wet roads. Advice: extreme slip
hazard on cornering lines, lean less.

MODERATE - Moderate winds / gust spikes. Wind from 25 km/h, gusts from
35 km/h, or gusty wind from 18 km/h. Advice: hold the bars firmly.

SLIGHT - Light rain / drizzle. From 0.2 mm/h rain. Advice: increase braking
distance.

SLIGHT - Sweating road (dew). Warm surface with very humid air near the dew
point, typically on shaded descents. Advice: reduce lean angle.

SLIGHT - Noticeable breeze. Wind from 20 km/h. Advice: hold the bars firmly.

Settings
--------

Open the settings on the device, in Garmin Express, or in the Connect IQ
phone app. Sections: Background, Alerts, Thresholds, Advanced.

Background:
- Minimal GPS (default 3 = Usable). Minimum GPS quality before weather is
  fetched. Higher values skip more indoor/stale fixes.
- Check interval minutes (default 5, minimum 5). How often weather is
  fetched. Lower is fresher but uses more battery and data.
- Background timeout / delay. Only for troubleshooting stalled fetches.
  Leave at default.

Alerts:
- Beep on alert. Sound when a new risk alert appears.
- Toast message on alert. Pop-up message on new alerts.
- Beep on alert state change. Sound when the banner changes, e.g. from
  Normal to Crosswind. Turn off for silent commuting.

Thresholds (alert banner only, defaults in brackets):
- Ice Alert (3.0 C). Banner shows ICE when the road surface is colder than
  this. Includes a safety margin above freezing.
- High Crosswind (25 km/h). Banner shows HIGH CROSSWIND when the sideways
  gust on your heading reaches this.
- Cross Gust (18 km/h). Earlier MODERATE CROSSWIND warning below the high
  level.
- Heavy Wind (35 km/h). Banner shows HEAVY WIND for strong sustained wind.
- Sustained Wind (25 km/h). Lighter sustained-wind notice for pacing.
- Headwind (12 km/h). Banner shows AERO HEADWIND when riding into this much
  headwind component.
- Heat Stress (32 C). Banner shows HEAT when the feels-like temperature
  reaches this.
- Precip Ahead (0.5 mm/h). Banner shows RAIN/SHOWERS AHEAD when this much
  rain is forecast. Lower it for earlier warnings, raise it to ignore
  drizzle.

Advanced:
- Forecast hours. Labels on the forecast bars: None, Relative (+1h, +2h) or
  Absolute (clock hours). Default Absolute.
- HSP breakpoint. Brightness switch between dark and light text. Only change
  if text is hard to read.
- Effective Cross Gust (default on). Use peak gusts instead of steady wind
  for the sideways push. Recommended, especially with deep rims.
- Feels Like Temperature (default on). Use feels-like instead of raw air
  temperature.
- Short Hazard (default off). Short tags like Ice or Gale Wind instead of
  full names. Handy on small data fields.
- Hide Risk Advice (default off). Show hazards only, no advice lines.
- Hide Units When Active (default on). Hide units during alerts to save
  space.
- Demo. Loads an example scenario once to check the layout.
- Reset to defaults. Restores all settings above.

Crosswind vs cross gust
-----------------------

Crosswind is the steady side push you lean against. Effective cross gust is
the peak sideways slam from gusts that can move your front wheel. Example:
riding across a 20 km/h wind with 40 km/h gusts, the crosswind is 20 km/h
but the effective cross gust is 40 km/h. Gusts matter most with deep-section
rims.

Tuning examples
---------------

Defaults suit a fit rider on shallow rims. Only the alert banner changes;
the fixed safety rules always protect you.

- Deep-section rims (50 to 80 mm) or time trial bike: set High Crosswind to
  18-20, Cross Gust to 12-15, Heavy Wind to 30, keep Effective Cross Gust on.
- Calm inland routes on shallow rims: raise High Crosswind to 28-30 and
  Cross Gust to 20-22 for fewer warnings.
- Tired, night riding, fast descents or loaded touring: set Ice Alert to 4-5
  and Precip Ahead to 0.2 for extra margin.
- Winter commuting near freezing: set Ice Alert to 4.0, bridges freeze first.
- Heat sensitive riders: set Heat Stress to 28-30.
- Headwind training: set Headwind to 8 so every drag stretch is marked.
- Gusty coast or bridge commute: set Cross Gust to 14-15 and Heavy Wind to
  30-32.

Change values in small steps (2-3 km/h for wind, 1 C for ice/heat), ride a
week, then adjust again. If the banner nags too much, set that one value
back rather than resetting everything.

Requirements
------------

Supported Edge head units, a connected phone for background weather fetch,
and GPS for your position. If data is stale, check the phone connection and
the background settings above.
