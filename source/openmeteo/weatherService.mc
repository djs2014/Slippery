import Toybox.System;
import Toybox.Lang;
import Toybox.Graphics;
import Toybox.Time;

class WeatherService {
    private static var _metrics as WeatherMetrics = new WeatherMetrics();
    private static var _risks as RiskAssessment = new RiskAssessment();
    private static var _processing as Boolean = false;
    private static var _lastRecalculationHour as Number = -1;

    public static function getMetrics() as WeatherMetrics {
        return _metrics;
    }

    public static function getRisks() as RiskAssessment {
        return _risks;
    }

    private static var _cachedData as Dictionary? = null;
    // Recalculate on hour switch to get the 'latest' weather data
    public static function recalculateOpenMeteoData(lat as Float) as Boolean {
        var currentHour = System.getClockTime().hour;
        if (_processing || currentHour == _lastRecalculationHour) {
            return false;
        }

        return parseOpenMeteoResponse(lat, _cachedData);
    }

    // Parse OpenMeteo API response and update weather metrics
    // Calculate risk assessment based on parsed weather data
    // Calculate risk forecast based on parsed weather data
    public static function parseOpenMeteoResponse(
        lat as Float,
        data as Dictionary?
    ) as Boolean {
        if (
            _processing ||
            data == null ||
            !data.hasKey("hourly") ||
            !data.hasKey("minutely_15")
        ) {
            return false;
        }

        _processing = true;
        try {
            var currentHour = System.getClockTime().hour;
            System.println("Processing for current hour: " + currentHour);

            _cachedData = data;

            var hourly = data.get("hourly") as Dictionary;
            var times = hourly.get("time") as Array<Number>?;

            if (times == null || times.size() == 0) {
                System.println("No hourly time data available.");
                return false;
            }

            // Get current device UTC time in seconds
            var nowSec = Time.now().value();
            var targetIdx = 0; // Fallback to start of array

            // Find the latest hour start timestamp that has already passed (times[i] <= nowSec)
            for (var i = 0; i < times.size(); i++) {
                if (times[i] <= nowSec) {
                    targetIdx = i;
                } else {
                    // Since times is strictly ascending, the moment times[i] > nowSec,
                    // targetIdx holds the correct active hour.
                    break;
                }
            }

            System.println("Target index for current hour: " + targetIdx);
            // Get the current hour's index and corresponding time
            var currentHourTime = times[targetIdx];
            System.println("Current hour time in unixtime: " + currentHourTime);
            System.println(
                "Current hour time formatted: " +
                    formatUnixTime(currentHourTime)
            );

            // Extract current metrics directlyp = precips[t
            var metrics = new WeatherMetrics();
            metrics.currentHour = currentHour;

            var airTemps = hourly.get("temperature_2m") as Array<Float>?;
            var surfTemps = hourly.get("surface_temperature") as Array<Float>?;
            var dewPoints = hourly.get("dewpoint_2m") as Array<Float>?;
            var humidities =
                hourly.get("relativehumidity_2m") as Array<Number>?;
            var snows = hourly.get("snowfall") as Array<Float>?;
            var rains = hourly.get("rain") as Array<Float>?;
            var showers = hourly.get("showers") as Array<Float>?;
            var windSpeeds = hourly.get("wind_speed_10m") as Array<Float>?;
            var windGusts = hourly.get("wind_gusts_10m") as Array<Float>?;
            var windDirections =
                hourly.get("wind_direction_10m") as Array<Number>?;
            if (
                airTemps == null ||
                surfTemps == null ||
                dewPoints == null ||
                humidities == null ||
                rains == null ||
                showers == null ||
                snows == null ||
                windSpeeds == null ||
                windGusts == null ||
                windDirections == null
            ) {
                System.println(
                    "One or more required hourly data arrays are missing."
                );
                return false;
            }
            metrics.airTemp = airTemps[targetIdx];
            metrics.surfaceTemp = surfTemps[targetIdx];
            metrics.dewPoint = dewPoints[targetIdx];
            metrics.humidity = humidities[targetIdx];
            metrics.snowCurrent = snows[targetIdx];
            metrics.rainCurrent = rains[targetIdx] + showers[targetIdx];
            metrics.windSpeed = windSpeeds[targetIdx];
            metrics.windGust = windGusts[targetIdx];
            metrics.windDirection = windDirections[targetIdx];
            metrics.gustSeverity = $.calculateGustSeverity(
                metrics.windSpeed,
                metrics.windGust
            );

            // Calculate 12-hour accumulated moisture lookback for slipperiness
            var startIdx = targetIdx - 12;
            if (startIdx < 0) {
                System.println(
                    "Start index for 12-hour lookback is less than 0. Adjusting to 0."
                );
                startIdx = 0;
            }

            var sumRain = 0.0;
            var sumSnow = 0.0;

            for (var j = startIdx; j <= targetIdx; j++) {
                if (j < rains.size() && j < showers.size()) {
                    sumRain += rains[j] + showers[j];
                }
                if (j < snows.size()) {
                    sumSnow += snows[j];
                }
            }

            metrics.rain12hSum = sumRain;
            metrics.snow12hSum = sumSnow;

            // Look back at dry streak length (for "first rain after dry spell" effect)
            // Counts PRECEDING dry hours (excludes the current hour) so the
            // first-rain rule can fire while it is raining now. Same definition
            // and thresholds as RiskProjectionEngine (rain mm, snow cm).
            var dryStreak = 0;
            for (var k = targetIdx - 1; k >= 0 && dryStreak < 24; k--) {
                if (
                    k < rains.size() &&
                    k < showers.size() &&
                    k < snows.size() &&
                    rains[k] + showers[k] <= 0.1f &&
                    snows[k] <= 0.1f
                ) {
                    dryStreak += 1;
                } else {
                    break;
                }
            }
            metrics.dryStreak = dryStreak;

            metrics.currentSeason = $.getMeteorologicalSeason(lat, Time.now());

            // TODO check that all sizes are the same

            // Get the 12 hour forecast for rain, wind, wind direction, and temperature
            // Start with the current hour time index!
            var maxForecastIdx = times.size();
            // Ensure all have same size
            var rainSize = rains.size();
            var showersSize = showers.size();
            var windSpeedSize = windSpeeds.size();
            var windDirectionSize = windDirections.size();
            var windGustSize = windGusts.size();
            var airTempSize = airTemps.size();
            var snowSize = snows.size();
            var surfTempSize = surfTemps.size();
            var dewPointSize = dewPoints.size();
            if (
                rainSize != maxForecastIdx ||
                showersSize != maxForecastIdx ||
                windSpeedSize != maxForecastIdx ||
                windDirectionSize != maxForecastIdx ||
                windGustSize != maxForecastIdx ||
                airTempSize != maxForecastIdx ||
                snowSize != maxForecastIdx ||
                surfTempSize != maxForecastIdx ||
                dewPointSize != maxForecastIdx
            ) {
                System.println(
                    "Warning: Forecast array sizes do not match the times array size."
                );
                System.println(
                    "Sizes: times=" +
                        times.size() +
                        ", rains=" +
                        rains.size() +
                        ", windSpeeds=" +
                        windSpeeds.size() +
                        ", windDirections=" +
                        windDirections.size() +
                        ", windGusts=" +
                        windGusts.size() +
                        ", showers=" +
                        showers.size() +
                        ", airTemps=" +
                        airTemps.size() +
                        ", showers=" +
                        showers.size() +
                        ", snows=" +
                        snows.size() +
                        ", surfTemps=" +
                        surfTemps.size() +
                        ", airTemps=" +
                        airTemps.size() +
                        ", dewPoints=" +
                        dewPoints.size()
                );
            }

            for (var l = targetIdx; l < maxForecastIdx; l++) {
                metrics.timeStampsForeCast.add(times[l]);

                // Guard each array against ragged API responses (a size
                // mismatch is only logged above); missing values default to dry/calm.
                metrics.rainForecast.add(
                    l < rains.size() ? rains[l] : 0.0f
                );
                metrics.showersForecast.add(
                    l < showers.size() ? showers[l] : 0.0f
                );
                metrics.windForecast.add(
                    l < windSpeeds.size() ? windSpeeds[l] : 0.0f
                );
                metrics.windDirForecast.add(
                    l < windDirections.size() ? windDirections[l] : 0
                );
                metrics.windGustForecast.add(
                    l < windGusts.size() ? windGusts[l] : 0.0f
                );
                metrics.airTempForecast.add(
                    l < airTemps.size() ? airTemps[l] : 0.0f
                );
                metrics.snowForecast.add(
                    l < snows.size() ? snows[l] : 0.0f
                );
                metrics.surfaceTempForecast.add(
                    l < surfTemps.size() ? surfTemps[l] : 0.0f
                );
                metrics.dewpointForecast.add(
                    l < dewPoints.size() ? dewPoints[l] : 0.0f
                );
            }

            // Minutely starts at current time and has 4 15-minute intervals
            var minutelyData = data.get("minutely_15") as Dictionary?;
            if (minutelyData != null) {
                // var timeStampArray = minutelyData.get("time") as Array<Number>?;
                var rainArray = minutelyData.get("rain") as Array<Float>?;
                var snowArray = minutelyData.get("snowfall") as Array<Float>?;
                // TEST DATA
                // rainArray =  [0.1f, 0.1f, 0.1f, 0.9f];
                // snowArray =  [0.1f, 1.0f, 0.0f, 1.0f];

                for (var i = 0; i < 4; i++) {
                    // var timestamp =
                    //     timeStampArray != null && timeStampArray.size() > i
                    //         ? timeStampArray[i]
                    //         : 0;
                    // var rain =
                    //     rainArray != null && rainArray.size() > i
                    //         ? rainArray[i]
                    //         : 0.0f;
                    // var snow =
                    //     snowArray != null && snowArray.size() > i
                    //         ? snowArray[i]
                    //         : 0.0f;
                    // var total = rain + snow;
                    // System.println(
                    //     [
                    //         "minutely rainandsnow",
                    //         i,
                    //         total,
                    //         formatUnixTime(timestamp),
                    //     ] +
                    //         " Rain: " +
                    //         rain +
                    //         " Snow: " +
                    //         snow
                    // );

                    metrics.minutelyRainForecast.add(
                        rainArray != null && rainArray.size() > i
                            ? rainArray[i]
                            : 0.0f
                    );
                    metrics.minutelySnowForecast.add(
                        snowArray != null && snowArray.size() > i
                            ? snowArray[i]
                            : 0.0f
                    );
                }
                // Gives the rider 15–30 minutes notice before wet asphalt compromises cornering grip
                var threshold = 0.1f;
                metrics.immediateRain = checkForImminentPrecipitation(
                    rainArray,
                    threshold
                );
                metrics.immediateSnow = checkForImminentPrecipitation(
                    snowArray,
                    threshold
                );
            }

            metrics.isValid = true;
            _metrics = metrics;

            // Calculate Risk Assessment current and forecasted conditions
            var risks = calculateCurrentRiskAssessment();

            // Calculate X-hour risk projection
            risks.hourlyRisksLevels =
                RiskProjectionEngine.calculate12HourRiskProfile(
                    _metrics,
                    targetIdx, // startIndex is current hour
                    airTemps,
                    surfTemps,
                    dewPoints,
                    humidities,
                    rains,
                    showers,
                    snows,
                    windSpeeds,
                    windGusts
                );
            _risks = risks;

            _lastRecalculationHour = currentHour;
            return true;
        } finally {
            _processing = false;
        }
    }

    static function calculateCurrentRiskAssessment() as RiskAssessment {
        var airTemp = _metrics.airTemp;
        var surfaceTemp = _metrics.surfaceTemp;
        var dewPoint = _metrics.dewPoint;
        var humidity = _metrics.humidity;
        var rainCurrent = _metrics.rainCurrent;
        var runningRain12h = _metrics.rain12hSum;
        var runningSnow12h = _metrics.snow12hSum;
        var dryHoursBeforeRain = _metrics.dryStreak;
        var season = _metrics.currentSeason;
        var windSpeed = _metrics.windSpeed; // in km/h
        var windGust = _metrics.windGust; // in km/h
        var immediateRain = _metrics.immediateRain;
        var immediateSnow = _metrics.immediateSnow;
        var snowCurrent = _metrics.snowCurrent;
        var surfaceDewSpread = surfaceTemp - dewPoint;

        var assessment = new RiskAssessment();

        RiskCalculator.setRiskOnly(false);
        var riskLevel = RiskCalculator.evaluateRisk(
            airTemp,
            surfaceTemp,
            dewPoint,
            humidity,
            rainCurrent,
            runningRain12h,
            runningSnow12h,
            dryHoursBeforeRain,
            season,
            windSpeed,
            windGust,
            immediateRain,
            immediateSnow,
            surfaceDewSpread,
            snowCurrent
        );
        assessment.riskLevel = riskLevel;
        assessment.hazards = RiskCalculator.getHazards();
        assessment.advice = RiskCalculator.getAdvice();
        return assessment;
    }
    static function checkForImminentPrecipitation(
        rainOrSnowArray as Array<Float>?,
        mmThreshold as Float
    ) as Number {
        if (rainOrSnowArray == null || rainOrSnowArray.size() == 0) {
            return -1; // No data available
        }
        // Check index 0 (0-15 min), index 1 (15-30 min), index 2 (30-45 min), index 3 (45-60 min)
        var maxSlotsToCheck =
            rainOrSnowArray.size() < 4 ? rainOrSnowArray.size() : 4;

        for (var i = 0; i < maxSlotsToCheck; i++) {
            var precip = rainOrSnowArray[i];
            if (precip != null && precip >= mmThreshold) {
                return i * 15; // Returns 0, 15, 30, or 45 minutes
            }
        }

        return -1; // No rain detected within the hour
    }
}
