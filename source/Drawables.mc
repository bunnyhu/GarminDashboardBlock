import Toybox.Lang;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.WatchUi;

/*
    Datafield background color drawable
    calling from layouts.xml
*/
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

/*
    Combined compass and radar speed indicator    
*/
class RadarCompass extends WatchUi.Drawable {  
    private var _fontCompIcon;
    private var _fontSpeedNumber;
    private var _align;
    private var _labelOffset = 0;
    private var _directionTexts;    // compass directions

    var sensors = null;
    var color = Graphics.COLOR_BLACK;
    var background = Graphics.COLOR_WHITE;
    var label = "";

    function initialize(options) {
        Drawable.initialize(options);
        _fontCompIcon = Application.loadResource( Rez.Fonts.compassIconFont ) as FontResource;
        _fontSpeedNumber = Application.loadResource( Rez.Fonts.smallNumFont ) as FontResource;
        _align = new Align();
        _labelOffset = _align.paddings[Graphics.FONT_MEDIUM];
        var n = WatchUi.loadResource( Rez.Strings.N ) as String;
        var w = WatchUi.loadResource( Rez.Strings.W ) as String;
        var e = WatchUi.loadResource( Rez.Strings.E ) as String;
        var s = WatchUi.loadResource( Rez.Strings.S ) as String;
        _directionTexts = [n, n+e, e, s+e, s, s+w, w, n+w, n];
    }

    function setOptions(options) {
        if (options[:sensors]!=null) { sensors = options[:sensors]; }
        if (options[:color]!=null) { color = options[:color]; }
        if (options[:background]!=null) { background = options[:background]; }
    }

    /* 
        Get compass 45° direction number, 0 - North CW
    */
    function getDirection(pHeadingValue) as Number {
        return Math.round(pHeadingValue / 45).toNumber();
    }

    /*
        The wind bearing in degrees. North = 0, East = 90, South = 180, West = 270
    */
    function getWindArc(pWind) as Array {
        return [];
    }

    /*
        Draw the component
    */
    function draw(dc as Dc) as Void {
        label = _directionTexts[getDirection(sensors[:heading])];

        if (sensors[:carSpeed]>0) {
            // radar speed indicator mode

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
            dc.fillCircle(locX+19, locY+20, 30);
            if (sensors[:carSpeed] < 45) {
                dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_WHITE);    
            } else if (sensors[:carSpeed] < 60) {
                dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_WHITE);    
            } else {
                dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_WHITE);
            }
            dc.setPenWidth(8);
            dc.drawCircle(locX+19, locY+20, 30);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.drawText(locX + 19, locY+8, _fontSpeedNumber, sensors[:carSpeed].format("%u"), Graphics.TEXT_JUSTIFY_CENTER);

        } else {
            // compass mode

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
            dc.fillCircle(locX+19, locY+19+15, 16);
            if (background == Graphics.COLOR_WHITE) {
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_WHITE);
            } else {
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
            }
            // sensors[:windDir] = 100;
            // sensors[:windSpeed] = 1.03f;
            if ((sensors[:windDir] != null) && sensors[:windSpeed] != null) {
                var windArc = getWindArc(getDirection(sensors[:windDir]));

                dc.setPenWidth(2);
                dc.drawArc(locX+19, locY+19+15, 16, Graphics.ARC_CLOCKWISE , 345, 60);
                dc.setPenWidth(6);
                dc.setColor(Graphics.COLOR_PURPLE, background);
                dc.drawArc(locX+19, locY+19+15, 16, Graphics.ARC_COUNTER_CLOCKWISE , 0, 45);
            } else {
                dc.setPenWidth(2);
                dc.drawCircle(locX+19, locY+19+15, 16);
            }
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawText(locX + 19, locY-_labelOffset, Graphics.FONT_MEDIUM, label, Graphics.TEXT_JUSTIFY_CENTER);
            // dc.drawBitmap(locX, locY+15, _imageCompCircle);
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(locX+19, locY+15, _fontCompIcon, getDirection(sensors[:heading]).format("%1u"), Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}