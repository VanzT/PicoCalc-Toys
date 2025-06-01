'-------------------------------------------------------------------
' WS2812 Light Show (MMBasic for PicoMite)
'
' This code drives an 8-LED WS2812 strip on GP28. All color-values
' are packed in GRB order so that “red” actually shows red, etc.
'
' Menu options:
'   1 = Larson Scanner (pure red)
'   2 = Static White   (all LEDs white)
'   3 = Static Orange  (all LEDs orange)
'   4 = Random Colors
'   5 = Binary Count (dim green for “1” bits)
'   6 = Ocean Effect (wave of blue)
'   7 = Static Dimmable Red (example)
'   8 = Communication Effect (fade a random color on a 2-pixel “pair”)
'   9 = Clear all LEDs
'   0 = Exit, turn all off
'-------------------------------------------------------------------

Const LEDCOUNT = 8

'-------------------------------------------------------------------
' GLOBAL DIMENSIONS (everything declared exactly once here)
'-------------------------------------------------------------------

Dim b%(LEDCOUNT - 1)        ' Buffer for 8 LEDs as 24-bit GRB words
Dim wave%(LEDCOUNT - 1)     ' OceanEffect helper
Dim dirOcean%(LEDCOUNT - 1)
Dim temp%(LEDCOUNT - 1)

Dim i%, j%                  ' general loop indices
Dim position%, direction%, speed%
Dim k$                      ' menu key
Dim greenOld%, redOld%, blueOld%, scaledOld%
Dim brightness%, brightnessStep%
Dim oldG%, oldR%, oldB%, newR%
Dim value%, bit%, mask%, ledIdx%
Dim dimG%
Dim waveFld%, brightnessFld%
Dim rC%, gC%, bC%
Dim mapG%, mapR%, mapB%
Dim r%, g%, bVal%, mixColor%
Dim ledPair%, offset%, waveVal
Dim redCh%, greenCh%, blueCh%
Dim red%, mode%
Dim rAdj%, gAdj%, bAdj%     ' used by StaticRGB
Dim ans$                    ' temporary string if needed
Dim response%               ' used by any Input routines

'-------------------------------------------------------------------
' INITIAL SETUP
'-------------------------------------------------------------------
position%  = 0      ' starting head position for Larson
direction% = 1      ' initial direction
speed%     = 100    ' default pause (ms) for moving effects
mode%      = 0

' Initialize strip off
For i% = 0 To LEDCOUNT - 1
  b%(i%) = 0
Next i%

'-------------------------------------------------------------------
' MAIN MENU LOOP
'-------------------------------------------------------------------
Do
  Cls
  Print "WS2812 Light Show Menu"
  Print
  Print "1: Larson Scanner"
  Print "2: Static White (all white)"
  Print "3: Static Orange (all orange)"
  Print "4: Random Colors"
  Print "5: Binary Count"
  Print "6: Ocean Effect"
  Print "7: Static Dimmable Red"
  Print "8: Communication Effect"
  Print "9: Clear LEDs"
  Print "0: Exit"
  Print
  Print "Make a selection: "

  ' Wait until a key is pressed
  k$ = ""
  Do
    k$ = Inkey$
  Loop Until k$ <> ""

  Select Case k$
    Case "1"
      LarsonScanner
    Case "2"
      StaticRGB 255, 255, 255
    Case "3"
      StaticRGB 255, 127, 0
    Case "4"
      RandomColors
    Case "5"
      BinaryCount
    Case "6"
      OceanEffect
    Case "7"
      StaticRGB 255, 0, 0
    Case "8"
      CommunicationEffect
    Case "9"
      ClearAll
    Case "0"
      ClearAll
      Exit Do
    Case Else
      Print "Invalid input!"
      Pause 800
  End Select

Loop

' Final clear before exiting
ClearAll

'-------------------------------------------------------------------
' SUBROUTINES (no local Dims for any of the globals above)
'-------------------------------------------------------------------

'------------------------------------------------------------
' PROCEDURE: ClearAll
' Turns off all LEDs immediately
Sub ClearAll
  For j% = 0 To LEDCOUNT - 1
    b%(j%) = 0
  Next j%
  Bitbang ws2812 o, GP28, LEDCOUNT, b%()
End Sub

'------------------------------------------------------------
' PROCEDURE: StaticRGB
' Sets every LED to the same static color, with brightness control
'   baseR, baseG, baseB range 0…255
'------------------------------------------------------------
' PROCEDURE: StaticRGB  (RGB-packed for your strip)
' Sets every LED to the same static color, with brightness control
'   baseR, baseG, baseB each 0…255
Sub StaticRGB(baseR%, baseG%, baseB%)
  brightness% = 255

  Do
    rAdj% = (baseR% * brightness%) \ 255
    gAdj% = (baseG% * brightness%) \ 255
    bAdj% = (baseB% * brightness%) \ 255

    For i% = 0 To LEDCOUNT - 1
      b%(i%) = (rAdj% * &H10000) + (gAdj% * &H100) + bAdj%
    Next i%
    Bitbang ws2812 o, GP28, LEDCOUNT, b%()

    k$ = Inkey$
    if k$ <> "" then
    Select Case k$
      Case Chr$(128)   ' “+” key on some PicoCalc keymaps
        brightness% = Min(brightness% + 15, 255)
      Case Chr$(129)   ' “–” key on some PicoCalc keymaps
        brightness% = Max(brightness% - 15,   0)
      case else
        exit sub
      End Select
    End If

    Pause 100
  Loop
End Sub


'------------------------------------------------------------
' PROCEDURE: RandomColors
' Each LED randomly toggles between 0 or 255 on R, G, B
Sub RandomColors
  Do
    For i% = 0 To LEDCOUNT - 1
      redCh%   = 255 * (Rnd > 0.5)
      greenCh% = 255 * (Rnd > 0.5)
      blueCh%  = 255 * (Rnd > 0.5)
      b%(i%) = (greenCh% * &H10000) + (redCh% * &H100) + blueCh%
    Next i%
    Bitbang ws2812 o, GP28, LEDCOUNT, b%()
    Pause 300
    If Inkey$ <> "" Then Exit Sub
  Loop
End Sub

'------------------------------------------------------------
' PROCEDURE: BinaryCount
' Use 8 LEDs as a binary counter (dim green = bit “1”, off = bit “0”)
Sub BinaryCount
  dimG% = 31   ' intensity for “1” bits
  Do
    For value% = 0 To 255
      For bit% = 0 To LEDCOUNT - 1
        mask% = (value% >> bit%) And 1
        ledIdx% = (LEDCOUNT - 1) - bit%
        If mask% = 1 Then
          b%(ledIdx%) = (dimG% * &H10000)  ' dim green only
        Else
          b%(ledIdx%) = 0
        End If
      Next bit%
      Bitbang ws2812 o, GP28, LEDCOUNT, b%()
      Pause speed%
      If Inkey$ <> "" Then Exit Sub
    Next value%
  Loop
End Sub

'------------------------------------------------------------
' PROCEDURE: LarsonScanner
' Classic “Knight Rider” red scanner with fading trail
Sub LarsonScanner
  position%  = 0
  direction% = 1

  Do
    ' Fade existing trail by 40% (shrinking the TOP byte, which is Red in RGB)
    For i% = 0 To LEDCOUNT - 1
      oldR% = (b%(i%) >> 16) And &HFF    ' top byte = Red
      oldG% = (b%(i%) >>  8) And &HFF    ' mid byte = Green
      oldB% =  b%(i%)        And &HFF    ' low byte = Blue

      newR% = Int(oldR% * 0.4)
      If newR% < 0 Then newR% = 0

      ' Re-pack as RGB: (R<<16) | (G<<8) | B
      b%(i%) = (newR% * &H10000) + (oldG% * &H100) + oldB%
    Next i%

    ' Light the “head” pixel in full-bright red (RGB = 0xFF0000)
    b%(position%) = &HFF0000

    Bitbang ws2812 o, GP28, LEDCOUNT, b%()

    ' Bounce the head back and forth
    position% = position% + direction%
    If position% = LEDCOUNT Then
      position%  = LEDCOUNT - 2
      direction% = -1
    End If
    If position% < 0 Then
      position%  = 1
      direction% = 1
    End If

    Pause speed%
  Loop Until Inkey$ <> ""
End Sub

'------------------------------------------------------------
' PROCEDURE: OceanEffect
' Smooth “wave” of blue across the strip
Sub OceanEffect
  offset% = 0      ' already declared globally
  direction% = 1   ' already declared globally
  Do
    For i% = 0 To LEDCOUNT - 1
      waveFld% = Sin(Rad(((i% - (LEDCOUNT \ 2)) + offset%) * 30)) * 15 + 16
      brightnessFld% = Int(waveFld%)
      If brightnessFld% < 0 Then brightnessFld% = 0
      If brightnessFld% > 31 Then brightnessFld% = 31
      mapG% = 0 : mapR% = 0 : mapB% = brightnessFld% * 8
      b%(i%) = (mapG% * &H10000) + (mapR% * &H100) + mapB%
    Next i%
    Bitbang ws2812 o, GP28, LEDCOUNT, b%()
    Pause speed%
    offset% = offset% + direction%
    If offset% Mod 8 = 0 Then direction% = -direction%
    If Inkey$ <> "" Then Exit Sub
  Loop
End Sub

'------------------------------------------------------------
' PROCEDURE: CommunicationEffect
' Fade a random RGB color on two adjacent LEDs
Sub CommunicationEffect
  Do
    ledPair% = 2 * Int(Rnd * (LEDCOUNT \ 2))
    If ledPair% > LEDCOUNT - 2 Then ledPair% = LEDCOUNT - 2

    Do
      rC% = 255 * (Rnd > 0.5)
      gC% = 255 * (Rnd > 0.5)
      bC% = 255 * (Rnd > 0.5)
    Loop Until rC% + gC% + bC% > 0

    For brightnessFld% = 255 To 0 Step -32
      For i% = 0 To LEDCOUNT - 1
        b%(i%) = 0
      Next i%
      mapG% = ((gC% * brightnessFld%) \ 255) * &H10000
      mapR% = ((rC% * brightnessFld%) \ 255) * &H100
      mapB% = ((bC% * brightnessFld%) \ 255)
      mixColor% = mapG% + mapR% + mapB%
      b%(ledPair%)     = mixColor%
      b%(ledPair% + 1) = mixColor%
      Bitbang ws2812 o, GP28, LEDCOUNT, b%()
      Pause speed%
      If Inkey$ <> "" Then Exit Sub
    Next brightnessFld%
  Loop
End Sub
