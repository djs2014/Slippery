import Toybox.Graphics;
import Toybox.Math;
import Toybox.Lang;
import Toybox.System;

class SubSegmentedForecastBar {
    /**
     * Helper to compute the global max precipitation rate across forecast hour.
     * Enforces a minimum scale ceiling (e.g., 2.0 mm/h) so light drizzles don't spike to max height.
     */
    public static function computeGlobalMaxRate(
        rain15min as Array<Float>,
        snow15min as Array<Float>,
        minCeilingMmh as Float
    ) as Float {
        var globalMax = minCeilingMmh;

        for (var i = 0; i < rain15min.size(); i++) {
            var rRate = (rain15min[i] != null ? rain15min[i] : 0.0f) * 4.0f;
            var sRate =
                (i < snow15min.size() && snow15min[i] != null
                    ? snow15min[i]
                    : 0.0f) * 4.0f;
            var total = rRate + sRate;

            if (total > globalMax) {
                globalMax = total;
            }
        }

        return globalMax;
    }

    /**
     * Draws a 1-hour forecast bar subdivided into 4 x 15-min blocks,
     * scaled relative to a global maxPrecip value across all hours.
     * Bar height: is rain + snow combined. If snow is present, it will be overlaid with diagonal hatching.
     *
     * @param maxPrecipMmh Global maximum precipitation rate (mm/h) across the entire multi-hour timeline.
     */
    public static function drawSubdividedHourScaled(
        dc as Graphics.Dc,
        x as Number,
        y as Number,
        barWidth as Number,
        barHeight as Number,
        rain15min as Array<Float>,
        snow15min as Array<Float>,
        maxPrecipMmh as Float,
        isDark as Boolean
    ) as Void {
        var numSubBlocks = 4;
        var subGap = 1;
        var totalGaps = (numSubBlocks - 1) * subGap;
        var subWidth = (barWidth - totalGaps) / numSubBlocks;

        // Fallback to 2.0 mm/h if maxPrecipMmh is 0 to avoid division by zero
        var scaleCeiling = maxPrecipMmh > 0.05f ? maxPrecipMmh : 2.0f;
        var baselineY = y + barHeight;

        for (var i = 0; i < numSubBlocks; i++) {
            var rVal =
                i < rain15min.size() && rain15min[i] != null
                    ? rain15min[i]
                    : 0.0f;
            var sVal =
                i < snow15min.size() && snow15min[i] != null
                    ? snow15min[i]
                    : 0.0f;

            // Convert 15-min rates to hourly rates by multiplying by 4
            var rRate = rVal * 4.0f;
            var sRate = sVal * 4.0f;
            var totalRate = rRate + sRate;

            var subX = x + i * (subWidth + subGap);

            // 1. Draw subtle background track
            // var trackColor = isDark ? 0x222222 : 0xE0E0E0;
            // dc.setColor(trackColor, Graphics.COLOR_TRANSPARENT);
            // dc.fillRectangle(subX.toNumber(), y, subWidth.toNumber(), barHeight);

            if (totalRate <= 0.05f) {
                continue; // Dry interval
            }

            // 2. Height scaled to shared global ceiling (maxPrecipMmh)
            // System.println("Total rate: " + totalRate + ", Scale ceiling: " + scaleCeiling + ", Bar height: " + barHeight);
            var fillPx = Math.round(
                (totalRate / scaleCeiling) * barHeight
            ).toNumber();
            if (fillPx < 2) {
                fillPx = 2;
            }
            if (fillPx > barHeight) {
                fillPx = barHeight;
            }

            var fillY = baselineY - fillPx;
            var intX = subX.toNumber();
            var intW = subWidth.toNumber();

            // 3. Solid base fill for rain (or light blue for snow-only)
            var baseColor =
                rRate > 0.0f
                    ? isDark
                        ? 0x3377ff
                        : 0x0000a8
                    : isDark
                      ? 0x97b9ff
                      : 0x7994cc;

            dc.setColor(baseColor, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(intX, fillY, intW, fillPx);
            //System.println("Rectangle " + i + " drawn at X: " + intX + ", Y: " + fillY + ", Width: " + intW + ", Height: " + fillPx);

            // 4. Diagonal line hatching for snow overlay
            //
            if (sRate > 0.0f) {
                var patternColor = Graphics.COLOR_WHITE;
                dc.setColor(patternColor, Graphics.COLOR_TRANSPARENT);

                for (var offset = -fillPx; offset < intW; offset += 4) {
                    var x1 = intX + offset;
                    var y1 = baselineY;
                    var x2 = intX + offset + fillPx;
                    var y2 = fillY;

                    if (x1 < intX) {
                        y1 = baselineY - (intX - x1);
                        x1 = intX;
                    }
                    if (x2 > intX + intW) {
                        y2 = fillY + (x2 - (intX + intW));
                        x2 = intX + intW;
                    }

                    if (y1 >= fillY && y2 <= baselineY && x1 <= intX + intW) {
                        dc.drawLine(x1, y1, x2, y2);
                    }
                }

                // Add horizontal line to mark amount of snow
                var fillPxSnow = Math.round(
                    (sRate / scaleCeiling) * barHeight
                ).toNumber();
                if (fillPxSnow < 2) {
                    fillPxSnow = 2;
                }
                if (fillPxSnow > barHeight) {
                    fillPxSnow = barHeight;
                }
                fillY = baselineY - fillPxSnow;
                dc.drawLine(intX, fillY, intX + intW, fillY);
            }

            // Add horizontal line to mark amount of rain
            dc.setColor(baseColor, Graphics.COLOR_TRANSPARENT);
            var fillPxRain = Math.round(
                (rRate / scaleCeiling) * barHeight
            ).toNumber();
            if (fillPxRain < 2) {
                fillPxRain = 2;
            }
            if (fillPxRain > barHeight) {
                fillPxRain = barHeight;
            }
            dc.drawLine(
                intX,
                baselineY - fillPxRain,
                intX + intW,
                baselineY - fillPxRain
            );
        }
    }

    // private static function getRainColor(
    //     rateMmh as Float,
    //     isDark as Boolean
    // ) as Graphics.ColorType {
    //     if (rateMmh < 0.5f) {
    //         return isDark ? 0x3399ff : 0x55aaff;
    //     }
    //     if (rateMmh < 2.5f) {
    //         /return isDark ? 0x0055ff : 0x0044cc;
    //     }
    //     if (rateMmh < 7.6f) {
    //         return isDark ? 0xff9900 : 0xdd7700;
    //     }
    //     return isDark ? 0xff2222 : 0xcc0000;
    // }
}
