'-------------------------------------------------------------------
' Fire Visualization for PicoCalc (MMBasic)
'
' Creates peaceful fire effects on an 8-LED WS2812 strip (GP28)
'
' Controls:
'   LEFT/RIGHT = Cycle through fire effects
'   UP/DOWN    = Adjust brightness
'   Any other key = Exit to menu
'
' Fire colors: Red, Orange, Yellow, and occasional White
'-------------------------------------------------------------------

Const LEDCOUNT = 8

'-------------------------------------------------------------------
' GLOBAL DIMENSIONS
'-------------------------------------------------------------------

Dim b%(LEDCOUNT - 1)        ' LED buffer (24-bit RGB packed)
Dim heights%(LEDCOUNT - 1)  ' Flame heights for flicker effect
Dim targets%(LEDCOUNT - 1)  ' Target heights for smooth transitions
Dim pulseVal%(LEDCOUNT - 1) ' Pulse values for ember effect

Dim i%, j%, k$
Dim effectMode%             ' Current fire effect (0-3)
Dim brightness%             ' Global brightness (0-255)
Dim rCol%, gCol%, bCol%     ' Color components
Dim rAdj%, gAdj%, bAdj%     ' Brightness-adjusted colors
Dim flameHeight%
Dim colorChoice%
Dim emberPhase%
Dim waveOffset%
Dim intensity%
Dim screenW%, screenH%      ' Screen dimensions
Dim boxW%, boxH%, boxX%, boxY%  ' For screen drawing
Dim numBoxes%, boxSize%     ' For random box effect
Dim hearthX%, hearthY%, hearthW%, hearthH%  ' Fireplace dimensions
Dim numEmbers%, emberX%, emberY%, emberSize%, emberBright%  ' Ember effect
Dim shrink%                 ' For filled box effect
Dim emberFrameCount%        ' Frame counter for slow ember pulsing
Dim breathPhase%            ' Phase counter for breathing effect
Dim ledPhase%               ' LED phase for breathing calculations

'-------------------------------------------------------------------
' INITIAL SETUP
'-------------------------------------------------------------------

effectMode% = 0    ' Start with first effect
brightness% = 200  ' Start at 78% brightness
emberFrameCount% = 0
breathPhase% = 0

' Get screen dimensions
screenW% = MM.HRes
screenH% = MM.VRes

' Initialize arrays
For i% = 0 To LEDCOUNT - 1
  b%(i%) = 0
  heights%(i%) = 0
  targets%(i%) = 0
  pulseVal%(i%) = Int(Rnd * 360)
Next i%

'-------------------------------------------------------------------
' MAIN MENU LOOP
'-------------------------------------------------------------------
Do
  Cls
  Print "Fire Visualization"
  Print
  Print "LEFT/RIGHT: Change effect"
  Print "UP/DOWN: Brightness"
  Print "Any key: Exit"
  Print
  Print "Press any key to start..."

  k$ = ""
  Do
    k$ = Inkey$
  Loop Until k$ <> ""

  ' Run the fire visualization
  RunFireVisualization

  ' Ask if user wants to continue
  Cls
  Print "Return to menu? (Y/N)"
  k$ = ""
  Do
    k$ = Inkey$
  Loop Until k$ <> ""

  If UCase$(k$) = "N" Then Exit Do
Loop

' Clear LEDs before exit
ClearAll
End

'-------------------------------------------------------------------
' MAIN VISUALIZATION LOOP
'-------------------------------------------------------------------

Sub RunFireVisualization
  emberPhase% = 0
  waveOffset% = 0
  Dim lastEffect%
  lastEffect% = -1

  ' Clear screen and set up graphics
  Cls

  Do
    ' Clear screen when effect changes
    If effectMode% <> lastEffect% Then
      Cls
      lastEffect% = effectMode%
    End If

    ' Render the current fire effect
    Select Case effectMode%
      Case 0
        FlickeringFlames
      Case 1
        FilledFlames
      Case 2
        Campfire
      Case 3
        Fireplace
      Case 4
        GlowingEmbers
      Case 5
        BreathingEmbers
    End Select

    ' Update the LED strip
    Bitbang ws2812 o, GP28, LEDCOUNT, b%()

    ' Check for button presses
    k$ = Inkey$
    If k$ <> "" Then
      Select Case k$
        Case Chr$(130)   ' LEFT button
          effectMode% = effectMode% - 1
          If effectMode% < 0 Then effectMode% = 5
          Pause 200  ' Debounce

        Case Chr$(131)   ' RIGHT button
          effectMode% = effectMode% + 1
          If effectMode% > 5 Then effectMode% = 0
          Pause 200  ' Debounce

        Case Chr$(128)   ' UP button
          brightness% = Min(brightness% + 15, 255)
          Pause 100

        Case Chr$(129)   ' DOWN button
          brightness% = Max(brightness% - 15, 20)
          Pause 100

        Case Else
          ' Any other key exits
          Exit Sub
      End Select
    End If

    Pause 50
  Loop
End Sub

'-------------------------------------------------------------------
' EFFECT 0: Flickering Flames
' Random flame heights with fire colors
'-------------------------------------------------------------------

Sub FlickeringFlames
  ' Draw vertical flame bars on screen (mimicking 8 LEDs)
  boxW% = screenW% \ LEDCOUNT

  For i% = 0 To LEDCOUNT - 1
    ' Smooth transition to target heights
    If heights%(i%) < targets%(i%) Then
      heights%(i%) = heights%(i%) + 1
    ElseIf heights%(i%) > targets%(i%) Then
      heights%(i%) = heights%(i%) - 1
    Else
      ' Reached target, set new target
      targets%(i%) = Int(Rnd * 10)
    End If

    flameHeight% = heights%(i%)

    If flameHeight% = 0 Then
      b%(i%) = 0
    Else
      ' Choose fire color based on height
      colorChoice% = Int(Rnd * 100)

      If flameHeight% > 7 Then
        ' Tall flames: yellow or white
        If colorChoice% < 80 Then
          rCol% = 255 : gCol% = 255 : bCol% = 0   ' Yellow
        Else
          rCol% = 255 : gCol% = 255 : bCol% = 150  ' Pale yellow-white
        End If
      ElseIf flameHeight% > 4 Then
        ' Medium flames: orange to yellow
        If colorChoice% < 70 Then
          rCol% = 255 : gCol% = 180 : bCol% = 0   ' Orange-yellow
        Else
          rCol% = 255 : gCol% = 255 : bCol% = 0   ' Yellow
        End If
      Else
        ' Low flames: red to orange
        If colorChoice% < 60 Then
          rCol% = 255 : gCol% = 50 : bCol% = 0    ' Red-orange
        Else
          rCol% = 255 : gCol% = 127 : bCol% = 0   ' Orange
        End If
      End If

      ' Apply brightness
      rAdj% = (rCol% * brightness%) \ 255
      gAdj% = (gCol% * brightness%) \ 255
      bAdj% = (bCol% * brightness%) \ 255

      b%(i%) = (rAdj% * &H10000) + (gAdj% * &H100) + bAdj%

      ' Draw flame bar on screen
      boxX% = i% * boxW%
      boxH% = (flameHeight% * screenH%) \ 10
      boxY% = screenH% - boxH%
      Box boxX%, boxY%, boxW% - 2, boxH%, 1, RGB(rAdj%, gAdj%, bAdj%)
    Else
      ' Clear this bar if no flame
      boxX% = i% * boxW%
      Box boxX%, 0, boxW% - 2, screenH%, 1, RGB(0, 0, 0)
    End If
  Next i%
End Sub

'-------------------------------------------------------------------
' EFFECT 1: Filled Flames
' Same as Flickering Flames but with solid filled bars
'-------------------------------------------------------------------

Sub FilledFlames
  ' Draw vertical flame bars on screen - same as Effect 0 but with full blocks
  ' Clear screen to black first
  Box 0, 0, screenW%, screenH%, 1, RGB(0, 0, 0)

  boxW% = screenW% \ LEDCOUNT

  For i% = 0 To LEDCOUNT - 1
    ' Smooth transition to target heights
    If heights%(i%) < targets%(i%) Then
      heights%(i%) = heights%(i%) + 1
    ElseIf heights%(i%) > targets%(i%) Then
      heights%(i%) = heights%(i%) - 1
    Else
      ' Reached target, set new target
      targets%(i%) = Int(Rnd * 10)
    End If

    flameHeight% = heights%(i%)

    If flameHeight% = 0 Then
      b%(i%) = 0
    Else
      ' Choose fire color based on height
      colorChoice% = Int(Rnd * 100)

      If flameHeight% > 7 Then
        ' Tall flames: yellow or white
        If colorChoice% < 80 Then
          rCol% = 255 : gCol% = 255 : bCol% = 0   ' Yellow
        Else
          rCol% = 255 : gCol% = 255 : bCol% = 150  ' Pale yellow-white
        End If
      ElseIf flameHeight% > 4 Then
        ' Medium flames: orange to yellow
        If colorChoice% < 70 Then
          rCol% = 255 : gCol% = 180 : bCol% = 0   ' Orange-yellow
        Else
          rCol% = 255 : gCol% = 255 : bCol% = 0   ' Yellow
        End If
      Else
        ' Low flames: red to orange
        If colorChoice% < 60 Then
          rCol% = 255 : gCol% = 50 : bCol% = 0    ' Red-orange
        Else
          rCol% = 255 : gCol% = 127 : bCol% = 0   ' Orange
        End If
      End If

      ' Apply brightness
      rAdj% = (rCol% * brightness%) \ 255
      gAdj% = (gCol% * brightness%) \ 255
      bAdj% = (bCol% * brightness%) \ 255

      b%(i%) = (rAdj% * &H10000) + (gAdj% * &H100) + bAdj%

      ' Draw flame bar - filled by drawing many concentric boxes
      boxH% = (flameHeight% * screenH%) \ 10
      boxY% = screenH% - boxH%
      boxX% = i% * boxW%

      ' Draw concentric boxes to fill the area
      For shrink% = 0 To Min(boxW% \ 2, boxH% \ 2) Step 1
        Box boxX% + shrink%, boxY% + shrink%, boxW% - (shrink% * 2), boxH% - (shrink% * 2), 1, RGB(rAdj%, gAdj%, bAdj%)
      Next shrink%
    End If
  Next i%
End Sub

'-------------------------------------------------------------------
' EFFECT 2: Campfire
' More chaotic, dancing flames with rapid changes
'-------------------------------------------------------------------

Sub Campfire
  ' Draw random fire boxes all over screen
  numBoxes% = 15

  For j% = 0 To numBoxes% - 1
    ' Random box position and size
    boxSize% = Int(10 + Rnd * 30)
    boxX% = Int(Rnd * (screenW% - boxSize%))
    boxY% = Int(Rnd * (screenH% - boxSize%))

    ' Random fire color
    intensity% = Int(Rnd * 255)
    If intensity% < 100 Then
      rCol% = 200 : gCol% = 0 : bCol% = 0
    ElseIf intensity% < 160 Then
      rCol% = 255 : gCol% = Int(Rnd * 100) : bCol% = 0
    ElseIf intensity% < 220 Then
      rCol% = 255 : gCol% = Int(100 + Rnd * 155) : bCol% = 0
    Else
      rCol% = 255 : gCol% = 255 : bCol% = Int(Rnd * 100)
    End If

    rAdj% = (rCol% * brightness%) \ 255
    gAdj% = (gCol% * brightness%) \ 255
    bAdj% = (bCol% * brightness%) \ 255

    Box boxX%, boxY%, boxSize%, boxSize%, 1, RGB(rAdj%, gAdj%, bAdj%)
  Next j%

  ' Update LEDs
  For i% = 0 To LEDCOUNT - 1
    ' Random chaotic flickering
    intensity% = Int(Rnd * 255)

    If intensity% < 40 Then
      ' Dark/off
      b%(i%) = 0
    ElseIf intensity% < 100 Then
      ' Deep red
      rCol% = 200 : gCol% = 0 : bCol% = 0
    ElseIf intensity% < 160 Then
      ' Orange-red
      rCol% = 255 : gCol% = Int(Rnd * 100) : bCol% = 0
    ElseIf intensity% < 220 Then
      ' Orange to yellow
      rCol% = 255 : gCol% = Int(100 + Rnd * 155) : bCol% = 0
    Else
      ' Bright yellow-white
      rCol% = 255 : gCol% = 255 : bCol% = Int(Rnd * 100)
    End If

    ' Apply brightness
    rAdj% = (rCol% * brightness%) \ 255
    gAdj% = (gCol% * brightness%) \ 255
    bAdj% = (bCol% * brightness%) \ 255

    b%(i%) = (rAdj% * &H10000) + (gAdj% * &H100) + bAdj%
  Next i%
End Sub

'-------------------------------------------------------------------
' EFFECT 2: Fireplace
' Steady warm glow with subtle variations
'-------------------------------------------------------------------

Sub Fireplace
  waveOffset% = waveOffset% + 1
  If waveOffset% > 359 Then waveOffset% = 0

  ' Draw fireplace frame (dark brown/brick)
  Box 0, 0, screenW%, screenH%, 1, RGB(40, 20, 10)

  ' Draw hearth opening (black)
  hearthX% = screenW% \ 8
  hearthY% = screenH% \ 4
  hearthW% = (screenW% * 3) \ 4
  hearthH% = (screenH% * 2) \ 3
  Box hearthX%, hearthY%, hearthW%, hearthH%, 1, RGB(0, 0, 0)

  ' Draw flames inside fireplace
  For j% = 0 To 11
    boxW% = hearthW% \ 12
    boxX% = hearthX% + (j% * boxW%)
    intensity% = Sin(Rad((j% * 30 + waveOffset%) Mod 360)) * 40 + 215
    boxH% = Int((intensity% * hearthH%) \ 300)
    boxY% = hearthY% + hearthH% - boxH%

    ' Vary colors
    colorChoice% = Int(Rnd * 100)
    If colorChoice% < 60 Then
      rCol% = 255 : gCol% = 127 : bCol% = 0
    ElseIf colorChoice% < 90 Then
      rCol% = 255 : gCol% = 200 : bCol% = 0
    Else
      rCol% = 255 : gCol% = 80 : bCol% = 0
    End If

    rAdj% = (rCol% * brightness%) \ 255
    gAdj% = (gCol% * brightness%) \ 255
    bAdj% = (bCol% * brightness%) \ 255

    Box boxX%, boxY%, boxW% - 1, boxH%, 1, RGB(rAdj%, gAdj%, bAdj%)
  Next j%

  ' Update LEDs
  For i% = 0 To LEDCOUNT - 1
    ' Gentle wave pattern for subtle movement
    intensity% = Sin(Rad((i% * 45 + waveOffset%) Mod 360)) * 30 + 225
    If intensity% < 180 Then intensity% = 180
    If intensity% > 255 Then intensity% = 255

    ' Warm orange-red glow
    colorChoice% = Int(Rnd * 100)

    If colorChoice% < 60 Then
      ' Orange
      rCol% = 255 : gCol% = 127 : bCol% = 0
    ElseIf colorChoice% < 90 Then
      ' Orange-yellow
      rCol% = 255 : gCol% = 200 : bCol% = 0
    Else
      ' Deep red-orange
      rCol% = 255 : gCol% = 80 : bCol% = 0
    End If

    ' Apply intensity and brightness
    rCol% = (rCol% * intensity%) \ 255
    gCol% = (gCol% * intensity%) \ 255
    bCol% = (bCol% * intensity%) \ 255

    rAdj% = (rCol% * brightness%) \ 255
    gAdj% = (gCol% * brightness%) \ 255
    bAdj% = (bCol% * brightness%) \ 255

    b%(i%) = (rAdj% * &H10000) + (gAdj% * &H100) + bAdj%
  Next i%
End Sub

'-------------------------------------------------------------------
' EFFECT 3: Glowing Embers
' Slow pulsing red/orange coals
'-------------------------------------------------------------------

Sub GlowingEmbers
  emberPhase% = emberPhase% + 3
  If emberPhase% > 359 Then emberPhase% = 0

  ' Draw background (dark)
  Box 0, 0, screenW%, screenH%, 1, RGB(10, 5, 0)

  ' Draw pulsing ember circles
  numEmbers% = 12

  For j% = 0 To numEmbers% - 1
    ' Position embers in a grid-like pattern
    emberX% = (j% Mod 4) * (screenW% \ 4) + (screenW% \ 8)
    emberY% = (j% \ 4) * (screenH% \ 3) + (screenH% \ 6)

    ' Each ember pulses independently
    emberBright% = Sin(Rad((emberPhase% + j% * 30) Mod 360)) * 80 + 175
    If emberBright% < 100 Then emberBright% = 100
    If emberBright% > 255 Then emberBright% = 255

    ' Size varies with brightness
    emberSize% = (emberBright% \ 15) + 5

    ' Deep red to orange
    colorChoice% = Int(Rnd * 100)
    If colorChoice% < 70 Then
      rCol% = 200 : gCol% = 0 : bCol% = 0
    ElseIf colorChoice% < 95 Then
      rCol% = 255 : gCol% = 60 : bCol% = 0
    Else
      rCol% = 255 : gCol% = 127 : bCol% = 0
    End If

    rCol% = (rCol% * emberBright%) \ 255
    gCol% = (gCol% * emberBright%) \ 255
    bCol% = (bCol% * emberBright%) \ 255

    rAdj% = (rCol% * brightness%) \ 255
    gAdj% = (gCol% * brightness%) \ 255
    bAdj% = (bCol% * brightness%) \ 255

    Circle emberX%, emberY%, emberSize%, 1, 1, RGB(rAdj%, gAdj%, bAdj%)
  Next j%

  ' Update LEDs - slow, peaceful pulsing
  emberFrameCount% = emberFrameCount% + 1
  If emberFrameCount% > 4 Then emberFrameCount% = 0

  For i% = 0 To LEDCOUNT - 1
    ' Only update pulse phase every 5th frame for very slow pulsing
    If emberFrameCount% = 0 Then
      pulseVal%(i%) = pulseVal%(i%) + 1
      If pulseVal%(i%) > 359 Then pulseVal%(i%) = 0
    End If

    ' Deeper, more dramatic pulsing intensity
    intensity% = Sin(Rad(pulseVal%(i%))) * 100 + 155
    If intensity% < 55 Then intensity% = 55
    If intensity% > 255 Then intensity% = 255

    ' Deep red to orange embers
    colorChoice% = Int(Rnd * 100)

    If colorChoice% < 70 Then
      ' Deep red
      rCol% = 200 : gCol% = 0 : bCol% = 0
    ElseIf colorChoice% < 95 Then
      ' Red-orange
      rCol% = 255 : gCol% = 60 : bCol% = 0
    Else
      ' Brighter orange
      rCol% = 255 : gCol% = 127 : bCol% = 0
    End If

    ' Apply intensity and brightness
    rCol% = (rCol% * intensity%) \ 255
    gCol% = (gCol% * intensity%) \ 255
    bCol% = (bCol% * intensity%) \ 255

    rAdj% = (rCol% * brightness%) \ 255
    gAdj% = (gCol% * brightness%) \ 255
    bAdj% = (bCol% * brightness%) \ 255

    b%(i%) = (rAdj% * &H10000) + (gAdj% * &H100) + bAdj%
  Next i%
End Sub

'-------------------------------------------------------------------
' EFFECT 5: Breathing Embers
' Very slow, smooth, fluid breathing/pulsating warm glow
'-------------------------------------------------------------------

Sub BreathingEmbers
  ' Increment phase very slowly (1 degree every 2 frames)
  breathPhase% = breathPhase% + 1
  If breathPhase% > 719 Then breathPhase% = 0

  ' Draw background (very dark)
  Box 0, 0, screenW%, screenH%, 1, RGB(5, 2, 0)

  ' Draw breathing ember circles on screen
  numEmbers% = 12

  For j% = 0 To numEmbers% - 1
    ' Position embers in a grid-like pattern
    emberX% = (j% Mod 4) * (screenW% \ 4) + (screenW% \ 8)
    emberY% = (j% \ 4) * (screenH% \ 3) + (screenH% \ 6)

    ' Each ember breathes with a slight phase offset
    ledPhase% = (breathPhase% \ 2 + j% * 30) Mod 360
    emberBright% = Sin(Rad(ledPhase%)) * 60 + 160
    If emberBright% < 100 Then emberBright% = 100
    If emberBright% > 220 Then emberBright% = 220

    ' Gentle size variation with breathing
    emberSize% = (emberBright% \ 20) + 8

    ' Warm ember colors only - deep red to soft orange
    rCol% = 220
    gCol% = Int((emberBright% - 100) \ 3)
    If gCol% > 60 Then gCol% = 60
    bCol% = 0

    rAdj% = (rCol% * brightness%) \ 255
    gAdj% = (gCol% * brightness%) \ 255
    bAdj% = (bCol% * brightness%) \ 255

    Circle emberX%, emberY%, emberSize%, 1, 1, RGB(rAdj%, gAdj%, bAdj%)
  Next j%

  ' Update LEDs with smooth breathing
  For i% = 0 To LEDCOUNT - 1
    ' Each LED has phase offset for gentle wave effect
    ledPhase% = (breathPhase% \ 2 + i% * 15) Mod 360

    ' Smooth breathing intensity
    intensity% = Sin(Rad(ledPhase%)) * 60 + 160
    If intensity% < 100 Then intensity% = 100
    If intensity% > 220 Then intensity% = 220

    ' Warm colors - mostly deep red with hint of orange
    rCol% = 220
    gCol% = Int((intensity% - 100) \ 3)
    If gCol% > 60 Then gCol% = 60
    bCol% = 0

    ' Apply intensity and brightness
    rCol% = (rCol% * intensity%) \ 255
    gCol% = (gCol% * intensity%) \ 255

    rAdj% = (rCol% * brightness%) \ 255
    gAdj% = (gCol% * brightness%) \ 255
    bAdj% = 0

    b%(i%) = (rAdj% * &H10000) + (gAdj% * &H100) + bAdj%
  Next i%
End Sub

'-------------------------------------------------------------------
' UTILITY: Clear All LEDs
'-------------------------------------------------------------------

Sub ClearAll
  For i% = 0 To LEDCOUNT - 1
    b%(i%) = 0
  Next i%
  Bitbang ws2812 o, GP28, LEDCOUNT, b%()
End Sub
