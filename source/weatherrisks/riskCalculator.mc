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
        _riskLevel = RiskLevelSafe;
        _hazards = [];
        _advice = [];
    }
    public static function evaluateRisk(
        airTemp as Float,
        surfaceTemp as Float,
        dewPoint as Float,
        humidity as Number,
        rainCurrent as Float,
        runningRain12h as Float,
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
            ((runningRain12h > 0.0 || rainCurrent > 0.0) ||
            (runningSnow12h > 0.0 || snowCurrent > 0.0))
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
            (runningRain12h > 0.0 || humidity > 88 || runningSnow12h > 0.0)
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

        // --- 5. RAIN ---
        // --- CRITICAL: Torrential / Violent Downpour ---
        if (rainCurrent >= 15.0f) {
            upgradeRisk(RiskLevelCritical);
            addHazard(HazardHeavyRainHydroplaning);
            addAdvice(AdviceReduceSpeedAndIncreaseGripMargin);
            addAdvice(AdviceIncreaseBreakingDistance);
        }
        // --- HIGH: Heavy Rain & Standing Water ---
        else if (rainCurrent >= 7.5f) {
            upgradeRisk(RiskLevelHigh);
            addHazard(HazardHeavyRainHydroplaning);
            addAdvice(AdviceIncreaseBreakingDistance);
            addAdvice(AdviceReduceSpeedAndIncreaseGripMargin);
        }
        // --- MODERATE: Summer/Spring First Rain ("Oil Slick") ---
        // Light rain (0.1 - 2.5 mm/h) releases oil film without flushing it away
        else if (
            (season == SeasonSummer || season == SeasonSpring) &&
            rainCurrent >= 0.1f &&
            rainCurrent < 2.5f &&
            runningDryStreak >= 10 // Dry hours preceding rain
        ) {
            upgradeRisk(RiskLevelModerate);
            addHazard(HazardFirstRainReleasingDirtOils);
            addAdvice(AdviceAsphaltSlippery);
            addAdvice(AdviceTractionImprovesAfterHeavierRain);
        }
        // --- MODERATE: Steady Rain ---
        else if (rainCurrent >= 2.5f) {
            upgradeRisk(RiskLevelModerate);
            addHazard(HazardWetAsphaltSurface);
            addAdvice(AdviceIncreaseBreakingDistance);
            addAdvice(AdviceReduceCorneringLeanAngle);
        }
        // --- SLIGHT: Light Rain / Drizzle ---
        else if (rainCurrent >= 0.2f) {
            upgradeRisk(RiskLevelSlight);
            addHazard(HazardWetAsphaltSurface);
            addAdvice(AdviceIncreaseBreakingDistance);
        }

        // --- 6. MODERATE: Autumn Wet Leaves ---
        if (
            season == SeasonAutumn &&
            (runningRain12h > 0.0 || humidity > 90 || runningSnow12h > 0.0)
        ) {
            System.println(
                "Autumn Wet Leaves Risk Assessment: Season = " +
                    season +
                    ", runningRain12h = " +
                    runningRain12h +
                    ", humidity = " +
                    humidity
            );
            upgradeRisk(RiskLevelModerate);
            addHazard(HazardWetLeafCoverage);
            addAdvice(AdviceExtremeSlipHazardOnCorneringLines);
            addAdvice(AdviceReduceCorneringLeanAngle);
        }

        // --- 8. SLIGHT: Dew Condensation ("Sweating Road") ---
        if (surfaceTemp > 0.0 && humidity > 90 && surfaceDewSpread <= 1.0) {
            upgradeRisk(RiskLevelSlight);
            addHazard(HazardWetAsphaltSurface);
            addAdvice(AdviceWatchOutForShadedAreasBridgesTreeLinedRoads);
            addAdvice(AdviceReduceCorneringLeanAngle);
        }

        // --- GUST RATIO CALCULATION ---
        var gustRatio = windSpeed > 1.0f ? windGust / windSpeed : 1.0f;

        // --- 10. CRITICAL: Gale-Force Winds, Extreme Gusts, or 3-Bar Severe Gust Spikes ---
        // Matches: Triangle len 18px + 3 Gust Bars (gust >= 45 km/h OR ratio >= 1.7)
        if (
            windSpeed >= 45.0f ||
            windGust >= 60.0f ||
            (windSpeed >= 35.0f && gustRatio >= 1.7f)
        ) {
            upgradeRisk(RiskLevelCritical);
            addHazard(HazardGaleForceWinds);
            addAdvice(AdviceBewareOfOpenFieldsAndBridges);
            addAdvice(AdviceHoldHandlebarsFirmly);
            addAdvice(AdviceConsiderLowerProfileWheels);
        }
        // --- 11. HIGH: Strong Crosswinds / 2-Bar Heavy Gust Spikes ---
        // Matches: Triangle len 15px + 2 Gust Bars (gust >= 35 km/h OR ratio >= 1.5)
        else if (
            windSpeed >= 35.0f ||
            windGust >= 45.0f ||
            (windSpeed >= 25.0f && gustRatio >= 1.5f)
        ) {
            upgradeRisk(RiskLevelHigh);
            addHazard(HazardStrongCrosswinds);
            addAdvice(AdviceBewareOfOpenFieldsAndBridges);
            addAdvice(AdviceHoldHandlebarsFirmly);
        }
        // --- 12. MODERATE: Moderate Winds / 1-Bar Gust Spikes ---
        // Matches: Triangle len 13px + 1 Gust Bar (gust >= 25 km/h OR ratio >= 1.3)
        else if (
            windSpeed >= 25.0f ||
            windGust >= 35.0f ||
            (windSpeed >= 18.0f && gustRatio >= 1.3f)
        ) {
            upgradeRisk(RiskLevelModerate);
            addHazard(HazardStrongCrosswinds);
            addAdvice(AdviceHoldHandlebarsFirmly);
        }
        // --- 13. SLIGHT: Noticeable Breeze / Single Base Triangle ---
        // Matches: Base Triangle display (windSpeed >= 20 km/h)
        else if (windSpeed >= 20.0f) {
            upgradeRisk(RiskLevelSlight);
        }

        // --- 14. IMMEDIATE: Imminent Rain ---
        if (immediateRain >= 0 && rainCurrent < 0.1f) {
            upgradeRisk(RiskLevelHigh);
            addHazard(HazardImminentRain);
        }
        // --- 15. IMMEDIATE: Imminent Snow ---
        if (immediateSnow >= 0 && snowCurrent < 0.1f) {
            upgradeRisk(RiskLevelHigh);
            addHazard(HazardImminentSnow);
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
