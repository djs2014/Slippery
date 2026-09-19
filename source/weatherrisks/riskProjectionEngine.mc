import Toybox.System;
import Toybox.Lang;
import Toybox.Graphics;
import Toybox.Time;

class RiskProjectionEngine {
    // Reconstructs per-hour derived metrics and evaluates risk for the current
    // hour plus the next 12 forecast hours (max 13 entries).
    public static function calculate12HourRiskProfile(
        currentMetrics as WeatherMetrics,
        startIndex as Number, // Start index of the current/next hour to project
        airTemps as Array<Float>,
        surfaceTemps as Array<Float>,
        dewPoints as Array<Float>,
        humidities as Array<Number>,
        rains as Array<Float>, // Contains full series (-12h up to +12h)
        showers as Array<Float>, // Contains full series (-12h up to +12h)
        snows as Array<Float>, // Contains full series (-12h up to +12h)
        windSpeeds as Array<Float>,
        windGusts as Array<Float>
    ) as Array<RiskLevel> {
        // Guard against ragged API arrays: work on the common prefix length so
        // no input array is ever indexed out of bounds.
        var count = airTemps.size();
        if (surfaceTemps.size() < count) {
            count = surfaceTemps.size();
        }
        if (dewPoints.size() < count) {
            count = dewPoints.size();
        }
        if (humidities.size() < count) {
            count = humidities.size();
        }
        if (rains.size() < count) {
            count = rains.size();
        }
        if (showers.size() < count) {
            count = showers.size();
        }
        if (snows.size() < count) {
            count = snows.size();
        }
        if (windSpeeds.size() < count) {
            count = windSpeeds.size();
        }
        if (windGusts.size() < count) {
            count = windGusts.size();
        }
        if (count <= 0) {
            return [];
        }
        if (startIndex < 0) {
            startIndex = 0;
        }
        if (startIndex >= count) {
            return [];
        }

        // Current hour + 12 forecast hours. Caps the profile when the API
        // returns longer series so the sparkline bars keep a usable width.
        var endIndex = startIndex + 12;
        if (endIndex >= count) {
            endIndex = count - 1;
        }
        var maxProfileLength = endIndex - startIndex + 1;
        var riskProfile = new [maxProfileLength] as Array<RiskLevel>;
        var season = currentMetrics.currentSeason;

        // Rain/showers are mm/h, snowfall is cm/h (Open-Meteo unit).
        var RAIN_THRESHOLD = 0.1f;
        var SNOW_THRESHOLD = 0.1f;

        // Projection only needs risk levels; keep the shared static
        // hazards/advice of the live assessment untouched.
        var prevRiskOnly = RiskCalculator.getRiskOnly();
        RiskCalculator.setRiskOnly(true);
        try {
            var profileIndex = -1;
            for (var h = startIndex; h <= endIndex; h++) {
                profileIndex += 1;

                var airTemp = airTemps[h];
                var surfaceTemp = surfaceTemps[h];
                var dewPoint = dewPoints[h];
                var humidity = humidities[h];
                // Combine rain and shower current values
                var rainAndShowerCurrent = rains[h] + showers[h];
                var snowCurrent = snows[h];
                var windSpeed = windSpeeds[h];
                var windGust = windGusts[h];
                var surfaceDewSpread = surfaceTemp - dewPoint;

                // --- 1. 12-HOUR ROLLING RAIN & SNOW SUMS ---
                // Window [h-12, h]: 13 hourly samples covering a 12h span,
                // identical to the live path in WeatherService.
                var runningRainAndShower12h = 0.0f;
                var runningSnow12h = 0.0f;
                var windowStart = h - 12 < 0 ? 0 : h - 12;

                for (var k = windowStart; k <= h; k++) {
                    runningRainAndShower12h += rains[k] + showers[k];
                    runningSnow12h += snows[k];
                }

                // --- 2. DRY STREAK: PRECEDING dry hours (excludes current) ---
                // Always counted, even while it is raining now: this is what the
                // first-rain rule needs ("dry hours preceding rain"). Same
                // definition and thresholds as the live path.
                var runningDryStreak = 0;
                for (var d = h - 1; d >= 0 && runningDryStreak < 24; d--) {
                    // Combine rain and shower for dry streak check
                    if (
                        rains[d] + showers[d] <= RAIN_THRESHOLD &&
                        snows[d] <= SNOW_THRESHOLD
                    ) {
                        runningDryStreak++;
                    } else {
                        break;
                    }
                }

                // --- 3. IMMEDIATE PRECIPITATION LOOKAHEAD ---
                // -1 no immediate precipitation, 0 active during this hour,
                // 60 starting within next hour block (hourly equivalent of the
                // live minutely_15 0/15/30/45 codes; the risk rule only tests >= 0)
                var immediateRainAndShower = -1;
                if (rainAndShowerCurrent >= RAIN_THRESHOLD) {
                    immediateRainAndShower = 0; // Active rain during this hour
                } else if (
                    h + 1 < count &&
                    rains[h + 1] + showers[h + 1] >= RAIN_THRESHOLD
                ) {
                    immediateRainAndShower = 60; // Starting within next hour block
                }

                var immediateSnow = -1;
                if (snowCurrent >= SNOW_THRESHOLD) {
                    immediateSnow = 0; // Active snow during this hour
                } else if (h + 1 < count && snows[h + 1] >= SNOW_THRESHOLD) {
                    immediateSnow = 60;
                }

                // --- 4. EVALUATE RISK ---
                riskProfile[profileIndex] = RiskCalculator.evaluateRisk(
                    airTemp,
                    surfaceTemp,
                    dewPoint,
                    humidity,
                    rainAndShowerCurrent,
                    runningRainAndShower12h,
                    runningSnow12h,
                    runningDryStreak,
                    season,
                    windSpeed,
                    windGust,
                    immediateRainAndShower,
                    immediateSnow,
                    surfaceDewSpread,
                    snowCurrent
                );
            }
        } finally {
            RiskCalculator.setRiskOnly(prevRiskOnly);
        }

        return riskProfile;
    }
}
