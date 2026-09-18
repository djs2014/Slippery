- linux taskbar app for local use
- weather app also same track heading mechanism / edgefield

Widefield
 Label icons
 Font larger
 beep on alertmode change
 icon alertmode temp / wind
 label to toplevel small after x sec
 ? zen mode -> na 20 sec label / unit weg wanneer niet trappen 3 sec dan tonen 
 no unit -> font bigger

auto mode / layout fonts
1 wide field
2 large field
3 small 
4 one field -> reorder fields

settings: warning levels headwind customize 15km headwind default

fix demo
replace all 
   
- alert on incoming rain/snow
- alert on ice forecast 
- check forecast x hours if it gets slippery
    - alert
- wide field arrow + cross wind value  
- alert on gust warning
- rain chance line?
- rain > 2.0 mm darker blue ..or color scheme wweather
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
..
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

oneField is ok?

wide/large/small field

airTemp / feels like temp
windGust / effect cross Gust
wind / net wind

forecast
enum AlertState {
    STATE_NORMAL = 0,
        airTemp 
    STATE_ICE_ALERT = 1,
        surfaceTemp
        dewpoint
        humidity
    STATE_HEAVY_RAIN = 2,
        
    STATE_HIGH_CROSSWIND = 3,
        windGust -> effective crossgust
        crossGust
        crossWind
        net Wind
    STATE_RAIN_SOON = 4,

    STATE_AERO_HEADWIND = 5,
        windspeed
        crossWind
        net Wind
    STATE_HEAT_STRESS = 6,
}

Display amount mm in coming hour
 rainIn30MinMmHr as Float, // Forecasted rain in next 15-30 mins
 rainIntensityMmHr as Float, // Current precipitation intensity (mm/h)
 // 2. Heavy Rain active or imminent (>2.5 mm/h is moderate/heavy rain)
        // if (rainIntensityMmHr >= 2.5f || rainIn30MinMmHr >= 2.5f) {
        //     return STATE_HEAVY_RAIN;
        // }

// 4. Light rain or incoming shower soon (0.5 mm to 2.5 mm/h forecast)
        if (rainIntensityMmHr > 0.1f || rainIn30MinMmHr >= 0.5f) {
            return STATE_RAIN_SOON;
        }

------------------------------------------------------
Fields + configuration

- air/feels like temp - relevant if <= 3 or => 20 
- surface temp <= 3
- dewpoint >= 20
- humidity >= 80
- wind speed > 20 km
- wind gust >= 20 (or gust level)
- net wind >= 15
- effective cross gust >= 20

Fields array 8|4|4
[none, airTemp, .. , automatic]
automatic -> not in list, then show most relevant

redesign layout wide field -> bigger number? and 4 fields?

aan eind C bar -> countdown to full hour
check hardcode colors 

Search for
AppState.activePalette[<ThemeManager.COLOR_SNOW_PATTERN>]
and replace it with
AppState.getColor(<ThemeManager.COLOR_SNOW_PATTERN>)
in this project *.mc files

get skill for connect IQ
nieuwe muis - met scrollen past text!
