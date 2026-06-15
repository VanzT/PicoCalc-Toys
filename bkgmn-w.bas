2' ============================================================================
' Backgammon Wi-Fi for PicoCalc (identical on both devices)
' Vance Thompson, Sept 2025
' https://github.com/VanzT/PicoCalc-Toys
' ============================================================================

' === Constants ===
OPTION BASE 0

CONST W = 320
CONST H = 320
CONST POINT_W = 23.666
CONST BAR_W = 18
CONST TRAY_W = 18
CONST TRI_HEIGHT = 100
CONST PIECE_R = 8
CONST RX_MAX% = 63

X_OFFSET = 0  ' Align left

' === Color Definitions ===
bgColor             = RGB(170,150,120)
barColor            = RGB(200,200,200)
trayColor           = RGB(120,100,80)
triColor1           = RGB(210,180,140)
triColor2           = RGB(255,255,255)
cursorColor         = RGB(255,0,0)
selectedCursorColor = RGB(0,255,0)

' === WS2812 strip ===
CONST LEDCOUNT = 8
DIM ledBuf%(LEDCOUNT - 1)

' === NET constants ===
CONST PORT% = 6000

DIM myRole$        ' "WHITE" or "BROWN"
DIM seq%
DIM lastSeq%
DIM peer$
DIM myTicket%
DIM assigned%
DIM lastMsg$
DIM lastHello!

DIM rxParts$(RX_MAX%)
DIM rxCount%
seq%     = 1
lastSeq% = 0

' --- Opening roll exchange state ---
DIM openW%
DIM openB%
DIM haveW%
DIM haveB%
DIM openingDone%
DIM tLastOpen%

' === Game state ===
DIM pieces(23)
DIM movesLeft, dieVal, doubleFlag
DIM d1, d2, m1, m2
DIM whiteBar, blackBar
DIM whiteOff, blackOff
DIM x%(2), y%(2)
DIM hasPicked
DIM cursorIndex
DIM validPoints(23)
DIM turnIsWhite
DIM screenFlipped
DIM whiteCursor, blackCursor
DIM k$, legalExists, src, dst, origPick, entryPt
DIM gameOver%, gameWinner$
gameOver%   = 0
gameWinner$ = ""


' === Helpers ================================================================

FUNCTION NowMs%()
  NowMs% = INT(TIMER)
END FUNCTION

FUNCTION RandHex$(n%)
  LOCAL s$, ii%
  s$ = ""
  FOR ii% = 1 TO n%
    s$ = s$ + MID$("0123456789ABCDEF", 1 + INT(RND * 16), 1)
  NEXT
  RandHex$ = s$
END FUNCTION

SUB LED_AllOff
  LOCAL i%
  FOR i% = 0 TO LEDCOUNT - 1: ledBuf%(i%) = 0: NEXT
  BITBANG ws2812 o, GP28, LEDCOUNT, ledBuf%()
END SUB

SUB LED_AllGreen
  LOCAL i%
  FOR i% = 0 TO LEDCOUNT - 1: ledBuf%(i%) = &H00FF00: NEXT
  BITBANG ws2812 o, GP28, LEDCOUNT, ledBuf%()
END SUB

SUB LED_UpdateTurnLights
  IF IsMyTurn%() THEN
    LED_AllGreen
  ELSE
    LED_AllOff
  ENDIF
END SUB


' === NET Pair ===============================================================

SUB NetPair
  LOCAL t$, src$, peerTicket%, assignedRole%, k$, chosen%

  WEB UDP OPEN PORT%
  myTicket% = INT(RND * 1000000) + 1
  assigned% = 0
  peer$     = ""
  lastHello! = -99

  CLS
  COLOR RGB(255,255,255), bgColor
  BOX 0, 0, W, H, 1, bgColor, bgColor
  TEXT W\2, H\2 - 10, "Waiting for opponent...", "CT", 1, 1, RGB(255,255,255), bgColor

  DO
    IF TIMER - lastHello! > 500 THEN
      WEB UDP SEND "255.255.255.255", PORT%, "HELLO " + STR$(myTicket%)
      lastHello! = TIMER
    END IF

    IF MM.MESSAGE$ <> "" THEN
      t$   = MM.MESSAGE$
      src$ = MM.ADDRESS$

      IF LEFT$(t$,5) = "HELLO" AND assigned% = 0 THEN
        peerTicket% = VAL(MID$(t$,7))
        IF peerTicket% = myTicket% THEN
          myTicket% = INT(RND * 1000000) + 1
        ELSE
          peer$ = src$
          IF myTicket% > peerTicket% THEN
            ' I am the assigner - ask which color I want
            CLS
            BOX 0, 0, W, H, 1, bgColor, bgColor
            COLOR RGB(255,255,255), bgColor
            TEXT W\2, H\2 - 40, "Choose your color:", "CT", 1, 1, RGB(255,255,255), bgColor
            TEXT W\2, H\2 - 10, "W = White", "CT", 1, 1, RGB(240,240,220), bgColor
            TEXT W\2, H\2 + 16, "B = Brown", "CT", 1, 1, RGB(0,0,0),  bgColor
            chosen% = 0
            DO
              k$ = INKEY$
              IF UCASE$(k$) = "W" THEN myRole$ = "WHITE" : screenFlipped = 0 : chosen% = 1
              IF UCASE$(k$) = "B" THEN myRole$ = "BROWN" : screenFlipped = 1 : chosen% = 1
              PAUSE 10
            LOOP UNTIL chosen% = 1
            IF myRole$ = "WHITE" THEN assignedRole% = 2 ELSE assignedRole% = 1
            lastMsg$ = "ASSIGN " + STR$(assignedRole%)
            WEB UDP SEND peer$, PORT%, lastMsg$
            assigned% = 1
          ELSE
            WEB UDP SEND peer$, PORT%, "HELLO " + STR$(myTicket%)
          END IF
        END IF

      ELSEIF LEFT$(t$,6) = "ASSIGN" AND assigned% = 0 THEN
        assignedRole% = VAL(MID$(t$,8))
        IF assignedRole% = 1 THEN
          myRole$ = "WHITE" : screenFlipped = 0
        ELSE
          myRole$ = "BROWN" : screenFlipped = 1
        END IF
        peer$     = src$
        assigned% = 1
      END IF
    END IF

    k$ = INKEY$
    IF k$ = "Q" THEN WEB UDP CLOSE : RUN
    PAUSE 10
  LOOP UNTIL assigned% = 1

  LED_AllOff
  CLS
  BOX 0, 0, W, H, 1, bgColor, bgColor
  COLOR RGB(255,255,255), bgColor
  TEXT W\2, H\2 - 10, "Opponent found!", "CT", 1, 1, RGB(255,255,255), bgColor
  IF myRole$ = "WHITE" THEN
    TEXT W\2, H\2 + 14, "You are White", "CT", 1, 1, RGB(240,240,220), bgColor
  ELSE
    TEXT W\2, H\2 + 14, "You are Brown", "CT", 1, 1, RGB(160,100,50),  bgColor
  END IF
  PAUSE 2000
END SUB


' === NET send/recv ==========================================================

SUB UdpSend(msg$)
  WEB UDP SEND peer$, PORT%, msg$
END SUB

SUB SendOpen1(role$, val%)
  seq% = seq% + 1
  UdpSend "OPEN1," + role$ + "," + STR$(val%) + "," + STR$(seq%)
END SUB

SUB SendDice(roller$, dd1%, dd2%)
  seq% = seq% + 1
  UdpSend "DICE," + roller$ + "," + STR$(dd1%) + "," + STR$(dd2%) + "," + STR$(seq%)
END SUB

SUB SendBoard(nextTurn$)
  LOCAL s$
  s$ = SerializeBoard$()
  seq% = seq% + 1
  UdpSend "BOARD," + nextTurn$ + "," + s$ + "," + STR$(seq%)
END SUB

SUB SendGameOver(winner$)
  seq% = seq% + 1
  UdpSend "GAMEOVER," + winner$ + "," + STR$(seq%)
END SUB

SUB SplitCSVInto(s$)
  LOCAL p%, q%, t$, idx%, lim%
  lim% = RX_MAX%
  FOR idx% = 1 TO lim%: rxParts$(idx%) = "": NEXT
  rxCount% = 0
  idx% = 1
  p%   = 1
  DO
    q% = INSTR(p%, s$, ",")
    IF q% = 0 THEN
      t$ = MID$(s$, p%)
    ELSE
      t$ = MID$(s$, p%, q% - p%)
    ENDIF
    IF idx% <= lim% THEN
      rxParts$(idx%) = t$
      rxCount%       = idx%
    ENDIF
    IF q% = 0 THEN EXIT DO
    idx% = idx% + 1
    p%   = q% + 1
  LOOP
END SUB

SUB HandlePacket(pkt$)
  LOCAL n%, tag$, thisSeq%
  IF pkt$ = "" THEN EXIT SUB
  IF INSTR(pkt$, ",") = 0 THEN EXIT SUB
  SplitCSVInto pkt$
  n%   = rxCount%
  IF n% < 1 THEN EXIT SUB
  tag$ = UCASE$(rxParts$(1))

  SELECT CASE tag$
    CASE "OPEN1"
      IF n% >= 4 THEN
        thisSeq% = VAL(rxParts$(4))
        IF thisSeq% > lastSeq% THEN lastSeq% = thisSeq%
        IF openingDone% = 0 THEN
          IF UCASE$(rxParts$(2)) = "WHITE" THEN
            openW% = VAL(rxParts$(3)) : haveW% = 1
          ELSE
            openB% = VAL(rxParts$(3)) : haveB% = 1
          ENDIF
        ENDIF
      ENDIF

    CASE "DICE"
      IF n% >= 5 THEN
        thisSeq% = VAL(rxParts$(5))
        IF thisSeq% > lastSeq% THEN
          lastSeq% = thisSeq%
          ApplyDice UCASE$(rxParts$(2)), VAL(rxParts$(3)), VAL(rxParts$(4))
        ENDIF
      ENDIF

    CASE "BOARD"
      IF n% >= 31 THEN
        thisSeq% = VAL(rxParts$(n%))
        IF thisSeq% > lastSeq% THEN
          lastSeq% = thisSeq%
          ApplyBoard1Based
        ENDIF
      ENDIF

    CASE "GAMEOVER"
      IF n% >= 3 THEN
        thisSeq% = VAL(rxParts$(3))
        IF thisSeq% > lastSeq% THEN
          lastSeq% = thisSeq%
          ApplyGameOver UCASE$(rxParts$(2))
        ENDIF
      ENDIF

  END SELECT
END SUB

SUB NetPoll()
  LOCAL msg$
  msg$ = MM.MESSAGE$
  IF msg$ <> "" THEN HandlePacket msg$
END SUB


' === Opening roll exchange ==================================================

SUB DoOpeningExchange
  LOCAL now%

  DO
    NetPoll
    now% = NowMs%()

    IF myRole$ = "WHITE" THEN
      IF haveW% = 0 THEN
        openW% = INT(RND * 6) + 1
        haveW% = 1
        SendOpen1 "WHITE", openW%
        tLastOpen% = now%
      ELSEIF now% - tLastOpen% >= 1000 AND haveB% = 0 THEN
        SendOpen1 "WHITE", openW%
        tLastOpen% = now%
      ENDIF
    ELSE
      IF haveB% = 0 THEN
        openB% = INT(RND * 6) + 1
        haveB% = 1
        SendOpen1 "BROWN", openB%
        tLastOpen% = now%
      ELSEIF now% - tLastOpen% >= 1000 AND haveW% = 0 THEN
        SendOpen1 "BROWN", openB%
        tLastOpen% = now%
      ENDIF
    ENDIF

    IF haveW% AND haveB% THEN
      IF openW% = openB% THEN
        haveW% = 0 : haveB% = 0
      ELSE
        EXIT DO
      ENDIF
    ENDIF

    k$ = INKEY$
    IF k$ = "Q" THEN WEB UDP CLOSE : RUN
    PAUSE 10
  LOOP

  AnimateOpeningAndApply openW%, openB%
  openingDone% = 1
END SUB


' === Opening animation ======================================================

SUB AnimateOpeningAndApply(wd%, bd%)
  LOCAL size, corner, y, xB, xW
  LOCAL i, rolls, prevBD, prevWD
  LOCAL brownFill, whiteFill, pipW, pipB
  LOCAL winIsWhite%, b
  LOCAL rB, rW
  size      = 96
  corner    = size \ 8
  y         = (H - size) \ 2
  xB        = (W \ 4) - (size \ 2)
  xW        = (3 * W \ 4) - (size \ 2)
  brownFill = RGB(100,60,20)
  whiteFill = RGB(240,240,220)
  pipB      = RGB(255,255,255)
  pipW      = RGB(0,0,0)
  COLOR bgColor, bgColor
  CLS
  RBOX xB, y, size, size, corner, RGB(0,0,0), brownFill
  RBOX xW, y, size, size, corner, RGB(0,0,0), whiteFill

  prevBD = 0 : prevWD = 0
  rolls  = INT(RND * 8) + 11
  FOR i = 1 TO rolls
    rB = INT(RND * 6) + 1
    rW = INT(RND * 6) + 1
    IF prevBD THEN ClearLargePips xB, y, size, prevBD, brownFill
    IF prevWD THEN ClearLargePips xW, y, size, prevWD, whiteFill
    DrawLargePips xB, y, size, rB, pipB
    DrawLargePips xW, y, size, rW, pipW
    prevBD = rB : prevWD = rW
    PAUSE 120
  NEXT

  IF prevBD THEN ClearLargePips xB, y, size, prevBD, brownFill
  IF prevWD THEN ClearLargePips xW, y, size, prevWD, whiteFill
  DrawLargePips xB, y, size, bd%, pipB
  DrawLargePips xW, y, size, wd%, pipW

  winIsWhite% = (wd% > bd%)
  PAUSE 500
  FOR b = 1 TO 5
    IF winIsWhite% THEN
      ClearLargePips xW, y, size, wd%, whiteFill
      PAUSE 180
      DrawLargePips   xW, y, size, wd%, pipW
    ELSE
      ClearLargePips xB, y, size, bd%, brownFill
      PAUSE 180
      DrawLargePips   xB, y, size, bd%, pipB
    ENDIF
    PAUSE 180
  NEXT

  IF winIsWhite% THEN
    turnIsWhite = 1
    d1 = wd% : d2 = bd%
  ELSE
    turnIsWhite = 0
    d1 = bd% : d2 = wd%
  ENDIF
  m1 = d1 : m2 = d2
  doubleFlag = 0
  movesLeft  = 2
  canRoll    = 0
  RedrawAll
  LED_UpdateTurnLights
END SUB

FUNCTION IsMyTurn%()
  IF myRole$ = "WHITE" THEN
    IsMyTurn% = (turnIsWhite <> 0)
  ELSEIF myRole$ = "BROWN" THEN
    IsMyTurn% = (turnIsWhite = 0)
  ELSE
    IsMyTurn% = 0
  ENDIF
END FUNCTION


' === Render =================================================================

SUB RedrawAll
  screenFlipped = (myRole$ = "BROWN")
  ClearScreen
  DrawBoard
  DrawBearTray
  DrawOffTrayPieces
  DrawCheckers pieces()
  DrawCenterBar
  DrawDice turnIsWhite
END SUB

SUB ClearScreen
  COLOR bgColor, bgColor
  CLS
  COLOR RGB(255,255,255), bgColor
END SUB

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

SUB DrawCursor(posi, erase)
  LOCAL row, col, colVis, baseX, leftX, rightX, cy, colr
  row = posi \ 12
  col = posi MOD 12
  IF row = 0 THEN
    colVis = 11 - col
  ELSE
    colVis = col
  ENDIF
  baseX  = X_OFFSET + colVis * POINT_W + (colVis \ 6) * BAR_W
  leftX  = FX(baseX + POINT_W / 2 - 6)
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

SUB DrawDice(turnIsWhite)
  LOCAL x1, x2, y, fillCol, pipCol
  y = 150
  IF turnIsWhite THEN
    fillCol = RGB(240,240,220)
    pipCol  = RGB(0,0,0)
    x1 = 200
    x2 = 234
  ELSE
    fillCol = RGB(100,60,20)
    pipCol  = RGB(255,255,255)
    x1 = 56
    x2 = 90
  ENDIF
  RBOX x1, y, 24, 24, 4, RGB(0,0,0), fillCol
  RBOX x2, y, 24, 24, 4, RGB(0,0,0), fillCol
  DrawDiePips x1, y, d1, pipCol
  DrawDiePips x2, y, d2, pipCol
END SUB

SUB DrawDiePips(x, y, val, col)
  LOCAL cx, cy, r
  r  = 2
  cx = x + 12
  cy = y + 12
  SELECT CASE val
    CASE 1
      CIRCLE cx, cy, r, , , col, col
    CASE 2
      CIRCLE x + 6,  y + 6,  r, , , col, col
      CIRCLE x + 18, y + 18, r, , , col, col
    CASE 3
      CIRCLE x + 6,  y + 6,  r, , , col, col
      CIRCLE cx,     cy,     r, , , col, col
      CIRCLE x + 18, y + 18, r, , , col, col
    CASE 4
      CIRCLE x + 6,  y + 6,  r, , , col, col
      CIRCLE x + 18, y + 6,  r, , , col, col
      CIRCLE x + 6,  y + 18, r, , , col, col
      CIRCLE x + 18, y + 18, r, , , col, col
    CASE 5
      CIRCLE x + 6,  y + 6,  r, , , col, col
      CIRCLE x + 18, y + 6,  r, , , col, col
      CIRCLE cx,     cy,     r, , , col, col
      CIRCLE x + 6,  y + 18, r, , , col, col
      CIRCLE x + 18, y + 18, r, , , col, col
    CASE 6
      CIRCLE x + 6,  y + 6,  r, , , col, col
      CIRCLE x + 18, y + 6,  r, , , col, col
      CIRCLE x + 6,  cy,     r, , , col, col
      CIRCLE x + 18, cy,     r, , , col, col
      CIRCLE x + 6,  y + 18, r, , , col, col
      CIRCLE x + 18, y + 18, r, , , col, col
  END SELECT
END SUB

SUB DrawBearTray
  LOCAL trayX
  IF screenFlipped THEN
    trayX = W - (X_OFFSET + 12 * POINT_W + BAR_W + TRAY_W)
  ELSE
    trayX = X_OFFSET + 12 * POINT_W + BAR_W
  ENDIF
  LINE trayX, 0, trayX, H, TRAY_W, trayColor
END SUB

SUB DrawOffTrayPieces
  LOCAL trayX, pieceH, i, rectX, rectY, fillCol, count
  IF screenFlipped THEN
    trayX = W - (X_OFFSET + 12 * POINT_W + BAR_W + TRAY_W)
  ELSE
    trayX = X_OFFSET + 12 * POINT_W + BAR_W
  ENDIF
  pieceH = INT((H/2) / 15)
  IF NOT screenFlipped THEN
    count = whiteOff : fillCol = RGB(240,240,220)
    FOR i = 1 TO count
      rectX = trayX + 1
      rectY = H - i * pieceH
      RBOX rectX, rectY, TRAY_W - 2, pieceH, 0, , fillCol
    NEXT
    count = blackOff : fillCol = RGB(100,60,20)
    FOR i = 1 TO count
      rectX = trayX + 1
      rectY = (i - 1) * pieceH
      RBOX rectX, rectY, TRAY_W - 2, pieceH, 0, , fillCol
    NEXT
  ELSE
    count = whiteOff : fillCol = RGB(240,240,220)
    FOR i = 1 TO count
      rectX = trayX + 1
      rectY = (i - 1) * pieceH
      RBOX rectX, rectY, TRAY_W - 2, pieceH, 0, , fillCol
    NEXT
    count = blackOff : fillCol = RGB(100,60,20)
    FOR i = 1 TO count
      rectX = trayX + 1
      rectY = H - i * pieceH
      RBOX rectX, rectY, TRAY_W - 2, pieceH, 0, , fillCol
    NEXT
  ENDIF
END SUB

SUB DrawCenterBar
  LOCAL rawX, xLine, circleX, j, cy, border, fill, centerY, offsetY
  rawX = X_OFFSET + 6 * POINT_W
  IF screenFlipped THEN
    xLine = W - (rawX + BAR_W)
  ELSE
    xLine = rawX
  ENDIF
  LINE xLine, 0, xLine, H, BAR_W, barColor
  circleX = xLine + BAR_W / 2
  centerY = H / 2
  border  = RGB(0,0,0) : fill = RGB(240,240,220)
  FOR j = 1 TO whiteBar
    offsetY = j * (PIECE_R * 2 + 2)
    cy = centerY - offsetY + PIECE_R
    cy = FY(cy)
    CIRCLE circleX, cy, PIECE_R, 1, , border, fill
  NEXT
  border = RGB(0,60,20) : fill = RGB(100,60,20)
  FOR j = 1 TO blackBar
    offsetY = j * (PIECE_R * 2 + 2)
    cy = centerY + offsetY - PIECE_R
    cy = FY(cy)
    CIRCLE circleX, cy, PIECE_R, 1, , border, fill
  NEXT
END SUB

SUB InitPieces(p())
  FOR i = 0 TO 23: p(i) = 0: NEXT
  p(0)  =  2
  p(11) =  5
  p(16) =  3
  p(18) =  5
  p(23) = -2
  p(12) = -5
  p(7)  = -3
  p(5)  = -5
END SUB

SUB BuildValidPoints(p(), v(), isWhite)
  FOR i = 0 TO 23
    v(i) = 1
  NEXT
END SUB

SUB DrawCheckers(p())
  LOCAL i, j, num, col, row, colVis, xx, yy
  LOCAL border, fill
  LOCAL normalSpacing, skewAmt, baseIdx, baseY
  normalSpacing = PIECE_R * 2 + 2
  skewAmt       = 4
  FOR i = 0 TO 23
    num = ABS(p(i))
    IF num = 0 THEN GOTO SkipDraw
    IF p(i) > 0 THEN
      border = RGB(0,0,0)
      fill   = RGB(240,240,220)
    ELSE
      border = RGB(0,0,20)
      fill   = RGB(100,60,20)
    ENDIF
    row = i \ 12
    col = i MOD 12
    IF row = 0 THEN
      colVis = 11 - col
    ELSE
      colVis = col
    ENDIF
    xx = X_OFFSET + colVis * POINT_W + (colVis \ 6) * BAR_W + POINT_W / 2
    FOR j = 0 TO num - 1
      IF j < 5 THEN
        IF row = 0 THEN
          yy = PIECE_R + 2 + j * normalSpacing
        ELSE
          yy = H - PIECE_R - 2 - j * normalSpacing
        ENDIF
      ELSE
        baseIdx = (j - 5) MOD 5
        IF row = 0 THEN
          baseY = PIECE_R + 2 + baseIdx * normalSpacing
          yy    = baseY + skewAmt
        ELSE
          baseY = H - PIECE_R - 2 - baseIdx * normalSpacing
          yy    = baseY - skewAmt
        ENDIF
      ENDIF
      CIRCLE FX(xx), FY(yy), PIECE_R, 1, , border, fill
    NEXT j
SkipDraw:
  NEXT i
END SUB

SUB BuildMovePoints(p(), v(), isWhite, origPick, die1, die2)
  LOCAL i, dist
  FOR i = 0 TO 23
    v(i) = 0
    dist = ABS(i - origPick)
    IF doubleFlag THEN
      IF movesLeft > 0 THEN
        IF ((isWhite AND i > origPick) OR (NOT isWhite AND i < origPick)) AND dist = dieVal THEN
          v(i) = 1
        ENDIF
      ENDIF
    ELSE
      IF ((isWhite AND i > origPick) OR (NOT isWhite AND i < origPick)) THEN
        IF die1 > 0 AND dist = die1 THEN v(i) = 1
        IF die2 > 0 AND dist = die2 THEN v(i) = 1
      ENDIF
    ENDIF
    IF v(i) = 1 THEN
      IF isWhite THEN
        IF p(i) < -1 THEN v(i) = 0
      ELSE
        IF p(i) >  1 THEN v(i) = 0
      ENDIF
    ENDIF
  NEXT
END SUB

SUB PickDrop
  LOCAL iFlash, dist, usedDie
  IF hasPicked = 0 THEN
    IF (turnIsWhite AND whiteBar > 0) OR (NOT turnIsWhite AND blackBar > 0) THEN
      FOR iFlash = 1 TO 3
        DrawCursor cursorIndex, 1: PAUSE 100
        DrawCursor cursorIndex, 0: PAUSE 100
      NEXT
      EXIT SUB
    ENDIF
    IF (turnIsWhite AND pieces(cursorIndex) > 0) OR (NOT turnIsWhite AND pieces(cursorIndex) < 0) THEN
      origPick = cursorIndex
      IF turnIsWhite THEN
        pieces(origPick) = pieces(origPick) - 1
      ELSE
        pieces(origPick) = pieces(origPick) + 1
      ENDIF
      hasPicked = 1
      RedrawAll
      BuildMovePoints pieces(), validPoints(), turnIsWhite, origPick, m1, m2
      DrawCursor cursorIndex, 0
    ELSE
      FOR iFlash = 1 TO 3
        DrawCursor cursorIndex, 1: PAUSE 100
        DrawCursor cursorIndex, 0: PAUSE 100
      NEXT
    ENDIF
  ELSE
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
    IF cursorIndex = origPick THEN
      IF turnIsWhite THEN
        pieces(origPick) = pieces(origPick) + 1
      ELSE
        pieces(origPick) = pieces(origPick) - 1
      ENDIF
      hasPicked = 0
      RedrawAll
      DrawCursor cursorIndex, 0
      EXIT SUB
    ENDIF
    IF (turnIsWhite AND cursorIndex < origPick) OR (NOT turnIsWhite AND cursorIndex > origPick) THEN
      FOR iFlash = 1 TO 3
        DrawCursor cursorIndex, 1: PAUSE 100
        DrawCursor cursorIndex, 0: PAUSE 100
      NEXT
      EXIT SUB
    ENDIF
    dist = ABS(cursorIndex - origPick)
    IF doubleFlag THEN
      IF dist = dieVal AND movesLeft > 0 THEN
        usedDie   = 0
        movesLeft = movesLeft - 1
        IF movesLeft <= 0 THEN
          doubleFlag = 0
          m1 = 0 : m2 = 0
        ENDIF
      ELSE
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
        FOR iFlash = 1 TO 3
          DrawCursor cursorIndex, 1: PAUSE 100
          DrawCursor cursorIndex, 0: PAUSE 100
        NEXT
        EXIT SUB
      ENDIF
    ENDIF
    IF turnIsWhite AND pieces(cursorIndex) < 0 THEN
      blackBar = blackBar + 1: pieces(cursorIndex) = 0
    ELSEIF NOT turnIsWhite AND pieces(cursorIndex) > 0 THEN
      whiteBar = whiteBar + 1: pieces(cursorIndex) = 0
    ENDIF
    IF turnIsWhite THEN
      pieces(cursorIndex) = pieces(cursorIndex) + 1
    ELSE
      pieces(cursorIndex) = pieces(cursorIndex) - 1
    ENDIF
    IF NOT doubleFlag THEN
      IF usedDie = 1 THEN
        m1 = 0
      ELSE
        m2 = 0
      ENDIF
    ENDIF
    hasPicked = 0
    RedrawAll
    BuildValidPoints pieces(), validPoints(), turnIsWhite
    IF m1 = 0 AND m2 = 0 THEN
      DrawCursor cursorIndex, 1
    ELSE
      DrawCursor cursorIndex, 0
    ENDIF
  ENDIF
END SUB

SUB EndTurn
  IF turnIsWhite THEN
    whiteCursor = cursorIndex
  ELSE
    blackCursor = cursorIndex
  ENDIF
  turnIsWhite = 1 - turnIsWhite
  canRoll    = 1
  doubleFlag = 0
  movesLeft  = 0
  m1         = 0
  m2         = 0
  state      = 0
  LOCAL nextTurn$
  IF turnIsWhite THEN
    nextTurn$ = "WHITE"
  ELSE
    nextTurn$ = "BROWN"
  ENDIF
  SendBoard nextTurn$
  RedrawAll
  BuildValidPoints pieces(), validPoints(), turnIsWhite
  LED_UpdateTurnLights
END SUB

SUB BarOff
  LOCAL iFlash, useDie
  BuildReEntryPoints pieces(), validPoints(), turnIsWhite, m1, m2
  entryPt = cursorIndex
  IF validPoints(entryPt) = 0 THEN
    FOR iFlash = 1 TO 3
      DrawCursor cursorIndex, 1: PAUSE 100
      DrawCursor cursorIndex, 0: PAUSE 100
    NEXT
    EXIT SUB
  ENDIF
  IF turnIsWhite THEN
    IF entryPt = (m1 - 1) THEN
      useDie = 1
    ELSEIF entryPt = (m2 - 1) THEN
      useDie = 2
    ELSE
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
      FOR iFlash = 1 TO 3
        DrawCursor cursorIndex, 1: PAUSE 100
        DrawCursor cursorIndex, 0: PAUSE 100
      NEXT
      EXIT SUB
    ENDIF
  ENDIF
  IF turnIsWhite AND pieces(entryPt) < 0 THEN
    blackBar = blackBar + 1: pieces(entryPt) = 0
  ELSEIF NOT turnIsWhite AND pieces(entryPt) > 0 THEN
    whiteBar = whiteBar + 1: pieces(entryPt) = 0
  ENDIF
  IF turnIsWhite THEN
    whiteBar = whiteBar - 1: pieces(entryPt) = pieces(entryPt) + 1
  ELSE
    blackBar = blackBar - 1: pieces(entryPt) = pieces(entryPt) - 1
  ENDIF
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
  RedrawAll
END SUB

SUB BuildReEntryPoints(p(), v(), isWhite, die1, die2)
  LOCAL i, pt
  FOR i = 0 TO 23
    v(i) = 0
  NEXT
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

SUB bearOff
  LOCAL i, j, dist, usedDie, highestSpot, legalMoveExists, iFlash

  FOR i = 0 TO 23
    IF turnIsWhite THEN
      IF pieces(i) > 0 AND i < 18 THEN GOTO invalidOff
    ELSE
      IF pieces(i) < 0 AND i > 5 THEN GOTO invalidOff
    ENDIF
  NEXT

  IF (turnIsWhite AND pieces(cursorIndex) <= 0) OR (NOT turnIsWhite AND pieces(cursorIndex) >= 0) THEN
    GOTO invalidOff
  ENDIF

  IF turnIsWhite AND cursorIndex < 18 THEN GOTO invalidOff
  IF NOT turnIsWhite AND cursorIndex > 5 THEN GOTO invalidOff

  IF turnIsWhite THEN
    dist = 24 - cursorIndex
  ELSE
    dist = cursorIndex + 1
  ENDIF

  highestSpot = -1
  IF turnIsWhite THEN
    FOR i = 18 TO 23
      IF pieces(i) > 0 THEN highestSpot = i: EXIT FOR
    NEXT
  ELSE
    FOR i = 5 TO 0 STEP -1
      IF pieces(i) < 0 THEN highestSpot = i: EXIT FOR
    NEXT
  ENDIF

  IF m1 > 0 AND dist = m1 THEN
    usedDie = 1
  ELSEIF m2 > 0 AND dist = m2 THEN
    usedDie = 2
  ELSE
    IF m1 > 0 AND dist < m1 THEN
      legalMoveExists = 0
      FOR i = 0 TO 23
        IF (turnIsWhite AND pieces(i) > 0) OR (NOT turnIsWhite AND pieces(i) < 0) THEN
          BuildMovePoints(pieces(), validPoints(), turnIsWhite, i, m1, 0)
          FOR j = 0 TO 23
            IF validPoints(j) = 1 THEN legalMoveExists = 1: EXIT FOR
          NEXT
          IF legalMoveExists THEN EXIT FOR
        ENDIF
      NEXT
      IF legalMoveExists = 0 AND cursorIndex = highestSpot THEN
        usedDie = 1
      ELSE
        GOTO invalidOff
      ENDIF
    ELSEIF m2 > 0 AND dist < m2 THEN
      legalMoveExists = 0
      FOR i = 0 TO 23
        IF (turnIsWhite AND pieces(i) > 0) OR (NOT turnIsWhite AND pieces(i) < 0) THEN
          BuildMovePoints(pieces(), validPoints(), turnIsWhite, i, m2, 0)
          FOR j = 0 TO 23
            IF validPoints(j) = 1 THEN legalMoveExists = 1: EXIT FOR
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

  IF doubleFlag THEN
    movesLeft = movesLeft - 1
    IF movesLeft <= 0 THEN
      doubleFlag = 0
      m1 = 0 : m2 = 0
    ENDIF
  ELSE
    IF usedDie = 1 THEN
      m1 = 0
    ELSE
      m2 = 0
    ENDIF
  ENDIF

  IF turnIsWhite THEN
    pieces(cursorIndex) = pieces(cursorIndex) - 1
    whiteOff = whiteOff + 1
  ELSE
    pieces(cursorIndex) = pieces(cursorIndex) + 1
    blackOff = blackOff + 1
  ENDIF
  RedrawAll
  BuildValidPoints pieces(), validPoints(), turnIsWhite
  IF whiteOff = 15 OR blackOff = 15 THEN
    LOCAL winner$
    IF whiteOff = 15 THEN
      winner$ = "WHITE"
    ELSE
      winner$ = "BROWN"
    ENDIF
    SendGameOver winner$
    ApplyGameOver winner$
    RETURN
  ENDIF
  RETURN

invalidOff:
  FOR iFlash = 1 TO 3
    DrawCursor cursorIndex, 1: PAUSE 100
    DrawCursor cursorIndex, 0: PAUSE 100
  NEXT
END SUB

SUB DrawLargePips(x, y, size, val, col)
  LOCAL cx, cy, r, off
  r   = size \ 12
  off = size \ 4
  cx  = x + size \ 2
  cy  = y + size \ 2
  SELECT CASE val
    CASE 1
      CIRCLE cx, cy, r, , , col, col
    CASE 2
      CIRCLE x+off,      y+off,      r, , , col, col
      CIRCLE x+size-off, y+size-off, r, , , col, col
    CASE 3
      CIRCLE x+off,      y+off,      r, , , col, col
      CIRCLE cx,         cy,         r, , , col, col
      CIRCLE x+size-off, y+size-off, r, , , col, col
    CASE 4
      CIRCLE x+off,      y+off,      r, , , col, col
      CIRCLE x+size-off, y+off,      r, , , col, col
      CIRCLE x+off,      y+size-off, r, , , col, col
      CIRCLE x+size-off, y+size-off, r, , , col, col
    CASE 5
      CIRCLE x+off,      y+off,      r, , , col, col
      CIRCLE x+size-off, y+off,      r, , , col, col
      CIRCLE cx,         cy,         r, , , col, col
      CIRCLE x+off,      y+size-off, r, , , col, col
      CIRCLE x+size-off, y+size-off, r, , , col, col
    CASE 6
      CIRCLE x+off,      y+off,      r, , , col, col
      CIRCLE x+size-off, y+off,      r, , , col, col
      CIRCLE x+off,      cy,         r, , , col, col
      CIRCLE x+size-off, cy,         r, , , col, col
      CIRCLE x+off,      y+size-off, r, , , col, col
      CIRCLE x+size-off, y+size-off, r, , , col, col
  END SELECT
END SUB

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
      CIRCLE x+off,      y+off,      r+1, , , fillCol, fillCol
      CIRCLE x+size-off, y+size-off, r+1, , , fillCol, fillCol
    CASE 3
      CIRCLE x+off,      y+off,      r+1, , , fillCol, fillCol
      CIRCLE cx,         cy,         r+1, , , fillCol, fillCol
      CIRCLE x+size-off, y+size-off, r+1, , , fillCol, fillCol
    CASE 4
      CIRCLE x+off,      y+off,      r+1, , , fillCol, fillCol
      CIRCLE x+size-off, y+off,      r+1, , , fillCol, fillCol
      CIRCLE x+off,      y+size-off, r+1, , , fillCol, fillCol
      CIRCLE x+size-off, y+size-off, r+1, , , fillCol, fillCol
    CASE 5
      CIRCLE x+off,      y+off,      r+1, , , fillCol, fillCol
      CIRCLE x+size-off, y+off,      r+1, , , fillCol, fillCol
      CIRCLE cx,         cy,         r+1, , , fillCol, fillCol
      CIRCLE x+off,      y+size-off, r+1, , , fillCol, fillCol
      CIRCLE x+size-off, y+size-off, r+1, , , fillCol, fillCol
    CASE 6
      CIRCLE x+off,      y+off,      r+1, , , fillCol, fillCol
      CIRCLE x+size-off, y+off,      r+1, , , fillCol, fillCol
      CIRCLE x+off,      cy,         r+1, , , fillCol, fillCol
      CIRCLE x+size-off, cy,         r+1, , , fillCol, fillCol
      CIRCLE x+off,      y+size-off, r+1, , , fillCol, fillCol
      CIRCLE x+size-off, y+size-off, r+1, , , fillCol, fillCol
  END SELECT
END SUB

SUB RollDice
  LOCAL rolls, i
  rolls = INT(RND * 8) + 11
  FOR i = 1 TO rolls
    d1 = INT(RND * 6) + 1
    d2 = INT(RND * 6) + 1
    DrawDice(turnIsWhite)
    PAUSE 80
  NEXT
  m1 = d1
  m2 = d2
  IF d1 = d2 THEN
    doubleFlag = 1
    dieVal     = d1
    movesLeft  = 4
  ELSE
    doubleFlag = 0
    movesLeft  = 2
  ENDIF
  canRoll = 0
  SendDice myRole$, d1, d2
END SUB

SUB ApplyDice(roller$, dd1%, dd2%)
  d1 = dd1%
  d2 = dd2%
  m1 = d1
  m2 = d2
  IF d1 = d2 THEN
    doubleFlag = 1
    dieVal     = d1
    movesLeft  = 4
  ELSE
    doubleFlag = 0
    movesLeft  = 2
  ENDIF
  canRoll = 0
  RedrawAll
END SUB

FUNCTION SerializeBoard$()
  LOCAL s$, idx%
  s$ = ""
  FOR idx% = 0 TO 23
    s$ = s$ + STR$(pieces(idx%))
    IF idx% < 23 THEN s$ = s$ + ","
  NEXT
  s$ = s$ + "," + STR$(whiteBar) + "," + STR$(blackBar) + "," + STR$(whiteOff) + "," + STR$(blackOff)
  SerializeBoard$ = s$
END FUNCTION

SUB ApplyBoard1Based
  LOCAL idx%
  FOR idx% = 0 TO 23
    pieces(idx%) = VAL(rxParts$(3 + idx%))
  NEXT
  whiteBar    = VAL(rxParts$(27))
  blackBar    = VAL(rxParts$(28))
  whiteOff    = VAL(rxParts$(29))
  blackOff    = VAL(rxParts$(30))
  turnIsWhite = (UCASE$(rxParts$(2)) = "WHITE")
  hasPicked   = 0
  canRoll     = 1
  doubleFlag  = 0
  movesLeft   = 0
  m1 = 0 : m2 = 0
  d1 = 0 : d2 = 0
  BuildValidPoints pieces(), validPoints(), turnIsWhite
  RedrawAll
  LED_UpdateTurnLights
END SUB


' === Win/loss record ========================================================

SUB UpdateWonFile
  LOCAL wins%, losses%, f$, line1$, line2$
  f$      = "B:bkgmn.won"
  wins%   = 0
  losses% = 0

  IF DIR$(f$) <> "" THEN
    OPEN f$ FOR INPUT AS #1
    LINE INPUT #1, line1$
    LINE INPUT #1, line2$
    CLOSE #1
    wins%   = VAL(MID$(line1$, 7))   ' skip "wins: "
    losses% = VAL(MID$(line2$, 9))   ' skip "losses: "
  END IF

  IF myRole$ = "WHITE" THEN
    IF gameWinner$ = "WHITE" THEN wins% = wins% + 1 ELSE losses% = losses% + 1
  ELSE
    IF gameWinner$ = "BROWN" THEN wins% = wins% + 1 ELSE losses% = losses% + 1
  END IF

  OPEN f$ FOR OUTPUT AS #1
  PRINT #1, "wins: " + STR$(wins%)
  PRINT #1, "losses: " + STR$(losses%)
  CLOSE #1
END SUB


' === Game over screen =======================================================

SUB ApplyGameOver(winner$)
  LOCAL iWon%, k$, dkBg%, b%, flash%, bx%, by%, bw%, bh%
  LOCAL wins%, losses%, f$, line1$, line2$

  gameOver%   = 1
  gameWinner$ = UCASE$(winner$)
  canRoll    = 0
  doubleFlag = 0
  movesLeft  = 0
  m1 = 0 : m2 = 0

  IF myRole$ = "WHITE" THEN
    iWon% = (gameWinner$ = "WHITE")
  ELSE
    iWon% = (gameWinner$ = "BROWN")
  END IF

  ' Update the win/loss file before showing the screen
  UpdateWonFile

  ' Read updated totals to display
  wins%   = 0
  losses% = 0
  f$ = "B:bkgmn.won"
  IF DIR$(f$) <> "" THEN
    OPEN f$ FOR INPUT AS #1
    LINE INPUT #1, line1$
    LINE INPUT #1, line2$
    CLOSE #1
    wins%   = VAL(MID$(line1$, 7))
    losses% = VAL(MID$(line2$, 9))
  END IF

  ' Dark background for contrast
  dkBg% = RGB(30, 20, 10)
  COLOR dkBg%, dkBg%
  CLS

  IF iWon% THEN
    ' === WIN SCREEN ===
    ' Gold banner across top third
    BOX 0, 0, W, H\3, 1, RGB(180,140,0), RGB(180,140,0)
    ' Dark middle band
    BOX 0, H\3, W, H\3, 1, dkBg%, dkBg%
    ' Muted bottom band
    BOX 0, (H\3)*2, W, H\3 + 2, 1, RGB(50,35,10), RGB(50,35,10)

    ' Big "YOU WIN" in the gold zone
    TEXT W\2, 18,      "YOU WIN",          "CT", 1, 3, RGB(255,235,80), RGB(180,140,0)

    ' Checker silhouette row under banner
    FOR b% = 0 TO 9
      CIRCLE 16 + b% * 30, H\3 + 14, 10, 1, , RGB(240,240,220), RGB(240,240,220)
    NEXT b%

    ' Role tag
    IF myRole$ = "WHITE" THEN
      TEXT W\2, H\3 + 32, "Playing White", "CT", 1, 1, RGB(240,240,220), dkBg%
    ELSE
      TEXT W\2, H\3 + 32, "Playing Brown", "CT", 1, 1, RGB(160,100,50),  dkBg%
    END IF

    ' Divider
    LINE 20, H\3 + 48, W - 20, H\3 + 48, 1, RGB(180,140,0)

    ' Record
    TEXT W\2, H\3 + 58, "Record:  " + STR$(wins%) + " W  /  " + STR$(losses%) + " L", "CT", 1, 1, RGB(220,200,120), dkBg%

    ' Prompt
    TEXT W\2, H - 28, "Press any key", "CT", 1, 1, RGB(160,140,80), RGB(50,35,10)

  ELSE
    ' === LOSE SCREEN ===
    BOX 0, 0, W, H\3, 1, RGB(80,20,20), RGB(80,20,20)
    BOX 0, H\3, W, H\3, 1, dkBg%, dkBg%
    BOX 0, (H\3)*2, W, H\3 + 2, 1, RGB(40,10,10), RGB(40,10,10)

    ' Big "YOU LOSE"
    TEXT W\2, 18,      "YOU LOSE",         "CT", 1, 3, RGB(255,100,80), RGB(80,20,20)

    ' Brown checker silhouette row (opponent's color won)
    FOR b% = 0 TO 9
      CIRCLE 16 + b% * 30, H\3 + 14, 10, 1, , RGB(100,60,20), RGB(100,60,20)
    NEXT b%

    ' Role tag
    IF myRole$ = "WHITE" THEN
      TEXT W\2, H\3 + 32, "Playing White", "CT", 1, 1, RGB(240,240,220), dkBg%
    ELSE
      TEXT W\2, H\3 + 32, "Playing Brown", "CT", 1, 1, RGB(160,100,50),  dkBg%
    END IF

    ' Divider
    LINE 20, H\3 + 48, W - 20, H\3 + 48, 1, RGB(120,40,40)

    ' Record
    TEXT W\2, H\3 + 58, "Record:  " + STR$(wins%) + " W  /  " + STR$(losses%) + " L", "CT", 1, 1, RGB(200,160,160), dkBg%

    ' Prompt
    TEXT W\2, H - 28, "Press any key", "CT", 1, 1, RGB(140,80,80), RGB(40,10,10)

  END IF

  LED_AllOff

  ' Flash the LEDs once on a win
  IF iWon% THEN
    FOR flash% = 1 TO 3
      LED_AllGreen
      PAUSE 300
      LED_AllOff
      PAUSE 300
    NEXT flash%
  END IF

  ' Wait for keypress then return to menu
  DO : LOOP UNTIL INKEY$ = ""
  DO
    PAUSE 20
    k$ = INKEY$
    IF k$ <> "" THEN EXIT DO
  LOOP

  WEB UDP CLOSE
  CHAIN "B:menu.bas"
END SUB


' === Coordinate helpers =====================================================

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

SUB NavigateCursor
  LOCAL newIdx, row, col, colVis, keyChar$
  DrawCursor cursorIndex, 1
  row    = cursorIndex \ 12
  col    = cursorIndex MOD 12
  IF row = 0 THEN
    colVis = 11 - col
  ELSE
    colVis = col
  ENDIF
  keyChar$ = k$
  IF NOT turnIsWhite THEN
    SELECT CASE keyChar$
      CASE CHR$(130): keyChar$ = CHR$(131)
      CASE CHR$(131): keyChar$ = CHR$(130)
      CASE CHR$(128): keyChar$ = CHR$(129)
      CASE CHR$(129): keyChar$ = CHR$(128)
    END SELECT
  ENDIF

  IF keyChar$ = CHR$(130) THEN
    colVis = (colVis - 1 + 12) MOD 12
    IF row = 0 THEN newIdx = 11 - colVis ELSE newIdx = 12 + colVis
  ELSEIF keyChar$ = CHR$(131) THEN
    colVis = (colVis + 1) MOD 12
    IF row = 0 THEN newIdx = 11 - colVis ELSE newIdx = 12 + colVis
  ELSEIF keyChar$ = CHR$(129) THEN
    IF row = 0 THEN newIdx = 12 + colVis ELSE newIdx = cursorIndex
  ELSEIF keyChar$ = CHR$(128) THEN
    IF row = 1 THEN newIdx = 11 - colVis ELSE newIdx = cursorIndex
  ELSE
    newIdx = cursorIndex
  ENDIF

  cursorIndex = newIdx
  IF (turnIsWhite AND whiteBar > 0) OR (NOT turnIsWhite AND blackBar > 0) THEN
    hasPicked = 1
  ENDIF
  DrawCursor cursorIndex, 0
END SUB


' === MAIN ===================================================================

whiteOff    = 0
blackOff    = 0
whiteCursor = 23
blackCursor = 0
turnIsWhite = 1
canRoll     = 1
RANDOMIZE TIMER

NetPair
InitPieces pieces()

ClearScreen
DrawBoard
DrawBearTray
DrawOffTrayPieces
DrawCenterBar
DrawCheckers pieces()

BuildValidPoints pieces(), validPoints(), turnIsWhite
hasPicked   = 0
cursorIndex = 0
i = 0
DO WHILE validPoints(cursorIndex) = 0 AND i < 24
  cursorIndex = (cursorIndex + 1) MOD 24
  i = i + 1
LOOP

DoOpeningExchange

' === Main Loop ==============================================================
DO
  NetPoll

  IF gameOver% THEN
    PAUSE 20
    CONTINUE DO
  END IF

  k$ = INKEY$
  IF k$ = "Q" THEN WEB UDP CLOSE : RUN

  IF k$ = "R" THEN
    LOCAL nt$
    IF turnIsWhite THEN nt$ = "WHITE" ELSE nt$ = "BROWN"
    SendBoard nt$
    k$ = ""
  END IF

  IF NOT IsMyTurn%() THEN
    IF k$ <> "" THEN k$ = ""
    PAUSE 10
    CONTINUE DO
  END IF

  IF (turnIsWhite AND whiteBar > 0) OR (NOT turnIsWhite AND blackBar > 0) THEN
    hasPicked = 1
  ENDIF

  IF (doubleFlag AND movesLeft = 0) OR (NOT doubleFlag AND m1 = 0 AND m2 = 0) THEN
    DrawCursor cursorIndex, 1
  ELSE
    DrawCursor cursorIndex, 0
  ENDIF

  SELECT CASE k$
    CASE " "
      IF canRoll = 1 THEN
        RollDice
        BuildValidPoints pieces(), validPoints(), turnIsWhite
        hasPicked = 0
        IF turnIsWhite THEN
          cursorIndex = whiteCursor
        ELSE
          cursorIndex = blackCursor
        ENDIF
      ENDIF
    CASE "T","t"
      IF canRoll = 0 THEN
        IF doubleFlag AND movesLeft = 0 THEN
          DrawCursor cursorIndex, 1
          EndTurn
          EXIT SELECT
        END IF
        legalExists = 0
        IF (turnIsWhite AND whiteBar > 0) OR (NOT turnIsWhite AND blackBar > 0) THEN
          BuildReEntryPoints pieces(), validPoints(), turnIsWhite, m1, m2
          FOR i = 0 TO 23
            IF validPoints(i) = 1 THEN legalExists = 1: EXIT FOR
          NEXT
        ELSE
          FOR src = 0 TO 23
            IF (turnIsWhite AND pieces(src) > 0) OR (NOT turnIsWhite AND pieces(src) < 0) THEN
              BuildMovePoints pieces(), validPoints(), turnIsWhite, src, m1, m2
              FOR dst = 0 TO 23
                IF validPoints(dst) = 1 THEN legalExists = 1: EXIT FOR
              NEXT
              IF legalExists THEN EXIT FOR
            ENDIF
          NEXT
        ENDIF
        IF legalExists = 0 OR (doubleFlag AND movesLeft = 0) OR (NOT doubleFlag AND m1 = 0 AND m2 = 0) THEN
          DrawCursor cursorIndex, 1
          EndTurn
        ENDIF
      ENDIF
    CASE "B","b"
      IF canRoll = 0 THEN
        bearOff
      ENDIF
    CASE CHR$(130), CHR$(128), CHR$(131), CHR$(129)
      IF canRoll = 0 AND ((doubleFlag AND movesLeft > 0) OR (NOT doubleFlag AND (m1 <> 0 OR m2 <> 0))) THEN
        NavigateCursor
      ENDIF
    CASE CHR$(13), CHR$(10)
      IF canRoll = 0 AND ((turnIsWhite AND whiteBar > 0) OR (NOT turnIsWhite AND blackBar > 0)) THEN
        BarOff
      ELSEIF canRoll = 0 AND ((doubleFlag AND movesLeft > 0) OR (NOT doubleFlag AND (m1 <> 0 OR m2 <> 0))) THEN
        PickDrop
      ENDIF
  END SELECT

  PAUSE 10
LOOP
' ===========================================================================