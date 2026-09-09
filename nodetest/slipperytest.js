const slippery = require('./slipperycheck.js');

// Amsterdam, Netherlands
var lat = 52.188950;
var lon = 4.549666;

// grossclockner 47.0833, 12.8422
lat = 47.0833;
lon = 12.8422;

// Tromsø / High Arctic Norway
lat = 69.6492;
lon = 18.9553;

// Highlands, Scotland: 56.8198, -5.1052
lat = 56.8198;
lon = -5.1052;

// greenland 78.75564882472699, -55.04153596826567
lat = 78.75564882472699;
lon = -55.04153596826567;
// Test the function

slippery.checkRoadSlipperiness(lat, lon)
	.then((result) => console.log(result))
	.catch((error) => {
		console.error(error);
		process.exitCode = 1;
	});

	/*
	{
  timestamp: '2026-09-04T16:00',
  season: 'summer',
  riskLevel: 'CRITICAL',
  hazards: [ 'Black ice / Freezing wet road', 'Snow or slush accumulation' ],
  advice: [
    'Extremely dangerous for road tires; avoid riding or lower tire pressure significantly.',
    'Loss of traction when leaning into turns; tread pattern required.'
  ],
  weatherSummary: {
    airTempC: -11.2,
    surfaceTempC: -11.4,
    dewPointC: -13.6,
    humidityPercent: 82,
    rainMM: 0,
    accumulatedPrecip12hMM: 1,
    accumulatedSnow12hCM: 0.6
  }
	*/