- linux taskbar app for local use
- weather app also same track heading mechanism / edgefield

- add precipitation_probability
- readme update alertmode thresholds

- rain chance line?
- show current day time

Plumbing (all small, all mirroring existing fields)
1. BackgroundService.mc:95 — append ,precipitation_probability to the hourly string.
2. WeatherMetrics — precipProbForecast as Array<Number> (%, following the showersForecast pattern).
3. weatherService — parse hourly.get("precipitation_probability"), fill with the same per-index guards as the other arrays, add to the size-mismatch warning.
4. demoData — probability arrays per scenario (high % on rainy hours, ~0 on dry ones).
5. Sparkline LAYER C — solid/hollow branch + gated scans. RiskProjectionEngine untouched.
One honest caveat: the risk engine and the rain/showers-ahead alerts currently treat a 5%-probable 3 mm exactly like a 95% one — hollow bars next to a Moderate badge could read contradictory. This proposal keeps risk as-is (display-only change); probability-weighted risk (e.g. requiring the floor for rain-ladder rules) is the natural follow-up once the display proves itself

 


check branch for stack overflow
Remaining suspects, in the order I'd test
1. Bisect the new plumbing: comment out just the projection call in parseOpenMeteoResponse — if clean, the trigger is inside the projection's prob code ([] as Array<Number> fallback, precipProbs[h+1] guards, or the new evaluateRisk arg choke point), not frame weight.
2. Old data without the field: replay a cached response lacking precipitation_probability — isolates the nullable-array paths (precipProbs != null … ? … : … in three places).
3. Hardware test: sim-only delivery-context stacks are a known category of false alarm; a real Edge may never reproduce it.
4. Full sim console, not just the trace — anything above the error (a preceding null/type warning would reframe this instantly).
My money is on 1 or 2 — something data/null-path-shaped rather than stack-shaped, given the mitigation changed nothing. Ping me when you pick it back up and we'll chase it down.









get skill for connect IQ
