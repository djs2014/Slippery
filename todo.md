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

 












get skill for connect IQ
