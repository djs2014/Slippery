import Toybox.Graphics;
import Toybox.Lang;

/*
// In draw routines (e.g., PredictiveSparkline.draw):
var textColor = AppState.activePalette[ThemeManager.COLOR_TEXT];
var hazardColor = AppState.activePalette[ThemeManager.COLOR_HAZARD];
*/
// Initialize active palette pointer once when theme updates
class AppState {
    public static var activePalette as Array<ColorType> =
        ThemeManager.DARK_PALETTE;

    public static function updateTheme(isDark as Boolean) as Void {
        activePalette = isDark
            ? ThemeManager.DARK_PALETTE
            : ThemeManager.LIGHT_PALETTE;
    }
}

class ThemeManager {
    // 1. Raw Base Colors (Defined ONCE as shared primitives)
    private static const RAW_BLUE = 0x00aaff;
    private static const RAW_CYAN_BLUE = 0x00d5ff;
    private static const RAW_ROYAL_BLUE = 0x0044cc;
    private static const RAW_DARK_BLUE = 0x0000aa;
    private static const RAW_YELLOW_DARK_THEME = 0xe5ff00;
    private static const RAW_YELLOW_LIGHT_THEME = 0xc79c00;
    private static const RAW_DARK_YELLOW = 0x997700;
    private static const RAW_GREEN_DARK_THEME = 0x00ff66;
    private static const RAW_GREEN_LIGHT_THEME = 0x008822;
    private static const RAW_DARK_GREEN = 0x006600;
    private static const RAW_RED_DARK_THEME = 0xff4444;
    private static const RAW_RED_LIGHT_THEME = 0xcc3333;
    private static const RAW_DARK_RED = 0xaa0000;
    private static const RAW_GREY_MID = 0xaaaaaa;
    private static const RAW_GREY_DARK = 0x555555;
    private static const RAW_DEEP_CYAN = 0x0088cc;
    private static const RAW_LIGHT_COLUMBIA_BLUE = 0x99ddff;
    private static const RAW_INTL_ORANGE = 0xff5500;
    private static const RAW_FREE_SPEECH_RED = 0xcc0000;
    private static const RAW_ELECTRIC_BLUE = 0x0055ff;
    private static const RAW_HAZARD_LIGHT = 0xb38f00;

    // 2. Semantic Color Keys (Indexes)
    enum ColorKey {
        COLOR_BLUE = 0,
        COLOR_CYAN_BLUE,
        COLOR_ROYAL_BLUE,
        COLOR_DARK_BLUE,
        COLOR_YELLOW,
        COLOR_DARK_YELLOW,
        COLOR_GREEN,
        COLOR_DARK_GREEN,
        COLOR_RED,
        COLOR_DARK_RED,
        COLOR_GREY,
        COLOR_DARK_GREY,
        COLOR_TEXT,
        COLOR_BG,
        COLOR_LABEL,
        COLOR_DIVIDER,
        COLOR_HAZARD,
        COLOR_DEEP_CYAN,
        COLOR_DEEP_SKY_BLUE,
        COLOR_LIGHT_COLUMBIA_BLUE,
        COLOR_INTERNATIONAL_ORANGE,
        COLOR_FREE_SPEECH_RED,
        COLOR_LABEL_LIGHT,
        COLOR_UNIT,
        COLOR_ELECTRIC_BLUE,
    }

    // 3. Dark Palette (Maps semantic keys to raw colors or system graphics constants)
    public static const DARK_PALETTE as Array<Graphics.ColorType> = [
        RAW_BLUE, // 0: COLOR_BLUE
        RAW_CYAN_BLUE, // 1: COLOR_CYAN_BLUE
        Graphics.COLOR_WHITE, // 2: COLOR_ROYAL_BLUE
        RAW_DARK_BLUE, // 3: COLOR_DARK_BLUE
        RAW_YELLOW_DARK_THEME, // 4: COLOR_YELLOW
        RAW_DARK_YELLOW, // 5: COLOR_DARK_YELLOW
        RAW_GREEN_DARK_THEME, // 6: COLOR_GREEN
        RAW_DARK_GREEN, // 7: COLOR_DARK_GREEN
        RAW_RED_DARK_THEME, // 8: COLOR_RED
        RAW_DARK_RED, // 9: COLOR_DARK_RED
        RAW_GREY_MID, // 10: COLOR_GREY
        RAW_GREY_DARK, // 11: COLOR_DARK_GREY
        Graphics.COLOR_WHITE, // 12: COLOR_TEXT
        Graphics.COLOR_BLACK, // 13: COLOR_BG
        Graphics.COLOR_LT_GRAY, // 14: COLOR_LABEL
        Graphics.COLOR_LT_GRAY, // 15: COLOR_DIVIDER
        RAW_YELLOW_DARK_THEME, // 16: COLOR_HAZARD
        RAW_DEEP_CYAN, // 17: COLOR_DEEP_CYAN
        RAW_BLUE, // 18: COLOR_DEEP_SKY_BLUE
        RAW_LIGHT_COLUMBIA_BLUE, // 19: COLOR_LIGHT_COLUMBIA_BLUE
        RAW_INTL_ORANGE, // 20: COLOR_INTERNATIONAL_ORANGE
        RAW_FREE_SPEECH_RED, // 21: COLOR_FREE_SPEECH_RED
        Graphics.COLOR_DK_GRAY, // 22: COLOR_LABEL_LIGHT
        Graphics.COLOR_LT_GRAY, // 23: COLOR_UNIT
        RAW_ELECTRIC_BLUE, // 24: COLOR_ELECTRIC_BLUE
    ];

    // 4. Light Palette (Reuses identical constants, changes only theme-specific indices)
    public static const LIGHT_PALETTE as Array<Graphics.ColorType> = [
        RAW_BLUE, // 0: COLOR_BLUE
        Graphics.COLOR_WHITE, // 1: COLOR_CYAN_BLUE
        RAW_ROYAL_BLUE, // 2: COLOR_ROYAL_BLUE
        RAW_DARK_BLUE, // 3: COLOR_DARK_BLUE
        RAW_YELLOW_LIGHT_THEME, // 4: COLOR_YELLOW
        RAW_DARK_YELLOW, // 5: COLOR_DARK_YELLOW
        RAW_GREEN_LIGHT_THEME, // 6: COLOR_GREEN
        RAW_DARK_GREEN, // 7: COLOR_DARK_GREEN
        RAW_RED_LIGHT_THEME, // 8: COLOR_RED
        RAW_DARK_RED, // 9: COLOR_DARK_RED
        RAW_GREY_DARK, // 10: COLOR_GREY
        RAW_GREY_DARK, // 11: COLOR_DARK_GREY
        Graphics.COLOR_BLACK, // 12: COLOR_TEXT
        Graphics.COLOR_WHITE, // 13: COLOR_BG
        Graphics.COLOR_DK_GRAY, // 14: COLOR_LABEL
        Graphics.COLOR_DK_GRAY, // 15: COLOR_DIVIDER
        RAW_HAZARD_LIGHT, // 16: COLOR_HAZARD
        RAW_DEEP_CYAN, // 17: COLOR_DEEP_CYAN
        RAW_BLUE, // 18: COLOR_DEEP_SKY_BLUE
        RAW_LIGHT_COLUMBIA_BLUE, // 19: COLOR_LIGHT_COLUMBIA_BLUE
        RAW_INTL_ORANGE, // 20: COLOR_INTERNATIONAL_ORANGE
        RAW_FREE_SPEECH_RED, // 21: COLOR_FREE_SPEECH_RED
        Graphics.COLOR_LT_GRAY, // 22: COLOR_LABEL_LIGHT
        Graphics.COLOR_LT_GRAY, // 23: COLOR_UNIT
        RAW_ELECTRIC_BLUE, // 24: COLOR_ELECTRIC_BLUE
    ];

    // Fast O(1) direct accessor
    public static function getThemeColor(
        key as ColorKey,
        isDarkTheme as Boolean
    ) as Graphics.ColorType {
        var palette = isDarkTheme ? DARK_PALETTE : LIGHT_PALETTE;
        return palette[key as Number];
    }
}
