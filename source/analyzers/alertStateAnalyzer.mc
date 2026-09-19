import Toybox.System;
import Toybox.Lang;
import Toybox.Graphics;

// Rain alerts already shown using the forecast banner.
// No need to check or trigger rain alerts separately
enum AlertState {
    STATE_NORMAL = 0,
    STATE_ICE_ALERT = 1,
    STATE_HIGH_CROSSWIND = 2,
    STATE_HEAVY_WIND = 3,
    STATE_MODERATE_CROSSWIND = 4,
    STATE_SUSTAINED_WIND = 5,
    STATE_AERO_HEADWIND = 6,
    STATE_HEAT_STRESS = 7,
}

public class AlertStateAnalyzer {
    private static var lastAlertState as AlertState = STATE_NORMAL;
    private static var stateHysteresisCounter as Number = 0;

    // Hold state for 30 cycles (e.g., 30 seconds if tick is 1s) before clearing lower
    private static const HYSTERESIS_HOLD_CYCLES = 30;

    // Severity rank, lowest (safe) to highest (most dangerous).
    // NOTE: this is intentionally NOT the AlertState enum order (where e.g.
    // STATE_ICE_ALERT = 1 < STATE_HEAT_STRESS = 7). All escalation /
    // de-escalation decisions must compare severities, never raw enum values.
    public static function getSeverity(state as AlertState) as Number {
        switch (state) {
            case STATE_ICE_ALERT:
                return 7;
            case STATE_HIGH_CROSSWIND:
                return 6;
            case STATE_HEAVY_WIND:
                return 5;
            case STATE_MODERATE_CROSSWIND:
                return 4;
            case STATE_SUSTAINED_WIND:
                return 3;
            case STATE_AERO_HEADWIND:
                return 2;
            case STATE_HEAT_STRESS:
                return 1;
            case STATE_NORMAL:
            default:
                return 0;
        }
    }

    public static function updateAndEvaluate(
        surfaceTemp as Float,
        crossGustKmh as Float,
        sustainedWindKmh as Float,
        netHeadwindKmh as Float,
        feelsLikeTemp as Float
    ) as AlertState {
        // 1. Calculate the instantaneous state based on raw thresholds
        var rawState = evaluateRawState(
            surfaceTemp,
            crossGustKmh,
            sustainedWindKmh,
            netHeadwindKmh,
            feelsLikeTemp
        );

        // 2. Immediate Escalation: Higher severity state triggers instantly
        // (compared by severity rank, not enum value)
        var rawSeverity = getSeverity(rawState);
        var lastSeverity = getSeverity(lastAlertState);
        if (rawSeverity > lastSeverity) {
            lastAlertState = rawState;
            stateHysteresisCounter = HYSTERESIS_HOLD_CYCLES;
            return lastAlertState;
        }

        // 3. De-escalation: Hold state until counter expires
        if (rawSeverity < lastSeverity) {
            if (stateHysteresisCounter > 0) {
                stateHysteresisCounter--;
                return lastAlertState; // Keep displaying higher alert
            } else {
                lastAlertState = rawState; // Counter expired; drop state
                stateHysteresisCounter = HYSTERESIS_HOLD_CYCLES;
            }
        } else {
            // Raw state matches active alert state; refresh hold counter
            stateHysteresisCounter = HYSTERESIS_HOLD_CYCLES;
        }

        return lastAlertState;
    }

    public static function setTreshIceAlert(value as Float) as Void {
        threshIceAlert = value;
    }
    public static function setTreshHighCrosswind(value as Float) as Void {
        threshHighCrosswind = value;
    }
    public static function setTreshCrossGust(value as Float) as Void {
        threshCrossGust = value;
    }
    public static function setTreshHeavyWind(value as Float) as Void {
        threshHeavyWind = value;
    }
    public static function setTreshSustainedWind(value as Float) as Void {
        threshSustainedWind = value;
    }
    public static function setTreshHeadwind(value as Float) as Void {
        // Negative sign convention: menu stores a positive magnitude.
        // Force negative so a stored negative value cannot invert the alert.
        if (value > 0.0f) {
            value = value * -1.0f;
        }
        threshHeadwind = value;
    }
    public static function setTreshHeatStress(value as Float) as Void {
        threshHeatStress = value;
    }

    // User-configurable thresholds
    public static var threshIceAlert as Float = 3.0f;

    public static var threshHighCrosswind as Float = 25.0f; // High hazard
    public static var threshCrossGust as Float = 18.0f; // Moderate alert

    public static var threshHeavyWind as Float = 35.0f; // Extreme ambient
    public static var threshSustainedWind as Float = 25.0f; // Moderate ambient

    public static var threshHeadwind as Float = -12.0f; // Negative sign convention
    public static var threshHeatStress as Float = 32.0f;

    private static function evaluateRawState(
        surfaceTemp as Float,
        crossGustKmh as Float,
        sustainedWindKmh as Float,
        netHeadwindKmh as Float,
        feelsLikeTemp as Float
    ) as AlertState {
        // 1. Direct Safety Hazard: Ice
        if (surfaceTemp <= threshIceAlert) {
            return STATE_ICE_ALERT;
        }

        // 2. High Stability Hazard: Severe Crosswind Gusts
        if (crossGustKmh >= threshHighCrosswind) {
            return STATE_HIGH_CROSSWIND;
        }

        // 3. High Ambient Force: Heavy Sustained Wind
        if (sustainedWindKmh >= threshHeavyWind) {
            return STATE_HEAVY_WIND;
        }

        // 4. Moderate Stability Warning: Moderate Crosswind Gusts
        if (crossGustKmh >= threshCrossGust) {
            return STATE_MODERATE_CROSSWIND;
        }

        // 5. Moderate Ambient Force: Sustained Wind Warning
        if (sustainedWindKmh >= threshSustainedWind) {
            return STATE_SUSTAINED_WIND;
        }

        // 6. Tactical Pacing: Aerodynamic Headwind
        if (netHeadwindKmh <= threshHeadwind) {
            return STATE_AERO_HEADWIND;
        }

        // 7. Thermal Comfort
        if (feelsLikeTemp >= threshHeatStress) {
            return STATE_HEAT_STRESS;
        }

        return STATE_NORMAL;
    }
}
