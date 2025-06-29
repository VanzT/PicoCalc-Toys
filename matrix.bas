'—— Matrix Rain + 8-LED WS2812 Sync with LED On/Off Toggle — PicoMite MMBasic

'— Screen constants —
Const WIDTH = 320
Const HEIGHT = 320
Const COL_WIDTH = 8
Const CHAR_HEIGHT = 10
Const NUM_COLS = WIDTH \ COL_WIDTH
Const TRAIL_LENGTH = 16
Const MAX_ACTIVE_COLS = 8

'— LED constants & buffers —
Const LEDCOUNT = 8
Const WHITE_THRESHOLD = 250   ' threshold for white?green transition
Const FADE_STEP      = 20     ' fade step per frame (slower fade)
Dim ledBuf%(LEDCOUNT - 1)     ' WS2812 RGB buffer
Dim ledFade%(LEDCOUNT - 1)    ' per-LED fade counter (0…255)
Dim ledEnabled               ' 0 = off, 1 = on

'— Matrix state buffers —
Dim colY(NUM_COLS)            ' vertical position of head
Dim colMode(NUM_COLS)         ' 0=idle, 1=raining, –1=blanking
Dim colSpeed(NUM_COLS)        ' pixels per frame
Dim fadeRGB(TRAIL_LENGTH)     ' precomputed green fade colors

'— Precompute green fades for the rain trail —
For i = 0 To TRAIL_LENGTH - 1
  brightness = 255 - (i * (230 \ TRAIL_LENGTH))
  If brightness < 45 Then brightness = 45
  fadeRGB(i) = RGB(0, brightness, 0)
Next i

'— Initialize —
CLS
Font 1
Randomize Timer
ledEnabled = 0   ' start with LEDs active

Do
  '—— 0) Check for toggle key (L) ——
  k$ = Inkey$
  If k$ = "l" Then
    ledEnabled = 1 - ledEnabled
    If ledEnabled = 0 Then
      ' clear strip immediately when turning off
      For j% = 0 To LEDCOUNT - 1
        ledBuf%(j%) = 0
      Next j%
      Bitbang ws2812 o, GP28, LEDCOUNT, ledBuf%()
    EndIf
  EndIf

  '—— 1) Spawn new drops up to the MAX_ACTIVE_COLS limit ——
  activeCount = 0
  For i = 0 To NUM_COLS - 1
    If colMode(i) <> 0 Then activeCount = activeCount + 1
  Next i

  For i = 0 To NUM_COLS - 1
    If activeCount >= MAX_ACTIVE_COLS Then Exit For
    If colMode(i) = 0 And Rnd < 0.02 Then
      If Rnd < 0.75 Then
        colMode(i) = 1
      Else
        colMode(i) = -1
      EndIf
      colY(i) = -TRAIL_LENGTH * CHAR_HEIGHT
      colSpeed(i) = 6 + Int(Rnd * 7)
      activeCount = activeCount + 1
    EndIf
  Next i

  '—— 2) Draw each column, update positions, and trigger LEDs ——
  For i = 0 To NUM_COLS - 1
    If colMode(i) = 0 Then Continue For
    x = i * COL_WIDTH
    y = colY(i)

    If colMode(i) = 1 Then
      ' Rain trail
      For t = 0 To TRAIL_LENGTH - 1
        ty = y - t * CHAR_HEIGHT
        If ty >= 0 And ty < HEIGHT Then
          Color fadeRGB(t)
          Text x, ty, Chr$(33 + Int(Rnd * 94))
        EndIf
      Next t
      ' Rain head (with glitch chance)
      If y >= 0 And y < HEIGHT Then
        gch = Rnd
        If gch < 0.05 Then
          Color RGB(100 + Int(Rnd * 155), 255, 255)
        ElseIf gch < 0.08 Then
          Color RGB(255, 255, 255)
        Else
          baseB = 255 - (TRAIL_LENGTH - 1) * (230 \ TRAIL_LENGTH)
          If baseB < 45 Then baseB = 45
          Color RGB(0, baseB, 0)
        EndIf
        Text x, y, Chr$(33 + Int(Rnd * 94))
      EndIf

    ElseIf colMode(i) = -1 Then
      ' Blanking trail
      For t = 0 To TRAIL_LENGTH - 1
        ty = y - t * CHAR_HEIGHT
        If ty >= 0 And ty < HEIGHT Then
          b = 45 - t * (45 \ TRAIL_LENGTH)
          If b < 0 Then b = 0
          Color RGB(0, b, 0)
          Text x, ty, Chr$(33 + Int(Rnd * 94))
        EndIf
      Next t
      ' Blanking head
      If y >= 0 And y < HEIGHT Then
        b = 45 - (TRAIL_LENGTH - 1) * (45 \ TRAIL_LENGTH)
        If b < 0 Then b = 0
        Color RGB(0, b, 0)
        Text x, y, Chr$(33 + Int(Rnd * 94))
      EndIf
    EndIf

    ' Move the drop
    colY(i) = y + colSpeed(i)

    ' Only trigger on raining drops
    If colMode(i) = 1 And y < HEIGHT And colY(i) >= HEIGHT Then
      slice = i \ (NUM_COLS \ LEDCOUNT)
      ledFade%(slice) = 255
    EndIf

    ' Deactivate when fully off-screen
    If colY(i) > HEIGHT + TRAIL_LENGTH * CHAR_HEIGHT Then
      colMode(i) = 0
    EndIf
  Next i

  '—— 3) Update LED fade & pack RGB values if enabled ——
  If ledEnabled Then
    For j% = 0 To LEDCOUNT - 1
      If ledFade%(j%) > 0 Then
        If ledFade%(j%) > WHITE_THRESHOLD Then
          rVal = ledFade%(j%)
          gVal = 255
          bVal = ledFade%(j%)
        Else
          rVal = 0
          gVal = ledFade%(j%)
          bVal = 0
        EndIf
        ledBuf%(j%) = (rVal * &H10000) + (gVal * &H100) + bVal
        ledFade%(j%) = ledFade%(j%) - FADE_STEP
      Else
        ledBuf%(j%) = 0
      EndIf
    Next j%
    Bitbang ws2812 o, GP28, LEDCOUNT, ledBuf%()
  EndIf

  Pause 10
Loop
