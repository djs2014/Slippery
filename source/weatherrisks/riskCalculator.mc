import Toybox.System;
import Toybox.Lang;
import Toybox.Graphics;
import Toybox.Time;
(:extendedCode) 
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
        rainAndShowerCurrent as Float,
        runningRainAndShower12h as Float,
        runningSnow12h as Float,
        runningDryStreak as Number,
        season as MeteorologicalSeason,
        windSpeed as Float,
        windGust as Float,
        immediateRainAndShower as Number,
        immediateSnow as Number,
        surfaceDewSpread as Float,
        snowCurrent as Float
    ) as RiskLevel {
        reset();

        // Shared meaningful-precipitation thresholds, used by every rule so
        // live assessment and forecast projection agree.
        // Rain/showers are mm/h, snowfall is cm/h (Open-Meteo unit);
        // 0.1 cm snow ~= 1 mm snow ~= 0.1 mm rain water equivalent.
        var RAIN_THRESHOLD = 0.1f;
        var SNOW_THRESHOLD = 0.1f;

        // --- 1. CRITICAL: Black Ice & Freezing Wet Asphalt ---
        if (
            (surfaceTemp <= 0.0 || airTemp <= 0.5) &&
            (runningRainAndShower12h >= RAIN_THRESHOLD ||
                rainAndShowerCurrent >= RAIN_THRESHOLD ||
                runningSnow12h >= SNOW_THRESHOLD ||
                snowCurrent >= SNOW_THRESHOLD)
        ) {
            upgradeRisk(RiskLevelCritical);
            addHazard(HazardBlackIceFreezingWetRoad);
            addAdvice(AdviceAvoidRiding);
            addAdvice(AdviceLowerTirePressure);
        }

        // --- 2. CRITICAL: Hoarfrost / Freezing Fog ---
        // Humid air is required: dry cold alone cannot deposit frost.
        if (
            surfaceTemp <= 0.0 &&
            surfaceDewSpread <= 2.0 &&
            humidity >= 80
        ) {
            upgradeRisk(RiskLevelCritical);
            addHazard(HazardRoadSurfaceFrost);
            addAdvice(AdviceWatchOutForShadedAreasBridgesTreeLinedRoads);
            addAdvice(AdviceAvoidSuddenBraking);
        }

        // --- 3. HIGH: Bridge Deck Freeze ---
        if (
            airTemp >= 0.0 &&
            airTemp <= 2.5 &&
            (runningRainAndShower12h >= RAIN_THRESHOLD ||
                humidity > 88 ||
                runningSnow12h >= SNOW_THRESHOLD)
        ) {
            upgradeRisk(RiskLevelHigh);
            addHazard(HazardIceOnBridges);
            addAdvice(AdviceWatchOutForShadedAreasBridgesTreeLinedRoads);
        }

        // --- 4. HIGH: Snow / Slush Accumulation ---
        // Only when temperatures allow snow to settle; ignores trace amounts
        // and warm conditions where past snow has melted.
        // (runningSnow12h already includes the current hour.)
        if (
            runningSnow12h >= SNOW_THRESHOLD &&
            (surfaceTemp <= 1.0 || airTemp <= 1.5)
        ) {
            upgradeRisk(RiskLevelHigh);
            addHazard(HazardSnowOrSlushAccumulation);
            addAdvice(AdviceLossOfTractionInTurns);
            addAdvice(AdviceTreadPatternRequired);
        }

        // --- 5. RAIN ---
        // --- CRITICAL: Torrential / Violent Downpour ---
        if (rainAndShowerCurrent >= 15.0f) {
            upgradeRisk(RiskLevelCritical);
            addHazard(HazardHeavyRainHydroplaning);
            addAdvice(AdviceReduceSpeedAndIncreaseGripMargin);
            addAdvice(AdviceIncreaseBreakingDistance);
        }
        // --- HIGH: Heavy Rain & Standing Water ---
        else if (rainAndShowerCurrent >= 7.5f) {
            upgradeRisk(RiskLevelHigh);
            addHazard(HazardHeavyRainHydroplaning);
            addAdvice(AdviceIncreaseBreakingDistance);
            addAdvice(AdviceReduceSpeedAndIncreaseGripMargin);
        }
        // --- MODERATE: Summer/Spring First Rain ("Oil Slick") ---
        // Light rain (0.1 - 2.5 mm/h) releases oil film without flushing it away
        else if (
            (season == SeasonSummer || season == SeasonSpring) &&
            rainAndShowerCurrent >= 0.1f &&
            rainAndShowerCurrent < 2.5f &&
            runningDryStreak >= 10 // Dry hours preceding rain
        ) {
            upgradeRisk(RiskLevelModerate);
            addHazard(HazardFirstRainReleasingDirtOils);
            addAdvice(AdviceAsphaltSlippery);
            addAdvice(AdviceTractionImprovesAfterHeavierRain);
        }
        // --- MODERATE: Steady Rain ---
        else if (rainAndShowerCurrent >= 2.5f) {
            upgradeRisk(RiskLevelModerate);
            addHazard(HazardWetAsphaltSurface);
            addAdvice(AdviceIncreaseBreakingDistance);
            addAdvice(AdviceReduceCorneringLeanAngle);
        }
        // --- SLIGHT: Light Rain / Drizzle ---
        else if (rainAndShowerCurrent >= 0.2f) {
            upgradeRisk(RiskLevelSlight);
            addHazard(HazardWetAsphaltSurface);
            addAdvice(AdviceIncreaseBreakingDistance);
        }

        // --- 6. MODERATE: Autumn Wet Leaves ---
        // Requires actual wetness. Damp air alone is covered by the dew rule (7).
        if (
            season == SeasonAutumn &&
            (runningRainAndShower12h >= RAIN_THRESHOLD ||
                runningSnow12h >= SNOW_THRESHOLD ||
                rainAndShowerCurrent >= RAIN_THRESHOLD ||
                snowCurrent >= SNOW_THRESHOLD)
        ) {
            upgradeRisk(RiskLevelModerate);
            addHazard(HazardWetLeafCoverage);
            addAdvice(AdviceExtremeSlipHazardOnCorneringLines);
            addAdvice(AdviceReduceCorneringLeanAngle);
        }

        // --- 7. SLIGHT: Dew Condensation ("Sweating Road") ---
        if (surfaceTemp > 0.0 && humidity > 90 && surfaceDewSpread <= 1.0) {
            upgradeRisk(RiskLevelSlight);
            addHazard(HazardWetAsphaltSurface);
            addAdvice(AdviceWatchOutForShadedAreasBridgesTreeLinedRoads);
            addAdvice(AdviceReduceCorneringLeanAngle);
        }

        // --- GUST RATIO CALCULATION ---
        var gustRatio = windSpeed > 1.0f ? windGust / windSpeed : 1.0f;

        // --- 8. CRITICAL: Gale-Force Winds or Extreme Gusts ---
        // Absolute gust/speed thresholds are deliberately one tier stricter than
        // the sparkline gust bars (which warn early at 45/35/25): the bars show
        // exposure, this rule upgrades the ride risk.
        // Ratio spikes need a base-wind floor so that e.g. 2 -> 4 km/h gusts
        // (ratio 2.0) at near-calm conditions do not trigger Critical.
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
        // --- 9. HIGH: Strong Crosswinds / Heavy Gusts ---
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
        // --- 10. MODERATE: Moderate Winds / Gust Spikes ---
        else if (
            windSpeed >= 25.0f ||
            windGust >= 35.0f ||
            (windSpeed >= 18.0f && gustRatio >= 1.3f)
        ) {
            upgradeRisk(RiskLevelModerate);
            addHazard(HazardStrongCrosswinds);
            addAdvice(AdviceHoldHandlebarsFirmly);
        }
        // --- 11. SLIGHT: Noticeable Breeze ---
        // Names the cause so the UI never shows an unexplained Slight level.
        else if (windSpeed >= 20.0f) {
            upgradeRisk(RiskLevelSlight);
            addHazard(HazardStrongCrosswinds);
            addAdvice(AdviceHoldHandlebarsFirmly);
        }

        // --- 12. IMMEDIATE: Imminent Rain ---
        // -1 no immediate precipitation, 0 active now, >0 minutes until start.
        // Suppressed while it is already raining (covered by the rain ladder).
        if (
            immediateRainAndShower >= 0 &&
            rainAndShowerCurrent < RAIN_THRESHOLD
        ) {
            upgradeRisk(RiskLevelHigh);
            addHazard(HazardImminentRain);
            if (immediateRainAndShower == 0) {
                addAdvice(AdviceRainStartingNow);
            } else {
                addAdvice(AdviceRainExpectedShortly);
            }
        }
        // --- 13. IMMEDIATE: Imminent Snow ---
        if (immediateSnow >= 0 && snowCurrent < SNOW_THRESHOLD) {
            upgradeRisk(RiskLevelHigh);
            addHazard(HazardImminentSnow);
            if (immediateSnow == 0) {
                addAdvice(AdviceSnowStartingNow);
            } else {
                addAdvice(AdviceSnowExpectedShortly);
            }
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
