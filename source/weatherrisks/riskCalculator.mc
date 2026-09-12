import Toybox.System;
import Toybox.Lang;
import Toybox.Graphics;
import Toybox.Time;

public class RiskCalculator {
    static var _riskOnly as Boolean = false;
    static var _riskLevel as RiskLevel = RiskLevelNoData;
    static var _hazards = [] as Array<WeatherHazard>;
    static var _advice = [] as Array<WeatherAdvice>;

    public static function setRiskOnly(riskOnly as Boolean) as Void {
        _riskOnly = riskOnly;
    }
    public static function getRiskOnly() as Boolean {
        return _riskOnly;
    }
    public static function getRiskLevel() as RiskLevel {
        return _riskLevel;
    }

    public static function getHazards() as Array<WeatherHazard> {
        return _hazards;
    }

    public static function getAdvice() as Array<WeatherAdvice> {
        return _advice;
    }
    private static function reset() as Void {
        _riskLevel = RiskLevelNoData;
        _hazards = [];
        _advice = [];
    }
    public static function evaluateRisk(
        airTemp as Float,
        surfaceTemp as Float,
        dewPoint as Float,
        humidity as Number,
        rainCurrent as Float,
        runningPrecip12h as Float,
        runningSnow12h as Float,
        runningDryStreak as Number,
        season as MeteorologicalSeason,
        windSpeed as Float,
        windGust as Float,
        immediateRain as Number,
        immediateSnow as Number,
        surfaceDewSpread as Float,
        snowCurrent as Float        
    ) as RiskLevel {
        reset();

        // --- 1. CRITICAL: Black Ice & Freezing Wet Asphalt ---
        if (
            (surfaceTemp <= 0.0 || airTemp <= 0.5) &&
            (runningPrecip12h > 0.0 || rainCurrent > 0.0)
        ) {
            upgradeRisk(RiskLevelCritical);
            addHazard(HazardBlackIceFreezingWetRoad);
            addAdvice(AdviceAvoidRiding);
            addAdvice(AdviceLowerTirePressure);
        }

        // --- 2. CRITICAL: Hoarfrost / Freezing" Fog ---
        if (surfaceTemp <= 0.0 && surfaceDewSpread <= 2.0) {
            upgradeRisk(RiskLevelCritical);
            addHazard(HazardRoadSurfaceFrost);
            addAdvice(AdviceWatchOutForShadedAreasBridgesTreeLinedRoads);
            addAdvice(AdviceAvoidSuddenBraking);
        }

        // --- 3. HIGH: Bridge Deck Freeze ---
        if (
            airTemp >= 0.0 &&
            airTemp <= 2.5 &&
            (runningPrecip12h > 0.0 || humidity > 88)
        ) {
            upgradeRisk(RiskLevelHigh);
            addHazard(HazardIceOnBridges);
            addAdvice(AdviceWatchOutForShadedAreasBridgesTreeLinedRoads);
        }

        // --- 4. HIGH: Snow / Slush Accumulation ---
        if (runningSnow12h > 0.0) {
            upgradeRisk(RiskLevelHigh);
            addHazard(HazardSnowOrSlushAccumulation);
            addAdvice(AdviceLossOfTractionInTurns);
            addAdvice(AdviceTreadPatternRequired);
        }

        // --- 5. HIGH / MODERATE: Heavy Rain Hydroplaning & Spray ---
        if (rainCurrent >= 5.0) {
            upgradeRisk(RiskLevelHigh);
            addHazard(HazardHeavyRainHydroplaning);
            addAdvice(AdviceIncreaseBreakingDistance);
            addAdvice(AdviceReduceSpeedAndIncreaseGripMargin);
        }

        // --- 6. MODERATE: Autumn Wet Leaves ---
        if (
            season == SeasonAutumn &&
            (runningPrecip12h > 0.0 || humidity > 90)
        ) {
            upgradeRisk(RiskLevelModerate);
            addHazard(HazardWetLeafCoverage);
            addAdvice(AdviceExtremeSlipHazardOnCorneringLines);
            addAdvice(AdviceReduceCorneringLeanAngle);
        }

        // --- 7. MODERATE: Summer/Spring First Rain ("Oil Slick") ---
        if (
            (season == SeasonSummer || season == SeasonSpring) &&
            rainCurrent > 0.0 &&
            rainCurrent < 2.5 &&
            runningDryStreak >= 18 // dry hours before rain
        ) {
            upgradeRisk(RiskLevelModerate);
            addHazard(HazardFirstRainReleasingDirtOils);
            addAdvice(AdviceAsphaltSlippery);
            addAdvice(AdviceTractionImprovesAfterHeavierRain);
        }

        // --- 8. SLIGHT: Dew Condensation ("Sweating Road") ---
        if (surfaceTemp > 0.0 && humidity > 90 && surfaceDewSpread <= 1.0) {
            upgradeRisk(RiskLevelSlight);
            addHazard(HazardWetAsphaltSurface);
            addAdvice(AdviceWatchOutForShadedAreasBridgesTreeLinedRoads);
            addAdvice(AdviceReduceCorneringLeanAngle);
        }

        // --- 9. SLIGHT: Light / Moderate Rain ---
        if (rainCurrent > 0.2 && rainCurrent < 5.0) {
            upgradeRisk(RiskLevelSlight);
            addHazard(HazardWetAsphaltSurface);
            addAdvice(AdviceIncreaseBreakingDistance);
            addAdvice(AdviceReduceCorneringLeanAngle);
        }

        // --- 10. CRITICAL / HIGH: Gale-Force Crosswinds & Violent Gusts ---
        if (windSpeed >= 45.0 || windGust >= 60.0) {
            upgradeRisk(RiskLevelCritical);
            addHazard(HazardGaleForceWinds);
            addAdvice(AdviceBewareOfOpenFieldsAndBridges);
            addAdvice(AdviceHoldHandlebarsFirmly);
            addAdvice(AdviceConsiderLowerProfileWheels);
        }
        // --- 11. MODERATE: Strong / Gusty Winds ---
        else if (windSpeed >= 30.0 || windGust >= 45.0) {
            upgradeRisk(RiskLevelModerate);
            addHazard(HazardStrongCrosswinds);
            addAdvice(AdviceBewareOfOpenFieldsAndBridges);
            addAdvice(AdviceHoldHandlebarsFirmly);
        }

        // --- 12. IMMEDIATE: Imminent Rain ---
        if (immediateRain >= 0 && rainCurrent < 0.1f) {
            upgradeRisk(RiskLevelHigh);
            addHazard(HazardImminentRain);

            // if (metrics.immediateRain == 0) {
            //     addAdvice( AdviceRainStartingNow);
            // } else {
            //     // Triggers UI banner: "RAIN IN 15 MIN" or "RAIN IN 30 MIN"
            //     addAdvice( AdviceRainExpectedShortly);
            // }
        }
        // --- 13. IMMEDIATE: Imminent Snow ---
        if (immediateSnow >= 0 && snowCurrent < 0.1f) {
            upgradeRisk(RiskLevelHigh);
            addHazard(HazardImminentSnow);

            // if (metrics.immediateSnow == 0) {
            //     addAdvice( AdviceSnowStartingNow);
            // } else {runningPrecip12h
            //     // Triggers UI banner: "SNOW IN 15 MIN" or "SNOW IN 30 MIN"
            //     addAdvice( AdviceSnowExpectedShortly);
            // }
        }

        return _riskLevel;
    }

    // --- HELPER UTILITIES FOR SAFE ARRAY & RISK MANAGEMENT ---

    static function upgradeRisk(newLevel as RiskLevel) as Void {
        if (newLevel > _riskLevel) {
            _riskLevel = newLevel;
        }
    }

    static function addHazard(hazard as WeatherHazard) as Void {
        if (_riskOnly) {
            return;
        }
        if (_hazards.indexOf(hazard) == -1) {
            _hazards.add(hazard);
        }
    }

    static function addAdvice(advice as WeatherAdvice) as Void {
        if (_riskOnly) {
            return;
        }
        if (_advice.indexOf(advice) == -1) {
            _advice.add(advice);
        }
    }
}
