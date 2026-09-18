import Toybox.Lang;
import Toybox.System;
import Toybox.Graphics;

    public enum AlertCategory {
        CATEGORY_NONE,
        CATEGORY_WIND,
        CATEGORY_COLD,
        CATEGORY_HEAT,
    }
public class AlertCategoryRenderer {
    public static function getCategoryForState(
        state as AlertState
    ) as AlertCategory {
        switch (state) {
            case STATE_ICE_ALERT:
                return CATEGORY_COLD;

            case STATE_HIGH_CROSSWIND:
            case STATE_HEAVY_WIND:
            case STATE_MODERATE_CROSSWIND:
            case STATE_SUSTAINED_WIND:
            case STATE_AERO_HEADWIND:
                return CATEGORY_WIND;

            case STATE_HEAT_STRESS:
                return CATEGORY_HEAT;

            case STATE_NORMAL:
            default:
                return CATEGORY_NONE;
        }
    }

    public static function drawCategoryIcon(
        dc as Graphics.Dc,
        cx as Number,
        cy as Number,
        size as Number,
        category as AlertCategory,
        color as Graphics.ColorType
    ) as Void {
        if (category == CATEGORY_NONE) {
            return;
        }

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var r = size / 2;

        switch (category) {
            case CATEGORY_WIND:
                // Draw 2 dynamic wind flow lines with trail tails
                dc.setPenWidth(2);

                // Top flow line (longer)
                dc.drawLine(cx - r + 2, cy - 3, cx + r - 2, cy - 3);
                dc.drawLine(cx + r - 2, cy - 3, cx + r, cy - 5); // trailing flick

                // Bottom flow line (shorter offset)
                dc.drawLine(cx - r + 5, cy + 3, cx + r - 4, cy + 3);
                dc.drawLine(cx + r - 4, cy + 3, cx + r - 2, cy + 5);
                break;

            case CATEGORY_COLD:
                // Draw 6-point snowflake (3 intersecting axis lines)
                dc.setPenWidth(2);

                // Vertical & Horizontal axes
                dc.drawLine(cx, cy - r + 1, cx, cy + r - 1);
                dc.drawLine(cx - r + 1, cy, cx + r - 1, cy);

                // Diagonal cross axes
                var diag = (r * 0.7).toNumber();
                dc.drawLine(cx - diag, cy - diag, cx + diag, cy + diag);
                dc.drawLine(cx - diag, cy + diag, cx + diag, cy - diag);
                break;

            case CATEGORY_HEAT:
                // Draw thermometer (bottom bulb + vertical stem)
                var bulbRadius = (r * 0.45).toNumber();
                if (bulbRadius < 3) {
                    bulbRadius = 3;
                }

                var stemWidth = (bulbRadius * 1.2).toNumber();
                var stemHeight = r + 1;

                // Thermometer body stem
                dc.fillRectangle(
                    cx - stemWidth / 2,
                    cy - r + 2,
                    stemWidth,
                    stemHeight
                );

                // Bottom mercury bulb
                dc.fillCircle(cx, cy + r - bulbRadius, bulbRadius + 1);

                // Rounded top cap for tube
                dc.fillCircle(cx, cy - r + 2, stemWidth / 2);
                break;

            default:
                break;
        }
    }
}
