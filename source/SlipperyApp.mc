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
        return [new SlipperyView()];
    }

    (:typecheck(disableBackgroundCheck))
    function onSettingsChanged() as Void {
        // loadUserSettings();
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
