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
    private var mHazardStrings as Array<String> = [];
    private var mAdviceStrings as Array<String> = [];

    private var mMinutesUntilSecondsCounter as Number = 0;
    private var mMinutesUntilRain as Number = -1;
    private var mMinutesUntilSnow as Number = -1;

    hidden var mAlertProcessedForLevel as RiskLevel = RiskLevelNoData;
    hidden var mToastIcon as BitmapResource?;

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

        setHazardAndAdviceStrings();
        initializeMinutesUntilCounters();
        WatchUi.requestUpdate();
    }

    function setHazardAndAdviceStrings() as Void {
        var hazardStrings = [];
        for (var i = 0; i < mRiskAssessment.hazards.size(); i++) {
            hazardStrings.add(getHazardString(mRiskAssessment.hazards[i]));
        }
        var adviceStrings = [];
        for (var i = 0; i < mRiskAssessment.advice.size(); i++) {
            adviceStrings.add(getAdviceString(mRiskAssessment.advice[i]));
        }
        // Atomic swap: Single pointer assignment is thread-safe
        mHazardStrings = hazardStrings;
        mAdviceStrings = adviceStrings;
    }

    // Set your layout here. Anytime the size of obscurity of
    // the draw context is changed this will be called.
    function onLayout(dc as Dc) as Void {
        dc.clearClip();

        mEdgeField = $.getEdgeField(dc);
    }

    var demoCounter as Number = 0;
    var recalcRiskAssessment as Boolean = false;
    function compute(info as Activity.Info) as Void {
        if ($.gDemo) {
            recalcRiskAssessment = true;
            mRiskAssessment =
                DemoWeatherService.getDemoRiskAssessment(demoCounter);
            demoCounter = demoCounter + 1;
            if (demoCounter > 50) {
                demoCounter = 0;
                $.gDemo = false;
                recalcRiskAssessment = false;
                // Get the current risk assessment based on the actual weather metrics
                mRiskAssessment =
                    WeatherService.calculateRiskAssessment(mWeatherMetrics);
            }
        }
        if (recalcRiskAssessment) {
            // Demo cancelled
            mRiskAssessment =
                DemoWeatherService.getDemoRiskAssessment(demoCounter);
        }

        mBGServiceHandler.onCompute(info);
        if ($.g_bg_delay_seconds <= 0) {
            mBGServiceHandler.autoScheduleService();
        } else {
            $.g_bg_delay_seconds = $.g_bg_delay_seconds - 1;
        }
        processMinutesUntilCounters();
        processAlerts();
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

    function processAlerts() as Void {
        if (mRiskAssessment.riskLevel > mAlertProcessedForLevel) {
            mAlertProcessedForLevel = mRiskAssessment.riskLevel;
            // Add your alert processing logic here
            Toybox.System.println("Alert for " + mRiskAssessment.riskLevel);
            if ($.gBeepOnAlert) {
                playAlert();
            }
            if ($.gToastOnAlert) {
                showToastForAlert();
            }
        } else if (mRiskAssessment.riskLevel != mAlertProcessedForLevel) {
            // Reset to current risk level
            mAlertProcessedForLevel = mRiskAssessment.riskLevel;
            Toybox.System.println(
                "Reset alert processing to level " + mAlertProcessedForLevel
            );
        }
    }

    function onUpdate(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        mIsDark = getBackgroundColor() == Graphics.COLOR_BLACK;

        AppState.updateTheme(mIsDark);

        // 1. Clear background
        dc.setColor(getBackgroundColor(), getBackgroundColor());
        dc.clear();

        if (mHasWeatherData) {
            if (mEdgeField == EfOne) {
                drawEdgeOneFieldWithSparkline(dc, width, height, mIsDark);
            } else if (mEdgeField == EfSmall) {
                drawEdgeSmallFieldWithSparkline(dc, width, height, mIsDark);
            } else if (mEdgeField == EfLarge) {
                drawEdgeLargeFieldWithSparkline(dc, width, height, mIsDark);
            } else if (mEdgeField == EfWide) {
                drawEdgeWideFieldWithSparkline(dc, width, height, mIsDark);
            }
        }

        // TODO refactor this section to improve readability
        if (
            mBGServiceHandler.getRequestCounter() > 0 &&
            !mBGServiceHandler.hasError()
        ) {
            return;
        }
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

        var textColor = AppState.activePalette[ThemeManager.COLOR_TEXT];
        var backColor = AppState.activePalette[ThemeManager.COLOR_BG];

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

        // 3. Draw Divider Line
        var dividerColor = AppState.activePalette[ThemeManager.COLOR_DIVIDER];
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

        // 2. Draw Top Metrics Section (y = 0 to topGridHeight)
        drawEdgeSmallField(dc, 0, 0, width, topGridHeight, isDark);
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

        // 3. Draw Divider Line
        var dividerColor = AppState.activePalette[ThemeManager.COLOR_DIVIDER];
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

        // 2. Draw Top Metrics Section (y = 0 to topGridHeight)
        drawEdgeOneField(dc, 0, 0, width, topGridHeight, isDark);
    }
    private function drawEdgeLargeFieldWithSparkline(
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

        // 3. Draw Divider Line
        var dividerColor = AppState.activePalette[ThemeManager.COLOR_DIVIDER];
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

        // 2. Draw Top Metrics Section (y = 0 to topGridHeight)
        drawEdgeLargeField(dc, 0, 0, width, topGridHeight, isDark);
    }

    private function drawEdgeWideFieldWithSparkline(
        dc as Graphics.Dc,
        width as Number,
        height as Number,
        isDark as Boolean
    ) as Void {
        // 1. Reserve bottom 20% of total height for the 12h Sparkline
        var sparklineHeight = (height * 0.2).toNumber();
        var topGridHeight = height - sparklineHeight;

        // Minimum height check: ensure sparkline gets at least 32px to render legibly
        if (sparklineHeight < 32) {
            sparklineHeight = 32;
            topGridHeight = height - sparklineHeight;
        }

        // 3. Draw Divider Line
        var dividerColor = AppState.activePalette[ThemeManager.COLOR_DIVIDER];
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

        // 2. Draw Top Metrics Section (y = 0 to topGridHeight)
        drawEdgeWideField(dc, 0, 0, width, topGridHeight, isDark);
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

        if ($.gHSPshowValue) {
            drawOptionalHsp(dc, isDark);
        }

        // --- BOTTOM ROW: Dynamic Full-Width Rain Warning Strip ---
        if (
            (mMinutesUntilRain >= 0 && mMinutesUntilRain <= 45) ||
            (mMinutesUntilSnow >= 0 && mMinutesUntilSnow <= 45)
        ) {
            var alertY = centerHeaderY + headerLineHeight + 4;
            var alertLineHeight = Graphics.getFontHeight(Graphics.FONT_XTINY);
            var alertH = alertLineHeight + 4;

            dc.setColor(
                AppState.activePalette[ThemeManager.COLOR_DEEP_CYAN],
                Graphics.COLOR_TRANSPARENT
            ); // Deep Cyan
            dc.fillRectangle(x, alertY, w, alertH);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
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

        var labelColor = AppState.activePalette[ThemeManager.COLOR_LABEL];

        // Grid Separator Lines
        var dividerColor = AppState.activePalette[ThemeManager.COLOR_DIVIDER];
        dc.setColor(dividerColor, Graphics.COLOR_TRANSPARENT);
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
            mWeatherMetrics.airTemp <= 0
                ? Graphics.COLOR_RED
                : AppState.activePalette[ThemeManager.COLOR_TEXT]
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
            mWeatherMetrics.surfaceTemp <= 0
                ? Graphics.COLOR_RED
                : AppState.activePalette[ThemeManager.COLOR_TEXT]
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
            mWeatherMetrics.dewPoint >= 20
                ? Graphics.COLOR_RED
                : AppState.activePalette[ThemeManager.COLOR_TEXT]
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
            mWeatherMetrics.humidity >= 80
                ? Graphics.COLOR_RED
                : AppState.activePalette[ThemeManager.COLOR_TEXT]
        );

        // --- DRAW FOOTER: HAZARD & ADVICE TEXT ---

        // Capture pointer once at start of frame
        var localHazards = mHazardStrings;
        var localAdvice = mAdviceStrings;
        var linePos = gridTop + gridHeight + 2;
        if (localHazards.size() > 0) {
            linePos += StringListRenderer.drawCenteredWrappedStrings(
                dc,
                localHazards,
                x,
                linePos,
                w,
                localHazards.size(), // maxLines
                Graphics.FONT_TINY,
                AppState.activePalette[ThemeManager.COLOR_HAZARD]
            );
        }

        if (localAdvice.size() > 0) {
            linePos += StringListRenderer.drawCenteredWrappedStrings(
                dc,
                localAdvice,
                x,
                linePos,
                w,
                localAdvice.size(), // maxLines
                Graphics.FONT_XTINY,
                AppState.activePalette[ThemeManager.COLOR_TEXT]
            );
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
        var labelHeight = dc.getFontHeight(Graphics.FONT_XTINY);

        // Value
        var font =
            $.getMatchingFont(dc, mFontsNumbers, w, h, value) as FontType;
        dc.setColor(valueColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x + w / 2,
            y + h / 2 + labelHeight / 2,
            font,
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

        var lineHeight = dc.getFontHeight(Graphics.FONT_XTINY) + 1;
        var linePos = y + 2;

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
            linePos,
            Graphics.FONT_XTINY,
            surfStr,
            Graphics.TEXT_JUSTIFY_LEFT
        );
        linePos += lineHeight;
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
            linePos,
            Graphics.FONT_XTINY,
            humidityStr,
            Graphics.TEXT_JUSTIFY_LEFT
        );
        linePos += lineHeight;

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
                    linePos,
                    Graphics.FONT_XTINY,
                    hazardStr,
                    Graphics.TEXT_JUSTIFY_LEFT
                );
                linePos += lineHeight;
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
        var riskLevelText = getRiskLevelString(mRiskAssessment.riskLevel);
        var isRiskColorLight = $.isColorLight(riskColor);
        var riskTextColor = isRiskColorLight
            ? Graphics.COLOR_BLACK
            : Graphics.COLOR_WHITE;

        var textColor = AppState.activePalette[ThemeManager.COLOR_TEXT];

        // Left Column (35%): Risk Block & Hazard
        var lineHeightRiskText = Graphics.getFontHeight(Graphics.FONT_MEDIUM);
        var heightRiskBlock = (lineHeightRiskText + 4).toNumber();

        var leftWidth = (w * 0.35).toNumber();
        dc.setColor(riskColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, leftWidth, heightRiskBlock);

        dc.setColor(riskTextColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x + leftWidth / 2,
            y + (heightRiskBlock / 2).toNumber(),
            Graphics.FONT_MEDIUM,
            riskLevelText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        // Hazard text underneath badge
        if (mRiskAssessment.hazards.size() > 0) {
            var lineHeight = Graphics.getFontHeight(Graphics.FONT_XTINY);
            var linePos = y + heightRiskBlock + lineHeight / 2;
            for (var i = 0; i < mRiskAssessment.hazards.size(); i++) {
                var hazardStr = getShortHazardString(
                    mRiskAssessment.hazards[i]
                );
                dc.setColor(
                    AppState.activePalette[ThemeManager.COLOR_HAZARD],
                    Graphics.COLOR_TRANSPARENT
                );
                dc.drawText(
                    x + 2,
                    linePos,
                    Graphics.FONT_XTINY,
                    hazardStr,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
                );
                linePos += lineHeight;
            }
        }

        // Divider Line
        var dividerColor = AppState.activePalette[ThemeManager.COLOR_DIVIDER];
        dc.setColor(dividerColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x + leftWidth, y, x + leftWidth, y + h);

        var labelColor = AppState.activePalette[ThemeManager.COLOR_LABEL];
        // Right Column (65%): 3 Metrics Side-by-Side
        var rightX = leftWidth;
        var colW = (w - leftWidth) / 3;

        // Col 1: Air Temp
        var airColor =
            mWeatherMetrics.airTemp <= 0 ? Graphics.COLOR_RED : textColor;
        drawMetricColumn(
            dc,
            x + rightX,
            y,
            colW,
            h,
            "AIR",
            Lang.format("$1$°C", [mWeatherMetrics.airTemp.format("%.1f")]),
            labelColor,
            airColor
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

    function drawOptionalHsp(dc as Graphics.Dc, isDark as Boolean) as Void {
        // Implementation for drawing optional HSP (Hazard, Safety, Precaution) information

        var color = getRiskColor(mRiskAssessment.riskLevel, isDark);
        // place the HSP value in the top left corner
        var hsp = $.calculateHSP(color);
        dc.drawText(
            1,
            1,
            Graphics.FONT_XTINY,
            hsp.format("%.1f"),
            Graphics.TEXT_JUSTIFY_LEFT
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
        var riskColor = getRiskColor(mRiskAssessment.riskLevel, isDark);
        var riskLevelText = getRiskLevelString(mRiskAssessment.riskLevel);
        var isRiskColorLight = $.isColorLight(riskColor);
        var riskTextColor = isRiskColorLight
            ? Graphics.COLOR_BLACK
            : Graphics.COLOR_WHITE;

        var textColor = AppState.activePalette[ThemeManager.COLOR_TEXT];
        // --- DRAW HEADER BAR ---
        var headerHeight = (h * 0.15).toNumber();
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

        // --- Center Alert Strip ---
        if (
            (mMinutesUntilRain >= 0 && mMinutesUntilRain <= 45) ||
            (mMinutesUntilSnow >= 0 && mMinutesUntilSnow <= 45)
        ) {
            var alertX = x + w / 3;
            var alertY = centerHeaderY; // + headerLineHeight + 4;
            var alertLineHeight = Graphics.getFontHeight(Graphics.FONT_XTINY);
            var alertH = alertLineHeight + 4;

            dc.setColor(
                AppState.activePalette[ThemeManager.COLOR_DEEP_CYAN],
                Graphics.COLOR_TRANSPARENT
            ); // Deep Cyan
            dc.fillRectangle(alertX, alertY, w / 3, alertH);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                alertX + w / 6,
                alertY + alertH / 2,
                Graphics.FONT_XTINY,
                $.getPrecipitationAlertMessage(
                    mMinutesUntilRain,
                    mMinutesUntilSnow
                ),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }

        // 2. Main 2x2 Grid
        var gridTop = y + headerHeight;
        var gridHeight = (h * 0.5).toNumber();
        var halfW = w / 2;
        var rowH = gridHeight / 2;

        // Grid Dividers
        var dividerColor = AppState.activePalette[ThemeManager.COLOR_DIVIDER];
        dc.setColor(dividerColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x + halfW, gridTop, x + halfW, gridTop + gridHeight);
        dc.drawLine(x, gridTop + rowH, x + w, gridTop + rowH);
        dc.drawLine(x, gridTop + gridHeight, x + w, gridTop + gridHeight);

        var labelColor = AppState.activePalette[ThemeManager.COLOR_LABEL];
        drawGridCell(
            dc,
            x,
            gridTop,
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
            gridTop,
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
            gridTop + rowH,
            halfW,
            rowH,
            "DEW POINT",
            Lang.format("$1$°C", [mWeatherMetrics.dewPoint.format("%.1f")]),
            labelColor,
            mWeatherMetrics.dewPoint >= 20 ? Graphics.COLOR_RED : textColor
        );
        drawGridCell(
            dc,
            x + halfW,
            gridTop + rowH,
            halfW,
            rowH,
            "HUMIDITY",
            Lang.format("$1$%", [mWeatherMetrics.humidity]),
            labelColor,
            mWeatherMetrics.humidity >= 80 ? Graphics.COLOR_RED : textColor
        );

        // 4. Hazards & Advice Section

        dc.setColor(
            AppState.activePalette[ThemeManager.COLOR_HAZARD],
            Graphics.COLOR_TRANSPARENT
        );

        // --- DRAW FOOTER: HAZARD & ADVICE TEXT ---
        // Capture pointer once at start of frame
        var localHazards = mHazardStrings;
        var localAdvice = mAdviceStrings;
        var linePos = gridTop + gridHeight + 2;
        if (localHazards.size() > 0) {
            linePos += StringListRenderer.drawCenteredWrappedStrings(
                dc,
                localHazards,
                x,
                linePos,
                w,
                localHazards.size(), // maxLines
                Graphics.FONT_TINY,
                AppState.activePalette[ThemeManager.COLOR_HAZARD]
            );
        }

        if (localAdvice.size() > 0) {
            linePos += StringListRenderer.drawCenteredWrappedStrings(
                dc,
                localAdvice,
                x,
                linePos,
                w,
                localAdvice.size(), // maxLines
                Graphics.FONT_XTINY,
                AppState.activePalette[ThemeManager.COLOR_TEXT]
            );
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

    function playAlert() as Void {
        if (!(Attention has :playTone) || !System.getDeviceSettings().tonesOn) {
            return;
        }

        Attention.playTone(Attention.TONE_ALERT_HI);
        return;
    }

    function showToastForAlert() as Void {
        if (!(WatchUi has :showToast)) {
            return;
        }

        if (mToastIcon == null) {
            mToastIcon =
                Application.loadResource(Rez.Drawables.warningIcon) as
                BitmapResource;
        }

        var riskLevelText = getRiskLevelString(mRiskAssessment.riskLevel);
        var message = mAppName + " - " + riskLevelText;

        var localHazards = mHazardStrings;
        if (localHazards.size() > 0) {
            for (var i = 0; i < localHazards.size(); i = i + 1) {
                var hazardStr = localHazards[i];
                message = message + "\n - " + hazardStr;
            }
        }

        WatchUi.showToast(message, { :icon => mToastIcon });
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
