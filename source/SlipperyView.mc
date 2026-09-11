import Toybox.Activity;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Graphics;

class SlipperyView extends WatchUi.DataField {
    var mBGServiceHandler as BGServiceHandler;
    var mCurrentLocation as CurrentLocation = new CurrentLocation();
    var mEdgeField as EdgeField = EfSmall;
    var mIsDark as Boolean = false;
    var mLat as Float = 0.0;
    var mAppName = "Slippery";

    private var mWeatherMetrics as WeatherMetrics;
    private var mRiskAssessment as RiskAssessment;
    private var mHasWeatherData as Boolean = false; // TODO then all color grey

    private var mMinutesUntilSecondsCounter as Number = 0;
    private var mMinutesUntilRain as Number = -1;
    private var mMinutesUntilSnow as Number = -1;

    hidden var mFontsNumbers as Array = [
        Graphics.FONT_XTINY,
        Graphics.FONT_TINY,
        Graphics.FONT_SYSTEM_SMALL,
        Graphics.FONT_SYSTEM_MEDIUM,
        Graphics.FONT_SYSTEM_LARGE,
        Graphics.FONT_NUMBER_MILD,
        Graphics.FONT_NUMBER_MEDIUM,
        Graphics.FONT_NUMBER_HOT,
        Graphics.FONT_NUMBER_THAI_HOT,
    ];

    function initialize() {
        DataField.initialize();
        mWeatherMetrics = new WeatherMetrics();
        mRiskAssessment = new RiskAssessment();

        $.checkFeatures();

        mCurrentLocation.setOnLocationChanged(self, :onLocationChanged);
        mBGServiceHandler = getApp().getBGServiceHandler();
        mBGServiceHandler.setOnBackgroundData(self, :onBackgroundData);
        mBGServiceHandler.setCurrentLocation(mCurrentLocation);

        // trigger to get optional cached location
        onLocationChanged(mCurrentLocation.getCurrentDegrees());
    }

    function onLocationChanged(degrees as Array<Double>) as Void {
        mLat = degrees[0].toFloat();
        System.println("Latitude updated to: " + mLat);
    }

    function onBackgroundData(data as Dictionary?) as Void {
        var weatherMetrics = $.parseOpenMeteoResponse(mLat, data);
        if (weatherMetrics == null) {
            return;
        }
        mHasWeatherData = true;
        System.println(weatherMetrics.toString());
        mWeatherMetrics = weatherMetrics;
        mRiskAssessment =
            WeatherService.calculateRiskAssessment(weatherMetrics);
        System.println(mRiskAssessment.toString());

        initializeMinutesUntilCounters();
    }

    // Set your layout here. Anytime the size of obscurity of
    // the draw context is changed this will be called.
    function onLayout(dc as Dc) as Void {
        dc.clearClip();

        mEdgeField = $.getEdgeField(dc);
    }

    function compute(info as Activity.Info) as Void {
        mBGServiceHandler.onCompute(info);
        if ($.g_bg_delay_seconds <= 0) {
            mBGServiceHandler.autoScheduleService();
        } else {
            $.g_bg_delay_seconds = $.g_bg_delay_seconds - 1;
        }
        processMinutesUntilCounters();
    }

    function initializeMinutesUntilCounters() as Void {
        if (mWeatherMetrics.immediateRain < 0) {
            mMinutesUntilRain = -1;
        } else {
            mMinutesUntilRain = mWeatherMetrics.immediateRain * 15;
        }
        if (mWeatherMetrics.immediateSnow < 0) {
            mMinutesUntilSnow = -1;
        } else {
            mMinutesUntilSnow = mWeatherMetrics.immediateSnow * 15;
        }        
        mMinutesUntilSecondsCounter = 0;
    }

    // This will called every second
    function processMinutesUntilCounters() as Void {
        // If a minute counter is active, decrement it
        // Increment the seconds counter
        mMinutesUntilSecondsCounter = mMinutesUntilSecondsCounter + 1;
        if (mMinutesUntilSecondsCounter >= 60) {
            mMinutesUntilSecondsCounter = 0;
            if (mMinutesUntilRain > 0) {
                mMinutesUntilRain = mMinutesUntilRain - 1;
            }
            if (mMinutesUntilSnow > 0) {
                mMinutesUntilSnow = mMinutesUntilSnow - 1;
            }
        }        
    }

    function onUpdate(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        mIsDark = getBackgroundColor() == Graphics.COLOR_BLACK;

        // 1. Clear background
        dc.setColor(getBackgroundColor(), getBackgroundColor());
        dc.clear();

        if (mEdgeField == EfOne) {
            drawEdgeOneFieldWithSparkline(dc, width, height, mIsDark);
        } else if (mEdgeField == EfSmall) {
            drawEdgeSmallFieldWithSparkline(dc, width, height, mIsDark);
        } else if (mEdgeField == EfLarge) {
            drawEdgeLargeFieldWithSparkline(dc, width, height, mIsDark);
        } else if (mEdgeField == EfWide) {
            drawEdgeWideFieldWithSparkline(dc, width, height, mIsDark);
        }

        if (
            mBGServiceHandler.getRequestCounter() > 0 &&
            !mBGServiceHandler.hasError()
        ) {
            return;
        }
        // TODO sep method or refactor a bit to improve readability
        var stats = "";
        if (mEdgeField == EfSmall) {
            stats = "#" + mBGServiceHandler.getCounterStats();
        } else {
            var counter = "#" + mBGServiceHandler.getCounterStats();
            var next = mBGServiceHandler.getWhenNextRequest("");
            if ($.g_bg_delay_seconds > 0) {
                next = $.g_bg_delay_seconds.format("%d");
            }
            var status = "";
            if (mBGServiceHandler.hasError()) {
                status = mBGServiceHandler.getError();
            } else {
                status = mBGServiceHandler.getStatus();
            }
            stats =
                mBGServiceHandler.getErrorMessage() +
                " " +
                counter +
                " " +
                status +
                "(" +
                next +
                ")";
        }

        var textColor = ThemeManager.getThemeColor(:text, mIsDark);
        var backColor = ThemeManager.getThemeColor(:background, mIsDark);

        var statsWH = dc.getTextDimensions(stats, Graphics.FONT_XTINY);
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            width,
            height - statsWH[1],
            Graphics.FONT_XTINY,
            stats,
            Graphics.TEXT_JUSTIFY_RIGHT
        );

        if (mBGServiceHandler.getRequestCounter() == 0) {
            // No data yet
            var next = mBGServiceHandler.getWhenNextRequest("");
            var status = "";
            if (mBGServiceHandler.hasError()) {
                status = mBGServiceHandler.getError();
            } else {
                status = mBGServiceHandler.getStatus();
            }
            stats =
                mBGServiceHandler.getErrorMessage() +
                " " +
                status +
                "(" +
                next +
                ")";
            if (mBGServiceHandler.isDisabled()) {
                stats = "App paused!";
            }
            // Draw rounded border around the stats text (if needed)
            statsWH = dc.getTextDimensions(stats, Graphics.FONT_SYSTEM_SMALL);
            dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(
                (width - statsWH[0]) / 2 - 6,
                (height - statsWH[1]) / 2 - 4,
                statsWH[0] + 12,
                statsWH[1] + 8,
                4
            );
            dc.setColor(backColor, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(
                (width - statsWH[0]) / 2 - 4,
                (height - statsWH[1]) / 2 - 2,
                statsWH[0] + 8,
                statsWH[1] + 4,
                4
            );

            dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                width / 2,
                height / 2,
                Graphics.FONT_SYSTEM_SMALL,
                stats,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }
    }

    private function drawEdgeSmallFieldWithSparkline(
        dc as Graphics.Dc,
        width as Number,
        height as Number,
        isDark as Boolean
    ) as Void {
        // 1. Reserve bottom 10% of total height for the 12h Sparkline
        var sparklineHeight = (height * 0.1).toNumber();
        var topGridHeight = height - sparklineHeight;

        // Minimum height check: ensure sparkline gets at least 20px to render legibly
        if (sparklineHeight < 20) {
            sparklineHeight = 20;
            topGridHeight = height - sparklineHeight;
        }

        // 2. Draw Top Metrics Section (y = 0 to topGridHeight)
        drawEdgeSmallField(dc, 0, 0, width, topGridHeight, isDark);

        // 3. Draw Divider Line
        var dividerColor = isDark
            ? Graphics.COLOR_DK_GRAY
            : Graphics.COLOR_LT_GRAY;
        dc.setColor(dividerColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(4, topGridHeight, width - 4, topGridHeight);

        // 4. Draw Bottom Sparkline Section (y = topGridHeight to h)
        // Add 4px horizontal padding on left/right so edges don't touch screen bezels
        var paddingX = 6;
        PredictiveSparkline.draw(
            dc,
            paddingX,
            topGridHeight + 2,
            width - paddingX * 2,
            sparklineHeight - 4,
            mWeatherMetrics,
            isDark,
            false
        );
    }
    private function drawEdgeOneFieldWithSparkline(
        dc as Graphics.Dc,
        width as Number,
        height as Number,
        isDark as Boolean
    ) as Void {
        // 1. Reserve bottom 25% of total height for the 12h Sparkline
        var sparklineHeight = (height * 0.2).toNumber();
        var topGridHeight = height - sparklineHeight;

        // Minimum height check: ensure sparkline gets at least 32px to render legibly
        if (sparklineHeight < 32) {
            sparklineHeight = 32;
            topGridHeight = height - sparklineHeight;
        }

        // 2. Draw Top Metrics Section (y = 0 to topGridHeight)
        drawEdgeOneField(dc, 0, 0, width, topGridHeight, isDark);

        // 3. Draw Divider Line
        var dividerColor = isDark
            ? Graphics.COLOR_DK_GRAY
            : Graphics.COLOR_LT_GRAY;
        dc.setColor(dividerColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(4, topGridHeight, width - 4, topGridHeight);

        // 4. Draw Bottom Sparkline Section (y = topGridHeight to h)
        // Add 4px horizontal padding on left/right so edges don't touch screen bezels
        var paddingX = 6;
        PredictiveSparkline.draw(
            dc,
            paddingX,
            topGridHeight + 2,
            width - paddingX * 2,
            sparklineHeight - 4,
            mWeatherMetrics,
            isDark,
            true
        );
    }
    private function drawEdgeLargeFieldWithSparkline(
        dc as Graphics.Dc,
        width as Number,
        height as Number,
        isDark as Boolean
    ) as Void {
        // 1. Reserve bottom 25% of total height for the 12h Sparkline
        var sparklineHeight = (height * 0.25).toNumber();
        var topGridHeight = height - sparklineHeight;

        // Minimum height check: ensure sparkline gets at least 32px to render legibly
        if (sparklineHeight < 32) {
            sparklineHeight = 32;
            topGridHeight = height - sparklineHeight;
        }

        // 2. Draw Top Metrics Section (y = 0 to topGridHeight)
        drawEdgeLargeField(dc, 0, 0, width, topGridHeight, isDark);

        // 3. Draw Divider Line
        var dividerColor = isDark
            ? Graphics.COLOR_DK_GRAY
            : Graphics.COLOR_LT_GRAY;
        dc.setColor(dividerColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(4, topGridHeight, width - 4, topGridHeight);

        // 4. Draw Bottom Sparkline Section (y = topGridHeight to h)
        // Add 4px horizontal padding on left/right so edges don't touch screen bezels
        var paddingX = 6;
        PredictiveSparkline.draw(
            dc,
            paddingX,
            topGridHeight + 2,
            width - paddingX * 2,
            sparklineHeight - 4,
            mWeatherMetrics,
            isDark,
            true
        );
    }

    private function drawEdgeWideFieldWithSparkline(
        dc as Graphics.Dc,
        width as Number,
        height as Number,
        isDark as Boolean
    ) as Void {
        // 1. Reserve bottom 42% of total height for the 12h Sparkline
        var sparklineHeight = (height * 0.42).toNumber();
        var topGridHeight = height - sparklineHeight;

        // Minimum height check: ensure sparkline gets at least 32px to render legibly
        if (sparklineHeight < 32) {
            sparklineHeight = 32;
            topGridHeight = height - sparklineHeight;
        }

        // 2. Draw Top Metrics Section (y = 0 to topGridHeight)
        drawEdgeWideField(dc, 0, 0, width, topGridHeight, isDark);

        // 3. Draw Divider Line
        var dividerColor = isDark
            ? Graphics.COLOR_DK_GRAY
            : Graphics.COLOR_LT_GRAY;
        dc.setColor(dividerColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(4, topGridHeight, width - 4, topGridHeight);

        // 4. Draw Bottom Sparkline Section (y = topGridHeight to h)
        // Add 4px horizontal padding on left/right so edges don't touch screen bezels
        var paddingX = 6;
        PredictiveSparkline.draw(
            dc,
            paddingX,
            topGridHeight + 2,
            width - paddingX * 2,
            sparklineHeight - 4,
            mWeatherMetrics,
            isDark,
            true
        );
    }
   
    private function drawEdgeOneField(
        dc as Graphics.Dc,
        x as Number,
        y as Number,
        w as Number,
        h as Number,
        isDark as Boolean
    ) as Void {
        var riskColor = getRiskColor(mRiskAssessment.riskLevel, isDark);
        var riskLevelText = getRiskLevelString(mRiskAssessment.riskLevel);
        var isRiskColorLight = $.isColorLight(riskColor);
        var riskTextColor = isRiskColorLight
            ? Graphics.COLOR_BLACK
            : Graphics.COLOR_WHITE;

        var textColor = ThemeManager.getThemeColor(:text, isDark);
        // --- DRAW HEADER BAR ---
        var headerHeight = (h * 0.22).toNumber();
        dc.setColor(riskColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, w, headerHeight);

        // --- TOP BAR: App Title + Risk Level ---
        var headerLineHeight = Graphics.getFontHeight(Graphics.FONT_SMALL);

        dc.setColor(riskTextColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x + 6,
            y + (headerHeight - headerLineHeight) / 2,
            Graphics.FONT_SMALL,
            mAppName,
            Graphics.TEXT_JUSTIFY_LEFT 
        );

        var centerHeaderY = y + (headerHeight - headerLineHeight) / 2; 
        dc.drawText(
            x + w - 6,
            centerHeaderY,
            Graphics.FONT_SMALL,
            riskLevelText,
            Graphics.TEXT_JUSTIFY_RIGHT 
        );

        // --- BOTTOM ROW: Dynamic Full-Width Rain Warning Strip ---
        if (
            (mMinutesUntilRain >= 0 && mMinutesUntilRain <= 45) ||
            (mMinutesUntilSnow >= 0 && mMinutesUntilSnow <= 45)
        ) {
            var alertY = centerHeaderY + headerLineHeight + 4;
            var alertLineHeight = Graphics.getFontHeight(Graphics.FONT_XTINY);
            var alertH = alertLineHeight + 4;
            
            dc.setColor(0x0088cc, Graphics.COLOR_TRANSPARENT); // Deep Cyan
            dc.fillRectangle(x, alertY, w, alertH);
            dc.setColor(
                Graphics.COLOR_WHITE,
                Graphics.COLOR_TRANSPARENT
            );
            dc.drawText(
                x + w / 2,
                alertY + alertH / 2,
                Graphics.FONT_XTINY,
                $.getPrecipitationAlertMessage(
                    mMinutesUntilRain,
                    mMinutesUntilSnow
                ),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }

        // --- DRAW 2x2 METRICS GRID ---
        var gridTop = headerHeight + 4;
        var gridHeight = (h * 0.45).toNumber();
        var colWidth = w / 2;
        var rowHeight = gridHeight / 2;

        var labelColor = ThemeManager.getThemeColor(:label, isDark);

        // Cell 1: Air Temp
        drawGridCell(
            dc,
            x,
            y + gridTop,
            colWidth,
            rowHeight,
            "AIR TEMP",
            Lang.format("$1$°C", [mWeatherMetrics.airTemp.format("%.1f")]),
            labelColor,
            mWeatherMetrics.airTemp <= 0 ? Graphics.COLOR_RED : textColor
        );

        // Cell 2: Surface Temp
        drawGridCell(
            dc,
            x + colWidth,
            y + gridTop,
            colWidth,
            rowHeight,
            "SURFACE",
            Lang.format("$1$°C", [mWeatherMetrics.surfaceTemp.format("%.1f")]),
            labelColor,
            mWeatherMetrics.surfaceTemp <= 0 ? Graphics.COLOR_RED : textColor
        );

        // Cell 3: Dew Point
        drawGridCell(
            dc,
            x,
            y + gridTop + rowHeight,
            colWidth,
            rowHeight,
            "DEW POINT",
            Lang.format("$1$°C", [mWeatherMetrics.dewPoint.format("%.1f")]),
            labelColor,
            textColor
        );

        // Cell 4: Humidity
        drawGridCell(
            dc,
            x + colWidth,
            y + gridTop + rowHeight,
            colWidth,
            rowHeight,
            "HUMIDITY",
            Lang.format("$1$%", [mWeatherMetrics.humidity]),
            labelColor,
            mWeatherMetrics.humidity >= 80 ? Graphics.COLOR_RED : textColor
        );

        // Grid Separator Lines
        dc.setColor(labelColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(
            x + colWidth,
            y + gridTop,
            x + colWidth,
            y + gridTop + gridHeight
        ); // Vertical
        dc.drawLine(x, y + gridTop + rowHeight, x + w, y + gridTop + rowHeight); // Horizontal
        dc.drawLine(
            x,
            y + gridTop + gridHeight,
            x + w,
            y + gridTop + gridHeight
        ); // Bottom

        // --- DRAW FOOTER: HAZARD & ADVICE TEXT ---
        var lineHeight = Graphics.getFontHeight(Graphics.FONT_XTINY);
        var linePos = gridTop + gridHeight;
        if (mRiskAssessment.hazards.size() > 0) {
            for (var i = 0; i < mRiskAssessment.hazards.size(); i++) {
                linePos += lineHeight;
                var hazardStr = getHazardString(mRiskAssessment.hazards[i]);
                dc.setColor(
                    mIsDark ? 0xe5ff00 : 0xb38f00,
                    Graphics.COLOR_TRANSPARENT
                );
                dc.drawText(
                    w / 2,
                    linePos,
                    Graphics.FONT_XTINY,
                    hazardStr,
                    Graphics.TEXT_JUSTIFY_CENTER
                );
            }
        }

        if (mRiskAssessment.advice.size() > 0) {
            for (var i = 0; i < mRiskAssessment.advice.size(); i++) {
                linePos += lineHeight;
                var adviceStr = getAdviceString(mRiskAssessment.advice[i]);

                dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
                dc.drawText(
                    w / 2,
                    linePos,
                    Graphics.FONT_XTINY,
                    adviceStr,
                    Graphics.TEXT_JUSTIFY_CENTER
                );
            }
        }
    }

    private function drawGridCell(
        dc as Graphics.Dc,
        x as Number,
        y as Number,
        w as Number,
        h as Number,
        label as String,
        value as String,
        labelColor as Number,
        valueColor as Number
    ) as Void {
        // Label
        dc.setColor(labelColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x + w / 2,
            y + 2,
            Graphics.FONT_XTINY,
            label,
            Graphics.TEXT_JUSTIFY_CENTER
        );

        // Value
        dc.setColor(valueColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x + w / 2,
            y + h / 2,
            Graphics.FONT_NUMBER_MILD,
            value,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    function drawEdgeSmallField(
        dc as Graphics.Dc,
        x as Number,
        y as Number,
        w as Number,
        h as Number,
        isDark as Boolean
    ) as Void {
        var riskColor = getRiskColor(mRiskAssessment.riskLevel, isDark);
        var isRiskColorLight = $.isColorLight(riskColor);
        var badgeTextColor = isRiskColorLight
            ? Graphics.COLOR_BLACK
            : Graphics.COLOR_WHITE;

        // Left 30%: Solid risk badge
        var badgeWidth = (w * 0.3).toNumber();
        dc.setColor(riskColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, badgeWidth, h);

        var headerText = getImminentPrecipitationText();
        if (headerText == "") {
            headerText = getShortRiskLabel(mRiskAssessment.riskLevel);
        }
        dc.setColor(badgeTextColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x + badgeWidth / 2,
            y + h / 2,
            Graphics.FONT_TINY,
            headerText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        // Right 70%: Surface Temp & Primary Hazard
        var textX = badgeWidth + 6;
        var textColor = isDark ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;

        var yOffset = 2;
        var lineHeight = dc.getFontHeight(Graphics.FONT_XTINY) + 1;
        // 1: Air Temperature
        var airStr = Lang.format("AIR $1$°C", [
            mWeatherMetrics.airTemp.format("%.1f"),
        ]);
        dc.setColor(
            mWeatherMetrics.airTemp <= 0 ? Graphics.COLOR_RED : textColor,
            Graphics.COLOR_TRANSPARENT
        );
        dc.drawText(
            textX,
            y + yOffset,
            Graphics.FONT_XTINY,
            airStr,
            Graphics.TEXT_JUSTIFY_LEFT
        );

        // 2: Surface Temperature
        var surfStr = Lang.format("SURF $1$°C", [
            mWeatherMetrics.surfaceTemp.format("%.1f"),
        ]);
        dc.setColor(
            mWeatherMetrics.surfaceTemp <= 0 ? Graphics.COLOR_RED : textColor,
            Graphics.COLOR_TRANSPARENT
        );
        dc.drawText(
            textX,
            y + yOffset + lineHeight,
            Graphics.FONT_XTINY,
            surfStr,
            Graphics.TEXT_JUSTIFY_LEFT
        );
        // 3: Humidity
        var humidityStr = Lang.format("HUM $1$%", [
            mWeatherMetrics.humidity.format("%.1f"),
        ]);
        dc.setColor(
            mWeatherMetrics.humidity >= 80 ? Graphics.COLOR_RED : textColor,
            Graphics.COLOR_TRANSPARENT
        );
        dc.drawText(
            textX,
            y + yOffset + 2 * lineHeight,
            Graphics.FONT_XTINY,
            humidityStr,
            Graphics.TEXT_JUSTIFY_LEFT
        );

        // 4: All Hazard strings (shortened)
        if (mRiskAssessment.hazards.size() > 0) {
            for (var i = 0; i < mRiskAssessment.hazards.size(); i += 1) {
                var hazardStr = getShortHazardString(
                    mRiskAssessment.hazards[i]
                );
                dc.setColor(
                    isDark ? Graphics.COLOR_LT_GRAY : Graphics.COLOR_DK_GRAY,
                    Graphics.COLOR_TRANSPARENT
                );
                dc.drawText(
                    textX,
                    y + h - lineHeight - i * lineHeight,
                    Graphics.FONT_XTINY,
                    hazardStr,
                    Graphics.TEXT_JUSTIFY_LEFT
                );
            }
        }
    }

    function drawEdgeWideField(
        dc as Graphics.Dc,
        x as Number,
        y as Number,
        w as Number,
        h as Number,
        isDark as Boolean
    ) as Void {
        var riskColor = getRiskColor(mRiskAssessment.riskLevel, isDark);
        var riskLabel = getRiskLevelString(mRiskAssessment.riskLevel);
        var textColor = isDark ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        var labelColor = isDark
            ? Graphics.COLOR_LT_GRAY
            : Graphics.COLOR_DK_GRAY;

        // Left Column (35%): Risk Block & Hazard
        var leftWidth = (w * 0.35).toNumber();
        dc.setColor(riskColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, leftWidth, (h * 0.55).toNumber());

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x + leftWidth / 2,
            y + (h * 0.27).toNumber(),
            Graphics.FONT_MEDIUM,
            riskLabel,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        // Hazard text underneath badge
        if (mRiskAssessment.hazards.size() > 0) {
            var lineHeight = Graphics.getFontHeight(Graphics.FONT_XTINY);
            for (var i = 0; i < mRiskAssessment.hazards.size(); i++) {
                var hazardStr = getShortHazardString(
                    mRiskAssessment.hazards[i]
                );
                dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
                dc.drawText(
                    x + 2,
                    y + h - lineHeight * (mRiskAssessment.hazards.size() - i),
                    Graphics.FONT_XTINY,
                    hazardStr,
                    Graphics.TEXT_JUSTIFY_LEFT
                );
            }
            // dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
            // dc.drawText(
            //     x + 2,
            //     y + h - lineHeight,
            //     Graphics.FONT_XTINY,
            //     getShortHazardString(mRiskAssessment.hazards[0]),
            //     Graphics.TEXT_JUSTIFY_LEFT
            // );
        }

        // Divider Line
        dc.setColor(labelColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x + leftWidth, y, x + leftWidth, y + h);

        // Right Column (65%): 3 Metrics Side-by-Side
        var rightX = leftWidth;
        var colW = (w - leftWidth) / 3;

        // Col 1: Air Temp
        drawMetricColumn(
            dc,
            x + rightX,
            y,
            colW,
            h,
            "AIR",
            Lang.format("$1$°C", [mWeatherMetrics.airTemp.format("%.1f")]),
            labelColor,
            textColor
        );

        // Col 2: Surface Temp
        var surfColor =
            mWeatherMetrics.surfaceTemp <= 0 ? Graphics.COLOR_RED : textColor;
        drawMetricColumn(
            dc,
            x + rightX + colW,
            y,
            colW,
            h,
            "SURFACE",
            Lang.format("$1$°C", [mWeatherMetrics.surfaceTemp.format("%.1f")]),
            labelColor,
            surfColor
        );

        // Col 3: Dew Point
        drawMetricColumn(
            dc,
            x + rightX + colW * 2,
            y,
            colW,
            h,
            "DEW PT",
            Lang.format("$1$°C", [mWeatherMetrics.dewPoint.format("%.1f")]),
            labelColor,
            textColor
        );
    }

    function drawEdgeLargeField(
        dc as Graphics.Dc,
        x as Number,
        y as Number,
        w as Number,
        h as Number,
        isDark as Boolean
    ) as Void {
        var textColor = isDark ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        var labelColor = isDark
            ? Graphics.COLOR_LT_GRAY
            : Graphics.COLOR_DK_GRAY;

        // 1. Header Banner (Risk Level)
        var headerH = (h * 0.16).toNumber();
        dc.setColor(
            getRiskColor(mRiskAssessment.riskLevel, isDark),
            Graphics.COLOR_TRANSPARENT
        );
        dc.fillRectangle(x, y, w, headerH);

        var htHeight = dc.getFontHeight(Graphics.FONT_LARGE);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x + w / 2,
            y + headerH - htHeight,
            Graphics.FONT_LARGE,
            getRiskLevelString(mRiskAssessment.riskLevel),
            Graphics.TEXT_JUSTIFY_CENTER // | Graphics.TEXT_JUSTIFY_VCENTER
        );

        // 2. Main 2x2 Grid
        var gridY = y + headerH + 4;
        var gridH = (h * 0.5).toNumber();
        var halfW = w / 2;
        var rowH = gridH / 2;

        drawGridCell(
            dc,
            x,
            gridY,
            halfW,
            rowH,
            "AIR TEMP",
            Lang.format("$1$°C", [mWeatherMetrics.airTemp.format("%.1f")]),
            labelColor,
            mWeatherMetrics.airTemp <= 0 ? Graphics.COLOR_RED : textColor
        );
        drawGridCell(
            dc,
            x + halfW,
            gridY,
            halfW,
            rowH,
            "SURFACE TEMP",
            Lang.format("$1$°C", [mWeatherMetrics.surfaceTemp.format("%.1f")]),
            labelColor,
            mWeatherMetrics.surfaceTemp <= 0 ? Graphics.COLOR_RED : textColor
        );
        drawGridCell(
            dc,
            x,
            gridY + rowH,
            halfW,
            rowH,
            "DEW POINT",
            Lang.format("$1$°C", [mWeatherMetrics.dewPoint.format("%.1f")]),
            labelColor,
            textColor
        );
        drawGridCell(
            dc,
            x + halfW,
            gridY + rowH,
            halfW,
            rowH,
            "HUMIDITY",
            Lang.format("$1$%", [mWeatherMetrics.humidity]),
            labelColor,
            mWeatherMetrics.humidity >= 80 ? Graphics.COLOR_RED : textColor
        );

        // Grid Dividers
        dc.setColor(labelColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x + halfW, gridY, x + halfW, gridY + gridH);
        dc.drawLine(x, gridY + rowH, x + w, gridY + rowH);
        dc.drawLine(x, gridY + gridH, x + w, gridY + gridH);

        // 3. Secondary Environmental Context Strip
        // var stripY = gridY + gridH + 6;
        // var stripStr = Lang.format("Dry: $1$h | Precip: $2$mm | Season: $3$", [
        //     mWeatherMetrics.dryStreak,
        //     mWeatherMetrics.precip12hSum.format("%.1f"),
        //     getSeasonString(mWeatherMetrics.currentSeason),
        // ]);
        // dc.setColor(labelColor, Graphics.COLOR_TRANSPARENT);
        // dc.drawText(
        //     x + w / 2,
        //     stripY,
        //     Graphics.FONT_XTINY,
        //     stripStr,
        //     Graphics.TEXT_JUSTIFY_CENTER
        // );
        var lineHeight = dc.getFontHeight(Graphics.FONT_XTINY);
        // 4. Hazards & Advice Section
        // var footerY = stripY + 22;
        var footerY = gridY + gridH;
        dc.setColor(isDark ? 0xe5ff00 : 0xb38f00, Graphics.COLOR_TRANSPARENT);

        // Primary & Secondary Hazards
        if (mRiskAssessment.hazards.size() > 0) {
            var h1 = getHazardString(mRiskAssessment.hazards[0]);
            var h2 =
                mRiskAssessment.hazards.size() > 1
                    ? " / " + getHazardString(mRiskAssessment.hazards[1])
                    : "";
            dc.drawText(
                x + w / 2,
                footerY,
                Graphics.FONT_XTINY,
                h1 + h2,
                Graphics.TEXT_JUSTIFY_CENTER
            );
            if (mRiskAssessment.hazards.size() > 2) {
                footerY += lineHeight;
                var h3 = getHazardString(mRiskAssessment.hazards[2]);
                var h4 =
                    mRiskAssessment.hazards.size() > 3
                        ? " / " + getHazardString(mRiskAssessment.hazards[3])
                        : "";
                dc.drawText(
                    x + w / 2,
                    footerY,
                    Graphics.FONT_XTINY,
                    h3 + h4,
                    Graphics.TEXT_JUSTIFY_CENTER
                );
            }
        }
        // Actionable Advice
        if (mRiskAssessment.advice.size() > 0) {
            footerY += lineHeight;
            dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
            var a1 = getAdviceString(mRiskAssessment.advice[0]);
            dc.drawText(
                x + w / 2,
                footerY,
                Graphics.FONT_XTINY,
                a1,
                Graphics.TEXT_JUSTIFY_CENTER
            );
            if (mRiskAssessment.advice.size() > 1) {
                footerY += lineHeight;
                var a2 = getAdviceString(mRiskAssessment.advice[1]);
                dc.drawText(
                    x + w / 2,
                    footerY,
                    Graphics.FONT_XTINY,
                    a2,
                    Graphics.TEXT_JUSTIFY_CENTER
                );
            }
        }
    }

    private function drawMetricColumn(
        dc as Graphics.Dc,
        x as Number,
        y as Number,
        colWidth as Number,
        height as Number,
        label as String,
        value as String,
        labelColor as Number,
        valueColor as Number
    ) as Void {
        var centerX = x + colWidth / 2;

        // 1. Draw Metric Label (Small / XTiny at the top)
        dc.setColor(labelColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            centerX,
            y + 4,
            Graphics.FONT_XTINY,
            label,
            Graphics.TEXT_JUSTIFY_CENTER
        );

        // 2. Draw Metric Value (Mild/Medium font centered vertically in remaining space)

        var font =
            $.getMatchingFont(dc, mFontsNumbers, colWidth, height, value) as
            FontType;

        dc.setColor(valueColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            centerX,
            y + (height * 0.58).toNumber(),
            font,
            value,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        // 3. Optional Right Divider Line
        dc.setColor(labelColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x + colWidth, y + 4, x + colWidth, y + height - 4);
    }

    function getImminentPrecipitationText() as String {
        if (mMinutesUntilSnow > 0 && mMinutesUntilSnow <= 30) {
            return mMinutesUntilSnow == 0
                ? "SNOW NOW"
                : "SNOW IN " + mMinutesUntilSnow + "M";
        }
        if (mMinutesUntilRain > 0 && mMinutesUntilRain <= 30) {
            return mMinutesUntilRain == 0
                ? "RAIN NOW"
                : "RAIN IN " + mMinutesUntilRain + "M";
        }
        return "";
    }
}

function getMatchingFont(
    dc as Dc,
    fontList as Array,
    maxWidth as Number,
    maxHeight as Number,
    text as String
) as FontType {
    var index = fontList.size() - 1;
    var font = fontList[index] as FontType;
    // System.println(Lang.format("text[$1$] max w[$2$]h[$3$]",[text, maxWidth, maxHeight]));
    // wxh
    var dimensions = dc.getTextDimensions(text, font);
    // System.println(Lang.format(" dim w[$1$]h[$2$]",dimensions));
    // while height or width of font too big, find another font
    while (
        (dimensions[0] > maxWidth || dimensions[1] > maxHeight) &&
        index > 0
    ) {
        index = index - 1;
        font = fontList[index] as FontType;
        dimensions = dc.getTextDimensions(text, font);
        // System.println(Lang.format(" dim w[$1$]h[$2$]",dimensions));
    }
    // System.println("font index: " + index);
    return font;
}
