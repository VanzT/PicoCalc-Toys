' Alien Nostromo Display with Animated Tunnel Draw (12-Slice Looping)
CLS
Font 1

' === Initial color for lines/shapes ===
Colour RGB(0,128,128)

' === Frame and Title ===
Colour RGB(0,255,255)
Box 0, 0, 319, 319
For v = 1 To 5
  Colour RGB(0,255,255)
  Text 70, 10, "-=APPROACH PARK ORBIT=-"
  Pause 500
  Colour RGB(0,0,0)
  Text 70, 10, "-=APPROACH PARK ORBIT=-"
  Pause 300
Next
Colour RGB(0,255,255)
Text 70, 10, "-=APPROACH PARK ORBIT=-"
Pause 500

' === Crosshairs ===
GoSub draw_crosshairs
Pause 1000
GoSub erase_crosshairs
Pause 1000
GoSub draw_crosshairs
Pause 1000
For v = 1 To 5
  GoSub erase_crosshairs
  Pause 100
  GoSub draw_crosshairs
  Pause 100
Next
GoSub draw_crosshairs
Pause 500

' === Planet ===
planetX = 320
planetY = 160
planetR = 140
Colour RGB(0,128,128)
Circle planetX, planetY, planetR
Pause 300

' Latitude lines
For pi_lat = -120 To 120 Step 30
  y = planetY + pi_lat
  w = Sqr(1 - (pi_lat / planetR)^2) * planetR
  x1 = planetX - w
  x2 = planetX + w
  Line x1, y, x2, y
  GoSub draw_crosshairs
  Colour RGB(0,128,128)
  Pause 100
Next

' Smoothed Longitude lines (now 6 total: -40 to +60)
For angle = -80 To 0 Step 10
  a = Rad(angle)
  prevX = -1: prevY = -1
  For pj = -planetR To planetR Step 4
    If Abs(pj) < planetR Then
      y = planetY + pj
      x = Cos(a) * Sqr(1 - (pj / planetR)^2) * planetR
      px = planetX - x
      py = y
      If prevX <> -1 Then
        ' Draw tail in dim blue
        Colour RGB(0,128,128)
        Line prevX, prevY, px, py
        ' Draw head segment in white
        Colour RGB(255,255,255)
        Line px, py, px, py  ' Just a single point at the end
      EndIf
      prevX = px: prevY = py
    EndIf
    GoSub draw_crosshairs
  Next
Next

GoSub draw_crosshairs

GoSub draw_text_init

' === Mini Orb: Sine-wave coastlines inside planet ===
' Ocean base
Colour RGB(0,180,180)
Circle 270, 190, 20

' Wavy coastlines
For band = -8 To 8 Step 4
  amp = 3 + Int(Rnd * 2)  ' Amplitude of wave
  freq = 0.3 + Rnd * 0.2  ' Frequency variation
  Colour RGB(0,150 + Int(Rnd * 50), 0) ' Dim green variation

  For x = -18 To 18 Step 1
    px1 = 270 + x
    py1 = 190 + band + Sin(x * freq) * amp
    px2 = 270 + x + 1
    py2 = 190 + band + Sin((x + 1) * freq) * amp
    Line px1, py1, px2, py2
  Next
  ' === Landing site marker (beacon) ===
  Colour RGB(255,0,0)
  For r = 2 To 1 Step -1
    Circle 275, 200, r
  Next
Next




' === Animated Tunnel Loop ===
Const NUM_SLICES = 12
Dim sliceScale(NUM_SLICES)
Dim sliceAngle(NUM_SLICES)

vanishX = 140
vanishY = 160

' Precompute spiral layout
For i = 0 To NUM_SLICES - 1
  sliceScale(i) = 1.2 - i * 0.1  ' 2 larger in front, 2 smaller in back
  sliceAngle(i) = i * 10
Next
Pause 1000
Do
  GoSub draw_text
  ' === Draw all spiral slices at full brightness ===
  For i = 0 To NUM_SLICES - 1
    Colour RGB(0,255,255)
    GoSub draw_slice
    Pause 200
  Next
  Colour RGB(0,128,128)
  'GoSub draw_longitude

  ' === Draw same spiral slices dimmed ===
  For i = 0 To NUM_SLICES - 1
    Colour RGB(0,64,64)
    GoSub draw_slice
    Pause 200
  Next
  Colour RGB(0,128,128)
  'GoSub draw_longitude

  ' === Erase (black) ===
  For i = 0 To NUM_SLICES - 1
    Colour RGB(0,0,0)
    GoSub draw_slice
    If i = NUM_SLICES - 1 Then
      Colour RGB(0,128,128)
      GoSub draw_longitude
      Colour RGB(0,0,0)
      For fade = 180 To 0 Step -20
        Colour RGB(fade, 0, 0)
        For r = 4 To 1 Step -1
          Circle cx, cy, r
        Next
        Pause 50
      Next

    EndIf
    Pause 100
  Next
  k$ = Inkey$
  If k$ <> "" Then 
    cls
    End
  EndIf
  Pause 1500
Loop

' === Redraw Longitude Lines Only ===
draw_longitude:
  For angle = 0 To 50 Step 10 ' Only the 4 leftmost longitudes
    a = Rad(angle)
    prevX = -1: prevY = -1
    For pj = -planetR To planetR Step 4
      If Abs(pj) < planetR Then
        y = planetY + pj
        x = Cos(a) * Sqr(1 - (pj / planetR)^2) * planetR
        px = planetX - x
        py = y
        If prevX <> -1 Then Line prevX, prevY, px, py
        prevX = px: prevY = py
      EndIf
    Next
  Next
GoSub draw_text
Return

' === Redraw Crosshairs ===
draw_crosshairs:
  Colour RGB(0,255,255)
  Line 15, 30, 15, 50: Line 5, 40, 25, 40
  Line 305, 30, 305, 50: Line 295, 40, 315, 40
  Line 15, 270, 15, 290: Line 5, 280, 25, 280
  Line 305, 270, 305, 290: Line 295, 280, 315, 280
Return


' === Erase Crosshairs ===
erase_crosshairs:
  Colour RGB(0,0,0)
  Line 15, 30, 15, 50: Line 5, 40, 25, 40
  Line 305, 30, 305, 50: Line 295, 40, 315, 40
  Line 15, 270, 15, 290: Line 5, 280, 25, 280
  Line 305, 270, 305, 290: Line 295, 280, 315, 280
Return

' === Occasional horizontal scanline glitch ===
scanline_glitch:
  If Rnd < 0.52 Then
    y = Int(Rnd * 320)
    Colour RGB(0,255,255)
    Line 0, y, 319, y
    Pause 20
    Colour RGB(0,0,0)
    Line 0, y, 319, y
    GoSub draw_text
    GoSub draw_crosshairs
  EndIf
Return

' === Redraw Green Text ===
draw_text:
  Colour RGB(0,255,0)
  textX = 240
  ty = 35: Text textX, ty, "TIME TO"
  ty = ty + 15: Text textX, ty, "00341.1"
  ty = ty + 20: Text textX, ty, "PRESENT"
  ty = ty + 15: Text textX, ty, "P.O.B"
  ty = ty + 15: Text textX, ty, "NOSTROMO"
  ty = ty + 15: Text textX, ty, "COMPLETE"
  ty = ty + 20: Text textX, ty, "REVERSE"
  ty = ty + 15: Text textX, ty, "SLOW"
  Text textX, 220, "SYSTEM 1"
  Text textX, 235, "SYSTEM 2"
  Text textX, 250, "SYSTEM 3"
Return

' === Draw Initial Green Text ===
draw_text_init:
  Colour RGB(0,255,0)
  textX = 240
  ty = 35: Text textX, ty, "TIME TO"
  Pause 700
  ty = ty + 15: Text textX, ty, "00341.1"
  Pause 500
  ty = ty + 20: Text textX, ty, "PRESENT"
  Pause 300
  ty = ty + 15: Text textX, ty, "P.O.B"
  Pause 200
  ty = ty + 15: Text textX, ty, "NOSTROMO"
  Pause 200
  ty = ty + 15: Text textX, ty, "COMPLETE"
  Pause 50
  ty = ty + 20: Text textX, ty, "REVERSE"
  Pause 50
  ty = ty + 15: Text textX, ty, "SLOW"
  Pause 300
  Text textX, 220, "SYSTEM 1"
  Pause 50
  Text textX, 235, "SYSTEM 2"
  Pause 50
  Text textX, 250, "SYSTEM 3"
Return

' === Slice Draw Routine ===
draw_slice:
  s = sliceScale(i)
  a = sliceAngle(i) - 20
  tw = 160 * s
  th = 100 * s

  dx = Cos(Rad(a))
  dy = Sin(Rad(a))

  cx = vanishX - 20 + i * 5
  a = a - 20
  cy = vanishY

  x1 = cx + (-tw/2 * dx - th/2 * dy)
  y1 = cy + (-tw/2 * dy + th/2 * dx)
  x2 = cx + ( tw/2 * dx - th/2 * dy)
  y2 = cy + ( tw/2 * dy + th/2 * dx)
  x3 = cx + ( tw/2 * dx + th/2 * dy)
  y3 = cy + ( tw/2 * dy - th/2 * dx)
  x4 = cx + (-tw/2 * dx + th/2 * dy)
  y4 = cy + (-tw/2 * dy - th/2 * dx)

  Line x1, y1, x2, y2
  Line x2, y2, x3, y3
  Line x3, y3, x4, y4
  Line x4, y4, x1, y1
  ' === Beacon ===
  If i = NUM_SLICES - 1 Then
    brightness = 180 + (Timer Mod 3) * 25 ' blink brightness 180230
    Colour RGB(brightness, 0, 0)
    For r = 4 To 1 Step -1
      Circle cx, cy, r
    Next
    Colour RGB(0,128,128)
  EndIf
Return
