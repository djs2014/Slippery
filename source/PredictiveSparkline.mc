import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;

class PredictiveSparkline {
    public static function draw(
        dc as Graphics.Dc,
        x as Number,
        y as Number,
        width as Number,
        height as Number,
        metrics as WeatherMetrics,
        riskProfile as Array<RiskLevel>,
        isDark as Boolean,
        showLabels as Boolean
    ) as Void {
        var rainForecast = metrics.rainForecast; // Float items (mm/h)
        var windForecast = metrics.windForecast; // Float items (km/h)
        var windDirForecast = metrics.windDirForecast; // Number items (0-359 deg)
        var tempForecast = metrics.tempForecast; // Float items (°C surface/air)
        var timeStampsForeCast = metrics.timeStampsForeCast; // Number items (unixtime in seconds)

        var numHours = rainForecast.size();
        if (numHours == 0) {
            return;
        }

        var barGap = 2;
        var totalGaps = (numHours - 1) * barGap;
        var barWidth = (width - totalGaps) / numHours;

        var textColor = isDark
            ? Graphics.COLOR_LT_GRAY
            : Graphics.COLOR_DK_GRAY;
        var offsetLabels = 16;
        var offsetChartHeight = 14;
        var offsetIceBars = 12;
        if (!showLabels) {
            offsetLabels = 0;
            offsetChartHeight = 0;
            offsetIceBars = 0;
        }
        var baselineY = y + height - offsetLabels; // Reserve 16px at bottom for wind arrows + labels
        var chartHeight = baselineY - y - offsetChartHeight;

        // --- 1. FREEZING RISK BACKGROUND TINT ---
        // Highlight ice risk slots where temperature <= 0.0°C
        for (var i = 0; i < numHours; i++) {
            if (tempForecast.size() > i && tempForecast[i] <= 0.0f) {
                var bx = x + i * (barWidth + barGap);
                dc.setColor(
                    isDark ? 0x003366 : 0xcce6ff,
                    Graphics.COLOR_TRANSPARENT
                );
                dc.fillRectangle(
                    bx,
                    y + offsetIceBars,
                    barWidth,
                    chartHeight + 2
                );
            }
        }

        // --- . DRAW 12-HOUR RISK HEATMAP BAR ALONG THE BOTTOM ---
        var blockW = (width.toFloat() / numHours) + 0.5f; // Small overlap to avoid pixel gaps
        var sparklineH = height - chartHeight - 4;
        var hourColor = AppState.activePalette[ThemeManager.COLOR_BG];
        for (var i = 0; i < riskProfile.size(); i++) {
            var blockX = x + (i * (width.toFloat() / numHours));
            var blockY = y + sparklineH + 2;
            var riskColor = $.getRiskColor(riskProfile[i], isDark);

            dc.setColor(riskColor, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(blockX.toNumber(), blockY, blockW.toNumber(), chartHeight);
            // Draw the hour label below the risk bar // TODO get current hour
            if (showLabels) {
                var hourLabel = Lang.format("+$1$", [i.format("%d")]);
                dc.setColor(hourColor, Graphics.COLOR_TRANSPARENT);
                dc.drawText(
                    blockX.toNumber() + blockW.toNumber() / 2,
                    blockY + chartHeight / 2,
                    Graphics.FONT_XTINY,
                    hourLabel,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
                );
            }
        }

        // --- 3. BASELINE & TIMELINE HOUR LABELS ---
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x, baselineY, x + width, baselineY);

        if (showLabels) {
            dc.drawText(
                x,
                baselineY + 3,
                Graphics.FONT_XTINY,
                "Now",
                Graphics.TEXT_JUSTIFY_LEFT
            );

            dc.drawText(
                x + width,
                baselineY + 3,
                Graphics.FONT_XTINY,
                Lang.format("+$1$h", [numHours.format("%d")]),
                Graphics.TEXT_JUSTIFY_RIGHT
            );
        }

        // --- 4. RAIN PRECIPITATION BARS ---
        var maxRain = 2.0f;
        for (var i = 0; i < numHours; i++) {
            if (rainForecast[i] > maxRain) {
                maxRain = rainForecast[i];
            }
        }

        var rainStartIdx = -1;
        for (var i = 0; i < numHours; i++) {
            var rain = rainForecast[i];
            if (rain > 0.05f) {
                var barH = ((rain / maxRain) * chartHeight).toNumber();
                if (barH < 3) {
                    barH = 3;
                }

                var bx = x + i * (barWidth + barGap);
                var by = baselineY - barH;

                if (rain >= 2.5f) {
                    dc.setColor(
                        Graphics.COLOR_BLUE,
                        Graphics.COLOR_TRANSPARENT
                    );
                    if (rainStartIdx == -1) {
                        rainStartIdx = i;
                    }
                } else if (rain >= 0.5f) {
                    dc.setColor(0x00aaff, Graphics.COLOR_TRANSPARENT);
                    if (rainStartIdx == -1) {
                        rainStartIdx = i;
                    }
                } else {
                    dc.setColor(
                        Graphics.COLOR_YELLOW,
                        Graphics.COLOR_TRANSPARENT
                    );
                }

                dc.fillRectangle(bx, by, barWidth, barH);
            }
        }
        // Display remaining time until first rain (if any)
        if (showLabels && rainStartIdx != -1) {
            // Get timestamp for the first rain event (if available)
            if (rainStartIdx < timeStampsForeCast.size()) {
                var firstRainTime = timeStampsForeCast[rainStartIdx];
                // Difference in hours:minute from current time
                var diffSec = firstRainTime - Time.now().value();
                if (diffSec > 0) {
                    dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(
                        (x + width) / 2,
                        baselineY + 3,
                        Graphics.FONT_XTINY,
                        Lang.format("first rain in $1$", [
                            $.secondsToShortTimeString(diffSec, "{h}:{m}:{s}"),
                        ]),
                        Graphics.TEXT_JUSTIFY_CENTER
                    );
                }
            }
        }

        // --- 5. WIND GUST SPARKLINE & DIRECTION ARROWS ---
        var maxWind = 60.0f;
        var prevX = -1;
        var prevY = -1;

        for (var i = 0; i < numHours; i++) {
            var gust = windForecast[i];
            var px = x + i * (barWidth + barGap) + barWidth / 2;

            var gustRatio = gust / maxWind;
            if (gustRatio > 1.0f) {
                gustRatio = 1.0f;
            }
            var py = baselineY - (gustRatio * chartHeight).toNumber();

            // Draw line segment
            dc.setColor(
                isDark ? 0xff5500 : 0xcc0000,
                Graphics.COLOR_TRANSPARENT
            );
            if (prevX != -1) {
                dc.drawLine(prevX, prevY, px, py);
            }

            // Wind spike dot (>35 km/h)
            if (gust >= 35.0f) {
                dc.fillCircle(px, py, 2);
            }

            // Draw Wind Direction Arrows every 3 hours (i = 0, 3, 6, 9)
            if (i % 3 == 0 && windDirForecast.size() > i) {
                drawWindArrow(
                    dc,
                    px,
                    baselineY - 4,
                    windDirForecast[i],
                    isDark
                );
            }

            prevX = px;
            prevY = py;
        }

        // if (showLabels) {
        //     // --- 5. TOP HEADER & FREEZE INDICATOR ---
        //     dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        //     dc.drawText(
        //         x,
        //         y,
        //         Graphics.FONT_XTINY,
        //         Lang.format("+$1$H FORECAST", [numHours.format("%d")]),
        //         Graphics.TEXT_JUSTIFY_LEFT
        //     );
        // }
        // Show explicit ICE indicator in header if sub-zero temps exist ahead
        var hasIceAhead = false;
        for (var i = 0; i < tempForecast.size(); i++) {
            if (tempForecast[i] <= 0.0f) {
                hasIceAhead = true;
                break;
            }
        }

        if (hasIceAhead) {
            dc.setColor(0x00aaff, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                x + width,
                y,
                Graphics.FONT_XTINY,
                "ICE AHEAD",
                Graphics.TEXT_JUSTIFY_RIGHT
            );
        }
    }

    // Helper: Draw a vector arrow for wind origin direction
    private static function drawWindArrow(
        dc as Graphics.Dc,
        cx as Number,
        cy as Number,
        angleDeg as Number,
        isDark as Boolean
    ) as Void {
        var rad = Math.toRadians(angleDeg);
        var len = 5;

        // Compute line endpoint in direction wind is blowing *towards*
        var dx = (len * Math.sin(rad)).toNumber();
        var dy = (-len * Math.cos(rad)).toNumber();

        dc.setColor(
            isDark ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK,
            Graphics.COLOR_TRANSPARENT
        );
        dc.drawLine(cx - dx, cy - dy, cx + dx, cy + dy);
        dc.fillCircle(cx + dx, cy + dy, 1); // Arrowhead / indicator point
    }
}
