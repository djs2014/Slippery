- linux taskbar app for local use

- option to collect lat/lon during commute 
    - for predict commute track
    - reset option after activity done

   

- werkende icon voor risk level (small screen)

- alert on incoming rain/snow
- alert on ice forecast 
- check forecast hours if it gets slippery
    - alert
    - border around bar and display level + colorpill under


switch hours -> will also need other minute rain data-> need 8 * 15 min ->

104 reset when connected
gps stats -> on pause / links/rechts boven
gsp stats: last time bg process or time of observation
when in safe mode / no hazards

option
show relative or actual hour in forecast + blend more in background
display upcoming risk greater than current 



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

---
Find a spot where to put this info 
TL;DR forecast explanation
- rain in x min
- snow in x min
- gusts in x min
// Display remaining time until first rain (if any)
        // if (showLabels && rainStartIdx != -1) {
        //     // Get timestamp for the first rain event (if available)
        //     if (rainStartIdx < timeStampsForeCast.size()) {
        //         var firstRainTime = timeStampsForeCast[rainStartIdx];
        //         // Difference in hours:minute from current time
        //         var diffSec = firstRainTime - Time.now().value();
        //         if (diffSec > 0) {
        //             dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        //             dc.drawText(
        //                 (x + width) / 2,
        //                 baselineY + 3,
        //                 Graphics.FONT_XTINY,
        //                 Lang.format("first rain in $1$", [
        //                     $.secondsToShortTimeString(diffSec, "{h}:{m}:{s}"),
        //                 ]),
        //                 Graphics.TEXT_JUSTIFY_CENTER
        //             );
        //         }
        //     }
        // }