- Menu
    options:

- BG call
    - cache it

- View
    show details
    -> display options: ??


+
- linux taskbar app for local use

- option to collect lat/lon during commute 
    - for predict commute track
    - reset option after activity done

- no data -> text gray 
- sync themecolor all field sizes
- temp/surface/dewp/hum colors sync on all field sizes 

crash on edge?
background dark - level ..
title tonen "slippery condition"

if safe current hour then calc until not safe and
- starttime counter for slippery alert (timesec-nowsec)

- display small bars rain/snow mm / hour
- + severity 

- title of app
- compacter stats 
    only when no data or error
    #1 only?
    labeltext ahv isDarkColor func
    large + one field with prediction ..
    icons or abbr for
    - air temp
    - surface temp
    - dew point
    - humidity
    


    // Inside your header rendering block:
if (metrics.minutesUntilRain >= 0 && metrics.minutesUntilRain <= 30 && metrics.rainCurrent < 0.1f) {
    var alertText = (metrics.minutesUntilRain == 0) 
        ? "RAIN STARTING NOW" 
        : "RAIN IN " + metrics.minutesUntilRain + " MIN";

    // Draw solid alert box
    dc.setColor(Gfx.COLOR_BLUE, Gfx.COLOR_TRANSPARENT);
    dc.fillRectangle(bannerX, bannerY, bannerWidth, bannerHeight);

    // White bold text
    dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
    dc.drawText(
        bannerX + (bannerWidth / 2), 
        bannerY + (bannerHeight / 2), 
        Gfx.FONT_SMALL, 
        alertText, 
        Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER
    );
}