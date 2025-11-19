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
Dim emberColorDuration%(LEDCOUNT - 1) ' How long each ember keeps its color
Dim emberColorChoice%(LEDCOUNT - 1) ' Current color for each ember

Dim i%, j%, k$
Dim effectMode%             ' Current fire effect (0-3)
Dim brightness%             ' Global brightness (0-255)
Dim showScreen%             ' Toggle for screen visualizations (1=on, 0=off)
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
Dim candleFlicker%(3)       ' Flicker intensity for each candle
Dim candleTarget%(3)        ' Target flicker for each candle
Dim wavePos%                ' Position of fire wave
Dim waveDir%                ' Direction of fire wave
Dim sunsetOffset%           ' Gradient offset for sunset
Dim logBrightness%(LEDCOUNT - 1)  ' Brightness of each log/ember
Dim logFadeTimer%(LEDCOUNT - 1)   ' Fade timer for each log
Dim spiralAngle%            ' Rotation angle for spiral
Dim numCandles%, candleIdx%, candleX%, candleY%, candleW%, candleH%
Dim flameH%, flameY%
Dim dist%, waveIntensity%
Dim colorPos%, gradientPhase%
Dim spotX%, spotY%, spotSize%
Dim centerX%, centerY%, numRings%, ringIdx%, angle%, radius%
Dim spiralX%, spiralY%

'-------------------------------------------------------------------
' INITIAL SETUP
'-------------------------------------------------------------------

effectMode% = 0    ' Start with first effect
brightness% = 200  ' Start at 78% brightness
showScreen% = 1    ' Screen visualizations on by default
emberFrameCount% = 0
breathPhase% = 0
wavePos% = 0
waveDir% = 1
sunsetOffset% = 0
spiralAngle% = 0

' Get screen dimensions
screenW% = MM.HRes
screenH% = MM.VRes

' Initialize arrays
For i% = 0 To LEDCOUNT - 1
  b%(i%) = 0
  heights%(i%) = 0
  targets%(i%) = 0
  pulseVal%(i%) = Int(Rnd * 360)
  emberColorDuration%(i%) = 0
  emberColorChoice%(i%) = 0
  logBrightness%(i%) = 0
  logFadeTimer%(i%) = 0
Next i%

' Initialize candle flicker
For i% = 0 To 3
  candleFlicker%(i%) = 200
  candleTarget%(i%) = 200
Next i%

'-------------------------------------------------------------------
' MAIN MENU LOOP
'-------------------------------------------------------------------
Cls
Print "Fire Visualization"
Print
Print "Controls:"
Print "  LEFT/RIGHT: Change effect"
Print "  UP/DOWN: Brightness"
Print "  S: Toggle screen display"
Print "  Q: Quit to menu"
Print
Print "Press any key to start..."

k$ = ""
Do
  k$ = Inkey$
Loop Until k$ <> ""

' Run the fire visualization
RunFireVisualization

' Clear LEDs and screen before exit
ClearAll
Cls

' Run menu.bas
Run "menu.bas"

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
    ' Clear screen when effect changes or when toggling screen viz
    If effectMode% <> lastEffect% Then
      Cls
      lastEffect% = effectMode%
    End If

    ' Keep screen black when screen display is off
    If showScreen% = 0 Then
      Cls
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
      Case 6
        CandleCluster
      Case 7
        FireWave
      Case 8
        SunsetGlow
      Case 9
        SmolderingLogs
      Case 10
        FireSpiral
    End Select

    ' Update the LED strip
    Bitbang ws2812 o, GP28, LEDCOUNT, b%()

    ' Check for button presses
    k$ = Inkey$
    If k$ <> "" Then
      Select Case k$
        Case Chr$(130)   ' LEFT button
          effectMode% = effectMode% - 1
          If effectMode% < 0 Then effectMode% = 10
          Pause 200  ' Debounce

        Case Chr$(131)   ' RIGHT button
          effectMode% = effectMode% + 1
          If effectMode% > 10 Then effectMode% = 0
          Pause 200  ' Debounce

        Case Chr$(128)   ' UP button
          brightness% = Min(brightness% + 15, 255)
          Pause 100

        Case Chr$(129)   ' DOWN button
          brightness% = Max(brightness% - 15, 20)
          Pause 100

        Case "q", "Q"    ' Quit
          Exit Sub

        Case "s", "S"    ' Toggle screen display
          showScreen% = 1 - showScreen%
          If showScreen% = 0 Then
            ' Clear screen to black when turning off
            Cls
          End If
          Pause 200  ' Debounce
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
  If showScreen% = 1 Then
    boxW% = screenW% \ LEDCOUNT
  End If

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
      If showScreen% = 1 Then
        boxX% = i% * boxW%
        boxH% = (flameHeight% * screenH%) \ 10
        boxY% = screenH% - boxH%
        Box boxX%, boxY%, boxW% - 2, boxH%, 1, RGB(rAdj%, gAdj%, bAdj%)
      End If
    Else
      ' Clear this bar if no flame
      If showScreen% = 1 Then
        boxX% = i% * boxW%
        Box boxX%, 0, boxW% - 2, screenH%, 1, RGB(0, 0, 0)
      End If
    End If
  Next i%
End Sub

'-------------------------------------------------------------------
' EFFECT 1: Filled Flames
' Same as Flickering Flames but with solid filled bars
'-------------------------------------------------------------------

Sub FilledFlames
  ' Draw vertical flame bars on screen - same as Effect 0 but with full blocks
  If showScreen% = 1 Then
    ' Clear screen to black first
    Box 0, 0, screenW%, screenH%, 1, RGB(0, 0, 0)
    boxW% = screenW% \ LEDCOUNT
  End If

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
      If showScreen% = 1 Then
        boxH% = (flameHeight% * screenH%) \ 10
        boxY% = screenH% - boxH%
        boxX% = i% * boxW%

        ' Draw concentric boxes to fill the area
        For shrink% = 0 To Min(boxW% \ 2, boxH% \ 2) Step 1
          Box boxX% + shrink%, boxY% + shrink%, boxW% - (shrink% * 2), boxH% - (shrink% * 2), 1, RGB(rAdj%, gAdj%, bAdj%)
        Next shrink%
      End If
    End If
  Next i%
End Sub

'-------------------------------------------------------------------
' EFFECT 2: Campfire
' More chaotic, dancing flames with rapid changes
'-------------------------------------------------------------------

Sub Campfire
  ' Draw random fire boxes all over screen
  If showScreen% = 1 Then
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
  End If

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

  If showScreen% = 1 Then
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
  End If

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

  If showScreen% = 1 Then
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
  End If

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

    ' Color changes with variable duration
    emberColorDuration%(i%) = emberColorDuration%(i%) - 1
    If emberColorDuration%(i%) <= 0 Then
      ' Pick new color and set random duration (3-12 frames)
      emberColorChoice%(i%) = Int(Rnd * 100)
      emberColorDuration%(i%) = Int(3 + Rnd * 10)
    End If

    ' Deep red to orange embers (brighter orange now only 2% chance)
    If emberColorChoice%(i%) < 70 Then
      ' Deep red (70% of the time)
      rCol% = 200 : gCol% = 0 : bCol% = 0
    ElseIf emberColorChoice%(i%) < 98 Then
      ' Red-orange (28% of the time)
      rCol% = 255 : gCol% = 60 : bCol% = 0
    Else
      ' Brighter orange (2% of the time)
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

  If showScreen% = 1 Then
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
  End If

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
' EFFECT 6: Candle Cluster
' Intimate candlelight with gentle flickering
'-------------------------------------------------------------------

Sub CandleCluster
  ' 4 candles, each gets 2 LEDs
  numCandles% = 4

  For candleIdx% = 0 To numCandles% - 1
    ' Smooth flicker transition - faster and more dynamic
    If candleFlicker%(candleIdx%) < candleTarget%(candleIdx%) Then
      candleFlicker%(candleIdx%) = candleFlicker%(candleIdx%) + 8
    ElseIf candleFlicker%(candleIdx%) > candleTarget%(candleIdx%) Then
      candleFlicker%(candleIdx%) = candleFlicker%(candleIdx%) - 8
    Else
      ' Reached target, set new varied target
      candleTarget%(candleIdx%) = 140 + Int(Rnd * 115)  ' Wider range: 140-255
    End If

    If showScreen% = 1 Then
      ' Clear screen each frame so flames can shrink properly (only on first candle)
      If candleIdx% = 0 Then
        Box 0, 0, screenW%, screenH%, 1, RGB(15, 10, 5)
      End If

      ' Draw candle body on screen
      candleW% = screenW% \ 6
      candleH% = screenH% \ 3
      candleX% = (candleIdx% * screenW% \ 4) + (screenW% \ 8) - (candleW% \ 2)
      candleY% = screenH% - candleH%

      ' Candle wax (cream color)
      Box candleX%, candleY%, candleW%, candleH%, 1, RGB(80, 70, 40)

      ' Flame (teardrop shape - approximate with boxes) - dramatic height changes
      flameH% = (candleFlicker%(candleIdx%) \ 3) + 5  ' Even bigger variation: 51-90 pixels
      flameY% = candleY% - flameH%

      ' Bright yellow-orange flame with dramatic color variation
      intensity% = candleFlicker%(candleIdx%)
      rAdj% = (255 * brightness%) \ 255
      gCol% = 80 + Int((intensity% - 140) * 1.5)  ' Wider green range
      If gCol% < 60 Then gCol% = 60
      If gCol% > 255 Then gCol% = 255
      gAdj% = (gCol% * intensity% * brightness%) \ 65025
      bAdj% = 0

      ' Draw flame with filled boxes for visibility
      For shrink% = 0 To Min((candleW% \ 4), (flameH% \ 2)) Step 1
        Box candleX% + (candleW% \ 4) + shrink%, flameY% + shrink%, (candleW% \ 2) - (shrink% * 2), flameH% - (shrink% * 2), 1, RGB(rAdj%, gAdj%, bAdj%)
      Next shrink%
    End If

    ' Update 2 LEDs for this candle
    intensity% = candleFlicker%(candleIdx%)

    ' Warm candle flame color - dramatic variation
    rCol% = 255
    gCol% = 80 + Int((intensity% - 140) * 1.5)  ' Match screen flame
    If gCol% < 60 Then gCol% = 60
    If gCol% > 255 Then gCol% = 255
    bCol% = 0

    ' Apply intensity variation - more dramatic brightness changes
    rAdj% = (rCol% * intensity% * brightness%) \ 65025
    gAdj% = (gCol% * intensity% * brightness%) \ 65025
    bAdj% = 0

    ' Boost low values to ensure visibility
    If rAdj% < 40 Then rAdj% = 40
    If gAdj% < 20 Then gAdj% = 20

    ' Set both LEDs for this candle
    b%(candleIdx% * 2) = (rAdj% * &H10000) + (gAdj% * &H100) + bAdj%
    b%(candleIdx% * 2 + 1) = (rAdj% * &H10000) + (gAdj% * &H100) + bAdj%
  Next candleIdx%
End Sub

'-------------------------------------------------------------------
' EFFECT 7: Fire Wave
' Hypnotic rolling wave of fire
'-------------------------------------------------------------------

Sub FireWave
  If showScreen% = 1 Then
    ' Clear background
    Box 0, 0, screenW%, screenH%, 1, RGB(10, 5, 0)
    boxW% = screenW% \ LEDCOUNT
  End If

  ' Move wave position
  wavePos% = wavePos% + waveDir%
  If wavePos% >= LEDCOUNT - 1 Then
    wavePos% = LEDCOUNT - 1
    waveDir% = -1
  End If
  If wavePos% <= 0 Then
    wavePos% = 0
    waveDir% = 1
  End If

  ' Draw wave on screen and LEDs
  For i% = 0 To LEDCOUNT - 1
    ' Calculate distance from wave center
    dist% = Abs(i% - wavePos%)

    ' Wave intensity falls off with distance
    If dist% = 0 Then
      waveIntensity% = 255
    ElseIf dist% = 1 Then
      waveIntensity% = 180
    ElseIf dist% = 2 Then
      waveIntensity% = 100
    Else
      waveIntensity% = 30
    End If

    ' Fire colors based on intensity
    If waveIntensity% > 200 Then
      rCol% = 255 : gCol% = 255 : bCol% = 100  ' Bright yellow-white
    ElseIf waveIntensity% > 150 Then
      rCol% = 255 : gCol% = 200 : bCol% = 0    ' Yellow-orange
    ElseIf waveIntensity% > 80 Then
      rCol% = 255 : gCol% = 100 : bCol% = 0    ' Orange
    Else
      rCol% = 200 : gCol% = 30 : bCol% = 0     ' Deep red
    End If

    ' Apply intensity and brightness
    rCol% = (rCol% * waveIntensity%) \ 255
    gCol% = (gCol% * waveIntensity%) \ 255
    bCol% = (bCol% * waveIntensity%) \ 255

    rAdj% = (rCol% * brightness%) \ 255
    gAdj% = (gCol% * brightness%) \ 255
    bAdj% = (bCol% * brightness%) \ 255

    ' Set LED
    b%(i%) = (rAdj% * &H10000) + (gAdj% * &H100) + bAdj%

    ' Draw on screen
    If showScreen% = 1 Then
      boxX% = i% * boxW%
      boxH% = (waveIntensity% * screenH%) \ 255
      boxY% = screenH% - boxH%

      For shrink% = 0 To Min(boxW% \ 2, boxH% \ 2) Step 1
        Box boxX% + shrink%, boxY% + shrink%, boxW% - (shrink% * 2), boxH% - (shrink% * 2), 1, RGB(rAdj%, gAdj%, bAdj%)
      Next shrink%
    End If
  Next i%
End Sub

'-------------------------------------------------------------------
' EFFECT 8: Sunset Glow
' Peaceful gradient that shifts over time
'-------------------------------------------------------------------

Sub SunsetGlow
  ' Slowly shift gradient
  sunsetOffset% = sunsetOffset% + 1
  If sunsetOffset% > 360 Then sunsetOffset% = 0

  If showScreen% = 1 Then
    ' Clear to dark
    Box 0, 0, screenW%, screenH%, 1, RGB(5, 0, 0)
    boxW% = screenW% \ LEDCOUNT
  End If

  For i% = 0 To LEDCOUNT - 1
    ' Calculate color based on position and offset
    colorPos% = (i% * 360 \ LEDCOUNT + sunsetOffset%) Mod 360

    ' Use sine wave for smooth gradient
    gradientPhase% = Sin(Rad(colorPos%)) * 127 + 128

    ' Sunset colors: deep red to orange to yellow
    If gradientPhase% < 85 Then
      ' Deep red
      rCol% = 180 + Int(gradientPhase% * 0.88)  ' Scale to max 255
      If rCol% > 255 Then rCol% = 255
      gCol% = 0
      bCol% = 0
    ElseIf gradientPhase% < 170 Then
      ' Red to orange
      rCol% = 255
      gCol% = (gradientPhase% - 85) * 2
      If gCol% > 255 Then gCol% = 255
      bCol% = 0
    Else
      ' Orange to yellow
      rCol% = 255
      gCol% = 170 + (gradientPhase% - 170)
      If gCol% > 255 Then gCol% = 255
      bCol% = 0
    End If

    rAdj% = (rCol% * brightness%) \ 255
    gAdj% = (gCol% * brightness%) \ 255
    bAdj% = (bCol% * brightness%) \ 255

    ' Set LED
    b%(i%) = (rAdj% * &H10000) + (gAdj% * &H100) + bAdj%

    If showScreen% = 1 Then
      ' Draw filled bar on screen
      boxX% = i% * boxW%
      For shrink% = 0 To boxW% \ 2 Step 1
        Box boxX% + shrink%, shrink%, boxW% - (shrink% * 2), screenH% - (shrink% * 2), 1, RGB(rAdj%, gAdj%, bAdj%)
      Next shrink%
    End If
  Next i%
End Sub

'-------------------------------------------------------------------
' EFFECT 9: Smoldering Logs
' Subtle, dying fire with occasional flares
'-------------------------------------------------------------------

Sub SmolderingLogs
  If showScreen% = 1 Then
    ' Very dark background
    Box 0, 0, screenW%, screenH%, 1, RGB(8, 4, 0)
  End If

  ' Update each log/ember
  For i% = 0 To LEDCOUNT - 1
    ' Decrement fade timer
    logFadeTimer%(i%) = logFadeTimer%(i%) - 1

    If logFadeTimer%(i%) <= 0 Then
      ' Occasionally flare up (10% chance)
      If Rnd < 0.1 Then
        logBrightness%(i%) = 180 + Int(Rnd * 75)
        logFadeTimer%(i%) = 20 + Int(Rnd * 40)
      Else
        ' Stay dim
        logBrightness%(i%) = 20 + Int(Rnd * 30)
        logFadeTimer%(i%) = 10 + Int(Rnd * 20)
      End If
    End If

    ' Slowly fade current brightness
    If logBrightness%(i%) > 25 Then
      logBrightness%(i%) = logBrightness%(i%) - 2
    End If

    ' Set color (deep red to orange based on brightness)
    If logBrightness%(i%) > 150 Then
      rCol% = 255 : gCol% = 100 : bCol% = 0  ' Bright orange
    ElseIf logBrightness%(i%) > 80 Then
      rCol% = 220 : gCol% = 40 : bCol% = 0   ' Red-orange
    Else
      rCol% = 150 : gCol% = 0 : bCol% = 0    ' Deep red
    End If

    rAdj% = (rCol% * logBrightness%(i%)) \ 255
    gAdj% = (gCol% * logBrightness%(i%)) \ 255
    bAdj% = 0

    rAdj% = (rAdj% * brightness%) \ 255
    gAdj% = (gAdj% * brightness%) \ 255

    b%(i%) = (rAdj% * &H10000) + (gAdj% * &H100) + bAdj%

    If showScreen% = 1 Then
      ' Draw small hot spots on screen
      If logBrightness%(i%) > 40 Then
        spotX% = (i% * screenW% \ LEDCOUNT) + (screenW% \ (LEDCOUNT * 2))
        spotY% = screenH% \ 2 + Int(Rnd * (screenH% \ 4)) - (screenH% \ 8)
        spotSize% = (logBrightness%(i%) \ 20) + 3

        Circle spotX%, spotY%, spotSize%, 1, 1, RGB(rAdj%, gAdj%, bAdj%)
      End If
    End If
  Next i%
End Sub

'-------------------------------------------------------------------
' EFFECT 10: Fire Spiral
' Mesmerizing rotating fire pattern
'-------------------------------------------------------------------

Sub FireSpiral
  ' Rotate spiral
  spiralAngle% = spiralAngle% + 2
  If spiralAngle% > 359 Then spiralAngle% = 0

  If showScreen% = 1 Then
    ' Dark background
    Box 0, 0, screenW%, screenH%, 1, RGB(10, 5, 5)

    ' Draw spiral on screen
    centerX% = screenW% \ 2
    centerY% = screenH% \ 2
    numRings% = 8

    For ringIdx% = 0 To numRings% - 1
      radius% = (ringIdx% + 1) * (Min(screenW%, screenH%) \ (numRings% * 2))
      angle% = (spiralAngle% + ringIdx% * 45) Mod 360

      spiralX% = centerX% + Int(Cos(Rad(angle%)) * radius%)
      spiralY% = centerY% + Int(Sin(Rad(angle%)) * radius%)

      ' Color based on ring
      intensity% = 200 - (ringIdx% * 20)
      If intensity% < 100 Then intensity% = 100

      rCol% = 255
      gCol% = 150 - (ringIdx% * 15)
      If gCol% < 0 Then gCol% = 0
      bCol% = 0

      rAdj% = (rCol% * intensity% * brightness%) \ 65025
      gAdj% = (gCol% * intensity% * brightness%) \ 65025
      bAdj% = 0

      Circle spiralX%, spiralY%, 8 - ringIdx%, 1, 1, RGB(rAdj%, gAdj%, bAdj%)
    Next ringIdx%
  End If

  ' Update LEDs in rotating pattern
  For i% = 0 To LEDCOUNT - 1
    ledPhase% = (spiralAngle% + i% * 45) Mod 360

    ' Brightness follows sine wave
    intensity% = Sin(Rad(ledPhase%)) * 100 + 155

    ' Warm fire colors
    rCol% = 255
    gCol% = 100 + Int((Sin(Rad(ledPhase%)) + 1) * 60)
    bCol% = 0

    rAdj% = (rCol% * intensity% * brightness%) \ 65025
    gAdj% = (gCol% * intensity% * brightness%) \ 65025
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
