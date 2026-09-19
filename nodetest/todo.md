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


Additional

- lat and lon should be pastable from '52.387520877358256, 4.7199631014777' (when getting the value from Google maps)
    - so it can be one lat,lon field in the configuration (If that is possible)
- after reload - fetach right away
- default HSP should be 127 because display not on a Garmin device
- popup display should be compacter
- no need to show info about HSP on the popup 
- no need to show info about treshold alerts on the popup
