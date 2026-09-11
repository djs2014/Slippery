import Toybox.System;
import Toybox.Lang;
import Toybox.Graphics;
import Toybox.Time;
class DemoWeatherService {
    
    var currentRiskLevel = RiskLevelSafe;

    public static function getDemoRiskAssessment(
        counter as Number
    ) as RiskAssessment {

            // TODO demo weather data 
        var ra = new RiskAssessment();
        if (counter <= 5) {
            ra.riskLevel = RiskLevelSafe;
        } else if (counter <= 10) {
            ra.riskLevel = RiskLevelSlight;
            addHazard(ra, HazardWetAsphaltSurface);
            addAdvice(ra, AdviceIncreaseBreakingDistance);
            addAdvice(ra, AdviceReduceCorneringLeanAngle);
        } else if (counter <= 20) {
            ra.riskLevel = RiskLevelModerate;
            addHazard(ra, HazardStrongCrosswinds);
            addAdvice(ra, AdviceBewareOfOpenFieldsAndBridges);
            addAdvice(ra, AdviceHoldHandlebarsFirmly);
        } else if (counter <= 30) {
            ra.riskLevel = RiskLevelHigh;
            addHazard(ra, HazardImminentRain);
            addAdvice(ra, AdviceIncreaseBreakingDistance);
            addAdvice(ra, AdviceReduceSpeedAndIncreaseGripMargin);
           } else if (counter <= 40) { 
            ra.riskLevel = RiskLevelModerate;
            addHazard(ra, HazardStrongCrosswinds);
            addAdvice(ra, AdviceBewareOfOpenFieldsAndBridges);
            addAdvice(ra, AdviceHoldHandlebarsFirmly);
        } else if (counter <= 50){
            ra.riskLevel = RiskLevelCritical;
            addHazard(ra, HazardGaleForceWinds);
            addAdvice(ra, AdviceBewareOfOpenFieldsAndBridges);
            addAdvice(ra, AdviceHoldHandlebarsFirmly);
            addAdvice(ra, AdviceConsiderLowerProfileWheels);
        } else {
            ra = null;
        }

        return ra;
    }

    static function addHazard(
        assessment as RiskAssessment,
        hazard as WeatherHazard
    ) as Void {
        if (assessment.hazards.indexOf(hazard) == -1) {
            assessment.hazards.add(hazard);
        }
    }

    static function addAdvice(
        assessment as RiskAssessment,
        advice as WeatherAdvice
    ) as Void {
        if (assessment.advice.indexOf(advice) == -1) {
            assessment.advice.add(advice);
        }
    }
}
