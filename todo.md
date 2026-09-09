- Menu
- BG call
    - get weather data
    - cache it
- Calc slipperyness on bg data event

- View
    show details
    -> display options: ??

- git -> remote

+
- linux taskbar app for local use

- option to collect lat/lon during commute 
- for predict commute track
- reset option after activity done


## Parsing the hourly time

How to Calculate Time Offsets In-Memory
Because Open-Meteo arrays are strictly sequential and hourly aligned:

Note the start_time (first entry of the array).

The i-th element in any weather array corresponds exactly to start_time + (i * 3600) seconds.

Once you extract the start index in Monkey C, you can immediately discard or ignore the time array in memory.
