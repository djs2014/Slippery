import Toybox.System;
import Toybox.Lang;
import Toybox.Graphics;
import Toybox.Time;

class RiskProjectionEngine {
    // Simulates metrics and returns an Array of RiskLevel values based on full historical/forecast arrays
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
        var maxForecast = airTemps.size();
        if (maxForecast <= 0 || startIndex >= maxForecast) {
            return [];
        }

        var maxProfileLength = maxForecast - startIndex;
        var riskProfile = new [maxProfileLength] as Array<RiskLevel>;
        var season = currentMetrics.currentSeason;

        var profileIndex = -1;
        for (var h = startIndex; h < maxForecast; h++) {
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

            // --- 1. DIRECT 12-HOUR ROLLING RAIN & SNOW SUMS ---
            var runningRainAndShower12h = 0.0f;
            var runningSnow12h = 0.0f;
            var windowStart = h - 11 < 0 ? 0 : h - 11;

            for (var k = windowStart; k <= h; k++) {
                runningRainAndShower12h += rains[k] + showers[k];
                runningSnow12h += snows[k];                
            }

            // --- 2. DIRECT DRY STREAK COMPUTATION ---
            var runningDryStreak = 0;
            if (rainAndShowerCurrent <= 0.1f && snowCurrent <= 0.0f) {
                // Count consecutive previous dry hours up to 24h
                for (var d = h - 1; d >= 0; d--) {
                    // Combine rain and shower for dry streak check
                    if (rains[d] + showers[d] <= 0.1f && snows[d] <= 0.0f) {
                        runningDryStreak++;
                    } else {
                        break;
                    }
                }
            }

            // --- 3. IMMEDIATE PRECIPITATION LOOKAHEAD ---
            // -1 no immediate precipitation, 0 active during this hour, 60 starting within next hour block
            var PRECIP_THRESHOLD = 0.1f; // Minimum 0.1mm to count as meaningful precipitation
            var immediateRainAndShower = -1;
            if (rainAndShowerCurrent > PRECIP_THRESHOLD) {
                immediateRainAndShower = 0; // Active rain during this hour
            } else if (h + 1 < rains.size() && rains[h + 1] + showers[h + 1] > PRECIP_THRESHOLD) {
                immediateRainAndShower = 60; // Starting within next hour block
            }
        
            var immediateSnow = -1;
            if (snowCurrent > PRECIP_THRESHOLD) {
                immediateSnow = 0; // Active snow during this hour
            } else if (h + 1 < snows.size() && snows[h + 1] > PRECIP_THRESHOLD) {
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

        return riskProfile;
    }
}
