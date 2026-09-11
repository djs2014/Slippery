import Toybox.Graphics;
import Toybox.Lang;

class StringListRenderer {

    // Pre-calculated spacing constants to avoid repeated width calls
    private const SEPARATOR = " / ";

    /// Draws an array of strings wrapped within a specified width and line limit.
    /// Returns the total height occupied by the rendered text.
    public static function drawWrappedStrings(
        dc as Graphics.Dc,
        items as Array<String>,
        x as Number,
        y as Number,
        maxWidth as Number,
        maxLines as Number,
        font as Graphics.FontDefinition,
        color as Graphics.ColorValue
    ) as Number {
        var numItems = items.size();
        if (numItems == 0) { return 0; }

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);

        var fontHeight = dc.getFontHeight(font);
        var separatorWidth = dc.getTextWidthInPixels(self.SEPARATOR, font);

        var currentY = y;
        var currentLineWidth = 0;
        var lineCount = 1;
        var isFirstItemOnLine = true;

        for (var i = 0; i < numItems; i++) {
            var item = items[i];
            var itemWidth = dc.getTextWidthInPixels(item, font);

            // Calculate width needed if appended to current line
            var neededWidth = itemWidth;
            if (!isFirstItemOnLine) {
                neededWidth += separatorWidth;
            }

            // Check if item fits on the current line
            if (isFirstItemOnLine || (currentLineWidth + neededWidth <= maxWidth)) {
                // Draw separator if it's not the first item on this line
                if (!isFirstItemOnLine) {
                    dc.drawText(x + currentLineWidth, currentY, font, self.SEPARATOR, Graphics.TEXT_JUSTIFY_LEFT);
                    currentLineWidth += separatorWidth;
                }

                // Draw hazard text
                dc.drawText(x + currentLineWidth, currentY, font, item, Graphics.TEXT_JUSTIFY_LEFT);
                currentLineWidth += itemWidth;
                isFirstItemOnLine = false;

            } else {
                // Wrap to next line
                lineCount++;
                if (lineCount > maxLines) { break; } // Respect line limit constraint

                currentY += fontHeight;
                currentLineWidth = 0;

                // Draw item at the start of the new line
                dc.drawText(x, currentY, font, item, Graphics.TEXT_JUSTIFY_LEFT);
                currentLineWidth = itemWidth;
                isFirstItemOnLine = false;
            }
        }
        return currentY - y;
    }

    /// Draws an array of strings centered and wrapped within a specified width and line limit.
    /// Returns the total height occupied by the rendered text.
    public static function drawCenteredWrappedStrings(
        dc as Graphics.Dc,
        items as Array<String>,
        x as Number,
        y as Number,
        maxWidth as Number,
        maxLines as Number,
        font as Graphics.FontDefinition,
        color as Graphics.ColorValue
    ) as Number {
        var numItems = items.size();
        if (numItems == 0) { return 0; }

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);

        var fontHeight = dc.getFontHeight(font);
        var separatorWidth = dc.getTextWidthInPixels(self.SEPARATOR, font);

        // Fixed array to track how many items land on each line (maxLines capacity)
        var lineItemCounts = new [maxLines];
        var lineLineWidths = new [maxLines];
        
        for (var l = 0; l < maxLines; l++) {
            lineItemCounts[l] = 0;
            lineLineWidths[l] = 0;
        }

        var currentLine = 0;
        var currentLineWidth = 0;
        var isFirstOnLine = true;

        // --- PASS 1: PACK ITEMS INTO LINES & MEASURE TOTAL LINE WIDTHS ---
        for (var i = 0; i < numItems; i++) {
            var itemWidth = dc.getTextWidthInPixels(items[i], font);
            var neededWidth = isFirstOnLine ? itemWidth : (itemWidth + separatorWidth);

            if (isFirstOnLine || (currentLineWidth + neededWidth <= maxWidth)) {
                currentLineWidth += neededWidth;
                lineItemCounts[currentLine]++;
                lineLineWidths[currentLine] = currentLineWidth;
                isFirstOnLine = false;
            } else {
                // Move to next line if available
                currentLine++;
                if (currentLine >= maxLines) { break; }

                currentLineWidth = itemWidth;
                lineItemCounts[currentLine] = 1;
                lineLineWidths[currentLine] = currentLineWidth;
                isFirstOnLine = false;
            }
        }

        // --- PASS 2: RENDER CENTERED LINES ---
        var itemIndex = 0;
        var currentY = y;

        for (var l = 0; l <= currentLine && l < maxLines; l++) {
            var count = lineItemCounts[l];
            if (count == 0) { break; }

            var totalLineWidth = lineLineWidths[l];
            // Compute centered starting offset
            var currentX = x + ((maxWidth - totalLineWidth) / 2);

            for (var i = 0; i < count; i++) {
                var item = items[itemIndex];
                
                if (i > 0) {
                    dc.drawText(currentX, currentY, font, self.SEPARATOR, Graphics.TEXT_JUSTIFY_LEFT);
                    currentX += separatorWidth;
                }

                dc.drawText(currentX, currentY, font, item, Graphics.TEXT_JUSTIFY_LEFT);
                currentX += dc.getTextWidthInPixels(item, font);
                
                itemIndex++;
            }

            currentY += fontHeight;
        }
        return currentY - y;
    }
}