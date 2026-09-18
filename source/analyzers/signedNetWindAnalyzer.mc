import Toybox.Lang;
import Toybox.System;
import Toybox.Math;

class NetwindAnalyzer {
    /**
     * Calculates signed headwind/tailwind component.
     *
     * @param windSpeed Speed of wind (e.g., km/h)
     * @param windDirDeg Angle wind is coming FROM (0-360)
     * @param headingDeg Current rider heading (0-360)
     * @return Positive float for Tailwind, Negative float for Headwind
     */
    static function calculateNetWind(
        windSpeed as Float,
        windDirDeg as Number,
        headingDeg as Null or Number
    ) as Float {
        if (headingDeg == null) {
            headingDeg = 0;
        }        
        // Wind vector angle (where wind is blowing TO)
        var windToDeg = windDirDeg + 180.0f;

        // Angle relative to heading
        var relRad = Math.toRadians(windToDeg - headingDeg);

        // cos(0) = +1.0 (Full Tailwind), cos(180) = -1.0 (Full Headwind)
        var netWind = windSpeed * Math.cos(relRad);

        return netWind;
    }

    // Formatting Helper for UI Display: "+12 TW" or "-8 HW"
    static function formatNetWind(netWind as Float) as String {
        var absVal = Math.round(netWind.abs()).toNumber();
        if (netWind >= 0) {
            return "+" + absVal + " TW";
        } else {
            return "-" + absVal + " HW";
        }
    }
}
