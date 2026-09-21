import Toybox.System;
import Toybox.Lang;
import Toybox.Graphics;
import Toybox.Time;
(:extendedCode) 
class DemoWeatherService {
    public static function getDemoWeatherMetrics(
        counter as Number
    ) as WeatherMetrics {
        var wd = new WeatherMetrics();
        var now = System.getTimer() / 1000; // Base Unix timestamp (in seconds)
        // Absolute hour labels follow the real clock, not hour 0.
        wd.currentHour = System.getClockTime().hour;

        if (counter <= 5) {
            // --- SAFE: Ideal Summer Ride ---
            wd.airTemp = 25.0f;
            wd.surfaceTemp = 20.0f;
            wd.dewPoint = 18.0f;
            wd.humidity = 51;
            wd.rainCurrent = 0.0f;
            wd.snowCurrent = 0.0f;
            wd.windSpeed = 5.0f;
            wd.windGust = 7.0f;
            wd.windDirection = 90;
            wd.gustSeverity = 1; // gust 7 < 25 but ratio 1.4 >= 1.3

            wd.rain12hSum = 0.0f;
            wd.snow12hSum = 0.0f;
            wd.dryStreak = 12;
            wd.currentSeason = SeasonSummer;

            wd.immediateRain = -1;
            wd.immediateSnow = -1;

            // Populate 12h Forecast Arrays (Steady, calm summer conditions)
            wd.timeStampsForeCast = new [12];
            wd.rainForecast = [
                0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f,
                0.0f, 0.0f,
            ];
            wd.snowForecast = [
                0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f,
                0.0f, 0.0f,
            ];
            wd.windForecast = [
                5.0f, 5.5f, 6.0f, 6.5f, 7.0f, 6.5f, 6.0f, 5.5f, 5.0f, 4.5f,
                4.0f, 4.0f,
            ];
            wd.windDirForecast = [
                90, 95, 100, 100, 105, 110, 110, 105, 100, 95, 90, 90,
            ];
            wd.windGustForecast = [
                7.0f, 8.0f, 9.0f, 9.5f, 10.0f, 9.0f, 8.5f, 8.0f, 7.0f, 6.0f,
                5.5f, 5.0f,
            ];
            wd.airTempForecast = [
                25.0f, 25.5f, 26.0f, 26.2f, 25.8f, 25.0f, 24.0f, 23.0f, 22.0f,
                21.0f, 20.5f, 20.0f,
            ];
            wd.surfaceTempForecast = [
                20.0f, 21.0f, 22.0f, 22.5f, 22.0f, 21.0f, 20.0f, 19.0f, 18.0f,
                17.5f, 17.0f, 16.5f,
            ];
        } else if (counter <= 10) {
            // --- RISK LEVEL SLIGHT: Autumn Morning Dew (bone dry, rain only in forecast) ---
            wd.airTemp = 12.0f;
            wd.surfaceTemp = 11.0f;
            wd.dewPoint = 10.2f;
            wd.humidity = 92;
            wd.rainCurrent = 0.0f;
            wd.snowCurrent = 0.0f;
            wd.windSpeed = 18.0f;
            wd.windGust = 22.0f;
            wd.windDirection = 270;
            wd.gustSeverity = 0; // gust 22 < 25, ratio ~1.2 < 1.3

            wd.rain12hSum = 0.0f;
            wd.snow12hSum = 0.0f;
            wd.dryStreak = 12;
            wd.currentSeason = SeasonAutumn;

            wd.immediateRain = -1;
            wd.immediateSnow = -1;

            // Forecast: Dry now, light rain starting at hour 1-2, winds picking up
            wd.timeStampsForeCast = new [12];
            wd.rainForecast = [
                0.0f, 0.8f, 1.5f, 1.8f, 1.2f, 0.5f, 0.0f, 0.0f, 0.0f, 0.0f,
                0.0f, 0.0f,
            ];
            wd.snowForecast = [
                0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f,
                0.0f, 0.0f,
            ];
            wd.windForecast = [
                18.0f, 20.0f, 24.0f, 26.0f, 25.0f, 22.0f, 19.0f, 18.0f, 16.0f,
                15.0f, 14.0f, 12.0f,
            ];
            wd.windDirForecast = [
                270, 265, 260, 255, 250, 245, 240, 240, 245, 250, 255, 260,
            ];
            wd.windGustForecast = [
                22.0f, 32.0f, 38.0f, 42.0f, 40.0f, 35.0f, 30.0f, 28.0f, 25.0f,
                22.0f, 20.0f, 18.0f,
            ];
            wd.airTempForecast = [
                12.0f, 11.5f, 11.0f, 10.5f, 10.0f, 9.8f, 9.5f, 9.2f, 9.0f, 8.8f,
                8.5f, 8.2f,
            ];
            wd.surfaceTempForecast = [
                11.0f, 10.5f, 10.0f, 9.5f, 9.2f, 9.0f, 8.8f, 8.5f, 8.2f, 8.0f,
                7.8f, 7.5f,
            ];
        } else if (counter <= 20) {
            // --- RISK LEVEL MODERATE: Rain Active & Strong Crosswind Gusts ---
            wd.airTemp = 8.0f;
            wd.surfaceTemp = 7.0f;
            wd.dewPoint = 7.0f;
            wd.humidity = 93;
            wd.rainCurrent = 2.1f; // == rainForecast[0] + showersForecast[0]
            wd.snowCurrent = 0.0f;
            wd.windSpeed = 25.0f;
            wd.windGust = 34.0f;
            wd.windDirection = 220;
            wd.gustSeverity = 1; // gust 34 >= 25, ratio ~1.36 >= 1.3

            wd.rain12hSum = 6.5f;
            wd.snow12hSum = 0.0f;
            wd.dryStreak = 0;
            wd.currentSeason = SeasonAutumn;

            wd.immediateRain = 0;
            wd.immediateSnow = -1;

            // Forecast: Active steady rain continuing for 4 hours, then tapering off
            wd.timeStampsForeCast = new [12];
            wd.rainForecast = [
                1.8f, 2.2f, 2.0f, 1.5f, 0.8f, 0.2f, 0.0f, 0.0f, 0.0f, 0.0f,
                0.0f, 0.0f,
            ];
            wd.snowForecast = [
                0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f,
                0.0f, 0.0f,
            ];
            wd.windForecast = [
                25.0f, 28.0f, 30.0f, 27.0f, 24.0f, 20.0f, 18.0f, 16.0f, 15.0f,
                14.0f, 12.0f, 10.0f,
            ];
            wd.windDirForecast = [
                220, 225, 230, 235, 240, 245, 250, 250, 245, 240, 235, 230,
            ];
            wd.windGustForecast = [
                34.0f, 46.0f, 48.0f, 44.0f, 38.0f, 32.0f, 28.0f, 25.0f, 22.0f,
                20.0f, 18.0f, 15.0f,
            ];
            wd.airTempForecast = [
                8.0f, 7.5f, 7.2f, 7.0f, 6.8f, 6.5f, 6.2f, 6.0f, 5.8f, 5.5f,
                5.2f, 5.0f,
            ];
            wd.surfaceTempForecast = [
                7.0f, 6.6f, 6.3f, 6.0f, 5.8f, 5.5f, 5.2f, 5.0f, 4.8f, 4.5f,
                4.2f, 4.0f,
            ];
        } else if (counter <= 30) {
            // --- RISK LEVEL HIGH: Near-Freezing Heavy Rain & Transitioning to Sleet ---
            wd.airTemp = 1.5f;
            wd.surfaceTemp = 0.8f;
            wd.dewPoint = 0.5f;
            wd.humidity = 95;
            wd.rainCurrent = 5.0f; // == rainForecast[0] + showersForecast[0]
            wd.snowCurrent = 0.0f;
            wd.windSpeed = 32.0f;
            wd.windGust = 55.0f;
            wd.windDirection = 310;
            wd.gustSeverity = 3;

            wd.rain12hSum = 18.0f;
            wd.snow12hSum = 0.0f;
            wd.dryStreak = 0;
            wd.currentSeason = SeasonWinter;

            wd.immediateRain = 0;
            wd.immediateSnow = 15; // Transition to snow in 15 mins

            // Forecast: Temperature drops sub-zero, heavy rain turns into heavy snowfall
            wd.timeStampsForeCast = new [12];
            wd.rainForecast = [
                4.5f, 2.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f,
                0.0f, 0.0f,
            ];
            wd.snowForecast = [
                0.0f, 1.5f, 3.2f, 2.8f, 1.0f, 0.2f, 0.0f, 0.0f, 0.0f, 0.0f,
                0.0f, 0.0f,
            ];
            wd.windForecast = [
                32.0f, 35.0f, 38.0f, 36.0f, 30.0f, 26.0f, 22.0f, 20.0f, 18.0f,
                16.0f, 15.0f, 14.0f,
            ];
            wd.windDirForecast = [
                310, 315, 320, 325, 330, 335, 340, 340, 345, 350, 350, 355,
            ];
            wd.windGustForecast = [
                55.0f, 60.0f, 65.0f, 62.0f, 52.0f, 44.0f, 36.0f, 32.0f, 28.0f,
                25.0f, 22.0f, 20.0f,
            ];
            wd.airTempForecast = [
                1.5f, 0.2f, -0.8f, -1.5f, -2.0f, -2.5f, -2.8f, -3.0f, -3.2f,
                -3.5f, -3.8f, -4.0f,
            ];
            wd.surfaceTempForecast = [
                0.8f, -0.2f, -1.2f, -2.0f, -2.6f, -3.0f, -3.3f, -3.5f, -3.8f,
                -4.0f, -4.2f, -4.5f,
            ];
        } else if (counter <= 40) {
            // --- RISK LEVEL MODERATE: Winter Post-Rain Freeze Risk ---
            wd.airTemp = 4.0f;
            wd.surfaceTemp = 3.2f;
            wd.dewPoint = 2.8f;
            wd.humidity = 92;
            wd.rainCurrent = 0.3f; // == rainForecast[0] + showersForecast[0]
            wd.snowCurrent = 0.0f;
            wd.windSpeed = 20.0f;
            wd.windGust = 35.0f;
            wd.windDirection = 180;
            wd.gustSeverity = 3;

            wd.rain12hSum = 12.0f;
            wd.snow12hSum = 0.0f;
            wd.dryStreak = 0;
            wd.currentSeason = SeasonWinter;

            wd.immediateRain = 0; // drizzle active now (minutely[0] >= 0.1)
            wd.immediateSnow = -1;

            // Forecast: Light drizzle clearing, temperatures dropping steadily toward 0°C
            wd.timeStampsForeCast = new [12];
            wd.rainForecast = [
                0.2f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f,
                0.0f, 0.0f,
            ];
            wd.snowForecast = [
                0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f,
                0.0f, 0.0f,
            ];
            wd.windForecast = [
                20.0f, 18.0f, 16.0f, 15.0f, 14.0f, 12.0f, 11.0f, 10.0f, 10.0f,
                9.0f, 8.0f, 8.0f,
            ];
            wd.windDirForecast = [
                180, 185, 190, 195, 200, 205, 210, 215, 220, 225, 230, 235,
            ];
            wd.windGustForecast = [
                35.0f, 30.0f, 26.0f, 24.0f, 22.0f, 18.0f, 16.0f, 15.0f, 14.0f,
                12.0f, 11.0f, 10.0f,
            ];
            wd.airTempForecast = [
                4.0f, 3.2f, 2.5f, 1.8f, 1.0f, 0.5f, 0.1f, -0.2f, -0.5f, -0.8f,
                -1.0f, -1.2f,
            ];
            wd.surfaceTempForecast = [
                3.2f, 2.5f, 1.8f, 1.0f, 0.2f, -0.2f, -0.8f, -1.2f, -1.5f, -1.8f,
                -2.0f, -2.2f,
            ];
        } else if (counter <= 50) {
            // --- RISK LEVEL CRITICAL: Sub-Zero Surface & Black Ice Formation ---
            wd.airTemp = -1.5f;
            wd.surfaceTemp = -2.2f;
            wd.dewPoint = -2.0f;
            wd.humidity = 98;
            wd.rainCurrent = 1.0f; // == rainForecast[0] + showersForecast[0]
            wd.snowCurrent = 1.5f;
            wd.windSpeed = 28.0f;
            wd.windGust = 48.0f;
            wd.windDirection = 45;
            wd.gustSeverity = 3;

            wd.rain12hSum = 14.0f;
            wd.snow12hSum = 5.0f;
            wd.dryStreak = 0;
            wd.currentSeason = SeasonWinter;

            wd.immediateRain = 0;
            wd.immediateSnow = 0;

            // Forecast: Freezing rain & severe blizzard conditions continuing
            wd.timeStampsForeCast = new [12];
            wd.rainForecast = [
                0.8f, 0.5f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f,
                0.0f, 0.0f,
            ];
            wd.snowForecast = [
                1.5f, 2.8f, 3.5f, 2.0f, 1.0f, 0.4f, 0.0f, 0.0f, 0.0f, 0.0f,
                0.0f, 0.0f,
            ];
            wd.windForecast = [
                28.0f, 32.0f, 35.0f, 30.0f, 26.0f, 22.0f, 18.0f, 16.0f, 15.0f,
                14.0f, 12.0f, 10.0f,
            ];
            wd.windDirForecast = [
                45, 50, 55, 60, 60, 65, 70, 70, 75, 80, 80, 85,
            ];
            wd.windGustForecast = [
                48.0f, 54.0f, 58.0f, 50.0f, 42.0f, 35.0f, 28.0f, 25.0f, 22.0f,
                20.0f, 18.0f, 15.0f,
            ];
            wd.airTempForecast = [
                -1.5f, -2.0f, -2.5f, -3.0f, -3.5f, -4.0f, -4.2f, -4.5f, -4.8f,
                -5.0f, -5.2f, -5.5f,
            ];
            wd.surfaceTempForecast = [
                -2.2f, -2.8f, -3.3f, -3.8f, -4.2f, -4.6f, -4.8f, -5.0f, -5.2f,
                -5.5f, -5.8f, -6.0f,
            ];
        }

        if (counter <= 5) {
            wd.showersForecast = [
                0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f,
                0.0f, 0.0f,
            ];
            wd.dewpointForecast = [
                18.0f, 18.2f, 18.5f, 18.0f, 17.5f, 17.0f, 16.0f, 15.0f, 14.0f,
                13.0f, 12.5f, 12.0f,
            ];
            wd.minutelyRainForecast = [0.0f, 0.0f, 0.0f, 0.0f];
            wd.minutelySnowForecast = [0.0f, 0.0f, 0.0f, 0.0f];
            wd.precipProbForecast = [
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            ];
            wd.sunshineDurationForecast = [
                1800.0f, 2400.0f, 3000.0f, 3600.0f, 3600.0f, 3000.0f, 2400.0f, 1800.0f, 1200.0f, 600.0f,
                0.0f, 0.0f,
            ];
        } else if (counter <= 10) {
            wd.showersForecast = [
                0.0f, 0.1f, 0.2f, 0.2f, 0.1f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f,
                0.0f, 0.0f,
            ];
            wd.dewpointForecast = [
                10.2f, 9.8f, 9.5f, 9.2f, 9.0f, 8.8f, 8.5f, 8.2f, 8.0f, 7.8f,
                7.5f, 7.2f,
            ];
            wd.minutelyRainForecast = [0.0f, 0.0f, 0.0f, 0.0f];
            wd.minutelySnowForecast = [0.0f, 0.0f, 0.0f, 0.0f];
            wd.precipProbForecast = [
                0, 35, 60, 75, 55, 25, 5, 0, 0, 0, 0, 0,
            ];
            wd.sunshineDurationForecast = [
                600.0f, 1200.0f, 1800.0f, 2400.0f, 2800.0f, 3000.0f, 2600.0f, 2000.0f, 1200.0f, 600.0f,
                0.0f, 0.0f,
            ];
        } else if (counter <= 20) {
            wd.showersForecast = [
                0.3f, 0.4f, 0.3f, 0.2f, 0.1f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f,
                0.0f, 0.0f,
            ];
            wd.dewpointForecast = [
                7.0f, 6.8f, 6.5f, 6.2f, 6.0f, 5.8f, 5.5f, 5.2f, 5.0f, 4.8f,
                4.5f, 4.2f,
            ];
            wd.minutelyRainForecast = [1.5f, 1.8f, 2.0f, 2.2f];
            wd.minutelySnowForecast = [0.0f, 0.0f, 0.0f, 0.0f];
            wd.precipProbForecast = [
                90, 95, 95, 85, 60, 30, 10, 0, 0, 0, 0, 0,
            ];
            wd.sunshineDurationForecast = [
                300.0f, 200.0f, 100.0f, 0.0f, 0.0f, 100.0f, 300.0f, 600.0f, 900.0f, 600.0f,
                300.0f, 0.0f,
            ];
        } else if (counter <= 30) {
            wd.showersForecast = [
                0.5f, 0.8f, 0.4f, 0.1f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f,
                0.0f, 0.0f,
            ];
            wd.dewpointForecast = [
                0.5f, -0.1f, -0.8f, -1.4f, -2.0f, -2.4f, -2.8f, -3.1f, -3.4f,
                -3.7f, -4.0f, -4.3f,
            ];
            wd.minutelyRainForecast = [3.5f, 3.0f, 2.2f, 1.5f];
            wd.minutelySnowForecast = [0.0f, 0.2f, 0.8f, 1.5f]; // snow from ~15 min
            wd.precipProbForecast = [
                95, 90, 85, 80, 50, 20, 5, 0, 0, 0, 0, 0,
            ];
            wd.sunshineDurationForecast = [
                0.0f, 0.0f, 0.0f, 100.0f, 300.0f, 600.0f, 800.0f, 600.0f, 300.0f, 100.0f,
                0.0f, 0.0f,
            ];
        } else if (counter <= 40) {
            wd.showersForecast = [
                0.1f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f,
                0.0f, 0.0f,
            ];
            wd.dewpointForecast = [
                2.8f, 2.2f, 1.6f, 1.0f, 0.4f, 0.0f, -0.4f, -0.8f, -1.1f, -1.4f,
                -1.7f, -2.0f,
            ];
            wd.minutelyRainForecast = [0.2f, 0.1f, 0.0f, 0.0f];
            wd.minutelySnowForecast = [0.0f, 0.0f, 0.0f, 0.0f];
            wd.precipProbForecast = [
                20, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            ];
            wd.sunshineDurationForecast = [
                0.0f, 200.0f, 600.0f, 1200.0f, 1800.0f, 2000.0f, 1800.0f, 1200.0f, 600.0f, 200.0f,
                0.0f, 0.0f,
            ];
        } else if (counter <= 50) {
            wd.showersForecast = [
                0.2f, 0.1f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f,
                0.0f, 0.0f,
            ];
            wd.dewpointForecast = [
                -2.0f, -2.5f, -3.0f, -3.5f, -3.9f, -4.3f, -4.6f, -4.9f, -5.1f,
                -5.4f, -5.7f, -6.0f,
            ];
            wd.minutelyRainForecast = [0.8f, 0.5f, 0.2f, 0.0f];
            wd.minutelySnowForecast = [1.5f, 2.0f, 2.5f, 2.8f];
            wd.precipProbForecast = [
                85, 90, 95, 85, 60, 30, 5, 0, 0, 0, 0, 0,
            ];
            wd.sunshineDurationForecast = [
                0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f,
                0.0f, 0.0f,
            ];
        }

        if (wd.timeStampsForeCast.size() == 12) {
            // Populate Unix Timestamps for the 12 forecast hours (3600 seconds per hour)
            for (var h = 0; h < 12; h++) {
                wd.timeStampsForeCast[h] = now + h * 3600;
            }
        }

        return wd;
    }

    var currentRiskLevel = RiskLevelSafe;
    // Derives the demo assessment from the demo metrics through the real
    // risk engine, so demo level/hazards/advice can never drift from the
    // demo weather again (single source of truth).
    public static function getDemoRiskAssessment(
        metrics as WeatherMetrics
    ) as RiskAssessment {
        var assessment = new RiskAssessment();

        RiskCalculator.setRiskOnly(false);
        assessment.riskLevel = RiskCalculator.evaluateRisk(
            metrics.airTemp,
            metrics.surfaceTemp,
            metrics.dewPoint,
            metrics.humidity,
            metrics.rainCurrent,
            metrics.rain12hSum,
            metrics.snow12hSum,
            metrics.dryStreak,
            metrics.currentSeason,
            metrics.windSpeed,
            metrics.windGust,
            metrics.immediateRain,
            metrics.immediateSnow,
            metrics.surfaceTemp - metrics.dewPoint,
            metrics.snowCurrent
        );
        assessment.hazards = RiskCalculator.getHazards();
        assessment.advice = RiskCalculator.getAdvice();

        // Forecast risk heatmap for the sparkline (layer B draws nothing
        // when this stays empty): same 12h projection engine as the live
        // path, run over the demo forecast hours. Demo has no humidity
        // forecast, so current humidity is held constant across the window.
        var demoHumidities = new [12] as Array<Number>;
        for (var hh = 0; hh < 12; hh++) {
            demoHumidities[hh] = metrics.humidity;
        }
        assessment.hourlyRisksLevels =
            RiskProjectionEngine.calculate12HourRiskProfile(
                metrics,
                0,
                metrics.airTempForecast,
                metrics.surfaceTempForecast,
                metrics.dewpointForecast,
                demoHumidities,
                metrics.rainForecast,
                metrics.showersForecast,
                metrics.snowForecast,
                metrics.windForecast,
                metrics.windGustForecast
            );
        return assessment;
    }
}
