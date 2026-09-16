import Toybox.System;
import Toybox.Lang;
import Toybox.Math;

public class WeatherUtils {
    /**
     * Calculates Dew Point in Celsius using the Magnus-Tetens approximation.
     *
     * @param tempC Ambient temperature in Celsius
     * @param humidity Relative humidity percentage (0 - 100)
     * @return Dew point in Celsius
     */
    public static function calculateDewPoint(
        tempC as Float,
        humidity as Float
    ) as Float {
        if (humidity <= 0.0f) {
            return tempC;
        }

        var a = 17.27f;
        var b = 237.7f;

        // alpha = ((a * T) / (b + T)) + ln(RH / 100)
        var alpha = (a * tempC) / (b + tempC) + Math.ln(humidity / 100.0f);

        // Dew Point = (b * alpha) / (a - alpha)
        var dewPoint = (b * alpha) / (a - alpha);

        return dewPoint;
    }

    /**
     * Calculates Heat Index (Apparent Temperature) in Celsius.
     * Fallback to ambient temperature if temp < 20°C (68°F).
     *
     * @param tempC Ambient temperature in Celsius
     * @param humidity Relative humidity percentage (0 - 100)
     * @return Heat Index in Celsius
     */
    public static function calculateHeatIndex(
        tempC as Float,
        humidity as Number
    ) as Float {
        // Heat Index is only valid for temperatures >= 20°C (68°F)
        if (tempC < 20.0f) {
            return tempC;
        }

        // Convert Celsius to Fahrenheit for Rothfusz formula
        var T = (tempC * 9.0f) / 5.0f + 32.0f;
        var RH = humidity;

        // Simple Steadman formula baseline
        var hiF = 0.5f * (T + 61.0f + (T - 68.0f) * 1.2f + RH * 0.094f);

        // If average HI >= 80°F, apply full Rothfusz regression equation
        if (hiF >= 80.0f) {
            hiF =
                -42.379f +
                2.04901523f * T +
                10.14333127f * RH -
                0.22475541f * T * RH -
                0.00683783f * T * T -
                0.05481717f * RH * RH +
                0.00122874f * T * T * RH +
                0.00085282f * T * RH * RH -
                0.00000199f * T * T * RH * RH;

            // Adjustment for low humidity + high temperature
            if (RH < 13.0f && T >= 80.0f && T <= 112.0f) {
                var adj =
                    ((13.0f - RH) / 4.0f) *
                    Math.sqrt((17.0f - (T - 95.0f).abs()) / 17.0f);
                hiF -= adj;
            }
            // Adjustment for high humidity + high temperature
            else if (RH > 85.0f && T >= 80.0f && T <= 87.0f) {
                var adj = ((RH - 85.0f) / 10.0f) * ((87.0f - T) / 5.0f);
                hiF += adj;
            }
        }

        // Convert result back to Celsius
        return ((hiF - 32.0f) * 5.0f) / 9.0f;
    }

    /**
     * Calculates a Unified Apparent ("Feels Like") Temperature in Celsius.
     * Integrates Wind Chill (for cold/windy conditions) and Heat Index (for hot/humid conditions).
     * 
     * @param tempC Ambient temperature in Celsius
     * @param humidity Relative humidity percentage (0 - 100)
     * @param windSpeedKmh Wind speed in km/h
     * @return Apparent Temperature in Celsius
     */
    public static function getApparentTemperature(
        tempC as Float,
        humidity as Number,
        windSpeedKmh as Float
    ) as Float {
        // 1. COLD REGIME: Apply Environment Canada Wind Chill Formula
        // Applicable when Temp <= 10°C and Wind Speed > 4.8 km/h
        if (tempC <= 10.0f && windSpeedKmh > 4.8f) {
            var v016 = Math.pow(windSpeedKmh, 0.16f);
            var windChill = 13.12f 
                + (0.6215f * tempC) 
                - (11.37f * v016) 
                + (0.3965f * tempC * v016);
            return windChill;
        }

        // 2. HOT REGIME: Apply Rothfusz Heat Index Formula
        // Applicable when Temp >= 20°C (68°F)
        if (tempC >= 20.0f) {
            return calculateHeatIndex(tempC, humidity);
        }

        // 3. MILD REGIME: Ambient Temperature (10°C < Temp < 20°C)
        return tempC;
    }
}


/*

var tempC = 28.5f;     // 28.5°C
var humidity = 75.0f;  // 75% RH

var dewPoint = WeatherMetrics.calculateDewPoint(tempC, humidity);
var heatIndex = WeatherMetrics.calculateHeatIndex(tempC, humidity);

// Use Dew Point to pick background color for the 12-hour bar
var barColor = ComfortColors.getComfortColor(dewPoint, isDark);
*/