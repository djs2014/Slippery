import Toybox.Math;
import Toybox.System;
import Toybox.Lang;

class AeroPacingCalculator {

    // Standard constants (Sea-level air density, average cyclist CdA, total mass)
    private static const RHO = 1.225f;       // Air density kg/m^3
    private static const CDA = 0.320f;       // Typical road bike hood position CdA
    private static const MASS_KG = 80.0f;    // Rider + bike mass
    private static const GRAVITY = 9.81f;

    /**
     * Calculates the apparent headwind component (km/h)
     * Positive = Headwind, Negative = Tailwind
     */
    public static function getNetHeadwind(
        groundSpeedKmh as Float, 
        windSpeedKmh as Float, 
        windDirDeg as Number, 
        headingDeg as Number
    ) as Float {
        var relAngleRad = Math.toRadians((windDirDeg - headingDeg + 360) % 360);
        var headwindComponent = windSpeedKmh * Math.cos(relAngleRad);
        
        // Apparent headwind includes ground speed movement through still air
        return groundSpeedKmh + headwindComponent;
    }

    /**
     * Calculates the perpendicular cross-gust component (km/h)
     */
    public static function getCrossGust(
        gustSpeedKmh as Float, 
        windDirDeg as Number, 
        headingDeg as Number
    ) as Float {
        var relAngleRad = Math.toRadians((windDirDeg - headingDeg + 360) % 360);
        return (gustSpeedKmh * Math.sin(relAngleRad)).abs();
    }

    /**
     * Calculates Virtual Grade (% slope equivalent of headwind drag)
     */
    public static function calculateVirtualGrade(
        actualGradePercent as Float, 
        groundSpeedMps as Float, 
        apparentHeadwindMps as Float
    ) as Float {
        if (groundSpeedMps < 1.0f) { return actualGradePercent; }

        // Aero Drag Force = 0.5 * rho * CdA * (V_air)^2
        var aeroForce = 0.5f * RHO * CDA * Math.pow(apparentHeadwindMps, 2);
        
        // Equivalent grade slope (%) = (F_aero / (m * g)) * 100
        var equivalentSlope = (aeroForce / (MASS_KG * GRAVITY)) * 100.0f;
        
        return actualGradePercent + equivalentSlope;
    }

    /**
     * Calculates Recommended Power Adjustment Delta (Watts)
     */
    public static function calculatePacingDeltaWatts(
        targetPowerBase as Number, 
        apparentHeadwindKmh as Float
    ) as Number {
        if (apparentHeadwindKmh > 10.0f) {
            // Push up to +10% into headwind for optimal TT pacing
            var bonus = (apparentHeadwindKmh - 10.0f) * 0.8f;
            return (bonus > 25.0f) ? 25 : bonus.toNumber();
        } else if (apparentHeadwindKmh < -10.0f) {
            // Back off up to -8% in tailwinds to save energy
            var discount = (apparentHeadwindKmh + 10.0f) * 0.5f;
            return (discount < -20.0f) ? -20 : discount.toNumber();
        }
        return 0;
    }
}