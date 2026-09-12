import Toybox.System;
import Toybox.Lang;
import Toybox.Graphics;
import Toybox.Time;

class WeatherService {
    private static var _metrics as WeatherMetrics = new WeatherMetrics();
    private static var _risks as RiskAssessment = new RiskAssessment();

    public static function getMetrics() as WeatherMetrics {
        return _metrics;
    }

    public static function getRisks() as RiskAssessment {
        return _risks;
    }

    // Parse OpenMeteo API response and update weather metrics
    // Calculate risk assessment based on parsed weather data
    // Calculate risk forecast based on parsed weather data
    public static function parseOpenMeteoResponse(
        lat as Float,
        data as Dictionary?
    ) as Boolean {
        if (data == null || !data.hasKey("hourly")) {
            return false;
        }

        var hourly = data.get("hourly") as Dictionary;
        var times = hourly.get("time") as Array<Number>?;

        if (times == null || times.size() == 0) {
            System.println("No hourly time data available.");
            return false;
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

        var airTemps = hourly.get("temperature_2m") as Array<Float>?;
        var surfTemps = hourly.get("surface_temperature") as Array<Float>?;
        var dewPoints = hourly.get("dewpoint_2m") as Array<Float>?;
        var humidities = hourly.get("relativehumidity_2m") as Array<Number>?;
        var rains = hourly.get("rain") as Array<Float>?;
        var precips = hourly.get("precipitation") as Array<Float>?;
        var snows = hourly.get("snowfall") as Array<Float>?;
        var windSpeeds = hourly.get("wind_speed_10m") as Array<Float>?;
        var windGusts = hourly.get("wind_gusts_10m") as Array<Float>?;
        var windDirections = hourly.get("wind_direction_10m") as Array<Number>?;
        if (
            airTemps == null ||
            surfTemps == null ||
            dewPoints == null ||
            humidities == null ||
            rains == null ||
            precips == null ||
            snows == null ||
            windSpeeds == null ||
            windGusts == null ||
            windDirections == null
        ) {
            System.println(
                "One or more required hourly data arrays are missing."
            );
            return false;
        }
        metrics.airTemp = airTemps[targetIdx];
        metrics.surfaceTemp = surfTemps[targetIdx];
        metrics.dewPoint = dewPoints[targetIdx];
        metrics.humidity = humidities[targetIdx];
        metrics.rainCurrent = rains[targetIdx];
        metrics.snowCurrent = snows[targetIdx];
        metrics.windSpeed = windSpeeds[targetIdx];
        metrics.windGust = windGusts[targetIdx];
        metrics.windDirection = windDirections[targetIdx];

        // Calculate 12-hour accumulated moisture lookback for slipperiness
        var startIdx = targetIdx - 12;
        if (startIdx < 0) {
            System.println(
                "Start index for 12-hour lookback is less than 0. Adjusting to 0."
            );
            startIdx = 0;
        }

        var sumPrecip = 0.0;
        var sumSnow = 0.0;

        for (var j = startIdx; j <= targetIdx; j++) {
            if (j < precips.size()) {
                sumPrecip += precips[j];
            }
            if (j < snows.size()) {
                sumSnow += snows[j];
            }
        }

        metrics.precip12hSum = sumPrecip;
        metrics.snow12hSum = sumSnow;

        // Look back at dry streak length (for "first rain after dry spell" effect)
        var dryStreak = 0;
        for (var k = targetIdx; k >= 0; k--) {
            if (k < rains.size() && rains[k] == 0.0) {
                dryStreak += 1;
            } else {
                break;
            }
        }
        metrics.dryStreak = dryStreak;

        metrics.currentSeason = $.getMeteorologicalSeason(lat, Time.now());

        // Get the 12 hour forecast for rain, wind, wind direction, and temperature
        // Start with the current hour time index!
        var maxForecastIdx = times.size();
        for (var l = targetIdx; l < maxForecastIdx; l++) {
            if (l < times.size()) {
                metrics.timeStampsForeCast.add(times[l]);
            }
            if (l < rains.size()) {
                metrics.rainForecast.add(rains[l]);
            }
            if (l < windSpeeds.size()) {
                metrics.windForecast.add(windSpeeds[l]);
            }
            if (l < windDirections.size()) {
                metrics.windDirForecast.add(windDirections[l]);
            }
            if (l < airTemps.size()) {
                metrics.tempForecast.add(airTemps[l]);
            }
        }

        var minutelyData = data.get("minutely_15") as Dictionary?;
        if (minutelyData != null) {
            var rainArray = minutelyData.get("rain") as Array<Float>?;
            var snowArray = minutelyData.get("snowfall") as Array<Float>?;

            // Gives the rider 15–30 minutes notice before wet asphalt compromises cornering grip
            var threshold = 0.1f;
            metrics.immediateRain = checkForImminentPrecipitation(
                rainArray,
                threshold
            );
            metrics.immediateSnow = checkForImminentPrecipitation(
                snowArray,
                threshold
            );
        }
        metrics.isValid = true;
        _metrics = metrics;

        // Calculate Risk Assessment current and forecasted conditions
        var risks = calculateCurrentRiskAssessment();
        
        // Calculate X-hour risk projection
        risks.hourlyRisksLevels =
            RiskProjectionEngine.calculate12HourRiskProfile(
                _metrics,
                targetIdx, // startIndex is current hour
                airTemps,
                surfTemps,
                dewPoints,
                humidities,
                rains,
                snows,
                windSpeeds,
                windGusts
            );
        _risks = risks;
        return true;
    }

    static function calculateCurrentRiskAssessment() as RiskAssessment {
        var airTemp = _metrics.airTemp;
        var surfaceTemp = _metrics.surfaceTemp;
        var dewPoint = _metrics.dewPoint;
        var humidity = _metrics.humidity;
        var rainCurrent = _metrics.rainCurrent;
        var runningPrecip12h = _metrics.precip12hSum;
        var runningSnow12h = _metrics.snow12hSum;
        var dryHoursBeforeRain = _metrics.dryStreak;
        var season = _metrics.currentSeason;
        var windSpeed = _metrics.windSpeed; // in km/h
        var windGust = _metrics.windGust; // in km/h
        var immediateRain = _metrics.immediateRain;
        var immediateSnow = _metrics.immediateSnow;
        var snowCurrent = _metrics.snowCurrent;
        var surfaceDewSpread = surfaceTemp - dewPoint;

        var assessment = new RiskAssessment();

        RiskCalculator.setRiskOnly(false);
        var riskLevel = RiskCalculator.evaluateRisk(
            airTemp,
            surfaceTemp,
            dewPoint,
            humidity,
            rainCurrent,
            runningPrecip12h,
            runningSnow12h,
            dryHoursBeforeRain,
            season,
            windSpeed,
            windGust,
            immediateRain,
            immediateSnow,
            surfaceDewSpread,
            snowCurrent
        );        
        assessment.riskLevel = riskLevel;
        assessment.hazards = RiskCalculator.getHazards();
        assessment.advice = RiskCalculator.getAdvice();
        return assessment;
    }
    static function checkForImminentPrecipitation(
        rainOrSnowArray as Array<Float>?,
        mmThreshold as Float
    ) as Number {
        if (rainOrSnowArray == null || rainOrSnowArray.size() == 0) {
            return -1; // No data available
        }
        // Check index 0 (0-15 min), index 1 (15-30 min), index 2 (30-45 min), index 3 (45-60 min)
        var maxSlotsToCheck =
            rainOrSnowArray.size() < 4 ? rainOrSnowArray.size() : 4;

        for (var i = 0; i < maxSlotsToCheck; i++) {
            var precip = rainOrSnowArray[i];
            if (precip != null && precip >= mmThreshold) {
                return i * 15; // Returns 0, 15, 30, or 45 minutes
            }
        }

        return -1; // No rain detected within the hour
    }

    // static function calculateRiskAssessment(
    //     riskOnly as Boolean
    // ) as RiskAssessment? {
    //     if (!_metrics.isValid) {
    //         return null;
    //     }
    //     var assessment = new RiskAssessment();
    //     assessment.riskLevel = RiskLevelSafe;
    //     assessment.hazards = [] as Array<WeatherHazard>;
    //     assessment.advice = [] as Array<WeatherAdvice>;
    //     assessment.hourlyRiskProfiles = [] as Array<RiskLevel>;

    //     var currentTemp = _metrics.airTemp;
    //     var surfaceTemp = _metrics.surfaceTemp;
    //     var dewPoint = _metrics.dewPoint;
    //     var humidity = _metrics.humidity;
    //     var currentRain = _metrics.rainCurrent;
    //     var runningPrecip12h = _metrics.precip12hSum;
    //     var runningSnow12h = _metrics.snow12hSum;
    //     var dryHoursBeforeRain = _metrics.dryStreak;
    //     var season = _metrics.currentSeason;
    //     var windSpeed = _metrics.windSpeed; // in km/h
    //     var windGust = _metrics.windGust; // in km/h
    //     var immediateRain = _metrics.immediateRain;
    //     var rainCurrent = _metrics.rainCurrent;
    //     var immediateSnow = _metrics.immediateSnow;
    //     var snowCurrent = _metrics.snowCurrent;
    //     var surfaceDewSpread = surfaceTemp - dewPoint;

    //     // --- 1. CRITICAL: Black Ice & Freezing Wet Asphalt ---
    //     if (
    //         (surfaceTemp <= 0.0 || currentTemp <= 0.5) &&
    //         (runningPrecip12h > 0.0 || currentRain > 0.0)
    //     ) {
    //         upgradeRisk(assessment, RiskLevelCritical);
    //         addHazard(assessment, HazardBlackIceFreezingWetRoad);
    //         addAdvice(assessment, AdviceAvoidRiding);
    //         addAdvice(assessment, AdviceLowerTirePressure);
    //     }

    //     // --- 2. CRITICAL: Hoarfrost / Freezing" Fog ---
    //     if (surfaceTemp <= 0.0 && surfaceDewSpread <= 2.0) {
    //         upgradeRisk(assessment, RiskLevelCritical);
    //         addHazard(assessment, HazardRoadSurfaceFrost);
    //         addAdvice(
    //             assessment,
    //             AdviceWatchOutForShadedAreasBridgesTreeLinedRoads
    //         );
    //         addAdvice(assessment, AdviceAvoidSuddenBraking);
    //     }

    //     // --- 3. HIGH: Bridge Deck Freeze ---
    //     if (
    //         currentTemp >= 0.0 &&
    //         currentTemp <= 2.5 &&
    //         (runningPrecip12h > 0.0 || humidity > 88)
    //     ) {
    //         upgradeRisk(assessment, RiskLevelHigh);
    //         addHazard(assessment, HazardIceOnBridges);
    //         addAdvice(
    //             assessment,
    //             AdviceWatchOutForShadedAreasBridgesTreeLinedRoads
    //         );
    //     }

    //     // --- 4. HIGH: Snow / Slush Accumulation ---
    //     if (runningSnow12h > 0.0) {
    //         upgradeRisk(assessment, RiskLevelHigh);
    //         addHazard(assessment, HazardSnowOrSlushAccumulation);
    //         addAdvice(assessment, AdviceLossOfTractionInTurns);
    //         addAdvice(assessment, AdviceTreadPatternRequired);
    //     }

    //     // --- 5. HIGH / MODERATE: Heavy Rain Hydroplaning & Spray ---
    //     if (currentRain >= 5.0) {
    //         upgradeRisk(assessment, RiskLevelHigh);
    //         addHazard(assessment, HazardHeavyRainHydroplaning);
    //         addAdvice(assessment, AdviceIncreaseBreakingDistance);
    //         addAdvice(assessment, AdviceReduceSpeedAndIncreaseGripMargin);
    //     }

    //     // --- 6. MODERATE: Autumn Wet Leaves ---
    //     if (
    //         season == SeasonAutumn &&
    //         (runningPrecip12h > 0.0 || humidity > 90)
    //     ) {
    //         upgradeRisk(assessment, RiskLevelModerate);
    //         addHazard(assessment, HazardWetLeafCoverage);
    //         addAdvice(assessment, AdviceExtremeSlipHazardOnCorneringLines);
    //         addAdvice(assessment, AdviceReduceCorneringLeanAngle);
    //     }

    //     // --- 7. MODERATE: Summer/Spring First Rain ("Oil Slick") ---
    //     if (
    //         (season == SeasonSummer || season == SeasonSpring) &&
    //         currentRain > 0.0 &&
    //         currentRain < 2.5 &&
    //         dryHoursBeforeRain >= 18
    //     ) {
    //         upgradeRisk(assessment, RiskLevelModerate);
    //         addHazard(assessment, HazardFirstRainReleasingDirtOils);
    //         addAdvice(assessment, AdviceAsphaltSlippery);
    //         addAdvice(assessment, AdviceTractionImprovesAfterHeavierRain);
    //     }

    //     // --- 8. SLIGHT: Dew Condensation ("Sweating Road") ---
    //     if (surfaceTemp > 0.0 && humidity > 90 && surfaceDewSpread <= 1.0) {
    //         upgradeRisk(assessment, RiskLevelSlight);
    //         addHazard(assessment, HazardWetAsphaltSurface);
    //         addAdvice(
    //             assessment,
    //             AdviceWatchOutForShadedAreasBridgesTreeLinedRoads
    //         );
    //         addAdvice(assessment, AdviceReduceCorneringLeanAngle);
    //     }

    //     // --- 9. SLIGHT: Light / Moderate Rain ---
    //     if (currentRain > 0.2 && currentRain < 5.0) {
    //         upgradeRisk(assessment, RiskLevelSlight);
    //         addHazard(assessment, HazardWetAsphaltSurface);
    //         addAdvice(assessment, AdviceIncreaseBreakingDistance);
    //         addAdvice(assessment, AdviceReduceCorneringLeanAngle);
    //     }

    //     // --- 10. CRITICAL / HIGH: Gale-Force Crosswinds & Violent Gusts ---
    //     if (windSpeed >= 45.0 || windGust >= 60.0) {
    //         upgradeRisk(assessment, RiskLevelCritical);
    //         addHazard(assessment, HazardGaleForceWinds);
    //         addAdvice(assessment, AdviceBewareOfOpenFieldsAndBridges);
    //         addAdvice(assessment, AdviceHoldHandlebarsFirmly);
    //         addAdvice(assessment, AdviceConsiderLowerProfileWheels);
    //     }
    //     // --- 11. MODERATE: Strong / Gusty Winds ---
    //     else if (windSpeed >= 30.0 || windGust >= 45.0) {
    //         upgradeRisk(assessment, RiskLevelModerate);
    //         addHazard(assessment, HazardStrongCrosswinds);
    //         addAdvice(assessment, AdviceBewareOfOpenFieldsAndBridges);
    //         addAdvice(assessment, AdviceHoldHandlebarsFirmly);
    //     }

    //     // --- 12. IMMEDIATE: Imminent Rain ---
    //     if (immediateRain >= 0 && rainCurrent < 0.1f) {
    //         upgradeRisk(assessment, RiskLevelHigh);
    //         addHazard(assessment, HazardImminentRain);

    //         // if (metrics.immediateRain == 0) {
    //         //     addAdvice(assessment, AdviceRainStartingNow);
    //         // } else {
    //         //     // Triggers UI banner: "RAIN IN 15 MIN" or "RAIN IN 30 MIN"
    //         //     addAdvice(assessment, AdviceRainExpectedShortly);
    //         // }
    //     }
    //     // --- 13. IMMEDIATE: Imminent Snow ---
    //     if (immediateSnow >= 0 && snowCurrent < 0.1f) {
    //         upgradeRisk(assessment, RiskLevelHigh);
    //         addHazard(assessment, HazardImminentSnow);

    //         // if (metrics.immediateSnow == 0) {
    //         //     addAdvice(assessment, AdviceSnowStartingNow);
    //         // } else {
    //         //     // Triggers UI banner: "SNOW IN 15 MIN" or "SNOW IN 30 MIN"
    //         //     addAdvice(assessment, AdviceSnowExpectedShortly);
    //         // }
    //     }

    //     return assessment;
    // }

    // // --- HELPER UTILITIES FOR SAFE ARRAY & RISK MANAGEMENT ---

    // static function upgradeRisk(
    //     assessment as RiskAssessment,
    //     newLevel as RiskLevel
    // ) as Void {
    //     if (newLevel > assessment.riskLevel) {
    //         assessment.riskLevel = newLevel;
    //     }
    // }

    // static function addHazard(
    //     assessment as Riskstatic function calculate12HourRiskProfile(
    //     hourlyData as Array<WeatherHourlyStep>
    // ) as Array<RiskLevel> {
    //     var riskProfile = new [12];

    //     for (var i = 0; i < 12; i++) {
    //         var step = hourlyData[i];

    //         // Evaluate your existing rule hierarchy for each future hour
    //         var risk = evaluateHazardRules(
    //             step.airTemp,
    //             step.surfaceTemp,
    //             step.rain,
    //             step.snow,
    //             step.windGust
    //         );

    //         riskProfile[i] = risk;
    //     }

    //     return riskProfile; // e.g., [Safe, Safe, Slight, Moderate, High, High, Moderate, ...]
    // }Assessment,
    //     hazard as WeatherHazard
    // ) as Void {
    //     if (assessment.hazards.indexOf(hazard) == -1) {
    //         assessment.hazards.add(hazard);
    //     }
    // }

    // static function addAdvice(
    //     assessment as RiskAssessment,
    //     advice as WeatherAdvice
    // ) as Void {
    //     if (assessment.advice.indexOf(advice) == -1) {
    //         assessment.advice.add(advice);
    //     }
    // }
}
