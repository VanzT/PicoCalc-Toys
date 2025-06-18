' Backgammon board for PicoCalc with 18px bar and tray, with screen flipping support

' === Constants ===
CONST W = 320
CONST H = 320
CONST BAR_INDEX = 24
CONST POINT_W = 23.666
CONST BAR_W = 18
CONST TRAY_W = 18
CONST TRI_HEIGHT = 100
CONST PIECE_R = 8
X_OFFSET = 0  ' Align left

' === Color Definitions ===
bgColor        = RGB(170,150,120)
barColor       = RGB(200,200,200)
trayColor      = RGB(120,100,80)
edgeColor      = RGB(80,80,80)
triColor1      = RGB(210,180,140)
triColor2      = RGB(255,255,255)
cursorColor    = RGB(255,0,0)
selectedCursorColor = RGB(0,255,0)

' === Set up game ===
DIM pieces(23)
DIM d1, d2, m1, m2
DIM whiteBar, blackBar
DIM x%(2), y%(2)
DIM state          ' 0=not rolled, 1=rolled, 2=no more moves
DIM hasPicked
DIM cursorIndex, pickedPoint
DIM validPoints(23), cursorSeq(23)

turnIsWhite = 1
canRoll = 1
RANDOMIZE TIMER

' === Initial Draw ===
ClearScreen
DrawBoard
DrawBearTray
InitPieces pieces()
DrawCenterBar
DrawCheckers pieces()
DrawDice turnIsWhite
BuildValidPoints pieces(), validPoints(), turnIsWhite
FOR i = 0 TO 23
  cursorSeq(i) = i
NEXT
hasPicked = 0
pickedPoint = -1
cursorIndex = 0
DO WHILE validPoints(cursorIndex) = 0
  cursorIndex = cursorIndex + 1
LOOP

' === Main Loop ===
DO
  k$ = INKEY$

  SELECT CASE k$
    CASE " "
      IF canRoll = 1 THEN 
        RollDice
        BuildValidPoints pieces(),validPoints(),turnIsWhite
        hasPicked = 0
        FOR i = 0 TO 23
          IF validPoints(i) THEN
            cursorIndex = i
            EXIT FOR
          ENDIF
        NEXt
      endif 

    CASE "T", "t"
      IF canRoll = 0 THEN EndTurn 'AND m1 = 0 AND m2 = 0 

    CASE "C", "c"
      IF state <> 0 THEN DoOver

    CASE CHR$(130), CHR$(128), CHR$(131), CHR$(129)
      IF canRoll = 0 THEN NavigateCursor  ' left/up/right/down

    CASE CHR$(13)
      if canRoll = 0 THEN PickDrop

  END SELECT

LOOP  ' Main Loop

SUB RollDice
  rolls = INT(RND * 8) + 11
  FOR i = 1 TO rolls
    d1 = INT(RND * 6) + 1
    d2 = INT(RND * 6) + 1
    DrawDice turnIsWhite
  PAUSE 80
  NEXT
  m1 = d1
  m2 = d2
  canRoll = 0
end SUB

' === Navigate Cursor Subroutine ===
SUB NavigateCursor
  LOCAL newIdx, row, col, colVis
  LOCAL keyChar$  ' string to hold key press

  ' Erase old cursor
  DrawCursor cursorIndex, 1
  ' Determine row (visual) and raw column
  row = cursorIndex \ 12    ' 0 = top row, 1 = bottom row
  col = cursorIndex MOD 12
  ' Convert to visual column for top row inversion
  IF row = 0 THEN
    colVis = 11 - col
  ELSE
    colVis = col
  ENDIF

  ' Read key and invert if it's brown's turn
  keyChar$ = k$
  IF NOT turnIsWhite THEN
    IF keyChar$ = CHR$(130) THEN
      keyChar$ = CHR$(131)
    ELSEIF keyChar$ = CHR$(131) THEN
      keyChar$ = CHR$(130)
    ELSEIF keyChar$ = CHR$(128) THEN
      keyChar$ = CHR$(129)
    ELSEIF keyChar$ = CHR$(129) THEN
      keyChar$ = CHR$(128)
    ENDIF
  ENDIF

  ' Handle directional input on normalized keyChar$
  IF keyChar$ = CHR$(130) THEN       ' Left
    colVis = (colVis - 1 + 12) MOD 12
  ELSEIF keyChar$ = CHR$(131) THEN   ' Right
    colVis = (colVis + 1) MOD 12
  ELSEIF keyChar$ = CHR$(129) THEN   ' Down
    IF row = 0 THEN row = 1
  ELSEIF keyChar$ = CHR$(128) THEN   ' Up
    IF row = 1 THEN row = 0
  ENDIF

  ' Compute new index from visual coords
  IF row = 0 THEN
    newIdx = 11 - colVis
  ELSE
    newIdx = 12 + colVis
  ENDIF

  cursorIndex = newIdx
  ' Draw new cursor
  DrawCursor cursorIndex, 0
END SUB





' === Pick or Drop Subroutine ===
SUB PickDrop
  LOCAL iFlash
  ' If nothing picked yet, attempt pick up
  IF hasPicked = 0 THEN
    ' Check for correct-color piece
    IF (turnIsWhite AND pieces(cursorIndex) > 0) OR (NOT turnIsWhite AND pieces(cursorIndex) < 0) THEN
      pickedPoint = cursorIndex
      ' Remove one checker from board
      IF turnIsWhite THEN
        pieces(pickedPoint) = pieces(pickedPoint) - 1
      ELSE
        pieces(pickedPoint) = pieces(pickedPoint) + 1
      ENDIF
      hasPicked = 1
      ' Redraw to remove the picked checker
      ClearScreen
      DrawBoard
      DrawBearTray
      DrawCheckers pieces()
      DrawCenterBar
      DrawDice turnIsWhite
      ' Show picked cursor in selected color
      DrawCursor cursorIndex, 0
    ELSE
      ' Invalid pick: flash cursor three times
      FOR iFlash = 1 TO 3
        DrawCursor cursorIndex, 1 : PAUSE 100
        DrawCursor cursorIndex, 0 : PAUSE 100
      NEXT
    ENDIF
  ELSE
    ' Drop-off logic to be implemented
  ENDIF
END SUB

SUB DoOver
  FOR i = 0 TO 23: pieces(i) = backupPieces(i): NEXT
  m1 = backupM1: m2 = backupM2: whiteBar = backupWhiteBar: blackBar = backupBlackBar
  canRoll = 0: state = 1: hasPicked = 0
  BuildValidPoints pieces(), validPoints(), turnIsWhite
  ClearScreen: DrawBoard: DrawBearTray: DrawCheckers pieces(): DrawCenterBar: DrawDice turnIsWhite
  FOR i = 0 TO 23: cursorIndex = i: EXIT FOR IF validPoints(i): NEXT
  DrawCursor cursorIndex, 0
END SUB

' === Clear Screen ===
SUB ClearScreen 
  COLOR bgColor, bgColor
  CLS
  COLOR RGB(255,255,255), bgColor
END SUB

' === Draw Board Subroutine ===
SUB DrawBoard
  LOCAL i, col, xx, colr
  FOR i = 0 TO 11
    col = 11 - i
    xx = X_OFFSET + col * POINT_W + (col \ 6) * BAR_W
    IF i MOD 2 = 0 THEN
      colr = triColor1
    ELSE
      colr = triColor2
    ENDIF
    x%(0) = FX(xx)
    y%(0) = FY(0)
    x%(1) = FX(xx + POINT_W)
    y%(1) = FY(0)
    x%(2) = FX(xx + POINT_W / 2)
    y%(2) = FY(TRI_HEIGHT)
    POLYGON 3, x%(), y%(), colr, colr
    x%(0) = FX(xx)
    y%(0) = FY(H)
    x%(1) = FX(xx + POINT_W)
    y%(1) = FY(H)
    x%(2) = FX(xx + POINT_W / 2)
    y%(2) = FY(H - TRI_HEIGHT)
    POLYGON 3, x%(), y%(), colr, colr
  NEXT
END SUB

' === Draw Cursor Subroutine ===
SUB DrawCursor(posi, erase)
  LOCAL row, col, colVis, baseX, leftX, rightX, cy, colr
  row = posi \ 12
  col = posi MOD 12
  IF row = 0 THEN
    colVis = 11 - col
  ELSE
    colVis = col
  ENDIF
  baseX = X_OFFSET + colVis * POINT_W + (colVis \ 6) * BAR_W
  leftX = FX(baseX + POINT_W / 2 - 6)
  rightX = FX(baseX + POINT_W / 2 + 6)
  IF erase THEN
    colr = bgColor
  ELSEIF hasPicked = 1 THEN
    colr = selectedCursorColor
  ELSE
    colr = cursorColor
  ENDIF
  IF row = 0 THEN
    cy = TRI_HEIGHT + 11
  ELSE
    cy = H - TRI_HEIGHT - 11
  ENDIF
  cy = FY(cy)
  LINE leftX, cy, rightX, cy, 4, colr
END SUB

' === Draw Dice Subroutine ===
SUB DrawDice(turnIsWhite)
  LOCAL x1, x2, y, fillCol, pipCol
  y = 150
  IF turnIsWhite THEN
    fillCol = RGB(240,240,220)
    pipCol = RGB(0,0,0)
    x1 = 200
    x2 = 234
  ELSE
    fillCol = RGB(100,60,20)
    pipCol = RGB(255,255,255)
    x1 = 56
    x2 = 90
  ENDIF
  RBOX x1, y, 24, 24, 4, RGB(0,0,0), fillCol
  RBOX x2, y, 24, 24, 4, RGB(0,0,0), fillCol
  DrawDiePips x1, y, d1, pipCol
  DrawDiePips x2, y, d2, pipCol
END SUB

' === Draw Die Pips Subroutine ===
SUB DrawDiePips(x, y, val, col)
  LOCAL cx, cy, r
  r = 2
  cx = x + 12
  cy = y + 12
  SELECT CASE val
    CASE 1
      CIRCLE cx, cy, r, , , col, col
    CASE 2
      CIRCLE x + 6, y + 6, r, , , col, col
      CIRCLE x + 18, y + 18, r, , , col, col
    CASE 3
      CIRCLE x + 6, y + 6, r, , , col, col
      CIRCLE cx, cy, r, , , col, col
      CIRCLE x + 18, y + 18, r, , , col, col
    CASE 4
      CIRCLE x + 6, y + 6, r, , , col, col
      CIRCLE x + 18, y + 6, r, , , col, col
      CIRCLE x + 6, y + 18, r, , , col, col
      CIRCLE x + 18, y + 18, r, , , col, col
    CASE 5
      CIRCLE x + 6, y + 6, r, , , col, col
      CIRCLE x + 18, y + 6, r, , , col, col
      CIRCLE cx, cy, r, , , col, col
      CIRCLE x + 6, y + 18, r, , , col, col
      CIRCLE x + 18, y + 18, r, , , col, col
    CASE 6
      CIRCLE x + 6, y + 6, r, , , col, col
      CIRCLE x + 18, y + 6, r, , , col, col
      CIRCLE x + 6, cy, r, , , col, col
      CIRCLE x + 18, cy, r, , , col, col
      CIRCLE x + 6, y + 18, r, , , col, col
      CIRCLE x + 18, y + 18, r, , , col, col
  END SELECT
END SUB

' === Draw Bear-off Tray Subroutine ===
SUB DrawBearTray
  LOCAL trayX
  IF screenFlipped THEN
    trayX = W - (X_OFFSET + 12 * POINT_W + BAR_W + TRAY_W)
  ELSE
    trayX = X_OFFSET + 12 * POINT_W + BAR_W
  ENDIF
  LINE trayX, 0, trayX, H, TRAY_W, trayColor
END SUB

' === Draw Center Bar Subroutine ===
SUB DrawCenterBar
  LOCAL rawX, xLine, circleX, j, cy, border, fill, centerY, offsetY
  ' Compute raw X position of center bar region start
  rawX = X_OFFSET + 6 * POINT_W
  ' Determine drawn X for bar line: left edge of bar
  IF screenFlipped THEN
    xLine = W - (rawX + BAR_W)
  ELSE
    xLine = rawX
  ENDIF
  LINE xLine, 0, xLine, H, BAR_W, barColor
  ' Compute circle X (center of bar)
  circleX = xLine + BAR_W / 2
  centerY = H / 2
  ' Draw white captured pieces above center
  border = RGB(0,0,0): fill = RGB(240,240,220)
  FOR j = 1 TO whiteBar
    offsetY = j * (PIECE_R * 2 + 2)
    cy = centerY - offsetY + PIECE_R
    cy = FY(cy)
    CIRCLE circleX, cy, PIECE_R, 1, , border, fill
  NEXT
  ' Draw black captured pieces below center
  border = RGB(0,60,20): fill = RGB(100,60,20)
  FOR j = 1 TO blackBar
    offsetY = j * (PIECE_R * 2 + 2)
    cy = centerY + offsetY - PIECE_R
    cy = FY(cy)
    CIRCLE circleX, cy, PIECE_R, 1, , border, fill
  NEXT
END SUB

SUB InitPieces(p())
  ' Clear all points
  FOR i = 0 TO 23: p(i) = 0: NEXT
  ' Place starting checkers:
  ' Two white on space 24 (upper-right) ? index 0
  p(0) = 2
  ' Five white on space 13 ? index 11
  p(11) = 5
  ' Three white on space 8 ? index 16
  p(16) = 3
  ' Five white on space 6 ? index 18
  p(18) = 5
  ' Two black on space 1 (lower-right) ? index 23
  p(23) = -2
  ' Five black on space 12 ? index 12
  p(12) = -5
  ' Three black on space 17 ? index 7
  p(7) = -3
  ' Five black on space 19 ? index 5
  p(5) = -5
END SUB

' === Build Valid Points ===
SUB BuildValidPoints(p(), v(), isWhite)
  LOCAL i
  ' Allow cursor to move to any space; mark all points as valid
  FOR i = 0 TO 23
    v(i) = 1
  NEXT
END SUB

' === Draw Checkers Subroutine ===
SUB DrawCheckers(p())
  LOCAL i, j, num, col, row, xx, yy, border, fill
  FOR i = 0 TO 23
    num = ABS(p(i))
    IF p(i) = 0 THEN GOTO SkipDraw
    IF p(i) > 0 THEN
      border = RGB(0,0,0)
      fill   = RGB(240,240,220)
    ELSE
      border = RGB(0,60,20)
      fill   = RGB(100,60,20)
    ENDIF
    row = i \ 12
    col = i MOD 12
    xx = X_OFFSET + col * POINT_W + (col \ 6) * BAR_W + POINT_W / 2
    IF row = 0 THEN
      col = 11 - col
      xx = X_OFFSET + col * POINT_W + (col \ 6) * BAR_W + POINT_W / 2
      FOR j = 0 TO num - 1
        yy = PIECE_R + 2 + j * (PIECE_R * 2 + 2)
        CIRCLE FX(xx), FY(yy), PIECE_R, 1, , border, fill
      NEXT
    ELSE
      FOR j = 0 TO num - 1
        yy = H - PIECE_R - 2 - j * (PIECE_R * 2 + 2)
        CIRCLE FX(xx), FY(yy), PIECE_R, 1, , border, fill
      NEXT
    ENDIF
SkipDraw:
  NEXT
END SUB

' === End Turn Subroutine ===
SUB EndTurn
  ' Flip the screen orientation for the next player
  screenFlipped = 1 - screenFlipped
  ' Switch player
  turnIsWhite = 1 - turnIsWhite
  ' Allow rolling again
  canRoll = 1
  state = 0
  ' Redraw everything in the new orientation
  ClearScreen
  DrawBoard
  DrawBearTray
  InitPieces pieces()   ' maintain current positions
  DrawCheckers pieces()
  DrawCenterBar
  DrawDice turnIsWhite
  ' Reset valid points and cursor
  BuildValidPoints pieces(), validPoints(), turnIsWhite
  ' Position cursor at first valid location
  FOR i = 0 TO 23
    IF validPoints(i) THEN
      cursorIndex = i
      EXIT FOR
    ENDIF
  NEXT
END SUB

' === Helper Functions ===
FUNCTION FX(x)
  IF screenFlipped THEN
    FX = W - x
  ELSE
    FX = x
  ENDIF
END FUNCTION

FUNCTION FY(y)
  IF screenFlipped THEN
    FY = H - y
  ELSE
    FY = y
  ENDIF
END FUNCTION
