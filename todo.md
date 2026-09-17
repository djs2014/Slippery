- linux taskbar app for local use
- weather app also same track heading mechanism

- option to collect lat/lon during commute 
    - for predict commute track
    - reset option after activity done

   
- alert on incoming rain/snow
- alert on ice forecast 
- check forecast x hours if it gets slippery
    - alert
- wide field arrow + cross wind value  

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

x indicate minute rain in first bar with darker blue / purple depends on rainfall!
Move start of minute rain on right position 



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
 
 alg
 -> shrink first bar according to current hour in steps of quarter
 -> get start hour minutely[0]
 -> which quarter of current hour
 -> draw on right places
 -> draw rest on next hour


TODO: remove precipation == rain + snowfall
add showers -> heavy rain burst as purple bars 
add precipitation_probability


Parameter Variable,Unit,Description
precipitation,mm,"Total precipitation (liquid rain + liquid equivalent of snowfall) combined over the preceding interval (e.g., preceding hour)."
rain,mm,Liquid precipitation only (excluding snow/freezing rain).
showers,mm,"Convective precipitation (e.g., brief intense rain showers from unstable air/thunderstorms)."
snowfall,cm,Amount of snowfall measured in centimeters (note: differs from rain/precipitation unit).
precipitation_probability,%,Probability of precipitation occurring during that forecast hour (0−100%).


