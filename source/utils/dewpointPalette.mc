import Toybox.Graphics;
import Toybox.Math;
import Toybox.Lang;

class DewpointPalette {
    // RGB Matrix: [DewpointThreshold (°C), Red, Green, Blue]
    private static const DEWPOINT_TABLE as Array<Array<Number> > = [
        [0, 229, 232, 232], // Very Cold / Dry
        [4, 153, 170, 187],
        [6, 232, 248, 245],
        [8, 212, 239, 223],
        [10, 163, 228, 215],
        [12, 169, 223, 191], // Comfortable Baseline
        [16, 249, 231, 159], // Moderate Humidity
        [18, 250, 215, 160], // Humid / Sticky
        [21, 245, 183, 177], // Uncomfortable
        [24, 230, 176, 170], // Very High
        [26, 215, 189, 226], // Severe Mugginess
        [30, 210, 180, 222], // Extreme
        [40, 56, 42, 61], // Dangerous
        [50, 215, 189, 226], // Off-the-charts
    ];

    /**
     * Retrieves hex color for a given dewpoint value (°C) with optional dark-mode shading.
     */
    public static function getColor(
        dewPoint as Float,
        isDark as Boolean
    ) as Graphics.ColorType {
        var r = DEWPOINT_TABLE[0][1];
        var g = DEWPOINT_TABLE[0][2];
        var b = DEWPOINT_TABLE[0][3];

        // Step through table to find matching band
        for (var i = DEWPOINT_TABLE.size() - 1; i >= 0; i--) {
            if (dewPoint >= DEWPOINT_TABLE[i][0]) {
                r = DEWPOINT_TABLE[i][1];
                g = DEWPOINT_TABLE[i][2];
                b = DEWPOINT_TABLE[i][3];
                break;
            }
        }

        // Apply dark mode shade reduction (-30 RGB component reduction)
        if (isDark) {
            r = r > 30 ? r - 30 : 0;
            g = g > 30 ? g - 30 : 0;
            b = b > 30 ? b - 30 : 0;
        }

        // Combine RGB channels into a single 24-bit hex integer (0xRRGGBB)
        return (r << 16) | (g << 8) | b;
    }
}
