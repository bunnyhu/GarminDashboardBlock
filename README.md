# Bunny's extended speed datafield
![GitHub Downloads (all assets, latest release)](https://img.shields.io/github/downloads/bunnyhu/BunnySpeedField/latest/total)
![Github stable release](https://img.shields.io/packagist/v/bunnyhu/BunnySpeedField?label=Stable)

*Extended speed datafield for Garmin Edge Explore 2*

This is a garmin Edge cycling computer data field. Its purpose is to display more data in one place, overcoming the limitations of the factory one-block-one-data split. I didn't want a full screen solution though, because I use other ConnectIQ data fields already from other developers (like smart bike lights), which unfortunately can't be inserted into a custom screen.

My data field displays 3 sizes of slightly different data, adapted to my own needs. The 2x2 big size is my main choice, the 2x1 line I use under the map, and the 1x1 is just why not make it.

## Adapted data

| Data | Comment | 2x2 | 2x1 | 1x1 |
| --- | --- | --- | --- | --- |
| current speed | with color support (see below) | X | X | X |
| average speed | | X | | |
| current cadence | | X | X | |
| climb % | negative if slope | X | X | |
| heart rate zones | colorized bar | X | | |
| compass | (see below) | X | | |
| wind direction | included into compass | X | | |
| radar speed | with color support | X | | |
| distance travelled | | | X | X |
| moving time | | | X | X |

### Enhanced data fields

**current speed** Its color marked: Green if the current speed is the same or faster than the average speed. Yellow if it is slower but not more than 1km/h or 1Mi/h, and orange if it is even slower than that. Also there is a triangled decimal dot, that show our speed is faster or slower than average (for color blinds or just simple a second sign).

**climb %** It is calculated from measured data, if slope the number is negative.

**heart rate zones** Color coded (same colors like Connect) zone bar.

**compass , wind , radar speed** Those data using the same place and changing dinamic.
* Default is the compass. If there is weather informations the wind direction also appers on the circle around the compass. If there is fresh wind data - we using is, anyway if we are offline and  it is more than one hour old, it start use the hourly forecast.
* If we have radar and wehicle(s) arriving, it show the fastest one's speed. If the speed moderate the number in a green circle, the ok speed means yellow and the fast one with red circle. After the wehicle pass, we turn back to compass.

## Install from Garmin store
https://apps.garmin.com/

## Manual install
* Download the latest version from Github Releases section and unpack it. https://github.com/bunnyhu/BunnySpeedField/releases
* Connect your garmin Edge to the PC with a USB cable, if you did it right a new drive will appear. 
* Copy the downloaded .prg file to the "\Internal Storage\Garmin\Apps\Media" folder on this new drive. 
* Disconnect the Garmin device and you will find this in the IQ fields when editing the screen. Depending on the block size you assign to the three layout will be automatically selected.

## Project home
https://github.com/bunnyhu/BunnySpeedField

## History
v1.0    Initial release.  2025. feb. 23.

## Q&A
### Why this data and not ...
First I want to put together the most important informations, like timer, distance, etc. Then I realize the refreshing timer have a little bit shifting between the factory datafield and the custom made. Not much, but that delay is really annoying when one data change a bit later than the others. This is why I choice some important (for me!) but not every second changing data. Also because they are not "life saver" important informations, I can use smaller number or not precise presentations and put more data to the same place.
### Why those devices, I need it for ...
Well, Garmin gives the developers a pretty good simulator that is supposed to know all your devices, but the accuracy of the display is quite poor. The size of the letters and numbers are different, their positioning is not the same, so designing a face calculated to such a pixel for a device I don't physically own is near impossible. Since I only have Explore 2 and my friend have 1040 - I could set up exactly what goes where and how it appears only those devices. 
### I really like this on my device / my language
No problem, feel free to redesign for your device, the source code is avaiable on GitHub and no need programming (but the VSC).
Check the *resources* folder and folders start with *resources-* what you need to tailoring. Make the folder that you need and modify the xml files then compile it. 
* https://developer.garmin.com/connect-iq/connect-iq-basics/getting-started/
* https://developer.garmin.com/connect-iq/reference-guides/devices-reference/
* https://developer.garmin.com/connect-iq/core-topics/resources/
