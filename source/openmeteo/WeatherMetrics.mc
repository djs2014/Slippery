import Toybox.System;
import Toybox.Lang;
import Toybox.Graphics;
import Toybox.Time;


class WeatherMetrics {
    var isValid as Boolean = false;
    var currentHour as Number = 0; // Current hour of the day (0-23)
    
    // Current Instant Metrics
    var airTemp as Float = 0.0; // in °C
    var surfaceTemp as Float = 0.0; // in °C
    var dewPoint as Float = 0.0; // in °C
    var humidity as Number = 0; // in %
    var rainCurrent as Float = 0.0; // in mm/h contains also showers
    var snowCurrent as Float = 0.0; // in cm/h
    var windSpeed as Float = 0.0; // in km/h
    var windGust as Float = 0.0; // in km/h
    var windDirection as Number = 0; // in degrees (0-359 deg) where the wind is coming from (standard weather map style)
    var gustSeverity as Number = 0; // Level of wind gust severity

    // Past 12h Context
    var rain12hSum as Float = 0.0; // in mm
    var snow12hSum as Float = 0.0; // in cm
    var dryStreak as Number = 0; // Length of the current dry streak in hours

    var currentSeason as MeteorologicalSeason = SeasonNoData;

    // forecast metrics per hour
    var hourFractionRemaining as Float = 1.0; // Fraction of the current hour that is remaining (0.0 - 1.0)
    var timeStampsForeCast as Array<Number> = []; // Number items (unixtime in seconds)
    var rainForecast as Array<Float> = []; // Float items (mm/h)
    var showersForecast as Array<Float> = []; // Float items (mm/h)
    var windForecast as Array<Float> = []; // Float items (km/h)
    var windDirForecast as Array<Number> = []; // Number items (0-359 deg) where the wind is coming from (standard weather map style)
    var windGustForecast as Array<Float> = []; // Float items (km/h)
    var airTempForecast as Array<Float> = []; // Float items (°C air)
    var snowForecast as Array<Float> = []; // Float items (cm/h)
    var surfaceTempForecast as Array<Float> = []; // Float items (°C surface)
    var dewpointForecast as Array<Float> = []; // Float items (°C)

    // Immediate rain in 15-minute intervals
    // (-1 = No rain soon, 0 = Active rain, 15/30/45 = Starting soon)
    var immediateRain as Number = -1;
    var immediateSnow as Number = -1;
    var minutelyRainForecast as Array<Float> = []; // Array<Float> (mm per 15-min interval)
    var minutelySnowForecast as Array<Float> = []; // Array<Float> (mm per 15-min interval)
    
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
            ", snowCurrent=" +
            snowCurrent +
            ", rain12hSum=" +            
            rain12hSum +
            ", snow12hSum=" +
            snow12hSum +
            ", windSpeed=" +
            windSpeed +
            ", windGust=" +
            windGust +
            ", windDirection=" +
            windDirection +
            ", dryStreak=" +
            dryStreak +
            ", currentSeason=" +
            currentSeason +
            ", immediateRain=" +
            immediateRain +
            ", immediateSnow=" +
            immediateSnow +
            ", timeStampsForeCast=" +
            timeStampsForeCast +
            ", rainForecast=" +
            rainForecast +
            ", showersForecast=" +
            showersForecast +
            ", windForecast=" +
            windForecast +
            ", windDirForecast=" +
            windDirForecast +
            ", windGustForecast=" +
            windGustForecast +
            ", airTempForecast=" +
            airTempForecast +
            ", snowForecast=" +
            snowForecast +
            ", surfaceTempForecast=" +
            surfaceTempForecast +
            ", dewpointForecast=" +
            dewpointForecast +
            "}"
        );
    }
}
