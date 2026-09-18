import Toybox.Attention;
import Toybox.System;

public class AlertAudioNotifier {
    private static var previousState as AlertState = STATE_NORMAL;

    public static function notifyStateChange(newState as AlertState) as Void {
        if (newState == previousState) {
            return; // No change, do nothing
        }

        // Only play audio on escalation (severity increasing)
        if (newState > previousState) {
            playToneForState(newState);
        }

        previousState = newState;
    }

    private static function playToneForState(state as AlertState) as Void {
        // Ensure device supports audio tones
        if (Attention has :playTone) {
            if (state == STATE_ICE_ALERT) {
                // Urgent alert for ice hazard
                Attention.playTone(Attention.TONE_ALERT_HI);
            } else if (state != STATE_NORMAL) {
                // Subtle single pip for wind/heat escalation
                Attention.playTone(Attention.TONE_KEY);
            }
            System.println("Played tone for state: " + state);  
        }
    }
}