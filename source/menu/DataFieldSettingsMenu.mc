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
  // hidden var _currentMenuItem as MenuItem?;
  // hidden var _view as DataFieldSettingsView;

  function initialize() {
    Menu2InputDelegate.initialize();
    // _view = view;
  }

  function onSelect(item as MenuItem) as Void {
    // _currentMenuItem = item;
    var id = item.getId();

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

      if (id instanceof String && item instanceof ToggleMenuItem) {
        $.StorageSetValue(id as String, item.isEnabled());
        return;
      }

      WatchUi.pushView(
        alertMenu,
        new $.GeneralMenuDelegate(),
        WatchUi.SLIDE_UP
      );
      return;
    }

    if (id instanceof String && id.equals("advanced")) {
      var advMenu = new WatchUi.Menu2({ :title => "Advanced" });

      var mi;

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

      WatchUi.pushView(advMenu, new $.GeneralMenuDelegate(), WatchUi.SLIDE_UP);
      return;
    }

    if (id instanceof String && item instanceof ToggleMenuItem) {
      $.StorageSetValue(id as String, item.isEnabled());
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
