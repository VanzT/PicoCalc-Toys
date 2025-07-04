' Backgammon board for PicoCalc - 2 player pass-the-device
' Vance Thompson June, 2025
' https://github.com/VanzT/PicoCalc-Toys

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
DIM movesLeft, dieVal, doubleFlag  ' doubles rule support
DIM d1, d2, m1, m2
DIM whiteBar, blackBar
DIM barActive, allowEnd
DIM x%(2), y%(2)
DIM state          ' 0=not rolled, 1=rolled, 2=no more moves
DIM hasPicked
DIM cursorIndex, pickedPoint
DIM validPoints(23), cursorSeq(23)
DIM whiteOff, blackOff

whiteOff = 0 
blackOff = 0
whiteCursor = 23
blackCursor = 0

turnIsWhite = 1
canRoll = 1
RANDOMIZE TIMER

DoOpeningRoll


' testing variables
' whiteBar = 1
' clear when done 


' === Initial Draw ===
ClearScreen
DrawBoard
DrawBearTray
DrawOffTrayPieces
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
  
  if (turnIsWhite AND whiteBar > 0) OR (NOT turnIsWhite AND blackBar > 0) THEN
    hasPicked = 1
  endif
  IF (doubleFlag AND movesLeft = 0) OR (NOT doubleFlag AND m1 = 0 AND m2 = 0) THEN
    DrawCursor cursorIndex, 1
  ELSE 
    DrawCursor cursorIndex, 0
  ENDIF

  SELECT CASE k$
    CASE " "
      IF canRoll = 1 THEN 
        RollDice
        BuildValidPoints pieces(),validPoints(),turnIsWhite
        hasPicked = 0
        if turnIsWhite THEN 
          cursorIndex = whiteCursor
        Else
          cursorIndex = blackCursor
        Endif 
      endif 

CASE "T","t"
  IF canRoll = 0 THEN
    legalExists = 0

    ' 1) If you have checkers on the bar, test re-entry only
    IF (turnIsWhite AND whiteBar > 0) OR (NOT turnIsWhite AND blackBar > 0) THEN
      BuildReEntryPoints pieces(), validPoints(), turnIsWhite, m1, m2
      FOR i = 0 TO 23
        IF validPoints(i) = 1 THEN
          legalExists = 1: EXIT FOR
        ENDIF
      NEXT

    ' 2) Otherwise, for each point you own, test movement with each die
    ELSE
      FOR src = 0 TO 23
        IF (turnIsWhite AND pieces(src) > 0) OR (NOT turnIsWhite AND pieces(src) < 0) THEN
          BuildMovePoints pieces(), validPoints(), turnIsWhite, src, m1, m2
          FOR dst = 0 TO 23
            IF validPoints(dst) = 1 THEN
              legalExists = 1: EXIT FOR
            ENDIF
          NEXT
          IF legalExists THEN EXIT FOR
        ENDIF
      NEXT
    ENDIF

    ' 3) If no legal moves, or you have already consumed all pips, end the turn
    IF legalExists = 0 OR (doubleFlag AND movesLeft = 0) OR (NOT doubleFlag AND m1 = 0 AND m2 = 0) THEN
      DrawCursor cursorIndex, 1
      EndTurn
    ENDIF
  ENDIF


'    CASE "C", "c"  --- maybe another day
'      IF state <> 0 THEN DoOver
    
    CASE "B", "b"
    ' Only valid if youve rolled 
    IF canRoll = 0 THEN
      bearOff
    ENDIF

    CASE CHR$(130), CHR$(128), CHR$(131), CHR$(129) ' left/up/right/down
      ' Navigate only if moves remain
      IF canRoll = 0 AND ((doubleFlag AND movesLeft > 0) OR (NOT doubleFlag AND (m1 <> 0 OR m2 <> 0))) THEN NavigateCursor  

    CASE CHR$(13), CHR$(10)
      IF canRoll = 0 AND ((turnIsWhite AND whiteBar > 0) OR (NOT turnIsWhite AND blackBar > 0)) THEN
        barOff
      Elseif canRoll = 0 AND ((doubleFlag AND movesLeft > 0) OR (NOT doubleFlag AND (m1 <> 0 OR m2 <> 0))) THEN 
        PickDrop
      endif

  END SELECT

LOOP  ' Main Loop

' === RollDice Subroutine ===
SUB RollDice
  rolls = INT(RND * 8) + 11
  FOR i = 1 TO rolls
    d1 = INT(RND * 6) + 1
    d2 = INT(RND * 6) + 1
    DrawDice(turnIsWhite)
    PAUSE 80
  NEXT
  m1 = d1
  m2 = d2
  dieVal1 = d1
  dieVal2 = d2
  IF d1 = d2 THEN
    doubleFlag = 1
    dieVal = d1
    movesLeft = 4
  ELSE
    doubleFlag = 0
    movesLeft = 2
  ENDIF
  canRoll = 0
END SUB

' === Navigate Cursor Subroutine ===
SUB NavigateCursor
  LOCAL newIdx, row, col, colVis, keyChar$

  ' Erase old cursor
  DrawCursor cursorIndex, 1

  ' Determine row (visual) and raw column
  row = cursorIndex \ 12    ' 0 = top row, 1 = bottom row
  col = cursorIndex MOD 12
  ' Convert to visual column on top row inversion
  IF row = 0 THEN
    colVis = 11 - col
  ELSE
    colVis = col
  ENDIF

  ' Read key and invert if it's brown's turn
  keyChar$ = k$
  IF NOT turnIsWhite THEN
    SELECT CASE keyChar$
      CASE CHR$(130)
        keyChar$ = CHR$(131)
      CASE CHR$(131)
        keyChar$ = CHR$(130)
      CASE CHR$(128)
        keyChar$ = CHR$(129)
      CASE CHR$(129)
        keyChar$ = CHR$(128)
    END SELECT
  ENDIF

  ' Handle directional input on unified keyChar$
  IF keyChar$ = CHR$(130) THEN       ' Left
    colVis = (colVis - 1 + 12) MOD 12
    IF row = 0 THEN
      newIdx = 11 - colVis
    ELSE
      newIdx = 12 + colVis
    ENDIF
  ELSEIF keyChar$ = CHR$(131) THEN   ' Right
    colVis = (colVis + 1) MOD 12
    IF row = 0 THEN
      newIdx = 11 - colVis
    ELSE
      newIdx = 12 + colVis
    ENDIF
  ELSEIF keyChar$ = CHR$(129) THEN   ' Down
    IF row = 0 THEN
      newIdx = 12 + colVis
    ELSE
      newIdx = cursorIndex
    ENDIF
  ELSEIF keyChar$ = CHR$(128) THEN   ' Up
    IF row = 1 THEN
      newIdx = 11 - colVis
    ELSE
      newIdx = cursorIndex
    ENDIF
  ELSE
    newIdx = cursorIndex
  ENDIF

  cursorIndex = newIdx
  ' Draw new cursor
  if (turnIsWhite AND whiteBar > 0) OR (NOT turnIsWhite AND blackBar > 0) THEN
    hasPicked = 1
  endif
  DrawCursor cursorIndex, 0
END SUB

' === BuildMovePoints Subroutine ===
SUB BuildMovePoints(p(), v(), isWhite, origPick, die1, die2)
  LOCAL i, dist

  FOR i = 0 TO 23
    v(i) = 0
    dist = ABS(i - origPick)

    IF doubleFlag THEN
      ' doubles allow any matching dieVal forward
      IF ((isWhite AND i > origPick) OR (NOT isWhite AND i < origPick)) AND dist = dieVal THEN
        v(i) = 1
      ENDIF
    ELSE
      ' normal dice
      IF ((isWhite AND i > origPick) OR (NOT isWhite AND i < origPick)) THEN
        IF die1 > 0 AND dist = die1 THEN v(i) = 1
        IF die2 > 0 AND dist = die2 THEN v(i) = 1
      ENDIF
    ENDIF

    ' reject moves onto two or more opponent checkers 
    IF v(i) = 1 THEN
      IF isWhite THEN
        IF p(i) < -1 THEN v(i) = 0
      ELSE
        IF p(i) >  1 THEN v(i) = 0
      ENDIF
    ENDIF
  NEXT

END SUB


' === Pick or Drop Subroutine ===
SUB PickDrop
  LOCAL iFlash, dist, usedDie, i
  ' Attempt pick-up if nothing is picked
  IF hasPicked = 0 THEN
    ' Enforce bar re-entry
    IF (turnIsWhite AND whiteBar > 0) OR (NOT turnIsWhite AND blackBar > 0) THEN
      FOR iFlash = 1 TO 3
        DrawCursor cursorIndex, 1: PAUSE 100
        DrawCursor cursorIndex, 0: PAUSE 100
      NEXT
      EXIT SUB
    ENDIF
    ' Valid pick-up?
    IF (turnIsWhite AND pieces(cursorIndex) > 0) OR (NOT turnIsWhite AND pieces(cursorIndex) < 0) THEN
      origPick = cursorIndex
      IF turnIsWhite THEN
        pieces(origPick) = pieces(origPick) - 1
      ELSE
        pieces(origPick) = pieces(origPick) + 1
      ENDIF
      hasPicked = 1
      ' Redraw after removal
      ClearScreen: DrawBoard: DrawBearTray: DrawOffTrayPieces: DrawCheckers pieces(): DrawCenterBar: DrawDice turnIsWhite
      ' Build forward-only valid drop targets
      BuildMovePoints pieces(), validPoints(), turnIsWhite, origPick, m1, m2
      ' Draw cursor on picked location
      DrawCursor cursorIndex, 0
    ELSE
      FOR iFlash = 1 TO 3
        DrawCursor cursorIndex, 1: PAUSE 100
        DrawCursor cursorIndex, 0: PAUSE 100
      NEXT
    ENDIF
  ELSE
    ' Drop-off phase
    '  DISALLOW landing on a point with 2+ opponent checkers 
    IF turnIsWhite AND pieces(cursorIndex) < -1 THEN
      FOR iFlash = 1 TO 3
        DrawCursor cursorIndex, 1: PAUSE 100
        DrawCursor cursorIndex, 0: PAUSE 100
      NEXT
      EXIT SUB
    ELSEIF NOT turnIsWhite AND pieces(cursorIndex) > 1 THEN
      FOR iFlash = 1 TO 3
        DrawCursor cursorIndex, 1: PAUSE 100
        DrawCursor cursorIndex, 0: PAUSE 100
      NEXT
      EXIT SUB
    ENDIF


    ' If returning to origin, cancel pick without penalty
    IF cursorIndex = origPick THEN
      IF turnIsWhite THEN
        pieces(origPick) = pieces(origPick) + 1
      ELSE
        pieces(origPick) = pieces(origPick) - 1
      ENDIF
      hasPicked = 0
      ClearScreen: DrawBoard: DrawBearTray: DrawOffTrayPieces: DrawCheckers pieces(): DrawCenterBar: DrawDice turnIsWhite
      DrawCursor cursorIndex, 0
      EXIT SUB
    ENDIF
    ' Disallow backwards moves (excluding the original point)
    IF (turnIsWhite AND cursorIndex < origPick) OR (NOT turnIsWhite AND cursorIndex > origPick) THEN
      FOR iFlash = 1 TO 3
        DrawCursor cursorIndex, 1: PAUSE 100
        DrawCursor cursorIndex, 0: PAUSE 100
      NEXT
      EXIT SUB
    ENDIF
    ' Compute move distance
    dist = ABS(cursorIndex - origPick)
    ' Determine which die to use or consume a double
    IF doubleFlag THEN
      IF dist = dieVal AND movesLeft > 0 THEN
        usedDie = 0
        movesLeft = movesLeft - 1
      ELSE
        ' Invalid drop: flash cursor
        FOR iFlash = 1 TO 3
          DrawCursor cursorIndex, 1: PAUSE 100
          DrawCursor cursorIndex, 0: PAUSE 100
        NEXT
        EXIT SUB
      ENDIF
    ELSE
      IF m1 > 0 AND dist = m1 THEN
        usedDie = 1
      ELSEIF m2 > 0 AND dist = m2 THEN
        usedDie = 2
      ELSE
        ' Invalid drop: flash cursor
        FOR iFlash = 1 TO 3
          DrawCursor cursorIndex, 1: PAUSE 100
          DrawCursor cursorIndex, 0: PAUSE 100
        NEXT
        EXIT SUB
      ENDIF
    ENDIF
    ' Capture blot if present if present
    IF turnIsWhite AND pieces(cursorIndex) < 0 THEN
      blackBar = blackBar + 1: pieces(cursorIndex) = 0
    ELSEIF NOT turnIsWhite AND pieces(cursorIndex) > 0 THEN
      whiteBar = whiteBar + 1: pieces(cursorIndex) = 0
    ENDIF
    ' Place moving checker
    IF turnIsWhite THEN
      pieces(cursorIndex) = pieces(cursorIndex) + 1
    ELSE
      pieces(cursorIndex) = pieces(cursorIndex) - 1
    ENDIF
    ' Consume pip
    IF NOT doubleFlag THEN
      IF usedDie = 1 THEN 
        m1 = 0 
      ELSE 
        m2 = 0 
      ENDIF
    ENDIF
    hasPicked = 0
    ' Redraw after move
    ClearScreen: DrawBoard: DrawBearTray: DrawOffTrayPieces: DrawCheckers pieces(): DrawCenterBar: DrawDice turnIsWhite
    BuildValidPoints pieces(), validPoints(), turnIsWhite    
    if m1 = 0 and m2 = 0 then
      DrawCursor cursorIndex, 1
    ELSE 
      DrawCursor cursorIndex, 0
    ENDIF 
  ENDIF
END SUB


' I am not sure this is really needed now - maybe another day
'SUB DoOver
'  FOR i = 0 TO 23: pieces(i) = backupPieces(i): NEXT
'  m1 = backupM1: m2 = backupM2: whiteBar = backupWhiteBar: blackBar = backupBlackBar
'  canRoll = 0: state = 1: hasPicked = 0
'  BuildValidPoints pieces(), validPoints(), turnIsWhite
'  ClearScreen: DrawBoard: DrawBearTray: DrawCheckers pieces(): DrawCenterBar: DrawDice turnIsWhite
'  FOR i = 0 TO 23: cursorIndex = i: EXIT FOR IF validPoints(i): NEXT
'  DrawCursor cursorIndex, 0
'END SUB

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

' === Draw the borne off pieces inside that same tray ===
SUB DrawOffTrayPieces
  LOCAL trayX, pieceH, i, rectX, rectY, fillCol, count

  ' 1) Position tray edge (orientation only)
  IF screenFlipped THEN
    trayX = W - (X_OFFSET + 12 * POINT_W + BAR_W + TRAY_W)
  ELSE
    trayX = X_OFFSET + 12 * POINT_W + BAR_W
  ENDIF

  ' 2) Compute piece height to fit 15 in half-board
  pieceH = INT((H/2) / 15)

  ' 3) Draw both players borne off stacks inside the flipped tray
  IF NOT screenFlipped THEN
    ' White turn (tray on right)
    '    White stack bottom up
    count = whiteOff: fillCol = RGB(240,240,220)
    FOR i = 1 TO count
      rectX = trayX + 1
      rectY = H - i * pieceH
      RBOX rectX, rectY, TRAY_W - 2, pieceH, 0, , fillCol
    NEXT
    
    '    Black stack top down
    count = blackOff: fillCol = RGB(100,60,20)
    FOR i = 1 TO count
      rectX = trayX + 1
      rectY = (i - 1) * pieceH
      RBOX rectX, rectY, TRAY_W - 2, pieceH, 0, , fillCol
    NEXT
  ELSE
    ' Black turn (tray on left)
    '    White stack top down
    count = whiteOff: fillCol = RGB(240,240,220)
    FOR i = 1 TO count
      rectX = trayX + 1
      rectY = (i - 1) * pieceH
      RBOX rectX, rectY, TRAY_W - 2, pieceH, 0, , fillCol
    NEXT
    
    '    Black stack bottom up
    count = blackOff: fillCol = RGB(100,60,20)
    FOR i = 1 TO count
      rectX = trayX + 1
      rectY = H - i * pieceH
      RBOX rectX, rectY, TRAY_W - 2, pieceH, 0, , fillCol
    NEXT
  ENDIF
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

SUB InitPiecesTESTING(p()) ' rename for debugging
  ' Clear the board
  FOR i = 0 TO 23: p(i) = 0: NEXT

  ' White
  p(18) = 3
  p(19) = 2
  p(20) = 2
  p(21) = 2
  p(22) = 2
  p(23) = 3


  ' Black: 
  p(1)  = -3
  p(2)  = -3
  p(3)  = -3
  p(4)  = -3
  p(5)  = -3
END SUB

SUB InitPieces(p())
  ' Clear all points
  FOR i = 0 TO 23: p(i) = 0: NEXT
  ' Place starting checkers:
  ' Two white on space 24 (upper-right)  index 0
  p(0) = 2
  ' Five white on space 13  index 11
  p(11) = 5
  ' Three white on space 8  index 16
  p(16) = 3
  ' Five white on space 6  index 18
  p(18) = 5
  ' Two black on space 1 (lower-right)  index 23
  p(23) = -2
  ' Five black on space 12  index 12
  p(12) = -5
  ' Three black on space 17  index 7
  p(7) = -3
  ' Five black on space 19  index 5
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
  LOCAL i, j, num, col, row, colVis, xx, yy
  LOCAL border, fill
  LOCAL normalSpacing, skewAmt, extraIdx, baseIdx, baseY

  normalSpacing = PIECE_R * 2 + 2   ' distance between the first 5 pieces
  skewAmt       = 4                 ' pixels to shift extras toward center

  FOR i = 0 TO 23
    num = ABS(p(i))
    IF num = 0 THEN GOTO SkipDraw

    ' choose colors
    IF p(i) > 0 THEN ' white pieces
      border = RGB(0,0,0)
      fill   = RGB(240,240,220)
    ELSE
      border = RGB(0,0,20) ' brown pieces RGB(0,60,20)
      fill   = RGB(100,60,20)
    ENDIF

    row = i \ 12        ' 0 = top, 1 = bottom
    col = i MOD 12
    IF row = 0 THEN    ' flip top row
      colVis = 11 - col
    ELSE
      colVis = col
    ENDIF

    xx = X_OFFSET + colVis * POINT_W + (colVis \ 6) * BAR_W + POINT_W / 2

    FOR j = 0 TO num - 1
      IF j < 5 THEN
        ' first five in a tight stack
        IF row = 0 THEN
          yy = PIECE_R + 2 + j * normalSpacing
        ELSE
          yy = H - PIECE_R - 2 - j * normalSpacing
        ENDIF

      ELSE
        ' extras: map 6th?1st, 7th?2nd, etc.
        baseIdx = (j - 5) MOD 5
        IF row = 0 THEN
          baseY = PIECE_R + 2 + baseIdx * normalSpacing
          yy    = baseY + skewAmt      ' skew toward center (downwards)
        ELSE
          baseY = H - PIECE_R - 2 - baseIdx * normalSpacing
          yy    = baseY - skewAmt      ' skew toward center (upwards)
        ENDIF
      ENDIF

      CIRCLE FX(xx), FY(yy), PIECE_R, 1, , border, fill
    NEXT j

SkipDraw:
  NEXT i
END SUB



' === End Turn Subroutine ===
SUB EndTurn
  If turnIsWhite THEN
    whiteCursor = cursorIndex
  else
    blackCursor = cursorIndex
  Endif
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
  DrawOffTrayPieces
  DrawCheckers pieces()
  DrawCenterBar
  DrawDice turnIsWhite
  ' Reset valid points and cursor
  BuildValidPoints pieces(), validPoints(), turnIsWhite
END SUB

' === Bar-Off Subroutine ===
SUB BarOff
  LOCAL iFlash, useDie, entryPt
  ' Build valid re-entry points
  BuildReEntryPoints pieces(), validPoints(), turnIsWhite, m1, m2
  entryPt = cursorIndex
  
    ' Disallow onto blocked points
  IF validPoints(entryPt) = 0 THEN
    FOR iFlash = 1 TO 3
      DrawCursor cursorIndex, 1: PAUSE 100
      DrawCursor cursorIndex, 0: PAUSE 100
    NEXT
    EXIT SUB
  ENDIF
  
  ' Determine which die corresponds to this point
  IF turnIsWhite THEN
    IF entryPt = (m1 - 1) THEN
      useDie = 1
    ELSEIF entryPt = (m2 - 1) THEN
      useDie = 2
    ELSE
      ' Invalid re-entry: flash cursor
      FOR iFlash = 1 TO 3
        DrawCursor cursorIndex, 1: PAUSE 100
        DrawCursor cursorIndex, 0: PAUSE 100
      NEXT
      EXIT SUB
    ENDIF
  ELSE
    IF entryPt = (24 - m1) THEN
      useDie = 1
    ELSEIF entryPt = (24 - m2) THEN
      useDie = 2
    ELSE
      ' Invalid re-entry: flash cursor
      FOR iFlash = 1 TO 3
        DrawCursor cursorIndex, 1: PAUSE 100
        DrawCursor cursorIndex, 0: PAUSE 100
      NEXT
      EXIT SUB
    ENDIF
  ENDIF
  ' Capture blot if present
  IF turnIsWhite AND pieces(entryPt) < 0 THEN
    blackBar = blackBar + 1: pieces(entryPt) = 0
  ELSEIF NOT turnIsWhite AND pieces(entryPt) > 0 THEN
    whiteBar = whiteBar + 1: pieces(entryPt) = 0
  ENDIF
  ' Remove from bar and place checker
  IF turnIsWhite THEN
    whiteBar = whiteBar - 1: pieces(entryPt) = pieces(entryPt) + 1
  ELSE
    blackBar = blackBar - 1: pieces(entryPt) = pieces(entryPt) - 1
  ENDIF
  ' Consume pip or die (double)
  IF doubleFlag THEN
    IF movesLeft > 0 THEN movesLeft = movesLeft - 1
  ELSE
    IF useDie = 1 THEN 
      m1 = 0 
    ELSE 
      m2 = 0 
    ENDIF
  ENDIF
  hasPicked = 0
  DrawCursor cursorIndex, 1
  ' Redraw board
  ClearScreen: DrawBoard: DrawBearTray: DrawOffTrayPieces: DrawCheckers pieces(): DrawCenterBar: DrawDice turnIsWhite
END SUB

' === Build Re-Entry Points ===
SUB BuildReEntryPoints(p(), v(), isWhite, die1, die2)
  LOCAL i, pt
  ' Clear previous re-entry flags
  FOR i = 0 TO 23
    v(i) = 0
  NEXT
  ' White re-entry uses points 0..5 (space 24..19)
  IF isWhite THEN
    IF die1 > 0 THEN
      pt = die1 - 1
      IF p(pt) >= -1 THEN v(pt) = 1
    ENDIF
    IF die2 > 0 AND die2 <> die1 THEN
      pt = die2 - 1
      IF p(pt) >= -1 THEN v(pt) = 1
    ENDIF
  ELSE
    ' Black re-entry uses points 23..18 (space 1..6)
    IF die1 > 0 THEN
      pt = 24 - die1
      IF p(pt) <= 1 THEN v(pt) = 1
    ENDIF
    IF die2 > 0 AND die2 <> die1 THEN
      pt = 24 - die2
      IF p(pt) <= 1 THEN v(pt) = 1
    ENDIF
  ENDIF
END SUB

' === Bear-Off Subroutine ===
SUB bearOff
  LOCAL i, j, dist, usedDie, highestSpot, legalMoveExists, iFlash

  ' 1) Ensure all checkers in home
  FOR i = 0 TO 23
    IF turnIsWhite THEN
      IF pieces(i) > 0 AND i < 18 THEN
        GOTO invalidOff
      ENDIF
    ELSE
      IF pieces(i) < 0 AND i > 5 THEN
        GOTO invalidOff
      ENDIF
    ENDIF
  NEXT

  ' 2) Must have checker at cursor
  IF (turnIsWhite AND pieces(cursorIndex) <= 0) OR (NOT turnIsWhite AND pieces(cursorIndex) >= 0) THEN
    GOTO invalidOff
  ENDIF

  ' 3) Only from home
  IF turnIsWhite AND cursorIndex < 18 THEN
    GOTO invalidOff
  ENDIF
  IF NOT turnIsWhite AND cursorIndex > 5 THEN
    GOTO invalidOff
  ENDIF

  ' 4) Compute pip distance
  IF turnIsWhite THEN
    dist = 24 - cursorIndex
  ELSE
    dist = cursorIndex + 1
  ENDIF

  ' 5) Find farthest checker (highestSpot)
  highestSpot = -1
  IF turnIsWhite THEN
    FOR i = 18 TO 23
      IF pieces(i) > 0 THEN
        highestSpot = i
        EXIT FOR
      ENDIF
    NEXT
  ELSE
    FOR i = 5 TO 0 STEP -1
      IF pieces(i) < 0 THEN
        highestSpot = i
        EXIT FOR
      ENDIF
    NEXT
  ENDIF

  ' 6) Exact pip match
  IF m1 > 0 AND dist = m1 THEN
    usedDie = 1
  ELSEIF m2 > 0 AND dist = m2 THEN
    usedDie = 2
  ELSE
    ' No exact: try highest roll for each remaining pip
    ' a) Try m1
    IF m1 > 0 AND dist < m1 THEN
      legalMoveExists = 0
      FOR i = 0 TO 23
        IF (turnIsWhite AND pieces(i) > 0) OR (NOT turnIsWhite AND pieces(i) < 0) THEN
          BuildMovePoints(pieces(), validPoints(), turnIsWhite, i, m1, 0)
          FOR j = 0 TO 23
            IF validPoints(j) = 1 THEN
              legalMoveExists = 1
              EXIT FOR
            ENDIF
          NEXT
          IF legalMoveExists THEN EXIT FOR
        ENDIF
      NEXT
      IF legalMoveExists = 0 AND cursorIndex = highestSpot THEN
        usedDie = 1
      ELSE
        GOTO invalidOff
      ENDIF

    ' b) Try m2
    ELSEIF m2 > 0 AND dist < m2 THEN
      legalMoveExists = 0
      FOR i = 0 TO 23
        IF (turnIsWhite AND pieces(i) > 0) OR (NOT turnIsWhite AND pieces(i) < 0) THEN
          BuildMovePoints(pieces(), validPoints(), turnIsWhite, i, m2, 0)
          FOR j = 0 TO 23
            IF validPoints(j) = 1 THEN
              legalMoveExists = 1
              EXIT FOR
            ENDIF
          NEXT
          IF legalMoveExists THEN EXIT FOR
        ENDIF
      NEXT
      IF legalMoveExists = 0 AND cursorIndex = highestSpot THEN
        usedDie = 2
      ELSE
        GOTO invalidOff
      ENDIF
    ELSE
      GOTO invalidOff
    ENDIF
  ENDIF

  ' 7) Consume pip or move counter
  IF doubleFlag THEN
    movesLeft = movesLeft - 1
  ELSE
    IF usedDie = 1 THEN
      m1 = 0
    ELSE
      m2 = 0
    ENDIF
  ENDIF

  ' 8) Remove checker
  IF turnIsWhite THEN
    pieces(cursorIndex) = pieces(cursorIndex) - 1
    whiteOff = whiteOff + 1
  ELSE
    pieces(cursorIndex) = pieces(cursorIndex) + 1
    blackOff = blackOff + 1
  ENDIF

  ' 9) Redraw and rebuild
  ClearScreen: DrawBoard: DrawBearTray: DrawOffTrayPieces: DrawCheckers pieces(): DrawCenterBar: DrawDice turnIsWhite
  BuildValidPoints pieces(), validPoints(), turnIsWhite
  
  ' 10) check for victory
  IF whiteOff = 15 OR blackOff = 15 THEN
    gameOver
    END
  ENDIF
  
  RETURN

invalidOff:
  ' flash cursor and exit without touching movesLeft/m1/m2
  FOR iFlash = 1 TO 3
    DrawCursor cursorIndex, 1: PAUSE 100
    DrawCursor cursorIndex, 0: PAUSE 100
  NEXT

END SUB

SUB gameOver
  CLS
  print "YOU WIN"
END SUB

' === Opening Roll to Determine First Player ===
SUB DoOpeningRoll
  LOCAL rolls, i, bd, wd, prevBD, prevWD
  LOCAL size, corner, y, xB, xW
  LOCAL brownFill, whiteFill
  LOCAL winX, winY, winFill, pipCol, b

  ' 1) Set dice size to twice the previous (96×96) and compute positions
  size      = 96
  corner    = size \ 8            ' 12-pixel rounded corners
  y         = (H - size) \ 2
  xB        = (W \ 4) - (size \ 2)
  xW        = (3 * W \ 4) - (size \ 2)

  brownFill = RGB(100,60,20)
  whiteFill = RGB(240,240,220)

  ' 2) Fill background and draw both large-dice backs once
  COLOR bgColor, bgColor
  CLS
  RBOX xB, y, size, size, corner, RGB(0,0,0), brownFill
  RBOX xW, y, size, size, corner, RGB(0,0,0), whiteFill

  prevBD = 0 : prevWD = 0

  ' 3) Shake animation, repeat if final is a double
  DO
    rolls = INT(RND * 8) + 11
    FOR i = 1 TO rolls
      bd = INT(RND * 6) + 1
      wd = INT(RND * 6) + 1

      IF prevBD THEN ClearLargePips xB, y, size, prevBD, brownFill
      IF prevWD THEN ClearLargePips xW, y, size, prevWD, whiteFill

      DrawLargePips   xB, y, size, bd, RGB(255,255,255)
      DrawLargePips   xW, y, size, wd, RGB(0,0,0)

      prevBD = bd : prevWD = wd
      PAUSE 150
    NEXT
  LOOP WHILE bd = wd

  ' 4) Decide first player based on final bd,wd
  IF bd > wd THEN
    turnIsWhite   = 0: screenFlipped = 1
    d1 = bd: d2 = wd
  ELSE
    turnIsWhite   = 1: screenFlipped = 0
    d1 = wd: d2 = bd
  ENDIF

  m1 = d1: m2 = d2

  ' 5) Blink the winning LARGE die pips five times
  winY = y
  IF turnIsWhite THEN
    winX    = xW
    winFill = whiteFill
    pipCol  = RGB(0,0,0)
  ELSE
    winX    = xB
    winFill = brownFill
    pipCol  = RGB(255,255,255)
  ENDIF
  pause 1000
  FOR b = 1 TO 5
    ClearLargePips winX, winY, size, d1, winFill  ' erase pips
    PAUSE 200
    DrawLargePips   winX, winY, size, d1, pipCol   ' redraw pips
    PAUSE 200
  NEXT
  PAUSE 1000
  canRoll = 0
END SUB


' === Draw two large dice side by side ===
SUB DrawLargeDice(brownVal, whiteVal)
  LOCAL xB, xW, y, size, corner

  size   = 48
  corner = 6
  y      = (H - size) / 2

  ' brown die on left
  xB = (W / 4) - (size / 2)
  RBOX xB, y, size, size, corner, RGB(0,0,0), RGB(100,60,20)
  DrawLargePips xB, y, size, brownVal, RGB(255,255,255)

  ' white die on right
  xW = (3 * W / 4) - (size / 2)
  RBOX xW, y, size, size, corner, RGB(0,0,0), RGB(240,240,220)
  DrawLargePips xW, y, size, whiteVal, RGB(0,0,0)
END SUB

' === Draw pip layout for a large die ===
SUB DrawLargePips(x, y, size, val, col)
  LOCAL cx, cy, r, off
  r   = size \ 12        ' e.g. 96/12 = 8-pixel radius
  off = size \ 4         ' e.g. 96/4  = 24-pixel offset

  cx = x + size \ 2
  cy = y + size \ 2

  SELECT CASE val
    CASE 1
      CIRCLE cx, cy, r, , , col, col
    CASE 2
      CIRCLE x+off,       y+off,       r, , , col, col
      CIRCLE x+size-off,  y+size-off,  r, , , col, col
    CASE 3
      CIRCLE x+off,       y+off,       r, , , col, col
      CIRCLE cx,           cy,          r, , , col, col
      CIRCLE x+size-off,  y+size-off,  r, , , col, col
    CASE 4
      CIRCLE x+off,        y+off,        r, , , col, col
      CIRCLE x+size-off,   y+off,        r, , , col, col
      CIRCLE x+off,        y+size-off,   r, , , col, col
      CIRCLE x+size-off,   y+size-off,   r, , , col, col
    CASE 5
      CIRCLE x+off,        y+off,        r, , , col, col
      CIRCLE x+size-off,   y+off,        r, , , col, col
      CIRCLE cx,            cy,          r, , , col, col
      CIRCLE x+off,        y+size-off,   r, , , col, col
      CIRCLE x+size-off,   y+size-off,   r, , , col, col
    CASE 6
      CIRCLE x+off,        y+off,        r, , , col, col
      CIRCLE x+size-off,   y+off,        r, , , col, col
      CIRCLE x+off,        cy,           r, , , col, col
      CIRCLE x+size-off,   cy,           r, , , col, col
      CIRCLE x+off,        y+size-off,   r, , , col, col
      CIRCLE x+size-off,   y+size-off,   r, , , col, col
  END SELECT
END SUB

' Clear pips by drawing them in the die fill color
SUB ClearLargePips(x, y, size, val, fillCol)
  LOCAL cx, cy, r, off
  r   = size \ 12
  off = size \ 4
  cx  = x + size \ 2
  cy  = y + size \ 2

  SELECT CASE val
    CASE 1
      CIRCLE cx, cy, r+1, , , fillCol, fillCol
    CASE 2
      CIRCLE x+off,       y+off,        r+1, , , fillCol, fillCol
      CIRCLE x+size-off,  y+size-off,   r+1, , , fillCol, fillCol
    CASE 3
      CIRCLE x+off,       y+off,        r+1, , , fillCol, fillCol
      CIRCLE cx,           cy,          r+1, , , fillCol, fillCol
      CIRCLE x+size-off,  y+size-off,   r+1, , , fillCol, fillCol
    CASE 4
      CIRCLE x+off,        y+off,        r+1, , , fillCol, fillCol
      CIRCLE x+size-off,   y+off,        r+1, , , fillCol, fillCol
      CIRCLE x+off,        y+size-off,   r+1, , , fillCol, fillCol
      CIRCLE x+size-off,   y+size-off,   r+1, , , fillCol, fillCol
    CASE 5
      CIRCLE x+off,        y+off,        r+1, , , fillCol, fillCol
      CIRCLE x+size-off,   y+off,        r+1, , , fillCol, fillCol
      CIRCLE cx,            cy,          r+1, , , fillCol, fillCol
      CIRCLE x+off,        y+size-off,   r+1, , , fillCol, fillCol
      CIRCLE x+size-off,   y+size-off,   r+1, , , fillCol, fillCol
    CASE 6
      CIRCLE x+off,        y+off,        r+1, , , fillCol, fillCol
      CIRCLE x+size-off,   y+off,        r+1, , , fillCol, fillCol
      CIRCLE x+off,        cy,           r+1, , , fillCol, fillCol
      CIRCLE x+size-off,   cy,           r+1, , , fillCol, fillCol
      CIRCLE x+off,        y+size-off,   r+1, , , fillCol, fillCol
      CIRCLE x+size-off,   y+size-off,   r+1, , , fillCol, fillCol
  END SELECT
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
