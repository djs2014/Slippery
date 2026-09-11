import Toybox.Graphics;
import Toybox.Lang;

/// Draws the background service statistics on the screen in right bottom corner.
/// Draws a centered countdown when there are no background service requests yet.
public function drawBackgroundServiceStats(
    dc as Graphics.Dc,
    xPos as Number,
    yPos as Number,
    BGServiceHandler as BGServiceHandler,
    isSmallField as Boolean,
    onlyShowIfErrors as Boolean
) as Void {
    var handler = BGServiceHandler;

    if (
        onlyShowIfErrors &&
        handler.getRequestCounter() > 0 &&
        !handler.hasError()
    ) {
        return;
    }
    var counterStats = handler.getCounterStats();
    var hasError = handler.hasError();
    var statusText = hasError ? handler.getError() : handler.getStatus();
    var nextTime =
        $.g_bg_delay_seconds > 0
            ? $.g_bg_delay_seconds.format("%d")
            : handler.getWhenNextRequest("");

    // --- 1. BUILD CORNER STATS STRING ---
    var stats = "";
    if (isSmallField) {
        stats = "#" + counterStats;
    } else {
        var errMsg = handler.getErrorMessage();
        // Single formatted assembly to minimize string fragment allocations
        stats = Lang.format("$1$ #$2$ $3$($4$)", [
            errMsg,
            counterStats,
            statusText,
            nextTime,
        ]);
    }

    var textColor = AppState.activePalette[ThemeManager.COLOR_TEXT];
    var backColor = AppState.activePalette[ThemeManager.COLOR_BG];

    // Measure once
    var statsWH = dc.getTextDimensions(stats, Graphics.FONT_XTINY);
    var textW = statsWH[0];
    var textH = statsWH[1];

    // Blank background for the stats text
    dc.setColor(backColor, Graphics.COLOR_TRANSPARENT);
    dc.fillRoundedRectangle(
        xPos - textW - 4,
        yPos - textH - 2,
        textW + 8,
        textH + 4,
        4
    );

    dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
    dc.drawText(
        xPos,
        yPos - textH,
        Graphics.FONT_XTINY,
        stats,
        Graphics.TEXT_JUSTIFY_RIGHT
    );

    // --- 2. CENTERED OVERLAY FOR INITIAL STATE ---
    if (handler.getRequestCounter() == 0) {
        var overlayText = "";
        if (handler.isDisabled()) {
            overlayText = "App paused!";
        } else {
            var errMsg = handler.getErrorMessage();
            overlayText = Lang.format("$1$ $2$($3$)", [
                errMsg,
                statusText,
                nextTime,
            ]);
        }

        var font = Graphics.FONT_SYSTEM_SMALL;
        var centerWH = dc.getTextDimensions(overlayText, font);
        var cW = centerWH[0];
        var cH = centerWH[1];

        var centerX = dc.getWidth() / 2;
        var centerY = dc.getHeight() / 2;

        var boxX = centerX - cW / 2 - 5;
        var boxY = centerY - cH / 2 - 3;
        var boxW = cW + 10;
        var boxH = cH + 6;

        // Draw background box fill
        dc.setColor(backColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(boxX, boxY, boxW, boxH, 4);

        // Draw crisp 1px border line directly instead of double fill
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(boxX, boxY, boxW, boxH, 4);

        dc.drawText(
            centerX,
            centerY,
            font,
            overlayText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }
}
