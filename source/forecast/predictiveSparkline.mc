import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;
import Toybox.System;

class PredictiveSparkline {
    public static function drawComfort(
        dc as Graphics.Dc,
        x as Number,
        y as Number,
        width as Number,
        height as Number,
        metrics as WeatherMetrics,
        isDark as Boolean
    ) {
        var dewpointForecast = metrics.dewpointForecast; // Float (°C)
        var numHours = dewpointForecast.size();
        if (numHours == 0) {
            return;
        }
        var smallWidth = width < 180;
        var barGap = smallWidth ? 1 : 2;
        var totalGaps = (numHours - 1) * barGap;
        var standardBarWidth = (width - totalGaps) / numHours;
        if (standardBarWidth < 2) {
            standardBarWidth = 2;
        }
        var bar0Width = (
            standardBarWidth * metrics.hourFractionRemaining
        ).toNumber();
        var leftShift = standardBarWidth - bar0Width;

        // DRAW COMFORT BAR
        var maxDewpoint = dewpointForecast[0];
        for (var i = 0; i < numHours; i++) {
            // Common column geometries
            var colX =
                i == 0 ? x : x + i * (standardBarWidth + barGap) - leftShift;
            var colW = i == 0 ? bar0Width : standardBarWidth;

            var dewPoint = dewpointForecast[i];
            var dx = colX;
            var dw = colW;
            dc.setColor(
                DewpointPalette.getColor(dewPoint, isDark),
                Graphics.COLOR_TRANSPARENT
            );
            dc.fillRectangle(dx, y, dw, height);

            if (dewPoint > maxDewpoint) {
                maxDewpoint = dewPoint;
            }
        }

        // 4. Subtle Outer Border Halo around the entire bar
        var haloColor = isDark ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE;
        dc.setColor(haloColor, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x - 1, y - 1, width + 2, height + 2);

        // --- CALC OVERLAY BADGE VISIBILITY ---
        // Render badges only if there is at least 12px margin on the left side of 'x'
        var enableBadges = x >= 12;
        if (enableBadges && y != -1) {
            dc.setColor(haloColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                x - 2,
                y + height / 2,
                Graphics.FONT_XTINY,
                "C",
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
            );
            dc.setColor(
                DewpointPalette.getColor(maxDewpoint, isDark),
                Graphics.COLOR_TRANSPARENT
            );
            dc.drawText(
                x - 3,
                y + height / 2,
                Graphics.FONT_XTINY,
                "C",
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }

        // --- SHOW MINUTES TO NEXT HOUR ---
        if (!smallWidth && metrics.hourFractionRemaining < 1.0) {
            //var minutesToNextHour = (metrics.hourFractionRemaining * 60).toNumber();
            var minutesToNextHour = 60 - System.getClockTime().min;
            System.println("Minutes to next hour: " + minutesToNextHour);
            dc.setColor(haloColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                x + width,
                y + height / 2,
                Graphics.FONT_XTINY,
                Lang.format("$1$", [minutesToNextHour]),
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
            );
            dc.setColor(
                AppState.getColor(ThemeManager.COLOR_TEXT),
                Graphics.COLOR_TRANSPARENT
            );
            dc.drawText(
                x + width - 1,
                y + height / 2,
                Graphics.FONT_XTINY,
                Lang.format("$1$", [minutesToNextHour]),
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }
    }

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
        showForecastHour as ShowForecastHour
    ) as Void {
        var timeStampsForeCast = metrics.timeStampsForeCast;
        var numHours = timeStampsForeCast.size();
        if (numHours == 0) {
            return;
        }

        var currentHour = metrics.currentHour;
        var rainForecast = metrics.rainForecast;
        var showersForecast = metrics.showersForecast;
        var snowForecast = metrics.snowForecast;
        var windForecast = metrics.windForecast;
        var windDirForecast = metrics.windDirForecast;
        var windGustForecast = metrics.windGustForecast;
        var surfaceTempForecast = metrics.surfaceTempForecast;
        var minutelyRainForecast = metrics.minutelyRainForecast;
        var minutelySnowForecast = metrics.minutelySnowForecast;

        var smallWidth = width < 180;
        var barGap = smallWidth ? 1 : 2;
        var totalGaps = (numHours - 1) * barGap;
        var standardBarWidth = (width - totalGaps) / numHours;
        if (standardBarWidth < 2) {
            standardBarWidth = 2;
        }

        var bar0Width = (
            standardBarWidth * metrics.hourFractionRemaining
        ).toNumber();
        var leftShift = standardBarWidth - bar0Width;

        var textColor = isDark
            ? Graphics.COLOR_LT_GRAY
            : Graphics.COLOR_DK_GRAY;
        var offsetLabels = showLabels ? 16 : 0;
        var offsetChartHeight = showLabels ? 14 : 0;
        var offsetIceBars = showLabels ? 12 : 0;

        var baselineY = y + height - offsetLabels;
        var chartHeight = baselineY - y - offsetChartHeight;

        var sparklineH = height - chartHeight - 4;
        var hourColor = AppState.getColor(ThemeManager.COLOR_BG);
        var riskBlockY = y + sparklineH + 2 + (chartHeight * 0.33).toNumber();
        var riskBlockHeight = (chartHeight * 0.66).toNumber();

        // ==========================================
        // PASS 1: PRE-CALCULATIONS & MIN/MAX RANGES
        // ==========================================
        var maxPrecip = 2.0f;
        var minSt = 1000.0f;
        var maxSt = -1000.0f;
        var hasIceAhead = false;
        // Significant convective burst floor (matches the rain color tiers).
        var showerHlThreshold = 0.5f;
        // First hour with significant showers; drives badge + outline.
        var firstShowerIdx = -1;
        var hasTempData = surfaceTempForecast.size() > 0;

        for (var i = 0; i < numHours; i++) {
            // 1. Precip Max
            var totalP = rainForecast[i] + showersForecast[i] + snowForecast[i];
            if (totalP > maxPrecip) {
                maxPrecip = totalP;
            }

            // 2. First significant shower hour
            if (
                firstShowerIdx < 0 &&
                i < showersForecast.size() &&
                showersForecast[i] >= showerHlThreshold
            ) {
                firstShowerIdx = i;
            }

            // 3. Temp Range & Ice check
            if (hasTempData && i < surfaceTempForecast.size()) {
                var st = surfaceTempForecast[i];
                if (st <= 0.0f) {
                    hasIceAhead = true;
                }
                if (st < minSt) {
                    minSt = st;
                }
                if (st > maxSt) {
                    maxSt = st;
                }
            }
        }

        if (hasTempData) {
            var rangeSt = maxSt - minSt;
            if (rangeSt < 5.0f) {
                var mid = (maxSt + minSt) / 2.0f;
                minSt = mid - 2.5f;
                maxSt = mid + 2.5f;
                rangeSt = 5.0f;
            }
        }

        // Baseline Line
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x, baselineY, x + width, baselineY);

        // Overlay Badge pre-calcs
        var enableBadges = x >= 12;
        var haloColor = isDark ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE;

        // Tracking state across render iterations
        var prevStX = -1,
            prevStY = -1,
            firstStY = -1;
        var prevWindX = -1,
            prevWindY = -1,
            firstWindY = -1;
        var maxWind = 60.0f;

        // ==========================================
        // PASS 2: COMBINED DRAWING LOOP
        // ==========================================        
        for (var i = 0; i < numHours; i++) {
            // Common column geometries
            var colX =
                i == 0 ? x : x + i * (standardBarWidth + barGap) - leftShift;
            var colW = i == 0 ? bar0Width : standardBarWidth;
            var px = colX + colW / 2; // Midpoint for line nodes

            var currentRisk =
                i < riskProfile.size() ? riskProfile[i] : RiskLevelSafe;

            // --- LAYER A: FREEZING TEMP BACKGROUND ---
            if (
                hasTempData &&
                i < surfaceTempForecast.size() &&
                surfaceTempForecast[i] <= 0.0f
            ) {
                dc.setColor(
                    AppState.getColor(ThemeManager.COLOR_FREEZING_TEMP_BACKGROUND),
                    Graphics.COLOR_TRANSPARENT
                );
                dc.fillRectangle(
                    colX,
                    y + offsetIceBars,
                    colW,
                    chartHeight + 2
                );
            }

            // --- LAYER B: RISK HEATMAP & HOUR LABELS ---
            if (i < riskProfile.size()) {
                // Show high color if risk level is above moderate
                if (currentRisk > RiskLevelModerate) {
                    dc.setColor(
                        $.getRiskColor(currentRisk, isDark),
                        Graphics.COLOR_TRANSPARENT
                    );                    
                } else {
                    dc.setColor(
                        $.getLightRiskColor(currentRisk, isDark),
                        Graphics.COLOR_TRANSPARENT
                    );
                }
                dc.fillRectangle(colX, riskBlockY, colW, riskBlockHeight);

                if (showLabels && showForecastHour != ForecastHourNone) {
                    var hourLabel =
                        showForecastHour == ForecastHourRelative
                            ? Lang.format("+$1$", [i.format("%d")])
                            : Lang.format("$1$", [
                                  ((currentHour + i) % 24).format("%d"),
                              ]);

                    dc.setColor(hourColor, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(
                        colX + colW / 2,
                        riskBlockY + riskBlockHeight / 2,
                        Graphics.FONT_XTINY,
                        hourLabel,
                        Graphics.TEXT_JUSTIFY_CENTER |
                            Graphics.TEXT_JUSTIFY_VCENTER
                    );
                }
            }

            // --- LAYER C: PRECIPITATION BARS (stacked: liquid base, snow cap) ---
            var rain = rainForecast[i];
            var showers = showersForecast[i];
            var snow = snowForecast[i];
            // Snow is cm/h ~= mm water-equivalent numerically (10:1), so the
            // shares below compare liquid mm against snow water directly.
            var liquid = rain + showers;
            var total = liquid + snow;
            if (total > 0.05f) {
                var barH = ((total / maxPrecip) * chartHeight).toNumber();
                if (barH < 3) {
                    barH = 3;
                }

                // Proportional split; snow cap never exceeds the column.
                var snowH = 0;
                if (snow > 0.0f) {
                    snowH = Math.round((snow / total) * barH).toNumber();
                    if (snowH < 0) {
                        snowH = 0;
                    }
                    if (snowH > barH) {
                        snowH = barH;
                    }
                }
                var liquidH = barH - snowH;

                var precipY = baselineY;
                // Liquid split: steady rain (blue) at the base, convective
                // showers (purple) above it. Significant bursts keep a 2px
                // floor so they stay visible inside rain-dominated columns.
                var rainH = 0;
                var showerH = 0;
                if (liquidH > 0 && liquid > 0.0f) {
                    if (showers <= 0.0f) {
                        rainH = liquidH;
                    } else if (rain <= 0.0f) {
                        showerH = liquidH;
                    } else {
                        showerH = Math.round(
                            (showers / liquid) * liquidH
                        ).toNumber();
                        if (showerH < 0) {
                            showerH = 0;
                        }
                        if (showerH > liquidH) {
                            showerH = liquidH;
                        }
                        if (
                            showers >= showerHlThreshold && showerH < 2
                        ) {
                            showerH = liquidH < 2 ? liquidH : 2;
                        }
                        rainH = liquidH - showerH;
                    }
                    if (rainH > 0) {
                        // Steady stratiform rain (blue, absolute tiers)
                        var rainColor =
                            rain >= 2.5f
                                ? AppState.getColor(ThemeManager.COLOR_BLUE)
                                : rain >= 0.5f
                                  ? AppState.getColor(
                                        ThemeManager.COLOR_DEEP_SKY_BLUE
                                    )
                                  : AppState.getColor(
                                        ThemeManager.COLOR_LIGHT_COLUMBIA_BLUE
                                    );
                        dc.setColor(rainColor, Graphics.COLOR_TRANSPARENT);
                        dc.fillRectangle(colX, precipY - rainH, colW, rainH);
                        precipY -= rainH;
                    }
                    if (showerH > 0) {
                        // Convective showers (purple)
                        dc.setColor(
                            AppState.getColor(ThemeManager.COLOR_SHOWERS),
                            Graphics.COLOR_TRANSPARENT
                        );
                        dc.fillRectangle(
                            colX,
                            precipY - showerH,
                            colW,
                            showerH
                        );
                        precipY -= showerH;
                    }
                }
                // Snow cap
                if (snowH > 0) {
                    dc.setColor(
                        AppState.getColor(ThemeManager.COLOR_SNOW_PATTERN),
                        Graphics.COLOR_TRANSPARENT
                    );
                    dc.fillRectangle(colX, precipY - snowH, colW, snowH);
                    dc.setColor(
                        Graphics.COLOR_DK_GRAY,
                        Graphics.COLOR_TRANSPARENT
                    );
                    dc.drawPoint(px, precipY - snowH + 1);
                } else if (snow > 0.0f) {
                    // Trace snow rounded to 0px: keep the dot so its
                    // presence is not lost inside a rain column.
                    // (precipY already points at the column top here.)
                    dc.setColor(
                        Graphics.COLOR_DK_GRAY,
                        Graphics.COLOR_TRANSPARENT
                    );
                    dc.drawPoint(px, precipY + 1);
                }

                // First-shower highlight: purple outline so the eye jumps to
                // when convective rain starts (mirrors the risk rising-edge
                // emphasis). This column always has total >= 0.5 > 0.05.
                if (i == firstShowerIdx) {
                    dc.setColor(
                        AppState.getColor(ThemeManager.COLOR_SHOWERS),
                        Graphics.COLOR_TRANSPARENT
                    );
                    dc.drawRectangle(colX, baselineY - barH, colW, barH);
                }
            }

            // --- LAYER D: TEMP SPARKLINE SEGMENT ---
            if (hasTempData && i < surfaceTempForecast.size()) {
                var st = surfaceTempForecast[i];
                var normalizedSt = (st - minSt) / (maxSt - minSt);
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

                var tempColor =
                    st <= 0.0f
                        ? Graphics.COLOR_RED
                        : currentRisk == RiskLevelSlight
                          ? isDark
                              ? Graphics.COLOR_WHITE
                              : Graphics.COLOR_BLACK
                          : isDark
                            ? Graphics.COLOR_YELLOW
                            : AppState.getColor(ThemeManager.COLOR_OLIVE);

                if (prevStX != -1) {
                    dc.setColor(haloColor, Graphics.COLOR_TRANSPARENT);
                    dc.drawLine(prevStX, prevStY - 1, px, py - 1);
                    dc.drawLine(prevStX, prevStY + 2, px, py + 2);

                    dc.setColor(tempColor, Graphics.COLOR_TRANSPARENT);
                    dc.drawLine(prevStX, prevStY, px, py);
                    dc.drawLine(prevStX, prevStY + 1, px, py + 1);
                }

                dc.setColor(haloColor, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(px, py, 3);
                dc.setColor(tempColor, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(px, py, 2);

                prevStX = px;
                prevStY = py;
            }

            // --- LAYER E: WIND SPARKLINE & ARROWS ---
            var windSpd = windForecast.size() > i ? windForecast[i] : 0.0f;
            var gust =
                windGustForecast.size() > i ? windGustForecast[i] : windSpd;
            var gustRatio = gust / maxWind;
            if (gustRatio > 1.0f) {
                gustRatio = 1.0f;
            }

            var windPy = baselineY - (gustRatio * chartHeight).toNumber();
            if (i == 0) {
                firstWindY = windPy;
            }

            var windLineColor =
                currentRisk == RiskLevelModerate || currentRisk == RiskLevelHigh
                    ? isDark
                        ? Graphics.COLOR_WHITE
                        : Graphics.COLOR_BLACK
                    : isDark
                      ? AppState.getColor(ThemeManager.COLOR_INTERNATIONAL_ORANGE)
                      : AppState.getColor(ThemeManager.COLOR_FREE_SPEECH_RED);

            if (prevWindX != -1 && i % 2 == 0) {
                dc.setColor(haloColor, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(prevWindX, prevWindY - 1, px, windPy - 1);
                dc.drawLine(prevWindX, prevWindY + 1, px, windPy + 1);

                dc.setColor(windLineColor, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(prevWindX, prevWindY, px, windPy);
            }

            if (gust >= 35.0f) {
                dc.setColor(haloColor, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(px, windPy, 4);
                dc.setColor(windLineColor, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(px, windPy, 3);
            }

            var relGustRatio = windSpd > 1.0f ? gust / windSpd : 1.0f;
            if (
                (windSpd >= 20.0f || gust >= 25.0f || relGustRatio >= 1.3f) &&
                windDirForecast.size() > i
            ) {
                if (smallWidth) {
                    drawWindArrow_line(
                        dc,
                        px,
                        windPy,
                        windDirForecast[i],
                        windSpd,
                        gust,
                        isDark
                    );
                } else {
                    drawWindArrow(
                        dc,
                        px,
                        windPy,
                        windDirForecast[i],
                        windSpd,
                        gust,
                        isDark
                    );
                }
            }

            prevWindX = px;
            prevWindY = windPy;
        }

        // --- SUB-SEGMENTED MINUTELY PRECIPITATION SPARKLINE ---
        // Minutely slots start at the fetch-time quarter, not at wall-clock
        // "now": drop elapsed quarters so stale data is never rendered as
        // upcoming rain, then keep only the quarters covered by the shrunk
        // first column (its width = remaining hour fraction). Fully stale
        // series (or no room) -> no overlay; the hourly bars already carry
        // the information.
        var skippedQuarters = 0;
        if (metrics.minutelyStartEpoch > 0) {
            skippedQuarters =
                (Time.now().value() - metrics.minutelyStartEpoch) / 900;
            if (skippedQuarters < 0) {
                skippedQuarters = 0; // clock skew / future data
            }
        }
        // hourFractionRemaining is quarter-quantized (1.0/0.75/0.5/0.25),
        // so this yields 4/3/2/1 quarters respectively.
        var quartersToShow =
            (4.0f * metrics.hourFractionRemaining + 0.99f).toNumber();
        if (quartersToShow < 1) {
            quartersToShow = 1;
        }
        if (quartersToShow > 4) {
            quartersToShow = 4;
        }
        var slicedRain = [] as Array<Float>;
        var rainTaken = 0;
        for (var q = skippedQuarters; q < minutelyRainForecast.size(); q++) {
            if (rainTaken >= quartersToShow) {
                break;
            }
            slicedRain.add(minutelyRainForecast[q]);
            rainTaken++;
        }
        var slicedSnow = [] as Array<Float>;
        var snowTaken = 0;
        for (var q = skippedQuarters; q < minutelySnowForecast.size(); q++) {
            if (snowTaken >= quartersToShow) {
                break;
            }
            slicedSnow.add(minutelySnowForecast[q]);
            snowTaken++;
        }
        // Overlay needs 1px per block plus 1px gaps; when the shrunk first
        // column has no room, skip the detail (hourly bars still show).
        var slicedBlocks = slicedRain.size();
        if (slicedSnow.size() > slicedBlocks) {
            slicedBlocks = slicedSnow.size();
        }
        if (slicedBlocks > 0 && bar0Width >= 2 * slicedBlocks - 1) {
            var slicedMax = SubSegmentedForecastBar.computeGlobalMaxRate(
                slicedRain,
                slicedSnow,
                maxPrecip
            );
            SubSegmentedForecastBar.drawSubdividedHourScaled(
                dc,
                x,
                baselineY - chartHeight,
                bar0Width,
                chartHeight,
                slicedRain,
                slicedSnow,
                slicedMax,
                isDark
            );
        }

        // --- LINE UNDER THE SPARKLINE ---
        dc.setColor(
            AppState.getColor(ThemeManager.COLOR_TEXT),
            Graphics.COLOR_TRANSPARENT
        );
        dc.drawLine(x, baselineY, x + width, baselineY);

        // --- BADGES AND HEADERS ---
        if (enableBadges) {
            if (firstStY != -1) {
                dc.setColor(haloColor, Graphics.COLOR_TRANSPARENT);
                dc.drawText(
                    x - 2,
                    firstStY + 1,
                    Graphics.FONT_XTINY,
                    "T",
                    Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
                );
                dc.setColor(
                    isDark ? Graphics.COLOR_YELLOW : AppState.getColor(ThemeManager.COLOR_OLIVE),
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
            if (firstWindY != -1) {
                dc.setColor(haloColor, Graphics.COLOR_TRANSPARENT);
                dc.drawText(
                    x - 2,
                    firstWindY + 1,
                    Graphics.FONT_XTINY,
                    "W",
                    Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
                );
                dc.setColor(
                    isDark ? AppState.getColor(ThemeManager.COLOR_INTERNATIONAL_ORANGE) : AppState.getColor(ThemeManager.COLOR_FREE_SPEECH_RED),
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
        }

        if (hasIceAhead) {
            dc.setColor(AppState.getColor(ThemeManager.COLOR_RED), Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                x + width,
                y,
                Graphics.FONT_XTINY,
                "ICE AHEAD",
                Graphics.TEXT_JUSTIFY_RIGHT
            );
        }

        // Convective outlook badge; stacked below ICE AHEAD when both fire.
        if (firstShowerIdx >= 0) {
            dc.setColor(
                AppState.getColor(ThemeManager.COLOR_SHOWERS),
                Graphics.COLOR_TRANSPARENT
            );
            dc.drawText(
                x + width,
                hasIceAhead ? y + 12 : y,
                Graphics.FONT_XTINY,
                "SHOWERS AHEAD",
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
        var standardBarWidth = baseHalfWidth + 2;

        for (var b = 1; b <= numGustBars; b++) {
            var bCenterX = baseX - (b * barSpacing * uX).toNumber();
            var bCenterY = baseY - (b * barSpacing * uY).toNumber();

            var bX1 = bCenterX + (standardBarWidth * pX).toNumber();
            var bY1 = bCenterY + (standardBarWidth * pY).toNumber();
            var bX2 = bCenterX - (standardBarWidth * pX).toNumber();
            var bY2 = bCenterY - (standardBarWidth * pY).toNumber();

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
        var isCompact = dc.getHeight() < 120;
        var len = isCompact ? 6 : 8;
        if (windSpeed >= 35.0f) {
            len = isCompact ? 10 : 14;
        } else if (windSpeed >= 25.0f) {
            len = isCompact ? 8 : 12;
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
        // Same tiers as calculateGustSeverity() and drawWindArrow():
        // 3 barbs at gust >= 45 or ratio >= 1.7, 2 at >= 35 / 1.5,
        // 1 at >= 25 / 1.3, 0 below (caller gates arrow visibility).
        var gustRatio = windSpeed > 1.0f ? gust / windSpeed : 1.0f;
        var numBarbs = 0;
        if (gust >= 45.0f || gustRatio >= 1.7f) {
            numBarbs = 3;
        } else if (gust >= 35.0f || gustRatio >= 1.5f) {
            numBarbs = 2;
        } else if (gust >= 25.0f || gustRatio >= 1.3f) {
            numBarbs = 1;
        }

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
        // Draw 0-3 diagonal flags sloping backwards along the tail
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
