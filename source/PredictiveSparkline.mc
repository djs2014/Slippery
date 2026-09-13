import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;
import Toybox.System;

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
        showLabels as Boolean,
        showForecastHour as ShowForecastHour,
    ) as Void {
        var timeStampsForeCast = metrics.timeStampsForeCast;
        var numHours = timeStampsForeCast.size();
        if (numHours == 0) {
            return;
        }
        var currentHour = metrics.currentHour;
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

        // --- 2. 12-HOUR RISK HEATMAP BAR 2/3 of chart height ---
        var blockW = (width.toFloat() / numHours + 0.5f).toNumber();
        var sparklineH = height - chartHeight - 4;
        var hourColor = AppState.activePalette[ThemeManager.COLOR_BG];

        for (var i = 0; i < riskProfile.size(); i++) {
            var blockX = (x + i * (width.toFloat() / numHours)).toNumber();
            var blockY = y + sparklineH + 2 + (chartHeight * 0.33).toNumber();
            var riskColor = $.getRiskColor(riskProfile[i], isDark);
            var riskBlockHeight = (chartHeight * 0.66).toNumber();
            dc.setColor(riskColor, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(
                blockX,
                blockY,
                blockW,
                riskBlockHeight
            );

            if (showLabels && showForecastHour != ForecastHourNone) {
                var hourLabel;
                if (showForecastHour == ForecastHourRelative) {
                    hourLabel = Lang.format("+$1$", [i.format("%d")]);
                } else if (showForecastHour == ForecastHourAbsolute) {
                    var hour = (currentHour + i) % 24; // Display the hour relative to the current hour
                    hourLabel = Lang.format("$1$", [hour.format("%d")]);
                }
                
                dc.setColor(hourColor, Graphics.COLOR_TRANSPARENT);
                dc.drawText(
                    blockX + blockW / 2,
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

        // --- 4. PRECIPITATION BARS ---
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
                    dc.setColor(
                        isDark ? Graphics.COLOR_WHITE : 0x00ffff,
                        Graphics.COLOR_TRANSPARENT
                    );
                    dc.fillRectangle(bx, by, barWidth, barH);
                    dc.setColor(
                        Graphics.COLOR_DK_GRAY,
                        Graphics.COLOR_TRANSPARENT
                    );
                    dc.drawPoint(bx + barWidth / 2, by + 1);
                } else {
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

        // --- CALC OVERLAY BADGE VISIBILITY ---
        // Render badges only if there is at least 12px margin on the left side of 'x'
        var enableBadges = x >= 12;

        // Helper stroke colors for halo outlines to guarantee readability over colored risk blocks
        var haloColor = isDark ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE;

        // --- 5. DYNAMIC SURFACE TEMP LINE (SOLID + CONTRAST HALO) ---
        if (surfaceTempForecast.size() > 0) {
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

            var rangeSt = maxSt - minSt;
            if (rangeSt < 5.0f) {
                var mid = (maxSt + minSt) / 2.0f;
                minSt = mid - 2.5f;
                maxSt = mid + 2.5f;
                rangeSt = 5.0f;
            }

            var prevStX = -1;
            var prevStY = -1;
            var firstStY = -1;

            for (var i = 0; i < numHours; i++) {
                if (surfaceTempForecast.size() <= i) {
                    break;
                }
                var st = surfaceTempForecast[i];
                var px = x + i * (barWidth + barGap) + barWidth / 2;

                var normalizedSt = (st - minSt) / rangeSt;
                if (normalizedSt < 0.0f) {
                    normalizedSt = 0.0f;
                }
                if (normalizedSt > 1.0f) {
                    normalizedSt = 1.0f;
                }

                var py = baselineY - (normalizedSt * chartHeight).toNumber();
                if (i == 0) {
                    firstStY = py;
                }

                // Check background collision (e.g., yellow temp over RiskLevelSlight yellow)
                var currentRisk =
                    i < riskProfile.size() ? riskProfile[i] : RiskLevelSafe;
                var tempColor =
                    st <= 0.0f
                        ? Graphics.COLOR_RED
                        : currentRisk == RiskLevelSlight
                          ? isDark
                              ? Graphics.COLOR_WHITE
                              : Graphics.COLOR_BLACK // Contrast override on yellow background
                          : isDark
                            ? Graphics.COLOR_YELLOW
                            : 0x666600;

                if (prevStX != -1) {
                    // Step 1: Draw 3px wide halo outline behind line
                    dc.setColor(haloColor, Graphics.COLOR_TRANSPARENT);
                    dc.drawLine(prevStX, prevStY - 1, px, py - 1);
                    dc.drawLine(prevStX, prevStY + 2, px, py + 2);

                    // Step 2: Draw 2px main temperature line
                    dc.setColor(tempColor, Graphics.COLOR_TRANSPARENT);
                    dc.drawLine(prevStX, prevStY, px, py);
                    dc.drawLine(prevStX, prevStY + 1, px, py + 1);
                }

                // Node point with halo
                dc.setColor(haloColor, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(px, py, 3);
                dc.setColor(tempColor, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(px, py, 2);

                prevStX = px;
                prevStY = py;
            }

            // Draw Badge "T" with halo outline
            if (enableBadges && firstStY != -1) {
                dc.setColor(haloColor, Graphics.COLOR_TRANSPARENT);
                dc.drawText(
                    x - 2,
                    firstStY + 1,
                    Graphics.FONT_XTINY,
                    "T",
                    Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
                );
                dc.setColor(
                    isDark ? Graphics.COLOR_YELLOW : 0x666600,
                    Graphics.COLOR_TRANSPARENT
                );
                dc.drawText(
                    x - 3,
                    firstStY,
                    Graphics.FONT_XTINY,
                    "T",
                    Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
                );
            }
        }

        // --- 6. WIND GUST SPARKLINE (DASHED + CONTRAST HALO) ---
        var maxWind = 60.0f; // km/h
        var prevX = -1;
        var prevY = -1;
        var firstWindY = -1;

        for (var i = 0; i < numHours; i++) {
            var windSpd = windForecast.size() > i ? windForecast[i] : 0.0f;
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
            if (i == 0) {
                firstWindY = py;
            }

            var currentRisk =
                i < riskProfile.size() ? riskProfile[i] : RiskLevelSafe;

            // Adjust line color if risk background matches orange/red wind hue
            var windLineColor =
                currentRisk == RiskLevelModerate || currentRisk == RiskLevelHigh
                    ? isDark
                        ? Graphics.COLOR_WHITE
                        : Graphics.COLOR_BLACK // Contrast override on orange background
                    : isDark
                      ? 0xff5500
                      : 0xcc0000;

            if (prevX != -1) {
                if (i % 2 == 0) {
                    // Step 1: Draw halo dots behind dashed segments
                    dc.setColor(haloColor, Graphics.COLOR_TRANSPARENT);
                    dc.drawLine(prevX, prevY - 1, px, py - 1);
                    dc.drawLine(prevX, prevY + 1, px, py + 1);

                    // Step 2: Draw inner dashed wind line
                    dc.setColor(windLineColor, Graphics.COLOR_TRANSPARENT);
                    dc.drawLine(prevX, prevY, px, py);
                }
            }

            if (gust >= 35.0f) {
                dc.setColor(haloColor, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(px, py, 4);
                dc.setColor(windLineColor, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(px, py, 3);
            }

            // --- CONDITIONAL ARROW DRAWING ---
            // Draw vector ONLY if wind is fast (>=20 km/h), gust is heavy (>=25 km/h),
            // or there is notable gust turbulence (gust >= 1.3 * base wind)
            var relGustRatio = windSpd > 1.0f ? gust / windSpd : 1.0f;
            var shouldDrawArrow =
                windSpd >= 20.0f || gust >= 25.0f || relGustRatio >= 1.3f;

            // Line height is wind strength
            if (shouldDrawArrow && windDirForecast.size() > i) {
                drawWindArrow(
                    dc,
                    px,
                    py, //baselineY - 4,
                    windDirForecast[i],
                    windSpd,
                    gust,
                    isDark
                );
            }

            prevX = px;
            prevY = py;
        }

        // Draw Badge "W" with halo outline
        if (enableBadges && firstWindY != -1) {
            dc.setColor(haloColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                x - 2,
                firstWindY + 1,
                Graphics.FONT_XTINY,
                "W",
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
            );
            dc.setColor(
                isDark ? 0xff5500 : 0xcc0000,
                Graphics.COLOR_TRANSPARENT
            );
            dc.drawText(
                x - 3,
                firstWindY,
                Graphics.FONT_XTINY,
                "W",
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
            );
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

    private static function drawWindArrow(
        dc as Graphics.Dc,
        cx as Number,
        cy as Number,
        angleDeg as Number,
        windSpeed as Float,
        gust as Float,
        isDark as Boolean
    ) as Void {
        // 1. LARGER TRIANGLE DIMENSIONS (Length: 12px to 18px)
        var len = 12;
        var baseHalfWidth = 4;
        if (windSpeed >= 35.0f) {
            len = 18;
            baseHalfWidth = 7;
        } else if (windSpeed >= 25.0f) {
            len = 15;
            baseHalfWidth = 6;
        } else if (windSpeed >= 18.0f) {
            len = 13;
            baseHalfWidth = 5;
        }

        // Convert direction: Flip by 180 deg so arrow points WHERE wind is blowing TO
        var rad = Math.toRadians(angleDeg + 180.0f);
        var uX = Math.sin(rad);
        var uY = -Math.cos(rad);

        // Perpendicular vector for triangle base (+90 deg rotation)
        var pX = -uY;
        var pY = uX;

        // Apex points in direction of travel, Base stays at origin
        var halfLen = len / 2.0f;
        var apexX = cx + (halfLen * uX).toNumber();
        var apexY = cy + (halfLen * uY).toNumber();
        var baseX = cx - (halfLen * uX).toNumber();
        var baseY = cy - (halfLen * uY).toNumber();

        // Base left/right corners
        var corner1X = baseX + (baseHalfWidth * pX).toNumber();
        var corner1Y = baseY + (baseHalfWidth * pY).toNumber();
        var corner2X = baseX - (baseHalfWidth * pX).toNumber();
        var corner2Y = baseY - (baseHalfWidth * pY).toNumber();

        var mainColor = isDark ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        var haloColor = isDark ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE;

        // --- STEP A: HALO BACKGROUND OUTLINE ---
        var haloPts = [
            [apexX + (uX * 2.0f).toNumber(), apexY + (uY * 2.0f).toNumber()],
            [
                corner1X + ((pX - uX) * 1.5f).toNumber(),
                corner1Y + ((pY - uY) * 1.5f).toNumber(),
            ],
            [
                corner2X - ((pX + uX) * 1.5f).toNumber(),
                corner2Y - ((pY + uY) * 1.5f).toNumber(),
            ],
        ];
        dc.setColor(haloColor, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(haloPts);

        // --- STEP B: FILLED FOREGROUND TRIANGLE ---
        var trianglePts = [
            [apexX, apexY],
            [corner1X, corner1Y],
            [corner2X, corner2Y],
        ];
        dc.setColor(mainColor, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(trianglePts);

        // --- STEP C: STACKED GUST BARS BEHIND BASE ---
        var gustRatio = windSpeed > 1.0f ? gust / windSpeed : 1.0f;
        var numGustBars = 0;

        if (gust >= 45.0f || gustRatio >= 1.7f) {
            numGustBars = 3;
        } else if (gust >= 35.0f || gustRatio >= 1.5f) {
            numGustBars = 2;
        } else if (gust >= 25.0f || gustRatio >= 1.3f) {
            numGustBars = 1;
        }

        var barSpacing = 4;
        var barWidth = baseHalfWidth + 2;

        for (var b = 1; b <= numGustBars; b++) {
            var bCenterX = baseX - (b * barSpacing * uX).toNumber();
            var bCenterY = baseY - (b * barSpacing * uY).toNumber();

            var bX1 = bCenterX + (barWidth * pX).toNumber();
            var bY1 = bCenterY + (barWidth * pY).toNumber();
            var bX2 = bCenterX - (barWidth * pX).toNumber();
            var bY2 = bCenterY - (barWidth * pY).toNumber();

            // 2px thick halo outline
            dc.setColor(haloColor, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(bX1 - 1, bY1, bX2 - 1, bY2);
            dc.drawLine(bX1 + 1, bY1, bX2 + 1, bY2);
            dc.drawLine(bX1, bY1 - 1, bX2, bY2 - 1);
            dc.drawLine(bX1, bY1 + 1, bX2, bY2 + 1);

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

    private static function drawWindArrow_line(
        dc as Graphics.Dc,
        cx as Number,
        cy as Number,
        angleDeg as Number,
        windSpeed as Float,
        gust as Float,
        isDark as Boolean
    ) as Void {
        // 1. SHAFT LENGTH BASED ON BASE WIND SPEED (Range: 8px to 14px)
        var len = 8;
        if (windSpeed >= 35.0f) {
            len = 14;
        } else if (windSpeed >= 25.0f) {
            len = 12;
        } else if (windSpeed >= 18.0f) {
            len = 10;
        }

        // Direction unit vector (0 deg = North)
        var rad = Math.toRadians(angleDeg);
        var uX = Math.sin(rad);
        var uY = -Math.cos(rad);

        // Perpendicular vector for crossbars/flags (rotated +90 degrees)
        var pX = -uY;
        var pY = uX;

        // Tip and Tail coordinates relative to center (cx, cy)
        var halfLen = len / 2.0f;
        var tipX = cx + (halfLen * uX).toNumber();
        var tipY = cy + (halfLen * uY).toNumber();
        var tailX = cx - (halfLen * uX).toNumber();
        var tailY = cy - (halfLen * uY).toNumber();

        // 2. GUST SEVERITY LEVELS
        var gustRatio = windSpeed > 1.0f ? gust / windSpeed : 1.0f;
        var isSevereGust = gust >= 40.0f || gustRatio >= 1.6f;
        var isModerateGust =
            gust >= 28.0f || (gustRatio >= 1.3f && !isSevereGust);

        var arrowColor = isDark ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        var haloColor = isDark ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE;

        // --- HELPER FUNCTION: DRAW HALOED LINE ---
        // Draws a line with a 1px halo background stroke for contrast over heatmaps
        dc.setColor(haloColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(tailX - 1, tailY, tipX - 1, tipY);
        dc.drawLine(tailX + 1, tailY, tipX + 1, tipY);
        dc.drawLine(tailX, tailY - 1, tipX, tipY - 1);
        dc.drawLine(tailX, tailY + 1, tipX, tipY + 1);

        dc.setColor(arrowColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(tailX, tailY, tipX, tipY);

        // --- STEP A: ARROWHEAD AT TIP ---
        // Small 2px arrowhead wings at tip
        var headLen = 3;
        var headX1 = tipX - (headLen * uX - 2 * pX).toNumber();
        var headY1 = tipY - (headLen * uY - 2 * pY).toNumber();
        var headX2 = tipX - (headLen * uX + 2 * pX).toNumber();
        var headY2 = tipY - (headLen * uY + 2 * pY).toNumber();

        dc.setColor(haloColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(tipX, tipY, headX1, headY1);
        dc.drawLine(tipX, tipY, headX2, headY2);

        dc.setColor(arrowColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(tipX, tipY, headX1, headY1);
        dc.drawLine(tipX, tipY, headX2, headY2);

        // --- STEP B: TAIL BASE MARKER (START OF LINE) ---
        // Short perpendicular line at the very tail to anchor the origin
        var baseW = 2;
        var tailBaseX1 = tailX - (baseW * pX).toNumber();
        var tailBaseY1 = tailY - (baseW * pY).toNumber();
        var tailBaseX2 = tailX + (baseW * pX).toNumber();
        var tailBaseY2 = tailY + (baseW * pY).toNumber();

        dc.setColor(haloColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(tailBaseX1, tailBaseY1, tailBaseX2, tailBaseY2);
        dc.setColor(arrowColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(tailBaseX1, tailBaseY1, tailBaseX2, tailBaseY2);

        // --- STEP C: DIAGONAL GUST BARBS AT TAIL ---
        // Draw 1, 2, or 3 diagonal flags sloping backwards along the tail
        var numBarbs = isSevereGust ? 3 : isModerateGust ? 2 : 1;
        var barbLength = 3;
        var barbSpacing = 3;

        for (var b = 0; b < numBarbs; b++) {
            // Position along the stem starting from tail forward
            var stemOffsetX = tailX + (b * barbSpacing * uX).toNumber();
            var stemOffsetY = tailY + (b * barbSpacing * uY).toNumber();

            // Diagonal backward slant: combination of backward -u and sideways +p
            var barbEndX = stemOffsetX + (barbLength * (pX - uX)).toNumber();
            var barbEndY = stemOffsetY + (barbLength * (pY - uY)).toNumber();

            dc.setColor(haloColor, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(stemOffsetX, stemOffsetY, barbEndX, barbEndY);
            dc.setColor(arrowColor, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(stemOffsetX, stemOffsetY, barbEndX, barbEndY);
        }
    }
}
