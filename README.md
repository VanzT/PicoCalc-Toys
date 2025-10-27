# PicoCalc-Toys

With a generous helping of AI, I present:

alien.bas - weak attempt at the motion tracker display from Alien

bio.bas - remember the Biorhythm craze in the mid to late 70's?   I do,
because I'm old. This takes the snake oil psudoscience into the new 
millenium much to the delight of nobody.  Self-explanatory (or just 
Google biorhythm and "learn" how silly people were in the 70's).
Or just leave it on the screen and tell people you are hacking the Gibson.

bkgmn.bas - playable "pass the device" Backgammon game

bkgmn.txt - notes on Backgammon game mechanics

bkgmn-w.bas - wifi enabled backgammon.  Needs OPTION WIFI "ssid","password" 
and OPTION UDP SERVER PORT 6000
set on both devices before starting

chat.bas - simple chat used to test communication between devices
see bkgmn-w.bas notes above for same OPTIONs that must be set

bsg1.bas - Battlestar Galactica original series.  Attempt at tactical radar display
Could be worse.

ghost.bas - shove a wire in GPIO28 and detect 'ghosts'!  Just a dumb program that 
reads from analog input 28 that isn't grounded.  Meaning, it is reading ambient 
electrical energy around the device.  Press 1 or 2 to switch between different
methods of recording the data.

matrix.bas - The Matrix style animation.  I'm quite pleased with the random white
flashes at the head of some drops

muthur.bas - very lame Alien-ish animation.  Terrible, is a kind description

nostromo.bas - farily proud of this one.  Another Alien inspired animation

othello.bas - what it sounds like.  Two player wifi only.

rgb.bas - I put an 8 RGB LED strip inside my pico and this makes neat effects.
Totally stolen from https://steinlaus.de/rgb-led-stick-fuer-den-picocalc/ and 
they deserve all credit.

sysinfo.bas - I just wanted to know my IP address without a lot of typing.  So 
it is with a few extra things to make it seem more fancy than it really is.

xfer.bas - a file transfer program to copy files between 2 PicoCalc devices.
It uses UDP, so you know it's rock solid!  /s  Actually, it works pretty
well for what it is.
