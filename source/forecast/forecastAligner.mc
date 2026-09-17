import Toybox.Graphics;
import Toybox.Time;
import Toybox.Lang;

class ForecastAligner {
    /**
     * Calculates the remaining fraction (0.25, 0.50, 0.75, 1.0) for hourlyTimes[0]
     * based on current epoch time relative to hourlyTimes[0].
     */
    public static function getFirstHourRemainingFraction(
        hourlyTimes as Array<Number>,
        nowEpoch as Number
    ) as Float {
        if (hourlyTimes.size() == 0) {
            return 1.0f;
        }

        var hourStartEpoch = hourlyTimes[0];

        // If current time is past the start of the first hour timestamp
        var secondsElapsed = nowEpoch - hourStartEpoch;

        if (secondsElapsed <= 0) {
            return 1.0f; // Whole hour remaining (100%)
        }

        var minutesElapsed = secondsElapsed / 60;

        if (minutesElapsed < 15) {
            return 1.0f; // 100% (4 quarters remaining)
        } else if (minutesElapsed < 30) {
            return 0.75f; // 75% (3 quarters remaining)
        } else if (minutesElapsed < 45) {
            return 0.50f; // 50% (2 quarters remaining)
        } else if (minutesElapsed < 60) {
            return 0.25f; // 25% (1 quarter remaining)
        }

        // Data is stale (>1 hr behind current time)
        return 0.25f;
    }

    /**
     * Renders hourly columns where Column 0 shrinks to match remaining 15-min quarters.
     */
    public static function drawHourlyGrid(
        dc as Graphics.Dc,
        startX as Number,
        startY as Number,
        standardColWidth as Number,
        height as Number,
        hourlyValues as Array<Float>,
        hourFraction as Float
    ) as Void {
        var numHours = hourlyValues.size();
        if (numHours == 0) {
            return;
        }

        var gap = 2;

        // Column 0 shrinks to the left, anchored at startX
        var col0Width = (standardColWidth * hourFraction).toNumber();

        // How much space was lost on the right side of Column 0
        var leftShift = standardColWidth - col0Width;

        for (var i = 0; i < numHours; i++) {
            var colX = 0;
            var colW = 0;

            if (i == 0) {
                // Anchor left edge at startX and only shrink width
                colX = startX;
                colW = col0Width;
            } else {
                // Place at normal grid position, then pull left by the lost width
                var normalX = startX + i * (standardColWidth + gap);
                colX = normalX - leftShift;
                colW = standardColWidth;
            }

            // Draw hourly column
            dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(colX, startY, colW, height);
        }
    }
}
