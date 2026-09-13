import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

class CurrentWindWidget {
    // Helper: Formats relative angle into a simple textual indicator
    public static function getWindTypeLabel(relAngleDeg as Float) as String {
        // Normalize angle to [0, 360)
        var norm = relAngleDeg.toNumber() % 360;
        if (norm < 0) {
            norm += 360;
        }

        if (norm >= 337 || norm < 23) {
            return "HEADWIND";
        } else if (norm >= 23 && norm < 68) {
            return "CROSS-HEAD (R)";
        } else if (norm >= 68 && norm < 113) {
            return "CROSSWIND (R)";
        } else if (norm >= 113 && norm < 158) {
            return "CROSS-TAIL (R)";
        } else if (norm >= 158 && norm < 203) {
            return "TAILWIND";
        } else if (norm >= 203 && norm < 248) {
            return "CROSS-TAIL (L)";
        } else if (norm >= 248 && norm < 293) {
            return "CROSSWIND (L)";
        } else {
            return "CROSS-HEAD (L)";
        }
    }

    public static function draw(
        dc as Graphics.Dc,
        cx as Number,
        cy as Number,
        windSpeed as Float,
        gust as Float,
        windDirDeg as Number,
        headingDeg as Number?, // Pass null if activity not started / no heading
        useRelativeHeading as Boolean,
        isDark as Boolean
    ) as Void {
        // 1. DETERMINE DISPLAY ANGLE
        // If relative mode is active and heading is available, calculate wind direction relative to bike heading.
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

        // 2. LARGE WIDGET DIMENSIONS
        var len = 28;
        var baseHalfWidth = 10;
        if (windSpeed >= 35.0f) {
            len = 38;
            baseHalfWidth = 14;
        } else if (windSpeed >= 25.0f) {
            len = 34;
            baseHalfWidth = 12;
        } else if (windSpeed >= 18.0f) {
            len = 30;
            baseHalfWidth = 11;
        }

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

        var corner1X = baseX + (baseHalfWidth * pX).toNumber();
        var corner1Y = baseY + (baseHalfWidth * pY).toNumber();
        var corner2X = baseX - (baseHalfWidth * pX).toNumber();
        var corner2Y = baseY - (baseHalfWidth * pY).toNumber();

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
                mainColor = isDark ? 0xff5500 : 0xcc0000; // Warning Orange/Red for dangerous side gusts
            }
        }

        // --- STEP A: HALO BACKGROUND ---
        var haloPts = [
            [apexX + (uX * 3.0f).toNumber(), apexY + (uY * 3.0f).toNumber()],
            [
                corner1X + ((pX - uX) * 2.0f).toNumber(),
                corner1Y + ((pY - uY) * 2.0f).toNumber(),
            ],
            [
                corner2X - ((pX + uX) * 2.0f).toNumber(),
                corner2Y - ((pY + uY) * 2.0f).toNumber(),
            ],
        ];
        dc.setColor(haloColor, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(haloPts);

        // --- STEP B: FILLED WEDGE ---
        var trianglePts = [
            [apexX, apexY],
            [corner1X, corner1Y],
            [corner2X, corner2Y],
        ];
        dc.setColor(mainColor, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(trianglePts);

        // --- STEP C: LARGE GUST BARS BEHIND BASE ---
        var gustRatio = windSpeed > 1.0f ? gust / windSpeed : 1.0f;
        var numGustBars = 0;

        if (gust >= 45.0f || gustRatio >= 1.7f) {
            numGustBars = 3;
        } else if (gust >= 35.0f || gustRatio >= 1.5f) {
            numGustBars = 2;
        } else if (gust >= 25.0f || gustRatio >= 1.3f) {
            numGustBars = 1;
        }

        var barSpacing = 6;
        var barWidth = baseHalfWidth + 3;

        for (var b = 1; b <= numGustBars; b++) {
            var bCenterX = baseX - (b * barSpacing * uX).toNumber();
            var bCenterY = baseY - (b * barSpacing * uY).toNumber();

            var bX1 = bCenterX + (barWidth * pX).toNumber();
            var bY1 = bCenterY + (barWidth * pY).toNumber();
            var bX2 = bCenterX - (barWidth * pX).toNumber();
            var bY2 = bCenterY - (barWidth * pY).toNumber();

            // Bold Halo Outline for Gust Bars
            dc.setColor(haloColor, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(bX1 - 2, bY1, bX2 - 2, bY2);
            dc.drawLine(bX1 + 2, bY1, bX2 + 2, bY2);
            dc.drawLine(bX1, bY1 - 2, bX2, bY2 - 2);
            dc.drawLine(bX1, bY1 + 2, bX2, bY2 + 2);

            // Double-thick foreground bar
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
