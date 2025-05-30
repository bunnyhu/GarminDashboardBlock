# Bunny's dashboard block
![GitHub Release](https://img.shields.io/github/v/release/bunnyhu/GarminDashboardBlock)
![GitHub Release Date](https://img.shields.io/github/release-date/bunnyhu/GarminDashboardBlock)

**Dashboard block for Garmin Edge**

This is a garmin Edge cycling computer data field. Its purpose is to display more data in one place, overcoming the limitations of the factory one-block-one-data split. I didn't want a full screen solution though, because I use other ConnectIQ data fields already from other developers (like smart bike lights), which unfortunately can't be inserted into a custom screen.

My data field displays 3 sizes of slightly different data, adapted to my own needs. The 2x2 big size is my main choice, the 2x1 line I use under the map, and the 1x1 is just why not make it.

## Supported devices

Edge Explore 2 , Edge 1040/1040 solar

## Adapted data

| Data | Comment | 2x2 | 2x1 | 1x1 |
| --- | --- | --- | --- | --- |
| current speed | with color support (see below) | X | X | X |
| average speed | | X | | |
| current cadence | | X | X | |
| climb % | negative if slope | X | X | |
| heart rate & zones | colorized bar | X | | |
| compass | (see below) | X | | |
| wind direction | included into compass | X | | |
| radar speed | with color support | X | | |
| distance travelled | | | X | X |
| moving time | | | X | X |

### Enhanced data fields

**current speed** Its color marked: Green if the current speed is the same or faster than the average speed. Yellow if it is slower but not more than 1km/h or 1Mi/h, and orange if it is even slower than that. Also there is a triangled decimal dot, that show our speed is faster or slower than average (for color blinds or just simple a second sign).

**climb %** It is calculated from measured data, if slope the number is negative.

**heart rate zones** The highest 3 color coded zone bar. The zone limits from your Garmin HR zones. On the top, there is the actual HR with number.

**compass , wind , radar speed** Those data using the same place and changing dinamic.
* Default is the compass. If there is weather informations the wind direction also appers on the circle around the compass with purple section. If there is fresh wind data - we using is, anyway if we are offline and  it is more than one hour old, it start use the hourly forecast. All information from official garmin weather data, the accurate of information is depend of that.
* If we have radar and wehicle(s) arriving, it show the fastest one's speed. If the speed moderate the number in a green circle, the ok speed means yellow and the fast one with red circle. After the wehicle pass, we turn back to compass.

## Install from Garmin store
https://apps.garmin.com/en-US/apps/bf65ec33-0655-485c-83eb-bdecebcd23d4

## Manual install
* Download the latest version from Github Releases section and unpack it. https://github.com/bunnyhu/GarminDashboardBlock/releases
* Connect your garmin Edge to the PC with a USB cable, if you did it right a new drive will appear. 
* Copy the downloaded .prg file to the "\Internal Storage\Garmin\Apps\Media" folder on this new drive. 
* Disconnect the Garmin device and you will find this in the IQ fields when editing the screen. Depending on the block size you assign to the three layout will be automatically selected.

## Project home
https://github.com/bunnyhu/GarminDashboardBlock

## History
v1.0.4    Initial release.  2025. april 3.