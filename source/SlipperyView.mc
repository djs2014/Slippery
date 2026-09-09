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
    private var mWeatherMetrics as WeatherMetrics;
    private var mRiskAssessment as RiskAssessment;

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
        System.println(weatherMetrics.toString());
        mWeatherMetrics = weatherMetrics;
        mRiskAssessment = $.calculateRiskAssessment(weatherMetrics);
        System.println(mRiskAssessment.toString());
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
    }

    function onUpdate(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        mIsDark = getBackgroundColor() == Graphics.COLOR_BLACK;

        // 1. Clear background
        dc.setColor(getBackgroundColor(), getBackgroundColor());
        dc.clear();

        

        if (mEdgeField == EfOne) {
            drawEdgeOneField(dc, width, height, mIsDark);
        } else if (mEdgeField == EfSmall) {
            drawEdgeSmallField(dc, width, height, mIsDark);
        } else if (mEdgeField == EfLarge) {
            drawEdgeLargeField(dc, width, height, mIsDark);
        } else if (mEdgeField == EfWide) {
            drawEdgeWideField(dc, width, height, mIsDark);
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

    private function drawEdgeOneField(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        isDark as Boolean
    ) as Void {
        var riskColor = getRiskColor(mRiskAssessment.riskLevel, isDark);
        var riskLabel = getRiskLevelString(mRiskAssessment.riskLevel);

        var headerBg = riskColor;
        var headerText = riskLabel;

        // --- DRAW HEADER BAR ---
        var headerHeight = (h * 0.22).toNumber();
        dc.setColor(headerBg, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, headerHeight);

        // Header Text
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            w / 2,
            headerHeight / 2,
            Graphics.FONT_MEDIUM,
            headerText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        // --- DRAW 2x2 METRICS GRID ---
        var gridTop = headerHeight + 4;
        var gridHeight = (h * 0.45).toNumber();
        var colWidth = w / 2;
        var rowHeight = gridHeight / 2;

        var textColor = isDark ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        var labelColor = isDark
            ? Graphics.COLOR_LT_GRAY
            : Graphics.COLOR_DK_GRAY;

        // Cell 1: Air Temp
        drawGridCell(
            dc,
            0,
            gridTop,
            colWidth,
            rowHeight,
            "AIR TEMP",
            Lang.format("$1$°C", [mWeatherMetrics.airTemp.format("%.1f")]),
            labelColor,
            textColor
        );

        // Cell 2: Surface Temp
        var surfColor =
            mWeatherMetrics.surfaceTemp <= 0 ? Graphics.COLOR_RED : textColor;
        drawGridCell(
            dc,
            colWidth,
            gridTop,
            colWidth,
            rowHeight,
            "SURFACE",
            Lang.format("$1$°C", [mWeatherMetrics.surfaceTemp.format("%.1f")]),
            labelColor,
            surfColor
        );

        // Cell 3: Dew Point
        drawGridCell(
            dc,
            0,
            gridTop + rowHeight,
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
            colWidth,
            gridTop + rowHeight,
            colWidth,
            rowHeight,
            "HUMIDITY",
            Lang.format("$1$%", [mWeatherMetrics.humidity]),
            labelColor,
            textColor
        );

        // Grid Separator Lines
        dc.setColor(labelColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(colWidth, gridTop, colWidth, gridTop + gridHeight); // Vertical
        dc.drawLine(0, gridTop + rowHeight, w, gridTop + rowHeight); // Horizontal
        dc.drawLine(0, gridTop + gridHeight, w, gridTop + gridHeight); // Bottom

        // --- DRAW FOOTER: HAZARD & ADVICE TEXT ---
        var footerTop = gridTop + gridHeight + 6;
        if (mRiskAssessment.hazards.size() > 0) {
            var primaryHazardStr = getHazardString(mRiskAssessment.hazards[0]);

            dc.setColor(
                mIsDark ? 0xe5ff00 : 0xb38f00,
                Graphics.COLOR_TRANSPARENT
            );
            dc.drawText(
                w / 2,
                footerTop,
                Graphics.FONT_XTINY,
                primaryHazardStr,
                Graphics.TEXT_JUSTIFY_CENTER
            );
        }

        if (mRiskAssessment.advice.size() > 0) {
            var primaryAdviceStr = getAdviceString(mRiskAssessment.advice[0]);

            dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                w / 2,
                footerTop + 18,
                Graphics.FONT_XTINY,
                primaryAdviceStr,
                Graphics.TEXT_JUSTIFY_CENTER
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
        w as Number,
        h as Number,
        isDark as Boolean
    ) as Void {
        var riskColor = getRiskColor(mRiskAssessment.riskLevel, isDark);
        var riskLabel = getShortRiskLabel(mRiskAssessment.riskLevel);

        // Left 30%: Solid risk badge
        var badgeWidth = (w * 0.3).toNumber();
        dc.setColor(riskColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, badgeWidth, h);

        // Badge text
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            badgeWidth / 2,
            h / 2,
            Graphics.FONT_TINY,
            riskLabel,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        // Right 70%: Surface Temp & Primary Hazard
        var textX = badgeWidth + 6;
        var textColor = isDark ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;

        // 1: Surface Temp
        var y = 2;
        var lineHeight = dc.getFontHeight(Graphics.FONT_XTINY) + 1;
        var surfStr = Lang.format("SURF $1$°C", [
            mWeatherMetrics.surfaceTemp.format("%.1f"),
        ]);
        dc.setColor(
            mWeatherMetrics.surfaceTemp <= 0 ? Graphics.COLOR_RED : textColor,
            Graphics.COLOR_TRANSPARENT
        );
        dc.drawText(
            textX,
            y,
            Graphics.FONT_XTINY,
            surfStr,
            Graphics.TEXT_JUSTIFY_LEFT
        );
        // 2: Humidity
        var humidityStr = Lang.format("HUM $1$%", [
            mWeatherMetrics.humidity.format("%.1f"),
        ]);
        dc.setColor(
            mWeatherMetrics.humidity >= 80 ? Graphics.COLOR_RED : textColor,
            Graphics.COLOR_TRANSPARENT
        );
        dc.drawText(
            textX,
            y + lineHeight,
            Graphics.FONT_XTINY,
            humidityStr,
            Graphics.TEXT_JUSTIFY_LEFT
        );

        // 3: All Hazard strings (shortened)
        if (mRiskAssessment.hazards.size() > 0) {
            for (var i = 0; i < mRiskAssessment.hazards.size(); i += 1) {
                var hazardStr = getShortHazardString(mRiskAssessment.hazards[i]);
                dc.setColor(
                    isDark ? Graphics.COLOR_LT_GRAY : Graphics.COLOR_DK_GRAY,
                    Graphics.COLOR_TRANSPARENT
                );
                dc.drawText(
                    textX,
                    h - 16 + i * lineHeight,
                    Graphics.FONT_XTINY,
                    hazardStr,
                    Graphics.TEXT_JUSTIFY_LEFT
                );
            }            
        }
    }

    function drawEdgeWideField(
        dc as Graphics.Dc,
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
        dc.fillRectangle(0, 0, leftWidth, (h * 0.55).toNumber());

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            leftWidth / 2,
            (h * 0.27).toNumber(),
            Graphics.FONT_MEDIUM,
            riskLabel,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        // Hazard text underneath badge
        if (mRiskAssessment.hazards.size() > 0) {
            dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                leftWidth / 2,
                h - 18,
                Graphics.FONT_XTINY,
                getHazardString(mRiskAssessment.hazards[0]),
                Graphics.TEXT_JUSTIFY_CENTER
            );
        }

        // Divider Line
        dc.setColor(labelColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(leftWidth, 0, leftWidth, h);

        // Right Column (65%): 3 Metrics Side-by-Side
        var rightX = leftWidth;
        var colW = (w - leftWidth) / 3;

        // Col 1: Air Temp
        drawMetricColumn(
            dc,
            rightX,
            0,
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
            rightX + colW,
            0,
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
            rightX + colW * 2,
            0,
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
        dc.fillRectangle(0, 0, w, headerH);

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            w / 2,
            headerH / 2,
            Graphics.FONT_LARGE,
            getRiskLevelString(mRiskAssessment.riskLevel),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        // 2. Main 2x2 Grid
        var gridY = headerH + 4;
        var gridH = (h * 0.4).toNumber();
        var halfW = w / 2;
        var rowH = gridH / 2;

        drawGridCell(
            dc,
            0,
            gridY,
            halfW,
            rowH,
            "AIR TEMP",
            Lang.format("$1$°C", [mWeatherMetrics.airTemp.format("%.1f")]),
            labelColor,
            textColor
        );
        drawGridCell(
            dc,
            halfW,
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
            0,
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
            halfW,
            gridY + rowH,
            halfW,
            rowH,
            "HUMIDITY",
            Lang.format("$1$%", [mWeatherMetrics.humidity]),
            labelColor,
            textColor
        );

        // Grid Dividers
        dc.setColor(labelColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(halfW, gridY, halfW, gridY + gridH);
        dc.drawLine(0, gridY + rowH, w, gridY + rowH);
        dc.drawLine(0, gridY + gridH, w, gridY + gridH);

        // 3. Secondary Environmental Context Strip
        var stripY = gridY + gridH + 6;
        var stripStr = Lang.format("Dry: $1$h | Precip: $2$mm | Season: $3$", [
            mWeatherMetrics.dryStreak,
            mWeatherMetrics.precip12hSum.format("%.1f"),
            getSeasonString(mWeatherMetrics.currentSeason),
        ]);
        dc.setColor(labelColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            w / 2,
            stripY,
            Graphics.FONT_XTINY,
            stripStr,
            Graphics.TEXT_JUSTIFY_CENTER
        );

        // 4. Hazards & Advice Section
        var footerY = stripY + 22;
        dc.setColor(isDark ? 0xe5ff00 : 0xb38f00, Graphics.COLOR_TRANSPARENT);

        // Primary & Secondary Hazards
        if (mRiskAssessment.hazards.size() > 0) {
            var h1 = getHazardString(mRiskAssessment.hazards[0]);
            var h2 =
                mRiskAssessment.hazards.size() > 1
                    ? " / " + getHazardString(mRiskAssessment.hazards[1])
                    : "";
            dc.drawText(
                w / 2,
                footerY,
                Graphics.FONT_XTINY,
                h1 + h2,
                Graphics.TEXT_JUSTIFY_CENTER
            );
        }
        // Actionable Advice
        if (mRiskAssessment.advice.size() > 0) {
            dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
            var a1 = getAdviceString(mRiskAssessment.advice[0]);
            dc.drawText(
                w / 2,
                footerY + 20,
                Graphics.FONT_XTINY,
                a1,
                Graphics.TEXT_JUSTIFY_CENTER
            );
        }
        // Actionable Advice
        if (mRiskAssessment.advice.size() > 0) {
            dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
            var a1 = getAdviceString(mRiskAssessment.advice[0]);
            dc.drawText(
                w / 2,
                footerY + 20,
                Graphics.FONT_XTINY,
                a1,
                Graphics.TEXT_JUSTIFY_CENTER
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

        var font = $.getMatchingFont(
            dc,
            mFontsNumbers,
            colWidth,
            height,
            value
          ) as FontType;

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
  while ((dimensions[0] > maxWidth || dimensions[1] > maxHeight) && index > 0) {
    index = index - 1;
    font = fontList[index] as FontType;
    dimensions = dc.getTextDimensions(text, font);
    // System.println(Lang.format(" dim w[$1$]h[$2$]",dimensions));
  }
  // System.println("font index: " + index);
  return font;
}