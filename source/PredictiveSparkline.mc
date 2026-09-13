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
        var timeStampsForeCast = metrics.timeStampsForeCast;
        var numHours = timeStampsForeCast.size();
        if (numHours == 0) {
            return;
        }

        var rainForecast = metrics.rainForecast; // Float (mm/h)
        var snowForecast = metrics.snowForecast; // Float (mm/h)
        var windForecast = metrics.windForecast; // Float (km/h)
        var windDirForecast = metrics.windDirForecast; // Number (0-359 deg)
        var windGustForecast = metrics.windGustForecast; // Float (km/h)
        var surfaceTempForecast = metrics.surfaceTempForecast; // Float (°C surface)

        var barGap = 2;
        var totalGaps = (numHours - 1) * barGap;
        var barWidth = (width - totalGaps) / numHours;

        var textColor = isDark
            ? Graphics.COLOR_LT_GRAY
            : Graphics.COLOR_DK_GRAY;
        var offsetLabels = showLabels ? 16 : 0;
        var offsetChartHeight = showLabels ? 14 : 0;
        var offsetIceBars = showLabels ? 12 : 0;

        var baselineY = y + height - offsetLabels;
        var chartHeight = baselineY - y - offsetChartHeight;

        // --- 1. FREEZING SURFACE TEMP BACKGROUND HIGHLIGHT ---
        for (var i = 0; i < numHours; i++) {
            if (
                surfaceTempForecast.size() > i &&
                surfaceTempForecast[i] <= 0.0f
            ) {
                var bx = x + i * (barWidth + barGap);
                dc.setColor(
                    isDark ? 0x002244 : 0xdceeff,
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

        // --- 2. 12-HOUR RISK HEATMAP BAR ---
        var blockW = width.toFloat() / numHours + 0.5f;
        var sparklineH = height - chartHeight - 4;
        var hourColor = AppState.activePalette[ThemeManager.COLOR_BG];

        for (var i = 0; i < riskProfile.size(); i++) {
            var blockX = x + i * (width.toFloat() / numHours);
            var blockY = y + sparklineH + 2;
            var riskColor = $.getRiskColor(riskProfile[i], isDark);

            dc.setColor(riskColor, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(
                blockX.toNumber(),
                blockY,
                blockW.toNumber(),
                chartHeight
            );

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

        // --- 3. BASELINE & LABELS ---
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
        }

        // --- 4. PRECIPITATION BARS (RAIN & SNOW STACKED/DIFFERENTIATED) ---
        var maxPrecip = 2.0f;
        for (var i = 0; i < numHours; i++) {
            var totalP = rainForecast[i] + snowForecast[i];
            if (totalP > maxPrecip) {
                maxPrecip = totalP;
            }
        }

        for (var i = 0; i < numHours; i++) {
            var rain = rainForecast[i];
            var snow = snowForecast[i];
            var total = rain + snow;

            if (total > 0.05f) {
                var barH = ((total / maxPrecip) * chartHeight).toNumber();
                if (barH < 3) {
                    barH = 3;
                }

                var bx = x + i * (barWidth + barGap);
                var by = baselineY - barH;

                if (snow > 0.0f) {
                    // Cyan / Ice-white for snow
                    dc.setColor(
                        isDark ? Graphics.COLOR_WHITE : 0x00ffff,
                        Graphics.COLOR_TRANSPARENT
                    );
                    dc.fillRectangle(bx, by, barWidth, barH);

                    // Add dotted top to distinguish snow from rain
                    dc.setColor(
                        Graphics.COLOR_DK_GRAY,
                        Graphics.COLOR_TRANSPARENT
                    );
                    dc.drawPoint(bx + barWidth / 2, by + 1);
                } else {
                    // Rain palette logic
                    if (rain >= 2.5f) {
                        dc.setColor(
                            AppState.activePalette[ThemeManager.COLOR_BLUE],
                            Graphics.COLOR_TRANSPARENT
                        );
                    } else if (rain >= 0.5f) {
                        dc.setColor(
                            AppState.activePalette[
                                ThemeManager.COLOR_DEEP_SKY_BLUE
                            ],
                            Graphics.COLOR_TRANSPARENT
                        );
                    } else {
                        dc.setColor(
                            AppState.activePalette[
                                ThemeManager.COLOR_LIGHT_COLUMBIA_BLUE
                            ],
                            Graphics.COLOR_TRANSPARENT
                        );
                    }
                    dc.fillRectangle(bx, by, barWidth, barH);
                }
            }
        }

        // --- 5. DYNAMIC SURFACE TEMP LINE SCALING ---
        if (surfaceTempForecast.size() > 0) {
            // Step A: Find min and max surface temperatures in the forecast
            var minSt = surfaceTempForecast[0];
            var maxSt = surfaceTempForecast[0];

            for (var i = 1; i < numHours; i++) {
                if (i >= surfaceTempForecast.size()) {
                    break;
                }
                var temp = surfaceTempForecast[i];
                if (temp < minSt) {
                    minSt = temp;
                }
                if (temp > maxSt) {
                    maxSt = temp;
                }
            }

            // Step B: Ensure a minimum span of 5.0°C to prevent flat-line distortion
            // when temperatures are almost constant
            var rangeSt = maxSt - minSt;
            if (rangeSt < 5.0f) {
                var mid = (maxSt + minSt) / 2.0f;
                minSt = mid - 2.5f;
                maxSt = mid + 2.5f;
                rangeSt = 5.0f;
            }

            // Step C: Render surface temp line using dynamic min/max range
            var prevStX = -1;
            var prevStY = -1;

            for (var i = 0; i < numHours; i++) {
                if (surfaceTempForecast.size() <= i) {
                    break;
                }
                var st = surfaceTempForecast[i];
                var px = x + i * (barWidth + barGap) + barWidth / 2;

                // Dynamic normalization: 0.0 at minSt, 1.0 at maxSt
                var normalizedSt = (st - minSt) / rangeSt;
                if (normalizedSt < 0.0f) {
                    normalizedSt = 0.0f;
                }
                if (normalizedSt > 1.0f) {
                    normalizedSt = 1.0f;
                }

                var py = baselineY - (normalizedSt * chartHeight).toNumber();

                // Highlight sub-zero points in RED; non-freezing in YELLOW / OLIVE
                dc.setColor(
                    st <= 0.0f
                        ? Graphics.COLOR_RED
                        : isDark
                          ? Graphics.COLOR_YELLOW
                          : 0x666600,
                    Graphics.COLOR_TRANSPARENT
                );

                if (prevStX != -1) {
                    dc.drawLine(prevStX, prevStY, px, py);
                }

                prevStX = px;
                prevStY = py;
            }
        }

        // --- 5. SURFACE TEMP LINE (SURFACE ICE WARNING OVERLAY) ---
        var prevStX = -1;
        var prevStY = -1;
        for (var i = 0; i < numHours; i++) {
            if (surfaceTempForecast.size() <= i) {
                break;
            }
            var st = surfaceTempForecast[i];
            var px = x + i * (barWidth + barGap) + barWidth / 2;

            // Map surface temp scale (-5°C to 25°C range window)
            var normalizedSt = (st + 5.0f) / 30.0f;
            if (normalizedSt < 0.0f) {
                normalizedSt = 0.0f;
            }
            if (normalizedSt > 1.0f) {
                normalizedSt = 1.0f;
            }
            var py = baselineY - (normalizedSt * chartHeight).toNumber();

            dc.setColor(
                st <= 0.0f
                    ? Graphics.COLOR_RED
                    : isDark
                      ? Graphics.COLOR_YELLOW
                      : 0x666600,
                Graphics.COLOR_TRANSPARENT
            );
            if (prevStX != -1) {
                dc.drawLine(prevStX, prevStY, px, py);
            }
            prevStX = px;
            prevStY = py;
        }

        // --- 6. WIND GUST SPARKLINE & DIRECTION ARROWS ---
        var maxWind = 60.0f;
        var prevX = -1;
        var prevY = -1;
        var windColor = AppState.activePalette[ThemeManager.COLOR_BG];
        for (var i = 0; i < numHours; i++) {
            var gust =
                windGustForecast.size() > i
                    ? windGustForecast[i]
                    : windForecast[i];
            var px = x + i * (barWidth + barGap) + barWidth / 2;

            var gustRatio = gust / maxWind;
            if (gustRatio > 1.0f) {
                gustRatio = 1.0f;
            }
            var py = baselineY - (gustRatio * chartHeight).toNumber();

            // dc.setColor(isDark ? 0xFF5500 : 0xCC0000, Graphics.COLOR_TRANSPARENT);
            dc.setColor(windColor, Graphics.COLOR_TRANSPARENT);
            if (prevX != -1) {
                dc.drawLine(prevX, prevY, px, py);
            }

            if (gust >= 35.0f) {
                dc.fillCircle(px, py, 2);
            }

            // Draw Wind Direction Arrows every 3 hours (i = 0, 3, 6, 9)
            // if (i % 3 == 0 && windDirForecast.size() > i) {
            if (windDirForecast.size() > i) {
                var isHeavyGust = gust >= 35.0f;
                drawWindArrow(
                    dc,
                    px,
                    baselineY - 4,
                    windDirForecast[i],
                    isHeavyGust,
                    isDark
                );
            }

            prevX = px;
            prevY = py;
        }

        // --- 7. ICE WARNING HEADER ---
        var hasIceAhead = false;
        for (var i = 0; i < surfaceTempForecast.size(); i++) {
            if (surfaceTempForecast[i] <= 0.0f) {
                hasIceAhead = true;
                break;
            }
        }

        if (hasIceAhead) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                x + width,
                y,
                Graphics.FONT_XTINY,
                "ICE AHEAD",
                Graphics.TEXT_JUSTIFY_RIGHT
            );
        }
    }

    // Helper: Draw a vector arrow for wind direction with gust emphasis
    private static function drawWindArrow(
        dc as Graphics.Dc,
        cx as Number,
        cy as Number,
        angleDeg as Number,
        isHeavyGust as Boolean,
        isDark as Boolean
    ) as Void {
        var rad = Math.toRadians(angleDeg);
        var len = isHeavyGust ? 7 : 5;

        var dx = (len * Math.sin(rad)).toNumber();
        var dy = (-len * Math.cos(rad)).toNumber();

        dc.setColor(
            isDark ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK,
            Graphics.COLOR_TRANSPARENT
        );

        // Draw normal or thick stem based on gust ratio
        dc.drawLine(cx - dx, cy - dy, cx + dx, cy + dy);
        if (isHeavyGust) {
            dc.drawLine(cx - dx + 1, cy - dy, cx + dx + 1, cy + dy);
        }

        // Arrowhead radius
        dc.fillCircle(cx + dx, cy + dy, isHeavyGust ? 2 : 1);
    }
}
