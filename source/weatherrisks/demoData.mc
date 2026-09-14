import Toybox.System;
import Toybox.Lang;
import Toybox.Graphics;
import Toybox.Time;
class DemoWeatherService {
    public static function getDemoWeatherMetrics(
        counter as Number
    ) as WeatherMetrics {
        var wd = new WeatherMetrics();
        var now = System.getTimer() / 1000; // Base Unix timestamp (in seconds)

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
            // --- RISK LEVEL SLIGHT: Autumn Dampness & Incoming Rain ---
            wd.airTemp = 12.0f;
            wd.surfaceTemp = 11.0f;
            wd.dewPoint = 10.0f;
            wd.humidity = 88;
            wd.rainCurrent = 0.0f;
            wd.snowCurrent = 0.0f;
            wd.windSpeed = 18.0f;
            wd.windGust = 28.0f;
            wd.windDirection = 270;

            wd.rain12hSum = 1.2f;
            wd.snow12hSum = 0.0f;
            wd.dryStreak = 1;
            wd.currentSeason = SeasonAutumn;

            wd.immediateRain = 30; // Rain approaching in 30 mins
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
                28.0f, 32.0f, 38.0f, 42.0f, 40.0f, 35.0f, 30.0f, 28.0f, 25.0f,
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
            wd.rainCurrent = 1.8f;
            wd.snowCurrent = 0.0f;
            wd.windSpeed = 25.0f;
            wd.windGust = 42.0f;
            wd.windDirection = 220;

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
                42.0f, 46.0f, 48.0f, 44.0f, 38.0f, 32.0f, 28.0f, 25.0f, 22.0f,
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
            wd.rainCurrent = 4.5f;
            wd.snowCurrent = 0.0f;
            wd.windSpeed = 32.0f;
            wd.windGust = 55.0f;
            wd.windDirection = 310;

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
            wd.rainCurrent = 0.2f;
            wd.snowCurrent = 0.0f;
            wd.windSpeed = 20.0f;
            wd.windGust = 35.0f;
            wd.windDirection = 180;

            wd.rain12hSum = 12.0f;
            wd.snow12hSum = 0.0f;
            wd.dryStreak = 0;
            wd.currentSeason = SeasonWinter;

            wd.immediateRain = -1;
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
            wd.rainCurrent = 0.8f;
            wd.snowCurrent = 1.5f;
            wd.windSpeed = 28.0f;
            wd.windGust = 48.0f;
            wd.windDirection = 45;

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

        if (wd.timeStampsForeCast.size() == 12) {
            // Populate Unix Timestamps for the 12 forecast hours (3600 seconds per hour)
            for (var h = 0; h < 12; h++) {
                wd.timeStampsForeCast[h] = now + h * 3600;
            }
        }

        return wd;
    }

    var currentRiskLevel = RiskLevelSafe;
    public static function getDemoRiskAssessment(
        counter as Number
    ) as RiskAssessment {
        // TODO demo weather data
        var ra = new RiskAssessment();
        if (counter <= 5) {
            ra.riskLevel = RiskLevelSafe;
        } else if (counter <= 10) {
            ra.riskLevel = RiskLevelSlight;
            addHazard(ra, HazardWetAsphaltSurface);
            addAdvice(ra, AdviceIncreaseBreakingDistance);
            addAdvice(ra, AdviceReduceCorneringLeanAngle);
        } else if (counter <= 20) {
            ra.riskLevel = RiskLevelModerate;
            addHazard(ra, HazardStrongCrosswinds);
            addAdvice(ra, AdviceBewareOfOpenFieldsAndBridges);
            addAdvice(ra, AdviceHoldHandlebarsFirmly);
        } else if (counter <= 30) {
            ra.riskLevel = RiskLevelHigh;
            addHazard(ra, HazardImminentRain);
            addAdvice(ra, AdviceIncreaseBreakingDistance);
            addAdvice(ra, AdviceReduceSpeedAndIncreaseGripMargin);
        } else if (counter <= 40) {
            ra.riskLevel = RiskLevelModerate;
            addHazard(ra, HazardStrongCrosswinds);
            addAdvice(ra, AdviceBewareOfOpenFieldsAndBridges);
            addAdvice(ra, AdviceHoldHandlebarsFirmly);
        } else if (counter <= 50) {
            ra.riskLevel = RiskLevelCritical;
            addHazard(ra, HazardGaleForceWinds);
            addAdvice(ra, AdviceBewareOfOpenFieldsAndBridges);
            addAdvice(ra, AdviceHoldHandlebarsFirmly);
            addAdvice(ra, AdviceConsiderLowerProfileWheels);
        }

        return ra;
    }

    static function addHazard(
        assessment as RiskAssessment,
        hazard as WeatherHazard
    ) as Void {
        if (assessment.hazards.indexOf(hazard) == -1) {
            assessment.hazards.add(hazard);
        }
    }

    static function addAdvice(
        assessment as RiskAssessment,
        advice as WeatherAdvice
    ) as Void {
        if (assessment.advice.indexOf(advice) == -1) {
            assessment.advice.add(advice);
        }
    }
}
