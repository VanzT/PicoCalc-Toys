Const WIDTH = 320
Const HEIGHT = 320
Const COL_WIDTH = 8
Const CHAR_HEIGHT = 10
Const NUM_COLS = WIDTH \ COL_WIDTH
Const TRAIL_LENGTH = 16
Const MAX_ACTIVE_COLS = 8 ' Max number of active columns

Dim colY(NUM_COLS)
Dim colMode(NUM_COLS) ' 0=idle, 1=raining, -1=blanking
Dim colSpeed(NUM_COLS) ' pixels per frame
Dim fadeRGB(TRAIL_LENGTH)

' Precalculate fade shades for raindrop (from bright to 45)
For i = 0 To TRAIL_LENGTH - 1
  brightness = 255 - (i * (230 \ TRAIL_LENGTH)) ' Start bright and fade to 45
  If brightness < 45 Then brightness = 45 ' Minimum brightness is 45
  fadeRGB(i) = RGB(0, brightness, 0) ' Fading green trail for raindrop
Next i

CLS
Font 1
Text 0, 0, ""
Randomize Timer

Do
  activeCount = 0

  ' Count active columns
  For i = 0 To NUM_COLS - 1
    If colMode(i) <> 0 Then activeCount = activeCount + 1
  Next i

  ' Activate new columns up to the limit
  For i = 0 To NUM_COLS - 1
    If activeCount >= MAX_ACTIVE_COLS Then Exit For
    If colMode(i) = 0 And Rnd < 0.02 Then
      If Rnd < 0.75 Then
        colMode(i) = 1 ' raining
      Else
        colMode(i) = -1 ' blanking
      EndIf
      colY(i) = -TRAIL_LENGTH * CHAR_HEIGHT
      colSpeed(i) = 6 + Int(Rnd * 7) ' Speed between 6 and 12
      activeCount = activeCount + 1
    EndIf
  Next i

  ' Draw and update columns
  For i = 0 To NUM_COLS - 1
    If colMode(i) = 0 Then Continue For

    x = i * COL_WIDTH
    y = colY(i)

    If colMode(i) = 1 Then ' raining
      ' Trail (from brightest to 45)
      For t = 0 To TRAIL_LENGTH - 1
        ty = y - (t * CHAR_HEIGHT)
        If ty >= 0 And ty < HEIGHT Then
          Color fadeRGB(t) ' Apply fading green trail
          randTrailChar$ = Chr$(128 + Int(Rnd * 128)) ' Random character
          Text x, ty, randTrailChar$
        EndIf
      Next t

      ' Head (bright to 45)
      If y >= 0 And y < HEIGHT Then
        glitchChance = Rnd
        If glitchChance < 0.05 Then
          ' Sparkly cyan
          Color RGB(100 + Int(Rnd * 155), 255, 255)
        ElseIf glitchChance < 0.08 Then
          ' White
          Color RGB(255, 255, 255)
        Else
          ' Normal bright green
          brightness = 255 - (TRAIL_LENGTH - 1) * (230 \ TRAIL_LENGTH)
          If brightness < 45 Then brightness = 45 ' Fade to 45
          Color RGB(0, brightness, 0)
        EndIf
        randHeadChar$ = Chr$(128 + Int(Rnd * 128)) ' Random character
        Text x, y, randHeadChar$
      EndIf

    ElseIf colMode(i) = -1 Then ' blanking (from 45 to 0)
      ' Trail (from 45 to 0)
      For t = 0 To TRAIL_LENGTH - 1
        ty = y - (t * CHAR_HEIGHT)
        If ty >= 0 And ty < HEIGHT Then
          brightness = 45 - (t * (45 \ TRAIL_LENGTH)) ' Fade from 45 to 0
          If brightness < 0 Then brightness = 0 ' Minimum brightness is 0
          Color RGB(0, brightness, 0) ' Apply fading green trail for blanking
          randTrailChar$ = Chr$(128 + Int(Rnd * 128)) ' Random character
          Text x, ty, randTrailChar$
        EndIf
      Next t

      ' Head (starts at 45 and fades to 0)
      If y >= 0 And y < HEIGHT Then
        brightness = 45 - (TRAIL_LENGTH - 1) * (45 \ TRAIL_LENGTH)
        If brightness < 0 Then brightness = 0
        Color RGB(0, brightness, 0) ' Fading head from 45 to 0
        randHeadChar$ = Chr$(128 + Int(Rnd * 128)) ' Random character
        Text x, y, randHeadChar$
      EndIf

    EndIf

    ' Update position
    colY(i) = colY(i) + colSpeed(i)
    If colY(i) > HEIGHT + TRAIL_LENGTH * CHAR_HEIGHT Then
      colMode(i) = 0
    EndIf
  Next i

  Pause 10
Loop
