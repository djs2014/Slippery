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
- heatindex
- getApparentTemperature Feels Like
- net wind

on not one fields
- option: feel like ipv air temp 
- option: net wind ipv wind speed

indicate progress in hour of first bar
show current day time

do something with precipation % chance -> bigger etc..
5.1 is ? 2.1 is 

TODO: remove precipation == rain + snowfall

add showers
add precipitation_probability

Parameter Variable,Unit,Description
precipitation,mm,"Total precipitation (liquid rain + liquid equivalent of snowfall) combined over the preceding interval (e.g., preceding hour)."
rain,mm,Liquid precipitation only (excluding snow/freezing rain).
showers,mm,"Convective precipitation (e.g., brief intense rain showers from unstable air/thunderstorms)."
snowfall,cm,Amount of snowfall measured in centimeters (note: differs from rain/precipitation unit).
precipitation_probability,%,Probability of precipitation occurring during that forecast hour (0−100%).