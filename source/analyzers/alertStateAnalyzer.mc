import Toybox.System;
import Toybox.Lang;
import Toybox.Graphics;

// Rain alerts already shown using the forecast banner.
// No need to check or trigger rain alerts separately
enum AlertState {
    STATE_NORMAL = 0,
    STATE_ICE_ALERT = 1,
    STATE_HIGH_CROSSWIND = 2,
    STATE_AERO_HEADWIND = 3,
    STATE_HEAT_STRESS = 4,
    STATE_HEAVY_WIND = 5,
}

public class AlertStateAnalyzer {
    private static var lastAlertState as AlertState = STATE_NORMAL;
    private static var stateHysteresisCounter as Number = 0;

    // Hold state for 30 cycles (e.g., 30 seconds if tick is 1s) before clearing lower
    private static const HYSTERESIS_HOLD_CYCLES = 30;

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

        // 2. Immediate Escalation: Higher priority state triggers instantly
        if (rawState > lastAlertState) {
            lastAlertState = rawState;
            stateHysteresisCounter = HYSTERESIS_HOLD_CYCLES;
            return lastAlertState;
        }

        // 3. De-escalation: Hold state until counter expires
        if (rawState < lastAlertState) {
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

    private static function evaluateRawState(
        surfaceTemp as Float,
        crossGustKmh as Float,
        sustainedWindKmh as Float,
        netHeadwindKmh as Float,
        feelsLikeTemp as Float
    ) as AlertState {
        if (surfaceTemp <= 3.0f) {
            return STATE_ICE_ALERT;
        }
        if (crossGustKmh >= 25.0f) {
            return STATE_HIGH_CROSSWIND;
        }
        if (sustainedWindKmh >= 35.0f) {
            return STATE_HEAVY_WIND;
        }
        if (netHeadwindKmh >= 15.0f) {
            return STATE_AERO_HEADWIND;
        }
        if (feelsLikeTemp >= 32.0f) {
            return STATE_HEAT_STRESS;
        }

        return STATE_NORMAL;
    }
}
