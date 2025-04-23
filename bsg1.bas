' BSG Tactical Display – MMBasic on PicoCalc
Const CX = 160, CY = 160

' Define colors
BGColor      = RGB(0, 80, 0)    ' background
DimColor     = RGB(0,100, 0)    ' dim overlay (rings & crosshairs)
CapsuleColor = RGB(0,150, 0)    ' slightly brighter capsule dots
BrightColor  = RGB(0,255, 0)    ' bright overlay (ships, text, enemies)
WhiteColor   = RGB(255,255,255)  ' white for text morph

' Clear screen and set original font
Color BGColor: CLS
Font 1

' --- Draw rings with dim color ---
Color DimColor
Circle CX, CY, 40: Pause 130   ' 1st ring
Circle CX, CY, 80: Pause 300   ' 2nd ring

' --- Draw capsule shape ---
' Vertical sides
Color DimColor
Line CX - 80, CY - 20, CX - 80, CY + 20
Line CX + 80, CY - 20, CX + 80, CY + 20

' Top semicircle (denser dots & slightly brighter)
Color CapsuleColor
For Ang = 0 To 180 Step 5
    Rad = Ang * 3.14159265 / 180
    X = INT(CX + 80 * COS(Rad))
    Y = INT(CY + 20 + 80 * SIN(Rad))
    LINE X, Y, X, Y: Pause 5
Next Ang

' Bottom semicircle
For Ang = 180 To 360 Step 5
    Rad = Ang * 3.14159265 / 180
    X = INT(CX + 80 * COS(Rad))
    Y = INT(CY - 20 + 80 * SIN(Rad))
    LINE X, Y, X, Y: Pause 5
Next Ang
Pause 30

' --- Draw additional rings ---
Color DimColor
Circle CX, CY, 100: Pause 130
Circle CX, CY, 105: Pause 130
Circle CX, CY, 130: Pause 130
Circle CX, CY, 160: Pause 300

' --- Draw crosshairs & diagonals ---
Color DimColor
Line CX,   0,  CX, 319: Pause 200
Line   0,  CY, 319, CY: Pause 200
Line   0,   0, 319, 319: Pause 200
Line 319,   0,   0, 319: Pause 1000

' --- Draw enemies & fighters ---
Color BrightColor
' Subroutine: Draw enemy marker with trail
Sub Enemy(x, y, trail)
    ' Asterisk marker
    LINE x-5, y,   x+5, y
    LINE x,   y-5, x,   y+5
    LINE x-4, y-4, x+4, y+4
    LINE x-4, y+4, x+4, y-4
    ' Trail segments to the right
    For t = 1 To trail
        LINE x+5 + (t-1)*5, y, x+5 + t*5, y
    Next t
    pause 300
End Sub

' Draw enemy contacts with varying trail lengths
Enemy CX + 55, CY - 40, 3
Enemy CX + 45, CY + 65, 2
Enemy CX + 85, CY + 15, 4

' Subroutine: Draw friendly fighter with variable trail
Sub Fighter(x, y, trail)
    ' Triangle body
    LINE x-5, y-5, x+5, y
    LINE x+5, y,   x-5, y+5
    LINE x-5, y+5, x-5, y-5
    ' Trail segments to the left
    For t = 1 To trail
        LINE x-5 - t*10, y, x - t*10, y
    Next t
End Sub

' Draw friendly squadrons
Fighter 60,  60, 2: Pause 1000
Fighter 80,  80, 3: Pause 150
Fighter 100,100,1: Pause 500
Fighter 60, 200,4: Pause 10
Fighter 80, 220,2: Pause 300
Fighter 100,240,3: Pause 120
Fighter  80,260,1: Pause 1000

' --- Letter-by-letter "CONDITION RED" with white morph ---
msg$ = "CONDITION RED"
stepX = 8                      ' original spacing
startX = INT(CX - (LEN(msg$)*stepX)/2)
yPos = CY - 20
For i = 1 To LEN(msg$)
    ch$ = MID$(msg$, i, 1)
    xPos = startX + (i-1)*stepX
    ' draw in white then morph to green
    Color WhiteColor: Text xPos, yPos, ch$: Pause 70
    Color BrightColor: Text xPos, yPos, ch$: Pause 20
Next i

' --- Blink "CONDITION RED" 3 times ---
For b = 1 To 3
    Color BGColor: Text startX, yPos, msg$
    Pause 200
    Color BrightColor: Text startX, yPos, msg$
    Pause 200
Next b

' --- Wait for key then exit ---
Do: k$ = INKEY$: Loop Until LEN(k$)
END
