import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Application.Storage;
import Toybox.System;

(:background)
class SlipperyApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {}

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {}

    //! Return the initial view of your application here
    (:typecheck(disableBackgroundCheck))
    function getInitialView() as [Views] or [Views, InputDelegates] {
        loadUserSettings();
        return [new SlipperyView()];
    }

    //! Return the settings view and delegate for the app
    //! @return Array Pair [View, Delegate]
    (:typecheck(disableBackgroundCheck))
    function getSettingsView() as
        [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] or Null
    {
        return [
            new $.DataFieldSettingsView(),
            new $.DataFieldSettingsDelegate(),
        ];
    }

    (:typecheck(disableBackgroundCheck))
    function onSettingsChanged() as Void {
        loadUserSettings();
    }

    (:typecheck(disableBackgroundCheck))
    function getBGServiceHandler() as BGServiceHandler {
        if ($._BGServiceHandler == null) {
            $._BGServiceHandler = new BGServiceHandler();
        }
        return $._BGServiceHandler as BGServiceHandler;
    }

    (:typecheck(disableBackgroundCheck))
    function loadUserSettings() as Void {
        try {
            System.println("Loading user settings");
            var reset = Storage.getValue("resetDefaults");
            if (reset == null || (reset as Boolean)) {
                System.println("Reset user settings");
                Storage.setValue("resetDefaults", false);
                Storage.setValue("checkIntervalMinutes", 5);
                Storage.setValue("demo", false);
                Storage.setValue("alert_beep", true);
                Storage.setValue("alert_toast", false);
                Storage.setValue("alert_beep_state_change", true);
                Storage.setValue("hsp_showvalue", false);                
                Storage.setValue("hsp_darklight_breakpoint", 180);    
                Storage.setValue("showForecastHour", ForecastHourAbsolute);            
                Storage.setValue("useEffectiveCrossGust", true);            
                Storage.setValue("useFeelsLikeTemperature", true);            
                Storage.setValue("shortHazard", false);            
                Storage.setValue("hideRiskAdvice", false);            
                Storage.setValue("hideUnitsWhenActive", true);

                Storage.setValue("threshIceAlert", 3.0f);
                Storage.setValue("threshHighCrosswind", 25.0f);
                Storage.setValue("threshCrossGust", 18.0f);
                Storage.setValue("threshHeavyWind", 35.0f);
                Storage.setValue("threshSustainedWind", 25.0f);
                Storage.setValue("threshHeadwind", 12.0f);
                Storage.setValue("threshHeatStress", 32.0f);
            }

            $.g_bg_timeout_seconds =
                $.getStorageValue(
                    "g_bg_timeout_seconds",
                    $.g_bg_timeout_seconds
                ) as Number;
            $.g_bg_delay_seconds =
                $.getStorageValue("g_bg_delay_seconds", $.g_bg_delay_seconds) as
                Number;

            var bgHandler = getBGServiceHandler();
            bgHandler.setMinimalGPSLevel(
                $.getStorageValue("minimalGPSquality", $.gMinimalGPSquality) as
                    Number
            );
            var interval =
                $.getStorageValue("checkIntervalMinutes", 5) as Number;
            if (interval < 5) {
                interval = 5;
                Storage.setValue("checkIntervalMinutes", interval);
            }
            bgHandler.setUpdateFrequencyInMinutes(interval);

            $.gDemo = $.getStorageValue("demo", false) as Boolean;
            if ($.gDemo) {
                Storage.setValue("demo", false);
            }
            $.gBeepOnAlert = $.getStorageValue("alert_beep", true) as Boolean;
            $.gToastOnAlert =
                $.getStorageValue("alert_toast", false) as Boolean;
            $.gBeepOnAlertStateChange = $.getStorageValue("alert_beep_state_change", true) as Boolean;
            $.gHSPshowValue =
                $.getStorageValue("hsp_showvalue", false) as Boolean;

            $.gShowForecastHour =
                $.getStorageValue("showForecastHour", ForecastHourAbsolute) as ShowForecastHour;
            $.gUseEffectiveCrossGust =
                $.getStorageValue("useEffectiveCrossGust", true) as Boolean;
            $.gUseFeelsLikeTemperature =
                $.getStorageValue("useFeelsLikeTemperature", true) as Boolean;
            $.gHideRiskAdvice =
                $.getStorageValue("hideRiskAdvice", false) as Boolean;  
            $.gShortHazard =
                $.getStorageValue("shortHazard", false) as Boolean;  
            $.gHideUnitsWhenActive =
                $.getStorageValue("hideUnitsWhenActive", true) as Boolean;  

            AlertStateAnalyzer.setTreshIceAlert($.getStorageValue("threshIceAlert", 0.0f) as Float);              
            AlertStateAnalyzer.setTreshHighCrosswind($.getStorageValue("threshHighCrossw ind", 0.0f) as Float);              
            AlertStateAnalyzer.setTreshCrossGust($.getStorageValue("threshCrossGust", 0.0f) as Float);              
            AlertStateAnalyzer.setTreshHeavyWind($.getStorageValue("threshHeavyWind", 0.0f) as Float);              
            AlertStateAnalyzer.setTreshSustainedWind($.getStorageValue("threshSustainedWind", 0.0f) as Float);              
            AlertStateAnalyzer.setTreshHeadwind($.getStorageValue("threshHeadwind", 0.0f) as Float);              
            AlertStateAnalyzer.setTreshHeatStress($.getStorageValue("threshHeatStress", 0.0f) as Float);              
        } catch (ex) {
            System.println(ex.getErrorMessage());
            ex.printStackTrace();
        }
    }

    public function getServiceDelegate() as [System.ServiceDelegate] {
        return [new BackgroundServiceDelegate()];
    }

    (:typecheck(disableBackgroundCheck))
    function onBackgroundData(data as Application.PersistableType) as Void {
        System.println("Background data recieved");
        System.println(data);

        if (data instanceof Lang.Number && data == 0) {
            System.println("Response code is 0 -> reset bg service");
            loadUserSettings();
            return;
        }

        var bgHandler = getBGServiceHandler();
        bgHandler.onBackgroundData(data); //, self, :updateBgData);   

        WatchUi.requestUpdate();     
    }
}

function getApp() as SlipperyApp {
    return Application.getApp() as SlipperyApp;
}

var _BGServiceHandler as BGServiceHandler?;
var gMinimalGPSquality as Number = 3;
var gDemo as Boolean = false;

var gBeepOnAlert as Boolean = true;
var gToastOnAlert as Boolean = false;
var gBeepOnAlertStateChange as Boolean = true;

var gHSPshowValue as Boolean = false;
var gShowForecastHour as ShowForecastHour = ForecastHourAbsolute;
var gUseEffectiveCrossGust as Boolean = true; 
var gUseFeelsLikeTemperature as Boolean = true;
var gHideRiskAdvice as Boolean = false;
var gShortHazard as Boolean = false;
var gHideUnitsWhenActive as Boolean = true;