const https = require("https");

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

/*
Summer: Detects sequences of dry days ($rain = 0$). 
Light rain after $\ge 2$ dry days triggers a high risk score due to oil/grease emulsion on asphalt.Winter: Prioritizes thermal thresholds ($\le 2^\circ\text{C}$) to flag black ice or frost.Autumn: Applies a baseline penalty for wet leaves and organic matter decomposition.Spring: Focuses on cold wet asphalt where tire rubber compounds remain firm and offer less mechanical bite.
*/
/**
 * Calculates road slipperiness for cycling based on past and current weather data.
 * 
 * @param {Array<Object>} history - Past 3-4 days weather data (daily or historical summary)
 * @param {Object} current - Current weather data from OWM OneCall
 * @param {'summer'|'autumn'|'spring'|'winter'} season - Current riding season
 * @returns {Object} Slippery index (0 to 100), risk level, and reasons
 */
function EvaluateRoadSlippiness(history, current, season = 'summer') {
    let score = 0;
    const reasons = [];

    const temp = current.temp;
    const rainCurrent = current.rain ? current.rain['1h'] || 0 : 0;
    const isWetNow = rainCurrent > 0 || current.humidity > 92;

    // 1. Seasonal Base Risk & Specific Factors
    switch (season.toLowerCase()) {
        case 'winter':
            if (temp <= 2) {
                score += 60;
                reasons.push("Freezing risk: Temperature is near or below freezing.");
            }
            if (temp <= 0 && isWetNow) {
                score += 30;
                reasons.push("Black ice risk: Moisture present at freezing temps.");
            }
            break;

        case 'autumn':
            score += 15; // Baseline risk for falling leaves/organic film
            if (isWetNow) {
                score += 25;
                reasons.push("Wet leaf hazard: Rain creates a slick layer over organic debris.");
            }
            break;

        case 'summer':
            // Summer "First Rain" Phenomenon
            const dryDaysCount = history.filter(day => {
                const rain = day.rain ? day.rain['1h'] || 0 : (day.precipitation || 0);
                return rain === 0;
            }).length;

            if (dryDaysCount >= 2 && rainCurrent > 0 && rainCurrent <= 2.5) {
                score += 45;
                reasons.push(`First Rain Effect: ${dryDaysCount} dry days accumulated road oil/dust, now lifted by light rain.`);
            } else if (dryDaysCount >= 2 && rainCurrent > 2.5) {
                score += 20; // Heavy rain partially washes away oils
                reasons.push("Heavy rain after dry spell: Partial oil lift, but runoff helps flush asphalt.");
            }
            break;

        case 'spring':
            if (isWetNow && temp < 10) {
                score += 15;
                reasons.push("Cold wet asphalt: Low tire rubber flexibility reduces grip.");
            }
            break;
    }

    // 2. Active Wetness Impact
    if (rainCurrent > 0) {
        if (rainCurrent <= 1.0) {
            score += 20; // Light drizzle creates slick film without washing road
            reasons.push("Light rain/drizzle creates surface film.");
        } else {
            score += 15; // Moderate/heavy rain reduces mechanical grip
            reasons.push("Active rainfall reduces tire traction.");
        }
    }

    // 3. Humidity & Dew Point (Fog / Condensation)
    if (!rainCurrent && current.humidity >= 90 && Math.abs(temp - current.dew_point) <= 1.5) {
        score += 25;
        reasons.push("High humidity & fog/dew: Invisible moisture film on road surface.");
    }

    // Check if ground might still be frozen from past 24-48 hours
    const hadRecentFreezing = history.some(entry => entry.temp <= 0);

    if (hadRecentFreezing && current.temp > 0 && current.temp <= 3 && rainCurrent > 0) {
        score += 50;
        reasons.push("Black Ice Risk: Rain falling on ground that was frozen in recent days.");
    }

    // Cap score between 0 and 100
    const finalScore = Math.min(Math.max(score, 0), 100);

    // Determine Risk Category
    let level = 'LOW';
    if (finalScore >= 70) level = 'CRITICAL';
    else if (finalScore >= 45) level = 'HIGH';
    else if (finalScore >= 20) level = 'MODERATE';

    return {
        score: finalScore,
        level: level,
        isSlippery: finalScore >= 45,
        reasons: reasons
    };
}

const historyEntrySchema = {
    dt: 1787932762,        // Unix timestamp
    temp: 18.5,            // °C (detects ground/air freeze history)
    precipitation: 1.33,   // mm (rain + snow combined)
    humidity: 85           // % (tracks road drying speed)
};

/*
// Example Usage:
const historyData = [
    { precipitation: 0 }, // 3 days ago
    { precipitation: 0 }, // 2 days ago
    { precipitation: 0 }  // Yesterday
];

const currentData = {
    temp: 19.8,
    humidity: 85,
    dew_point: 17.2,
    rain: { "1h": 1.15 }
};

const result = EvaluateRoadSlippiness(historyData, currentData, 'summer');
console.log(result);
*/
/*
Parsing weather entry:  {
  dt: 1788447911,
  sunrise: 1788411382,
  sunset: 1788459992,
  temp: 22.48,
  feels_like: 22.79,
  pressure: 1015,
  humidity: 77,
  dew_point: 18.25,
  uvi: 1.01,
  clouds: 100,
  visibility: 10000,
  wind_speed: 2.24,
  wind_deg: 254,
  wind_gust: 6.71,
  weather: [
    {
      id: 804,
      main: 'Clouds',
      description: 'overcast clouds',
      icon: '04d'
    }
  ]
}
*/
const parseWeatherData = function (entry) {
    console.log("Parsing weather entry: ", entry);

    const dateStr = new Date(entry.dt * 1000).toISOString();

    // Basic properties
    const temp = entry.temp;
    const humidity = entry.humidity;
    const pressure = entry.pressure;
    const windSpeed = entry.wind_speed;
    const clouds = entry.clouds;

    // Safely extract rain/snow volumes
    const rain = entry.rain ? entry.rain['1h'] || 0 : 0;
    const snow = entry.snow ? entry.snow['1h'] || 0 : 0;
    const precipitation = rain + snow;

    return `[${dateStr}] Temp: ${temp}°C | Humidity: ${humidity}% | Pressure: ${pressure}hPa | Wind: ${windSpeed}m/s | Precip: ${precipitation}mm | Clouds: ${clouds}%`;
}

const getPastFourDaysWeather = async function (appid, lat, lon) {

    const nowInSeconds = Math.floor(Date.now() / 1000);
    const ONE_DAY_IN_SECONDS = 86400;

    // Generate Unix timestamps for the past 4 days
    const timestamps = [1, 2, 3, 4].map((day) => nowInSeconds - day * ONE_DAY_IN_SECONDS);

    var allWeatherData = [];
    
    for (const ts of timestamps) {
        const url = `https://api.openweathermap.org/data/3.0/onecall/timemachine?lat=${lat}&lon=${lon}&dt=${ts}&appid=${appid}&units=metric`;

        try {
            const response = await fetch(url);
            const json_data = await response.json();
            
            if (json_data.current) {
                console.log('--- Requested Timestamp Weather ---');
                allWeatherData.push(parseWeatherData(json_data.current));
            }


            // Target full 24-hour history for that day
            if (Array.isArray(json_data.data)) {
                console.log('--- Hourly Breakdown ---');
                json_data.data.forEach((hour) => {
                    allWeatherData.push(parseWeatherData(hour));
                });
            }

        } catch (error) {
            console.error(`Error fetching data for timestamp ${ts}:`, error.message);
        }
    }
    return allWeatherData;
}

/*
{
  lat: 52.1515,
  lon: 4.7743,
  timezone: "Europe/Amsterdam",
  timezone_offset: 7200,
  data: [
    {
      dt: 1787846805,
      sunrise: 1787805844,
      sunset: 1787856082,
      temp: 27.08,
      feels_like: 28.65,
      pressure: 1008,
      humidity: 66,
      dew_point: 20.18,
      uvi: 1.06,
      clouds: 67,
      visibility: 10000,
      wind_speed: 2.9,
      wind_deg: 184,
      wind_gust: 4.9,
      weather: [
        {
          id: 803,
          main: "Clouds",{
  dt: 1787933334,
  sunrise: 1787892342,
  sunset: 1787942349,
  temp: 17.21,
  feels_like: 17.47,
  pressure: 1007,
  humidity: 95,
  dew_point: 16.4,
  uvi: 0.95,
  clouds: 99,
  visibility: 10000,
  wind_speed: 4,
  wind_deg: 0,
  wind_gust: 8.9,
  weather: [
    {
      id: 501,
      main: "Rain",
      description: "moderate rain",
      icon: "10d",
    },
  ],
  rain: {
    "1h": 1.33,
  },
}
          description: "broken clouds",
          icon: "04d",
        },
      ],
    },
  ],
}
  */


exports.getSlipperyness = async function (appid, lat, lon) {
    var season = getMeteorologicalSeason(lat, Math.floor(Date.now() / 1000));
    console.log("Season: " + season);

    let slipperyData = await getPastFourDaysWeather(appid, lat, lon);
    console.log("Slippery Data: ", slipperyData);


}