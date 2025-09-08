' ============================================================================
' Backgammon Wi-Fi for PicoCalc (identical on both devices)
' Vance Thompson, Sept 2025
' https://github.com/VanzT/PicoCalc-Toys
' ============================================================================


' === Constants ===
OPTION BASE 0

CONST W = 320
CONST H = 320
CONST BAR_INDEX = 24
CONST POINT_W = 23.666
CONST BAR_W = 18
CONST TRAY_W = 18
CONST TRI_HEIGHT = 100
CONST PIECE_R = 8
CONST RX_MAX% = 63

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

' === NET constants ===
CONST PORT% = 6000
CONST HANDSHAKE_LISTEN_MS% = 5000
CONST HELLO_RETRY_MS% = 1000
CONST MAXLINE% = 512

DIM myRole$        ' "WHITE" or "BROWN"
DIM gameId$
DIM seq%
DIM lastSeq%
DIM started%
DIM peerSeen%
DIM lastPeer$
DIM tStart%, tLastHello%
DIM rx$
CONST MAXTOK% = 64
DIM rxParts$(RX_MAX%)
DIM rxCount%         ' number of tokens in rxParts$
seq% = 1
lastSeq% = 0
started% = 0
peerSeen% = 0
rx$ = ""
DIM bcast$, bcast255$

DIM hudHideAt%, hudHidden%
DIM pairedDone%

DIM postPairingAt%
DIM kickoffDone%
DIM showHUD%
postPairingAt% = 0
kickoffDone%   = 0
showHUD%       = 1


' --- Opening roll exchange state ---
DIM openW%          ' WHITE's single die (1..6)
DIM openB%          ' BROWN's single die (1..6)
DIM haveW%          ' 1 when we know WHITE's die
DIM haveB%          ' 1 when we know BROWN's die
DIM openingDone%    ' 1 once we finished the opening selection
DIM tLastOpen%      ' resend timer for OPEN1


' === Game state ===
DIM pieces(23)
DIM movesLeft, dieVal, doubleFlag  ' doubles rule support
DIM d1, d2, m1, m2, dieVal1, dieVal2
DIM whiteBar, blackBar
DIM whiteOff, blackOff
DIM barActive, allowEnd
DIM x%(2), y%(2)
DIM state          ' 0=not rolled, 1=rolled, 2=no more moves
DIM hasPicked
DIM cursorIndex, pickedPoint
DIM validPoints(23), cursorSeq(23)
DIM turnIsWhite
DIM screenFlipped
DIM whiteCursor, blackCursor
DIM k$, legalExists, src, dst, origPick, entryPt

' === Helpers ================================================================

' Compute subnet broadcast (x.y.z.255) from our current IP
FUNCTION BroadcastIP$()
  LOCAL ip$, i%
  ip$ = MM.INFO(IP ADDRESS)
  FOR i% = LEN(ip$) TO 1 STEP -1
    IF MID$(ip$, i%, 1) = "." THEN EXIT FOR
  NEXT i%
  BroadcastIP$ = LEFT$(ip$, i% - 1) + ".255"
END FUNCTION

FUNCTION NowMs%()
  NowMs% = INT(TIMER)
END FUNCTION

SUB SendOpen1(role$, val%)
  seq% = seq% + 1
  ' Role + value + our gameId so the other side can just store by role
  UdpBroadcast "OPEN1," + role$ + "," + STR$(val%) + "," + gameId$ + "," + STR$(seq%)
END SUB

FUNCTION RandHex$(n%)
  LOCAL s$, ii%
  s$ = ""
  FOR ii% = 1 TO n%
    s$ = s$ + MID$("0123456789ABCDEF", 1 + INT(RND * 16), 1)
  NEXT
  RandHex$ = s$
END FUNCTION

SUB AfterPairingKickoff
  LOCAL t%
  IF pairedDone% THEN EXIT SUB

  StatusHUD("Paired")
  t% = NowMs%() + 2000
  DO WHILE NowMs%() < t%: PAUSE 20: LOOP

  COLOR bgColor, bgColor
  BOX 0,0,W,14, , bgColor

  pairedDone% = 1

  IF myRole$ = "WHITE" THEN
    DoOpeningRoll_NetMaster
  ENDIF
END SUB

SUB StatusHUD(msg$)
  IF showHUD% = 0 THEN EXIT SUB
  IF pairedDone% THEN EXIT SUB

  LOCAL ip$, role$, s$
  ip$ = MM.INFO(IP ADDRESS)
  IF myRole$ = "" THEN role$ = "-" ELSE role$ = myRole$

  s$ = bcast$ + "Role:" + role$ + "  started:" + STR$(started%) + "  peer:" + STR$(peerSeen%) + "  IP:" + ip$ + "  msg:" + msg$
  IF lastPeer$ <> "" THEN
    s$ = s$ + "  lastPeer:" + lastPeer$
  ELSE
    s$ = s$ + "  lastPeer:-"
  ENDIF

  COLOR RGB(255,255,255), bgColor
  BOX 0,0,W,14, , bgColor
  PRINT @(0,0) s$
END SUB


SUB EnsureWifiAndBroadcasts()
  ' Start Wi-Fi if not already connected; wait up to ~6s
  LOCAL t0%, ip$
  ip$ = MM.INFO(IP ADDRESS)
  IF ip$ = "" OR ip$ = "0.0.0.0" THEN
    ' TODO: set your SSID/PASS here, or comment this if you auto-join elsewhere.
    ' WEB START STA "YourSSID","YourPass"
    t0% = NowMs%()
    DO
      ip$ = MM.INFO(IP ADDRESS)
      IF ip$ <> "" AND ip$ <> "0.0.0.0" THEN EXIT DO
      PAUSE 100
    LOOP WHILE NowMs%() - t0% < 6000
  ENDIF

  ' Compute broadcasts even if IP is weird — fall back to all-ones
  bcast$    = BroadcastIP$()
  IF bcast$ = "" OR LEFT$(bcast$,2)="0." THEN bcast$ = "255.255.255.255"
  bcast255$ = "255.255.255.255"
END SUB


' === NET init/close/send/recv ==============================================

SUB NetInit()
  EnsureWifiAndBroadcasts
  WEB UDP OPEN SERVER PORT PORT%
  WEB UDP INTERRUPT OnUDP

  gameId$     = RandHex$(8)
  myRole$     = ""
  started%    = 0
  peerSeen%   = 0
  seq%        = 1
  lastSeq%    = 0

  tStart%     = NowMs%()
  tLastHello% = 0

  hudHideAt%  = -1
  hudHidden%  = 0

  pairedDone% = 0
  StatusHUD("NetInit")
END SUB



SUB OnUDP
  LOCAL a$, m$
  a$ = MM.ADDRESS$
  m$ = MM.MESSAGE$

  ' Ignore our own traffic
  IF a$ = MM.INFO(IP ADDRESS) THEN EXIT SUB

  lastPeer$ = a$
  peerSeen% = 1
  StatusHUD("RX:" + LEFT$(m$, 5))   ' quick visual ping
  HandlePacket m$
END SUB



SUB NetClose()
  ' WEB UDP CLOSE
END SUB

SUB UdpBroadcast(msg$)
  ' Dual broadcast (some APs only allow subnet, some all-ones)
  WEB UDP SEND bcast$,    PORT%, msg$
  WEB UDP SEND bcast255$, PORT%, msg$
END SUB

'FUNCTION UdpRecvLine$(BYREF from$)
'  LOCAL r$, rp%
'  from$ = ""
'  r$ = ""
'  WEB UDP RECV FROM from$, rp%, r$
'  UdpRecvLine$ = r$
'END FUNCTION



SUB SendHello(role$)
  ' Blast both broadcasts for discovery, every time
  UdpBroadcast "HELLO," + role$ + "," + gameId$
END SUB


SUB SendOpen(wd%, bd%)
  seq% = seq% + 1
  UdpBroadcast "OPEN," + STR$(wd%) + "," + STR$(bd%) + "," + STR$(seq%)
END SUB

SUB SendDice(roller$, dd1%, dd2%)
  seq% = seq% + 1
  UdpBroadcast "DICE," + roller$ + "," + STR$(dd1%) + "," + STR$(dd2%) + "," + STR$(seq%)
END SUB

SUB SendBoard(nextTurn$)
  LOCAL s$
  s$ = SerializeBoard$()
  seq% = seq% + 1
  UdpBroadcast "BOARD," + nextTurn$ + "," + s$ + "," + STR$(seq%)
END SUB

SUB SendEndTurn(nextTurn$)
  seq% = seq% + 1
  UdpBroadcast "ENDTURN," + nextTurn$ + "," + STR$(seq%)
END SUB

' Trim any characters in c$ from the start and end of s$
FUNCTION Trim$(s$, c$)
  Trim$ = RTrim$(LTrim$(s$, c$), c$)
END FUNCTION

' Trim from the end
FUNCTION RTrim$(s$, c$)
  LOCAL j%
  j% = LEN(s$)
  DO WHILE j% > 0 AND INSTR(c$, MID$(s$, j%, 1)) > 0
    j% = j% - 1
  LOOP
  RTrim$ = LEFT$(s$, j%)
END FUNCTION

' Trim from the start
FUNCTION LTrim$(s$, c$)
  LOCAL i%, n%
  n% = LEN(s$)
  i% = 1
  DO WHILE i% <= n% AND INSTR(c$, MID$(s$, i%, 1)) > 0
    i% = i% + 1
  LOOP
  LTrim$ = MID$(s$, i%)
END FUNCTION


FUNCTION SplitCSV$(s$)()
  LOCAL a$(), p%, q%, t$
  REDIM a$(0)
  p% = 1
  DO
    q% = INSTR(p%, s$, ",")
    IF q% = 0 THEN
      t$ = MID$(s$, p%)
    ELSE
      t$ = MID$(s$, p%, q% - p%)
    ENDIF
    IF a$(0) = "" AND UBOUND(a$) = 0 THEN
      a$(0) = LTRIM$(RTRIM$(t$))
    ELSE
      REDIM PRESERVE a$(UBOUND(a$) + 1)
      a$(UBOUND(a$)) = LTRIM$(RTRIM$(t$))
    END IF
    IF q% = 0 THEN EXIT DO
    p% = q% + 1
  LOOP
  SplitCSV$ = a$
END FUNCTION

SUB SplitCSVInto(s$)
  LOCAL p%, q%, t$, idx%, lim%
  lim% = RX_MAX%

  ' clear previous tokens (use 1..lim%)
  FOR idx% = 1 TO lim%: rxParts$(idx%) = "": NEXT
  rxCount% = 0

  idx% = 1
  p% = 1
  DO
    q% = INSTR(p%, s$, ",")
    IF q% = 0 THEN
      t$ = MID$(s$, p%)
    ELSE
      t$ = MID$(s$, p%, q% - p%)
    ENDIF

    IF idx% <= lim% THEN
      rxParts$(idx%) = t$
      rxCount% = idx%          ' count = last index written
    ENDIF

    IF q% = 0 THEN EXIT DO
    idx% = idx% + 1
    p%   = q% + 1
  LOOP
END SUB








SUB HandlePacket(pkt$)
  LOCAL n%, tag$, thisSeq%, nextTurn$, otherRole$, otherId$
  IF pkt$ = "" THEN EXIT SUB
  IF INSTR(pkt$, ",") = 0 THEN EXIT SUB

  SplitCSVInto pkt$
  n% = rxCount%            ' 1-based count
  IF n% < 1 THEN EXIT SUB

  tag$ = UCASE$(rxParts$(1))

  SELECT CASE tag$

    CASE "HELLO"
      IF n% >= 3 THEN
        otherRole$ = UCASE$(rxParts$(2))
        otherId$   = rxParts$(3)
        IF otherId$ = gameId$ THEN EXIT SUB

        peerSeen% = 1

        IF myRole$ = "" THEN
          IF otherRole$ = "WHITE" THEN
            myRole$ = "BROWN" : screenFlipped = 1
          ELSE
            myRole$ = "WHITE" : screenFlipped = 0
          ENDIF
          SendHello myRole$
          RedrawAll
        ELSE
          IF myRole$ = otherRole$ THEN
            IF myRole$ = "WHITE" THEN
              IF gameId$ > otherId$ THEN
                myRole$ = "BROWN" : screenFlipped = 1
                SendHello myRole$
                RedrawAll
              ELSE
                SendHello myRole$
              ENDIF
            ELSE
              IF gameId$ < otherId$ THEN
                myRole$ = "WHITE" : screenFlipped = 0
                SendHello myRole$
                RedrawAll
              ELSE
                SendHello myRole$
              ENDIF
            ENDIF
          ENDIF
        ENDIF

        ' paired when roles are complementary
        IF myRole$ <> "" AND otherRole$ <> "" AND myRole$ <> otherRole$ THEN
          IF started% = 0 THEN
            started%      = 1
            postPairingAt% = NowMs%() + 2000
          ENDIF
        ENDIF
      ENDIF



    CASE "OPEN"
      ' OPEN,<wd>,<bd>,<seq>
      IF n% >= 4 THEN
        thisSeq% = VAL(rxParts$(4))
        IF thisSeq% > lastSeq% THEN
          lastSeq% = thisSeq%
          ApplyOpening VAL(rxParts$(2)), VAL(rxParts$(3))
        ENDIF
      ENDIF

    CASE "OPEN1"
      ' OPEN1,<role>,<val>,<otherGameId>,<seq>
      IF n% >= 5 THEN
        ' Optional: bump lastSeq% (keeps ordering monotonic)
        thisSeq% = VAL(rxParts$(5))
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
      ' DICE,<roller>,<d1>,<d2>,<seq>
      IF n% >= 5 THEN
        thisSeq% = VAL(rxParts$(5))
        IF thisSeq% > lastSeq% THEN
          lastSeq% = thisSeq%
          ApplyDice UCASE$(rxParts$(2)), VAL(rxParts$(3)), VAL(rxParts$(4))
        ENDIF
      ENDIF

    CASE "BOARD"
      ' BOARD,<nextTurn>,<24 pts>,<whiteBar>,<blackBar>,<whiteOff>,<blackOff>,<seq>
      IF n% >= 31 THEN
        thisSeq% = VAL(rxParts$(n%))
        IF thisSeq% > lastSeq% THEN
          lastSeq% = thisSeq%
          ApplyBoard1Based
        ENDIF
      ENDIF

    CASE "ENDTURN"
      ' ENDTURN,<nextTurn>,<seq>
      IF n% >= 3 THEN
        thisSeq% = VAL(rxParts$(3))
        IF thisSeq% > lastSeq% THEN
          lastSeq% = thisSeq%
          nextTurn$ = UCASE$(rxParts$(2))
          ApplyEndTurn nextTurn$
        ENDIF
      ENDIF

  END SELECT
END SUB

SUB NetPoll()
  LOCAL from$, pkt$, now%
  now% = NowMs%()

  ' --- Phase 1: LISTEN ONLY for first 5 seconds ---
  IF myRole$ = "" THEN
    ' listen (no sending, no role assignment)
    'pkt$ = UdpRecvLine$(from$)
    'IF pkt$ <> "" THEN HandlePacket pkt$

    ' after 5s of silence, claim WHITE and start advertising
    IF now% - tStart% > HANDSHAKE_LISTEN_MS% THEN
      myRole$ = "WHITE"
      screenFlipped = 0
      tLastHello% = 0         ' force immediate HELLO on next block
    ENDIF

    StatusHUD("Listening...")
    EXIT SUB
  ENDIF

  ' --- Phase 2: after claiming a role, advertise until paired ---
  IF started% = 0 THEN
    IF now% - tLastHello% >= HELLO_RETRY_MS% THEN
      SendHello myRole$
      tLastHello% = now%
    ENDIF
    'pkt$ = UdpRecvLine$(from$)
    'IF pkt$ <> "" THEN HandlePacket pkt$
    EXIT SUB
  ENDIF
  ' after pairing, wait 2 seconds, then hide HUD exactly once
  IF started% = 1 AND kickoffDone% = 0 THEN
    IF postPairingAt% > 0 AND NowMs%() >= postPairingAt% THEN
      showHUD%     = 0
      kickoffDone% = 1
      ' do not roll here; the OPEN1 exchange below will handle the opening
    END IF
    EXIT SUB
  END IF


  ' --- Opening exchange: symmetric one-die-per-side until not a tie ---
  IF started% AND openingDone% = 0 THEN
    ' Ensure our local single die is chosen & sent (once), then resend every 1s until both received.
    IF myRole$ = "WHITE" THEN
      IF haveW% = 0 THEN
        openW% = INT(RND * 6) + 1
        haveW% = 1
        SendOpen1 "WHITE", openW% : tLastOpen% = NowMs%()
      ELSEIF NowMs%() - tLastOpen% >= 1000 AND haveB% = 0 THEN
        SendOpen1 "WHITE", openW% : tLastOpen% = NowMs%()
      ENDIF
    ELSE
      IF haveB% = 0 THEN
        openB% = INT(RND * 6) + 1
        haveB% = 1
        SendOpen1 "BROWN", openB% : tLastOpen% = NowMs%()
      ELSEIF NowMs%() - tLastOpen% >= 1000 AND haveW% = 0 THEN
        SendOpen1 "BROWN", openB% : tLastOpen% = NowMs%()
      ENDIF
    ENDIF

    ' If we have both values, resolve tie or finish.
    IF haveW% AND haveB% THEN
      IF openW% = openB% THEN
        ' Tie: clear and repeat (both sides do this symmetrically)
        haveW% = 0 : haveB% = 0
      ELSE
        ' Not a tie: animate and lock in the first turn & dice
        AnimateOpeningAndApply openW%, openB%
        openingDone% = 1
        ' canRoll stays 0; the winner will move immediately using m1/m2 we set.
      ENDIF
    ENDIF

    ' While opening not done, skip normal play path this tick.
    EXIT SUB
  END IF

  ' --- Phase 3: normal play ---
  'pkt$ = UdpRecvLine$(from$)
  'IF pkt$ <> "" THEN HandlePacket pkt$
END SUB

SUB AnimateOpeningAndApply(wd%, bd%)
  ' wd% is WHITEs die, bd% is BROWNs die

  ' --- All locals must be declared up-front in MMBasic ---
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

  ' --- quick “rolling” animation frames ---
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

  ' --- show the agreed final values ---
  IF prevBD THEN ClearLargePips xB, y, size, prevBD, brownFill
  IF prevWD THEN ClearLargePips xW, y, size, prevWD, whiteFill
  DrawLargePips xB, y, size, bd%, pipB
  DrawLargePips xW, y, size, wd%, pipW

  ' --- flash the winners die ---
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

  ' --- apply first turn: winner uses both dice ---
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

' === Render helper (fixed by role) =========================================
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

  IF screenFlipped THEN
    trayX = W - (X_OFFSET + 12 * POINT_W + BAR_W + TRAY_W)
  ELSE
    trayX = X_OFFSET + 12 * POINT_W + BAR_W
  ENDIF

  pieceH = INT((H/2) / 15)

  IF NOT screenFlipped THEN
    count = whiteOff: fillCol = RGB(240,240,220)
    FOR i = 1 TO count
      rectX = trayX + 1
      rectY = H - i * pieceH
      RBOX rectX, rectY, TRAY_W - 2, pieceH, 0, , fillCol
    NEXT

    count = blackOff: fillCol = RGB(100,60,20)
    FOR i = 1 TO count
      rectX = trayX + 1
      rectY = (i - 1) * pieceH
      RBOX rectX, rectY, TRAY_W - 2, pieceH, 0, , fillCol
    NEXT
  ELSE
    count = whiteOff: fillCol = RGB(240,240,220)
    FOR i = 1 TO count
      rectX = trayX + 1
      rectY = (i - 1) * pieceH
      RBOX rectX, rectY, TRAY_W - 2, pieceH, 0, , fillCol
    NEXT

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
  rawX = X_OFFSET + 6 * POINT_W
  IF screenFlipped THEN
    xLine = W - (rawX + BAR_W)
  ELSE
    xLine = rawX
  ENDIF
  LINE xLine, 0, xLine, H, BAR_W, barColor
  circleX = xLine + BAR_W / 2
  centerY = H / 2
  border = RGB(0,0,0): fill = RGB(240,240,220)
  FOR j = 1 TO whiteBar
    offsetY = j * (PIECE_R * 2 + 2)
    cy = centerY - offsetY + PIECE_R
    cy = FY(cy)
    CIRCLE circleX, cy, PIECE_R, 1, , border, fill
  NEXT
  border = RGB(0,60,20): fill = RGB(100,60,20)
  FOR j = 1 TO blackBar
    offsetY = j * (PIECE_R * 2 + 2)
    cy = centerY + offsetY - PIECE_R
    cy = FY(cy)
    CIRCLE circleX, cy, PIECE_R, 1, , border, fill
  NEXT
END SUB

SUB InitPieces(p())
  FOR i = 0 TO 23: p(i) = 0: NEXT
  p(0) = 2
  p(11) = 5
  p(16) = 3
  p(18) = 5
  p(23) = -2
  p(12) = -5
  p(7)  = -3
  p(5)  = -5
END SUB

' === Build Valid Points ===
SUB BuildValidPoints(p(), v(), isWhite)
  FOR i = 0 TO 23
    v(i) = 1
  NEXT
END SUB

' === Draw Checkers Subroutine ===
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

' === BuildMovePoints Subroutine ===
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

' === Pick or Drop Subroutine ===
SUB PickDrop
  LOCAL iFlash, dist, usedDie
  ' Attempt pick-up if nothing is picked
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
    ' Drop-off phase
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
        usedDie = 0
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

' === End Turn Subroutine (MODIFIED for Wi-Fi) ===
SUB EndTurn
  IF turnIsWhite THEN
    whiteCursor = cursorIndex
  ELSE
    blackCursor = cursorIndex
  ENDIF

  ' DO NOT FLIP: orientation fixed by role
  ' screenFlipped = 1 - screenFlipped  ' removed

  turnIsWhite = 1 - turnIsWhite

  canRoll = 1
  doubleFlag = 0
  movesLeft  = 0
  m1         = 0
  m2         = 0
  state = 0

  ' Send board + endturn
  LOCAL nextTurn$
  IF turnIsWhite THEN
    nextTurn$ = "WHITE"
  ELSE
    nextTurn$ = "BROWN"
  ENDIF
  SendBoard nextTurn$
  SendEndTurn nextTurn$

  RedrawAll
  BuildValidPoints pieces(), validPoints(), turnIsWhite
END SUB

' === Bar-Off Subroutine ===
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

' === Build Re-Entry Points ===
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

' === Bear-Off Subroutine ===
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
    gameOver
    END
  ENDIF
  
  RETURN

invalidOff:
  FOR iFlash = 1 TO 3
    DrawCursor cursorIndex, 1: PAUSE 100
    DrawCursor cursorIndex, 0: PAUSE 100
  NEXT
END SUB

SUB gameOver
  CLS
  PRINT "YOU WIN"
END SUB

' === Draw two large dice (kept for completeness) ===
SUB DrawLargeDice(brownVal, whiteVal)
  LOCAL xB, xW, y, size, corner

  size   = 48
  corner = 6
  y      = (H - size) / 2

  xB = (W / 4) - (size / 2)
  RBOX xB, y, size, size, corner, RGB(0,0,0), RGB(100,60,20)
  DrawLargePips xB, y, size, brownVal, RGB(255,255,255)

  xW = (3 * W / 4) - (size / 2)
  RBOX xW, y, size, size, corner, RGB(0,0,0), RGB(240,240,220)
  DrawLargePips xW, y, size, whiteVal, RGB(0,0,0)
END SUB

' === Draw pip layout for a large die ===
SUB DrawLargePips(x, y, size, val, col)
  LOCAL cx, cy, r, off
  r   = size \ 12
  off = size \ 4

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

' === OPENING ROLL (network-aware) ==========================================
SUB DoOpeningRoll_NetMaster
  ' WHITE performs animated opening roll, then sends OPEN
  LOCAL rolls, i, bd, wd, prevBD, prevWD
  LOCAL size, corner, y, xB, xW
  LOCAL brownFill, whiteFill
  LOCAL winX, winY, winFill, pipCol, b

  size      = 96
  corner    = size \ 8
  y         = (H - size) \ 2
  xB        = (W \ 4) - (size \ 2)
  xW        = (3 * W \ 4) - (size \ 2)

  brownFill = RGB(100,60,20)
  whiteFill = RGB(240,240,220)

  COLOR bgColor, bgColor
  CLS
  RBOX xB, y, size, size, corner, RGB(0,0,0), brownFill
  RBOX xW, y, size, size, corner, RGB(0,0,0), whiteFill

  prevBD = 0 : prevWD = 0

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

  IF bd > wd THEN
    turnIsWhite = 0
    d1 = bd: d2 = wd
  ELSE
    turnIsWhite = 1
    d1 = wd: d2 = bd
  ENDIF

  m1 = d1: m2 = d2

  IF turnIsWhite THEN
    winX    = xW
    winY    = y
    winFill = whiteFill
    pipCol  = RGB(0,0,0)
  ELSE
    winX    = xB
    winY    = y
    winFill = brownFill
    pipCol  = RGB(255,255,255)
  ENDIF
  PAUSE 1000
  FOR b = 1 TO 5
    ClearLargePips winX, winY, size, d1, winFill
    PAUSE 200
    DrawLargePips   winX, winY, size, d1, pipCol
    PAUSE 200
  NEXT
  PAUSE 500

  ' Send to peer
  SendOpen d1, d2

  canRoll = 0
  RedrawAll
END SUB

SUB ApplyOpening(wd%, bd%)
  ' BROWN side adopts WHITE's opening roll
  IF bd% > wd% THEN
    turnIsWhite = 0
    d1 = bd%: d2 = wd%
  ELSE
    turnIsWhite = 1
    d1 = wd%: d2 = bd%
  ENDIF
  m1 = d1: m2 = d2
  canRoll = 0
  RedrawAll
END SUB

' === RollDice Subroutine (broadcast) =======================================
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

  ' Broadcast the roll
  SendDice myRole$, d1, d2
END SUB

' === ApplyDice from network ===============================================
SUB ApplyDice(roller$, dd1%, dd2%)
  d1 = dd1%
  d2 = dd2%
  m1 = d1
  m2 = d2
  IF d1 = d2 THEN
    doubleFlag = 1
    dieVal = d1
    movesLeft = 4
  ELSE
    doubleFlag = 0
    movesLeft = 2
  ENDIF
  canRoll = 0
  RedrawAll
END SUB

' === Serialize/Apply board for sync ========================================
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

SUB ApplyBoard(parts$(), n%)
  ' parts$: 0=BOARD, 1=nextTurn, 2..25=24 points, 26=whiteBar, 27=blackBar, 28=whiteOff, 29=blackOff, 30=seq
  LOCAL idx%
  FOR idx% = 0 TO 23
    pieces(idx%) = VAL(parts$(2 + idx%))
  NEXT
  whiteBar = VAL(parts$(26))
  blackBar = VAL(parts$(27))
  whiteOff = VAL(parts$(28))
  blackOff = VAL(parts$(29))

  turnIsWhite = (UCASE$(parts$(1)) = "WHITE")
  RedrawAll
END SUB

SUB ApplyBoard1Based
  LOCAL idx%
  ' rxParts$(1)=BOARD, (2)=nextTurn, (3..26)=24 points, (27)=whiteBar, (28)=blackBar,
  '               (29)=whiteOff, (30)=blackOff, (31)=seq
  FOR idx% = 0 TO 23
    pieces(idx%) = VAL(rxParts$(3 + idx%))
  NEXT
  whiteBar = VAL(rxParts$(27))
  blackBar = VAL(rxParts$(28))
  whiteOff = VAL(rxParts$(29))
  blackOff = VAL(rxParts$(30))
  turnIsWhite = (UCASE$(rxParts$(2)) = "WHITE")
  RedrawAll
END SUB



SUB ApplyEndTurn(nextTurn$)
  turnIsWhite = (UCASE$(nextTurn$) = "WHITE")
  hasPicked   = 0

  ' reset for the player who is about to act on this device
  canRoll     = 1
  doubleFlag  = 0
  movesLeft   = 0
  m1 = 0 : m2 = 0
  d1 = 0 : d2 = 0         ' draw blank dice until a roll happens

  BuildValidPoints pieces(), validPoints(), turnIsWhite
  RedrawAll
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

' === Navigate Cursor Subroutine (unchanged logic) ==========================
SUB NavigateCursor
  LOCAL newIdx, row, col, colVis, keyChar$

  DrawCursor cursorIndex, 1

  row = cursorIndex \ 12
  col = cursorIndex MOD 12
  IF row = 0 THEN
    colVis = 11 - col
  ELSE
    colVis = col
  ENDIF

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
  IF (turnIsWhite AND whiteBar > 0) OR (NOT turnIsWhite AND blackBar > 0) THEN
    hasPicked = 1
  ENDIF
  DrawCursor cursorIndex, 0
END SUB

' === MAIN ===================================================================

' Seed + defaults
whiteOff = 0 
blackOff = 0
whiteCursor = 23
blackCursor = 0
turnIsWhite = 1
canRoll = 1
RANDOMIZE TIMER

' Init network % board
NetInit
InitPieces pieces()

' Initial Draw
ClearScreen
DrawBoard
DrawBearTray
DrawOffTrayPieces
DrawCenterBar
DrawCheckers pieces()
DrawDice turnIsWhite

' Build valid points BEFORE choosing the initial cursor
BuildValidPoints pieces(), validPoints(), turnIsWhite

FOR i = 0 TO 23
  cursorSeq(i) = i
NEXT
hasPicked   = 0
pickedPoint = -1

' Find the first valid point, wrapping safely (no out-of-bounds)
cursorIndex = 0
i = 0
DO WHILE validPoints(cursorIndex) = 0 AND i < 24
  cursorIndex = (cursorIndex + 1) MOD 24
  i = i + 1
LOOP
' (If none are valid, cursorIndex stays 0 — harmless)


' === Main Loop ===
DO
  NetPoll

  IF myRole$ = "" OR started% = 0 THEN
    PAUSE 10
    k$ = INKEY$: IF k$ <> "" THEN k$ = "" ' ignore keys until paired
    CONTINUE DO
  ENDIF
  ' block keys until opening exchange is done
  IF openingDone% = 0 THEN
    PAUSE 10
    k$ = INKEY$: IF k$ <> "" THEN k$ = ""
    CONTINUE DO
  END IF
  
  k$ = INKEY$
  
  IF NOT IsMyTurn%() THEN
    ' not my turn so ignore any key
    IF k$ <> "" THEN k$ = ""
    StatusHUD("Waiting for opponent")
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
        BuildValidPoints pieces(),validPoints(),turnIsWhite
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
            IF validPoints(i) = 1 THEN
              legalExists = 1: EXIT FOR
            ENDIF
          NEXT
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

        IF legalExists = 0 OR (doubleFlag AND movesLeft = 0) OR (NOT doubleFlag AND m1 = 0 AND m2 = 0) THEN
          DrawCursor cursorIndex, 1
          EndTurn
        ENDIF
      ENDIF

    CASE "B", "b"
      IF canRoll = 0 THEN
        bearOff
      ENDIF

    CASE CHR$(130), CHR$(128), CHR$(131), CHR$(129) ' left/up/right/down
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
  StatusHUD("")
LOOP
' ===========================================================================

