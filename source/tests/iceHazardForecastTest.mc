import Toybox.Lang;
import Toybox.Test;

(:test)
class IceHazardTestSupport {
    static function weather(count as Number) as WeatherMetrics {
        var metrics = new WeatherMetrics();
        metrics.airTemp = 5.0f;
        metrics.surfaceTemp = 5.0f;
        metrics.dewPoint = -5.0f;
        metrics.humidity = 40;
        metrics.currentSeason = SeasonWinter;
        for (var i = 0; i < count; i++) {
            metrics.airTempForecast.add(5.0f);
            metrics.surfaceTempForecast.add(5.0f);
            metrics.dewpointForecast.add(-5.0f);
            metrics.rainForecast.add(0.0f);
            metrics.showersForecast.add(0.0f);
            metrics.snowForecast.add(0.0f);
            metrics.windForecast.add(0.0f);
            metrics.windGustForecast.add(0.0f);
        }
        return metrics;
    }

    static function evaluate(metrics as WeatherMetrics) as RiskLevel {
        return RiskCalculator.evaluateRisk(
            metrics.airTemp,
            metrics.surfaceTemp,
            metrics.dewPoint,
            metrics.humidity,
            metrics.rainCurrent,
            metrics.rain12hSum,
            metrics.snow12hSum,
            metrics.dryStreak,
            metrics.currentSeason,
            metrics.windSpeed,
            metrics.windGust,
            metrics.immediateRain,
            metrics.immediateSnow,
            metrics.surfaceTemp - metrics.dewPoint,
            metrics.snowCurrent,
            metrics.upcomingRain
        );
    }

    static function project(
        metrics as WeatherMetrics,
        humidities as Array<Number>,
        startIndex as Number,
        assessment as RiskAssessment
    ) as Void {
        RiskProjectionEngine.calculate12HourRiskProfile(
            metrics,
            startIndex,
            metrics.airTempForecast,
            metrics.surfaceTempForecast,
            metrics.dewpointForecast,
            humidities,
            metrics.rainForecast,
            metrics.showersForecast,
            metrics.snowForecast,
            metrics.windForecast,
            metrics.windGustForecast,
            assessment
        );
    }
}

(:test)
function blackIceSetsForecastFlag(logger as Test.Logger) as Boolean {
    RiskCalculator.setRiskOnly(false);
    var metrics = IceHazardTestSupport.weather(0);
    metrics.airTemp = -2.0f;
    metrics.rain12hSum = 0.1f;
    Test.assertEqual(
        IceHazardTestSupport.evaluate(metrics), RiskLevelCritical
    );
    Test.assert(RiskCalculator.hasIceHazard());
    Test.assertEqual(RiskCalculator.getHazards().size(), 1);
    Test.assertEqual(
        RiskCalculator.getHazards()[0], HazardBlackIceFreezingWetRoad
    );
    return true;
}

(:test)
function frostSetsForecastFlag(logger as Test.Logger) as Boolean {
    RiskCalculator.setRiskOnly(false);
    var metrics = IceHazardTestSupport.weather(0);
    metrics.airTemp = -2.0f;
    metrics.surfaceTemp = 3.0f;
    metrics.dewPoint = 1.0f;
    metrics.humidity = 80;
    Test.assertEqual(
        IceHazardTestSupport.evaluate(metrics), RiskLevelCritical
    );
    Test.assert(RiskCalculator.hasIceHazard());
    Test.assertEqual(RiskCalculator.getHazards().size(), 1);
    Test.assertEqual(
        RiskCalculator.getHazards()[0], HazardRoadSurfaceFrost
    );
    metrics.humidity = 79;
    IceHazardTestSupport.evaluate(metrics);
    Test.assert(!RiskCalculator.hasIceHazard());
    metrics.humidity = 80;
    metrics.surfaceTemp = 3.1f;
    metrics.dewPoint = 1.1f;
    IceHazardTestSupport.evaluate(metrics);
    Test.assert(!RiskCalculator.hasIceHazard());
    return true;
}

(:test)
function bridgeIceSetsForecastFlag(logger as Test.Logger) as Boolean {
    RiskCalculator.setRiskOnly(false);
    var metrics = IceHazardTestSupport.weather(0);
    metrics.airTemp = 3.5f;
    metrics.humidity = 89;
    Test.assertEqual(IceHazardTestSupport.evaluate(metrics), RiskLevelHigh);
    Test.assert(RiskCalculator.hasIceHazard());
    Test.assertEqual(RiskCalculator.getHazards().size(), 1);
    Test.assertEqual(RiskCalculator.getHazards()[0], HazardIceOnBridges);
    metrics.humidity = 88;
    IceHazardTestSupport.evaluate(metrics);
    Test.assert(!RiskCalculator.hasIceHazard());
    return true;
}

(:test)
function slushSetsForecastFlag(logger as Test.Logger) as Boolean {
    RiskCalculator.setRiskOnly(false);
    var metrics = IceHazardTestSupport.weather(0);
    metrics.surfaceTemp = 0.0f;
    metrics.snow12hSum = 0.1f;
    IceHazardTestSupport.evaluate(metrics);
    Test.assert(RiskCalculator.hasIceHazard());
    Test.assert(
        RiskCalculator.getHazards().indexOf(HazardSnowOrSlushAccumulation) >= 0
    );
    metrics.surfaceTemp = 0.1f;
    IceHazardTestSupport.evaluate(metrics);
    Test.assert(
        RiskCalculator.getHazards().indexOf(HazardSnowOrSlushAccumulation) < 0
    );
    metrics.surfaceTemp = 5.0f;
    IceHazardTestSupport.evaluate(metrics);
    Test.assert(!RiskCalculator.hasIceHazard());
    return true;
}

(:test)
function dryColdAndNonIceRisksDoNotSetFlag(logger as Test.Logger) as Boolean {
    RiskCalculator.setRiskOnly(false);
    var metrics = IceHazardTestSupport.weather(0);
    metrics.surfaceTemp = -1.0f;
    metrics.airTemp = -2.0f;
    Test.assertEqual(IceHazardTestSupport.evaluate(metrics), RiskLevelSafe);
    Test.assert(!RiskCalculator.hasIceHazard());

    metrics.rain12hSum = 0.1f;
    IceHazardTestSupport.evaluate(metrics);
    Test.assert(RiskCalculator.hasIceHazard());

    metrics.surfaceTemp = 10.0f;
    metrics.airTemp = 10.0f;
    metrics.rainCurrent = 15.0f;
    metrics.windSpeed = 45.0f;
    Test.assertEqual(
        IceHazardTestSupport.evaluate(metrics), RiskLevelCritical
    );
    Test.assert(!RiskCalculator.hasIceHazard());
    return true;
}

(:test)
function riskOnlyRetainsIceFlagWithoutHazardLists(
    logger as Test.Logger
) as Boolean {
    var metrics = IceHazardTestSupport.weather(0);
    metrics.airTemp = -2.0f;
    metrics.rain12hSum = 0.1f;
    RiskCalculator.setRiskOnly(true);
    Test.assertEqual(
        IceHazardTestSupport.evaluate(metrics), RiskLevelCritical
    );
    Test.assert(RiskCalculator.hasIceHazard());
    Test.assertEqual(RiskCalculator.getHazards().size(), 0);
    Test.assertEqual(RiskCalculator.getAdvice().size(), 0);
    RiskCalculator.setRiskOnly(false);
    return true;
}

(:test)
function hourlyIceFlagsMatchEachProjectedHour(
    logger as Test.Logger
) as Boolean {
    RiskCalculator.setRiskOnly(false);
    var metrics = IceHazardTestSupport.weather(8);
    metrics.surfaceTemp = 0.0f;
    metrics.airTemp = -2.0f;
    metrics.dewPoint = -2.0f;
    metrics.humidity = 80;
    var assessment = new RiskAssessment();
    assessment.riskLevel = IceHazardTestSupport.evaluate(metrics);
    assessment.hazards = RiskCalculator.getHazards();
    assessment.advice = RiskCalculator.getAdvice();

    metrics.airTempForecast[0] = -2.0f;
    metrics.surfaceTempForecast[0] = -1.0f;
    metrics.windForecast[1] = 45.0f;
    metrics.airTempForecast[2] = -1.0f;
    metrics.rainForecast[2] = 0.1f;
    metrics.airTempForecast[4] = -2.0f;
    metrics.surfaceTempForecast[4] = 0.0f;
    metrics.dewpointForecast[4] = -2.0f;
    metrics.airTempForecast[5] = 2.5f;
    metrics.surfaceTempForecast[6] = 1.0f;
    metrics.snowForecast[6] = 0.1f;
    IceHazardTestSupport.project(
        metrics, [40, 40, 40, 40, 80, 89, 40, 40], 0, assessment
    );
    var expected = [false, false, true, false, true, true, true, false];
    Test.assertEqual(assessment.hourlyIceHazards.size(), expected.size());
    Test.assertEqual(assessment.hourlyRisksLevels.size(), expected.size());
    for (var i = 0; i < expected.size(); i++) {
        Test.assertEqualMessage(
            assessment.hourlyIceHazards[i], expected[i], "Ice hour " + i
        );
    }
    Test.assertEqual(assessment.hourlyRisksLevels[1], RiskLevelCritical);
    Test.assertEqual(assessment.riskLevel, RiskLevelCritical);
    Test.assertEqual(assessment.hazards.size(), 1);
    Test.assertEqual(assessment.hazards[0], HazardRoadSurfaceFrost);
    Test.assertEqual(assessment.advice.size(), 2);
    Test.assertEqual(RiskCalculator.getRiskOnly(), false);
    return true;
}

(:test)
function iceForecastUsesRollingHistoryAndCurrentHour(
    logger as Test.Logger
) as Boolean {
    RiskCalculator.setRiskOnly(true);
    var metrics = IceHazardTestSupport.weather(15);
    var humidities = new [15] as Array<Number>;
    for (var i = 0; i < humidities.size(); i++) {
        humidities[i] = 40;
    }
    metrics.showersForecast[0] = 0.1f;
    metrics.airTempForecast[12] = 2.5f;
    metrics.airTempForecast[13] = 2.5f;
    metrics.snowForecast[14] = 0.1f;
    metrics.surfaceTempForecast[14] = 1.0f;
    var assessment = new RiskAssessment();
    IceHazardTestSupport.project(metrics, humidities, 12, assessment);
    Test.assertEqual(assessment.hourlyIceHazards.size(), 3);
    Test.assertEqual(assessment.hourlyIceHazards[0], true);
    Test.assertEqual(assessment.hourlyIceHazards[1], false);
    Test.assertEqual(assessment.hourlyIceHazards[2], true);
    Test.assertEqual(assessment.hourlyRisksLevels[1], RiskLevelHigh);
    Test.assertEqual(RiskCalculator.getRiskOnly(), true);
    RiskCalculator.setRiskOnly(false);
    return true;
}

(:test)
function iceForecastHandlesShortAndExpiredInputs(
    logger as Test.Logger
) as Boolean {
    var metrics = IceHazardTestSupport.weather(4);
    var assessment = new RiskAssessment();
    IceHazardTestSupport.project(metrics, [40, 40], -1, assessment);
    Test.assertEqual(assessment.hourlyRisksLevels.size(), 2);
    Test.assertEqual(assessment.hourlyIceHazards.size(), 2);
    IceHazardTestSupport.project(metrics, [40, 40], 2, assessment);
    Test.assertEqual(assessment.hourlyRisksLevels.size(), 0);
    Test.assertEqual(assessment.hourlyIceHazards.size(), 0);
    IceHazardTestSupport.project(metrics, [] as Array<Number>, 0, assessment);
    Test.assertEqual(assessment.hourlyRisksLevels.size(), 0);
    Test.assertEqual(assessment.hourlyIceHazards.size(), 0);
    return true;
}

(:test)
function demoForecastIncludesHourlyIceFlags(logger as Test.Logger) as Boolean {
    for (var counter = 0; counter <= 30; counter += 5) {
        var metrics = DemoWeatherService.getDemoWeatherMetrics(counter);
        var assessment = DemoWeatherService.getDemoRiskAssessment(metrics);
        Test.assertEqual(assessment.hourlyRisksLevels.size(), 12);
        Test.assertEqual(assessment.hourlyIceHazards.size(), 12);
    }
    return true;
}

(:test)
function nearFreezingHumidNightMatchesAppletFrost(
    logger as Test.Logger
) as Boolean {
    // Keesing 02:00 forecast where the applet showed ice and CIQ did not.
    RiskCalculator.setRiskOnly(false);
    var metrics = IceHazardTestSupport.weather(0);
    metrics.airTemp = 4.3f;
    metrics.surfaceTemp = 3.0f;
    metrics.dewPoint = 2.4f;
    metrics.humidity = 88;
    Test.assertEqual(
        IceHazardTestSupport.evaluate(metrics), RiskLevelCritical
    );
    Test.assert(RiskCalculator.hasIceHazard());
    Test.assertEqual(RiskCalculator.getHazards()[0], HazardRoadSurfaceFrost);
    return true;
}
