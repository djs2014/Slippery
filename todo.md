- linux taskbar app for local use

- option to collect lat/lon during commute 
    - for predict commute track
    - reset option after activity done

Nice to have - on hour switch ->
    - update forecast bar
    - TODO cache next hour
   

- werkende icon voor risk level (small screen)

- alert on incoming rain/snow
- alert on ice forecast 
- check forecast hours if it gets slippery
    - alert
    - border around bar and display level + colorpill under



import Toybox.Graphics as Gfx;
import Toybox.Lang;

class PredictiveSparkline {

    public static function drawSparklineWithRisk(
        dc as Gfx.Dc,
        x as Number,
        y as Number,
        width as Number,
        height as Number,
        trendData as Array<Float>,       // 12 float values (e.g., surface temp or wetness)
        riskProfile as Array<RiskLevel> // 12 RiskLevel values
    ) as Void {
        var count = trendData.size();
        if (count < 2) { return; }

        var barHeight = 6;
        var sparklineH = height - barHeight - 4;
        var stepX = width.toFloat() / (count - 1);

        // --- 1. DRAW 12-HOUR RISK HEATMAP BAR ALONG THE BOTTOM ---
        var blockW = (width.toFloat() / count) + 0.5f; // Small overlap to avoid pixel gaps

        for (var i = 0; i < count; i++) {
            var blockX = x + (i * (width.toFloat() / count));
            var blockY = y + sparklineH + 2;
            var riskColor = ThemeManager.getRiskColor(riskProfile[i]);

            dc.setColor(riskColor, Gfx.COLOR_TRANSPARENT);
            dc.fillRectangle(blockX.toNumber(), blockY, blockW.toNumber(), barHeight);
        }

        // --- 2. DRAW PREDICTIVE TREND LINE OVER THE HEATMAP ---
        // Find min/max for line scaling
        var min = trendData[0];
        var max = trendData[0];
        for (var i = 1; i < count; i++) {
            if (trendData[i] < min) { min = trendData[i]; }
            if (trendData[i] > max) { max = trendData[i]; }
        }
        
        var range = (max - min == 0) ? 1.0f : (max - min);

        dc.setColor(AppState.activePalette[ThemeManager.COLOR_TEXT], Gfx.COLOR_TRANSPARENT);

        var prevX = x;
        var prevY = y + sparklineH - (((trendData[0] - min) / range) * sparklineH).toNumber();

        for (var i = 1; i < count; i++) {
            var currX = x + (i * stepX).toNumber();
            var currY = y + sparklineH - (((trendData[i] - min) / range) * sparklineH).toNumber();

            dc.drawLine(prevX, prevY, currX, currY);

            prevX = currX;
            prevY = currY;
        }
    }
}