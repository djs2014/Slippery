- linux taskbar app for local use
- weather app also same track heading mechanism / edgefield

graphic examples
get skill for connect IQ
52.352547, 4.852022
sunshine_duration? x sec/hour

What changed
draw() (~110 frame slots) is now a thin orchestrator (~24 slots) plus 8 sequential helpers, each running in its own freed frame:
Function	Frame size	Does
draw()	11 params + 13 vars	geometry, one heap ctx Dictionary, calls passes in order
computePrecipRanges()	2 + 21	old PASS 1 (min/max, ice flag, first shower/rain idx)
drawRiskLayer()	4 + 23	old layers A+B (freezing bg, risk heatmap, hour labels)
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

