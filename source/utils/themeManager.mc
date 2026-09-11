import Toybox.Graphics;
import Toybox.Lang;

// Initialize active palette pointer once when theme updates
class AppState {
    public static var activePalette as Array<Number> = ThemeManager.DARK_PALETTE;

    public static function updateTheme(isDark as Boolean) as Void {
        activePalette = isDark ? ThemeManager.DARK_PALETTE : ThemeManager.LIGHT_PALETTE;
    }
}

/*
// In draw routines (e.g., PredictiveSparkline.draw):
var textColor = AppState.activePalette[ThemeManager.COLOR_TEXT];
var hazardColor = AppState.activePalette[ThemeManager.COLOR_HAZARD];
*/

class ThemeManager {

    enum ColorKey {
        COLOR_BLUE,        // 0
        COLOR_CYAN_BLUE,   // 1
        COLOR_ROYAL_BLUE,  // 2
        COLOR_DARK_BLUE,   // 3
        COLOR_YELLOW,      // 4
        COLOR_DARK_YELLOW, // 5
        COLOR_GREEN,       // 6
        COLOR_DARK_GREEN,  // 7
        COLOR_RED,         // 8
        COLOR_DARK_RED,    // 9
        COLOR_GREY,        // 10
        COLOR_DARK_GREY,   // 11
        COLOR_TEXT,        // 12
        COLOR_BG,          // 13
        COLOR_LABEL,       // 14
        COLOR_DIVIDER,     // 15
        COLOR_HAZARD,      // 16
        COLOR_DEEP_CYAN    // 17
    }

    // Direct indexed palettes for Dark and Light themes
    public static const DARK_PALETTE as Array<Number> = [
        0x00AAFF,            // 0: BLUE
        0x00D5FF,            // 1: CYAN_BLUE
        Graphics.COLOR_WHITE,// 2: ROYAL_BLUE (fallback)
        0x0000AA,            // 3: DARK_BLUE
        0xE5FF00,            // 4: YELLOW
        0x997700,            // 5: DARK_YELLOW
        0x00FF66,            // 6: GREEN
        0x006600,            // 7: DARK_GREEN
        0xFF4444,            // 8: RED
        0xAA0000,            // 9: DARK_RED
        0xAAAAAA,            // 10: GREY
        0x555555,            // 11: DARK_GREY
        Graphics.COLOR_WHITE,// 12: TEXT
        Graphics.COLOR_BLACK,// 13: BG
        Graphics.COLOR_LT_GRAY,// 14: LABEL
        Graphics.COLOR_LT_GRAY,// 15: DIVIDER
        0xE5FF00,            // 16: HAZARD
        0x0088CC             // 17: DEEP_CYAN
    ];

    public static const LIGHT_PALETTE as Array<Number> = [
        0x00AAFF,            // 0: BLUE
        Graphics.COLOR_WHITE,// 1: CYAN_BLUE (fallback)
        0x0044CC,            // 2: ROYAL_BLUE
        0x0000AA,            // 3: DARK_BLUE
        0xC79C00,            // 4: YELLOW
        0x997700,            // 5: DARK_YELLOW
        0x008822,            // 6: GREEN
        0x006600,            // 7: DARK_GREEN
        0xCC3333,            // 8: RED
        0xAA0000,            // 9: DARK_RED
        0x555555,            // 10: GREY
        0x555555,            // 11: DARK_GREY
        Graphics.COLOR_BLACK,// 12: TEXT
        Graphics.COLOR_WHITE,// 13: BG
        Graphics.COLOR_DK_GRAY,// 14: LABEL
        Graphics.COLOR_DK_GRAY,// 15: DIVIDER
        0xB38F00,            // 16: HAZARD
        0x0088CC             // 17: DEEP_CYAN
    ];
    
    // Ultra-fast O(1) lookup, 0 branching, zero runtime allocations
    static function getThemeColor(key as ColorKey, isDarkTheme as Boolean) as Graphics.ColorType {
        var palette = isDarkTheme ? DARK_PALETTE : LIGHT_PALETTE;
        return palette[key as Number];
    }
}