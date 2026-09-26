import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.System;

class DataFieldSettingsMenu extends WatchUi.Menu2 {
  function initialize() {
    Menu2.initialize({ :title => "Settings" });
  }
}

//! Handles menu input and stores the menu data
class DataFieldSettingsMenuDelegate extends WatchUi.Menu2InputDelegate {
  hidden var _item as MenuItem?;
  hidden var _storageKey as String = "";
  hidden var _arrayIndex as Number = -1;

  function initialize() {
    Menu2InputDelegate.initialize();
    // _view = view;
  }

  function onSelect(menuItem as MenuItem) as Void {
    _item = menuItem;
    var id = menuItem.getId();

    // System.println(["onSelect id", id, id.toString(), id instanceof String]);

    // Extract selected storage key and index
    _storageKey = stringLeft(id.toString(), "|", id.toString());
    var idx = stringRight(id.toString(), "|", "").toNumber();
    if (idx == null) {
      _arrayIndex = -1;
    } else {
      _arrayIndex = idx;
    }
    if (id instanceof String && id.equals("background")) {
      var proxyMenu = new WatchUi.Menu2({ :title => "Background config" });

      var mi = new WatchUi.MenuItem(
        "Minimal GPS",
        null,
        "minimalGPSquality",
        null
      );
      var value =
        getStorageValue(mi.getId() as String, $.gMinimalGPSquality) as Number;
      mi.setSubLabel($.getMinimalGPSqualityText(value));
      proxyMenu.addItem(mi);
      // @@ url - text picker
      // @@ apikey - text picker
      mi = new WatchUi.MenuItem(
        "Checkinterval minutes",
        null,
        "checkIntervalMinutes",
        null
      );
      mi.setSubLabel($.getStorageNumberAsString(mi.getId() as String));
      proxyMenu.addItem(mi);

      mi = new WatchUi.MenuItem(
        "Background timeout sec",
        null,
        "g_bg_timeout_seconds",
        null
      );
      mi.setSubLabel($.getStorageNumberAsString(mi.getId() as String));
      proxyMenu.addItem(mi);

      mi = new WatchUi.MenuItem(
        "Background delay sec",
        null,
        "g_bg_delay_seconds",
        null
      );
      mi.setSubLabel($.getStorageNumberAsString(mi.getId() as String));
      proxyMenu.addItem(mi);

      WatchUi.pushView(
        proxyMenu,
        new $.GeneralMenuDelegate(),
        WatchUi.SLIDE_UP
      );
      return;
    }

    if (id instanceof String && id.equals("alerts")) {
      var alertMenu = new WatchUi.Menu2({ :title => "Alerts" });

      var boolean = Storage.getValue("alert_beep") ? true : false;
      alertMenu.addItem(
        new WatchUi.ToggleMenuItem(
          "Beep on alert",
          null,
          "alert_beep",
          boolean,
          null
        )
      );

      boolean = Storage.getValue("alert_toast") ? true : false;
      alertMenu.addItem(
        new WatchUi.ToggleMenuItem(
          "Toast message on alert",
          null,
          "alert_toast",
          boolean,
          null
        )
      );
      boolean = Storage.getValue("alert_beep_state_change") ? true : false;
      alertMenu.addItem(
        new WatchUi.ToggleMenuItem(
          "Beep on alert state change",
          null,
          "alert_beep_state_change",
          boolean,
          null
        )
      );

      if (id instanceof String && menuItem instanceof ToggleMenuItem) {
        $.StorageSetValue(id as String, menuItem.isEnabled());
        return;
      }

      WatchUi.pushView(
        alertMenu,
        new $.GeneralMenuDelegate(),
        WatchUi.SLIDE_UP
      );
      return;
    }

    if (id instanceof String && id.equals("thresholds")) {
      var trshMenu = new WatchUi.Menu2({ :title => "Thresholds" });

      var mi;

      mi = new WatchUi.MenuItem(
        "Ice Alert|-10~10.0 (°C)",
        null,
        "threshIceAlert",
        null
      );
      mi.setSubLabel($.getStorageFloatAsString(mi.getId() as String));
      trshMenu.addItem(mi);

      mi = new WatchUi.MenuItem(
        "High Crosswind|0~100.0 (km/h)",
        null,
        "threshHighCrosswind",
        null
      );
      mi.setSubLabel($.getStorageFloatAsString(mi.getId() as String));
      trshMenu.addItem(mi);

      mi = new WatchUi.MenuItem(
        "Cross Gust|0~100.0 (km/h)",
        null,
        "threshCrossGust",
        null
      );
      mi.setSubLabel($.getStorageFloatAsString(mi.getId() as String));
      trshMenu.addItem(mi);

      mi = new WatchUi.MenuItem(
        "Heavy Wind|0~100.0 (km/h)",
        null,
        "threshHeavyWind",
        null
      );
      mi.setSubLabel($.getStorageFloatAsString(mi.getId() as String));
      trshMenu.addItem(mi);

      mi = new WatchUi.MenuItem(
        "Sustained Wind|0~100.0 (km/h)",
        null,
        "threshSustainedWind",
        null
      );
      mi.setSubLabel($.getStorageFloatAsString(mi.getId() as String));
      trshMenu.addItem(mi);

      mi = new WatchUi.MenuItem(
        "Headwind|0~100.0 (km/h)",
        null,
        "threshHeadwind",
        null
      );
      mi.setSubLabel($.getStorageFloatAsString(mi.getId() as String));
      trshMenu.addItem(mi);

      mi = new WatchUi.MenuItem(
        "Heat Stress|0~50.0 (°C)",
        null,
        "threshHeatStress",
        null
      );
      mi.setSubLabel($.getStorageFloatAsString(mi.getId() as String));
      trshMenu.addItem(mi);

      mi = new WatchUi.MenuItem(
        "Precip Ahead|0~20.0 (mm/h)",
        null,
        "threshPrecipAhead",
        null
      );
      mi.setSubLabel($.getStorageFloatAsString(mi.getId() as String));
      trshMenu.addItem(mi);

      WatchUi.pushView(trshMenu, new $.GeneralMenuDelegate(), WatchUi.SLIDE_UP);
      return;
    }

    if (
      id instanceof String &&
      (id.equals("show_one_field") ||
        id.equals("show_large_field") ||
        id.equals("show_wide_field") ||
        id.equals("show_small_field"))
    ) {
      var label = menuItem.getLabel();
      var fieldMenu = new WatchUi.Menu2({ :title => label + " items" });

      var storageKey = id.toString();

      var array = $.getStorageValue(storageKey, []) as Array<Number or Boolean>;
      // Check size
      if (
        $.ensureArraySize(
          array as Array<Application.PropertyValueType>,
          $.gSizeArrFieldItems,
          0
        )
      ) {
        $.setStorageValueOrArray(
          storageKey,
          array as Array<Application.PropertyValueType>
        );
      }
      var isWideField = id.equals("show_wide_field");
      var isSmallField = id.equals("show_small_field");
      var showShowHazards = !isSmallField;
      var showShortHazard = !isWideField && !isSmallField;
      var showShowAdvice = !isWideField && !isSmallField;
      var showSimplifyWind = !isSmallField;

      var index = 0;
      if (showShowHazards) {
        $.addToggleMenuItem(
          fieldMenu,
          "Show hazards",
          null,
          $.getKeyAndIndex(storageKey, index),
          array[index] == true
        );
      }
      index = 1;
      if (showShortHazard) {
        $.addToggleMenuItem(
          fieldMenu,
          "Short hazard",
          null,
          $.getKeyAndIndex(storageKey, index),
          array[index] == true
        );
      }

      index = 2;
      if (showShowAdvice) {
        $.addToggleMenuItem(
          fieldMenu,
          "Show advice",
          null,
          $.getKeyAndIndex(storageKey, index),
          array[index] == true
        );
      }

      index = 3;
      if (showSimplifyWind) {
        $.addToggleMenuItem(
          fieldMenu,
          "Simplify wind",
          null,
          $.getKeyAndIndex(storageKey, index),
          array[index] == true
        );
      }

      index = 4;
      $.addToggleMenuItem(
        fieldMenu,
        "Show risk footer",
        null,
        $.getKeyAndIndex(storageKey, index),
        array[index] == true
      );

      index = 5;
      $.addToggleMenuItem(
        fieldMenu,
        "Show effective crossgust",
        null,
        $.getKeyAndIndex(storageKey, index),
        array[index] == true
      );

      index = 6;
      $.addToggleMenuItem(
        fieldMenu,
        "Show feelslike temperature",
        null,
        $.getKeyAndIndex(storageKey, index),
        array[index] == true
      );

      index = 7;
      $.addToggleMenuItem(
        fieldMenu,
        "Show winddata default",
        null,
        $.getKeyAndIndex(storageKey, index),
        array[index] == true
      );

      // $.addMenuItem(
      //   fieldMenu,
      //   "Hours forecast|0~24",
      //   (array[index] as Number).toString(),
      //   getKeyAndIndex(storageKey, index)
      // );
      // index = 9; // show_one_field|9 etc
      // $.addMenuItem(
      //   fieldMenu,
      //   "Wind unit",
      //   $.getShowWindText(array[index] as Number),
      //   $.getKeyAndIndex(storageKey, index)
      // );

      WatchUi.pushView(
        fieldMenu,
        new $.GeneralMenuDelegate(),
        WatchUi.SLIDE_UP
      );
      return;
    }

    if (id instanceof String && id.equals("advanced")) {
      var advMenu = new WatchUi.Menu2({ :title => "Advanced" });

      var mi;

      mi = new WatchUi.MenuItem(
        "Forecast hours",
        null,
        "showForecastHour",
        null
      );
      var value =
        getStorageValue(mi.getId() as String, $.gShowForecastHour) as Number;
      mi.setSubLabel($.getShowForecastHourText(value));
      advMenu.addItem(mi);

      mi = new WatchUi.MenuItem(
        "HSP breakpoint|0-255.0(HSP)",
        null,
        "hsp_darklight_breakpoint",
        null
      );
      mi.setSubLabel($.getStorageFloatAsString(mi.getId() as String));
      advMenu.addItem(mi);

      var boolean;

      boolean = Storage.getValue("hsp_showvalue") ? true : false;
      advMenu.addItem(
        new WatchUi.ToggleMenuItem(
          "Show HSP value",
          null,
          "hsp_showvalue",
          boolean,
          null
        )
      );

      boolean = Storage.getValue("hideUnitsWhenActive") ? true : false;
      advMenu.addItem(
        new WatchUi.ToggleMenuItem(
          "Hide Units When Active",
          null,
          "hideUnitsWhenActive",
          boolean,
          null
        )
      );

      WatchUi.pushView(advMenu, new $.GeneralMenuDelegate(), WatchUi.SLIDE_UP);
      return;
    }

    if (id instanceof String && menuItem instanceof ToggleMenuItem) {
      $.StorageSetValue(id as String, menuItem.isEnabled());
      return;
    }
  }
}

class GeneralMenuDelegate extends WatchUi.Menu2InputDelegate {
  hidden var _item as MenuItem?;
  hidden var _currentPrompt as String = "";
  hidden var _debug as Boolean = false;

  function initialize() {
    Menu2InputDelegate.initialize();
  }

  function onSelect(item as MenuItem) as Void {
    _item = item;
    var id = item.getId();

    if (id instanceof String && id.equals("noop")) {
      return;
    }

    if (id instanceof String && id.equals("minimalGPSquality")) {
      var sp = new selectionMenuPicker("Minimal GPS", id as String);
      for (var i = 0; i <= 4; i++) {
        sp.add($.getMinimalGPSqualityText(i), null, i);
      }
      sp.setOnSelected(self, :onSelectedSelection, item);
      sp.show();
      return;
    }
    if (id instanceof String && id.equals("showForecastHour")) {
      var sp = new selectionMenuPicker("Show Forecast Hour", id as String);
      for (var i = 0; i < MaxForecastHourItems; i++) {
        sp.add($.getShowForecastHourText(i), null, i);
      }
      sp.setOnSelected(self, :onSelectedSelection, item);
      sp.show();
      return;
    }
    if (id instanceof String && id.equals("minimalGPSquality")) {
      var sp = new selectionMenuPicker("Minimal GPS", id as String);
      for (var i = 0; i <= 4; i++) {
        sp.add($.getMinimalGPSqualityText(i), null, i);
      }
      sp.setOnSelected(self, :onSelectedSelection, item);
      sp.show();
      return;
    }

    if (id instanceof String && item instanceof ToggleMenuItem) {
      Storage.setValue(id as String, item.isEnabled());
      return;
    }

    // Numeric input
    var prompt = item.getLabel();
    var value = $.getStorageValue(id as String, 0) as Numeric;
    var view = $.getNumericInputView(prompt, value);
    view.setOnAccept(self, :onAcceptNumericinput);
    view.setOnKeypressed(self, :onNumericinput);

    Toybox.WatchUi.pushView(
      view,
      new $.NumericInputDelegate(view),
      WatchUi.SLIDE_RIGHT
    );
  }

  function onAcceptNumericinput(value as Numeric, subLabel as String) as Void {
    try {
      if (_item != null) {
        var storageKey = _item.getId() as String;

        Storage.setValue(storageKey, value);
        (_item as MenuItem).setSubLabel(subLabel);
      }
    } catch (ex) {
      ex.printStackTrace();
    }
  }

  function onNumericinput(
    editData as Array<Char>,
    cursorPos as Number,
    insert as Boolean,
    negative as Boolean,
    opt as NumericOptions
  ) as Void {
    // Hack to refresh screen
    WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    var view = new $.NumericInputView("", 0);
    view.processOptions(opt);
    view.setEditData(editData, cursorPos, insert, negative);
    view.setOnAccept(self, :onAcceptNumericinput);
    view.setOnKeypressed(self, :onNumericinput);

    Toybox.WatchUi.pushView(
      view,
      new $.NumericInputDelegate(view),
      WatchUi.SLIDE_IMMEDIATE
    );
  }

  //! Handle the back key being pressed

  function onBack() as Void {
    WatchUi.popView(WatchUi.SLIDE_DOWN);
  }

  //! Handle the done item being selected

  function onDone() as Void {
    WatchUi.popView(WatchUi.SLIDE_DOWN);
  }

  function onSelectedSelection(
    storageKey as String,
    value as Application.PropertyValueType
  ) as Void {
    Storage.setValue(storageKey, value);
  }
}

function StorageSetValue(
  key as Application.PropertyKeyType,
  value as Application.PropertyValueType
) as Void {
  try {
    Toybox.Application.Storage.setValue(key, value);
  } catch (ex) {
    ex.printStackTrace();
  }
}

function addMenuItem(
  menu as WatchUi.Menu2,
  label as String,
  subLabel as String,
  id as String
) {
  var mi = new WatchUi.MenuItem(label, subLabel, id, null);
  menu.addItem(mi);
}

function addToggleMenuItem(
  menu as WatchUi.Menu2,
  label as String,
  subLabel as String?,
  id as String,
  enabled as Boolean
) {
  var tmi = new WatchUi.ToggleMenuItem(label, subLabel, id, enabled, null);
  menu.addItem(tmi);
}

function getKeyAndIndex(key as String, index as Number) as String {
  return Lang.format("$1$|$2$", [key, index.toString()]);
}
