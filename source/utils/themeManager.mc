import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;

/*
// Option A: Direct palette access with explicit cast
var textColor = AppState.getColor(ThemeManager.COLOR_TEXT);
var hazardColor = AppState.getColor(ThemeManager.COLOR_HAZARD);
*/
class AppState {
    // Reference Graphics.ColorType explicitly
    private static var activePalette as Array<Graphics.ColorType> = ThemeManager.DARK_PALETTE;

    public static function updateTheme(isDark as Boolean) as Void {
        activePalette = isDark
            ? ThemeManager.DARK_PALETTE
            : ThemeManager.LIGHT_PALETTE;
    }

    public static function getColor(key as ThemeManager.ColorKey) as Graphics.ColorType {
        var idx = key as Number;

        // Bounds check safeguard
        if (idx < 0 || idx >= activePalette.size()) {
            System.println("AppState: Color index out of bounds: " + idx);
            System.println("Key index requested: " + (key as Number));
            System.println("Palette size: " + activePalette.size());
            return Graphics.COLOR_WHITE; // Default fallback on error
        }

        return activePalette[idx];
    }
}

class ThemeManager {
    // 1. Raw Base Colors
    private static const RAW_BLUE                  = 0x00AAFF;
    private static const RAW_CYAN_BLUE             = 0x00D5FF;
    private static const RAW_ROYAL_BLUE            = 0x0044CC;
    private static const RAW_DARK_BLUE             = 0x0000AA;
    private static const RAW_YELLOW_DARK_THEME     = 0xE5FF00;
    private static const RAW_YELLOW_LIGHT_THEME    = 0xC79C00;
    private static const RAW_DARK_YELLOW           = 0x997700;
    private static const RAW_GREEN_DARK_THEME      = 0x00FF66;
    private static const RAW_GREEN_LIGHT_THEME     = 0x008822;
    private static const RAW_DARK_GREEN            = 0x006600;
    private static const RAW_RED_DARK_THEME        = 0xFF4444;
    private static const RAW_RED_LIGHT_THEME       = 0xCC3333;
    private static const RAW_DARK_RED              = 0xAA0000;
    private static const RAW_GREY_MID              = 0xAAAAAA;
    private static const RAW_GREY_DARK             = 0x555555;
    private static const RAW_DEEP_CYAN             = 0x0088CC;
    private static const RAW_LIGHT_COLUMBIA_BLUE  = 0x99DDFF;
    private static const RAW_INTL_ORANGE           = 0xFF5500;
    private static const RAW_FREE_SPEECH_RED       = 0xCC0000;
    private static const RAW_ELECTRIC_BLUE         = 0x0055FF;
    private static const RAW_HAZARD_LIGHT          = 0xB38F00;
    private static const RAW_DEEP_PURPLE_LIGHT     = 0x5500AA;
    private static const RAW_DEEP_PURPLE_DARK      = 0xAA00FF;
    private static const RAW_SHADES_OF_TANGAROA    = 0x002244;
    private static const RAW_SHADES_OF_ALICE_BLUE  = 0xDCEEFF;
    private static const RAW_SHADES_OF_AQUA        = 0x00FFFF;
    private static const RAW_SHADES_OF_OLIVE       = 0x666600;

    // 2. Semantic Color Keys (0 through 30)
    public enum ColorKey {
        COLOR_BLUE,                        // 0
        COLOR_CYAN_BLUE,                   // 1
        COLOR_ROYAL_BLUE,                  // 2
        COLOR_DARK_BLUE,                   // 3
        COLOR_YELLOW,                      // 4
        COLOR_DARK_YELLOW,                 // 5
        COLOR_GREEN,                       // 6
        COLOR_DARK_GREEN,                  // 7
        COLOR_RED,                         // 8
        COLOR_DARK_RED,                    // 9
        COLOR_GREY,                        // 10
        COLOR_DARK_GREY,                   // 11
        COLOR_TEXT,                        // 12
        COLOR_BG,                          // 13
        COLOR_LABEL,                       // 14
        COLOR_DIVIDER,                     // 15
        COLOR_HAZARD,                      // 16
        COLOR_DEEP_CYAN,                   // 17
        COLOR_DEEP_SKY_BLUE,               // 18
        COLOR_LIGHT_COLUMBIA_BLUE,         // 19
        COLOR_INTERNATIONAL_ORANGE,        // 20
        COLOR_FREE_SPEECH_RED,             // 21
        COLOR_LABEL_LIGHT,                 // 22
        COLOR_UNIT,                        // 23
        COLOR_ELECTRIC_BLUE,               // 24
        COLOR_DEEP_PURPLE_LIGHT,           // 25
        COLOR_DEEP_PURPLE_DARK,            // 26
        COLOR_FREEZING_TEMP_BACKGROUND,    // 27
        COLOR_SNOW_PATTERN,                // 28
        COLOR_SHOWERS,                     // 29
        COLOR_OLIVE,                       // 30
        COLOR_COUNT                        // 31 (Guard marker for palette size)
    }

    // 3. Dark Palette
    public static const DARK_PALETTE as Array<Graphics.ColorType> = [
        RAW_BLUE,                          // 0
        RAW_CYAN_BLUE,                     // 1
        Graphics.COLOR_WHITE,              // 2
        RAW_DARK_BLUE,                     // 3
        RAW_YELLOW_DARK_THEME,             // 4
        RAW_DARK_YELLOW,                   // 5
        RAW_GREEN_DARK_THEME,              // 6
        RAW_DARK_GREEN,                    // 7
        RAW_RED_DARK_THEME,                // 8
        RAW_DARK_RED,                      // 9
        RAW_GREY_MID,                      // 10
        RAW_GREY_DARK,                     // 11
        Graphics.COLOR_WHITE,              // 12
        Graphics.COLOR_BLACK,              // 13
        Graphics.COLOR_LT_GRAY,            // 14
        Graphics.COLOR_LT_GRAY,            // 15
        RAW_YELLOW_DARK_THEME,             // 16
        RAW_DEEP_CYAN,                     // 17
        RAW_BLUE,                          // 18
        RAW_LIGHT_COLUMBIA_BLUE,           // 19
        RAW_INTL_ORANGE,                   // 20
        RAW_FREE_SPEECH_RED,               // 21
        Graphics.COLOR_DK_GRAY,            // 22
        Graphics.COLOR_LT_GRAY,            // 23
        RAW_ELECTRIC_BLUE,                 // 24
        RAW_DEEP_PURPLE_LIGHT,             // 25
        RAW_DEEP_PURPLE_DARK,              // 26
        RAW_SHADES_OF_TANGAROA,            // 27
        Graphics.COLOR_WHITE,              // 28
        RAW_DEEP_PURPLE_LIGHT,             // 29
        RAW_SHADES_OF_OLIVE                // 30
    ];

    // 4. Light Palette
    public static const LIGHT_PALETTE as Array<Graphics.ColorType> = [
        RAW_BLUE,                          // 0
        Graphics.COLOR_WHITE,              // 1
        RAW_ROYAL_BLUE,                    // 2
        RAW_DARK_BLUE,                     // 3
        RAW_YELLOW_LIGHT_THEME,            // 4
        RAW_DARK_YELLOW,                   // 5
        RAW_GREEN_LIGHT_THEME,             // 6
        RAW_DARK_GREEN,                    // 7
        RAW_RED_LIGHT_THEME,               // 8
        RAW_DARK_RED,                      // 9
        RAW_GREY_DARK,                     // 10
        RAW_GREY_DARK,                     // 11
        Graphics.COLOR_BLACK,              // 12
        Graphics.COLOR_WHITE,              // 13
        Graphics.COLOR_DK_GRAY,            // 14
        Graphics.COLOR_DK_GRAY,            // 15
        RAW_HAZARD_LIGHT,                  // 16
        RAW_DEEP_CYAN,                     // 17
        RAW_BLUE,                          // 18
        RAW_LIGHT_COLUMBIA_BLUE,           // 19
        RAW_INTL_ORANGE,                   // 20
        RAW_FREE_SPEECH_RED,               // 21
        Graphics.COLOR_LT_GRAY,            // 22
        Graphics.COLOR_LT_GRAY,            // 23
        RAW_ELECTRIC_BLUE,                 // 24
        RAW_DEEP_PURPLE_LIGHT,             // 25
        RAW_DEEP_PURPLE_DARK,              // 26
        RAW_SHADES_OF_ALICE_BLUE,          // 27
        RAW_SHADES_OF_AQUA,                // 28
        RAW_DEEP_PURPLE_DARK,              // 29
        RAW_SHADES_OF_OLIVE                // 30
    ];   
}