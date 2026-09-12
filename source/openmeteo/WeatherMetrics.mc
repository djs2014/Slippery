import Toybox.System;
import Toybox.Lang;
import Toybox.Graphics;
import Toybox.Time;
import Toybox.Lang;

class WeatherMetrics {
    var isValid as Boolean = false;
    
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






