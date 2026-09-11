import Toybox.System;
import Toybox.Lang;
import Toybox.Graphics;
import Toybox.Time;

class WeatherService {
    public static function calculateRiskAssessment(
        metrics as WeatherMetrics
    ) as RiskAssessment {
        var assessment = new RiskAssessment();
        assessment.riskLevel = RiskLevelSafe;
        assessment.hazards = [] as Array<WeatherHazard>;
        assessment.advice = [] as Array<WeatherAdvice>;

        var currentTemp = metrics.airTemp;
        var surfaceTemp = metrics.surfaceTemp;
        var dewPoint = metrics.dewPoint;
        var humidity = metrics.humidity;
        var currentRain = metrics.rainCurrent;
        var recentPrecip = metrics.precip12hSum;
        var recentSnow = metrics.snow12hSum;
        var dryHoursBeforeRain = metrics.dryStreak;
        var season = metrics.currentSeason;
        var windSpeed = metrics.windSpeed; // in km/h
        var windGust = metrics.windGust; // in km/h
        // var immediateRain = metrics.immediateRain;
        // var immediateSnow = metrics.immediateSnow;
        var surfaceDewSpread = surfaceTemp - dewPoint;

        // --- 1. CRITICAL: Black Ice & Freezing Wet Asphalt ---
        if (
            (surfaceTemp <= 0.0 || currentTemp <= 0.5) &&
            (recentPrecip > 0.0 || currentRain > 0.0)
        ) {
            upgradeRisk(assessment, RiskLevelCritical);
            addHazard(assessment, HazardBlackIceFreezingWetRoad);
            addAdvice(assessment, AdviceAvoidRiding);
            addAdvice(assessment, AdviceLowerTirePressure);
        }

        // --- 2. CRITICAL: Hoarfrost / Freezing" Fog ---
        if (surfaceTemp <= 0.0 && surfaceDewSpread <= 2.0) {
            upgradeRisk(assessment, RiskLevelCritical);
            addHazard(assessment, HazardRoadSurfaceFrost);
            addAdvice(
                assessment,
                AdviceWatchOutForShadedAreasBridgesTreeLinedRoads
            );
            addAdvice(assessment, AdviceAvoidSuddenBraking);
        }

        // --- 3. HIGH: Bridge Deck Freeze ---
        if (
            currentTemp >= 0.0 &&
            currentTemp <= 2.5 &&
            (recentPrecip > 0.0 || humidity > 88)
        ) {
            upgradeRisk(assessment, RiskLevelHigh);
            addHazard(assessment, HazardIceOnBridges);
            addAdvice(
                assessment,
                AdviceWatchOutForShadedAreasBridgesTreeLinedRoads
            );
        }

        // --- 4. HIGH: Snow / Slush Accumulation ---
        if (recentSnow > 0.0) {
            upgradeRisk(assessment, RiskLevelHigh);
            addHazard(assessment, HazardSnowOrSlushAccumulation);
            addAdvice(assessment, AdviceLossOfTractionInTurns);
            addAdvice(assessment, AdviceTreadPatternRequired);
        }

        // --- 5. HIGH / MODERATE: Heavy Rain Hydroplaning & Spray ---
        if (currentRain >= 5.0) {
            upgradeRisk(assessment, RiskLevelHigh);
            addHazard(assessment, HazardHeavyRainHydroplaning);
            addAdvice(assessment, AdviceIncreaseBreakingDistance);
            addAdvice(assessment, AdviceReduceSpeedAndIncreaseGripMargin);
        }

        // --- 6. MODERATE: Autumn Wet Leaves ---
        if (season == SeasonAutumn && (recentPrecip > 0.0 || humidity > 90)) {
            upgradeRisk(assessment, RiskLevelModerate);
            addHazard(assessment, HazardWetLeafCoverage);
            addAdvice(assessment, AdviceExtremeSlipHazardOnCorneringLines);
            addAdvice(assessment, AdviceReduceCorneringLeanAngle);
        }

        // --- 7. MODERATE: Summer/Spring First Rain ("Oil Slick") ---
        if (
            (season == SeasonSummer || season == SeasonSpring) &&
            currentRain > 0.0 &&
            currentRain < 2.5 &&
            dryHoursBeforeRain >= 18
        ) {
            upgradeRisk(assessment, RiskLevelModerate);
            addHazard(assessment, HazardFirstRainReleasingDirtOils);
            addAdvice(assessment, AdviceAsphaltSlippery);
            addAdvice(assessment, AdviceTractionImprovesAfterHeavierRain);
        }

        // --- 8. SLIGHT: Dew Condensation ("Sweating Road") ---
        if (surfaceTemp > 0.0 && humidity > 90 && surfaceDewSpread <= 1.0) {
            upgradeRisk(assessment, RiskLevelSlight);
            addHazard(assessment, HazardWetAsphaltSurface);
            addAdvice(
                assessment,
                AdviceWatchOutForShadedAreasBridgesTreeLinedRoads
            );
            addAdvice(assessment, AdviceReduceCorneringLeanAngle);
        }

        // --- 9. SLIGHT: Light / Moderate Rain ---
        if (currentRain > 0.2 && currentRain < 5.0) {
            upgradeRisk(assessment, RiskLevelSlight);
            addHazard(assessment, HazardWetAsphaltSurface);
            addAdvice(assessment, AdviceIncreaseBreakingDistance);
            addAdvice(assessment, AdviceReduceCorneringLeanAngle);
        }

        // --- 10. CRITICAL / HIGH: Gale-Force Crosswinds & Violent Gusts ---
        if (windSpeed >= 45.0 || windGust >= 60.0) {
            upgradeRisk(assessment, RiskLevelCritical);
            addHazard(assessment, HazardGaleForceWinds);
            addAdvice(assessment, AdviceBewareOfOpenFieldsAndBridges);
            addAdvice(assessment, AdviceHoldHandlebarsFirmly);
            addAdvice(assessment, AdviceConsiderLowerProfileWheels);
        }
        // --- 11. MODERATE: Strong / Gusty Winds ---
        else if (windSpeed >= 30.0 || windGust >= 45.0) {
            upgradeRisk(assessment, RiskLevelModerate);
            addHazard(assessment, HazardStrongCrosswinds);
            addAdvice(assessment, AdviceBewareOfOpenFieldsAndBridges);
            addAdvice(assessment, AdviceHoldHandlebarsFirmly);
        }

        // --- 12. IMMEDIATE: Imminent Rain ---
        if (metrics.immediateRain >= 0 && metrics.rainCurrent < 0.1f) {
            upgradeRisk(assessment, RiskLevelHigh);
            addHazard(assessment, HazardImminentRain);
            
            // if (metrics.immediateRain == 0) {
            //     addAdvice(assessment, AdviceRainStartingNow);
            // } else {
            //     // Triggers UI banner: "RAIN IN 15 MIN" or "RAIN IN 30 MIN"
            //     addAdvice(assessment, AdviceRainExpectedShortly);
            // }
        }
        // --- 13. IMMEDIATE: Imminent Snow ---
        if (metrics.immediateSnow >= 0 && metrics.snowCurrent < 0.1f) {
            upgradeRisk(assessment, RiskLevelHigh);
            addHazard(assessment, HazardImminentSnow);

            // if (metrics.immediateSnow == 0) {
            //     addAdvice(assessment, AdviceSnowStartingNow);
            // } else {
            //     // Triggers UI banner: "SNOW IN 15 MIN" or "SNOW IN 30 MIN"
            //     addAdvice(assessment, AdviceSnowExpectedShortly);
            // }
        }
        return assessment;
    }

    // --- HELPER UTILITIES FOR SAFE ARRAY & RISK MANAGEMENT ---

    static function upgradeRisk(
        assessment as RiskAssessment,
        newLevel as RiskLevel
    ) as Void {
        if (newLevel > assessment.riskLevel) {
            assessment.riskLevel = newLevel;
        }
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
