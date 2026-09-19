Yes — and since your slipperycheck.js engine is dependency-free, it ports almost 1:1. I scaffolded a native panel applet at cinnamon-applet/slippery@local/ (applet.js + metadata.json + settings-schema.json).
Key point: Mint panel applets run on GJS, not node, so you can't require() the file. Instead the applet embeds the same functions — same Open-Meteo URL as BackgroundService.mc, same 13 checks as RiskCalculator, same seasons. The only swap is fetch → curl via Gio.Subprocess (curl ships with Mint; this also sidesteps the Soup 2-vs-3 API split between Cinnamon versions). Verified: identical output to slipperycheck.js on your moderaterisk fixture (MODERATE / Wet Leaves), plus gale and black-ice spot checks pass.
Panel shows a colored chip (Ok/Low/Mod/Hig/Crt + temp, same scale as the data field); click opens hazards, advice, and wind/rain summary. Lat/lon, refresh interval (≥5 min), and temp display are configurable in the applet's settings.
Install on your Mint machine:
cp -r cinnamon-applet/slippery@local ~/.local/share/cinnamon/applets/
# then Alt+F2 → r  (restart Cinnamon)
# Menu → Applets → find "Slippery" → add to panel → gear icon for lat/lon
Debug via melange (Alt+F2 → melange → Log tab) if the label sticks at n/a.
One limitation vs the watch: no 12-hour sparkline bars in the popup — Cinnamon popups are text rows, so the applet shows current risk only. If you want the forecast graph too, your nodetest/graph.js SVG can be opened alongside, or I can add a "save forecast SVG" action to the applet's menu next.