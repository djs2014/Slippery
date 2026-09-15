import Toybox.System;
import Toybox.Activity;
import Toybox.Lang;

public class ActivityUtils {
    static var mPaused as Boolean = false;
    static var mStartCountdown as Number = 0;

    // Return paused is true fast, or false after 5 seconds of being unpaused
    public static function getPaused(info as Activity.Info) as Boolean {
        var activityTimerPaused = false;
        if (info has :timerState) {
            activityTimerPaused =
                info.timerState == Activity.TIMER_STATE_PAUSED or
                info.timerState == Activity.TIMER_STATE_OFF;
        }
        if (activityTimerPaused) {
            mStartCountdown = 5;
            mPaused = true;
        } else {
            if (mStartCountdown >= 0) {
                mStartCountdown--;
            } else {
                mPaused = false;
            }
        }
        return mPaused;
    }
}
