Slippery - cycling road hazard data field
=============================================

Slippery tells you while you ride whether the road is slippery or dangerous
for cycling. It turns live Open-Meteo weather data
(https://open-meteo.com) into a risk level (Safe, Slight, Moderate, High,
Critical), the hazard type (ice, crosswind, heavy rain, ...) and short
safety advice. Your phone fetches the forecast in the background, so this
data field needs a connected phone and GPS.

How it works: fixed safety rules check the current hour plus the next 12
hours; the worst triggered rule sets the risk level. A big alert banner
shows the dominant alert (ICE, CROSSWIND, RAIN AHEAD, ...). You can tune the
banner in Settings, Thresholds.

What is checked
---------------

CRITICAL: black ice / freezing wet road (frozen surface plus rain or snow,
avoid riding); hoarfrost / freezing fog (frozen surface, humid air, watch
bridges, no sudden braking); gale winds (wind from 45 km/h or gusts from 60
km/h, hold the bars firmly); torrential downpour (from 15 mm/h, reduce
speed).

HIGH: bridge deck freeze (0 to 2.5 C, wet or humid, bridges freeze first);
snow / slush (recent snow near freezing, treaded tires needed); heavy rain
(from 7.5 mm/h, increase braking distance); strong crosswinds (wind from 35
km/h or gusts from 45 km/h, beware open fields and bridges); rain or snow
starting within 0 to 45 minutes.

MODERATE: first-rain oil slick (spring/summer light rain after 10+ dry
hours, extremely slippery); steady rain (from 2.5 mm/h, lean less); autumn
wet leaves (extreme slip in corners); moderate winds (wind from 25 km/h or
gusts from 35 km/h).

SLIGHT: light rain / drizzle (from 0.2 mm/h); sweating road (warm surface,
very humid air, shaded descents); noticeable breeze (wind from 20 km/h).

Settings (device, Garmin Express or Connect IQ app)
---------------------------------------------------

Background: minimal GPS quality (default Usable), check interval in minutes
(default 5, minimum 5). Leave timeout/delay at default.

Alerts: beep on alert, pop-up toast message, beep on banner change (turn off
for silent commuting).

Thresholds, alert banner only (defaults): Ice Alert 3.0 C, High Crosswind 25
km/h, Cross Gust 18 km/h, Heavy Wind 35 km/h, Sustained Wind 25 km/h,
Headwind 12 km/h, Heat Stress 32 C, Precip Ahead 0.5 mm/h. Lower a value for
earlier warnings, raise it for fewer warnings.

Advanced: forecast hour labels (None, Relative, Absolute); Effective Cross
Gust on (use peak gusts for side push, recommended with deep rims); Feels
Like Temperature on; Short Hazard off (compact tags like Ice for small
fields); Hide Risk Advice off; Hide Units When Active on; Demo scenario;
Reset to defaults.

Crosswind is the steady side push you lean against; effective cross gust is
the peak sideways slam from gusts that can move your front wheel. Gusts
matter most with deep-section rims.

Tuning examples: deep rims (50-80 mm): High Crosswind 18-20, Cross Gust
12-15, Heavy Wind 30. Tired / night / descents: Ice Alert 4-5, Precip Ahead
0.2. Winter commute: Ice Alert 4.0. Heat sensitive: Heat Stress 28-30.
Adjust in small steps; if the banner nags, set that one value back.

Requirements: supported Edge head unit, connected phone for weather fetch,
GPS for position. If data is stale, check the phone connection.
