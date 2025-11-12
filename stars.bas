' Starfield like win95 on PicoCalc
w=MM.HRES
h=MM.VRES
framebuffer create
framebuffer write f
cx=w/2
cy=h/2
n=100+asc("*") 'The Answer
speed=.2
dim x(n),y(n),z(n)

' --- LED setup ---
CONST LEDCOUNT = 8
DIM ledBuf%(LEDCOUNT-1)
DIM ledFade%(LEDCOUNT-1)
DIM ledMax%(LEDCOUNT-1)
CONST FADE_STEP_MIN = 15
CONST FADE_STEP_MAX = 30
DIM ledEnabled     ' 0=off, 1=on
ledEnabled = 0     ' LEDs start off

for i=0 to n
 one
next i

do
 k$=inkey$

 ' --- Key handling ---
 IF k$ = "q" THEN
     ' Clear LEDs
     FOR i=0 TO LEDCOUNT-1
         ledBuf%(i) = 0
         ledFade%(i) = 0
     NEXT
     BITBANG WS2812 O, GP28, LEDCOUNT, ledBuf%()
     
     ' Run menu.bas
     RUN "B:menu.bas"
 END IF

 IF k$ = "l" THEN
     ledEnabled = 1 - ledEnabled
     ' clear LEDs immediately if turning off
     IF ledEnabled = 0 THEN
         FOR i=0 TO LEDCOUNT-1
             ledBuf%(i) = 0
             ledFade%(i) = 0
         NEXT
         BITBANG WS2812 O, GP28, LEDCOUNT, ledBuf%()
     END IF
 END IF

 IF k$=chr$(128) THEN speed=speed+.1
 IF k$=chr$(129) THEN speed=speed-.1

 cls

 ' --- Update starfield ---
 for i=0 to n
  z(i)=z(i)-speed
  if z(i)<=.1 then one
  sx=int(cx+x(i)/z(i))
  sy=int(cy+y(i)/z(i))
  if sx<0 or sx>=w or sy<0 then continue for
  if sy>=h then continue for
  c=rgb(255,255,255)
  s=.5+int((10-z(i))*.12)
  circle sx,sy,s,,,c,c
 next i

 ' --- Natural LED twinkle ---
 IF ledEnabled THEN
     FOR i=0 TO LEDCOUNT-1
         IF ledFade%(i)=0 THEN
             IF RND < 0.015 THEN
                 ledMax%(i) = 200 + INT(RND*55)   ' random peak brightness 200-255
                 ledFade%(i) = ledMax%(i)
             END IF
         END IF
     NEXT

     ' --- Fade LEDs ---
     FOR i=0 TO LEDCOUNT-1
         IF ledFade%(i) > 0 THEN
             ledBuf%(i) = ledFade%(i)*&H10101  ' white
             ledFade%(i) = ledFade%(i) - (FADE_STEP_MIN + INT(RND*(FADE_STEP_MAX-FADE_STEP_MIN)))
             IF ledFade%(i)<0 THEN ledFade%(i)=0
         ELSE
             ledBuf%(i) = 0
         END IF
     NEXT

     ' --- Send LED buffer ---
     BITBANG WS2812 O, GP28, LEDCOUNT, ledBuf%()
 END IF

 framebuffer copy f,n
loop

sub one
 x(i)=(rnd*2-1)*w
 y(i)=(rnd*2-1)*h
 z(i)=rnd*9+1
end sub
