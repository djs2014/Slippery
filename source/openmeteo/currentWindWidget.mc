import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;

class CurrentWindWidget {
    public static function draw(
        dc as Graphics.Dc,
        cx as Number,
        cy as Number,
        windSpeed as Float,
        gust as Float,
        windDirDeg as Number,
        headingDeg as Number?, // Pass null if activity not started / no heading
        useRelativeHeading as Boolean,
        isDark as Boolean,
        isBigField as Boolean // Scaling factor for big fields + inline speed label
    ) as Void {
        // 1. DETERMINE DISPLAY ANGLE
        var effectiveAngle = windDirDeg;
        var isRelative = useRelativeHeading && headingDeg != null;

        if (isRelative) {
            // Wind arrow points WHERE wind is blowing TO (windDirDeg + 180).
            // Subtract headingDeg so 0 deg relative = straight ahead.
            effectiveAngle = windDirDeg + 180.0f - headingDeg;
        } else {
            // Absolute cardinal mode: point towards destination vector (windDir + 180)
            effectiveAngle = windDirDeg + 180.0f;
        }

        // 2. DIMENSION SCALING
        var scale = isBigField ? 2.0f : 1.0f;
        var len = (28 * scale).toNumber();
        var baseHalfWidth = (10 * scale).toNumber();

        if (windSpeed >= 35.0f) {
            len = (38 * scale).toNumber();
            baseHalfWidth = (14 * scale).toNumber();
        } else if (windSpeed >= 25.0f) {
            len = (34 * scale).toNumber();
            baseHalfWidth = (12 * scale).toNumber();
        } else if (windSpeed >= 18.0f) {
            len = (30 * scale).toNumber();
            baseHalfWidth = (11 * scale).toNumber();
        }

        // Depth of the rear indent (30% of total arrow length)
        var indentDepth = len * 0.30f;

        // Direction unit vector
        var rad = Math.toRadians(effectiveAngle);
        var uX = Math.sin(rad);
        var uY = -Math.cos(rad);

        // Perpendicular vector for base (+90 deg rotation)
        var pX = -uY;
        var pY = uX;

        var halfLen = len / 2.0f;
        var apexX = cx + (halfLen * uX).toNumber();
        var apexY = cy + (halfLen * uY).toNumber();
        var baseX = cx - (halfLen * uX).toNumber();
        var baseY = cy - (halfLen * uY).toNumber();

        // Rear Outer Corners
        var corner1X = baseX + (baseHalfWidth * pX).toNumber();
        var corner1Y = baseY + (baseHalfWidth * pY).toNumber();
        var corner2X = baseX - (baseHalfWidth * pX).toNumber();
        var corner2Y = baseY - (baseHalfWidth * pY).toNumber();

        // Rear Center Inset Point (Notch)
        var indentX = baseX + (indentDepth * uX).toNumber();
        var indentY = baseY + (indentDepth * uY).toNumber();

        var mainColor = isDark ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        var haloColor = isDark ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE;

        // Highlight crosswinds in red/orange if relative mode is active
        if (isRelative) {
            var normRel = (windDirDeg - headingDeg).toNumber() % 360;
            if (normRel < 0) {
                normRel += 360;
            }
            var isCrosswind =
                (normRel >= 45 && normRel <= 135) ||
                (normRel >= 225 && normRel <= 315);

            if (isCrosswind && gust >= 30.0f) {
                mainColor = isDark ? 0xff5500 : 0xcc0000; // Warning Orange/Red
            }
        }

        // --- STEP A: HALO BACKGROUND (4-POINT DART POLYGON) ---
        var haloPts = [
            [apexX + (uX * 3.0f).toNumber(), apexY + (uY * 3.0f).toNumber()],
            [
                corner1X + ((pX - uX) * 2.0f).toNumber(),
                corner1Y + ((pY - uY) * 2.0f).toNumber(),
            ],
            [
                indentX - (uX * 2.0f).toNumber(),
                indentY - (uY * 2.0f).toNumber(),
            ],
            [
                corner2X - ((pX + uX) * 2.0f).toNumber(),
                corner2Y - ((pY + uY) * 2.0f).toNumber(),
            ],
        ];
        dc.setColor(haloColor, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(haloPts);

        // --- STEP B: FILLED 4-POINT DART ---
        var dartPts = [
            [apexX, apexY],
            [corner1X, corner1Y],
            [indentX, indentY],
            [corner2X, corner2Y],
        ];
        dc.setColor(mainColor, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(dartPts);
       
        // --- STEP D: GUST BARS BEHIND BASE NOTCH ---
        var numGustBars = $.calculateGustSeverity(windSpeed, gust);
        // var gustRatio = windSpeed > 1.0f ? gust / windSpeed : 1.0f;
        // var numGustBars = 0;

        // if (gust >= 45.0f || gustRatio >= 1.7f) {
        //     numGustBars = 3;
        // } else if (gust >= 35.0f || gustRatio >= 1.5f) {
        //     numGustBars = 2;
        // } else if (gust >= 25.0f || gustRatio >= 1.3f) {
        //     numGustBars = 1;
        // }

        var barSpacing = (6 * scale).toNumber();
        var barWidth = baseHalfWidth + (3 * scale).toNumber();

        for (var b = 1; b <= numGustBars; b++) {
            // Gust bars offset backwards relative to the rear outer corners
            var bCenterX = baseX - (b * barSpacing * uX).toNumber();
            var bCenterY = baseY - (b * barSpacing * uY).toNumber();

            var bX1 = bCenterX + (barWidth * pX).toNumber();
            var bY1 = bCenterY + (barWidth * pY).toNumber();
            var bX2 = bCenterX - (barWidth * pX).toNumber();
            var bY2 = bCenterY - (barWidth * pY).toNumber();

            // Halo Outline for Gust Bars
            dc.setColor(haloColor, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(bX1 - 2, bY1, bX2 - 2, bY2);
            dc.drawLine(bX1 + 2, bY1, bX2 + 2, bY2);
            dc.drawLine(bX1, bY1 - 2, bX2, bY2 - 2);
            dc.drawLine(bX1, bY1 + 2, bX2, bY2 + 2);

            // Foreground bar
            dc.setColor(mainColor, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(bX1, bY1, bX2, bY2);
            dc.drawLine(
                bX1 + uX.toNumber(),
                bY1 + uY.toNumber(),
                bX2 + uX.toNumber(),
                bY2 + uY.toNumber()
            );
        }
    }
}
