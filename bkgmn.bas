' Backgammon board for PicoCalc with 18px bar and tray

' === Constants ===
CONST W = 320
CONST H = 320
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

' === Set up game ===
DIM i, rolls
DIM pieces(23)
DIM d1, d2
turnIsWhite = 0
RANDOMIZE TIMER

ClearScreen
DrawBoard
DrawBearTray
InitPieces pieces()
DrawCheckers pieces()
DrawCenterBar

' === main loop ===
DO
  k$ = INKEY$
  IF k$ = " " THEN
    rolls = INT(RND * 5) + 8  ' random between 5 and 12 rolls
    FOR i = 1 TO rolls
      d1 = INT(RND * 6) + 1
      d2 = INT(RND * 6) + 1
      DrawDice(turnIsWhite)
      PAUSE 80
    NEXT
    DrawDice(turnIsWhite)
    turnIsWhite = 1 - turnIsWhite
  ENDIF
LOOP

' === Clear Screen ===
SUB ClearScreen 
  COLOR bgColor, bgColor
  CLS
  COLOR RGB(255,255,255), bgColor
END SUB

' === Draw Board Subroutine ===
SUB DrawBoard
  LOCAL i, col, xx, colr
  DIM x%(2), y%(2)

  FOR i = 0 TO 11
    col = 11 - i
    xx = X_OFFSET + col * POINT_W + (col \ 6) * BAR_W
    IF i MOD 2 = 0 THEN colr = triColor1 ELSE colr = triColor2

    ' Top triangle
    x%(0) = xx
    y%(0) = 0
    x%(1) = xx + POINT_W
    y%(1) = 0
    x%(2) = xx + POINT_W / 2
    y%(2) = TRI_HEIGHT
    POLYGON 3, x%(), y%(), colr, colr

    ' Bottom triangle
    x%(0) = xx
    y%(0) = H
    x%(1) = xx + POINT_W
    y%(1) = H
    x%(2) = xx + POINT_W / 2
    y%(2) = H - TRI_HEIGHT
    POLYGON 3, x%(), y%(), colr, colr
  NEXT
END SUB

' === Dice Drawing Function ===
SUB DrawDice(turnIsWhite)
  LOCAL x, y, fillCol, pipCol
  x = W - TRAY_W - 24 * 2 - 10 - 50
  y = INT(H / 2 - 12)

  IF turnIsWhite THEN
    fillCol = RGB(240,240,220)
    pipCol = RGB(0,0,0)
  ELSE
    fillCol = RGB(100,60,20)
    pipCol = RGB(255,255,255)
  ENDIF
  RBOX x, y, 24, 24, 4, RGB(0,0,0), fillCol
  RBOX x + 34, y, 24, 24, 4, RGB(0,0,0), fillCol
  DrawDiePips x, y, d1, pipCol
  DrawDiePips x + 34, y, d2, pipCol
END SUB

' === Dice Pip Drawing Function ===
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

' === Draw Right Bear-off Tray ===
SUB DrawBearTray
  LOCAL trayX
  trayX = X_OFFSET + 12 * POINT_W + BAR_W
  LINE trayX, 0, trayX, H, TRAY_W, trayColor
END SUB

' === Draw Center Bar-off Tray ===
SUB DrawCenterBar
  LOCAL xx
  xx = X_OFFSET + 6 * POINT_W
  LINE xx, 0, xx, H, BAR_W, barColor
END SUB

' === Initialize Checker Setup ===
SUB InitPieces(p())
  p(0) = 2
  p(11) = 5
  p(16) = 3
  p(18) = 5
  p(23) = -2
  p(12) = -5
  p(7)  = -3
  p(5)  = -5
END SUB

' === Draw Checkers ===
SUB DrawCheckers(p())
  LOCAL i, j, num, col, row, xx, yy, border, fill
  FOR i = 0 TO 23
    num = ABS(p(i))
    IF p(i) = 0 THEN GOTO SkipDraw

    IF p(i) > 0 THEN
      border = RGB(0,0,0)
      fill   = RGB(240,240,220)
    ELSE
      border = RGB(0,0,0)
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
        CIRCLE xx, yy, PIECE_R, 1, , border, fill
      NEXT
    ELSE
      FOR j = 0 TO num - 1
        yy = H - PIECE_R - 2 - j * (PIECE_R * 2 + 2)
        CIRCLE xx, yy, PIECE_R, 1, , border, fill
      NEXT
    ENDIF
SkipDraw:
  NEXT
END SUB
