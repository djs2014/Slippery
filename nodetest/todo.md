cinnamon applet

Configuration options
- colors bright 
- colors modest
- follow theme 

- ? delayed at startup
- thresholds (like in connect IQ app slippery)

- option to add a list of lat/lon - with description (max 5)
- option to use HSP check for textcolor on risk color background
- config HSP treshold value (with live sample)



on click
- details
- display when relevant
- windspeed / direction / gust
- temp / feels like / dewpoint / humidity / surface temp
- display coming x hours 
    - risklevel + precipation amount 
- display current risklevels + precipation from list of lat/lon 

note ICE or ICE coming hours is big warning (same for the list of lat/lon)
Create deploy script to install/update it on the cinnamon panel.

Goal is: have a few points on a commute track so i can see if it will be risky to cycle the coming hours.
(Also when on the way back (after 8 hours of work))

- lat and lon should be pastable from '52.387520877358256, 4.7199631014777' (when getting the value from Google maps)
    - so it can be one lat,lon field in the configuration (If that is possible)
- after reload - fetach right away
- default HSP should be 127 because display not on a Garmin device
- popup display should be compacter
- no need to show info about HSP on the popup 
- no need to show info about treshold alerts on the popup
- option to set the first lat,lon by current location using computer info
- check usage of lat lon in examples, prefill etc. Use the lat lon of Amsterdam central

Additional

Configuration:
Label locations, change coordinates to `latitude,longitude`
Is it possible to put the locations 2 - 5 behind a tab section?
Repeat fetch after startup -> maybe name it like 'Delay on start (sec)'?

Add option to show hazards.
Add option to show advice.

With Panel chip colors
- Add extra setting to show only colors when risklevel above .. <risklevel>
After this, then decide if 'Follow theme' setting is still needed, if not then remove it.

The popup:

Lets focus first on location 1 data
Show in text: location name, Risklevel + list of hazards / advice
Short summary of : temp/feels like, surface, dewpoint, humidity, wind, gust and direction only if relevant based on the tresholds (or a value close to those tresholds like 10% below that value).

If possible, visualize the upcoming hours for
- risklevel, wind, wind direction, gust, temperature, precepation
- hazards as color line per hour block under the risklevel block
(under it the lines per hazard when they start / stop on which block  lines have diff colors per hazard)
a little bit like the layout.png file
    
     
Remarks after the change:

Combine Location 1 and Locations 2-5 tab to one Locations tab
Probably the prefix Location on the settings is not needed, just a number is enough.
Remove the showing hazards settings, it will confuse the user.
Is it possible to show a picture on the popup?
