import Toybox.System;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Graphics;

/*
    Compensate the simulator and the device font padding difference

    change excludeAnnotations in monkey.jungle s for device, d for simulator
*/

class Align {
    /* 
        Font padding for real device
    */
    public var paddings;
    public var font = Graphics.FONT_SMALL; // SYSTEM fonts -9 !!!

    function initialize() {
        paddings = getPaddings();
    }

    (:d)
    private function getPaddings() {
        // System.println("Loading device font paddings");
        return WatchUi.loadResource(Rez.JsonData.DeviceFontPaddings);
    }

    /* 
        Font padding for simulator
    */
    (:s)
    private function getPaddings() {
        // System.println("Loading simulator font paddings");
        return WatchUi.loadResource(Rez.JsonData.SimulatorFontPaddings);
    }
    
    /* 
        Device/simu font Y padding realign
    */
    function reAlign(item as Text) {                        
            item.locY = item.locY - paddings[font];
    }

}