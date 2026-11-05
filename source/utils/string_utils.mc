import Toybox.System;
import Toybox.Lang;

function stringReplace(str as String, oldString as String, newString as String) as String {
  var result = str;
  //if (str == null || oldString == null || newString == null) {
  //  return str;
  //}

  var index = result.find(oldString);
  var count = 0;
  while (index != null && count < 30) {
    var indexEnd = index + oldString.length();
    result = result.substring(0, index) + newString + result.substring(indexEnd, result.length());
    index = result.find(oldString);
    count = count + 1;
  }

  return result;
}

function stringReplacePos(
  str as String,
  start as Number,
  oldString as String,
  newString as String,
  occurrence as Number
) as String {
  var result = str;
  //if (str == null || oldString == null || newString == null) {
  //  return str;
  //}

  if (start > str.length()) {
    return str;
  }

  var pre = str.substring(0, start) as String;
  result = str.substring(start, str.length()) as String;

  var index = result.find(oldString);
  var count = 0;
  while (index != null && count < occurrence) {
    var indexEnd = index + oldString.length();
    result = result.substring(0, index) + newString + result.substring(indexEnd, result.length());
    index = result.find(oldString);
    count = count + 1;
  }

  return pre + result;
}

function stringLeft(str as String, marker as String, dflt as String) as String {
  if (str.length() == 0 || marker.length() == 0) {
    return dflt;
  }

  var index = str.find(marker);
  if (index == null) {
    return dflt;
  }
  return str.substring(0, index) as String;
}

function stringRight(
  str as String,
  marker as String,
  dflt as String
) as String {
  if (str.length() == 0 || marker.length() == 0) {
    return dflt;
  }

  var index = str.find(marker);
  if (index == null || index + 1 >= str.length()) {
    return dflt;
  }
  return str.substring(index + 1, str.length()) as String;
}