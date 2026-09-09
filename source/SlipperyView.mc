import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class SlipperyView extends WatchUi.DataField {
    var mBGServiceHandler as BGServiceHandler;
    var mCurrentLocation as CurrentLocation = new CurrentLocation();
    var mEdgeField as EdgeField = EfSmall;
    var mHeight as Number = 0;
    var mWidth as Number = 0;
    var mIsDark as Boolean = false;

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
        // mCurWpt = new WayPoint(degrees[0], degrees[1]);
    }

    function onBackgroundData(data as Dictionary) as Void {
        // var poiData = $.toPoiData(data);
        // if (poiData.set.length() > 0) {
        //   mWpts = poiData.pts;
        //   mPoiSetName = poiData.set;
        //   mPoiSetId = $.toPOISet(poiData.set_id);
        // }
        // if (mDc != null) {
        //   calculateOptimalZoom(mDc as Dc);
        // }
    }

    // Set your layout here. Anytime the size of obscurity of
    // the draw context is changed this will be called.
    function onLayout(dc as Dc) as Void {
        dc.clearClip();

        mHeight = dc.getHeight();
        mWidth = dc.getWidth();

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
        mIsDark = (getBackgroundColor() == Graphics.COLOR_BLACK);

        var textColor = ThemeManager.getThemeColor(:text, mIsDark) ;

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

        var statsWH = dc.getTextDimensions(stats, Graphics.FONT_XTINY);
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            mWidth,
            mHeight - statsWH[1],
            Graphics.FONT_XTINY,
            stats,
            Graphics.TEXT_JUSTIFY_RIGHT
        );

        if (mBGServiceHandler.getRequestCounter() == 0) {
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

            dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                mWidth / 2,
                mHeight / 2,
                Graphics.FONT_SYSTEM_SMALL,
                stats,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }
    }
}
