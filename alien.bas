' Alien Motion Tracker on PicoCalc with Moving Targets and Fading Effect
Option DEFAULT INTEGER
Const cx = 160, cy = 160
Const r = 120
Const gridRedrawFrames = 1 ' Reduced number of frames to redraw grid lines after crossing a cardinal point
Const trailLength = 20 ' Length of the fading trail (how many degrees to fade over)
Const fadeSpeed = 5 ' Speed at which targets fade to black
Const redrawCirclesInterval = 4 ' Redraw circles every 4 sweeps

' Clear the screen and set the radar grid
CLS
Color RGB(0, 64, 0)
Circle cx, cy, r
Circle cx, cy, r - 20
Circle cx, cy, r - 40
Line cx - r, cy, cx + r, cy
Line cx, cy - r, cx, cy + r

' Fake target positions
Dim targets(2, 1)  ' 3 targets (indexes 0 to 2), each with x and y coordinates
Dim targetFade(3)  ' Array to track target fade levels (3 targets)
Dim targetTimers(3) ' Array to track time to fade before moving the target
targets(0, 0) = 100 : targets(0, 1) = 30
targets(1, 0) = -60 : targets(1, 1) = 90
targets(2, 0) = 20 : targets(2, 1) = -100

' Define target movement speeds
Dim targetSpeeds(3, 1)
targetSpeeds(0, 0) = 1 : targetSpeeds(0, 1) = -1 ' Target 0 moves at 1, -1 (dx, dy)
targetSpeeds(1, 0) = -1 : targetSpeeds(1, 1) = 1  ' Target 1 moves at -1, 1
targetSpeeds(2, 0) = 0 : targetSpeeds(2, 1) = 2  ' Target 2 moves at 0, 2

sweepAngle = 0
gridRedrawCount = 0
circleRedrawCount = 0

Do
    ' Redraw the circles every few sweeps to avoid erasing by sweep or targets
    If circleRedrawCount = 0 Then
        ' Clear previous sweep and target markings
        Color RGB(0, 64, 0)
        Circle cx, cy, r
        Circle cx, cy, r - 20
        Circle cx, cy, r - 40
        Line cx - r, cy, cx + r, cy
        Line cx, cy - r, cx, cy + r
    End If

    ' Increment the redraw counter, resetting it every redraw interval
    circleRedrawCount = (circleRedrawCount + 1) Mod redrawCirclesInterval

    ' Draw the current sweep line (brightest)
    Color RGB(0, 255, 0)
    x2 = cx + r * Cos(Rad(sweepAngle))
    y2 = cy + r * Sin(Rad(sweepAngle))
    Line cx, cy, x2, y2

    ' Draw the trailing fade (45-degree trail that fades from bright to black)
    For i = 1 To trailLength
        angle = sweepAngle - (i * 1) ' Draw trail lines 1 degree behind each step
        If angle < 0 Then angle = angle + 360

        ' Calculate fade amount based on distance from current sweep angle
        fadeAmount = 255 - (i * (255 / trailLength)) ' Gradual fade to black

        ' Draw trail lines with decreasing brightness
        Color RGB(0, fadeAmount, 0)
        x2 = cx + r * Cos(Rad(angle))
        y2 = cy + r * Sin(Rad(angle))
        Line cx, cy, x2, y2
    Next

    ' Check if the last part of the trail crosses the cardinal points
    If (sweepAngle + trailLength) Mod 360 >= 2 And (sweepAngle + trailLength) Mod 360 < 92 Then
        gridRedrawCount = gridRedrawFrames ' Start redrawing grid lines for fewer frames
    End If
    If (sweepAngle + trailLength) Mod 360 >= 92 And (sweepAngle + trailLength) Mod 360 < 182 Then
        gridRedrawCount = gridRedrawFrames
    End If
    If (sweepAngle + trailLength) Mod 360 >= 182 And (sweepAngle + trailLength) Mod 360 < 272 Then
        gridRedrawCount = gridRedrawFrames
    End If
    If (sweepAngle + trailLength) Mod 360 >= 272 And (sweepAngle + trailLength) Mod 360 < 360 Then
        gridRedrawCount = gridRedrawFrames
    End If

    ' Redraw grid lines if in the "grid redraw" phase
    If gridRedrawCount > 0 Then
        Color RGB(0, 64, 0)
        Line cx - r, cy, cx + r, cy ' Horizontal
        Line cx, cy - r, cx, cy + r ' Vertical
        gridRedrawCount = gridRedrawCount - 1 ' Decrease the redraw counter
    End If

    ' Draw targets and handle their fading
    For i = 0 To 2
        tx = cx + targets(i, 0)
        ty = cy + targets(i, 1)
        dx = tx - cx
        dy = ty - cy

        ' Calculate angle to target
        If dx = 0 Then
            If dy > 0 Then
                a = 90
            Else
                a = 270
            End If
        Else
            a = Deg(Atn(dy / dx))
            If dx < 0 Then
                a = a + 180
            ElseIf dy < 0 Then
                a = a + 360
            End If
        End If

        ' Ensure angle is within 0-360 degrees
        If a < 0 Then a = a + 360

        ' Determine proximity to sweep angle
        diff = Abs(a - sweepAngle)
        If diff > 180 Then diff = 360 - diff

        ' If the sweep angle is near the target, light it up
        If diff < 5 And targetFade(i) = 0 Then
            ' Set target to full brightness immediately when lit up
            targetFade(i) = 255
            targetTimers(i) = 180 ' Set a timer for 180 degrees to start fading

            ' Play tone when target is found
            Play TONE 1000, 1200, 500 ' Play 1000Hz on left channel and 1200Hz on right channel for 500ms
        ElseIf targetFade(i) > 0 Then
            ' Gradually fade the target as soon as it is lit up
            targetFade(i) = targetFade(i) - fadeSpeed
        End If

        ' Draw target with fading effect (green)
        Color RGB(0, targetFade(i), 0)
        Circle tx, ty, 3, 3

        ' Move target if it's fully faded (completely black)
        If targetFade(i) <= 0 Then
            ' Move target to a random new location within the radar circle
            targets(i, 0) = Int(Rnd * 2 * r) - r
            targets(i, 1) = Int(Rnd * 2 * r) - r
            ' Reset fade level to start the fade over for next cycle
            targetFade(i) = 0
        End If
    Next

    ' Stop any sounds
    Play STOP

    ' Move the sweep angle forward
    sweepAngle = sweepAngle + 2
    If sweepAngle >= 360 Then sweepAngle = 0

    ' Speed optimization: reduce the pause to speed things up
    'PAUSE 20
Loop
