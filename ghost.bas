' Real-time scrolling graph of calibrated analog input at 4 Hz (every 0.25 s)
CLS
SETPIN GP28, AIN  ' configure GP28 as analog input

'--- Calibration (5 s at 100 Hz) ---
PRINT SPACE$(7);"Calibrating... Please wait"
sum=0:lowest=1:highest=0
start=TIMER
FOR i=1 TO 500
  DO:LOOP UNTIL TIMER>=start+(i-1)*10
  v=PIN(GP28)
  sum=sum+v
  IF v<lowest THEN lowest=v
  IF v>highest THEN highest=v
NEXT
avg=sum/500
CLS

'--- Graph parameters ---
leftMargin=30:topMargin=10:bottomMargin=280:maxPts=240:graphHeight=bottomMargin-topMargin:graphWidth=319-leftMargin

COLOR RGB(255,255,255)
' vertical axis
LINE leftMargin,topMargin,leftMargin,bottomMargin

' y-axis labels and major ticks
FOR y=0 TO 100 STEP 10
  ypix=topMargin+INT((100-y)*graphHeight/100)
  TEXT 2,ypix-4,STR$(y)
  LINE leftMargin-4,ypix,leftMargin,ypix
NEXT
' minor y-axis ticks
FOR y=5 TO 95 STEP 10
  ypix=topMargin+INT((100-y)*graphHeight/100)
  LINE leftMargin-2,ypix,leftMargin,ypix
NEXT

' horizontal axis
LINE leftMargin,bottomMargin,leftMargin+graphWidth,bottomMargin

' minute and quarter-minute ticks and labels
FOR m=0 TO 4
  xpix=leftMargin+INT(m*graphWidth/4)
  LINE xpix,bottomMargin,xpix,bottomMargin+5
  IF m>0 AND m<4 THEN TEXT xpix-5,bottomMargin+8,STR$(m)
  IF m<4 THEN
    FOR q=1 TO 3
      xsub=leftMargin+INT((m*60+q*15)*graphWidth/240)
      LINE xsub,bottomMargin,xsub,bottomMargin+3
    NEXT
  ENDIF
NEXT

' label "Minutes" centered under axis
TEXT leftMargin + graphWidth \ 2 - 20, bottomMargin+20, "Minutes"

'--- Buffer & smoothing setup ---
rollScaled=avg
mode=1  ' 1 = smoothed (default), 2 = raw

'--- 4-minute sweep real-time loop ---
period=INT(240000/graphWidth)
next_time=TIMER
DO
  ' wait for next interval
  DO:LOOP UNTIL TIMER>=next_time
  next_time=next_time+period

  ' read and scale
  v=PIN(GP28)
  IF v<=avg THEN
    scaled=INT((v-lowest)*50/(avg-lowest))
  ELSE
    scaled=50+INT((v-avg)*50/(highest-avg))
  ENDIF
  IF scaled<0 THEN scaled=0
  IF scaled>100 THEN scaled=100

  ' check key press to switch modes
  k$=INKEY$
  IF k$="1" THEN mode=1
  IF k$="2" THEN mode=2

  ' select plot value based on mode
  IF mode=1 THEN
    rollScaled=(rollScaled*9+scaled)\10
    plotVal=rollScaled
  ELSE
    plotVal=scaled
  ENDIF

  ' scroll plot area
  BLIT leftMargin+1,topMargin,leftMargin+2,topMargin,graphWidth-1,graphHeight

  ' clear newly exposed column
  COLOR RGB(0,0,0)
  LINE leftMargin+1,topMargin,leftMargin+1,bottomMargin-1

  ' plot newest point
  COLOR RGB(0,255,0)
  ypix=topMargin+INT((100-plotVal)*graphHeight/100)
  PIXEL leftMargin+1,ypix
LOOP
