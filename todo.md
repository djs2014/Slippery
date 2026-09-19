- linux taskbar app for local use
- weather app also same track heading mechanism / edgefield

- if showers > setting, then mark them under the bar! + warning icon and alert
- readme update alertmode thresholds
- setting incoming rain minimal mm/h alert


Widefield
 Label icons - check using debug
 Font larger
 beep on alertmode change
 icon alertmode temp / wind
 label to toplevel small after x sec
 ? zen mode -> na 20 sec label / unit weg wanneer niet trappen 3 sec dan tonen 
 no unit -> font bigger


auto mode / layout fonts
1 wide field
    - icon
    - alert icon
    - fonts
    - wind: wind + cx gust + net wind
    - temp: air/fl + surf + dewpnt
    
2 large field
    - icons
    - alert icon
    - wind: wind + gust
        cx gust + net wind
    - temp: air/feel like + surf 
         dewpnt + humidity

3 small 
    - icons
    - alert icon
    met label en unit -> zen
    wind: Cx Gust + Net Wind
    cold: air/feel like + surf
    heat/normal: air/feel like + dewpnt
        
4 one field -> icons smaller en bij de tekst
    - icons
    - alert icon

    air / feel like + surface
    dewp + humidity
    wind + gust 
    net wind + cruss gust

x settings: warning levels headwind customize 15km headwind default

replace all getColor 
forecast -> color > riskleve x -> draw normal risklevel color or only when risklevel goes up


- alert on incoming rain/snow
- alert on ice forecast 
- check forecast x hours if it gets slippery
    - alert
- wide field arrow + cross wind value  
- alert on gust warning
- rain chance line?
- rain > 2.0 mm darker blue ..or color scheme wweather
switch hours -> will also need other minute rain data-> need 8 * 15 min ->

Hazards in order of importance?

--- finetune the rules


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



check hardcode colors 


get skill for connect IQ
nieuwe muis - met scrollen past text!
