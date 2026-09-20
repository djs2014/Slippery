Yes — and since your slipperycheck.js engine is dependency-free, it ports almost 1:1. I scaffolded a native panel applet at cinnamon-applet/slippery@local/ (applet.js + metadata.json + settings-schema.json).
Key point: Mint panel applets run on GJS, not node, so you can't require() the file. Instead the applet embeds the same functions — same Open-Meteo URL as BackgroundService.mc, same 13 checks as RiskCalculator, same seasons. The only swap is fetch → curl via Gio.Subprocess (curl ships with Mint; this also sidesteps the Soup 2-vs-3 API split between Cinnamon versions). Verified: identical output to slipperycheck.js on your moderaterisk fixture (MODERATE / Wet Leaves), plus gale and black-ice spot checks pass.
Panel shows a colored chip (Ok/Low/Mod/Hig/Crt + temp, same scale as the data field); click opens a compact popup: hazards, advice, one wind row + one temps row, then per location a coming-hours totals row (rain/snow sums, ICE hours, max risk, top gust) plus an "Hourly graph" button that renders the same SVG as nodetest/graph.js from the already-fetched forecast and opens it in the default image viewer (no extra packages needed).
Install on your Mint machine (or run cinnamon-applet/install.sh, which does the copy):
cp -r cinnamon-applet/slippery@local ~/.local/share/cinnamon/applets/
# then Alt+F2 → r  (restart Cinnamon)
# Menu → Applets → find "Slippery" → add to panel → gear icon for lat/lon
Debug via melange (Alt+F2 → melange → Log tab) if the label sticks at n/a.
Each of the up to 5 commute points gets its own totals row + graph button in the popup.