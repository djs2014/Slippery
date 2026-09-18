- linux taskbar app for local use
- weather app also same track heading mechanism

- option to collect lat/lon during commute 
    - for predict commute track
    - reset option after activity done
    - option use hazard abbreviation 

   
- alert on incoming rain/snow
- alert on ice forecast 
- check forecast x hours if it gets slippery
    - alert
- wide field arrow + cross wind value  
- alert on gust warning
- rain > x mm dark blue ..or color scheme wweather
switch hours -> will also need other minute rain data-> need 8 * 15 min ->

// Setting? 
temp to color <0, <10 <15 
humidity to color

Hazards in order of importance?

--- finetune the rules
--- check wind relative direction 


If times is strictly linear hourly steps (each entry is exactly $3600$ seconds apart), you can eliminate the for loop completely with single-line integer math:
var nowSec = Time.now().value();

// Calculate index offset directly from start epoch
var targetIdx = (nowSec - times[0]) / 3600;

// Clamp bounds [0, times.size() - 1]
if (targetIdx < 0) { 
    targetIdx = 0; 
} else if (targetIdx >= times.size()) { 
    targetIdx = times.size() - 1; 
}


x track than bearing
x lighter color set risk for forecast 
x arrow as in w weather
x groot in small field
x center in grid one field
x gust lines met indent
x calc dewpoint plus comfort bar
place wind arrow in center small field if enabled or no hazards
in w weather ook effective gust option

netto wind / indien geen gust

open code use free models
contex7
skill connect iq
integrate in VSCode

---
x- getApparentTemperature Feels Like
x- heatindex
x- net wind

Configure fields per fieldsize
- order
- fieldtype
- show current wind

- speed/power/hr?

on not one fields
- show fields per edgefield 8 / 4 / 3 / 4
- option: feel like ipv air temp 
- option: net wind ipv wind speed

indicate progress in hour of first bar/ top of field (combine with current time)
 - indicates next background call / switch to next hour / remaining minutes in current hour
show current day time



[hourly rainandsnow, 12, 0.500000, 2026-09-17 17:00:00] Rain: 0.500000 Snow: 0.000000 <- current
[hourly rainandsnow, 13, 0.400000, 2026-09-17 18:00:00] Rain: 0.400000 Snow: 0.000000
[hourly rainandsnow, 14, 3.600000, 2026-09-17 19:00:00] Rain: 3.600000 Snow: 0.000000
[hourly rainandsnow, 15, 0.200000, 2026-09-17 20:00:00] Rain: 0.200000 Snow: 0.000000
[hourly rainandsnow, 16, 0.100000, 2026-09-17 21:00:00] Rain: 0.100000 Snow: 0.000000
[hourly rainandsnow, 17, 0.100000, 2026-09-17 22:00:00] Rain: 0.100000 Snow: 0.000000
[hourly rainandsnow, 18, 0.000000, 2026-09-17 23:00:00] Rain: 0.000000 Snow: 0.000000
[hourly rainandsnow, 19, 0.000000, 2026-09-18 00:00:00] Rain: 0.000000 Snow: 0.000000
[hourly rainandsnow, 20, 0.000000, 2026-09-18 01:00:00] Rain: 0.000000 Snow: 0.000000
[hourly rainandsnow, 21, 0.000000, 2026-09-18 02:00:00] Rain: 0.000000 Snow: 0.000000
[hourly rainandsnow, 22, 0.000000, 2026-09-18 03:00:00] Rain: 0.000000 Snow: 0.000000
[hourly rainandsnow, 23, 0.000000, 2026-09-18 04:00:00] Rain: 0.000000 Snow: 0.000000
// per quarter
[minutely rainandsnow, 0, 0.100000, 2026-09-17 17:45:00] Rain: 0.100000 Snow: 0.000000
[minutely rainandsnow, 1, 0.100000, 2026-09-17 18:00:00] Rain: 0.100000 Snow: 0.000000
[minutely rainandsnow, 2, 0.900000, 2026-09-17 18:15:00] Rain: 0.900000 Snow: 0.000000
[minutely rainandsnow, 3, 0.900000, 2026-09-17 18:30:00] Rain: 0.900000 Snow: 0.000000
if current is 17:59
 --> 0 minutely is current -> 17:45 start and is last bar of current hour.
 --> put other 3 on next hour
 
Check timestamp minutely if valid


TODO: remove precipation == rain + snowfall
add showers -> heavy rain burst as purple bars 
add precipitation_probability


Parameter Variable,Unit,Description
precipitation,mm,"Total precipitation (liquid rain + liquid equivalent of snowfall) combined over the preceding interval (e.g., preceding hour)."
rain,mm,Liquid precipitation only (excluding snow/freezing rain).
showers,mm,"Convective precipitation (e.g., brief intense rain showers from unstable air/thunderstorms)."
snowfall,cm,Amount of snowfall measured in centimeters (note: differs from rain/precipitation unit).
precipitation_probability,%,Probability of precipitation occurring during that forecast hour (0−100%).




Best Practice for 15-Minute Data in CIQ
When handling 15-minute precipitation data in your app:

Rely on total precipitation for the 15-minute array to capture all liquid volume (which already accounts for shower intensity internally).

Use rain + showers specifically when summing or parsing hourly arrays.

// Fallback definitions for non-native color constants
const COLOR_DEEP_PURPLE_LIGHT = 0x5500AA; // Deep Indigo/Purple for Light Mode
const COLOR_DEEP_PURPLE_DARK  = 0xAA00FF; // Electric Purple for Dark Mode

// Inside your rendering or palette selector logic
var showerColor = isDark ? COLOR_DEEP_PURPLE_DARK : COLOR_DEEP_PURPLE_LIGHT;

// Focus on wind related
// - Aero pacing / cross gust / net wind 
// Focus on temperature / humidity


public static function drawAeroPacingOverlay(
    dc as Graphics.Dc,
    x as Number,
    y as Number,
    width as Number,
    power3s as Number,
    targetPowerBase as Number,
    virtualGrade as Float,
    crossGustKmh as Float,
    isDark as Boolean
) as Void {
    var textColor = isDark ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
    var accentColor = isDark ? Graphics.COLOR_YELLOW : 0x666600;

    // --- 1. VIRTUAL GRADE BADGE (Top Right) ---
    var gradeText = Lang.format("vG: $1$%", [virtualGrade.format("%.1f")]);
    dc.setColor(accentColor, Graphics.COLOR_TRANSPARENT);
    dc.drawText(
        x + width - 4, 
        y + 2, 
        Graphics.FONT_XTINY, 
        gradeText, 
        Graphics.TEXT_JUSTIFY_RIGHT
    );

    // --- 2. PACING DELTA ALERT (Target vs Actual 3s Power) ---
    var deltaW = AeroPacingCalculator.calculatePacingDeltaWatts(targetPowerBase, virtualGrade);
    if (deltaW != 0) {
        var deltaText = (deltaW > 0) 
            ? Lang.format("PUSH +$1$W", [deltaW]) 
            : Lang.format("EASE $1$W", [deltaW]);
            
        var alertColor = (deltaW > 0) ? Graphics.COLOR_RED : Graphics.COLOR_BLUE;
        dc.setColor(alertColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x + (width / 2), 
            y + 2, 
            Graphics.FONT_XTINY, 
            deltaText, 
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    // --- 3. CROSS-GUST STABILITY WARNING BANNER ---
    // High cross-gusts (>30 km/h) trigger a subtle stability cue at the bottom
    if (crossGustKmh >= 30.0f) {
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y + 36, width, 14);
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x + (width / 2), 
            y + 36, 
            Graphics.FONT_XTINY, 
            Lang.format("GUST ALERT: $1$ km/h", [crossGustKmh.format("%d")]), 
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }
}