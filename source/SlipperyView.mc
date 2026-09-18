import Toybox.Activity;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Math;

class SlipperyView extends WatchUi.DataField {
    var mBGServiceHandler as BGServiceHandler;
    var mCurrentLocation as CurrentLocation = new CurrentLocation();
    var mEdgeField as EdgeField = EfSmall;
    var mIsDark as Boolean = false;
    var mLat as Float = 0.0;
    var mAppName = "Slippery";

    private var mWeatherMetrics as WeatherMetrics = new WeatherMetrics();
    private var mRiskAssessment as RiskAssessment = new RiskAssessment();
    private var mHasWeatherData as Boolean = false; // TODO then all color grey
    private var mHazardStrings as Array<String> = [];
    private var mHazardStringsShortened as Array<String> = [];
    private var mAdviceStrings as Array<String> = [];

    private var mMinutesUntilSecondsCounter as Number = 0;
    private var mMinutesUntilRain as Number = -1;
    private var mMinutesUntilSnow as Number = -1;

    hidden var mAlertProcessedForLevel as RiskLevel = RiskLevelNoData;
    hidden var mAlertIncomingRain as Number = -1;
    hidden var mAlertIncomingSnow as Number = -1;
    hidden var mToastIcon as BitmapResource?;

    hidden var mHeadingDegrees as Number? = null;
    hidden var mPaused as Boolean = false;

    hidden var mFontsNumbers as Array = [
        Graphics.FONT_XTINY,
        Graphics.FONT_TINY,
        Graphics.FONT_SYSTEM_SMALL,
        Graphics.FONT_SYSTEM_MEDIUM,
        Graphics.FONT_SYSTEM_LARGE,
        Graphics.FONT_NUMBER_MILD,
        Graphics.FONT_NUMBER_MEDIUM,
        // Not needed.
        // Graphics.FONT_NUMBER_HOT,
        // Graphics.FONT_NUMBER_THAI_HOT,
    ];

    private var mCurrentHour as Number = -1;
    private var _lastMinuteChecked as Number = -1;

    private var mAlertState as AlertState = STATE_NORMAL;
    private var mCrossGust as CrosswindResult = new CrosswindResult(
        SEVERITY_LOW,
        0.0f,
        0
    );
    private var mNetHeadwindKmh as Float = 0.0f;
    private var mFeelsLikeTemp as Float = 0.0f;

    function initialize() {
        DataField.initialize();

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
        if (!WeatherService.parseOpenMeteoResponse(mLat, data)) {
            return;
        }
        if ($.gDemo) {
            mHasWeatherData = true;
            return;
        }
        updateWeatherAndRisks(
            WeatherService.getMetrics(),
            WeatherService.getRisks()
        );
        mHasWeatherData = true;
    }

    function updateWeatherAndRisks(
        weatherMetrics as WeatherMetrics,
        riskAssessment as RiskAssessment
    ) as Void {
        mWeatherMetrics = weatherMetrics;
        System.println(weatherMetrics.toString());
        mRiskAssessment = riskAssessment;
        System.println(mRiskAssessment.toString());

        setHazardAndAdviceStrings();
        initializeMinutesUntilCounters();
        processAlerts();
        // Force an immediate recalculation when fresh data arrives
        _lastMinuteChecked = -1;
    }

    function handleForecastQuarterChange() as Void {
        var currentMin = System.getClockTime().min;

        // Gate: Only calculate ONCE per minute instead of every second
        if (mHasWeatherData && currentMin != _lastMinuteChecked) {
            _lastMinuteChecked = currentMin;

            var nowEpoch = Time.now().value();
            mWeatherMetrics.hourFractionRemaining =
                ForecastAligner.getFirstHourRemainingFraction(
                    mWeatherMetrics.timeStampsForeCast,
                    nowEpoch
                );
            System.println(
                "Cached hour fraction updated to: " +
                    mWeatherMetrics.hourFractionRemaining
            );
        }
    }

    function setHazardAndAdviceStrings() as Void {
        var hazardStrings = [];
        var hazardStringsShortened = [];
        for (var i = 0; i < mRiskAssessment.hazards.size(); i++) {
            var shortHazardStr = getShortHazardString(
                mRiskAssessment.hazards[i]
            );
            if ($.gShortHazard) {
                hazardStrings.add(shortHazardStr);
            } else {
                var fullHazardStr = getHazardString(mRiskAssessment.hazards[i]);
                hazardStrings.add(fullHazardStr);
            }
            hazardStringsShortened.add(shortHazardStr);
        }
        var adviceStrings = [];
        for (var i = 0; i < mRiskAssessment.advice.size(); i++) {
            adviceStrings.add(getAdviceString(mRiskAssessment.advice[i]));
        }
        // Atomic swap: Single pointer assignment is thread-safe
        mHazardStrings = hazardStrings;
        mHazardStringsShortened = hazardStringsShortened;
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
    function processDemo() as Void {
        if ($.gDemo) {
            demoCounter = demoCounter + 1;
            mWeatherMetrics =
                DemoWeatherService.getDemoWeatherMetrics(demoCounter);
            mRiskAssessment =
                DemoWeatherService.getDemoRiskAssessment(demoCounter);
            setHazardAndAdviceStrings();
            initializeMinutesUntilCounters();
            if (demoCounter > 50) {
                $.gDemo = false;
                demoCounter = 0;
                recalcRiskAssessment = true;
                return;
            }
        }
        if (recalcRiskAssessment) {
            recalcRiskAssessment = false;
            updateWeatherAndRisks(
                WeatherService.getMetrics(),
                WeatherService.getRisks()
            );
        }
    }

    function compute(info as Activity.Info) as Void {
        processDemo();

        mBGServiceHandler.onCompute(info);
        if ($.g_bg_delay_seconds <= 0) {
            mBGServiceHandler.autoScheduleService();
        } else {
            $.g_bg_delay_seconds = $.g_bg_delay_seconds - 1;
        }
        handleHourChange();
        processMinutesUntilCounters();

        mHeadingDegrees = Geo.getHeadingDegrees(info, mHeadingDegrees);

        mPaused = ActivityUtils.getPaused(info);
        handleForecastQuarterChange();

        UpdateAlertState();
    }

    hidden var mAlertCategory as AlertCategory = CATEGORY_NONE;
    function UpdateAlertState() as Void {
        mCrossGust = CrosswindAnalyzer.evaluateCrosswind(
            mWeatherMetrics.windDirection,
            mHeadingDegrees,
            mWeatherMetrics.windGust,
            mIsDark
        );
        mFeelsLikeTemp = WeatherUtils.getApparentTemperature(
            mWeatherMetrics.airTemp,
            mWeatherMetrics.humidity,
            mWeatherMetrics.windSpeed
        );
        mNetHeadwindKmh = NetwindAnalyzer.calculateNetWind(
            mWeatherMetrics.windSpeed,
            mWeatherMetrics.windDirection,
            mHeadingDegrees
        );

        mAlertState = AlertStateAnalyzer.updateAndEvaluate(
            mWeatherMetrics.surfaceTemp,
            mCrossGust.crosswindGustKmH,
            mWeatherMetrics.windSpeed,
            mNetHeadwindKmh,
            mFeelsLikeTemp
        );

        mAlertCategory = AlertCategoryRenderer.getCategoryForState(mAlertState);
        if ($.gBeepOnAlertStateChange) {
            AlertAudioNotifier.notifyStateChange(mAlertState);
        }
    }

    function initializeMinutesUntilCounters() as Void {
        if (mWeatherMetrics.immediateRain < 0) {
            mMinutesUntilRain = -1;
        } else {
            mMinutesUntilRain = mWeatherMetrics.immediateRain;
        }
        if (mWeatherMetrics.immediateSnow < 0) {
            mMinutesUntilSnow = -1;
        } else {
            mMinutesUntilSnow = mWeatherMetrics.immediateSnow;
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
        var newAlert = false;
        // Check for new alerts based on risk level
        if (mRiskAssessment.riskLevel > mAlertProcessedForLevel) {
            mAlertProcessedForLevel = mRiskAssessment.riskLevel;
            // Add your alert processing logic here
            newAlert = true;
            Toybox.System.println(
                "Alert for level" + mRiskAssessment.riskLevel
            );
        } else if (mRiskAssessment.riskLevel != mAlertProcessedForLevel) {
            // Reset to current risk level
            mAlertProcessedForLevel = mRiskAssessment.riskLevel;
            Toybox.System.println(
                "Reset alert processing to level " + mAlertProcessedForLevel
            );
        }
        // Check for incoming rain and snow alerts
        if (mAlertIncomingRain < 0 && mMinutesUntilRain >= 0) {
            mAlertIncomingRain = mMinutesUntilRain;
            newAlert = true;
        } else {
            mAlertIncomingRain = -1;
        }
        if (mAlertIncomingSnow < 0 && mMinutesUntilSnow >= 0) {
            mAlertIncomingSnow = mMinutesUntilSnow;
            newAlert = true;
        } else {
            mAlertIncomingSnow = -1;
        }
        if (newAlert) {
            if ($.gBeepOnAlert) {
                playAlert();
            }
            if ($.gToastOnAlert) {
                showToastForAlert();
            }
        }
    }

    function handleHourChange() as Void {
        var currentHour = System.getClockTime().hour;
        if (mCurrentHour < 0) {
            // First time initialization of the current hour
            mCurrentHour = currentHour;
        } else if (currentHour != mCurrentHour) {
            System.println(
                "Hour changed from " + mCurrentHour + " to " + currentHour
            );
            mCurrentHour = currentHour;
            if (WeatherService.recalculateOpenMeteoData(mLat)) {
                updateWeatherAndRisks(
                    WeatherService.getMetrics(),
                    WeatherService.getRisks()
                );
            }
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

        if (mHasWeatherData || $.gDemo) {
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

        // Only show background service stats if there are errors or no requests yet
        $.drawBackgroundServiceStats(
            dc,
            width,
            height,
            mBGServiceHandler,
            mEdgeField == EfSmall,
            true
        );

        if ($.gDemo) {
            // Draw demo enabled
            dc.setColor(
                AppState.getColor(ThemeManager.COLOR_TEXT),
                Graphics.COLOR_TRANSPARENT
            );

            dc.drawText(
                dc.getWidth() / 2,
                dc.getFontHeight(Graphics.FONT_XTINY),
                Graphics.FONT_XTINY,
                "DEMO (" + demoCounter.format("%d") + ")",
                Graphics.TEXT_JUSTIFY_CENTER
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
        var sparklineHeight = (height * 0.2).toNumber();
        var topGridHeight = height - sparklineHeight;

        // Minimum height check: ensure sparkline gets at least 20px to render legibly
        if (sparklineHeight < 20) {
            sparklineHeight = 20;
            topGridHeight = height - sparklineHeight;
        }

        // 3. Draw Divider Line
        var dividerColor = AppState.getColor(ThemeManager.COLOR_DIVIDER);
        dc.setColor(dividerColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(4, topGridHeight, width - 4, topGridHeight);

        // 4. Draw Bottom Sparkline Section (y = topGridHeight to h)
        // Add 4px horizontal padding on left/right so edges don't touch screen bezels
        var paddingX = 6;
        if (!$.gHasHighResScreen) {
            paddingX = 2;
        }

        PredictiveSparkline.drawComfort(
            dc,
            paddingX,
            topGridHeight,
            width - paddingX * 2,
            2,
            mWeatherMetrics,
            isDark
        );

        PredictiveSparkline.draw(
            dc,
            paddingX,
            topGridHeight + 2,
            width - paddingX * 2,
            sparklineHeight - 4,
            mWeatherMetrics,
            mRiskAssessment.hourlyRisksLevels,
            isDark,
            false,
            ForecastHourNone
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
        var dividerColor = AppState.getColor(ThemeManager.COLOR_DIVIDER);
        dc.setColor(dividerColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(4, topGridHeight, width - 4, topGridHeight);

        // 4. Draw Bottom Sparkline Section (y = topGridHeight to h)
        // Add 15px horizontal padding on left/right so edges don't touch screen bezels
        var paddingX = 15;

        PredictiveSparkline.drawComfort(
            dc,
            paddingX,
            topGridHeight,
            width - paddingX * 2,
            10,
            mWeatherMetrics,
            isDark
        );

        PredictiveSparkline.draw(
            dc,
            paddingX,
            topGridHeight + 2,
            width - paddingX * 2,
            sparklineHeight - 4,
            mWeatherMetrics,
            mRiskAssessment.hourlyRisksLevels,
            isDark,
            true,
            $.gShowForecastHour
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
        var dividerColor = AppState.getColor(ThemeManager.COLOR_DIVIDER);
        dc.setColor(dividerColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(4, topGridHeight, width - 4, topGridHeight);

        // 4. Draw Bottom Sparkline Section (y = topGridHeight to h)
        // Add 4px horizontal padding on left/right so edges don't touch screen bezels
        var paddingX = 6;

        PredictiveSparkline.drawComfort(
            dc,
            paddingX,
            topGridHeight,
            width - paddingX * 2,
            6,
            mWeatherMetrics,
            isDark
        );

        PredictiveSparkline.draw(
            dc,
            paddingX,
            topGridHeight + 2,
            width - paddingX * 2,
            sparklineHeight - 4,
            mWeatherMetrics,
            mRiskAssessment.hourlyRisksLevels,
            isDark,
            true,
            $.gShowForecastHour
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
        var dividerColor = AppState.getColor(ThemeManager.COLOR_DIVIDER);
        dc.setColor(dividerColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(4, topGridHeight, width - 4, topGridHeight);

        // 4. Draw Bottom Sparkline Section (y = topGridHeight to h)
        // Add 4px horizontal padding on left/right so edges don't touch screen bezels
        var paddingX = 6;

        PredictiveSparkline.drawComfort(
            dc,
            paddingX,
            topGridHeight,
            width - paddingX * 2,
            4,
            mWeatherMetrics,
            isDark
        );

        PredictiveSparkline.draw(
            dc,
            paddingX,
            topGridHeight + 2,
            width - paddingX * 2,
            sparklineHeight - 4,
            mWeatherMetrics,
            mRiskAssessment.hourlyRisksLevels,
            isDark,
            false,
            ForecastHourNone
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
        var headerTextPosX = x + w - 6;
        dc.drawText(
            headerTextPosX,
            centerHeaderY,
            Graphics.FONT_SMALL,
            riskLevelText,
            Graphics.TEXT_JUSTIFY_RIGHT
        );

        var iconSize = (headerHeight * 0.4).toNumber();
        RiskIconRenderer.drawRiskIcon(
            dc,
            w / 2,
            centerHeaderY,
            iconSize,
            mRiskAssessment.riskLevel,
            riskTextColor,
            riskColor
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
                AppState.getColor(ThemeManager.COLOR_DEEP_CYAN),
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
                    mMinutesUntilSnow,
                    false
                ),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }

        // --- DRAW 3x2 METRICS GRID ---
        var gridTop = headerHeight + 4;
        var gridHeight = (h * 0.46).toNumber();
        var colWidth = w / 2;
        var rowHeight = gridHeight / 3;

        var labelColor = AppState.getColor(ThemeManager.COLOR_LABEL);
        var unitColor = AppState.getColor(ThemeManager.COLOR_UNIT);
        // Grid Separator Lines
        var dividerColor = AppState.getColor(ThemeManager.COLOR_DIVIDER);
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
            y + gridTop + 2 * rowHeight,
            x + w,
            y + gridTop + 2 * rowHeight
        ); // Horizontal
        dc.drawLine(
            x,
            y + gridTop + gridHeight,
            x + w,
            y + gridTop + gridHeight
        ); // Bottom

        var gridLinePos = y + gridTop;
        // Cell 1: Air Temp

        if ($.gUseFeelsLikeTemperature) {
            // Cell 1: Feels like
            drawGridCell(
                dc,
                x,
                gridLinePos,
                colWidth,
                rowHeight,
                "FEELS LIKE",
                Lang.format("$1$", [mFeelsLikeTemp.format("%.1f")]),
                "°C",
                labelColor,
                $.getTemperatureColor(mFeelsLikeTemp, isDark),
                unitColor
            );
        } else {
            drawGridCell(
                dc,
                x,
                gridLinePos,
                colWidth,
                rowHeight,
                "AIR TEMP",
                Lang.format("$1$", [mWeatherMetrics.airTemp.format("%.1f")]),
                "°C",
                labelColor,
                $.getTemperatureColor(mWeatherMetrics.airTemp, isDark),
                unitColor
            );
        }
        // Cell 2: Surface Temp
        drawGridCell(
            dc,
            x + colWidth,
            gridLinePos,
            colWidth,
            rowHeight,
            "SURFACE",
            Lang.format("$1$", [mWeatherMetrics.surfaceTemp.format("%.1f")]),
            "°C",
            labelColor,
            $.getTemperatureColor(mWeatherMetrics.surfaceTemp, isDark),
            unitColor
        );

        gridLinePos += rowHeight;
        // Cell 3: Dew Point
        drawGridCell(
            dc,
            x,
            gridLinePos,
            colWidth,
            rowHeight,
            "DEW POINT",
            Lang.format("$1$", [mWeatherMetrics.dewPoint.format("%.1f")]),
            "°C",
            labelColor,
            DewpointPalette.getColor(mWeatherMetrics.dewPoint, isDark),
            unitColor
        );

        // Cell 4: Humidity
        drawGridCell(
            dc,
            x + colWidth,
            gridLinePos,
            colWidth,
            rowHeight,
            "HUMIDITY",
            Lang.format("$1$", [mWeatherMetrics.humidity]),
            "%",
            labelColor,
            $.getHumidityColor(mWeatherMetrics.humidity, isDark),
            unitColor
        );

        gridLinePos += rowHeight;

        // Cell 5: Wind Speed
        drawGridCell(
            dc,
            x,
            gridLinePos,
            colWidth,
            rowHeight,
            "WIND SPEED",
            Lang.format("$1$", [mWeatherMetrics.windSpeed.format("%.1f")]),
            "km/h",
            labelColor,
            $.getWindSpeedColor(mWeatherMetrics.windSpeed, isDark),
            unitColor
        );

        // Cell 6: Wind Gust
        drawGridCell(
            dc,
            x + colWidth,
            gridLinePos,
            colWidth,
            rowHeight,
            "WIND GUST",
            Lang.format("$1$", [mWeatherMetrics.windGust.format("%.1f")]),
            "km/h",
            labelColor,
            $.getGustSeverityColor(mWeatherMetrics.gustSeverity, isDark),
            unitColor
        );

        // Capture pointer once at start of frame
        var localHazards = mHazardStrings;
        var localAdvice = mAdviceStrings;

        if ($.gHideRiskAdvice || localHazards.size() <= 3) {
            // Show when no advice or max 3 hazard
            gridLinePos += rowHeight;

            // Cell 7: Net wind
            drawGridCell(
                dc,
                x,
                gridLinePos,
                colWidth,
                rowHeight,
                "NET WIND " + NetwindAnalyzer.formatNetWind(mNetHeadwindKmh),
                Lang.format("$1$", [mNetHeadwindKmh.format("%.1f")]),
                "km/h",
                labelColor,
                $.getNetSpeedColor(mNetHeadwindKmh, isDark),
                unitColor
            );
            // Cell 8: Cross gust
            drawGridCell(
                dc,
                x + colWidth,
                gridLinePos,
                colWidth,
                rowHeight,
                "CROSS GUST",
                Lang.format("$1$", [
                    mCrossGust.crosswindGustKmH.format("%.1f"),
                ]),
                "km/h",
                labelColor,
                mCrossGust.color,
                unitColor
            );
        }
        // --- CURRENT WIND ARROW CENTERED IN GRID HEADER ---
        CurrentWindWidget.draw(
            dc,
            x + w / 2, // Widget X center
            y + gridTop + 2 * rowHeight, // Widget Y center
            0,
            h,
            mWeatherMetrics.windSpeed, // e.g. 24.0f km/h
            mWeatherMetrics.windGust, // e.g. 38.0f km/h
            mWeatherMetrics.windDirection, // e.g. 180.0f deg
            mHeadingDegrees, // Heading from activity
            true, // true = Relative to bike heading, false = Cardinal North
            isDark, // Use risklevel background
            true // Big field scaling
        );

        gridLinePos += rowHeight;
        // --- DRAW FOOTER: HAZARD & ADVICE TEXT ---

        // var linePos = y + gridTop + gridHeight + 2;
        var linePos = gridLinePos;
        if (localHazards.size() > 0) {
            linePos += StringListRenderer.drawCenteredWrappedStrings(
                dc,
                localHazards,
                x,
                linePos,
                w,
                localHazards.size(), // maxLines
                $.gHideRiskAdvice ? Graphics.FONT_SMALL : Graphics.FONT_TINY,
                AppState.getColor(ThemeManager.COLOR_HAZARD)
            );
        }

        if (!$.gHideRiskAdvice && localAdvice.size() > 0) {
            linePos += StringListRenderer.drawCenteredWrappedStrings(
                dc,
                localAdvice,
                x,
                linePos,
                w,
                localAdvice.size(), // maxLines
                Graphics.FONT_XTINY,
                AppState.getColor(ThemeManager.COLOR_TEXT)
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
        unit as String,
        labelColor as Number,
        valueColor as Number,
        unitColor as Number
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

        if ($.gHideUnitsWhenActive and !mPaused) {
            return;
        }
        // Unit

        // 2. Calculate text metrics for alignment
        var valueWidth = dc.getTextWidthInPixels(value, font);
        var fontAscent = Graphics.getFontAscent(font);
        var fontDescent = Graphics.getFontDescent(font);

        // Horizontal position: Right edge of main value + small gap (e.g., 2px)
        var unitX = x + w / 2 + valueWidth / 2 + 2;

        // Vertical baseline calculation: Align with the bottom baseline of the main font
        var mainBaselineY =
            y + h / 2 + labelHeight / 2 + fontAscent / 2 - fontDescent / 2;
        var xtinyAscent = Graphics.getFontAscent(Graphics.FONT_XTINY);

        // Vertical position: Offset back up by XTINY's ascent so its baseline aligns perfectly
        var unitY = mainBaselineY - xtinyAscent;

        dc.setColor(unitColor, Graphics.COLOR_TRANSPARENT);

        // 3. Draw unit tag
        dc.drawText(
            unitX,
            unitY,
            Graphics.FONT_XTINY,
            unit,
            Graphics.TEXT_JUSTIFY_LEFT // Left-aligned so it extends to the right
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
        var badgeWidth = (w * 0.2).toNumber();
        var badgeHeight = (h * 0.4).toNumber();
        dc.setColor(riskColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, badgeWidth, badgeHeight);

        var headerLineHeight = dc.getFontHeight(Graphics.FONT_XTINY) + 1;
        var linePos = y + headerLineHeight;

        RiskIconRenderer.drawRiskIcon(
            dc,
            x + badgeWidth / 2,
            linePos,
            (badgeHeight * 0.6).toNumber(),
            mRiskAssessment.riskLevel,
            badgeTextColor,
            riskColor
        );

        linePos = y + h / 2;

        // Right 70%: Metrics Grid & Hazards
        var rightAreaX = x + badgeWidth + 4;
        var textColor = AppState.getColor(ThemeManager.COLOR_TEXT);
        var labelColor = AppState.getColor(ThemeManager.COLOR_LABEL);
        var unitColor = AppState.getColor(ThemeManager.COLOR_UNIT);
        var lineHeight = dc.getFontHeight(Graphics.FONT_XTINY) + 1;
        var linePosMetrics = y + lineHeight;

        // --- ROW 1: Side-by-Side (2x2 Grid) ---

        // Calculate based on max widths
        var labelWidth = dc.getTextWidthInPixels("Ws", Graphics.FONT_XTINY);
        var col1Width =
            labelWidth +
            dc.getTextWidthInPixels("88.8", Graphics.FONT_TINY) +
            dc.getTextWidthInPixels("%", Graphics.FONT_XTINY) -
            2;

        drawMetricField(
            dc,
            rightAreaX,
            linePosMetrics,
            labelWidth,
            "Ts",
            mWeatherMetrics.surfaceTemp.format("%.1f"),
            "°",
            labelColor,
            mWeatherMetrics.surfaceTemp <= 0 ? Graphics.COLOR_RED : textColor,
            unitColor
        );

        // Col 2: Wind Speed

        drawMetricField(
            dc,
            rightAreaX + col1Width,
            linePosMetrics,
            labelWidth,
            "Ws",
            mWeatherMetrics.windSpeed.format("%.1f"),
            "km/h",
            labelColor,
            $.getWindSpeedColor(mWeatherMetrics.windSpeed, isDark),
            unitColor
        );

        linePosMetrics += lineHeight;

        // --- ROW 2:  ---

        drawMetricField(
            dc,
            rightAreaX,
            linePosMetrics,
            labelWidth,
            "Rh",
            mWeatherMetrics.humidity.format("%d"),
            "%",
            labelColor,
            $.getHumidityColor(mWeatherMetrics.humidity, isDark),
            unitColor
        );

        if ($.gUseEffectiveCrossGust) {
            var crossWind = CrosswindAnalyzer.evaluateCrosswind(
                mWeatherMetrics.windDirection,
                mHeadingDegrees,
                mWeatherMetrics.windGust,
                isDark
            );

            drawMetricField(
                dc,
                rightAreaX + col1Width,
                linePosMetrics,
                labelWidth,
                "Cx",
                crossWind.crosswindGustKmH.format("%.1f"),
                "km/h",
                labelColor,
                crossWind.color,
                unitColor
            );
        } else {
            drawMetricField(
                dc,
                rightAreaX + col1Width,
                linePosMetrics,
                labelWidth,
                "Gu",
                mWeatherMetrics.windGust.format("%.1f"),
                "km/h",
                labelColor,
                $.getGustSeverityColor(mWeatherMetrics.gustSeverity, isDark),
                unitColor
            );
        }

        linePosMetrics += lineHeight / 2;

        // Horizontal dividing line under columns
        var dividerColor = AppState.getColor(ThemeManager.COLOR_DIVIDER);
        dc.setColor(dividerColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x, linePosMetrics, x + w, linePosMetrics);

        // --- ROW 3+: Shortened Hazard Strings ---

        var localHazards = mHazardStringsShortened;
        if (localHazards.size() > 0) {
            var totalWidth = w - rightAreaX;
            linePosMetrics += StringListRenderer.drawWrappedStrings(
                dc,
                localHazards,
                x,
                linePosMetrics,
                totalWidth,
                localHazards.size(), // maxLines
                Graphics.FONT_XTINY,
                AppState.getColor(ThemeManager.COLOR_HAZARD)
            );
        }

        if (
            (mMinutesUntilRain >= 0 && mMinutesUntilRain <= 45) ||
            (mMinutesUntilSnow >= 0 && mMinutesUntilSnow <= 45)
        ) {
            var alertX = x;
            var alertLineHeight = Graphics.getFontHeight(Graphics.FONT_XTINY);
            var alertH = alertLineHeight + 4;
            var alertY = y + h - alertH;
            var alertW = w;

            dc.setColor(
                AppState.getColor(ThemeManager.COLOR_DEEP_CYAN),
                Graphics.COLOR_TRANSPARENT
            );
            dc.fillRectangle(alertX, alertY, alertW, alertH);

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                alertX + alertW / 2,
                alertY + alertH / 2,
                Graphics.FONT_XTINY,
                $.getPrecipitationAlertMessage(
                    mMinutesUntilRain,
                    mMinutesUntilSnow,
                    false
                ),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }

        // --- CURRENT WIND ARROW CENTERED ---
        var windY = h / 2;
        if (localHazards.size() == 0) {
            // No hazards, so put arrow in the white space
            windY += (h * 0.3).toNumber();
        }
        CurrentWindWidget.draw(
            dc,
            w / 2, // Widget X center
            windY, // Widget Y center
            0,
            h,
            mWeatherMetrics.windSpeed, // e.g. 24.0f km/h
            mWeatherMetrics.windGust, // e.g. 38.0f km/h
            mWeatherMetrics.windDirection, // e.g. 180.0f deg
            mHeadingDegrees, // Heading from activity
            true, // true = Relative to bike heading, false = Cardinal North
            isDark,
            false // Big field scaling
        );
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
        var isRiskColorLight = $.isColorLight(riskColor);
        var riskTextColor = isRiskColorLight
            ? Graphics.COLOR_BLACK
            : Graphics.COLOR_WHITE;

        var textColor = AppState.getColor(ThemeManager.COLOR_TEXT);

        // =========================================================================
        // 1. LEFT COLUMN (35%): RISK BADGE + LARGE RELATIVE WIND ARROW
        // =========================================================================
        var leftWidth = (w * 0.25).toNumber();
        var lineHeightRiskText = Graphics.getFontHeight(Graphics.FONT_MEDIUM);
        var heightRiskBlock = (lineHeightRiskText + 2).toNumber();

        // Risk Level Badge Top
        dc.setColor(riskColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, leftWidth, heightRiskBlock);

        var colIconW = (leftWidth / 3).toNumber();
        var posIconX = x + colIconW;
        RiskIconRenderer.drawRiskIcon(
            dc,
            posIconX,
            y + (heightRiskBlock / 2).toNumber(),
            (heightRiskBlock * 0.7).toNumber(),
            mRiskAssessment.riskLevel,
            riskTextColor,
            riskColor
        );

        AlertCategoryRenderer.drawCategoryIcon(
            dc,
            posIconX + colIconW,
            y + (heightRiskBlock / 2).toNumber(),
            (heightRiskBlock * 0.7).toNumber(),
            mAlertCategory,
            riskTextColor
        );

        // Render Large Wind Arrow centered in the remaining lower area of the left box
        var arrowAreaCenterY =
            y + heightRiskBlock + ((h - heightRiskBlock) / 2).toNumber();
        var arrowAreaCenterX = x + (leftWidth / 2).toNumber();

        CurrentWindWidget.draw(
            dc,
            arrowAreaCenterX, // Widget X center
            arrowAreaCenterY, // Widget Y center
            0,
            h,
            mWeatherMetrics.windSpeed, // e.g. 24.0f km/h
            mWeatherMetrics.windGust, // e.g. 38.0f km/h
            mWeatherMetrics.windDirection, // e.g. 180.0f deg
            mHeadingDegrees, // Heading from activity
            true, // true = Relative to bike heading, false = Cardinal North
            isDark,
            false // Big field scaling
        );

        // Divider Line between Left & Right Columns
        var dividerColor = AppState.getColor(ThemeManager.COLOR_DIVIDER);
        dc.setColor(dividerColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x + leftWidth, y, x + leftWidth, y + h);

        // =========================================================================
        // 2. RIGHT COLUMN (65%): COMPRESSED COLUMNS (TOP ~40%) & HAZARDS (BOTTOM)
        // =========================================================================
        var labelColor = AppState.getColor(ThemeManager.COLOR_LABEL_LIGHT);
        var unitColor = AppState.getColor(ThemeManager.COLOR_UNIT);
        var rightX = leftWidth;
        var colW = (w - leftWidth) / 3;

        // Compact columns height (~40% of field height)
        var colHeight = (h * 0.5).toNumber();

        if (mAlertCategory == CATEGORY_WIND) {
            // Col 1: Wind
            drawMetricColumn(
                dc,
                x + rightX,
                y,
                colW,
                colHeight,
                "WIND",
                Lang.format("$1$", [mWeatherMetrics.windSpeed.format("%.1f")]),
                "km/h",
                labelColor,
                $.getWindSpeedColor(mWeatherMetrics.windSpeed, isDark),
                unitColor
            );

            // Col 2: Cross Gust
            if ($.gUseEffectiveCrossGust) {
                drawMetricColumn(
                    dc,
                    x + rightX + colW,
                    y,
                    colW,
                    colHeight,
                    "Cx GUST",
                    Lang.format("$1$", [
                        mCrossGust.crosswindGustKmH.format("%.1f"),
                    ]),
                    "km/h",
                    labelColor,
                    mCrossGust.color,
                    unitColor
                );
            } else {
                drawMetricColumn(
                    dc,
                    x + rightX + colW,
                    y,
                    colW,
                    colHeight,
                    "GUST",
                    Lang.format("$1$", [
                        mWeatherMetrics.windGust.format("%.1f"),
                    ]),
                    "km/h",
                    labelColor,
                    $.getGustSeverityColor(
                        mWeatherMetrics.gustSeverity,
                        isDark
                    ),
                    unitColor
                );
            }

            // Col 3: Net wind
            drawMetricColumn(
                dc,
                x + rightX + colW * 2,
                y,
                colW,
                colHeight,
                NetwindAnalyzer.formatNetWind(mNetHeadwindKmh),
                Lang.format("$1$", [mNetHeadwindKmh.format("%.1f")]),
                "km/h",
                labelColor,
                $.getNetSpeedColor(mNetHeadwindKmh, isDark),
                unitColor
            );
        } else {
            if ($.gUseFeelsLikeTemperature) {
                // Col 1: Feels Like Temp
                drawMetricColumn(
                    dc,
                    x + rightX,
                    y,
                    colW,
                    colHeight,
                    "FEELS LIKE",
                    Lang.format("$1$", [mFeelsLikeTemp.format("%.1f")]),
                    "°C",
                    labelColor,
                    $.getTemperatureColor(mFeelsLikeTemp, isDark),
                    unitColor
                );
            } else {
                // Col 1: Air Temp
                drawMetricColumn(
                    dc,
                    x + rightX,
                    y,
                    colW,
                    colHeight,
                    "AIR",
                    Lang.format("$1$", [
                        mWeatherMetrics.airTemp.format("%.1f"),
                    ]),
                    "°C",
                    labelColor,
                    $.getTemperatureColor(mWeatherMetrics.airTemp, isDark),
                    unitColor
                );
            }

            // Col 2: Surface Temp
            drawMetricColumn(
                dc,
                x + rightX + colW,
                y,
                colW,
                colHeight,
                "SURFACE",
                Lang.format("$1$", [
                    mWeatherMetrics.surfaceTemp.format("%.1f"),
                ]),
                "°C",
                labelColor,
                $.getTemperatureColor(mWeatherMetrics.surfaceTemp, isDark),
                unitColor
            );

            // Col 3: Dew Point
            drawMetricColumn(
                dc,
                x + rightX + colW * 2,
                y,
                colW,
                colHeight,
                "DEW PT",
                Lang.format("$1$", [mWeatherMetrics.dewPoint.format("%.1f")]),
                "°C",
                labelColor,
                textColor,
                unitColor
            );
        }

        // Horizontal dividing line under columns
        dc.setColor(dividerColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x + rightX, y + colHeight, x + w, y + colHeight);

        // --- HAZARD LIST (BELOW METRIC COLUMNS) ---
        var hazardY = y + colHeight;

        var localHazards = mHazardStrings;
        if (localHazards.size() > 0) {
            var lineHeight = Graphics.getFontHeight(Graphics.FONT_XTINY);
            var linePos = hazardY + (lineHeight / 2).toNumber();
            var totalWidth = 3 * colW;
            linePos += StringListRenderer.drawWrappedStrings(
                dc,
                localHazards,
                x + rightX + 2,
                linePos,
                totalWidth,
                localHazards.size(), // maxLines
                Graphics.FONT_XTINY,
                AppState.getColor(ThemeManager.COLOR_HAZARD)
            );
        }

        // --- IMMINENT PRECIPITATION ALERT (ANCHORED AT BOTTOM RIGHT) ---
        if (
            (mMinutesUntilRain >= 0 && mMinutesUntilRain <= 45) ||
            (mMinutesUntilSnow >= 0 && mMinutesUntilSnow <= 45)
        ) {
            var alertX = x + rightX;
            var alertLineHeight = Graphics.getFontHeight(Graphics.FONT_XTINY);
            var alertH = alertLineHeight + 4;
            var alertY = y + h - alertH;
            var alertW = colW * 3;

            dc.setColor(
                AppState.getColor(ThemeManager.COLOR_DEEP_CYAN),
                Graphics.COLOR_TRANSPARENT
            );
            dc.fillRectangle(alertX, alertY, alertW, alertH);

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                alertX + alertW / 2,
                alertY + alertH / 2,
                Graphics.FONT_XTINY,
                $.getPrecipitationAlertMessage(
                    mMinutesUntilRain,
                    mMinutesUntilSnow,
                    false
                ),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }
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

        var textColor = AppState.getColor(ThemeManager.COLOR_TEXT);
        // --- DRAW HEADER BAR ---
        var headerHeight = (h * 0.15).toNumber();

        dc.setColor(riskColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, w, headerHeight);

        // --- TOP BAR: App Title + Risk Level ---
        var headerLineHeight = Graphics.getFontHeight(Graphics.FONT_SMALL);

        var centerHeaderY = y + (headerHeight - headerLineHeight) / 2;
        dc.setColor(riskTextColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x + 6,
            centerHeaderY,
            Graphics.FONT_SMALL,
            mAppName,
            Graphics.TEXT_JUSTIFY_LEFT
        );

        var iconSize = (headerHeight * 0.7).toNumber();
        AlertCategoryRenderer.drawCategoryIcon(
            dc,
            x + 6 + dc.getTextWidthInPixels(mAppName, Graphics.FONT_SMALL) + iconSize,
            centerHeaderY + iconSize / 2,
            iconSize,
            mAlertCategory,
            riskTextColor
        );

        var headerTextPosX = x + w - 6;
        dc.drawText(
            headerTextPosX,
            centerHeaderY,
            Graphics.FONT_SMALL,
            riskLevelText,
            Graphics.TEXT_JUSTIFY_RIGHT
        );
        var headerTextLength = dc.getTextWidthInPixels(
            riskLevelText,
            Graphics.FONT_SMALL
        );
        
        RiskIconRenderer.drawRiskIcon(
            dc,
            headerTextPosX - headerTextLength - iconSize - 1,
            centerHeaderY + iconSize / 2, 
            iconSize,
            mRiskAssessment.riskLevel,
            riskTextColor,
            riskColor
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
                AppState.getColor(ThemeManager.COLOR_DEEP_CYAN),
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
                    mMinutesUntilSnow,
                    false
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
        var dividerColor = AppState.getColor(ThemeManager.COLOR_DIVIDER);
        dc.setColor(dividerColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x + halfW, gridTop, x + halfW, gridTop + gridHeight);
        dc.drawLine(x, gridTop + rowH, x + w, gridTop + rowH);
        dc.drawLine(x, gridTop + gridHeight, x + w, gridTop + gridHeight);

        var labelColor = AppState.getColor(ThemeManager.COLOR_LABEL_LIGHT);
        var unitColor = AppState.getColor(ThemeManager.COLOR_UNIT);

        if (mAlertCategory == CATEGORY_WIND) {
            drawGridCell(
                dc,
                x,
                gridTop,
                halfW,
                rowH,
                "WIND",
                Lang.format("$1$", [mWeatherMetrics.windSpeed.format("%.1f")]),
                "km/h",
                labelColor,
                $.getTemperatureColor(mWeatherMetrics.windSpeed, isDark),
                unitColor
            );
            drawGridCell(
                dc,
                x + halfW,
                gridTop,
                halfW,
                rowH,
                "GUST",
                Lang.format("$1$", [mWeatherMetrics.windGust.format("%.1f")]),
                "km/h",
                labelColor,
                $.getTemperatureColor(mWeatherMetrics.windGust, isDark),
                unitColor
            );

            drawGridCell(
                dc,
                x,
                gridTop + rowH,
                halfW,
                rowH,
                NetwindAnalyzer.formatNetWind(mNetHeadwindKmh),
                Lang.format("$1$", [mNetHeadwindKmh.format("%.1f")]),
                "km/h",
                labelColor,
                $.getNetSpeedColor(mNetHeadwindKmh, isDark),
                unitColor
            );
            drawGridCell(
                dc,
                x + halfW,
                gridTop + rowH,
                halfW,
                rowH,
                "Cx GUST",
                Lang.format("$1$", [
                    mCrossGust.crosswindGustKmH.format("%.1f"),
                ]),
                "km/h",
                labelColor,
                mCrossGust.color,
                unitColor
            );
        } else {
            if ($.gUseFeelsLikeTemperature) {
                drawGridCell(
                    dc,
                    x,
                    gridTop,
                    halfW,
                    rowH,
                    "FEELS LIKE",
                    Lang.format("$1$", [mFeelsLikeTemp.format("%.1f")]),
                    "°C",
                    labelColor,
                    unitColor,
                    $.getTemperatureColor(mFeelsLikeTemp, isDark)
                );
            } else {
                drawGridCell(
                    dc,
                    x,
                    gridTop,
                    halfW,
                    rowH,
                    "AIR TEMP",
                    Lang.format("$1$", [
                        mWeatherMetrics.airTemp.format("%.1f"),
                    ]),
                    "°C",
                    labelColor,
                    unitColor,
                    $.getTemperatureColor(mWeatherMetrics.airTemp, isDark)
                );
            }
            drawGridCell(
                dc,
                x + halfW,
                gridTop,
                halfW,
                rowH,
                "SURFACE TEMP",
                Lang.format("$1$", [
                    mWeatherMetrics.surfaceTemp.format("%.1f"),
                ]),
                "°C",
                labelColor,
                $.getTemperatureColor(mWeatherMetrics.surfaceTemp, isDark),
                unitColor,
            );
            drawGridCell(
                dc,
                x,
                gridTop + rowH,
                halfW,
                rowH,
                "DEW POINT",
                Lang.format("$1$", [mWeatherMetrics.dewPoint.format("%.1f")]),
                "°C",
                labelColor,
                DewpointPalette.getColor(mWeatherMetrics.dewPoint, isDark),
                unitColor,
            );
            drawGridCell(
                dc,
                x + halfW,
                gridTop + rowH,
                halfW,
                rowH,
                "HUMIDITY",
                Lang.format("$1$", [mWeatherMetrics.humidity]),
                "%",
                labelColor,
                $.getHumidityColor(mWeatherMetrics.humidity, isDark),
                unitColor,
            );
        }
        // // --- CURRENT WIND ARROW CENTERED IN GRID ---
        // CurrentWindWidget.draw(
        //     dc,
        //     w / 2, // Widget X center
        //     h / 2, // gridTop + gridHeight / 2, // Widget Y center
        //     0,
        //     h,
        //     mWeatherMetrics.windSpeed, // e.g. 24.0f km/h
        //     mWeatherMetrics.windGust, // e.g. 38.0f km/h
        //     mWeatherMetrics.windDirection, // e.g. 180.0f deg
        //     mHeadingDegrees, // Heading from activity
        //     true, // true = Relative to bike heading, false = Cardinal North
        //     isDark,
        //     false // Big field scaling
        // );
        // 4. Hazards & Advice Section

        dc.setColor(
            AppState.getColor(ThemeManager.COLOR_HAZARD),
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
                AppState.getColor(ThemeManager.COLOR_HAZARD)
            );
        }

        if (!$.gHideRiskAdvice && localAdvice.size() > 0) {
            linePos += StringListRenderer.drawCenteredWrappedStrings(
                dc,
                localAdvice,
                x,
                linePos,
                w,
                localAdvice.size(), // maxLines
                Graphics.FONT_XTINY,
                AppState.getColor(ThemeManager.COLOR_TEXT)
            );
        }
        // --- CURRENT WIND ARROW CENTERED IN GRID ---
        CurrentWindWidget.draw(
            dc,
            w / 2, // Widget X center
            h / 2, // Widget Y center
            0,
            h,
            mWeatherMetrics.windSpeed, // e.g. 24.0f km/h
            mWeatherMetrics.windGust, // e.g. 38.0f km/h
            mWeatherMetrics.windDirection, // e.g. 180.0f deg
            mHeadingDegrees, // Heading from activity
            true, // true = Relative to bike heading, false = Cardinal North
            isDark,
            false // Big field scaling
        );
    }

    private function drawMetricColumn(
        dc as Graphics.Dc,
        x as Number,
        y as Number,
        colWidth as Number,
        height as Number,
        label as String,
        value as String,
        unit as String,
        labelColor as Number,
        valueColor as Number,
        unitColor as Number
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

        var offsetX = 0;
        var hideUnits =
            unit.length() == 0 or ($.gHideUnitsWhenActive and !mPaused);
        var valueWidth = colWidth;
        if (!hideUnits) {
            // Units need to fit too, so make width smaller
            var unitWidth = dc.getTextWidthInPixels(unit, Graphics.FONT_XTINY);
            valueWidth -= unitWidth;
            offsetX = unitWidth / 2;
        }

        // 2. Draw Metric Value (Mild/Medium font centered vertically in remaining space)
        var font =
            $.getMatchingFont(dc, mFontsNumbers, valueWidth, height, value) as
            FontType;

        dc.setColor(valueColor, Graphics.COLOR_TRANSPARENT);
        var valueY = y + (height * 0.68).toNumber();
        dc.drawText(
            centerX - offsetX,
            valueY,
            font,
            value,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        if (hideUnits) {
            return;
        }

        // Unit
        var valueWidth = dc.getTextWidthInPixels(value, font);
        var fontAscent = Graphics.getFontAscent(font);
        var fontDescent = Graphics.getFontDescent(font);

        // Horizontal position: Right edge of main value + small gap (e.g., 2px)
        var unitX = centerX - offsetX + valueWidth / 2 + 2;

        // Vertical baseline calculation: Align with the bottom baseline of the main font
        var mainBaselineY = valueY + fontAscent / 2 - fontDescent / 2;
        var xtinyAscent = Graphics.getFontAscent(Graphics.FONT_XTINY);

        // Vertical position: Offset back up by XTINY's ascent so its baseline aligns perfectly
        var unitY = mainBaselineY - xtinyAscent;

        dc.setColor(unitColor, Graphics.COLOR_TRANSPARENT);
        // 3. Draw unit tag
        dc.drawText(
            unitX,
            unitY,
            Graphics.FONT_XTINY,
            unit,
            Graphics.TEXT_JUSTIFY_LEFT // Left-aligned so it extends to the right
        );

        // 3. Optional Right Divider Line
        dc.setColor(labelColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x + colWidth, y + 4, x + colWidth, y + height - 4);
    }

    private function drawMetricField(
        dc as Graphics.Dc,
        x as Number,
        y as Number,
        labelWidth as Number,
        label as String,
        value as String,
        unit as String,
        labelColor as Number,
        valueColor as Number,
        unitColor as Number
    ) as Void {
        var valueFont = Graphics.FONT_TINY;
        var valueWidth = dc.getTextWidthInPixels(value, valueFont);
        var fontAscent = Graphics.getFontAscent(valueFont);
        var fontDescent = Graphics.getFontDescent(valueFont);

        // Vertical baseline calculation: Align with the bottom baseline of the main font
        var mainBaselineY = y + fontAscent / 2 - fontDescent / 2;
        var xtinyAscent = Graphics.getFontAscent(Graphics.FONT_XTINY);

        // Vertical position: Offset back up by XTINY's ascent so its baseline aligns perfectly
        var labelAndUnitY = mainBaselineY - xtinyAscent;

        dc.setColor(labelColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x,
            labelAndUnitY,
            Graphics.FONT_XTINY,
            label,
            Graphics.TEXT_JUSTIFY_LEFT
        );

        dc.setColor(valueColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x + labelWidth,
            y,
            Graphics.FONT_TINY,
            value,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );

        if ($.gHideUnitsWhenActive and !mPaused) {
            return;
        }

        dc.setColor(unitColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x + labelWidth + valueWidth,
            labelAndUnitY,
            Graphics.FONT_XTINY,
            unit,
            Graphics.TEXT_JUSTIFY_LEFT
        );
    }

    function playAlert() as Void {
        if (!(Attention has :playTone) || !System.getDeviceSettings().tonesOn) {
            return;
        }

        Attention.playTone(Attention.TONE_ALERT_HI);
        System.println("Playing alert tone");
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
                message = message + "-" + hazardStr;
            }
        }

        // Show incoming rain and snow alerts if applicable
        if (mAlertIncomingRain >= 0) {
            message = message + "Rain in " + mAlertIncomingRain + " minutes";
        }
        if (mAlertIncomingSnow >= 0) {
            message = message + "Snow in " + mAlertIncomingSnow + " minutes";
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
