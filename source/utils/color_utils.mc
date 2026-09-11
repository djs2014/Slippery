import Toybox.System;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Graphics;
import Toybox.Application;
import Toybox.Application.Storage;

var gCreateColors as Boolean = false;
var gUseSetFillStroke as Boolean = false;

function checkFeatures() as Void {
  $.gCreateColors = Graphics has : createColor;
  try {
    $.gUseSetFillStroke = Graphics.Dc has : setStroke;
    if ($.gUseSetFillStroke) {
      $.gUseSetFillStroke = Graphics.Dc has : setFill;
    }
  } catch (ex) {
    ex.printStackTrace();
  }
}

// [perc, R, G, B]
const PERC_COLORS_SCHEME_DIST =
  [
    [0, 0, 0, 0], // Black
    [100, 170, 170, 170],    // COLOR_LT_GRAY 
  ] as Array<Array<Number> >;

// alpha, 255 is solid, 0 is transparent
function percentageToColorAlt(
  percentage as Numeric?,
  alpha as Number,
  colorScheme as Array<Array<Number> >,
  darker as Number
) as ColorType {
  var pcolor = 0;
  var pColors = colorScheme;
  if (percentage == null || percentage == 0) {
    return Graphics.createColor(alpha, 255, 255, 255); //@@get from scheme
  }
  // else if (percentage >= 100) {
  //   // final entry
  //   pcolor = pColors[pColors.size() - 1] as Array<Number>;
  //   return Graphics.createColor(alpha, pcolor[1], pcolor[2], pcolor[3]);
  // }

  var i = 1;
  while (i < pColors.size()) {
    pcolor = pColors[i] as Array<Number>;
    if (percentage <= pcolor[0]) {
      break;
    }
    i++;
  }
  if (i >= pColors.size()) {
    i = pColors.size() - 1;
  }

  // System.println(percentage);
  // System.println(i);

  var lower = pColors[i - 1];
  var upper = pColors[i];
  var range = upper[0] - lower[0];
  var rangePct = 1;
  if (range != 0) {
    rangePct = (percentage - lower[0]) / range;
  }
  var pctLower = 1 - rangePct;
  var pctUpper = rangePct;

  var red = Math.floor(lower[1] * pctLower + upper[1] * pctUpper);
  var green = Math.floor(lower[2] * pctLower + upper[2] * pctUpper);
  var blue = Math.floor(lower[3] * pctLower + upper[3] * pctUpper);

  if (darker > 0 && darker < 100) {
    red = red - (red / 100) * darker;
    green = green - (green / 100) * darker;
    blue = blue - (blue / 100) * darker;
  }

  return Graphics.createColor(alpha, red.toNumber(), green.toNumber(), blue.toNumber());
}

// Returns true if the color is light (needs black text), false if dark (needs white text)
// HSP 0 is darkest (black), 255 is lightest (white). The threshold is set at 127.5 by default, but can be adjusted via settings.
function isColorLight(garminColor as Graphics.ColorType) as Boolean {
    // 1. Bit-shift to extract RGB channels
    var r = (garminColor >> 16) & 0xff;
    var g = (garminColor >> 8) & 0xff;
    var b = garminColor & 0xff;

    // 2. Square the channels to match your HSP formula
    var rSq = (r * r).toFloat();
    var gSq = (g * g).toFloat();
    var bSq = (b * b).toFloat();

    // 3. Apply standard perceptual weights
    var hsp = Math.sqrt(0.299 * rSq + 0.587 * gSq + 0.114 * bSq);

    // 4. Return true if light, false if dark
    // 127.5 is the midpoint of the 0-255 range, which is a common threshold for determining light vs dark colors
    var breakpoint = Storage.getValue("hsp_darklight_breakpoint");
    if (breakpoint == null || breakpoint < 0 || breakpoint > 255) {
        //breakpoint = 127.5; // Default to midpoint if not set
        breakpoint = 145; // Default to midpoint if not set
    }
    return hsp > breakpoint;
}

function calculateHSP(garminColor as Graphics.ColorType) as Float {
    // 1. Bit-shift to extract RGB channels
    var r = (garminColor >> 16) & 0xff;
    var g = (garminColor >> 8) & 0xff;
    var b = garminColor & 0xff;

    // 2. Square the channels to match your HSP formula
    var rSq = (r * r).toFloat();
    var gSq = (g * g).toFloat();
    var bSq = (b * b).toFloat();

    // 3. Apply standard perceptual weights
    return Math.sqrt(0.299 * rSq + 0.587 * gSq + 0.114 * bSq);
}