const https = require("https");

/**
 * Fetches Open-Meteo weather data and evaluates road slipperiness.
 * @param {number} lat - Latitude
 * @param {number} lon - Longitude
 * @param {number} pastDays - Number of previous days to analyze (default: 2)
 */
exports.checkRoadSlipperiness = async function (lat, lon, pastDays = 2) {
    const params = new URLSearchParams({
        latitude: lat,
        longitude: lon,
        hourly: [
            'temperature_2m',
            'relative_humidity_2m',
            'dew_point_2m',
            'precipitation',
            'rain',
            'snowfall',
            'surface_temperature'
        ].join(','),
        past_days: pastDays,
        forecast_days: 1,
        timezone: 'auto'
    });

    const url = `https://api.open-meteo.com/v1/forecast?${params.toString()}`;

    try {
        const response = await fetch(url);
        if (!response.ok) throw new Error(`Open-Meteo HTTP error: ${response.status}`);
              
        const data = await response.json();

        const jsonString = JSON.stringify(data);
        const memoryBytes = Buffer.byteLength(jsonString, 'utf8');
        console.log(`JSON Data Size: ${memoryBytes} bytes (${(memoryBytes / 1024).toFixed(2)} KB)`);

        return evaluateCyclingSlipperiness(data.hourly);
    } catch (err) {
        console.error('Failed to fetch Open-Meteo data:', err);
        return null;
    }
}

/**
 * Determines the meteorological season based on latitude and Unix timestamp.
 * 
 * @param {number} lat - Latitude (-90 to 90)
 * @param {number} dtInSeconds - Unix timestamp in seconds
 * @returns {'spring'|'summer'|'autumn'|'winter'} Season name
 */
getMeteorologicalSeason = function getMeteorologicalSeason(lat, dtInSeconds) {
    const date = new Date(dtInSeconds * 1000);
    const month = date.getUTCMonth(); // 0 = Jan, 1 = Feb, ..., 11 = Dec

    // Northern Hemisphere mapping
    let season = '';
    if (month === 11 || month === 0 || month === 1) {
        season = 'winter';
    } else if (month >= 2 && month <= 4) {
        season = 'spring';
    } else if (month >= 5 && month <= 7) {
        season = 'summer';
    } else {
        season = 'autumn';
    }

    // Invert for Southern Hemisphere
    if (lat < 0) {
        const invertedSeasons = {
            winter: 'summer',
            spring: 'autumn',
            summer: 'winter',
            autumn: 'spring'
        };
        season = invertedSeasons[season];
    }

    return season;
};

/**
 * Validates seasonal tags like "spring", "summer", "spring;summer;autumn", "winter".
 */
function isSeasonActive(seasonalTag, lat, date = new Date()) {
    if (!seasonalTag) return true; // Default open if no tag

    const clean = seasonalTag.trim().toLowerCase();
    if (clean === 'no' || clean === 'false') return true;

    const currentSeason = getMeteorologicalSeason(lat, Math.floor(date.getTime() / 1000));

    // Split multi-value tags like "spring;summer;autumn" or "summer, autumn"
    const seasons = clean.split(/[;,/]/).map(s => s.trim().replace('fall', 'autumn'));

    if (seasons.includes(currentSeason)) {
        return true;
    }

    // Default "seasonal=yes" logic (active except in winter)
    if (clean === 'yes' || clean === 'true') {
        return currentSeason !== 'winter';
    }

    return false;
}

/**
 * Calculates meteorological road slipperiness specifically for cycling.
 * 
 * @param {Object} hourlyData - Hourly forecast data object from Open-Meteo
 * @param {number} lat - Latitude (used to calculate current season)
 * @param {Date} [checkDate=new Date()] - Date/time to evaluate against
 */
function evaluateCyclingSlipperiness(hourlyData, lat, checkDate = new Date()) {
    const times = hourlyData.time;
    const nowISO = checkDate.toISOString().substring(0, 13);

    let currentIndex = times.findIndex(t => t.startsWith(nowISO));
    if (currentIndex === -1) currentIndex = times.length - 1;

    // Current hour weather parameters
    const currentTemp = hourlyData.temperature_2m[currentIndex];
    const surfaceTemp = hourlyData.surface_temperature[currentIndex];
    const dewPoint = hourlyData.dew_point_2m[currentIndex];
    const humidity = hourlyData.relative_humidity_2m[currentIndex];
    const currentRain = hourlyData.rain[currentIndex];

    // Look back up to 12 hours for moisture and temperature trends
    const lookbackStart = Math.max(0, currentIndex - 12);
    const recentPrecip = hourlyData.precipitation
        .slice(lookbackStart, currentIndex + 1)
        .reduce((sum, val) => sum + (val || 0), 0);

    const recentSnow = hourlyData.snowfall
        .slice(lookbackStart, currentIndex + 1)
        .reduce((sum, val) => sum + (val || 0), 0);

    // Look back at dry streak length (for "first rain after dry spell" effect)
    const previous24hStart = Math.max(0, currentIndex - 24);
    const dryHoursBeforeRain = hourlyData.precipitation
        .slice(previous24hStart, Math.max(0, currentIndex - 1))
        .filter(val => (val || 0) === 0).length;

    // Determine current season
    const currentSeason = getMeteorologicalSeason(lat, checkDate);

    let riskLevel = 'SAFE'; // SAFE | SLIGHT | MODERATE | HIGH | CRITICAL
    let hazards = [];
    let advice = [];

    // --- HAZARD EVALUATION (Prioritized by risk severity) ---

    // 1. Black Ice & Freezing Wet Asphalt
    if ((surfaceTemp <= 0 || currentTemp <= 0.5) && recentPrecip > 0) {
        riskLevel = 'CRITICAL';
        hazards.push('Black ice / Freezing wet road');
        advice.push('Extremely dangerous for road tires; avoid riding or lower tire pressure significantly.');
    }

    // 2. Active Snow or Accumulated Slush
    if (recentSnow > 0) {
        if (riskLevel !== 'CRITICAL') riskLevel = 'HIGH';
        hazards.push('Snow or slush accumulation');
        advice.push('Loss of traction when leaning into turns; tread pattern required.');
    }

    // 3. Hoarfrost / Freezing Fog (Asphalt temperature at or below freezing near dew point)
    if (surfaceTemp <= 0 && (currentTemp - dewPoint) < 2.0 && humidity > 85) {
        if (riskLevel !== 'CRITICAL') riskLevel = 'HIGH';
        hazards.push('Road surface frost / Hoarfrost');
        advice.push('Watch out for shaded areas, bridge decks, and tree-lined roads.');
    }

    // 4. Autumn Wet Leaves Hazard
    if (currentSeason === 'autumn' && (recentPrecip > 0 || humidity > 90)) {
        if (riskLevel === 'SAFE' || riskLevel === 'SLIGHT') riskLevel = 'MODERATE';
        hazards.push('Wet leaf coverage on asphalt');
        advice.push('Extreme slip hazard on cornering lines; avoid sudden braking over leaves.');
    }

    // 5. Summer/Spring First Rain ("Oil Slick" effect)
    if ((currentSeason === 'summer' || currentSeason === 'spring') && currentRain > 0 && currentRain < 2.0 && dryHoursBeforeRain >= 18) {
        if (riskLevel === 'SAFE') riskLevel = 'MODERATE';
        hazards.push('First rain releasing road oil/dirt film');
        advice.push('Asphalt is slippery during initial rainfall; traction improves after heavier washing rain.');
    }

    // 6. General Wet Asphalt
    if (currentRain > 0.5 && riskLevel === 'SAFE') {
        riskLevel = 'SLIGHT';
        hazards.push('Wet asphalt surface');
        advice.push('Increase braking distance and reduce cornering lean angle.');
    }

    return {
        timestamp: times[currentIndex],
        season: currentSeason,
        riskLevel,
        hazards,
        advice,
        weatherSummary: {
            airTempC: currentTemp,
            surfaceTempC: surfaceTemp,
            dewPointC: dewPoint,
            humidityPercent: humidity,
            rainMM: currentRain,
            accumulatedPrecip12hMM: Math.round(recentPrecip * 10) / 10,
            accumulatedSnow12hCM: Math.round(recentSnow * 10) / 10
        }
    };
}

// Example usage:
// checkRoadSlipperiness(52.0908, 5.1222, 2).then(console.log);