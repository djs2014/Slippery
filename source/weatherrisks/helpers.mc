import Toybox.System;
import Toybox.Lang;
import Toybox.Graphics;
import Toybox.Time;

class RiskAssessment {
    var riskLevel as RiskLevel = RiskLevelNoData;
    var hazards = [] as Array<WeatherHazard>;
    var advice = [] as Array<WeatherAdvice>;
    var hourlyRisksLevels = [] as Array<RiskLevel>;

    public function toString() as String {
        return (
            "RiskAssessment{" +
            "riskLevel=" +
            riskLevel +
            ", hazards=" +
            hazards +
            ", advice=" +
            advice +
            ", hourlyRisksLevels=" +
            hourlyRisksLevels +
            "}"
        );
    }
}

enum WeatherHazard {
    HazardBlackIceFreezingWetRoad,
    HazardSnowOrSlushAccumulation,
    HazardRoadSurfaceFrost,
    HazardWetLeafCoverage,
    HazardFirstRainReleasingDirtOils,
    HazardIceOnBridges,
    HazardWetAsphaltSurface,
    HazardHeavyRainHydroplaning,
    HazardStrongCrosswinds,
    HazardGaleForceWinds,
    HazardImminentSnow,
    HazardImminentRain,
}

function getHazardString(hazard as WeatherHazard) as Lang.String {
    if (hazard == HazardBlackIceFreezingWetRoad) {
        return "Black Ice / Freezing Wet Road";
    } else if (hazard == HazardSnowOrSlushAccumulation) {
        return "Snow Or Slush Accumulation";
    } else if (hazard == HazardRoadSurfaceFrost) {
        return "Road Surface Frost";
    } else if (hazard == HazardWetLeafCoverage) {
        return "Wet Leaf Coverage";
    } else if (hazard == HazardFirstRainReleasingDirtOils) {
        return "First Rain Releasing Dirt / Oils";
    } else if (hazard == HazardIceOnBridges) {
        return "Ice On Bridges";
    } else if (hazard == HazardWetAsphaltSurface) {
        return "Wet Asphalt Surface";
    } else if (hazard == HazardHeavyRainHydroplaning) {
        return "Heavy Rain / Hydroplaning";
    } else if (hazard == HazardStrongCrosswinds) {
        return "Strong Crosswinds";
    } else if (hazard == HazardGaleForceWinds) {
        return "Gale Force Winds";
    } else if (hazard == HazardImminentSnow) {
        return "Imminent Snow";
    } else if (hazard == HazardImminentRain) {
        return "Imminent Rain";
    }
    return "";
}

function getShortHazardString(hazard as WeatherHazard) as Lang.String {
    if (hazard == HazardBlackIceFreezingWetRoad) {
        return "Black Ice";
    } else if (hazard == HazardSnowOrSlushAccumulation) {
        return "Snow/Slush";
    } else if (hazard == HazardRoadSurfaceFrost) {
        return "Frost";
    } else if (hazard == HazardWetLeafCoverage) {
        return "Wet Leaves";
    } else if (hazard == HazardFirstRainReleasingDirtOils) {
        return "First Rain";
    } else if (hazard == HazardIceOnBridges) {
        return "Ice on Bridges";
    } else if (hazard == HazardWetAsphaltSurface) {
        return "Wet Asphalt";
    } else if (hazard == HazardHeavyRainHydroplaning) {
        return "Heavy Rain";
    } else if (hazard == HazardStrongCrosswinds) {
        return "Strong Crosswinds";
    } else if (hazard == HazardGaleForceWinds) {
        return "Gale Force Winds";
    } else if (hazard == HazardImminentSnow) {
        return "Imminent Snow";
    } else if (hazard == HazardImminentRain) {
        return "Imminent Rain";
    }
    return "";
}

enum WeatherAdvice {
    AdviceAvoidRiding,
    AdviceLowerTirePressure,
    AdviceLossOfTractionInTurns,
    AdviceTreadPatternRequired,
    AdviceWatchOutForShadedAreasBridgesTreeLinedRoads,
    AdviceAvoidSuddenBraking,
    AdviceExtremeSlipHazardOnCorneringLines,
    AdviceAsphaltSlippery,
    AdviceTractionImprovesAfterHeavierRain,
    AdviceIncreaseBreakingDistance,
    AdviceReduceCorneringLeanAngle,
    AdviceReduceSpeedAndIncreaseGripMargin,
    AdviceHoldHandlebarsFirmly,
    AdviceBewareOfOpenFieldsAndBridges,
    AdviceConsiderLowerProfileWheels,
    AdviceRainStartingNow,
    AdviceRainExpectedShortly,
    AdviceSnowStartingNow,
    AdviceSnowExpectedShortly,
}

function getAdviceString(advice as WeatherAdvice) as Lang.String {
    if (advice == AdviceAvoidRiding) {
        return "Avoid Riding";
    } else if (advice == AdviceLowerTirePressure) {
        return "Lower Tire Pressure";
    } else if (advice == AdviceLossOfTractionInTurns) {
        return "Loss Of Traction In Turns";
    } else if (advice == AdviceTreadPatternRequired) {
        return "Tread Pattern Required";
    } else if (advice == AdviceWatchOutForShadedAreasBridgesTreeLinedRoads) {
        return "Watch Out For Shaded Areas, Bridges, Tree-Lined Roads";
    } else if (advice == AdviceAvoidSuddenBraking) {
        return "Avoid Sudden Braking";
    } else if (advice == AdviceExtremeSlipHazardOnCorneringLines) {
        return "Extreme Slip Hazard On Cornering Lines";
    } else if (advice == AdviceAsphaltSlippery) {
        return "Aspalt Slippery";
    } else if (advice == AdviceTractionImprovesAfterHeavierRain) {
        return "Traction Improves After Heavier Rain";
    } else if (advice == AdviceIncreaseBreakingDistance) {
        return "Increase Breaking Distance";
    } else if (advice == AdviceReduceCorneringLeanAngle) {
        return "Reduce Cornering Lean Angle";
    } else if (advice == AdviceReduceSpeedAndIncreaseGripMargin) {
        return "Reduce Speed And Increase Grip Margin";
    } else if (advice == AdviceHoldHandlebarsFirmly) {
        return "Hold Handlebars Firmly";
    } else if (advice == AdviceBewareOfOpenFieldsAndBridges) {
        return "Beware Of Open Fields And Bridges";
    } else if (advice == AdviceConsiderLowerProfileWheels) {
        return "Consider Lower Profile Wheels";
    } else if (advice == AdviceRainStartingNow) {
        return "Rain Starting Now";
    } else if (advice == AdviceRainExpectedShortly) {
        return "Rain in"; // x min
    } else if (advice == AdviceSnowStartingNow) {
        return "Snow Starting Now";
    } else if (advice == AdviceSnowExpectedShortly) {
        return "Snow in"; // x min
    }
    return "";
}
enum MeteorologicalSeason {
    SeasonNoData,
    SeasonSpring,
    SeasonSummer,
    SeasonAutumn,
    SeasonWinter,
}

function getSeasonString(season as MeteorologicalSeason) as Lang.String {
    if (season == SeasonNoData) {
        return "No Data";
    } else if (season == SeasonSpring) {
        return "Spring";
    } else if (season == SeasonSummer) {
        return "Summer";
    } else if (season == SeasonAutumn) {
        return "Autumn";
    } else if (season == SeasonWinter) {
        return "Winter";
    }
    return "";
}

function getMeteorologicalSeason(
    lat as Float,
    date as Moment
) as MeteorologicalSeason {
    var info = Gregorian.utcInfo(date, Time.FORMAT_SHORT);
    var month = info.month; // month 1 = January
    if (lat >= 0) {
        // Northern Hemisphere
        if (month >= 3 && month <= 5) {
            return SeasonSpring;
        } else if (month >= 6 && month <= 8) {
            return SeasonSummer;
        } else if (month >= 9 && month <= 11) {
            return SeasonAutumn;
        } else {
            return SeasonWinter;
        }
    } else {
        // Southern Hemisphere
        if (month >= 3 && month <= 5) {
            return SeasonAutumn;
        } else if (month >= 6 && month <= 8) {
            return SeasonWinter;
        } else if (month >= 9 && month <= 11) {
            return SeasonSpring;
        } else {
            return SeasonSummer;
        }
    }
}

enum RiskLevel {
    RiskLevelNoData,
    RiskLevelSafe,
    RiskLevelSlight,
    RiskLevelModerate,
    RiskLevelHigh,
    RiskLevelCritical,
}

function getRiskLevelString(riskLevel as RiskLevel) as Lang.String {
    if (riskLevel == RiskLevelNoData) {
        return "No Data";
    } else if (riskLevel == RiskLevelSafe) {
        return "Safe";
    } else if (riskLevel == RiskLevelSlight) {
        return "Slight";
    } else if (riskLevel == RiskLevelModerate) {
        return "Moderate";
    } else if (riskLevel == RiskLevelHigh) {
        return "High";
    } else if (riskLevel == RiskLevelCritical) {
        return "Critical";
    }
    return "";
}
function getShortRiskLabel(riskLevel as RiskLevel) as Lang.String {
    if (riskLevel == RiskLevelNoData) {
        return "-";
    } else if (riskLevel == RiskLevelSafe) {
        return "Ok";
    } else if (riskLevel == RiskLevelSlight) {
        return "Low";
    } else if (riskLevel == RiskLevelModerate) {
        return "Mod";
    } else if (riskLevel == RiskLevelHigh) {
        return "Hig";
    } else if (riskLevel == RiskLevelCritical) {
        return "Crt";
    }
    return "";
}

function getRiskColor(
    riskLevel as RiskLevel,
    isDark as Boolean
) as Graphics.ColorType {
    if (riskLevel == RiskLevelNoData || riskLevel == RiskLevelSafe) {
        // Dark Gray / Light Gray
        return isDark ? 0x404040 : 0xefefef;
    } else if (riskLevel == RiskLevelSlight) {
        // Yellow/Olive
        return isDark ? 0xffff00 : 0x808000;
    } else if (riskLevel == RiskLevelModerate) {
        // Orange / Dark Orange
        return isDark ? 0xffa500 : 0xff8c00;
    } else if (riskLevel == RiskLevelHigh) {
        // Orange-Red / Red
        return isDark ? 0xff4500 : 0xff0000;
    } else if (riskLevel == RiskLevelCritical) {
        // Red / Dark Red
        return isDark ? 0xff0000 : 0x8b0000;
    }
    return Graphics.COLOR_TRANSPARENT;
}

function getRiskTextColor(
    riskLevel as RiskLevel,
    isDark as Boolean
) as Graphics.ColorType {
    if (riskLevel == RiskLevelNoData || riskLevel == RiskLevelSafe) {
        // Transparent fill uses default theme text color
        return isDark ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
    } else if (riskLevel == RiskLevelSlight) {
        // Yellow/Olive backgrounds require dark text for legibility
        return Graphics.COLOR_BLACK;
    } else if (riskLevel == RiskLevelModerate) {
        // Orange/Dark Orange backgrounds work best with dark text
        return Graphics.COLOR_BLACK;
    } else if (riskLevel == RiskLevelHigh) {
        // Orange-Red / Red fills require bright white text
        return Graphics.COLOR_WHITE;
    } else if (riskLevel == RiskLevelCritical) {
        // Red / Dark Red fills require bright white text
        return Graphics.COLOR_WHITE;
    }

    return isDark ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
}

function getPrecipitationAlertMessage(
    minutesUntilRain as Number,
    minutesUntilSnow as Number,
    short as Boolean
) as String {
    if (
        (minutesUntilRain < 0 || minutesUntilRain > 45) &&
        (minutesUntilSnow < 0 || minutesUntilSnow > 45)
    ) {
        return "";
    }

    var minutesUntil = -1;
    var precipType = 0; // 0 = None, 1 = Rain, 2 = Snow, 3 = Freezing Rain

    var typeStr = "RAIN";
    if (minutesUntilRain >= 0 && minutesUntilRain <= 45) {
        precipType = 1;
    }
    if (minutesUntilSnow >= 0 && minutesUntilSnow <= 45) {
        if (precipType == 1) {
            // Rain is already set, so this will be a mix of rain and snow (sleet)
            precipType = 3;
        } else {
            precipType = 2;
        }
    }
    if (precipType == 1) {
        minutesUntil = minutesUntilRain;
    } else if (precipType == 2) {
        minutesUntil = minutesUntilSnow;
    } else if (precipType == 3) {
        minutesUntil = min(minutesUntilRain, minutesUntilSnow);
    }

    if (precipType == 2) {
        typeStr = "SNOW";
    } else if (precipType == 3) {
        typeStr = "SLEET";
    }

    if (short) {
        if (minutesUntil == 0) {
            return typeStr;
        } else {
            return typeStr + "." + minutesUntil;
        }
    }
    if (minutesUntil == 0) {
        return typeStr + " STARTING";
    } else {
        return typeStr + " IN " + minutesUntil + " MIN";
    }
}
var MaxForecastHourItems = 4;
enum ShowForecastHour {
    ForecastHourNone,
    ForecastHourRelative,
    ForecastHourAbsolute,
}

function getShowForecastHourText(hourOption as ShowForecastHour) as String {
    switch (hourOption) {
        case ForecastHourNone:
            return "None";
        case ForecastHourRelative:
            return "Relative";
        case ForecastHourAbsolute:
            return "Absolute";
    }
    return "-";
}

function calculateGustSeverity(
    windSpeed as Float?,
    windGust as Float?
) as Number {
    if (windSpeed == null) {
        windSpeed = 0;
    }
    if (windGust == null) {
        windGust = 0;
    }
    var gustRatio = windSpeed > 1.0f ? windGust / windSpeed : 1.0f;
    var level = 0;

    if (windGust >= 45.0f || gustRatio >= 1.7f) {
        level = 3;
    } else if (windGust >= 35.0f || gustRatio >= 1.5f) {
        level = 2;
    } else if (windGust >= 25.0f || gustRatio >= 1.3f) {
        level = 1;
    }
    return level;
}

function getGustSeverityColor(level as Number, isDark as Boolean) as ColorType {
    switch (level) {
        case 0:
            return isDark ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        case 1:
            return isDark ? Graphics.COLOR_YELLOW : Graphics.COLOR_YELLOW;
        case 2:
            return isDark ? Graphics.COLOR_ORANGE : Graphics.COLOR_ORANGE;
        case 3:
            return isDark ? Graphics.COLOR_RED : Graphics.COLOR_RED;
    }
    return isDark ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
}

// Returns dynamic metric color scaling from neutral (White/Black) to Red/Magenta based on wind speed (km/h)
public function getWindSpeedColor(
    windSpeed as Float,
    isDark as Boolean
) as Graphics.ColorType {
    if (windSpeed < 10.0f) {
        // Calm / Light breeze: Standard high-contrast neutral
        return isDark ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
    } else if (windSpeed < 20.0f) {
        // Moderate breeze (10-19 km/h): Subtle/Safe Green
        return isDark ? Graphics.COLOR_GREEN : Graphics.COLOR_DK_GREEN;
    } else if (windSpeed < 30.0f) {
        // Stronger breeze (20-29 km/h): Caution Yellow
        return Graphics.COLOR_YELLOW;
    } else if (windSpeed < 40.0f) {
        // High wind / Headwind challenge (30-39 km/h): Orange
        return Graphics.COLOR_ORANGE;
    } else if (windSpeed < 50.0f) {
        // Strong gale / High risk (40-49 km/h): Alert Red
        return Graphics.COLOR_RED;
    } else {
        // Extreme gale / Dangerous (50+ km/h): Severe Magenta/Purple
        return Graphics.COLOR_PURPLE;
    }
}


/*
import Toybox.Graphics;
import Toybox.Lang;

class WindColorMapper {

    // Returns dynamic metric color scaling from neutral to Red/Magenta based on gust speed (km/h)
    public static function getWindGustColor(gustSpeed as Float, isDark as Boolean) as Graphics.ColorType {
        if (gustSpeed < 15.0f) {
            // Calm / Minor gusts: Standard high-contrast neutral
            return isDark ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        } else if (gustSpeed < 25.0f) {
            // Mild gusts (15-24 km/h): Noticeable but safe
            return isDark ? Graphics.COLOR_GREEN : Graphics.COLOR_DK_GREEN;
        } else if (gustSpeed < 35.0f) {
            // Moderate gusts (25-34 km/h): Caution required on deep rims
            return Graphics.COLOR_YELLOW;
        } else if (gustSpeed < 45.0f) {
            // Strong gusts (35-44 km/h): Handling hazard / Orange warning
            return Graphics.COLOR_ORANGE;
        } else if (gustSpeed < 55.0f) {
            // Severe gusts (45-54 km/h): High risk of being blown sideways / Red
            return Graphics.COLOR_RED;
        } else {
            // Extreme gusts (55+ km/h): Dangerous control conditions / Purple
            return Graphics.COLOR_PURPLE;
        }
    }
}
*/