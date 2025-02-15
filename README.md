# Bunny's combined datafield
![GitHub Downloads (all assets, latest release)](https://img.shields.io/github/downloads/bunnyhu/garminCombiDF/latest/total)
![Github stable release](https://img.shields.io/packagist/v/bunnyhu/garminCombiDF?label=Stable)

*Combined datafield for Garmin Edge Explore 2*

This is a garmin Edge cycling computer data field. Its purpose is to display more data in one place, overcoming the limitations of the factory one-block-one-data split. I didn't want a full screen solution though, because I use other ConnectIQ data fields already from other developers (like smart bike lights), which unfortunately can't be inserted into a custom screen.

My data field displays 3 sizes of slightly different data, adapted to my own needs.

## 2x2 size
For me, this is the format that displayed on my main training screen. It contains:
* current speed with colour support (see below)
* average speed 
* current pedal cadence
* percentage of climb (calculated from the measured altitude data)
* heart rate in a zones associated colour column

**colour marking of the current speed** Green if the current speed is the same or faster than the average speed. Yellow if it is slower but not more than 1km/h or 1Mi/h, and orange if it is even slower than that.

## 2x1 size
I use this under the navigation map view, so I prefer to display the main actual values there. In addition to the colour-supported speed (described above), the climb percentage, distance travelled, active time, and pedal cadence are displayed.

## 1x1 size
Only 3 basic data: colour-supported speed, distance travelled and active time.

## Install from Garmin store
https://apps.garmin.com/

## Manual install
* Download the latest version from Github Releases section and unpack it. https://github.com/bunnyhu/garminCombiDF/releases
* Connect your garmin Edge to your computer with a USB cable, if you did it right a new drive will appear. 
* Copy the .prg file to the /app/media directory on this new drive. 
* Disconnect the Garmin device and you will find this in the IQ fields when editing the screen. Depending on the block size you assign to the three layout will be automatically selected.

## Project home
https://github.com/bunnyhu/garminCombiDF

## History
v1.0 

> [!NOTE]
> *You may ask the legitimate question, why is it only compatible with Edge Explore 2? Well, Garmin gives the developers a pretty good simulator that is supposed to know all your devices, but the accuracy of the display is quite poor. The size of the letters and numbers are different, their positioning is not the same so designing a face calculated to such a pixel for a device I don't physically own is near impossible. Since I only have Explore 2, I could set up exactly what goes where and how it appears.*