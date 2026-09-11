import Toybox.System;
import Toybox.Lang;
import Toybox.Graphics;
import Toybox.Time;
import Toybox.Lang;

class WeatherMetrics {

    // Current Instant Metrics
    var airTemp as Float = 0.0; // in °C
    var surfaceTemp as Float = 0.0; // in °C
    var dewPoint as Float = 0.0; // in °C
    var humidity as Number = 0; // in %
    var rainCurrent as Float = 0.0; // in mm/h
    var snowCurrent as Float = 0.0; // in mm/h
    var windSpeed as Float = 0.0; // in km/h
    var windGust as Float = 0.0; // in km/h
    var windDirection as Number = 0; // in degrees

    // Past 12h Context
    var precip12hSum as Float = 0.0;
    var snow12hSum as Float = 0.0;
    var dryStreak as Number = 0; // Length of the current dry streak in hours

    var currentSeason as MeteorologicalSeason = SeasonNoData;

    // forecast metrics per hour
    var timeStampsForeCast as Array<Number> = []; // Number items (unixtime in seconds)
    var rainForecast as Array<Float> = []; // Float items (mm/h)
    var windForecast as Array<Float> = []; // Float items (km/h)
    var windDirForecast as Array<Number> = []; // Number items (0-359 deg)
    var tempForecast as Array<Float> = []; // Float items (°C surface/air)

    // Immediate rain in 15-minute intervals
    // (-1 = No rain soon, 0 = Active rain, 15/30/45 = Starting soon)
    var immediateRain as Number = -1;
    var immediateSnow as Number = -1;

    public function toString() as String {
        return (
            "WeatherMetrics{" +
            "airTemp=" +
            airTemp +
            ", surfaceTemp=" +
            surfaceTemp +
            ", dewPoint=" +
            dewPoint +
            ", humidity=" +
            humidity +
            ", rainCurrent=" +
            rainCurrent +
            ", precip12hSum=" +
            snowCurrent +
            ", snowCurrent=" +
            precip12hSum +
            ", snow12hSum=" +
            snow12hSum +
            ", windSpeed=" +
            windSpeed +
            ", windGust=" +
            windGust +
            ", dryStreak=" +
            dryStreak +
            ", currentSeason=" +
            currentSeason +
            ", immediateRain=" +
            immediateRain +
            ", immediateSnow=" +
            immediateSnow +
            "}"
        );
    }
}

function parseOpenMeteoResponse(
    lat as Float,
    data as Dictionary?
) as WeatherMetrics? {  
    if (data == null || !data.hasKey("hourly")) {
        return null;
    }

    var hourly = data.get("hourly") as Dictionary;
    var times = hourly.get("time") as Array<Number>?;

    if (times == null || times.size() == 0) {
        System.println("No hourly time data available.");
        return null;
    }

    // Get current device UTC time in seconds
    var nowSec = Time.now().value();

    // Find index for current hour (or fallback to latest)
    var targetIdx = times.size() - 1;
    for (var i = 0; i < times.size(); i++) {
        if (times[i] >= nowSec) {
            // times[i] is start of the hour
            // we need to go back one hour to get the current hour's data if possible
            if (i > 0) {
                targetIdx = i - 1;
            } else {
                targetIdx = i;
            }
            break;
        }
    }
    System.println("Target index for current hour: " + targetIdx);
    // Get the current hour's index and corresponding time
    var currentHourTime = times[targetIdx];
    System.println("Current hour time in unixtime: " + currentHourTime);
    System.println(
        "Current hour time formatted: " + formatUnixTime(currentHourTime)
    );

    // Extract current metrics directlyp = precips[t
    var metrics = new WeatherMetrics();

    var airTemps = hourly.get("temperature_2m") as Array<Float>?;
    var surfTemps = hourly.get("surface_temperature") as Array<Float>?;
    var dewPoints = hourly.get("dewpoint_2m") as Array<Float>?;
    var humidities = hourly.get("relativehumidity_2m") as Array<Number>?;
    var rains = hourly.get("rain") as Array<Float>?;
    var precips = hourly.get("precipitation") as Array<Float>?;
    var snows = hourly.get("snowfall") as Array<Float>?;
    var windSpeeds = hourly.get("wind_speed_10m") as Array<Float>?;
    var windGusts = hourly.get("wind_gusts_10m") as Array<Float>?;
    var windDirections = hourly.get("wind_direction_10m") as Array<Number>?;
    if (airTemps == null || surfTemps == null || dewPoints == null || humidities == null || rains == null || precips == null || snows == null || windSpeeds == null || windGusts == null || windDirections == null) {
        System.println("One or more required hourly data arrays are missing.");
        return null;
    }
    metrics.airTemp = airTemps[targetIdx];
    metrics.surfaceTemp = surfTemps[targetIdx];
    metrics.dewPoint = dewPoints[targetIdx];
    metrics.humidity = humidities[targetIdx];
    metrics.rainCurrent = rains[targetIdx];
    metrics.snowCurrent = snows[targetIdx];
    metrics.windSpeed = windSpeeds[targetIdx];
    metrics.windGust = windGusts[targetIdx];
    metrics.windDirection = windDirections[targetIdx];

    // Calculate 12-hour accumulated moisture lookback for slipperiness
    var startIdx = targetIdx - 12;
    if (startIdx < 0) {
        startIdx = 0;
    }

    var sumPrecip = 0.0;
    var sumSnow = 0.0;

    for (var j = startIdx; j <= targetIdx; j++) {
        if (j < precips.size()) {
            sumPrecip += precips[j];
        }
        if (j < snows.size()) {
            sumSnow += snows[j];
        }
    }

    metrics.precip12hSum = sumPrecip;
    metrics.snow12hSum = sumSnow;

    // Look back at dry streak length (for "first rain after dry spell" effect)
    var dryStreak = 0;
    for (var k = targetIdx; k >= 0; k--) {
        if (    k < rains.size() && rains[k] == 0.0) {
            dryStreak += 1;
        } else {
            break;
        }
    }
    metrics.dryStreak = dryStreak;

    metrics.currentSeason = getMeteorologicalSeason(lat, Time.now());

    // Get the 12 hour forecast for rain, wind, wind direction, and temperature
    // Start with the current hour time index! 
    var maxForecastIdx = times.size();
    for (var l = targetIdx; l < maxForecastIdx; l++) {
        if (l < times.size()) {
            metrics.timeStampsForeCast.add(times[l]);
        }
        if (l < rains.size()) {
            metrics.rainForecast.add(rains[l]);
        }
        if (l < windSpeeds.size()) {
            metrics.windForecast.add(windSpeeds[l]);
        }
        if (l < windDirections.size()) {
            metrics.windDirForecast.add(windDirections[l]);
        }
        if (l < airTemps.size()) {
            metrics.tempForecast.add(airTemps[l]);
        }
    }

    var minutelyData = data.get("minutely_15") as Dictionary?;
    if (minutelyData != null) {
        var rainArray = minutelyData.get("rain") as Array<Float>?;
        var snowArray = minutelyData.get("snowfall") as Array<Float>?;

        // Gives the rider 15–30 minutes notice before wet asphalt compromises cornering grip
        var threshold = 0.1f;
        metrics.immediateRain = $.checkForImminentPrecipitation(
            rainArray,
            threshold
        );
        metrics.immediateSnow = $.checkForImminentPrecipitation(
            snowArray,
            threshold
        );
    }
    return metrics;
}

function checkForImminentPrecipitation(
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
