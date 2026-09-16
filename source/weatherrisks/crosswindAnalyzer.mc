import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// Severity Levels
enum CrosswindSeverity {
    SEVERITY_LOW = 0, // Safe / minimal lateral force
    SEVERITY_MODERATE = 1, // Noticeable force, easy to manage
    SEVERITY_CAUTION = 2, // Crosswind tugs felt on handlebars
    SEVERITY_WARNING = 3, // High instability / strong wheel displacement
    SEVERITY_HAZARD = 4, // Extreme crosswind hazard
}

// Result structure containing severity classification and visual color
public class CrosswindResult {
    public var severity as CrosswindSeverity;
    public var crosswindGustKmH as Float;
    public var color as Graphics.ColorType;

    public function initialize(
        sev as CrosswindSeverity,
        crossGust as Float,
        clr as Graphics.ColorType
    ) {
        self.severity = sev;
        self.crosswindGustKmH = crossGust;
        self.color = clr;
    }
}

class CrosswindAnalyzer {
    /**
     * Calculates lateral gust impact based on relative wind angle and rider heading.
     *
     * @param windDirDeg Angle wind is coming FROM (0-359 deg)
     * @param headingDeg Current rider heading (0-359 deg)
     * @param gustKmH    Gust speed in km/h
     * @param isDark     True for dark background mode
     */
    public static function evaluateCrosswind(
        windDirDeg as Number,
        headingDeg as Number?,
        gustKmH as Float,
        isDark as Boolean
    ) as CrosswindResult {
        if (headingDeg == null) {
            headingDeg = 0;
        }        
                
        // Calculate relative angle between wind direction and heading
        var relAngleDeg = (windDirDeg - headingDeg) % 360;
        if (relAngleDeg < 0) {
            relAngleDeg += 360;
        }

        // Calculate perpendicular lateral component: gust * |sin(relativeAngle)|
        var rad = Math.toRadians(relAngleDeg.toFloat());
        var crosswindFactor = Math.sin(rad).abs();
        var effectiveCrossGust = gustKmH * crosswindFactor;

        var severity = SEVERITY_LOW;
        var color = isDark ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;

        // Thresholds based on true lateral force (km/h)
        if (effectiveCrossGust < 12.0f) {
            severity = SEVERITY_LOW;
            color = isDark ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        } else if (effectiveCrossGust < 20.0f) {
            severity = SEVERITY_MODERATE;
            color = isDark ? Graphics.COLOR_GREEN : Graphics.COLOR_DK_GREEN;
        } else if (effectiveCrossGust < 28.0f) {
            severity = SEVERITY_CAUTION;
            color = Graphics.COLOR_YELLOW;
        } else if (effectiveCrossGust < 38.0f) {
            severity = SEVERITY_WARNING;
            color = Graphics.COLOR_ORANGE;
        } else {
            severity = SEVERITY_HAZARD;
            color = Graphics.COLOR_RED;
        }

        return new CrosswindResult(severity, effectiveCrossGust, color);
    }
}


