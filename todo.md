- linux taskbar app for local use
- weather app also same track heading mechanism / edgefield

52.352547, 4.852022
69.840043, 26.883803
64.66204068732797, -19.170883997217427 iceland

list some lat/lon with interesting wheater situations for testing purpose


fix -104 issue

add incoming rain wide field
hide hazard large field, etc..
analyze bg service /numeric input etc.

panel chip locations
primare or high risk 


Verified — redundant calculations found:
High (per-frame / in-loop):
- SlipperyView.mc:232,239 — two loops over rainForecast / showersForecast for maxRain/ShowersAhead. Merge into one loop. Same data re-looped 7x in predictiveSparkline.mc:248,344,440,630,712,781 per onUpdate.
- SlipperyView.mc:353,358 — getBackgroundColor() called 3x per onUpdate. Cache in local: var bg = getBackgroundColor(); mIsDark = bg == ...; dc.setColor(bg, bg);
- predictiveSparkline.mc:40-53,344-388,512-600 + SlipperyView.mc:435-455 — DewpointPalette.getColor / getRiskColor / getLightRiskColor / AppState.getColor inside per-hour loops. Only 4-5 distinct risk levels exist — hoist to 5-entry lookup table per frame.
- SlipperyView.mc:1174-1204 drawGridCell() — getFontHeight, getMatchingFont (loops getTextDimensions), getTextWidthInPixels, getFontAscent/Descent per cell, called 6-8x per frame. Cache labelHeight / xtinyAscent once per onUpdate; cache valueWidth only if font caching added.
- predictiveSparkline.mc:1104,1221, currentWindWidget.mc:60 — Math.toRadians+sin/cos per wind arrow; gust-tier >=1.7/1.5/1.3 triplicated in :1158,:1242,:833, helpers.mc:407, currentWindWidget.mc:132. Centralize in calculateGustSeverity().
Medium (per-draw):
- SlipperyView.mc:497,508 (+3 other layouts) — width - paddingX*2 computed twice; compute innerW once and pass to drawComfort/draw/drawRiskFooter.
- Bar geometry barGap/standardBarWidth/bar0Width/leftShift/colX duplicated in drawComfort:27, draw:146, drawRiskFooter:425, +5 layer loops. Compute once in draw(), share via ctx.
- riskFooterFor() called 2x/frame (SlipperyView.mc:490 + predictiveSparkline.mc:343); simplifyWindFor() per drawWindLayer:776 + dc.getHeight()<120 per arrow :1211. Hoist per frame.
- AppState.getColor(COLOR_DIVIDER/LABEL/TEXT/...) refetched dozens of times per frame (SlipperyView.mc:478,561, predictiveSparkline.mc:181,183). Hoist per onUpdate.
- SlipperyView.mc:2029 vs 2113 — drawMetricColumn vs drawMetricField near-identical. Merge.
- StringListRenderer.mc:118,160 — getTextWidthInPixels twice per string (measure + draw passes). Reuse PASS1 widths.
Low: field_utils.mc:26 getDeviceSettings() only in onLayout (ok); BGServiceHandler.mc:101 per-background-cycle (ok); forecastAligner.mc:64 geometry duplicates sparkline but unused in draw path.
Fix order if you want: H6 → H1 → M-bar-geometry → H2 color table.

