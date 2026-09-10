import Toybox.System;
import Toybox.Lang;
import Toybox.Graphics;

class WeatherMetrics {
    // Current Instant Metrics
    var airTemp as Float = 0.0;
    var surfaceTemp as Float = 0.0;
    var dewPoint as Float = 0.0;
    var humidity as Number = 0;
    var rainCurrent as Float = 0.0;
    var windSpeed as Float = 0.0; // in km/h
    var windGust as Float = 0.0; // in km/h
    var windDirection as Number = 0; // in degrees

    // Past 12h Context
    var precip12hSum as Float = 0.0;
    var snow12hSum as Float = 0.0;
    var dryStreak as Number = 0; // Length of the current dry streak in hours

    var currentSeason as MeteorologicalSeason = SeasonNoData;

    // 12h forecast metrics
    var rainForecast as Array<Float> = []; // 12 Float items (mm/h)
    var windForecast as Array<Float> = []; // 12 Float items (km/h)
    var windDirForecast as Array<Number> = []; // 12 Number items (0-359 deg)
    var tempForecast as Array<Float> = []; // 12 Float items (°C surface/air)

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
            ", windSpeed=" +
            windSpeed +
            ", windGust=" +
            windGust +
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
            // times[i] is start of the hour
            // we need to go back one hour to get the current hour's data if possible
            if (i > 0) {
                targetIdx = i - 1;
            } else {
                targetIdx = i;
            }
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

    // Extract current metrics directlyp = precips[t
    var metrics = new WeatherMetrics();

    var airTemps = hourly.get("temperature_2m") as Array<Float>;
    var surfTemps = hourly.get("surface_temperature") as Array<Float>;
    var dewPoints = hourly.get("dewpoint_2m") as Array<Float>;
    var humidities = hourly.get("relativehumidity_2m") as Array<Number>;
    var rains = hourly.get("rain") as Array<Float>;
    var precips = hourly.get("precipitation") as Array<Float>;
    var snows = hourly.get("snowfall") as Array<Float>;
    var windSpeeds = hourly.get("wind_speed_10m") as Array<Float>;
    var windGusts = hourly.get("wind_gusts_10m") as Array<Float>;
    var windDirections = hourly.get("wind_direction_10m") as Array<Number>;

    metrics.airTemp = airTemps[targetIdx];
    metrics.surfaceTemp = surfTemps[targetIdx];
    metrics.dewPoint = dewPoints[targetIdx];
    metrics.humidity = humidities[targetIdx];
    metrics.rainCurrent = rains[targetIdx];
    metrics.windSpeed = windSpeeds[targetIdx];
    metrics.windGust = windGusts[targetIdx];
    metrics.windDirection = windDirections[targetIdx];

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

    // Get the 12 hour forecast for rain, wind, wind direction, and temperature
    var maxForecastIdx = times.size();
    for (var l = targetIdx + 1; l < maxForecastIdx; l++) {
        if (rains != null && l < rains.size()) {
            metrics.rainForecast.add(rains[l]);
        }
        if (windSpeeds != null && l < windSpeeds.size()) {
            metrics.windForecast.add(windSpeeds[l]);
        }
        if (windDirections != null && l < windDirections.size()) {
            metrics.windDirForecast.add(windDirections[l]);
        }
        if (airTemps != null && l < airTemps.size()) {
            metrics.tempForecast.add(airTemps[l]);
        }            
    }
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

    return assessment;
}

// --- HELPER UTILITIES FOR SAFE ARRAY & RISK MANAGEMENT ---

function upgradeRisk(
    assessment as RiskAssessment,
    newLevel as RiskLevel
) as Void {
    if (newLevel > assessment.riskLevel) {
        assessment.riskLevel = newLevel;
    }
}

function addHazard(
    assessment as RiskAssessment,
    hazard as WeatherHazard
) as Void {
    if (assessment.hazards.indexOf(hazard) == -1) {
        assessment.hazards.add(hazard);
    }
}

function addAdvice(
    assessment as RiskAssessment,
    advice as WeatherAdvice
) as Void {
    if (assessment.advice.indexOf(advice) == -1) {
        assessment.advice.add(advice);
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
        return "Hydroplaning";
    } else if (hazard == HazardStrongCrosswinds) {
        return "Strong Crosswinds";
    } else if (hazard == HazardGaleForceWinds) {
        return "Gale Force Winds";
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
