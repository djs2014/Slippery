import Toybox.System;
import Toybox.Lang;
import Toybox.Graphics;
import Toybox.Time;

class RiskProjectionEngine {
    // Simulates stateful metrics and returns an Array of 12 RiskLevel values
    public static function calculate12HourRiskProfile(
        currentMetrics as WeatherMetrics,
        startIndex as Number, //Start will be index of the next hour
        airTemps as Array<Float>,
        surfaceTemps as Array<Float>,
        dewPoints as Array<Float>,
        humidities as Array<Number>,
        rains as Array<Float>,
        snows as Array<Float>,
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

        // --- Initialize State with Current Real-Time Values ---
        var runningDryStreak = currentMetrics.dryStreak;
        var runningPrecip12h = currentMetrics.precip12hSum;
        var runningSnow12h = currentMetrics.snow12hSum;

        // Keep a rolling window of 12 hourly precip/snow totals for exact rolling sums
        // (Index 0 = oldest hour, Index 11 = current hour)
        var precipHistory = new [maxForecast] as Array<Float>;
        var snowHistory = new [maxForecast] as Array<Float>;

        // Seed initial history approximation (distribute current maxForecast h sum evenly)
        var avgInitialPrecip = currentMetrics.precip12hSum / maxForecast.toFloat();
        var avgInitialSnow = currentMetrics.snow12hSum / maxForecast.toFloat();
        for (var k = 0; k < maxForecast; k++) {
            precipHistory[k] = avgInitialPrecip;
            snowHistory[k] = avgInitialSnow;
        }

        // --- 12-Hour Simulation Loop ---
        var profileIndex = -1;
        for (var h = startIndex; h < maxForecast; h++) {
            profileIndex += 1;
            // 1. Extract Instantaneous Hourly Metrics
            var airTemp = airTemps[h];
            var surfaceTemp = surfaceTemps[h];
            var dewPoint = dewPoints[h];
            var humidity = humidities[h];
            var rainCurrent = rains[h];
            var snowCurrent = snows[h];
            var windSpeed = windSpeeds[h];
            var windGust = windGusts[h];            
            var surfaceDewSpread = surfaceTemp - dewPoint;

            // 2. Advance Stateful Metrics (Dry Streak)
            if (rainCurrent > 0.1f || snowCurrent > 0.0f) {
                runningDryStreak = 0;
            } else {
                runningDryStreak += 1;
            }

            // 3. Advance Stateful Rolling 12-Hour Accumulations
            // Subtract the oldest hour leaving the 12h window, add the incoming hour
            runningPrecip12h =
                runningPrecip12h - precipHistory[0] + rainCurrent;
            runningSnow12h = runningSnow12h - snowHistory[0] + snowCurrent;
            if (runningPrecip12h < 0.0f) {
                runningPrecip12h = 0.0f;
            }
            if (runningSnow12h < 0.0f) {
                runningSnow12h = 0.0f;
            }

            // Shift rolling history window left
            for (var i = 0; i < maxForecast - 1; i++) {
                precipHistory[i] = precipHistory[i + 1];
                snowHistory[i] = snowHistory[i + 1];
            }
            precipHistory[maxForecast - 1] = rainCurrent;
            snowHistory[maxForecast - 1] = snowCurrent;

            // 4. Derive Immediate Rain / Snow for Future Hours
            // For hour 'h', immediate lookahead looks at hour 'h+1' if within array bounds
            var immediateRain = -1;
            var immediateSnow = -1;
            if (rainCurrent > 0.0f) {
                immediateRain = 0; // Active rain during this hour
            } else if (
                h + 1 < rains.size() &&
                rains[h + 1] > 0.1f
            ) {
                immediateRain = 60; // Starting within the next hour block
            }

            if (snowCurrent > 0.0f) {
                immediateSnow = 0; // Active snow during this hour
            } else if (
                h + 1 < snows.size() &&
                snows[h + 1] > 0.0f
            ) {
                immediateSnow = 60;
            }

            // 5. Calculate Risk for Hour 'h' using re-calculated state
            riskProfile[profileIndex] = RiskCalculator.evaluateRisk(
                airTemp,
                surfaceTemp,
                dewPoint,
                humidity,
                rainCurrent,
                runningPrecip12h,
                runningSnow12h,
                runningDryStreak,
                season,
                windSpeed,
                windGust,
                immediateRain,
                immediateSnow,
                surfaceDewSpread,
                snowCurrent
            );
        }

        return riskProfile;
    }
}
