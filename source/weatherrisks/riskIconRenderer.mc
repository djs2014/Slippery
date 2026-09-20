import Toybox.Graphics;
import Toybox.System;
import Toybox.Lang;
(:extendedCode) 
public class RiskIconRenderer {

    // (cx, cy) is the absolute center of the icon
    public static function drawRiskIcon(
        dc as Graphics.Dc, 
        cx as Number, 
        cy as Number, 
        size as Number, 
        riskLevel as RiskLevel, 
        color as Graphics.ColorType,
        backgroundColor as Graphics.ColorType
    ) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        
        var radius = size / 2;

        switch (riskLevel) {
            case RiskLevelSafe:
                // Solid circle centered at (cx, cy)
                dc.fillCircle(cx, cy, radius - 1);
                break;

            case RiskLevelSlight:
                // Hollow triangle using drawLine sequence around center (cx, cy)
                var p1 = [cx, cy - radius];
                var p2 = [cx + radius, cy + radius];
                var p3 = [cx - radius, cy + radius];
                
                dc.setPenWidth(2);
                dc.drawLine(p1[0], p1[1], p2[0], p2[1]);
                dc.drawLine(p2[0], p2[1], p3[0], p3[1]);
                dc.drawLine(p3[0], p3[1], p1[0], p1[1]);
                break;

            case RiskLevelModerate:
                // Solid triangle centered at (cx, cy)
                var pointsMod = [
                    [cx, cy - radius],
                    [cx + radius, cy + radius],
                    [cx - radius, cy + radius]
                ];
                dc.fillPolygon(pointsMod);
                break;

            case RiskLevelHigh:
                // Solid triangle with background cutout
                var pointsHigh = [
                    [cx, cy - radius],
                    [cx + radius, cy + radius],
                    [cx - radius, cy + radius]
                ];
                dc.fillPolygon(pointsHigh);
                
                // Cutout exclamation mark
                dc.setColor(backgroundColor, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(cx - 1, cy - (radius / 3), 2, radius - 1);
                dc.fillCircle(cx, cy + radius - 2, 1);
                break;

            case RiskLevelCritical:
                // Solid circle with horizontal bar (No Entry symbol)
                dc.fillCircle(cx, cy, radius);
                
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                var barWidth = size - 4;
                var barHeight = size / 4;
                if (barHeight < 2) { barHeight = 2; }
                dc.fillRectangle(cx - (barWidth / 2), cy - (barHeight / 2), barWidth, barHeight);
                break;

            case RiskLevelNoData:
            default:
                // Muted horizontal dash (-) centered at (cx, cy)
                var dashWidth = size - 4;
                dc.fillRectangle(cx - (dashWidth / 2), cy - 1, dashWidth, 2);
                break;
        }
    }
}