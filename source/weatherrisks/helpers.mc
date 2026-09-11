import Toybox.System;
import Toybox.Lang;
import Toybox.Graphics;
import Toybox.Time;

class RiskAssessment {
    var riskLevel as RiskLevel= RiskLevelNoData;
    var hazards = [] as Array<WeatherHazard>;
    var advice = [] as Array<WeatherAdvice>;

    public function toString() as String {
        return (
            "RiskAssessment{" +
            "riskLevel=" +
            riskLevel +
            ", hazards=" +
            hazards +
            ", advice=" +
            advice +
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
        return "S";
    } else if (riskLevel == RiskLevelSlight) {
        return "Sl";
    } else if (riskLevel == RiskLevelModerate) {
        return "M";
    } else if (riskLevel == RiskLevelHigh) {
        return "H";
    } else if (riskLevel == RiskLevelCritical) {
        return "C";
    }
    return "";
}

function getRiskColor(
    riskLevel as RiskLevel,
    isDark as Boolean
) as Graphics.ColorType {
    if (riskLevel == RiskLevelNoData || riskLevel == RiskLevelSafe) {
        // Dark Gray / Light Gray
        return isDark ? 0x404040 : 0xd3d3d3;
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

function getPrecipitationAlertMessage(minutesUntilRain as Number, minutesUntilSnow as Number) as String {
    if ((minutesUntilRain < 0 || minutesUntilRain > 45)
    && (minutesUntilSnow < 0 || minutesUntilSnow > 45)) { return ""; }

    var minutesUntil = -1;
    var precipType = 0; // 0 = None, 1 = Rain, 2 = Snow, 3 = Freezing Rain

    var typeStr = "RAIN";
    var icon = "🌧️";
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
        icon = "❄️";
    } else if (precipType == 3) {
        typeStr = "SLEET";
        icon = "🌧️❄️";
    }

    if (minutesUntil == 0) {
        return icon + " " + typeStr + " STARTING NOW";
    } else {
        return icon + " " + typeStr + " IN " + minutesUntil + " MIN";
    }
}