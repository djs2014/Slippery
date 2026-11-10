import Toybox.System;
import Toybox.Lang;
import Toybox.Graphics;
import Toybox.Time;

var MaxPresetItems = 5;
(:extendedCode)
public enum RiskPreset {
    PresetVeryCautious = 0,
    PresetCautious = 1,
    PresetNormal = 2,
    PresetSport = 3,
    PresetTough = 4,
}

(:extendedCode)
function getRiskPresetText(value as RiskPreset) as String {
    switch (value) {
        case PresetVeryCautious:
            return "Very Cautious";
        case PresetCautious:
            return "Cautious";
        case PresetNormal:
            return "Normal";
        case PresetSport:
            return "Sport";
        case PresetTough:
            return "Tough";
        default:
            return "--";
    }
}

(:extendedCode)
public class RiskConfig {
    public var iceT as Float = 3.0f;
    public var threshRain as Float = 1.0f;
    public var threshSnow as Float = 1.0f;
    public var threshWind as Float = 1.0f;
    public var threshGustRatio as Float = 1.0f;

    public function initialize(preset as RiskPreset) {
        switch (preset) {
            case PresetVeryCautious:
                iceT = 4.0f; // Highly conservative ice buffer
                threshRain = 0.3f; // Extremely low tolerance for rain
                threshSnow = 0.3f; // Warns at slightest trace of snow
                threshWind = 0.7f; // Triggers wind warnings early
                threshGustRatio = 0.8f;
                break;
            case PresetCautious:
                iceT = 3.5f;
                threshRain = 0.5f;
                threshSnow = 0.5f;
                threshWind = 0.8f;
                threshGustRatio = 0.9f;
                break;
            case PresetSport:
                iceT = 1.5f; // Tighter ice window
                threshRain = 1.25f; // Slightly higher precipitation requirement
                threshSnow = 1.25f;
                threshWind = 1.1f; // Ignores minor breezes
                threshGustRatio = 1.05f;
                break;
            case PresetTough:
                iceT = 1.0f; // Only warn right at/below freezing
                threshRain = 1.75f; // High rain threshold before triggering High/Critical
                threshSnow = 1.75f;
                threshWind = 1.3f; // High wind tolerance
                threshGustRatio = 1.15f;
                break;
            case PresetNormal:
            default:
                iceT = 2.5f;
                threshRain = 1.0f;
                threshSnow = 1.0f;
                threshWind = 1.0f;
                threshGustRatio = 1.0f;
                break;
        }
    }
}

(:extendedCode)
public class RiskCalculator {
    static var _riskOnly as Boolean = false;
    static var _riskLevel as RiskLevel = RiskLevelNoData;
    static var _hazards = [] as Array<WeatherHazard>;
    static var _advice = [] as Array<WeatherAdvice>;
    static var _hasIceHazard as Boolean = false;

    // Active configuration instance (defaults to Normal)
    static var _config as RiskConfig = new RiskConfig(PresetNormal);

    public static function setConfig(config as RiskConfig) as Void {
        _config = config;
    }

    public static function setPreset(preset as RiskPreset) as Void {
        _config = new RiskConfig(preset);
    }

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

    public static function hasIceHazard() as Boolean {
        return _hasIceHazard;
    }

    private static function reset() as Void {
        _riskLevel = RiskLevelSafe;
        _hazards = [];
        _advice = [];
        _hasIceHazard = false;
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
        snowCurrent as Float,
        upcomingRainAndShower as Float
    ) as RiskLevel {
        reset();

        // --- Configurable Thresholds scaling from multipliers ---
        var RAIN_THRESHOLD = 0.1f * _config.threshRain;
        var SNOW_THRESHOLD = 0.1f * _config.threshSnow;
        var ICE_T = _config.iceT;

        // --- 1. CRITICAL: Black Ice & Freezing Wet Asphalt ---[cite: 1]
        if (
            (surfaceTemp <= ICE_T || airTemp <= ICE_T * 0.5f + 0.5f) &&
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

        // --- 2. CRITICAL: Hoarfrost / Freezing Fog ---[cite: 1]
        if (surfaceTemp <= ICE_T && surfaceDewSpread <= 2.0 && humidity >= 80) {
            upgradeRisk(RiskLevelCritical);
            addHazard(HazardRoadSurfaceFrost);
            addAdvice(AdviceWatchOutForShadedAreasBridgesTreeLinedRoads);
            addAdvice(AdviceAvoidSuddenBraking);
        }

        // --- 3. HIGH: Bridge Deck Freeze ---[cite: 1]
        if (
            airTemp >= ICE_T - 4.0f &&
            airTemp <= ICE_T + 0.5f &&
            (runningRainAndShower12h >= RAIN_THRESHOLD ||
                humidity > 88 ||
                runningSnow12h >= SNOW_THRESHOLD)
        ) {
            upgradeRisk(RiskLevelHigh);
            addHazard(HazardIceOnBridges);
            addAdvice(AdviceWatchOutForShadedAreasBridgesTreeLinedRoads);
        }

        // --- 4. HIGH: Snow / Slush Accumulation ---[cite: 1]
        if (
            runningSnow12h >= SNOW_THRESHOLD &&
            (surfaceTemp <= ICE_T - 3.0f || airTemp <= ICE_T - 1.5f)
        ) {
            upgradeRisk(RiskLevelHigh);
            addHazard(HazardSnowOrSlushAccumulation);
            addAdvice(AdviceLossOfTractionInTurns);
            addAdvice(AdviceTreadPatternRequired);
        }

        // --- 5. RAIN ---[cite: 1]
        if (rainAndShowerCurrent >= 15.0f * _config.threshRain) {
            upgradeRisk(RiskLevelCritical);
            addHazard(HazardHeavyRainHydroplaning);
            addAdvice(AdviceReduceSpeedAndIncreaseGripMargin);
            addAdvice(AdviceIncreaseBreakingDistance);
        } else if (rainAndShowerCurrent >= 7.5f * _config.threshRain) {
            upgradeRisk(RiskLevelHigh);
            addHazard(HazardHeavyRainHydroplaning);
            addAdvice(AdviceIncreaseBreakingDistance);
            addAdvice(AdviceReduceSpeedAndIncreaseGripMargin);
        } else if (
            (season == SeasonSummer || season == SeasonSpring) &&
            rainAndShowerCurrent >= 0.1f * _config.threshRain &&
            rainAndShowerCurrent < 2.5f * _config.threshRain &&
            runningDryStreak >= 10
        ) {
            upgradeRisk(RiskLevelModerate);
            addHazard(HazardFirstRainReleasingDirtOils);
            addAdvice(AdviceAsphaltSlippery);
            addAdvice(AdviceTractionImprovesAfterHeavierRain);
        } else if (rainAndShowerCurrent >= 2.5f * _config.threshRain) {
            upgradeRisk(RiskLevelModerate);
            addHazard(HazardWetAsphaltSurface);
            addAdvice(AdviceIncreaseBreakingDistance);
            addAdvice(AdviceReduceCorneringLeanAngle);
        } else if (rainAndShowerCurrent >= 0.2f * _config.threshRain) {
            upgradeRisk(RiskLevelSlight);
            addHazard(HazardWetAsphaltSurface);
            addAdvice(AdviceIncreaseBreakingDistance);
        }

        // --- 6. MODERATE: Autumn Wet Leaves ---[cite: 1]
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

        // --- 7. SLIGHT: Dew Condensation ---[cite: 1]
        if (surfaceTemp > 0.0 && humidity > 90 && surfaceDewSpread <= 1.0) {
            upgradeRisk(RiskLevelSlight);
            addHazard(HazardWetAsphaltSurface);
            addAdvice(AdviceWatchOutForShadedAreasBridgesTreeLinedRoads);
            addAdvice(AdviceReduceCorneringLeanAngle);
        }

        // --- GUST RATIO CALCULATION ---[cite: 1]
        var gustRatio = windSpeed > 1.0f ? windGust / windSpeed : 1.0f;
        var wLimit = _config.threshWind;
        var gRatioLimit = _config.threshGustRatio;

        // --- 8. CRITICAL: Gale-Force Winds or Extreme Gusts ---[cite: 1]
        if (
            windSpeed >= 45.0f * wLimit ||
            windGust >= 60.0f * wLimit ||
            (windSpeed >= 35.0f * wLimit && gustRatio >= 1.7f * gRatioLimit)
        ) {
            upgradeRisk(RiskLevelCritical);
            addHazard(HazardGaleForceWinds);
            addAdvice(AdviceBewareOfOpenFieldsAndBridges);
            addAdvice(AdviceHoldHandlebarsFirmly);
            addAdvice(AdviceConsiderLowerProfileWheels);
        }
        // --- 9. HIGH: Strong Crosswinds / Heavy Gusts ---[cite: 1]
        else if (
            windSpeed >= 35.0f * wLimit ||
            windGust >= 45.0f * wLimit ||
            (windSpeed >= 25.0f * wLimit && gustRatio >= 1.5f * gRatioLimit)
        ) {
            upgradeRisk(RiskLevelHigh);
            addHazard(HazardStrongCrosswinds);
            addAdvice(AdviceBewareOfOpenFieldsAndBridges);
            addAdvice(AdviceHoldHandlebarsFirmly);
        }
        // --- 10. MODERATE: Moderate Winds / Gust Spikes ---[cite: 1]
        else if (
            windSpeed >= 25.0f * wLimit ||
            windGust >= 35.0f * wLimit ||
            (windSpeed >= 18.0f * wLimit && gustRatio >= 1.3f * gRatioLimit)
        ) {
            upgradeRisk(RiskLevelModerate);
            addHazard(HazardStrongCrosswinds);
            addAdvice(AdviceHoldHandlebarsFirmly);
        }
        // --- 11. SLIGHT: Noticeable Breeze ---[cite: 1]
        else if (windSpeed >= 20.0f * wLimit) {
            upgradeRisk(RiskLevelSlight);
            addHazard(HazardStrongCrosswinds);
            addAdvice(AdviceHoldHandlebarsFirmly);
        }

        // --- 12. IMMEDIATE: Imminent Rain ---[cite: 1]
        if (
            immediateRainAndShower >= 0 &&
            rainAndShowerCurrent < RAIN_THRESHOLD
        ) {
            if (upcomingRainAndShower >= 2.5f * _config.threshRain) {
                upgradeRisk(RiskLevelHigh);
            } else {
                upgradeRisk(RiskLevelModerate);
            }
            addHazard(HazardImminentRain);
        }

        // --- 13. IMMEDIATE: Imminent Snow ---[cite: 1]
        if (immediateSnow >= 0 && snowCurrent < SNOW_THRESHOLD) {
            upgradeRisk(RiskLevelHigh);
            addHazard(HazardImminentSnow);
        }

        return _riskLevel;
    }

    // --- HELPER UTILITIES ---

    static function upgradeRisk(newLevel as RiskLevel) as Void {
        if (newLevel > _riskLevel) {
            _riskLevel = newLevel;
        }
    }

    static function addHazard(hazard as WeatherHazard) as Void {
        if (
            hazard == HazardBlackIceFreezingWetRoad ||
            hazard == HazardRoadSurfaceFrost ||
            hazard == HazardIceOnBridges ||
            hazard == HazardSnowOrSlushAccumulation
        ) {
            _hasIceHazard = true;
        }
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
