import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;

class CurrentWindWidget {
    public static function draw(
        dc as Graphics.Dc,
        cx as Number,
        cy as Number,
        y, // Top Y boundary
        h, // Total height of the DataField
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

        // --- STEP D: TAPERED GUST CHEVRONS (DIMENSION CLAMPED) ---
        var numGustBars = $.calculateGustSeverity(windSpeed, gust);

        if (numGustBars > 0) {
            // 1. DIMENSION CONSTRAINTS
            // Calculate max vertical extent available from cy before clipping field bounds
            // Margin of 4px accounts for halo outline padding
            var bottomEdgeY = y + h - 4;

            // 2. TUNING PARAMETERS
            var gapBetweenBars = (5 * scale).toNumber();
            var barHeight = (7 * scale).toNumber();
            var bottomIndentDepth = 2.5f * scale;

            // Calculate outer edge slope of the main dart
            var arrowEffectiveLength = len - indentDepth;
            var slope =
                arrowEffectiveLength > 0
                    ? baseHalfWidth.toFloat() / arrowEffectiveLength.toFloat()
                    : 0.4f;

            var currentBackDist = 0.0f;

            for (var b = 1; b <= numGustBars; b++) {
                var nextBackDist = currentBackDist + gapBetweenBars + barHeight;

                // Test predicted lowest Y position of this chevron (Rear Indent Point)
                var testBaseX = baseX - (nextBackDist * uX).toNumber();
                var testBaseY = baseY - (nextBackDist * uY).toNumber();
                var testIndentY =
                    testBaseY + (bottomIndentDepth * uY).toNumber();

                // CLAMP CHECK: If the rear notch exceeds field bounds, stop rendering further chevrons
                if (testIndentY > bottomEdgeY || testIndentY < y + 4) {
                    break;
                }

                currentBackDist = nextBackDist;

                // Base anchor point
                var bBaseX = testBaseX;
                var bBaseY = testBaseY;

                // Dynamic outer width (expands along main arrow slope)
                var extraDistFromApex = len / 2.0f + currentBackDist;
                var barWidth = (extraDistFromApex * slope).toNumber();

                // 1. Forward Triangular Peak
                var bApexX = bBaseX + (barHeight * uX).toNumber();
                var bApexY = bBaseY + (barHeight * uY).toNumber();

                // 2. Outer Wing Corners
                var bCorner1X = bBaseX + (barWidth * pX).toNumber();
                var bCorner1Y = bBaseY + (barWidth * pY).toNumber();

                var bCorner2X = bBaseX - (barWidth * pX).toNumber();
                var bCorner2Y = bBaseY - (barWidth * pY).toNumber();

                // 3. Rear Center Indent Notch
                var bIndentX = bBaseX + (bottomIndentDepth * uX).toNumber();
                var bIndentY = bBaseY + (bottomIndentDepth * uY).toNumber();

                // --- CHEVRON HALO (OUTLINE) ---
                var gustHaloPts = [
                    [
                        bApexX + (uX * 2.0f).toNumber(),
                        bApexY + (uY * 2.0f).toNumber(),
                    ],
                    [
                        bCorner1X + ((pX - uX) * 1.5f).toNumber(),
                        bCorner1Y + ((pY - uY) * 1.5f).toNumber(),
                    ],
                    [
                        bIndentX - (uX * 1.5f).toNumber(),
                        bIndentY - (uY * 1.5f).toNumber(),
                    ],
                    [
                        bCorner2X - ((pX + uX) * 1.5f).toNumber(),
                        bCorner2Y - ((pY + uY) * 1.5f).toNumber(),
                    ],
                ];
                dc.setColor(haloColor, Graphics.COLOR_TRANSPARENT);
                dc.fillPolygon(gustHaloPts);

                // --- CHEVRON FOREGROUND POLYGON ---
                var gustChevronPts = [
                    [bApexX, bApexY], // Forward Apex
                    [bCorner1X, bCorner1Y], // Outer Right
                    [bIndentX, bIndentY], // Rear Notch
                    [bCorner2X, bCorner2Y], // Outer Left
                ];
                dc.setColor(mainColor, Graphics.COLOR_TRANSPARENT);
                dc.fillPolygon(gustChevronPts);
            }
        }
    }
}
