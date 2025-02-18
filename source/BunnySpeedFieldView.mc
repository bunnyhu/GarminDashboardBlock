import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.AntPlus;
import Toybox.System;
import Toybox.UserProfile;


/*
    Bunny's combined speed datafield for Garmin Edge Explore2

    author: Karoly Szabo (Bunny)
    version: 1.0
    release: 2024. febr. 15.
    https://github.com/bunnyhu/BunnySpeedField
*/
class BunnySpeedFieldView extends WatchUi.DataField {
    private var _sensors as {   // Actual sensors datas set by compute()
        :speed as Number,
        :avgSpeed as Number,
        :timer as Number,
        :slope as Number,
        :distance as Float,
        :cadence as Number,
        :heading as Float,
        :hr as Number,          // actual heart rate
    };
    private var _speedMod = 1;  // speed multiplier km/mi
    private var _units as Array;    // unit strings [dist, speed]
    private var _paddings;          // Simu/Device padding
    private var _imgVRainbowBar;    // heart rate bar
    private var _iconFont;          // data icons
    private var _directionTexts;        // compass direction texts
    private var _lastBackground = -1;
    private var _layout as String = "2x2";
    // 128,153,179,204,230,255
    private var _hrZones as Array = []; // heartRate Zones
    private var _hrPixel as Float = 3.00f;   // 1 HR pulse pixel
    private var _heartVisible as Number = 0;


    // FONT_MEDIUM = gyári label, FONT_NUMBER_MEDIUM = 2 soros szám, FONT_NUMBER_HOT gyári számméret
    // type: 0=labelColor, 1=textColor, other=nochange
    private var _labelDatas as Array = [        
        "speed", "distance", "timer", "cadence", "avgSpeed", "slope", "hrIcon",
    ];
    private var _alignLabels as Array = [
        "fieldLabel", "cadLabel", "avgSpLabel", "compLabel",
    ];
    private var _labelIcons as Array = [
        "slopeIcon", "distanceIcon", "timerIcon", "cadenceIcon", "speedIcon",
    ];
  
    private var _gradientData = [   // slope
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

    /* 
        Defaults
    */
    function initialize() {
        DataField.initialize();
        _sensors = {
            :speed => 0,
            :avgSpeed => 0,
            :timer => 0,
            :slope => 0,
            :distance => 0.0f,
            :cadence  => 0,
            :heading  => 0.0f,
            :hr  => 0,
        };        
        _hrZones = UserProfile.getHeartRateZones(UserProfile.getCurrentSport());
        if (_hrZones.size() != 6 ) {
            _hrZones = [1,2,3,4,5,6];
        }        
        _hrPixel =  90 / (_hrZones[5]-_hrZones[0]).toFloat();
        // System.println(_hrPixel);

        _gradientData[11] = true; // Enable
        _paddings = getPaddings();
        if ( System.getDeviceSettings().distanceUnits == System.UNIT_METRIC) {
            _speedMod = 3.6;
            _units = ["km", "km/h", "C", "D"];
        } else {
            _speedMod = 2.23694;
            _units = ["mi", "mi/h", "F", "E"];
        }
        _imgVRainbowBar = Application.loadResource( Rez.Drawables.imageVRainbowBar ) as BitmapResource;
        _iconFont = Application.loadResource( Rez.Fonts.bikeDataIconFont ) as FontResource;
        _directionTexts = Application.loadResource( Rez.JsonData.directionText ) as Array;
    }


    /*
        Running on layout change or first time
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

        // label translate and expand
        if (View.findDrawableById("fieldLabel")) {
            (View.findDrawableById("fieldLabel") as Text).setText( 
                (WatchUi.loadResource(Rez.Strings.fieldLabel) as String) + " "+ _units[1] 
            );
        }
        if (View.findDrawableById("distanceLabel")) {
            (View.findDrawableById("distanceLabel") as Text).setText( 
                (WatchUi.loadResource(Rez.Strings.distanceLabel) as String) + " "+ _units[0] 
            );
        }
        if (View.findDrawableById("timerLabel")) {
            (View.findDrawableById("timerLabel") as Text).setText( 
                WatchUi.loadResource(Rez.Strings.timerLabel) as String
            );
        }     
        if (View.findDrawableById("avgSpLabel")) {
            (View.findDrawableById("avgSpLabel") as Text).setText( 
                (WatchUi.loadResource(Rez.Strings.avgSpeedLabel) as String) + " "+ _units[1]
            );
        }     
        if (View.findDrawableById("cadLabel")) {
            (View.findDrawableById("cadLabel") as Text).setText( 
                WatchUi.loadResource(Rez.Strings.cadenceLabel) as String
            );
        }
        if (View.findDrawableById("distanceIcon")) {
            (View.findDrawableById("distanceIcon") as Text).setText(_units[2]);
        }
        if (View.findDrawableById("speedIcon")) {
            (View.findDrawableById("speedIcon") as Text).setText(_units[3]);
        }

        // realign all text where need
        for (var f=0; f<_alignLabels.size(); f++) {
            var elem = findDrawableById(_alignLabels[f]) as Text;
            if (elem) {
                reAlign(elem);
            }
        }        
    }

    /* 
        datafield adatfrissítés kb mp-enként
    */
    function compute(info as Activity.Info) as Void {
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
    }


    /*
        callign every second if datafield visible
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

        if (_lastBackground != getBackgroundColor()) {
            (View.findDrawableById("Background") as Text).setColor(getBackgroundColor());

            for (var f=0; f<_alignLabels.size(); f++) {
                var elem = findDrawableById(_alignLabels[f]) as Text;
                if (elem) {
                    elem.setColor(labelColor);
                }
            }
            for (var f=0; f<_labelIcons.size(); f++) {
                var elem = findDrawableById(_labelIcons[f]) as Text;
                if (elem) {
                    elem.setColor(labelColor);
                }
            }

            for (var f=0; f<_labelDatas.size(); f++) {
                var elem = findDrawableById(_labelDatas[f]) as Text;
                if (elem) {
                    elem.setColor(numColor);
                }
            }
        }

        if ((_sensors[:speed] > 1) && (_sensors[:avgSpeed] > 0) ) {
            var deltaSpd = _sensors[:speed] - _sensors[:avgSpeed];
            if (deltaSpd >= 0) {
                numColor = Graphics.COLOR_DK_GREEN;
            } else if (deltaSpd > -1) {
                numColor = Graphics.COLOR_YELLOW;
            } else {
                numColor = Graphics.COLOR_ORANGE;
            }
        }
        var elem = findDrawableById("speed") as Text;
        if (elem) {
            elem.setColor(numColor);
        }

        if (_sensors[:speed] < 100) {
            setNumData("speed", _sensors[:speed].format("%0.1f"));
        } else {
            setNumData("speed", Math.round(_sensors[:speed]).format("%0.0f"));
        }
        if (_sensors[:avgSpeed] < 100) {
            setNumData("avgSpeed", _sensors[:avgSpeed].format("%0.1f"));
        } else {
            setNumData("avgSpeed", Math.round(_sensors[:avgSpeed]).format("%0.0f"));
        }
        
        setNumData("cadence", _sensors[:cadence].format("%0.0f"));
        setNumData("distance", showDistance(_sensors[:distance]));
        setNumData("timer", formatTime(_sensors[:timer]));

        if (_layout.equals("2x2")) {
            setNumData("slope", Math.round(_sensors[:slope]).format("%0.0f"));
        } else if (_layout.equals("2x1")) {
            setNumData("slope", _sensors[:slope].format("%0.1f"));
        }
        elem = findDrawableById("dirLabel") as Text;
        if (elem) {
            elem.setText(_sensors[:heading].format("%1d"));
        }

        elem = findDrawableById("compass") as Text;
        if (elem) {
            elem.setText(drawHeading(_sensors[:heading]).format("%1d"));
        }
        elem = findDrawableById("compLabel") as Text;
        if (elem) {
            elem.setText(_directionTexts[drawHeading(_sensors[:heading])]);
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

        // drawRuler(dc);
        // dc.drawBitmap( 50, 50, image );
        // dc.setColor(Graphics.COLOR_RED, getBackgroundColor());
        // dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_LT_GRAY);
        // dc.drawText(10, 30, numFont, "0", Graphics.TEXT_JUSTIFY_LEFT);
        // dc.setColor(Graphics.COLOR_DK_GREEN, Graphics.COLOR_LT_GRAY);
        // dc.drawText(120, 30, Graphics.FONT_SYSTEM_NUMBER_THAI_HOT, "123", Graphics.TEXT_JUSTIFY_LEFT);
        // dc.drawRectangle(10, 30, 80, 80);
    }

    /* 
        Font padding for real device
    */
    (:d)
    private function getPaddings() {
        System.println("Loading device font paddings");
        return WatchUi.loadResource(Rez.JsonData.DeviceFontPaddings);
    }

    /* 
        Font padding for simulator
    */
    (:s)
    private function getPaddings() {
        System.println("Loading simulator font paddings");
        return WatchUi.loadResource(Rez.JsonData.SimulatorFontPaddings);
    }
    
    /* 
        Edge/szimu font Y padding realign
    */
    function reAlign(item as Text) {            
            var _font = Graphics.FONT_SYSTEM_SMALL - 9; // SYSTEM fonts -9 !!!
            item.locY = item.locY - _paddings["EN"][_font];
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
    function setNumData(pId, pValue) {
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
        dc.fillRectangle(options[:x], options[:y], 10, Math.floor(_hrPixel * (_hrZones[5]-hr) ));
        _heartVisible ++;
        if (_heartVisible > 2) {
            dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(8, options[:y]-12+Math.floor(_hrPixel * (_hrZones[5]-hr) ), _iconFont, "H", Graphics.TEXT_JUSTIFY_LEFT);
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
