hardcoded risk values or not?

show drawScoreBadges in connect IQ
-> show rules
function rateCyclingHour(hh, iceT) {
    let score = 10.0;
    const isIcy = hh.ice || (hh.surfaceTemp !== undefined && hh.surfaceTemp !== null && hh.surfaceTemp <= iceT);
    if (isIcy) return 0.0;

    const temp = hh.airTemp;
    if (temp !== undefined && temp !== null) {
        if (temp < 10) score -= Math.min(4.0, (10 - temp) * 0.4);
        else if (temp < 18) score -= (18 - temp) * 0.15;
        else if (temp > 30) score -= Math.min(5.0, (temp - 30) * 0.5);
        else if (temp > 24) score -= (temp - 24) * 0.05;
    }

    const precip = (hh.rain || 0) + (hh.snow || 0);
    if (precip >= 7.5) score -= 5.0;
    else if (precip >= 2.5) score -= 3.0;
    else if (precip > 0) score -= 1.5;

    if (hh.dewPoint > 18) score -= 1.5;
    else if (hh.dewPoint > 15) score -= 0.7;

    const wind = Math.max(hh.windSpeed || 0, hh.windGust || 0);
    if (wind >= 45) score -= 5.0;
    else if (wind >= 35) score -= 3.0;
    else if (wind >= 25) score -= 1.5;
    else if (wind >= 18) score -= 0.5;

    return Math.max(0, Math.min(10, Math.round(score * 10) / 10));
}


risk footer align large / one / small field

- linux taskbar app for local use
- weather app also same track heading mechanism / edgefield

52.352547, 4.852022
69.840043, 26.883803
64.66204068732797, -19.170883997217427 iceland
Girona
42.046663, 2.775519

list some lat/lon with interesting wheater situations for testing purpose


analyze bg service /numeric input etc.

panel chip locations
primare or high risk 

sparkline arrows larger
option bigger arrow
one field - no hazards -> higher forecast..

display best hour in graph
option what to display in the graph
- wind/ sun / etc


The change in riskCalculator.mc uses a fixed 3.0°C reference, the same as the applet:

Hazard	Was	Now
Black ice	surface ≤ 0 or air ≤ 0.5	surface ≤ 3 or air ≤ 2
Surface frost	surface ≤ 0	surface ≤ 3
Bridge ice	air 0 to 2.5	air −1 to 3.5
Snow/slush	surface ≤ 1 or air ≤ 1.5	surface ≤ 0 or air ≤ 1.5
This affects more than the ice warning. These hazards also feed the overall risk level, so Connect IQ will now show critical or high risk more often in near-freezing conditions, just as the applet does.

I also updated the hazard table in readme.md. In iceHazardForecastTest.mc I moved the existing tests to the new boundary values and added one using the Keesing 02:00 forecast values.

Two differences remain:

Time window: Connect IQ looks 12 hours ahead, while your applet ice chip uses 24 hours. Ice between 12 and 24 hours ahead will only show in the applet; tonight's ice starts at +10 h, so both catch it.
Your applet threshold setting: the applet always uses 3.0°C for these hazards and ignores your thresh-ice-alert setting of 1.5. Connect IQ now does the same with its threshIceAlert setting.


==>
alert settings config central