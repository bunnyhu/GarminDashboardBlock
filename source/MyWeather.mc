import Toybox.System;
import Toybox.Lang;
import Toybox.Activity;
import Toybox.Weather;
import Toybox.Time;
import Toybox.Time.Gregorian;

class MyWeather {
    /*
        For saving energy, we try to cache data top of the garmin cache (we no nothing about that, so no trust).
        There is a start period when the activity start, we try to load first time the weather data more often.
        When this period finish and still no data, we still try slower but still faster than normal till we get one.
        If we have first data ever, we turn to normal refresh frequent.
        If the data is older than CURRENT_LIFETIME, we do not trust the CurrentCondition anymore and we using 
        the hourlyForecast. Anytime when we get fresh data, the lifetime restart.
    */    
    const START_DURATION = 60*5;        // start period duration, we try to get data harder
    const START_REFRESH = 15;           // first data trying frequent in start period
    const NORMAL_FIRST_REFRESH = 60*2;  // if no data after start duration, the first data try frequent
    const NORMAL_REFRESH = 60*10;       // we have data, slow down. Normal refresh frequent
    const CURRENT_LIFETIME = 60*60;     // how long the currentCondition fine, after this we using hourlyForecast

    // Test data
    // const START_DURATION = 60*1;
    // const START_REFRESH = 5;
    // const NORMAL_FIRST_REFRESH = 10;
    // const NORMAL_REFRESH = 20;    
    // const CURRENT_LIFETIME = 60*1;

    var hourlyForecast = null;
    var current = null;
    var wind = {:speed=>null, :dir=>null};
    var hourlyTS = null;
    var currentTS = null;
    var lastTryTS = null;

    function initialize() {
    }

    function loadWeather() {
        // System.print("loading...");
        lastTryTS = Time.now();
        var _current = Weather.getCurrentConditions();
        if (_current != null) {                        
            currentTS = Time.now();
            current = _current;
            wind = {:speed=>current.windSpeed, :dir=>current.windBearing};
        }
        var _hourlyForecast = Weather.getHourlyForecast();
        if (_hourlyForecast != null) {
            hourlyTS = Time.now();
            hourlyForecast = _hourlyForecast;
        }
        // System.println(((_current != null) && (_hourlyForecast != null)) ? "OK" : "FAIL");
        if ( (_current == null) && (currentTS != null) && (hourlyTS != null) ) {
            if (( Time.now().subtract(current.observationTime).value() > CURRENT_LIFETIME ) && (hourlyForecast != null) ) {
                // System.println("Current túl régi, de van forecast");
                wind = getForecastWind( wind );
            }
        }
    }

    function getForecastWind(_wind) as Dictionary {
        if (hourlyForecast != null) {
            for (var f=0; f<hourlyForecast.size(); f++) {
                // var today = Gregorian.info(hourlyForecast[f].forecastTime, Time.FORMAT_MEDIUM);
                // var dateString = Lang.format( "$1$ $2$ $3$ $4$:$5$:$6$",
                //                  [today.year, today.month, today.day, today.hour, today.min, today.sec, ] );                
                // System.print(dateString);
                if ( (hourlyForecast[f].forecastTime.value() > current.observationTime.value() )
                    && (hourlyForecast[f].forecastTime.value() <= Time.now().value()) ) {
                    _wind = {:speed=>hourlyForecast[f].windSpeed, :dir=>hourlyForecast[f].windBearing };
                //     System.println(" save");
                // } else {
                //     System.println("");
                }
            }
        }
        return _wind;
    }


    function getWind() as Dictionary {
        // if (hourlyTS && currentTS) {
        //     System.print("Van adat, kora: ");
        //     System.print(Time.now().subtract(currentTS).value());
        //     System.println(" s:" + wind[:speed].format("%0.2f") + " d:" + wind[:dir].format("%d"));
        // }
        return wind;
    }

    function get(info as Activity.Info) as Boolean {
        if ((info.timerState == Activity.TIMER_STATE_ON) && (info.startTime != null)) {
            // Fut az aktivitás
            // System.print(Time.now().subtract(info.startTime).value());
            // System.print(", ");
            if ((currentTS == null) && (Time.now().subtract(info.startTime).value() <= START_DURATION )) {
                System.println("indulási fázis és nincs adat");
                if (lastTryTS == null) {
                    // System.println("Még sosem próbáltam");
                    loadWeather();
                } else if (Time.now().subtract(lastTryTS).value() >= START_REFRESH) {
                    // System.println("volt már sikertelen próba és ideje újra próbálni");
                    loadWeather();
                }                
            } else if ((currentTS == null) && (Time.now().subtract(lastTryTS).value() >= NORMAL_FIRST_REFRESH)) {
                // System.println("Lejárt az indítási fázis de még mindig nincs adat");
                loadWeather();
            } else if (Time.now().subtract(lastTryTS).value() >= NORMAL_REFRESH) {
                // System.println("Akár van adat akár nincs, normál frissítést elvégezzük");
                loadWeather();
            }
        }
        return (hourlyTS && currentTS) ? true : false;
    }
}
