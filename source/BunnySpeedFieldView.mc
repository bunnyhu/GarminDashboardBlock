import Toybox.System;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Activity;
import Toybox.Graphics;
import Toybox.UserProfile;
import Toybox.Sensor;
import Toybox.Ant;
import Toybox.AntPlus;


class MyBikeRadarListener extends AntPlus.BikeRadarListener {
    var targets = null;
    var maxSpeed = 0f;

    function initialize() {
        BikeRadarListener.initialize();
    }

    function onBikeRadarUpdate(data as Lang.Array<AntPlus.RadarTarget>) {
        targets = data;
        maxSpeed = 0;
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
    Bunny's extended speed datafield for Garmin Edge Explore2

    @author Karoly Szabo (Bunny)
    @version 1.0
    @release 2024. febr. 18.
    @link https://github.com/bunnyhu/BunnySpeedField

    @note FONT_MEDIUM = garmin label, FONT_NUMBER_MEDIUM = garmin 2 lines num, FONT_NUMBER_HOT = garmin 1 line num
*/
class BunnySpeedFieldView extends WatchUi.DataField {
    private var _layout as String = "2x2";
    private var _speedMod = 1;      // speed multiplier km/mi
    private var _units as Array;    // unit strings [dist, speed]
    private var _imgVRainbowBar;    // heart rate bar
    private var _iconFont;          // data icons
    private var _padding;           // Simu/Device padding
    private var _weather;           // Weather function class

    private var _sensors;           // Actual sensors datas set by compute() and resetSensors()
    private var _hrZones as Array = [];     // heartRate Zones
    private var _hrPixel as Float = 3.00f;  // 1 HR pulse pixel
    private var _heartVisible as Number = 0;

    private var _radarListener;
    private var _radar = null;
    private var _colorDataText as Array = [    // standard data color
        "speed", "distance", "timer", "cadence", "avgSpeed", "slope", "hrIcon",
    ];
    private var _colorLabelText as Array = [   // label color
        "fieldLabel", "cadLabel", "avgSpLabel", "slopeIcon", "distanceIcon", "timerIcon", "cadenceIcon", "speedIcon",
    ];
    private var _alignText as Array = [         // reAlign texts
        "fieldLabel", "cadLabel", "avgSpLabel",
    ];

    // speed ok, little slow, real slow
    private var speedColors = [Graphics.COLOR_DK_GREEN, Graphics.COLOR_YELLOW, Graphics.COLOR_RED];   
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
            :heading     => 0.0f,
            :hr          => 0,
            :carSpeed    => 0,
            :carRelSpeed => 0,
            :windDir     => null,
            :windSpeed   => null,
        };        
    }

    function initialize() {
        DataField.initialize();        
        resetSensors();
        _hrZones = UserProfile.getHeartRateZones(UserProfile.getCurrentSport());
        if (_hrZones.size() != 6 ) {
            _hrZones = [1,2,3,4,5,6];
        }        
        _hrPixel =  90 / (_hrZones[5]-_hrZones[0]).toFloat();
        _gradientData[11] = true; // Enable
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
        _imgVRainbowBar = Application.loadResource( Rez.Drawables.imageVRainbowBar ) as BitmapResource;
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
        if (info.currentHeartRate != null) {
            _sensors[:hr] = info.currentHeartRate;
        }
        if (info.currentHeading != null) {
            // 0 is north. -PI/2 radians (90deg CCW) is west, and +PI/2 radians (90deg CW) is east.
            _sensors[:heading] = (info.currentHeading < 0) ? 360.0 + Math.toDegrees(info.currentHeading) : Math.toDegrees(info.currentHeading);
        }
        _sensors[:slope] = computeGradient(info);

        if ((_radarListener != null) && _radarListener.maxSpeed>0) {
            _sensors[:carRelSpeed] = Math.round(_radarListener.maxSpeed * _speedMod);
            _sensors[:carSpeed] = Math.round(_sensors[:carRelSpeed] + _sensors[:speed]);
        }

        if (_weather.get(info)) {            
            var _wind = _weather.getWind();
            _sensors[:windDir] = _wind[:dir];
            _sensors[:windSpeed] = _wind[:speed];
        }
        
    }


    /*
        update screen every second if datafield visible
    */    
    function onUpdate(dc as Dc) as Void {
        var numColor;
        var labelColor;

        if (getBackgroundColor() == Graphics.COLOR_BLACK) {
            numColor = Graphics.COLOR_WHITE;
            labelColor = Graphics.COLOR_DK_GRAY;
        } else {
            numColor = Graphics.COLOR_BLACK;
            labelColor = Graphics.COLOR_LT_GRAY;
        }

        (View.findDrawableById("Background") as Text).setColor(getBackgroundColor());

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
        setDrawableText("cadence", _sensors[:cadence].format("%0.0f"));
        setDrawableText("distance", showDistance(_sensors[:distance]));
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

        View.onUpdate(dc);  // !!!!!!

        if (_layout.equals("2x2")) {
            drawColorBar(dc, {
                :x => 1,
                :y => 1,
                :hr => _sensors[:hr],
                :icon => "hrIcon",
            });   

        }
    }

    function drawSpeed( numColor ) {
        var spdColor = numColor;
        var deltaDot = ".";
        if ((_sensors[:speed] > 1) && (_sensors[:avgSpeed] > 0) ) {
            var deltaSpd = _sensors[:speed] - _sensors[:avgSpeed];
            if (deltaSpd >= 0) {
                spdColor = speedColors[0];
                deltaDot = "(";
            } else if (deltaSpd > -1) {
                spdColor = speedColors[1];                
                deltaDot = ")";
            } else {
                spdColor = speedColors[2];
                deltaDot = ")";
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
        Dinamic long distance
    */
    function showDistance(pDistance) as String {
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
        GradeDataField
        @author maca88
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
        GradeDataField
        @author maca88
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
        Show text if avaiable       
        @param pId layout text ID
        @param pValue text value
    */
    function setDrawableText(pId, pValue) {
        var elem = View.findDrawableById(pId) as Text;
        if (elem != null) {
            elem.setText(pValue);
        }                
    }


    /*
        Draw heart rate bar
    */
    function drawColorBar(dc as Dc, options as { :x as Number, :y as Number, :hr as Number }) {
        var hr = options[:hr];
        if (hr == null) {
            hr = 0;
        }
        // balcsi kör
        // 87,103,121,138,156,180         87-103, 104-121, 122-138, 139-156, 157<
        // Garmin min: 65 max: 181        91-108, 109-126, 127-144, 145-162, 163-180, 
        if (hr > _hrZones[5]) {
            hr = _hrZones[5];
        } else if (hr < _hrZones[0]) {
            hr = _hrZones[0];               
        }
        dc.setColor(getBackgroundColor(), Graphics.COLOR_TRANSPARENT);
        dc.drawBitmap(options[:x], options[:y], _imgVRainbowBar);
        dc.fillRectangle(options[:x], options[:y], 15, Math.floor(_hrPixel * (_hrZones[5]-hr) ));
        _heartVisible ++;
        if (_heartVisible > 2) {
            var y = options[:y]-8+Math.floor(_hrPixel * (_hrZones[5]-hr) );
            if (y >= 0) {
                dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
                dc.drawText(2, y, _iconFont, "H", Graphics.TEXT_JUSTIFY_LEFT);
            }
        }
        if (_heartVisible > 4) {
            _heartVisible = 0;
        }
    }

    /* 
        Get compass arrow number
        @see compassIconFont
    */
    function drawHeading(pHeadingValue) as Number {
        var dir = pHeadingValue;
        dir = Math.round(dir / 45);
        return dir.toNumber();
    }


    /* 
        Vonalzó kirajzolás dev alatt pozícionáláshoz
    */
    function drawRuler(dc as Dc) {
        var fieldHeight = dc.getHeight();
        for (var f=0; f<=fieldHeight; f++) {
            dc.setColor(Graphics.COLOR_BLUE, getBackgroundColor());
            if (f%10 == 0) {
                dc.setColor(Graphics.COLOR_RED, getBackgroundColor());
                dc.drawLine(0, f, 10, f);
            } else if (f%2 == 0) {
                dc.drawLine(0, f, 5, f);
            }
        }        
    }
}
