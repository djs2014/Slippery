import Toybox.System;
import Toybox.Lang;
import Toybox.Graphics;
import Toybox.Time;
class DemoWeatherService {
    public static function getDemoWeatherMetrics(
        counter as Number
    ) as WeatherMetrics {
        var wd = new WeatherMetrics();

        if (counter <= 5) {
            // Safe: Ideal summer conditions, dry roads
            wd.airTemp = 25.0;
            wd.surfaceTemp = 20.0;
            wd.dewPoint = 18.0;
            wd.humidity = 51;
            wd.rainCurrent = 0.0;
            wd.snowCurrent = 0.0;
            wd.windSpeed = 5.0;
            wd.windGust = 7.0;
            wd.windDirection = 90;

            wd.precip12hSum = 0.0;
            wd.snow12hSum = 0.0;
            wd.dryStreak = 12;
            wd.currentSeason = SeasonSummer;

            wd.immediateRain = -1;
            wd.immediateSnow = -1;
        } else if (counter <= 10) {
            // RiskLevelSlight: Autumn dampness, wet leaf hazard, light crosswind
            wd.airTemp = 12.0;
            wd.surfaceTemp = 11.0;
            wd.dewPoint = 10.0;
            wd.humidity = 88;
            wd.rainCurrent = 0.0;
            wd.snowCurrent = 0.0;
            wd.windSpeed = 18.0;
            wd.windGust = 28.0;
            wd.windDirection = 270;

            wd.precip12hSum = 1.2;
            wd.snow12hSum = 0.0;
            wd.dryStreak = 1;
            wd.currentSeason = SeasonAutumn;

            wd.immediateRain = 30; // Rain expected in 30 minutes
            wd.immediateSnow = -1;
        } else if (counter <= 20) {
            // RiskLevelModerate: Light rain starting, wet road surface, moderate wind gusts
            wd.airTemp = 8.0;
            wd.surfaceTemp = 7.0;
            wd.dewPoint = 7.0;
            wd.humidity = 93;
            wd.rainCurrent = 1.8;
            wd.snowCurrent = 0.0;
            wd.windSpeed = 25.0;
            wd.windGust = 42.0;
            wd.windDirection = 220;

            wd.precip12hSum = 6.5;
            wd.snow12hSum = 0.0;
            wd.dryStreak = 0;
            wd.currentSeason = SeasonAutumn;

            wd.immediateRain = 0; // Active rain starting now
            wd.immediateSnow = -1;
        } else if (counter <= 30) {
            // RiskLevelHigh: Near-freezing temperatures, heavy rain, imminent frost/sleet risk
            wd.airTemp = 1.5;
            wd.surfaceTemp = 0.8;
            wd.dewPoint = 0.5;
            wd.humidity = 95;
            wd.rainCurrent = 4.5;
            wd.snowCurrent = 0.0;
            wd.windSpeed = 32.0;
            wd.windGust = 55.0;
            wd.windDirection = 310;

            wd.precip12hSum = 18.0;
            wd.snow12hSum = 0.0;
            wd.dryStreak = 0;
            wd.currentSeason = SeasonWinter;

            wd.immediateRain = 0;
            wd.immediateSnow = 15; // Transitioning to snow in 15 mins
        } else if (counter <= 40) {
            // RiskLevelModerate: Post-rain cooling, lingering damp asphalt, moderate gusty winds
            wd.airTemp = 4.0;
            wd.surfaceTemp = 3.2;
            wd.dewPoint = 2.8;
            wd.humidity = 92;
            wd.rainCurrent = 0.2;
            wd.snowCurrent = 0.0;
            wd.windSpeed = 20.0;
            wd.windGust = 35.0;
            wd.windDirection = 180;

            wd.precip12hSum = 12.0;
            wd.snow12hSum = 0.0;
            wd.dryStreak = 0;
            wd.currentSeason = SeasonWinter;

            wd.immediateRain = -1;
            wd.immediateSnow = -1;
        } else if (counter <= 50) {
            // RiskLevelCritical: Sub-zero road surface, black ice formation, freezing rain
            wd.airTemp = -1.5;
            wd.surfaceTemp = -2.2;
            wd.dewPoint = -2.0;
            wd.humidity = 98;
            wd.rainCurrent = 0.8;
            wd.snowCurrent = 1.5;
            wd.windSpeed = 28.0;
            wd.windGust = 48.0;
            wd.windDirection = 45;

            wd.precip12hSum = 14.0;
            wd.snow12hSum = 5.0;
            wd.dryStreak = 0;
            wd.currentSeason = SeasonWinter;

            wd.immediateRain = 0;
            wd.immediateSnow = 0; // Active freezing rain/snow now
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
