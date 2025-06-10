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

' === Clear Screen ===
COLOR bgColor, bgColor
CLS
COLOR RGB(255,255,255), bgColor

' === Triangle Coordinate Arrays ===
DIM x%(2), y%(2)

' === Draw Triangle Points ===
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

' === Draw Center Bar ===
xx = X_OFFSET + 6 * POINT_W
LINE xx, 0, xx, H, BAR_W, barColor

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

  ' === Draw Pips for Static Roll (5 and 6) ===
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

' === Initial Dice Draw ===
RANDOMIZE TIMER
turnIsWhite = 0
d1 = 5
d2 = 6
DrawDice(turnIsWhite)


' === Draw Right Bear-off Tray ===
trayX = X_OFFSET + 12 * POINT_W + BAR_W
LINE trayX, 0, trayX, H, TRAY_W, trayColor



' === Checker Setup ===
DIM pieces(23)
pieces(24 - 24) = 2
pieces(24 - 13) = 5
pieces(24 - 8)  = 3
pieces(24 - 6)  = 5
pieces(24 - 1)  = -2
pieces(24 - 12) = -5
pieces(24 - 17) = -3
pieces(24 - 19) = -5

' === Draw Checkers ===
FOR i = 0 TO 23
  num = ABS(pieces(i))
  IF pieces(i) = 0 THEN GOTO SkipDraw

  IF pieces(i) > 0 THEN
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

' === Handle Dice Roll on Spacebar ===
DO
  k$ = INKEY$
  IF k$ = " " THEN
    d1 = INT(RND * 6) + 1
    d2 = INT(RND * 6) + 1
    turnIsWhite = 1 - turnIsWhite
    DrawDice(turnIsWhite)
  ENDIF
LOOP
  ELSE
    FOR j = 0 TO num - 1
      yy = H - PIECE_R - 2 - j * (PIECE_R * 2 + 2)
      CIRCLE xx, yy, PIECE_R, 1, , border, fill
    NEXT
  ENDIF

SkipDraw:
NEXT
