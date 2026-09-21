- linux taskbar app for local use
- weather app also same track heading mechanism / edgefield

graphic examples
get skill for connect IQ
52.352547, 4.852022
69.840043, 26.883803

sunshine_duration? x sec/hour

What changed
draw() (~110 frame slots) is now a thin orchestrator (~24 slots) plus 8 sequential helpers, each running in its own freed frame:
Function	Frame size	Does
draw()	11 params + 13 vars	geometry, one heap ctx Dictionary, calls passes in order
computePrecipRanges()	2 + 21	old PASS 1 (min/max, ice flag, first shower/rain idx)
drawRiskLayer()	4 + 23	old layers A+B (freezing bg, risk heatmap,\ hour labels)
drawPrecipLayer()	3 + 36	old layer C (stacked rain/snow bars, highlights)
drawTempLayer()	4 + 26	old layer D, returns firstStY
drawSunLayer()	3 + 23	old layer F, returns firstSunY
drawWindLayer()	4 + 29	old layer E + arrow calls, returns firstWindY
drawMinutelyOverlay()	3 + 17	old 15-min overlay block
drawBadges()	5 + 8	old T/W/S + ICE/SHOWERS/RAIN badges
Shared state travels in one ctx Dictionary (heap) — exactly Garmin's recommended workaround. Render order is unchanged (background → risk → precip → temp → sun → wind → minutely → line → badges), and layers were already independent (each tracked its own prev-point state), so separate per-layer loops draw pixel-identically. drawComfort, drawWindArrow(_line), and the draw() signature are untouched.
Verification (no SDK here, so static)
- Braces/parens balanced; each helper defined once, called once, ≤5 params
- All 28 ctx keys written in draw() are exactly the 28 read by helpers (both directions clean)
- Rendering math copied verbatim; during the work I caught and fixed one real slip (a dropped currentRisk condition in the wind-line color — restored with riskProfile passed to drawWindLayer)
Please verify on your side
1. Build in VS Code / run in the simulator with this exact scenario — first fetch with data, gusty forecast (arrows drawn), non-small field
2. Confirm the sparkline renders identically to before (all SAFE hours → light risk blocks, sun line rising to full height by midday, no badges since nothing crosses thresholds)
3. If it still overflows on an old small-stack device, the next target is drawWindArrow()'s gust-chevron loop (~15 of its 38 slots) — say the word and I'll extract that too

Done. drawGustChevrons(dc, geom) is extracted; drawWindArrow() now just builds the triangle and hands off.
What changed (predictiveSparkline.mc only)
- New drawGustChevrons(dc, geom) — the entire STEP C block (severity tiers, bar sizing, halo+foreground chevron loop) moved verbatim into its own frame. The 11 geometry values travel in one small Dictionary (heap), keeping the signature at 2 params, well clear of the 8–9 parameter caution.
- drawWindArrow() shrunk 38 → 27 frame slots — gustRatio, numGustBars, barSpacing, standardBarWidth, and all b* loop vars moved out. It ends with the dict-passing call (inline literal, same pattern as the existing showToast call).
Measured effect
Frame sizes (params + vars) across the worst path, gusty forecast with arrows drawn:
- before this session: draw 109 + drawWindArrow 38 → peak ≈ 166 incl. call chain
- after the layer split: peak ≈ 133
- now: peak ≈ 127; typical no-arrow frames ≈ 82 (was 128)
Verified: braces/parens balanced, drawGustChevrons defined once / called once, all 11 geom keys passed match the 11 read, STEP C code exists in exactly one place, behavior identical (pure move — severity thresholds, halo geometry, and draw order untouched).
One honest caveat on the mechanism: nested frames still add up, so extraction pays off most where sequential passes replace one giant live frame (the draw() split) rather than subdivide an already-nested one (this change). The remaining nested tail is drawWindLayer (33) + drawWindArrow (27) + chevrons (24) — if you ever need more headroom there, inlining the chevron call's dict (i.e., passing the 3–4 scalars it actually varies on) won't help; the next real lever would be simplifying the halo-outline passes.


Add option per field (one, large, wide, small) to show the risklevel under the forecast,
so in effect the forast bottom shrinks and in the remaining space the risk color is displayed.
