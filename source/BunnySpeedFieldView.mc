import Toybox.System;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Sensor;
import Toybox.Ant;
import Toybox.AntPlus;

/*!
 * Radar event listener
*/
class MyBikeRadarListener extends AntPlus.BikeRadarListener {
    //! RadarTarget array
    var targets = null;
    //! The fastest car speed
    var maxSpeed = 0f;

    function initialize() {
        BikeRadarListener.initialize();
    }

    function onBikeRadarUpdate(data as Lang.Array<AntPlus.RadarTarget>) {
        targets = data;
        maxSpeed = 0;
        // find the fastest car behind
        for (var f=0; f<data.size(); f++) {
            if (data[f].speed == 0) {
                break;
            } else if (data[f].speed > maxSpeed) {
                maxSpeed = data[f].speed;
            }
        }
    }
}


/*
    Bunny's extended speed dashboard for Garmin Edge

    @author Karoly Szabo (Bunny)
    @version 1.0.5
    @link https://github.com/bunnyhu/GarminDashboardBlock

    @note FONT_MEDIUM = garmin label, FONT_NUMBER_MEDIUM = garmin 2 lines num, FONT_NUMBER_HOT = garmin 1 line num
*/
class BunnySpeedFieldView extends WatchUi.DataField {
    private var _layout as String = "2x2";
    private var _speedMod = 1;      // speed multiplier km/mi
    private var _units as Array;    // unit strings [dist, speed, icon dist, icon speed]
    private var _iconFont;          // data icons
    private var _padding;           // Simu/Device padding
    private var _weather;           // Weather function class
    private var _darkMode;
    private var _sensors;           // All sensors data, always read from this

    private var _radarListener;
    private var _radar = null;
    private const radarDangerLimits = [45, 60]; // max radar speed for circle color [green, yellow ]

    private var _colorDataText as Array = [     // standard data color
        "speed", "distance", "timer", "cadence", "avgSpeed", "slope", "hrIcon", "hrNum",
    ];
    private var _colorLabelText as Array = [    // label color
        "fieldLabel", "cadLabel", "avgSpLabel", "slopeIcon", "distanceIcon", "timerIcon", "cadenceIcon", "speedIcon",
    ];
    private var _alignText as Array = [         // reAlign texts
        "fieldLabel", "cadLabel", "avgSpLabel", "hrNum",
    ];

    // current speed is [ok, little slow, real slow]
    private var speedColors = [Graphics.COLOR_DK_GREEN, Graphics.COLOR_YELLOW, Graphics.COLOR_RED];
    // colors for day/dark mode
    private var baseColors = {
        :sunNumColor => Graphics.COLOR_BLACK,
        :sunLabelColor => 0x777777,         // Graphics.COLOR_DK_GRAY,
        :sunSpeedColors  => [Graphics.COLOR_DK_GREEN, Graphics.COLOR_YELLOW, Graphics.COLOR_RED],

        :darkNumColor => Graphics.COLOR_WHITE,
        :darkLabelColor => 0x999999,
        :darkSpeedColors => [Graphics.COLOR_GREEN, Graphics.COLOR_YELLOW, Graphics.COLOR_RED],

    };

    private var _gradientData = [       // slope
        0f,    // 0. Altitude last estimate
        0f,    // 1. Altitude kalman gain
        0.1f,  // 2. Altitude process noise
        0.5f,  // 3. Altitude estimation error

        0f,    // 4. Distance last estimate
        0f,    // 5. Distance kalman gain
        0.1f,  // 6. Distance process noise
        0.5f,  // 7. Distance estimation error

        0f,    // 8. Last elapsed distance
        0f,    // 9. Last calculation time
        0f,    // 10. Last gradient
        false  // 11. Whether gradient should be calculated
    ];

    function resetSensors() {
        _sensors = {
            :speed       => 0,
            :avgSpeed    => 0,
            :timer       => 0,
            :slope       => 0,
            :distance    => 0.0f,
            :cadence     => 0,
            :avgCadence  => 0,
            :heading     => 0.0f,
            :track       => null,
            :hr          => 0,
            :carSpeed    => 0,
            :carRelSpeed => 0,
            :carDanger   => 0,
            :windDir     => null,
            :windSpeed   => null,
        };
    }

    function initialize() {
        DataField.initialize();
        resetSensors();
        _gradientData[11] = true;   // Enable slope
        _padding = new Align();
        _radarListener = new MyBikeRadarListener();
        _radar = Toybox.AntPlus has :BikeRadar ? new AntPlus.BikeRadar(_radarListener) : null;
        if ( System.getDeviceSettings().distanceUnits == System.UNIT_METRIC) {
            _speedMod = 3.6;
            _units = ["km", "km/h", "C", "D"];
        } else {
            _speedMod = 2.23694;
            _units = ["mi", "mi/h", "F", "E"];
        }
        _weather = new MyWeather();
        _iconFont = Application.loadResource( Rez.Fonts.bikeDataIconFont ) as FontResource;
    }


    /*
        Running when layout change or first load
    */
    function onLayout(dc as Dc) as Void {
        var screenWidth = System.getDeviceSettings().screenWidth;
        var screenHeight = System.getDeviceSettings().screenHeight;
        var fieldWidth = dc.getWidth();
        var fieldHeight = dc.getHeight();

        if (fieldWidth >= (screenWidth/2) ) {
            if (fieldHeight>=(screenHeight/2)) {
                View.setLayout(Rez.Layouts.layout2x2(dc));
                _layout="2x2";
            } else if (fieldHeight>=(screenHeight/4)) {
                View.setLayout(Rez.Layouts.layout2x2(dc));
                _layout="2x2";
            } else {
                View.setLayout(Rez.Layouts.layout2x1(dc));
                _layout="2x1";
            }
        } else {
            View.setLayout(Rez.Layouts.layout1x1(dc));
            _layout="1x1";
        }
        // System.println(_layout);

        setDrawableText("fieldLabel", (WatchUi.loadResource(Rez.Strings.fieldLabel) as String) + " "+ _units[1]);
        setDrawableText("distanceLabel", (WatchUi.loadResource(Rez.Strings.distanceLabel) as String) + " "+ _units[0]);
        setDrawableText("timerLabel", WatchUi.loadResource(Rez.Strings.timerLabel) as String);
        setDrawableText("avgSpLabel", (WatchUi.loadResource(Rez.Strings.avgSpeedLabel) as String) + " "+ _units[1]);
        setDrawableText("cadLabel", WatchUi.loadResource(Rez.Strings.cadenceLabel) as String);
        setDrawableText("distanceIcon", _units[2]);
        setDrawableText("speedIcon", _units[3]);

        // realign all text where need
        for (var f=0; f<_alignText.size(); f++) {
            var elem = findDrawableById(_alignText[f]) as Text;
            if (elem != null) {
                _padding.reAlign(elem);
            }
        }
    }


    /*
        update class var with fresh data like every second
    */
    function compute(info as Activity.Info) as Void {
        if ((_radar == null) && (Toybox.AntPlus has :BikeRadar)) {
            _radar = new AntPlus.BikeRadar(_radarListener);
        }

        resetSensors();
        if (info.currentSpeed != null) {
            _sensors[:speed] = info.currentSpeed * _speedMod;
        }
        if (info.averageSpeed != null) {
            _sensors[:avgSpeed] = info.averageSpeed * _speedMod;
        }
        if (info.timerTime != null) {
            _sensors[:timer] = info.timerTime;
        }
        if (info.elapsedDistance != null) {
            _sensors[:distance] = info.elapsedDistance;
        }
        if (info.currentCadence != null) {
            _sensors[:cadence] = info.currentCadence;
        }
        if (info.averageCadence != null) {
            _sensors[:avgCadence] = info.averageCadence;
        }
        if (info.currentHeartRate != null) {
            _sensors[:hr] = info.currentHeartRate;
        }

        if (info.track != null) {
            _sensors[:track] = (info.track < 0) ? 360.0 + Math.toDegrees(info.track) : Math.toDegrees(info.track);
        } else if (info.currentHeading != null) {
            // 0 is north. -PI/2 radians (90deg CCW) is west, and +PI/2 radians (90deg CW) is east.
            _sensors[:heading] = (info.currentHeading < 0) ? 360.0 + Math.toDegrees(info.currentHeading) : Math.toDegrees(info.currentHeading);
        }
        _sensors[:slope] = computeGradient(info);

        if ((_radarListener != null) && _radarListener.maxSpeed>0) {
            _sensors[:carRelSpeed] = Math.round(_radarListener.maxSpeed * _speedMod);
            _sensors[:carSpeed] = Math.round(_sensors[:carRelSpeed] + _sensors[:speed]);
            if ( _sensors[:carSpeed] <= (radarDangerLimits[0] / 3.6)* _speedMod   ) {
                _sensors[:carDanger] = 1;
            } else if ( _sensors[:carSpeed] <= (radarDangerLimits[1] / 3.6)* _speedMod  ) {
                _sensors[:carDanger] = 2;
            } else {
                _sensors[:carDanger] = 3;
            }
        }

        if (_weather.get(info)) {
            var wind = _weather.getWind();
            _sensors[:windDir] = wind[:dir];
            _sensors[:windSpeed] = wind[:speed];
        }
    }


    /*
        update screen every second if datafield visible
    */
    function onUpdate(dc as Dc) as Void {
        var numColor;
        var labelColor;

        if (getBackgroundColor() == Graphics.COLOR_BLACK) {
            _darkMode = true;
            numColor = baseColors[:darkNumColor]; // Graphics.COLOR_WHITE
            labelColor = baseColors[:darkLabelColor]; // Graphics.COLOR_DK_GRAY
            speedColors = baseColors[:darkSpeedColors];
        } else {
            _darkMode = false;
            numColor = baseColors[:sunNumColor]; // Graphics.COLOR_BLACK
            labelColor = baseColors[:sunLabelColor]; // Graphics.COLOR_LT_GRAY;
            speedColors = baseColors[:sunSpeedColors];
        }
        (View.findDrawableById("Background") as Text).setColor(getBackgroundColor());

        // colorize the labels and datas because night mode
        var colors = [[_colorLabelText, labelColor], [_colorDataText, numColor]];
        for (var c=0; c<colors.size(); c++) {
            for (var f=0; f<colors[c][0].size(); f++) {
                var elem = findDrawableById(colors[c][0][f]) as Text;
                if (elem != null) {
                    elem.setColor(colors[c][1]);
                }
            }
        }
        drawSpeed(numColor);
        if (_sensors[:avgSpeed] < 100) {
            setDrawableText("avgSpeed", _sensors[:avgSpeed].format("%0.1f"));
        } else {
            setDrawableText("avgSpeed", Math.round(_sensors[:avgSpeed]).format("%0.0f"));
        }
        setDrawableText("cadence", formatCadence());
        setDrawableText("distance", formatDistance(_sensors[:distance]));
        setDrawableText("timer", formatTime(_sensors[:timer]));

        if (_layout.equals("2x2")) {
            setDrawableText("slope", Math.round(_sensors[:slope]).format("%0.0f"));

            if (View.findDrawableById("multiCompass") != null) {
                (View.findDrawableById("multiCompass") as RadarCompass).setOptions({
                    :color => numColor,
                    :sensors => _sensors,
                    :background => getBackgroundColor(),
                });
            }
        } else if (_layout.equals("2x1")) {
            setDrawableText("slope", _sensors[:slope].format("%0.1f"));
        }
        setDrawableText("hrNum", _sensors[:hr].format("%u"));

        if (View.findDrawableById("pulseBar") != null) {
            (View.findDrawableById("pulseBar") as HRZoneBar).setOptions({
                :hr => _sensors[:hr],
                :background => getBackgroundColor(),
            });
        }

        View.onUpdate(dc);  // update the layouts, do it BEFORE extra drawing !!!!!!!
    }


    /*
        Colorized speed number, for triange dot we use ( and ) char
    */
    function drawSpeed( numColor ) {
        var spdColor = numColor;
        var deltaDot = ".";
        if ((_sensors[:speed] > 1) && (_sensors[:avgSpeed] > 0) ) {
            var deltaSpd = _sensors[:speed] - _sensors[:avgSpeed];
            if (deltaSpd >= 0) {
                spdColor = speedColors[0];
                deltaDot = "(";     // UP
            } else if (deltaSpd > -1) {
                spdColor = speedColors[1];
                deltaDot = ")";     // DOWN
            } else {
                spdColor = speedColors[2];
                deltaDot = ")";     // DOWN
            }
        }
        var elem = findDrawableById("speed") as Text;
        if (elem != null) {
            elem.setColor(spdColor);
        }
        var speed;
        if (_sensors[:speed] < 100) {
            speed = _sensors[:speed].format("%0.1f");
        } else {
            speed = Math.round(_sensors[:speed]).format("%0.0f");
        }
        var dot = speed.find(".");
        if (dot != null) {
            speed = speed.substring(null, dot) + deltaDot + speed.substring(dot+1, null);
        }
        setDrawableText("speed", speed);
    }


    /*
        Delta indexed cadence number
    */
    function formatCadence() as String {
        if (_sensors[:cadence] == null) {
            return "";
        }

        var index = "";
        if ((_sensors[:avgCadence] != null) && (_sensors[:cadence] > 0)) {
            if (_sensors[:cadence] >= _sensors[:avgCadence]) {
                index = "[";    // UP
            } else {
                index = "]";    // DOWN
            }
        }

        return index + _sensors[:cadence].format("%0.0f");
    }


    /*
        dinamic time formatting [h:]mm:ss
    */
    function formatTime(seconds) as String {
        if ((seconds == null) || (seconds==0)) {
            return "-";
        }
        seconds = seconds / 1000;

        var h = seconds / 3600;
        var m = (seconds % 3600) / 60;
        var s = seconds % 60;
        if (h>0) {
            return h.format("%d") +":" + m.format("%02d") + ":" + s.format("%02d");
        } else {
            return m.format("%02d") + ":" + s.format("%02d");
        }
    }


    /*
        Dinamic distance decimal formatting
    */
    function formatDistance(pDistance) as String {
        if (pDistance == null) {
            return "-";
        }
        pDistance = pDistance / 1000;
        if (pDistance >= 100) {
            return pDistance.format("%.1f");
        } else if (pDistance >= 10) {
            return pDistance.format("%.2f");
        } else {
            return pDistance.format("%.3f");
        }
    }


    /*
        GradeDataField from maca88
        @link https://github.com/maca88/SmartBikeLights/tree/master/Source/GradeDataField
    */
    function computeGradient(activityInfo as Activity.Info) {
        //System.println("usedMemory=" + System.getSystemStats().usedMemory);
        var altitude = activityInfo.altitude;
        var elapsedDistance = activityInfo.elapsedDistance;
        var gradientData = _gradientData;
        if (gradientData[11] /* Enabled */ && altitude != null && elapsedDistance != null) {
            var diffDistance = elapsedDistance - gradientData[8] /* Last elapsed distance */;
            if (diffDistance > 0.5f && activityInfo.timerState == 3 /* TIMER_STATE_ON */) {
                var timer = System.getTimer();
                // Reset last estimate in case the GPS signal is lost to prevent abnormal gradients
                if ((timer - gradientData[9]) > 3000) {
                    //System.println("init d=" + elapsedDistance + " init a=" + altitude);
                    gradientData[0] = altitude; // Reset altitude last estimate
                    gradientData[4] = diffDistance; // Reset distance last estimate
                }

                gradientData[8] = elapsedDistance; // Update last elapsed distance
                gradientData[9] = timer; // Update last calculation time
                var lastEstimateAltitude = gradientData[0];
                var currentEstimateAltitude = updateGradientData(altitude, 0); // Update estimated altitude
                gradientData[10] = ((currentEstimateAltitude - lastEstimateAltitude) / updateGradientData(diffDistance, 4) /* Update estimated distance */) * 100; // Calculate gradient
                //System.println("d=" + elapsedDistance + " a=" + altitude + " ca=" + currentEstimateAltitude + " ddiff=" + diffDistance + " cddiff=" + gradientData[4] + " cadiff=" + (currentEstimateAltitude - lastEstimateAltitude) + " grade=" + gradientData[10]);
            } else {
                gradientData[10] = 0f; // Reset last gradient
            }
        }
        return gradientData[10];
    }


    /*
        GradeDataField from maca88
        @link https://github.com/maca88/SmartBikeLights/tree/master/Source/GradeDataField
    */
    private function updateGradientData(value, index) {
        // Calculate smooth gradient, applying simple kalman filter
        var gradientData = _gradientData;
        var lastEstimate = gradientData[index];
        var errorEstimate = gradientData[index + 3];
        var kalmanGain = errorEstimate / (errorEstimate + 5f /* Measure error */);
        var currentEstimate = lastEstimate + kalmanGain * (value - lastEstimate);
        var diffEstimate = (lastEstimate - currentEstimate).abs();
        gradientData[index + 3] = (1f - kalmanGain) * errorEstimate + diffEstimate * gradientData[index + 2] /* Process noise */; // Update estimation error
        gradientData[index + 1] = kalmanGain; // Update kalman gain
        gradientData[index + 2] = 1f /* Max process noise */ / (1f + diffEstimate * diffEstimate); // Update process noise
        gradientData[index] = currentEstimate; // Update last estimate
        return currentEstimate;
    }


    /*
        Safe setText()
    */
    function setDrawableText(pId, pValue) {
        var elem = View.findDrawableById(pId) as Text;
        if (elem != null) {
            elem.setText(pValue);
        }
    }
}
