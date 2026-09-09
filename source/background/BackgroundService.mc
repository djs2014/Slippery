import Toybox.Application;
import Toybox.Lang;
import Toybox.Time;
import Toybox.System;
import Toybox.Background;
import Toybox.Sensor;
import Toybox.Application.Storage;
import Toybox.Communications;
// using CommunicationsHelpers as Helpers;

(:background)
class BackgroundServiceDelegate extends System.ServiceDelegate {
  function initialize() {
    System.println("BackgroundServiceDelegate initialize");
    ServiceDelegate.initialize();
  }

  public function onTemporalEvent() as Void {
    try {
      System.println("BackgroundServiceDelegate onTemporalEvent");

      var error = fetchOpenMeteoData();
      System.println(
        "BackgroundServiceDelegate fetchOpenMeteoData result " + error
      );
      if (error != 0) {
        Background.exit(error);
      }
    } catch (ex) {
      System.println(ex.getErrorMessage());
      ex.printStackTrace();
      Background.exit(CustomErrors.ERROR_BG_EXCEPTION);
    }
  }

  function fetchOpenMeteoData() as Number {
    try {
      System.println("BackgroundServiceDelegate fetchOpenMeteoData");

      var location = Storage.getValue("latest_latlng");
      if (location == null) {
        return CustomErrors.ERROR_BG_NO_POSITION;
      }
      var lat = (location as Array)[0] as Double;
      var lon = (location as Array)[1] as Double;
      if (
        (lat >= 179.99 || lat <= -179.99) &&
        (lon >= 179.99 || lon <= -179.99)
      ) {
        System.println(
          "1 Invalid location lat[" +
            lat +
            "] lon[" +
            lon +
            "] exit background service"
        );
        return CustomErrors.ERROR_BG_NO_POSITION;
      }

      var pastDays = 1;
      var apiUrl = "https://api.open-meteo.com/v1/forecast";

      // convert the lat and lon comma to period
      var latStr = replaceCommaWithDot(lat.format("%.6f"));
      var lonStr = replaceCommaWithDot(lon.format("%.6f"));
      System.println(
        Lang.format("Url[$1$] location lat[$2$] lon[$3$]", [
          apiUrl,
          latStr,
          lonStr,
        ])
      );

      //  latStr = "52.188950";
      //  lonStr = "4.549666";

      // Convert coordinates to String explicitly
      // Format hourly variables as a single comma-separated String, NOT an array!
      var params =
        ({
          "latitude" => latStr,
          "longitude" => lonStr,
          "hourly"
          =>
          "temperature_2m,relativehumidity_2m,dewpoint_2m,precipitation,rain,snowfall,surface_temperature",
          "past_days" => pastDays.toString(),
          "forecast_days" => "1",
          "timezone" => "auto", // Convert to local time
          "timeformat" => "unixtime", // payload is smaller
        }) as Lang.Dictionary<Lang.Object, Lang.Object>;

      if (!requestData(apiUrl as String, params)) {
        return CustomErrors.ERROR_BG_EXCEPTION;
      }
      return 0;
    } catch (ex) {
      System.println(ex.getErrorMessage());
      ex.printStackTrace();
      return CustomErrors.ERROR_BG_EXCEPTION;
    }
  }

  function requestData(
    url as String,
    params as Lang.Dictionary<Lang.Object, Lang.Object>
  ) as Boolean {
    try {
      System.println("Requesting data from URL: " + url);
      System.println("Request parameters: " + params);
      var options = {
        :method => Communications.HTTP_REQUEST_METHOD_GET,
        :headers => {
          "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
          "Accept" => "application/json",
        },
        :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
      };
      var responseCallBack = method(:onReceiveWeather);

      Communications.makeWebRequest(url, params, options, responseCallBack);
      return true;
    } catch (ex) {
      System.println(ex.getErrorMessage());
      ex.printStackTrace();
    }
    return false;
  }

  function onReceiveWeather(
    responseCode as Lang.Number,
    responseData as Lang.Dictionary or Null or Lang.String
  ) as Void {
    try {
      System.println("onReceiveWeather responseCode " + responseCode);
      if (responseCode == 200 && responseData != null) {
        System.println("onReceiveWeather data not null");
        // !! Do not convert responseData to string (println etc..) --> gives out of memory
        //System.println(responseData);   --> gives out of memory
        // var data = responseData as String;  --> gives out of memory
        Background.exit(responseData as PropertyValueType);
      } else {
        System.println("Not 200");
        System.println(responseData);
        Background.exit(responseCode);
      }
    } catch (ex instanceof Background.ExitDataSizeLimitException) {
      System.println(ex.getErrorMessage());
      ex.printStackTrace();
      Background.exit(CustomErrors.ERROR_BG_EXIT_DATA_SIZE_LIMIT);
    } catch (ex) {
      System.println(ex.getErrorMessage());
      ex.printStackTrace();
      Background.exit(CustomErrors.ERROR_BG_EXCEPTION);
    }
  }

  function replaceCommaWithDot(str as String?) as String {
    if (str == null) {
      return "";
    }

    var chars = str.toCharArray();
    var result = "";

    for (var i = 0; i < chars.size(); i++) {
      if (chars[i] == ',') {
        result += ".";
      } else {
        result += chars[i];
      }
    }

    return result;
  }
}
