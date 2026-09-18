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
}

public class AlertStateAnalyzer {
    // Evaluates environment data and returns the highest-priority state
    public static function evaluateDisplayState(
        surfaceTemp as Float,
        crossGustKmh as Float,
        netWindKmh as Float
    ) as AlertState {
        // 1. Ice / Freezing road surfaces (Absolute highest safety priority)
        if (surfaceTemp <= 3.0f) {
            return STATE_ICE_ALERT;
        }

        // 3. Dangerous Lateral Gusts
        if (crossGustKmh >= 20.0f) {
            return STATE_HIGH_CROSSWIND;
        }

        // 5. Significant Aero Headwind
        if (netWindKmh >= 15.0f) {
            return STATE_AERO_HEADWIND;
        }

        return STATE_NORMAL;
    }

    public function drawContextualBanner(
        dc as Dc,
        state as AlertState,
        rainIn30MinMmHr as Float,
        x as Number,
        y as Number,
        w as Number,
        h as Number
    ) as Void {
        switch (state) {
            // case STATE_HEAVY_RAIN:
            //     // High-visibility blue alert box
            //     dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_DK_BLUE);
            //     dc.fillRectangle(x, y, w, h);
            //     dc.drawText(
            //         x + w / 2,
            //         y + 2,
            //         Graphics.FONT_TINY,
            //         "HEAVY RAIN!",
            //         Graphics.TEXT_JUSTIFY_CENTER
            //     );
            //     break;

            // case STATE_RAIN_SOON:
            //     // Forecast alert ahead of time
            //     dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
            //     var msg = Lang.format("RAIN SOON (~$1$mm)", [
            //         rainIn30MinMmHr.format("%.1f"),
            //     ]);
            //     dc.drawText(
            //         x + w / 2,
            //         y + 2,
            //         Graphics.FONT_TINY,
            //         msg,
            //         Graphics.TEXT_JUSTIFY_CENTER
            //     );
            //     break;

            case STATE_HIGH_CROSSWIND:
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_RED);
                dc.fillRectangle(x, y, w, h);
                dc.drawText(
                    x + w / 2,
                    y + 2,
                    Graphics.FONT_TINY,
                    "GUST ALERT!",
                    Graphics.TEXT_JUSTIFY_CENTER
                );
                break;

            case STATE_AERO_HEADWIND:
                dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
                dc.drawText(
                    x + w / 2,
                    y + 2,
                    Graphics.FONT_TINY,
                    "vG +3.2% | +15W",
                    Graphics.TEXT_JUSTIFY_CENTER
                );
                break;

            case STATE_NORMAL:
                // Screen stays clean: show standard power/speed or subtle weather icon
                break;
        }
    }
}
/*

Forecast Lead Time: If your backend supplies 15-minute or 30-minute weather slots, showing RAIN IN 15M gives you enough time to put on a jacket or adjust tire pressure expectations before the roads get slick.

Auto-Clear / Hysteresis: Add a small delay (e.g., 30 seconds after rain or gusts drop below threshold) before switching back to normal so the display isn't constantly flickering back and forth near threshold limits.

*/
