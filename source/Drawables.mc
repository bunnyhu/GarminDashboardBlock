import Toybox.Lang;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.UserProfile;

/*  *************************************************************
    Datafield background color drawable
    *************************************************************  */
class Background extends WatchUi.Drawable {
    hidden var mColor as ColorValue;

    function initialize() {
        var dictionary = {
            :identifier => "Background"
        };
        Drawable.initialize(dictionary);
        mColor = Graphics.COLOR_WHITE;
    }


    function setColor(color as ColorValue) as Void {
        mColor = color;
    }


    function draw(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_TRANSPARENT, mColor);
        dc.clear();
    }
}

/*  *************************************************************
    Combined compass and radar speed indicator
    *************************************************************   */
class RadarCompass extends WatchUi.Drawable {
    private var _fontCompIcon;      // compass icons font
    private var _fontSpeedNumber;   // wehicle speed number font
    private var _align;             // device related text align class
    private var _labelOffset = 0;   // align offset for label
    private var _directionTexts;    // compass directions

    var sensors = null;             // all sensor infomation from datafield
    var color = Graphics.COLOR_BLACK;       // texts color
    var background = Graphics.COLOR_WHITE;  // system background color
    var label = "";                 // label for my heading
    var baseCompassRadius = 20;
    var baseRadarRadius = 30;

    function initialize(options) {
        Drawable.initialize(options);
        _fontCompIcon = Application.loadResource( Rez.Fonts.compassIconFont ) as FontResource;
        _fontSpeedNumber = Application.loadResource( Rez.Fonts.smallNumFont ) as FontResource;
        _align = new Align();
        _labelOffset = _align.paddings[Graphics.FONT_MEDIUM];
        var n = WatchUi.loadResource( Rez.Strings.North ) as String;
        var w = WatchUi.loadResource( Rez.Strings.West ) as String;
        var e = WatchUi.loadResource( Rez.Strings.East ) as String;
        var s = WatchUi.loadResource( Rez.Strings.South ) as String;
        _directionTexts = [n, n+e, e, s+e, s, s+w, w, n+w, n];
        setOptions(options);
    }

    function draw(dc as Dc) as Void {
        if (sensors == null) {
            return;
        }
        if (sensors[:carSpeed]>0) {
            drawRadar(dc);      // radar speed mode
        } else {
            drawCompass(dc);    // compass mode
        }
    }

    /*  *************************************************************
    */
    function setOptions(options) {
        if ( options[:sensors]!=null ) { sensors = options[:sensors]; }
        if ( options[:color]!=null ) { color = options[:color]; }
        if ( options[:background]!=null ) { background = options[:background]; }
    }


    /*  *************************************************************
        Get compass 1/8 direction number, 0 - North CW
    */
    function getDirection(pHeadingValue) as Number {
        var r = Math.round(pHeadingValue / 45).toNumber();
        // if (r>7) { r = r-8; }
        return r % 8;
    }


    /*  *************************************************************
        The wind bearing in degrees. North = 0, East = 90, South = 180, West = 270
    */
    function getWindArc( pWind, pHeading ) as Dictionary {
        var _arcHalfDegree = 23;
        var _arcMargin = 12;
        // var _north = 360-pHeading;
        // var _wind = pWind - pHeading;
        // if (_wind < 0) {
        //     _wind += 360;
        // }
        var _wind = getDirection(pWind.toFloat()) - getDirection(pHeading.toFloat());
        if (_wind < 0) {
            _wind += 8;
        }

        var _arc = [90, 45, 0, 315, 270, 225, 180, 135, 90];
        var _center = _arc[ _wind ];

        var result = [_center-_arcHalfDegree-_arcMargin, _center+_arcHalfDegree+_arcMargin, _center-_arcHalfDegree, _center+_arcHalfDegree];
        for (var f=0; f<result.size(); f++) {
            if (result[f] < 0) {
                result[f] = 360 + result[f];
            } else if (result[f]>360) {
                result[f] = result[f] - 360;
            }
        }
        //  cut begin/end, wind begin/end
        return {:cb=>result[0], :ce=>result[1], :wb=>result[2], :we=>result[3]};
    }


    /*  *************************************************************
        Draw veicle speed radar warning
    */
    function drawRadar(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        dc.fillCircle(locX+17, locY+30, baseRadarRadius);
        if (sensors[:carDanger] == 1) {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_WHITE);
        } else if (sensors[:carDanger] == 2) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_WHITE);
        } else {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_WHITE);
        }
        dc.setPenWidth(8);
        dc.drawCircle(locX+17, locY+30, baseRadarRadius);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(locX + 17, locY+18, _fontSpeedNumber, sensors[:carSpeed].format("%u"), Graphics.TEXT_JUSTIFY_CENTER);
    }


    /*  *************************************************************
        Draw wind direction supported headind up moving north compass
    */
    function drawCompass(dc as Dc) as Void {
        var direction = sensors[:heading];

        if (sensors[:track] != null) {
            direction = sensors[:track];
        }

        label = _directionTexts[getDirection(direction)];

        // white bg stroke circle area
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        dc.fillCircle(locX+19, locY+19+baseCompassRadius, baseCompassRadius);
        if (background == Graphics.COLOR_WHITE) {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_WHITE);
        } else {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        }

        if (sensors[:windDir] != null) {
            // We have wind info, let show its direction on circle with arc
            var windArc = getWindArc(sensors[:windDir], direction);
            dc.setPenWidth(2);
            dc.drawArc(locX+19, locY+20+baseCompassRadius, baseCompassRadius, Graphics.ARC_CLOCKWISE , windArc[:cb], windArc[:ce]);
            dc.setPenWidth(10);
            dc.setColor(Graphics.COLOR_PURPLE, background);
            dc.drawArc(locX+19, locY+20+baseCompassRadius, baseCompassRadius, Graphics.ARC_COUNTER_CLOCKWISE , windArc[:wb], windArc[:we]);
        } else {
            // No wind, full circle
            dc.setPenWidth(2);
            dc.drawCircle(locX+19, locY+20+baseCompassRadius, baseCompassRadius);
        }
        // Direction label and compass arrow (from font)
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(locX + 19, locY-_labelOffset, Graphics.FONT_MEDIUM, label, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(locX+19, locY+baseCompassRadius, _fontCompIcon, getDirection(direction).format("%1u"), Graphics.TEXT_JUSTIFY_CENTER);
    }
}


/*  *************************************************************
    Heart rate zone bar with heart glyph
    *************************************************************   */
class HRZoneBar extends WatchUi.Drawable {
    var hr = null;
    var _hrZones as Array = [];         // heartRate Zones
    var bgColor = Graphics.COLOR_WHITE;

    private var _heartVisible as Number = 0;    // heart glyph flashing
    private var _hrPixel as Float = 3.00f;      // 1 HR pulse pixel
    private var _imgVRainbowBar;    // heart rate bar
    private var _iconFont;          // data icons

    function initialize(options) {
        Drawable.initialize(options);
        _hrZones = UserProfile.getHeartRateZones(UserProfile.getCurrentSport());
        if (_hrZones.size() != 6 ) {
            _hrZones = [1,2,3,4,5,6];
        }
        // _hrPixel =  90 / (_hrZones[5]-_hrZones[0]).toFloat();
        _hrPixel =  75 / (_hrZones[5]-_hrZones[2]).toFloat();
        _imgVRainbowBar = Application.loadResource( Rez.Drawables.imageVRainbowBar ) as BitmapResource;
        _iconFont = Application.loadResource( Rez.Fonts.bikeDataIconFont ) as FontResource;
        setOptions(options);
    }


    /*  *************************************************************
    */
    function setOptions( options ) {
        if (options[:hr] != null) { hr = options[:hr]; }
        if (options[:background] != null) { bgColor = options[:background]; }
    }


    /*  *************************************************************
    */
    function getZone(_hr) as Number {
        for (var f=0; f<=4; f++) {
            if ((_hr>=_hrZones[f]) && (_hr<=_hrZones[f+1])) {
                return f;
            }
        }
        return 5;
    }

    /*  *************************************************************
        Garmin min: 65 max: 181
        91-108, 109-126, 127-144, 145-162, 163-180,
        91,108,126,144,162,180
    */
    function draw(dc as Dc) as Void {
        if ((hr == null) || (hr<25)) {
            return;
        }

        var _hr = hr;
        if (_hr > _hrZones[5]) {
            _hr = _hrZones[5];
        } else if (_hr < _hrZones[2]) {
            _hr = _hrZones[2];
        }

        var ZoneClear = [2,2,2,1,0,0];
        dc.setColor(bgColor, Graphics.COLOR_TRANSPARENT);
        dc.drawBitmap(locX, locY+23, _imgVRainbowBar);
        // dc.fillRectangle(locX, locY+23, 15, Math.floor(_hrPixel * (_hrZones[5] - hr) ));
        dc.fillRectangle(locX, locY+23, 15, Math.floor(ZoneClear[getZone(_hr)]*25));

        var y = Math.floor(_hrPixel * (_hrZones[5] - _hr) );
        if (y>70) {
            y = 70;
        }
        if (bgColor == Graphics.COLOR_BLACK) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
        }
        // dc.fillRectangle(locX+10, locY+21+y, 15, 4);
        dc.fillPolygon([[locX+13,locY+23+y], [locX+23,locY+18+y], [locX+23,locY+28+y]]);

        // _heartVisible ++;   // blinking the heart
        // if (_heartVisible > 2) {
        //     var y = locY - 8 + Math.floor(_hrPixel * (_hrZones[5] - hr) );
        //     if (y >= 0) {
        //         dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        //         dc.drawText(locX + 2, y, _iconFont, "H", Graphics.TEXT_JUSTIFY_LEFT);  // Heart glyph
        //     }
        // }
        // if (_heartVisible > 4) {
        //     _heartVisible = 0;
        // }
    }
}