' Backgammon board for PicoCalc with 18px bar and tray, with screen flipping support

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
cursorColor    = RGB(255,0,0)

' === Helper Functions for Screen Flip ===
FUNCTION FX(x)
  IF screenFlipped THEN FX = W - x ELSE FX = x
END FUNCTION

FUNCTION FY(y)
  IF screenFlipped THEN FY = H - y ELSE FY = y
END FUNCTION

' === Set up game ===
DIM i, rolls
DIM pieces(23)
DIM d1, d2
DIM x%(2), y%(2)
DIM validPoints(23)
DIM spaceOrder(23)
DIM cursorSeq(23)
DIM leftToRight(23)
DIM rightToLeft(23)
FOR i = 0 TO 11: leftToRight(i) = 11 - i: NEXT
FOR i = 0 TO 11: leftToRight(i + 12) = i + 12: NEXT
FOR i = 0 TO 23: rightToLeft(i) = leftToRight(23 - i): NEXT
turnIsWhite = 1
canRoll = 1
screenFlipped = 0
cursorIndex = -1
RANDOMIZE TIMER

' === Opening Roll to Determine First Player ===
do
  bd = INT(RND * 6) + 1
  wd = INT(RND * 6) + 1
loop while bd = wd

if bd > wd then
  turnIsWhite = 0          ' Brown starts
  screenFlipped = 1       ' Flip board for Brown
  d1 = bd: d2 = wd        ' Opening roll dice values
else
  turnIsWhite = 1          ' White starts
  screenFlipped = 0       ' Standard orientation
  d1 = wd: d2 = bd
endif

' Display opening roll
DrawDice turnIsWhite
pause 1000

canRoll = 0



ClearScreen
DrawBoard
DrawBearTray
InitPieces pieces()
DrawCheckers pieces()
DrawCenterBar
DrawDice turnIsWhite
BuildValidPoints pieces(), validPoints(), turnIsWhite
FOR i = 0 TO 23
  cursorSeq(i) = leftToRight(i)
NEXT

FOR i = 0 TO 23
  IF validPoints(cursorSeq(i)) THEN cursorIndex = cursorSeq(i) : EXIT FOR
NEXT
'DrawDice(turnIsWhite)

' === main loop ===
DO
  k$ = INKEY$
  IF k$ = " " AND canRoll THEN
    rolls = INT(RND * 8) + 11
    FOR i = 1 TO rolls
      d1 = INT(RND * 6) + 1
      d2 = INT(RND * 6) + 1
      DrawDice(turnIsWhite)
      PAUSE 80
    NEXT
    DrawDice(turnIsWhite)
    canRoll = 0
  ENDIF

  IF (k$ = "T" OR k$ = "t") AND canRoll = 0 THEN
    turnIsWhite = 1 - turnIsWhite
    canRoll = 1
    screenFlipped = 1 - screenFlipped
    IF turnIsWhite THEN
      FOR i = 0 TO 23
        cursorSeq(i) = leftToRight(i)
      NEXT
    ELSE
      FOR i = 0 TO 23
        cursorSeq(i) = rightToLeft(i)
      NEXT
    ENDIF
    ClearScreen
    DrawBoard
    DrawBearTray
    DrawCheckers pieces()
    DrawCenterBar
    DrawDice(turnIsWhite)
    BuildValidPoints pieces(), validPoints(), turnIsWhite
    FOR i = 0 TO 23
      IF validPoints(cursorSeq(i)) THEN cursorIndex = cursorSeq(i) : EXIT FOR
    NEXT
  ENDIF

  IF k$ = CHR$(130) AND cursorIndex >= 0 THEN
    DrawCursor cursorIndex, 1 ' erase
    FOR i = 0 TO 23
      IF cursorSeq(i) = cursorIndex THEN EXIT FOR
    NEXT
    DO
      i = (i - 1 + 24) MOD 24
      cursorIndex = cursorSeq(i)
    LOOP WHILE validPoints(cursorIndex) = 0
    DrawCursor cursorIndex, 0 ' draw
  ENDIF

  IF k$ = CHR$(131) AND cursorIndex >= 0 THEN
    DrawCursor cursorIndex, 1 ' erase
    FOR i = 0 TO 23
      IF cursorSeq(i) = cursorIndex THEN EXIT FOR
    NEXT
    DO
      i = (i + 1) MOD 24
      cursorIndex = cursorSeq(i)
    LOOP WHILE validPoints(cursorIndex) = 0
    DrawCursor cursorIndex, 0 ' draw
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

  FOR i = 0 TO 11
    col = 11 - i
    xx = X_OFFSET + col * POINT_W + (col \ 6) * BAR_W
    IF i MOD 2 = 0 THEN colr = triColor1 ELSE colr = triColor2

    ' Top triangle
    x%(0) = FX(xx)
    y%(0) = FY(0)
    x%(1) = FX(xx + POINT_W)
    y%(1) = FY(0)
    x%(2) = FX(xx + POINT_W / 2)
    y%(2) = FY(TRI_HEIGHT)
    POLYGON 3, x%(), y%(), colr, colr

    ' Bottom triangle
    x%(0) = FX(xx)
    y%(0) = FY(H)
    x%(1) = FX(xx + POINT_W)
    y%(1) = FY(H)
    x%(2) = FX(xx + POINT_W / 2)
    y%(2) = FY(H - TRI_HEIGHT)
    POLYGON 3, x%(), y%(), colr, colr
  NEXT
END SUB

' === DrawCursor Subroutine ===
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
  ELSE
    colr = cursorColor
  ENDIF

  IF row = 0 THEN
    cy = TRI_HEIGHT + 11
  ELSE
    cy = H - TRI_HEIGHT - 11
  ENDIF

  cy = FY(cy)

  LINE leftX, cy, rightX, cy, 2, colr
END SUB




' === Dice Drawing Function ===
SUB DrawDice(turnIsWhite)
  LOCAL x1, x2, y, fillCol, pipCol
  y = 150

  IF NOT turnIsWhite THEN
    fillCol = RGB(100,60,20)
    pipCol = RGB(255,255,255)
    x1 = 56
    x2 = 90
  ELSE
    fillCol = RGB(240,240,220)
    pipCol = RGB(0,0,0)
    x1 = 200
    x2 = 234
  ENDIF

  RBOX x1, y, 24, 24, 4, RGB(0,0,0), fillCol
  RBOX x2, y, 24, 24, 4, RGB(0,0,0), fillCol
  DrawDiePips x1, y, d1, pipCol
  DrawDiePips x2, y, d2, pipCol
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
  IF screenFlipped THEN
    trayX = W - (X_OFFSET + 12 * POINT_W + BAR_W + TRAY_W)
  ELSE
    trayX = X_OFFSET + 12 * POINT_W + BAR_W
  ENDIF
  LINE trayX, 0, trayX, H, TRAY_W, trayColor
END SUB

' === Draw Center Bar-off Tray ===
SUB DrawCenterBar
  LOCAL xx
  IF screenFlipped THEN
    xx = 18 + X_OFFSET + 6 * POINT_W
  Else
    xx = X_OFFSET + 6 * POINT_W
  endif
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


' === Determine Valid Points ===
SUB BuildValidPoints(p(), v(), isWhite)
  LOCAL i
  FOR i = 0 TO 23
    IF isWhite AND p(i) > 0 THEN v(i) = 1 ELSE IF NOT isWhite AND p(i) < 0 THEN v(i) = 1 ELSE v(i) = 0
  NEXT
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
