import Toybox.System;
import Toybox.Lang;
import Toybox.Graphics;

class WeatherMetrics {
    var airTemp as Float = 0.0;
    var surfaceTemp as Float = 0.0;
    var dewPoint as Float = 0.0;
    var humidity as Number = 0;
    var rainCurrent as Float = 0.0;
    var precip12hSum as Float = 0.0;
    var snow12hSum as Float = 0.0;
    var dryStreak as Number = 0; // Length of the current dry streak in hours
    var currentSeason as MeteorologicalSeason = SeasonNoData;

    public function toString() as String {
        return (
            "WeatherMetrics{" +
            "airTemp=" +
            airTemp +
            ", surfaceTemp=" +
            surfaceTemp +
            ", dewPoint=" +
            dewPoint +
            ", humidity=" +
            humidity +
            ", rainCurrent=" +
            rainCurrent +
            ", precip12hSum=" +
            precip12hSum +
            ", snow12hSum=" +
            snow12hSum +
            ", dryStreak=" +
            dryStreak +
            ", currentSeason=" +
            currentSeason +
            "}"
        );
    }
}

import Toybox.Time;
import Toybox.Lang;

function parseOpenMeteoResponse(
    lat as Float,
    data as Dictionary?
) as WeatherMetrics? {
    if (data == null || !data.hasKey("hourly")) {
        return null;
    }

    var hourly = data.get("hourly") as Dictionary;
    var times = hourly.get("time") as Array<Number>?;

    if (times == null || times.size() == 0) {
        return null;
    }

    // Get current device UTC time in seconds
    var nowSec = Time.now().value();

    // Find index for current hour (or fallback to latest)
    var targetIdx = times.size() - 1;
    for (var i = 0; i < times.size(); i++) {
        if (times[i] >= nowSec) {
            targetIdx = i;
            break;
        }
    }
    System.println("Target index for current hour: " + targetIdx);
    // Get the current hour's index and corresponding time
    var currentHourTime = times[targetIdx];
    System.println("Current hour time in unixtime: " + currentHourTime);
    System.println(
        "Current hour time formatted: " + formatUnixTime(currentHourTime)
    );

    // Extract current metrics directly
    var metrics = new WeatherMetrics();

    var temps = hourly.get("temperature_2m") as Array<Float>;
    var surfTemps = hourly.get("surface_temperature") as Array<Float>;
    var dewPoints = hourly.get("dewpoint_2m") as Array<Float>;
    var humidities = hourly.get("relativehumidity_2m") as Array<Number>;
    var rains = hourly.get("rain") as Array<Float>;
    var precips = hourly.get("precipitation") as Array<Float>;
    var snows = hourly.get("snowfall") as Array<Float>;

    metrics.airTemp = temps[targetIdx];
    metrics.surfaceTemp = surfTemps[targetIdx];
    metrics.dewPoint = dewPoints[targetIdx];
    metrics.humidity = humidities[targetIdx];
    metrics.rainCurrent = rains[targetIdx];

    // Calculate 12-hour accumulated moisture lookback for slipperiness
    var startIdx = targetIdx - 12;
    if (startIdx < 0) {
        startIdx = 0;
    }

    var sumPrecip = 0.0;
    var sumSnow = 0.0;

    for (var j = startIdx; j <= targetIdx; j++) {
        if (precips != null && j < precips.size()) {
            sumPrecip += precips[j];
        }
        if (snows != null && j < snows.size()) {
            sumSnow += snows[j];
        }
    }

    metrics.precip12hSum = sumPrecip;
    metrics.snow12hSum = sumSnow;

    // Look back at dry streak length (for "first rain after dry spell" effect)
    var dryStreak = 0;
    for (var k = targetIdx; k >= 0; k--) {
        if (rains != null && k < rains.size() && rains[k] == 0.0) {
            dryStreak += 1;
        } else {
            break;
        }
    }
    metrics.dryStreak = dryStreak;

    metrics.currentSeason = getMeteorologicalSeason(lat, Time.now());

    return metrics;
}

class RiskAssessment {
    var riskLevel = RiskLevelNoData;
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

function calculateRiskAssessment(metrics as WeatherMetrics) as RiskAssessment {
    var assessment = new RiskAssessment();
    assessment.riskLevel = RiskLevelSafe; // Example logic, replace with actual calculation
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

    // --- HAZARD EVALUATION (Prioritized by risk severity) ---

    // 1. Black Ice & Freezing Wet Asphalt
    if ((surfaceTemp <= 0 || currentTemp <= 0.5) && recentPrecip > 0) {
        assessment.riskLevel = RiskLevelCritical;
        assessment.hazards.add(HazardBlackIceFreezingWetRoad);
        assessment.advice.add(AdviceAvoidRiding);
        assessment.advice.add(AdviceLowerTirePressure);
    }

    // 2. Active Snow or Accumulated Slush
    if (recentSnow > 0) {
        if (assessment.riskLevel != RiskLevelCritical) {
            assessment.riskLevel = RiskLevelHigh;
        }
        assessment.hazards.add(HazardSnowOrSlushAccumulation);
        assessment.advice.add(AdviceLossOfTractionInTurns);
        assessment.advice.add(AdviceTreadPatternRequired);
    }

    // 3. Hoarfrost / Freezing Fog (Asphalt temperature at or below freezing near dew point)
    if (surfaceTemp <= 0 && currentTemp - dewPoint < 2.0 && humidity > 85) {
        if (assessment.riskLevel != RiskLevelCritical) {
            assessment.riskLevel = RiskLevelHigh;
        }
        assessment.hazards.add(HazardRoadSurfaceFrost);
        assessment.advice.add(
            AdviceWatchOutForShadedAreasBridgesTreeLinedRoads
        );
    }

    // 4. Autumn Wet Leaves Hazard
    if (season == SeasonAutumn && (recentPrecip > 0 || humidity > 90)) {
        if (
            assessment.riskLevel != RiskLevelCritical &&
            assessment.riskLevel != RiskLevelHigh
        ) {
            assessment.riskLevel = RiskLevelModerate;
        }
        assessment.hazards.add(HazardWetLeafCoverage);
        assessment.advice.add(AdviceExtremeSlipHazardOnCorneringLines);
    }

    // 5. Summer/Spring First Rain ("Oil Slick" effect)
    if (
        (season == SeasonSummer || season == SeasonSpring) &&
        currentRain > 0 &&
        currentRain < 2.0 &&
        dryHoursBeforeRain >= 18
    ) {
        if (assessment.riskLevel == RiskLevelSafe) {
            assessment.riskLevel = RiskLevelModerate;
        }
        assessment.hazards.add(HazardFirstRainReleasingDirtOils);
        assessment.advice.add(AdviceAspaltSlippery);
        assessment.advice.add(AdviceTractionImprovesAfterHeavierRain);
    }

    // 6. General Wet Asphalt
    if (currentRain > 0.5 && assessment.riskLevel == RiskLevelSafe) {
        assessment.riskLevel = RiskLevelSlight;
        assessment.hazards.add(HazardWetAsphaltSurface);
        assessment.advice.add(AdviceIncreaseBreakingDistance);
        assessment.advice.add(AdviceReduceCorneringLeanAngle);
    }

    return assessment;
}

enum WeatherHazard {
    HazardBlackIceFreezingWetRoad,
    HazardSnowOrSlushAccumulation,
    HazardRoadSurfaceFrost,
    HazardWetLeafCoverage,
    HazardFirstRainReleasingDirtOils,
    HazardIceOnBridges,
    HazardWetAsphaltSurface,
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
    AdviceAspaltSlippery,
    AdviceTractionImprovesAfterHeavierRain,
    AdviceIncreaseBreakingDistance,
    AdviceReduceCorneringLeanAngle,
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
    } else if (advice == AdviceAspaltSlippery) {
        return "Aspalt Slippery";
    } else if (advice == AdviceTractionImprovesAfterHeavierRain) {
        return "Traction Improves After Heavier Rain";
    } else if (advice == AdviceIncreaseBreakingDistance) {
        return "Increase Breaking Distance";
    } else if (advice == AdviceReduceCorneringLeanAngle) {
        return "Reduce Cornering Lean Angle";
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

function getRiskColor(riskLevel as RiskLevel, isDark as Boolean) as Graphics.ColorType {
    if (riskLevel == RiskLevelNoData) {
        return Graphics.COLOR_TRANSPARENT;
    } else if (riskLevel == RiskLevelSafe) {
        return isDark ? 0x00ff00 : 0x008000;
    } else if (riskLevel == RiskLevelSlight) {
        return isDark ? 0xffff00 : 0x808000;
    } else if (riskLevel == RiskLevelModerate) {
        return isDark ? 0xffa500 : 0xff8c00;
    } else if (riskLevel == RiskLevelHigh) {
        return isDark ? 0xff4500 : 0xff0000;
    } else if (riskLevel == RiskLevelCritical) {
        return isDark ? 0xff0000 : 0x8b0000;
    }
    return Graphics.COLOR_TRANSPARENT;
}
