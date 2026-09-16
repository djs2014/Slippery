import Toybox.Graphics;
import Toybox.Lang;

class ComfortColors {

    /**
     * Maps temperature/dewpoint values to intuitive weather colors:
     * Grey (Freezing) -> Blue (Cold) -> Green (Comfortable) -> Yellow (Warm) -> Orange (Hot) -> Red (Extreme)
     */
    public static function getComfortColor(
        tempCelsius as Float,
        isDark as Boolean
    ) as Graphics.ColorType {
        if (tempCelsius < 2.0f) {
            // Freezing / Very Cold: Slate Grey / Ice Blue
            return isDark ? 0x778899 : 0x708090;
        } else if (tempCelsius < 12.0f) {
            // Cold: Deep Cyan / Blue
            return isDark ? 0x00aaff : 0x0077cc;
        } else if (tempCelsius < 21.0f) {
            // Ideal Comfort Range: Green / Emerald
            return isDark ? 0x00ff7f : 0x00aa44;
        } else if (tempCelsius < 27.0f) {
            // Warm / Mild: Bright Yellow / Gold
            return isDark ? 0xffff00 : 0xd4af37;
        } else if (tempCelsius < 33.0f) {
            // Hot: Amber Orange
            return isDark ? 0xffaa00 : 0xcc6600;
        } else {
            // Extreme Heat / High Dew Point Risk: Crimson Red
            return isDark ? 0xff3333 : 0xcc0000;
        }
    }
}



/**
 * Draws a compact 12-segment hourly forecast comfort strip.
 */
function drawComfortBar(
    dc as Graphics.Dc,
    startX as Number,
    startY as Number,
    totalWidth as Number,
    barHeight as Number,
    hourlyTemps as Array<Float>, // Array of 12 float values
    isDark as Boolean
) as Void {
    var numSegments = hourlyTemps.size();
    if (numSegments == 0) { return; }

    var gap = 2; // Pixel gap between hourly slots
    var segmentWidth = (totalWidth - (gap * (numSegments - 1))) / numSegments;

    for (var i = 0; i < numSegments; i++) {
        var segX = startX + (i * (segmentWidth + gap));
        var segColor = ComfortColors.getComfortColor(hourlyTemps[i], isDark);

        dc.setColor(segColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(segX, startY, segmentWidth, barHeight);
    }
}