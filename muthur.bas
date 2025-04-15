' TRANSMISSION RECEIVED - Smooth Version
CLS
Font 1

' === Constants ===
color_green = RGB(0,255,0)
color_white = RGB(255,255,255)
color_cyan = RGB(0,255,255)
color_bg = RGB(0,0,0)

SCREEN_WIDTH = 320
SCREEN_HEIGHT = 320

' === Draw Static Elements Once ===
Colour color_green
Text 50, 10, ">> TRANSMISSION RECEIVED <<"

Colour color_white
Text 70, 295, "[ DECODING IN PROGRESS... ]"

' Glyph stream positions
Dim glyphX(10), glyphY(10)
For i = 0 To 10
  glyphX(i) = 20 + i * 28
  glyphY(i) = 120 + Int(Rnd * 50)
Next

frame = 0

' === Main Loop ===
Do
  ' === Sine Waveform (clean redraw only the line) ===
  Colour color_bg
  For x = 0 To 314 Step 4
    y1 = 80 + 20 * Sin(Rad((x + frame * 6) Mod 360))
    y2 = 80 + 20 * Sin(Rad((x + 4 + frame * 6) Mod 360))
    Line x, y1, x + 4, y2
  Next

  Colour color_cyan
  For x = 0 To 314 Step 4
    y1 = 80 + 20 * Sin(Rad((x + (frame + 1) * 6) Mod 360))
    y2 = 80 + 20 * Sin(Rad((x + 4 + (frame + 1) * 6) Mod 360))
    Line x, y1, x + 4, y2
  Next

  ' === Glyph Flicker (partial update) ===
  For i = 0 To 3 ' only update a few each frame
    col = Int(Rnd * 11)
    row = Int(Rnd * 5)
    x = glyphX(col)
    y = glyphY(col) + row * 15
    Colour color_bg
    Text x, y, "X" ' erase approx char width
    Colour color_green
    char$ = Chr$(33 + Int(Rnd * 30))
    Text x, y, char$
  Next

  ' === Signal Bar Pulse ===
  Colour color_bg
  Box 300, 180, 310, 260
  Colour color_white
  For i = 0 To 4
    If (frame Mod 8) > i Then
      Box 300, 250 - i * 15, 310, 260 - i * 15
    EndIf
  Next

  frame = frame + 1
  Pause 5
Loop Until Inkey$ <> ""
End
