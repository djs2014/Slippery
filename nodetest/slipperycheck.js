/**
 * Slippery Node.js test harness — parity port of the Monkey C implementation.
 *
 * Source of truth:
 *  - source/background/BackgroundService.mc  (API request)
 *  - source/openmeteo/weatherService.mc      (parsing, 12h sums, dry streak, minutely)
 *  - source/weatherrisks/riskCalculator.mc   (all 13 risk rules)
 *  - source/weatherrisks/riskProjectionEngine.mc (12h projection)
 *  - source/weatherrisks/helpers.mc          (seasons, hazard/advice strings)
 *
 * Units (same as Monkey C / Open-Meteo defaults):
 *  rain+showers mm/h, snowfall cm/h, wind km/h, temps °C, humidity %.
 */

const RAIN_THRESHOLD = 0.1;
const SNOW_THRESHOLD = 0.1;

const RiskLevel = {
  NO_DATA: 0,
  SAFE: 1,
  SLIGHT: 2,
  MODERATE: 3,
  HIGH: 4,
  CRITICAL: 5,
};

const RISK_NAMES = ['NO_DATA', 'SAFE', 'SLIGHT', 'MODERATE', 'HIGH', 'CRITICAL'];

const Hazards = {
  BLACK_ICE: 'Black Ice / Freezing Wet Road',
  SNOW_SLUSH: 'Snow Or Slush Accumulation',
  FROST: 'Road Surface Frost',
  WET_LEAVES: 'Wet Leaf Coverage',
  FIRST_RAIN: 'First Rain Releasing Dirt / Oils',
  BRIDGE_ICE: 'Ice On Bridges',
  WET_ASPHALT: 'Wet Asphalt Surface',
  HEAVY_RAIN: 'Heavy Rain / Hydroplaning',
  CROSSWIND: 'Strong Crosswinds',
  GALE: 'Gale Force Winds',
  IMMINENT_SNOW: 'Immin Snow',
  IMMINENT_RAIN: 'Immin Rain',
};

const ShortHazards = {
  [Hazards.BLACK_ICE]: 'Ice',
  [Hazards.SNOW_SLUSH]: 'Snow/Slush',
  [Hazards.FROST]: 'Frost',
  [Hazards.WET_LEAVES]: 'Leaves',
  [Hazards.FIRST_RAIN]: 'Slick Rain',
  [Hazards.BRIDGE_ICE]: 'Bridge Ice',
  [Hazards.WET_ASPHALT]: 'Wet Road',
  [Hazards.HEAVY_RAIN]: 'Pouring',
  [Hazards.CROSSWIND]: 'Crosswind',
  [Hazards.GALE]: 'Gale Wind',
  [Hazards.IMMINENT_SNOW]: 'Imm. Snow',
  [Hazards.IMMINENT_RAIN]: 'Imm. Rain',
};

const Advice = {
  AVOID_RIDING: 'Avoid Riding',
  LOWER_TIRE_PRESSURE: 'Lower Tire Pressure',
  TRACTION_LOSS_TURNS: 'Loss Of Traction In Turns',
  TREAD_REQUIRED: 'Tread Pattern Required',
  WATCH_SHADED: 'Watch Out For Shaded Areas, Bridges, Tree-Lined Roads',
  AVOID_BRAKING: 'Avoid Sudden Braking',
  SLIP_CORNERING: 'Extreme Slip Hazard On Cornering Lines',
  ASPHALT_SLIPPERY: 'Aspalt Slippery',
  TRACTION_AFTER_RAIN: 'Traction Improves After Heavier Rain',
  BRAKING_DISTANCE: 'Increase Breaking Distance',
  LEAN_ANGLE: 'Reduce Cornering Lean Angle',
  SPEED_GRIP: 'Reduce Speed And Increase Grip Margin',
  HOLD_BARS: 'Hold Handlebars Firmly',
  OPEN_FIELDS: 'Beware Of Open Fields And Bridges',
  LOWER_PROFILE_WHEELS: 'Consider Lower Profile Wheels',
  RAIN_NOW: 'Rain Starting Now',
  RAIN_SHORTLY: 'Rain in', // + ' X min'
  SNOW_NOW: 'Snow Starting Now',
  SNOW_SHORTLY: 'Snow in', // + ' X min'
};

/**
 * API request builder — mirrors BackgroundServiceDelegate.fetchOpenMeteoData().
 * @param {number} lat
 * @param {number} lon
 * @param {number} pastHours default 12 (12h lookback for slipperiness)
 * @param {number} forecastHours default 12
 */
function buildApiParams(lat, lon, pastHours = 12, forecastHours = 12) {
  return new URLSearchParams({
    latitude: String(lat),
    longitude: String(lon),
    hourly: [
      'temperature_2m',
      'relativehumidity_2m',
      'dewpoint_2m',
      'showers',
      'rain',
      'snowfall',
      'precipitation_probability',
      'surface_temperature',
      'wind_speed_10m',
      'wind_gusts_10m',
      'wind_direction_10m',
      'sunshine_duration',
    ].join(','),
    past_hours: String(pastHours),
    forecast_hours: String(forecastHours),
    timezone: 'auto',
    timeformat: 'unixtime',
    minutely_15: 'rain,snowfall',
    forecast_minutely_15: '4',
  });
}

function buildApiUrl(lat, lon, pastHours = 12, forecastHours = 12) {
  return `https://api.open-meteo.com/v1/forecast?${buildApiParams(lat, lon, pastHours, forecastHours).toString()}`;
}

/**
 * Fetches Open-Meteo weather data and evaluates road slipperiness.
 * @param {number} lat - Latitude
 * @param {number} lon - Longitude
 * @param {number} pastHours - lookback window (default 12, mirrors Monkey C)
 * @param {number} forecastHours - forecast window (default 12)
 */
exports.checkRoadSlipperiness = async function (lat, lon, pastHours = 12, forecastHours = 12) {
  const url = buildApiUrl(lat, lon, pastHours, forecastHours);

  try {
    const response = await fetch(url);
    if (!response.ok) throw new Error(`Open-Meteo HTTP error: ${response.status}`);

    const data = await response.json();

    const jsonString = JSON.stringify(data);
    const memoryBytes = Buffer.byteLength(jsonString, 'utf8');
    console.log(`JSON Data Size: ${memoryBytes} bytes (${(memoryBytes / 1024).toFixed(2)} KB)`);

    return parseOpenMeteoResponse(lat, data, Math.floor(Date.now() / 1000));
  } catch (err) {
    console.error('Failed to fetch Open-Meteo data:', err);
    return null;
  }
};

/**
 * Determines the meteorological season — mirrors helpers.mc getMeteorologicalSeason().
 * Northern: Mar-May spring, Jun-Aug summer, Sep-Nov autumn, else winter. Mirrored south.
 */
function getMeteorologicalSeason(lat, date = new Date()) {
  const month = date.getUTCMonth() + 1; // 1 = January (Gregorian.utcInfo().month)
  let season;
  if (month >= 3 && month <= 5) {
    season = 'spring';
  } else if (month >= 6 && month <= 8) {
    season = 'summer';
  } else if (month >= 9 && month <= 11) {
    season = 'autumn';
  } else {
    season = 'winter';
  }
  if (lat < 0) {
    const inverted = { spring: 'autumn', summer: 'winter', autumn: 'spring', winter: 'summer' };
    season = inverted[season];
  }
  return season;
}
exports.getMeteorologicalSeason = getMeteorologicalSeason;

/**
 * Validates seasonal tags like "spring", "summer", "spring;summer;autumn", "winter".
 * (Kept from first draft; not used by Monkey C, which compares season enums directly.)
 */
function isSeasonActive(seasonalTag, lat, date = new Date()) {
  if (!seasonalTag) return true;
  const clean = String(seasonalTag).trim().toLowerCase();
  if (clean === 'no' || clean === 'false') return true;
  const currentSeason = getMeteorologicalSeason(lat, date);
  const seasons = clean.split(/[;,/]/).map((s) => s.trim().replace('fall', 'autumn'));
  if (seasons.includes(currentSeason)) return true;
  if (clean === 'yes' || clean === 'true') return currentSeason !== 'winter';
  return false;
}
exports.isSeasonActive = isSeasonActive;

// --- Parsing helpers (field-name tolerant: new + legacy draft names) ---

function pickHourly(hourly, candidates, fallback = []) {
  for (const key of candidates) {
    if (hourly && Array.isArray(hourly[key])) return hourly[key];
  }
  return fallback;
}

function toUnixSeconds(t) {
  if (typeof t === 'number') return t;
  if (typeof t === 'string') {
    // ISO "2026-09-04T16:00" (legacy draft) or numeric string
    const asNum = Number(t);
    if (Number.isFinite(asNum) && /^\d+$/.test(t.trim())) return asNum;
    const ms = Date.parse(t.length === 13 ? t + ':00' : t);
    if (Number.isFinite(ms)) return Math.floor(ms / 1000);
  }
  return 0;
}

/**
 * Mirrors weatherService.mc checkForImminentPrecipitation().
 * Returns -1 (none), 0 (active now), or 15/30/45 (minutes until start).
 */
function checkForImminentPrecipitation(arr, mmThreshold = 0.1) {
  if (!arr || arr.length === 0) return -1;
  const n = Math.min(arr.length, 4);
  for (let i = 0; i < n; i++) {
    const p = arr[i];
    if (p != null && p >= mmThreshold) return i * 15;
  }
  return -1;
}
exports.checkForImminentPrecipitation = checkForImminentPrecipitation;

/**
 * Core risk engine — exact port of RiskCalculator.evaluateRisk().
 * All thresholds / gates / advice match the Monkey C implementation.
 */
function evaluateRisk({
  airTemp,
  surfaceTemp,
  dewPoint,
  humidity,
  rainAndShowerCurrent,
  runningRainAndShower12h,
  runningSnow12h,
  runningDryStreak,
  season, // 'spring' | 'summer' | 'autumn' | 'winter'
  windSpeed,
  windGust,
  immediateRainAndShower, // -1 none, 0 now, >0 minutes ahead
  immediateSnow,
  surfaceDewSpread, // surfaceTemp - dewPoint
  snowCurrent,
}) {
  let riskLevel = RiskLevel.SAFE;
  const hazards = [];
  const advice = [];
  const upgrade = (level) => {
    if (level > riskLevel) riskLevel = level;
  };
  const addHazard = (h) => {
    if (!hazards.includes(h)) hazards.push(h);
  };
  const addAdvice = (a) => {
    if (!advice.includes(a)) advice.push(a);
  };

  // --- 1. CRITICAL: Black Ice & Freezing Wet Asphalt ---
  if (
    (surfaceTemp <= 0.0 || airTemp <= 0.5) &&
    (runningRainAndShower12h >= RAIN_THRESHOLD ||
      rainAndShowerCurrent >= RAIN_THRESHOLD ||
      runningSnow12h >= SNOW_THRESHOLD ||
      snowCurrent >= SNOW_THRESHOLD)
  ) {
    upgrade(RiskLevel.CRITICAL);
    addHazard(Hazards.BLACK_ICE);
    addAdvice(Advice.AVOID_RIDING);
    addAdvice(Advice.LOWER_TIRE_PRESSURE);
  }

  // --- 2. CRITICAL: Hoarfrost / Freezing Fog (humid air required) ---
  if (surfaceTemp <= 0.0 && surfaceDewSpread <= 2.0 && humidity >= 80) {
    upgrade(RiskLevel.CRITICAL);
    addHazard(Hazards.FROST);
    addAdvice(Advice.WATCH_SHADED);
    addAdvice(Advice.AVOID_BRAKING);
  }

  // --- 3. HIGH: Bridge Deck Freeze ---
  if (
    airTemp >= 0.0 &&
    airTemp <= 2.5 &&
    (runningRainAndShower12h >= RAIN_THRESHOLD ||
      humidity > 88 ||
      runningSnow12h >= SNOW_THRESHOLD)
  ) {
    upgrade(RiskLevel.HIGH);
    addHazard(Hazards.BRIDGE_ICE);
    addAdvice(Advice.WATCH_SHADED);
  }

  // --- 4. HIGH: Snow / Slush Accumulation (temp-gated, running sum incl. current) ---
  if (runningSnow12h >= SNOW_THRESHOLD && (surfaceTemp <= 1.0 || airTemp <= 1.5)) {
    upgrade(RiskLevel.HIGH);
    addHazard(Hazards.SNOW_SLUSH);
    addAdvice(Advice.TRACTION_LOSS_TURNS);
    addAdvice(Advice.TREAD_REQUIRED);
  }

  // --- 5. RAIN LADDER ---
  if (rainAndShowerCurrent >= 15.0) {
    upgrade(RiskLevel.CRITICAL);
    addHazard(Hazards.HEAVY_RAIN);
    addAdvice(Advice.SPEED_GRIP);
    addAdvice(Advice.BRAKING_DISTANCE);
  } else if (rainAndShowerCurrent >= 7.5) {
    upgrade(RiskLevel.HIGH);
    addHazard(Hazards.HEAVY_RAIN);
    addAdvice(Advice.BRAKING_DISTANCE);
    addAdvice(Advice.SPEED_GRIP);
  } else if (
    (season === 'summer' || season === 'spring') &&
    rainAndShowerCurrent >= 0.1 &&
    rainAndShowerCurrent < 2.5 &&
    runningDryStreak >= 10
  ) {
    upgrade(RiskLevel.MODERATE);
    addHazard(Hazards.FIRST_RAIN);
    addAdvice(Advice.ASPHALT_SLIPPERY);
    addAdvice(Advice.TRACTION_AFTER_RAIN);
  } else if (rainAndShowerCurrent >= 2.5) {
    upgrade(RiskLevel.MODERATE);
    addHazard(Hazards.WET_ASPHALT);
    addAdvice(Advice.BRAKING_DISTANCE);
    addAdvice(Advice.LEAN_ANGLE);
  } else if (rainAndShowerCurrent >= 0.2) {
    upgrade(RiskLevel.SLIGHT);
    addHazard(Hazards.WET_ASPHALT);
    addAdvice(Advice.BRAKING_DISTANCE);
  }

  // --- 6. MODERATE: Autumn Wet Leaves (requires actual wetness) ---
  if (
    season === 'autumn' &&
    (runningRainAndShower12h >= RAIN_THRESHOLD ||
      runningSnow12h >= SNOW_THRESHOLD ||
      rainAndShowerCurrent >= RAIN_THRESHOLD ||
      snowCurrent >= SNOW_THRESHOLD)
  ) {
    upgrade(RiskLevel.MODERATE);
    addHazard(Hazards.WET_LEAVES);
    addAdvice(Advice.SLIP_CORNERING);
    addAdvice(Advice.LEAN_ANGLE);
  }

  // --- 7. SLIGHT: Dew Condensation ("Sweating Road") ---
  if (surfaceTemp > 0.0 && humidity > 90 && surfaceDewSpread <= 1.0) {
    upgrade(RiskLevel.SLIGHT);
    addHazard(Hazards.WET_ASPHALT);
    addAdvice(Advice.WATCH_SHADED);
    addAdvice(Advice.LEAN_ANGLE);
  }

  // --- WIND (gust ratio floor avoids false alarms near calm) ---
  const gustRatio = windSpeed > 1.0 ? windGust / windSpeed : 1.0;

  // --- 8. CRITICAL: Gale-Force Winds or Extreme Gusts ---
  if (windSpeed >= 45.0 || windGust >= 60.0 || (windSpeed >= 35.0 && gustRatio >= 1.7)) {
    upgrade(RiskLevel.CRITICAL);
    addHazard(Hazards.GALE);
    addAdvice(Advice.OPEN_FIELDS);
    addAdvice(Advice.HOLD_BARS);
    addAdvice(Advice.LOWER_PROFILE_WHEELS);
  } else if (windSpeed >= 35.0 || windGust >= 45.0 || (windSpeed >= 25.0 && gustRatio >= 1.5)) {
    // --- 9. HIGH: Strong Crosswinds / Heavy Gusts ---
    upgrade(RiskLevel.HIGH);
    addHazard(Hazards.CROSSWIND);
    addAdvice(Advice.OPEN_FIELDS);
    addAdvice(Advice.HOLD_BARS);
  } else if (windSpeed >= 25.0 || windGust >= 35.0 || (windSpeed >= 18.0 && gustRatio >= 1.3)) {
    // --- 10. MODERATE: Moderate Winds / Gust Spikes ---
    upgrade(RiskLevel.MODERATE);
    addHazard(Hazards.CROSSWIND);
    addAdvice(Advice.HOLD_BARS);
  } else if (windSpeed >= 20.0) {
    // --- 11. SLIGHT: Noticeable Breeze ---
    upgrade(RiskLevel.SLIGHT);
    addHazard(Hazards.CROSSWIND);
    addAdvice(Advice.HOLD_BARS);
  }

  // --- 12/13. IMMEDIATE: Imminent Rain / Snow (suppressed while already active) ---
  if (immediateRainAndShower >= 0 && rainAndShowerCurrent < RAIN_THRESHOLD) {
    upgrade(RiskLevel.HIGH);
    addHazard(Hazards.IMMINENT_RAIN);
    addAdvice(immediateRainAndShower === 0 ? Advice.RAIN_NOW : `${Advice.RAIN_SHORTLY} ${immediateRainAndShower} min`);
  }
  if (immediateSnow >= 0 && snowCurrent < SNOW_THRESHOLD) {
    upgrade(RiskLevel.HIGH);
    addHazard(Hazards.IMMINENT_SNOW);
    addAdvice(immediateSnow === 0 ? Advice.SNOW_NOW : `${Advice.SNOW_SHORTLY} ${immediateSnow} min`);
  }

  return { riskLevel, riskName: RISK_NAMES[riskLevel], hazards, advice };
}
exports.evaluateRisk = evaluateRisk;
exports.RiskLevel = RiskLevel;
exports.Hazards = Hazards;
exports.Advice = Advice;

/**
 * Full response parser — mirrors weatherService.mc parseOpenMeteoResponse().
 * Finds the active hour (latest time <= now), builds 12h sums + dry streak,
 * reads minutely_15, then runs evaluateRisk().
 */
function parseOpenMeteoResponse(lat, data, nowSec = Math.floor(Date.now() / 1000)) {
  if (!data || !data.hourly) return null;
  const hourly = data.hourly;

  const times = hourly.time || [];
  if (times.length === 0) return null;

  const unixTimes = times.map(toUnixSeconds);
  let targetIdx = 0;
  for (let i = 0; i < unixTimes.length; i++) {
    if (unixTimes[i] <= nowSec) targetIdx = i;
    else break;
  }

  const airTemps = pickHourly(hourly, ['temperature_2m']);
  const surfTemps = pickHourly(hourly, ['surface_temperature']);
  const dewPoints = pickHourly(hourly, ['dewpoint_2m', 'dew_point_2m']);
  const humidities = pickHourly(hourly, ['relativehumidity_2m', 'relative_humidity_2m']);
  const rains = pickHourly(hourly, ['rain']);
  const showers = pickHourly(hourly, ['showers'], new Array(times.length).fill(0));
  const snows = pickHourly(hourly, ['snowfall']);
  const windSpeeds = pickHourly(hourly, ['wind_speed_10m', 'windspeed_10m'], new Array(times.length).fill(0));
  const windGusts = pickHourly(hourly, ['wind_gusts_10m', 'windgusts_10m'], new Array(times.length).fill(0));

  const at = (arr, i) => (i < arr.length && arr[i] != null ? arr[i] : 0);
  const sum12 = (a, b) => {
    let s = 0;
    const start = Math.max(0, targetIdx - 12);
    for (let j = start; j <= targetIdx; j++) s += at(a, j) + (b ? at(b, j) : 0);
    return s;
  };

  const airTemp = at(airTemps, targetIdx);
  const surfaceTemp = at(surfTemps, targetIdx);
  const dewPoint = at(dewPoints, targetIdx);
  const humidity = at(humidities, targetIdx);
  const rainCurrent = at(rains, targetIdx) + at(showers, targetIdx);
  const snowCurrent = at(snows, targetIdx);
  const windSpeed = at(windSpeeds, targetIdx);
  const windGust = at(windGusts, targetIdx);

  const rain12hSum = sum12(rains, showers);
  const snow12hSum = sum12(snows, null);

  // Dry streak: PRECEDING dry hours only (excludes current), cap 24 — mirrors Monkey C.
  let dryStreak = 0;
  for (let k = targetIdx - 1; k >= 0 && dryStreak < 24; k--) {
    if (at(rains, k) + at(showers, k) <= RAIN_THRESHOLD && at(snows, k) <= SNOW_THRESHOLD) dryStreak += 1;
    else break;
  }

  const season = getMeteorologicalSeason(lat, new Date(nowSec * 1000));
  const surfaceDewSpread = surfaceTemp - dewPoint;

  // minutely_15: first 4 slots, threshold 0.1 — mirrors Monkey C.
  let immediateRain = -1;
  let immediateSnow = -1;
  let minutelyRain = [];
  let minutelySnow = [];
  if (data.minutely_15) {
    minutelyRain = (data.minutely_15.rain || []).slice(0, 4);
    minutelySnow = (data.minutely_15.snowfall || []).slice(0, 4);
    immediateRain = checkForImminentPrecipitation(minutelyRain, 0.1);
    immediateSnow = checkForImminentPrecipitation(minutelySnow, 0.1);
  }

  const result = evaluateRisk({
    airTemp,
    surfaceTemp,
    dewPoint,
    humidity,
    rainAndShowerCurrent: rainCurrent,
    runningRainAndShower12h: rain12hSum,
    runningSnow12h: snow12hSum,
    runningDryStreak: dryStreak,
    season,
    windSpeed,
    windGust,
    immediateRainAndShower: immediateRain,
    immediateSnow,
    surfaceDewSpread,
    snowCurrent,
  });

  const ts = times[targetIdx];
  const timestamp = typeof ts === 'number' ? new Date(ts * 1000).toISOString() : String(ts);

  return {
    timestamp,
    targetIndex: targetIdx,
    season,
    riskLevel: result.riskName,
    riskLevelNum: result.riskLevel,
    hazards: result.hazards,
    shortHazards: result.hazards.map((h) => ShortHazards[h] || h),
    advice: result.advice,
    immediateRain,
    immediateSnow,
    hourlyRiskProfile: calculate12HourRiskProfile(lat, data, targetIdx, season),
    weatherSummary: {
      airTempC: airTemp,
      surfaceTempC: surfaceTemp,
      dewPointC: dewPoint,
      humidityPercent: humidity,
      rainMM: Math.round(rainCurrent * 10) / 10,
      snowCM: Math.round(snowCurrent * 10) / 10,
      windKmh: windSpeed,
      gustKmh: windGust,
      dryStreakHours: dryStreak,
      accumulatedPrecip12hMM: Math.round(rain12hSum * 10) / 10,
      accumulatedSnow12hCM: Math.round(snow12hSum * 10) / 10,
    },
  };
}
exports.parseOpenMeteoResponse = parseOpenMeteoResponse;
exports.buildApiUrl = buildApiUrl;

/**
 * 12h projection — port of RiskProjectionEngine.calculate12HourRiskProfile().
 * Returns up to 13 risk names (current hour + 12 forecast hours).
 */
function calculate12HourRiskProfile(lat, data, startIndex, season) {
  const hourly = data.hourly;
  if (!hourly) return [];
  const airTemps = pickHourly(hourly, ['temperature_2m']);
  const surfTemps = pickHourly(hourly, ['surface_temperature']);
  const dewPoints = pickHourly(hourly, ['dewpoint_2m', 'dew_point_2m']);
  const humidities = pickHourly(hourly, ['relativehumidity_2m', 'relative_humidity_2m']);
  const rains = pickHourly(hourly, ['rain']);
  const showers = pickHourly(hourly, ['showers'], new Array((hourly.time || []).length).fill(0));
  const snows = pickHourly(hourly, ['snowfall']);
  const windSpeeds = pickHourly(hourly, ['wind_speed_10m', 'windspeed_10m'], []);
  const windGusts = pickHourly(hourly, ['wind_gusts_10m', 'windgusts_10m'], []);

  const count = Math.min(
    airTemps.length,
    surfTemps.length,
    dewPoints.length,
    humidities.length,
    rains.length,
    showers.length,
    snows.length,
    windSpeeds.length,
    windGusts.length
  );
  if (count <= 0 || startIndex < 0 || startIndex >= count) return [];
  const endIndex = Math.min(startIndex + 12, count - 1);
  const profile = [];
  const at = (arr, i) => (i < arr.length && arr[i] != null ? arr[i] : 0);

  for (let h = startIndex; h <= endIndex; h++) {
    const airTemp = at(airTemps, h);
    const surfaceTemp = at(surfTemps, h);
    const dewPoint = at(dewPoints, h);
    const rainCur = at(rains, h) + at(showers, h);
    const snowCur = at(snows, h);
    let rain12 = 0;
    let snow12 = 0;
    for (let k = Math.max(0, h - 12); k <= h; k++) {
      rain12 += at(rains, k) + at(showers, k);
      snow12 += at(snows, k);
    }
    let dry = 0;
    for (let d = h - 1; d >= 0 && dry < 24; d--) {
      if (at(rains, d) + at(showers, d) <= RAIN_THRESHOLD && at(snows, d) <= SNOW_THRESHOLD) dry++;
      else break;
    }
    // Hourly equivalent of minutely immediacy: active now, else starting next hour.
    let immR = -1;
    if (rainCur >= RAIN_THRESHOLD) immR = 0;
    else if (h + 1 < count && at(rains, h + 1) + at(showers, h + 1) >= RAIN_THRESHOLD) immR = 60;
    let immS = -1;
    if (snowCur >= SNOW_THRESHOLD) immS = 0;
    else if (h + 1 < count && at(snows, h + 1) >= SNOW_THRESHOLD) immS = 60;

    const r = evaluateRisk({
      airTemp,
      surfaceTemp,
      dewPoint,
      humidity: at(humidities, h),
      rainAndShowerCurrent: rainCur,
      runningRainAndShower12h: rain12,
      runningSnow12h: snow12,
      runningDryStreak: dry,
      season: season || getMeteorologicalSeason(lat, new Date()),
      windSpeed: at(windSpeeds, h),
      windGust: at(windGusts, h),
      immediateRainAndShower: immR,
      immediateSnow: immS,
      surfaceDewSpread: surfaceTemp - dewPoint,
      snowCurrent: snowCur,
    });
    profile.push(r.riskName);
  }
  return profile;
}
exports.calculate12HourRiskProfile = calculate12HourRiskProfile;

/**
 * Legacy wrapper kept for backwards compatibility with the first draft.
 * Accepts hourly-only input (ISO times) and routes it through the new engine.
 */
function evaluateCyclingSlipperiness(hourlyData, lat, checkDate = new Date()) {
  const data = { hourly: hourlyData };
  const nowSec =
    checkDate instanceof Date
      ? Math.floor(checkDate.getTime() / 1000)
      : Math.floor(Date.now() / 1000);
  const parsed = parseOpenMeteoResponse(lat, data, nowSec);
  if (!parsed) return null;
  return {
    timestamp: parsed.timestamp,
    season: parsed.season,
    riskLevel: parsed.riskLevel,
    hazards: parsed.hazards,
    advice: parsed.advice,
    weatherSummary: parsed.weatherSummary,
  };
}
exports.evaluateCyclingSlipperiness = evaluateCyclingSlipperiness;

// Example usage:
// checkRoadSlipperiness(52.0908, 5.1222).then(console.log);
