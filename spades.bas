' ============================================================
' SPADES for PicoCalc
' MMBasic / WebMite  ·  2-player networked
'
' Phase 0 — Pairing      (NetPair)
' Phase 1 — Variant pick (PickVariant)
' Phase 2 — Setup        (DoSetup)
' Phase 3 — Bidding      (DoBidding)   stub
' Phase 4 — Play         (DoPlay)
' Phase 5 — Scoring      (DoScoring)
'
' Messages:
'   HELLO n     broadcast during pairing
'   ASSIGN r    assigner sends role to peer (r=1 or 2)
'   VARIANT v   0=face-down  1=face-up discards
'   DECK csv   full shuffled deck as 52 comma-separated card codes
'   SETUP c     setup turn done; c=discarded card (0=face-down)
'   BID n       bid value (0=nil)
'   PLAY c      card played  (suit*100+value)
'
' Card encoding:  suit*100 + value
'   Suit:  1=Club 2=Diamond 3=Heart 4=Spade
'   Value: 1=Ace  2-10  11=J  12=Q  13=K
'
' Role:  1=First Player (draws first)
'        2=Second Player (bids first, leads first trick)
'        Asterisk in stat panel marks Second Player.
' ============================================================
OPTION BASE 1
OPTION EXPLICIT
RANDOMIZE TIMER

' -- Colors --------------------------------------------------
CONST BG%     = RGB(0,160,0)
CONST WHITE%  = RGB(255,255,255)
CONST BLACK%  = RGB(0,0,0)
CONST DKBLUE% = RGB(30,30,180)
CONST RED%    = RGB(180,0,0)
CONST CYAN%   = RGB(0,230,230)
CONST YELLOW% = RGB(255,220,0)
CONST GREY%   = RGB(160,160,160)

' -- Suit codes ----------------------------------------------
CONST CLUB%    = 1
CONST DIAMOND% = 2
CONST HEART%   = 3
CONST SPADE%   = 4

' -- Key codes -----------------------------------------------
CONST KEY_UP%    = 128
CONST KEY_DOWN%  = 129
CONST KEY_LEFT%  = 130
CONST KEY_RIGHT% = 131
CONST KEY_ENTER% = 13
CONST KEY_R%     = 82
CONST KEY_Q%     = 81

' -- Network -------------------------------------------------
CONST PORT% = 6000

' -- LEDs ----------------------------------------------------
CONST LEDCOUNT = 8
DIM ledBuf%(8)

' -- Card geometry -------------------------------------------
CONST CW%    = 40
CONST CSTEP% = 22
CONST CORG%  = 6
CONST FCW%   = 66
CONST FCH%   = 108
CONST STATW% = 56

' -- Computed layout -----------------------------------------
DIM ScrW% : ScrW% = MM.HRES
DIM ScrH% : ScrH% = MM.VRES
DIM CTH%  : CTH%  = (ScrH% * 22) \ 100
DIM OPP_Y%: OPP_Y%= 2
DIM MY_Y% : MY_Y% = ScrH% - CTH% - 2
DIM PLAYY%: PLAYY%= OPP_Y% + CTH% + 2
DIM PLAYW%: PLAYW%= ScrW% - 2 * STATW%
DIM PLAYH%: PLAYH%= MY_Y% - PLAYY% - 2
DIM PLAYX%: PLAYX%= STATW%

' -- Suit bitmaps (1-based, rows 1-8) ------------------------
DIM SP%(8)
DIM HT%(8)
DIM DM%(8)
DIM CL%(8)

' -- Deck & hands --------------------------------------------
DIM deck%(52)
DIM myHand%(13)
DIM myHSz%
DIM oppHSz%

' -- Game state ----------------------------------------------
DIM myRole%
DIM iAmAssigner%
DIM deckStr$    ' full deck order as CSV, sent from assigner to peer
DIM myScore%
DIM oppScore%
DIM myBid%
DIM oppBid%
DIM myTricks%
DIM oppTricks%
DIM myBags%
DIM oppBags%
DIM spadesBroken%
DIM myTurn%
DIM faceUpDiscard%
DIM gamePhase%
DIM handNum%
DIM trickNum%
DIM leadCard%
DIM myPlayedCard%
DIM oppPlayedCard%
DIM sel%
DIM deckPtr%
DIM setupDiscard%

' -- Networking ----------------------------------------------
DIM peer$
DIM myTicket%
DIM assigned%
DIM lastMsg$
DIM lastRcvd$   ' last processed MM.MESSAGE$ — prevents reprocessing same packet
DIM lastHello!

' -- Trick display -------------------------------------------
DIM trickMyCard%
DIM trickOppCard%

' ============================================================
'  MAIN
' ============================================================
InitSuitPatterns
InitLEDs

NetPair
PickVariant

DO
  handNum% = handNum% + 1
  oppHSz%  = 0          ' reset opponent card count — setup rebuilds from scratch
  DoSetup
  DoBidding
  DoPlay
  DoScoring
  IF myScore% >= 500 OR oppScore% >= 500 THEN EXIT DO
  ' Swap roles each hand — second player becomes first to draw next hand
  myRole% = 3 - myRole%
LOOP

ShowGameOver
WEB UDP CLOSE
END

' ============================================================
'  PHASE 0 — NET PAIR
' ============================================================
SUB NetPair
  LOCAL t$, src$, peerTicket%, assignedRole%

  WEB UDP OPEN PORT%
  myTicket%    = INT(RND * 1000000) + 1
  assigned%    = 0
  iAmAssigner% = 0
  peer$        = ""
  lastHello!   = -99

  CLS BG%
  TEXT ScrW%\2, ScrH%\2 - 10, "Waiting for opponent...", "CT", 1, 1, WHITE%, BG%

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
            IF RND > 0.5 THEN assignedRole% = 2 ELSE assignedRole% = 1
            myRole%      = 3 - assignedRole%
            assigned%    = 1
            iAmAssigner% = 1
            lastMsg$     = "ASSIGN " + STR$(assignedRole%)
            WEB UDP SEND peer$, PORT%, lastMsg$
          ELSE
            WEB UDP SEND peer$, PORT%, "HELLO " + STR$(myTicket%)
          END IF
        END IF

      ELSEIF LEFT$(t$,6) = "ASSIGN" AND assigned% = 0 THEN
        myRole%   = VAL(MID$(t$,8))
        peer$     = src$
        assigned% = 1
      END IF
    END IF

    IF INKEY$ = CHR$(KEY_Q%) THEN WEB UDP CLOSE : END
    PAUSE 10
  LOOP UNTIL assigned% = 1

  LED_Off
  CLS BG%
  TEXT ScrW%\2, ScrH%\2 - 10, "Opponent found!", "CT", 1, 1, WHITE%, BG%
  IF myRole% = 2 THEN
    TEXT ScrW%\2, ScrH%\2 + 8, "You lead first this hand", "CT", 1, 1, CYAN%, BG%
  ELSE
    TEXT ScrW%\2, ScrH%\2 + 8, "Opponent leads first", "CT", 1, 1, CYAN%, BG%
  END IF
  PAUSE 2000
END SUB

' ============================================================
'  PHASE 1 — PICK VARIANT
' ============================================================
SUB PickVariant
  LOCAL k$, chosen%
  CLS BG%

  IF myRole% = 1 THEN
    LED_Green
    TEXT ScrW%\2, 40,  "Discard variant:",      "CT", 1, 1, WHITE%,  BG%
    TEXT ScrW%\2, 70,  "ENTER = Face Down",      "CT", 1, 1, WHITE%,  BG%
    TEXT ScrW%\2, 88,  "(discards hidden)",       "CT", 1, 1, CYAN%,   BG%
    TEXT ScrW%\2, 115, "SPACE = Face Up",         "CT", 1, 1, WHITE%,  BG%
    TEXT ScrW%\2, 133, "(discards visible)",      "CT", 1, 1, CYAN%,   BG%
    chosen% = 0
    DO
      k$ = INKEY$
      IF k$ = CHR$(13) THEN faceUpDiscard% = 0 : chosen% = 1
      IF k$ = CHR$(32) THEN faceUpDiscard% = 1 : chosen% = 1
      IF k$ = CHR$(KEY_Q%) THEN WEB UDP CLOSE : END
      PAUSE 10
    LOOP UNTIL chosen% = 1
    lastMsg$ = "VARIANT " + STR$(faceUpDiscard%)
    WEB UDP SEND peer$, PORT%, lastMsg$
  ELSE
    LED_Off
    TEXT ScrW%\2, ScrH%\2, "Waiting for variant choice...", "CT", 1, 1, WHITE%, BG%
    DO
      IF MM.MESSAGE$ <> "" THEN
        IF LEFT$(MM.MESSAGE$,7) = "VARIANT" THEN
          faceUpDiscard% = VAL(MID$(MM.MESSAGE$,9))
          EXIT DO
        END IF
      END IF
      IF INKEY$ = CHR$(KEY_Q%) THEN WEB UDP CLOSE : END
      PAUSE 10
    LOOP
  END IF

  CLS BG%
  IF faceUpDiscard% THEN
    TEXT ScrW%\2, ScrH%\2, "Face-up discards", "CT", 1, 1, WHITE%, BG%
  ELSE
    TEXT ScrW%\2, ScrH%\2, "Face-down discards", "CT", 1, 1, WHITE%, BG%
  END IF
  PAUSE 1200
END SUB

' ============================================================
'  PHASE 2 — SETUP
' ============================================================
SUB DoSetup
  LOCAL setupTurn%, myCount%, oppCount%
  LOCAL card1%, card2%, discarded%, kept%
  LOCAL k$, msg$, i%, p%, nxt%, idx%, keptAlready%

  lastRcvd$ = ""   ' clear stale messages from previous phase

  IF iAmAssigner% THEN
    ' Shuffle deck and send complete order as CSV to peer
    BuildDeck
    ShuffleDeck
    deckStr$ = STR$(deck%(1))
    FOR i% = 2 TO 52
      deckStr$ = deckStr$ + "," + STR$(deck%(i%))
    NEXT i%
    lastMsg$ = "DECK " + deckStr$
    WEB UDP SEND peer$, PORT%, lastMsg$
  ELSE
    ' Wait for DECK message and reconstruct deck from it
    CLS BG%
    TEXT ScrW%\2, ScrH%\2, "Waiting for deck...", "CT", 1, 1, WHITE%, BG%
    DO
      IF MM.MESSAGE$ <> "" AND MM.MESSAGE$ <> lastRcvd$ THEN
        msg$      = MM.MESSAGE$
        lastRcvd$ = msg$
        IF LEFT$(msg$,4) = "DECK" THEN
          deckStr$ = MID$(msg$,6)
          ' Parse CSV into deck%()
          p% = 1 : idx% = 1
          DO
            nxt% = INSTR(p%, deckStr$, ",")
            IF nxt% = 0 THEN
              deck%(idx%) = VAL(MID$(deckStr$, p%))
              EXIT DO
            END IF
            deck%(idx%) = VAL(MID$(deckStr$, p%, nxt%-p%))
            idx% = idx% + 1
            p% = nxt% + 1
          LOOP
          EXIT DO
        END IF
      END IF
      IF INKEY$ = CHR$(KEY_Q%) THEN WEB UDP CLOSE : END
      PAUSE 10
    LOOP
  END IF

  myHSz%        = 0 : oppHSz%      = 0
  myCount%      = 0 : oppCount%    = 0
  deckPtr%      = 1
  setupDiscard% = 0
  spadesBroken% = 0
  sel%          = 1

  DrawSetupScreen
  ' Role 1 draws first — light LEDs for whoever goes first
  LOCAL whoseTurn% : whoseTurn% = 1
  IF myRole% = 1 THEN LED_Green ELSE LED_Off

  FOR setupTurn% = 1 TO 26

    card1% = deck%(deckPtr%)
    card2% = deck%(deckPtr%+1)

    IF whoseTurn% = myRole% THEN
      LED_Green
      DrawSetupCenterCard card1%
      ShowSetupMsg "D=Discard  K=Keep"
      keptAlready% = 0

      DO
        k$ = INKEY$
        IF k$ = "k" OR k$ = "K" THEN
          kept%      = card1%
          discarded% = card2%
          ' Add kept card to hand and show it first
          myCount%          = myCount% + 1
          myHand%(myCount%) = kept%
          myHSz%            = myCount%
          SortHand myHand%(), myHSz%
          DrawMyHand
          keptAlready% = 1
          ' Now show card2 briefly before discarding it
          DrawSetupCenterCard discarded%
          ShowSetupMsg "Discarding..."
          PAUSE 1000
          DrawSetupCenterCard 0
          EXIT DO
        END IF
        IF k$ = "d" OR k$ = "D" THEN
          kept%      = card2%
          discarded% = card1%
          ' Move discarded card to pile first, then show kept card
          DrawSetupCenterCard 0
          DrawSetupDiscard discarded%
          DrawSetupCenterCard kept%
          ShowSetupKept
          PAUSE 2000
          EXIT DO
        END IF
        IF k$ = CHR$(KEY_R%) AND lastMsg$ <> "" THEN
          WEB UDP SEND peer$, PORT%, lastMsg$
        END IF
        IF k$ = CHR$(KEY_Q%) THEN WEB UDP CLOSE : END
        PAUSE 10
      LOOP

      ' Add kept card to hand — only if K handler didn't already do it
      IF keptAlready% = 0 THEN
        myCount%          = myCount% + 1
        myHand%(myCount%) = kept%
        myHSz%            = myCount%
        SortHand myHand%(), myHSz%
      END IF

      setupDiscard% = discarded%
      DrawSetupCenterCard 0
      DrawSetupDiscard discarded%
      DrawMyHand

      IF faceUpDiscard% THEN
        lastMsg$ = "SETUP " + STR$(discarded%)
      ELSE
        lastMsg$ = "SETUP 0"
      END IF
      WEB UDP SEND peer$, PORT%, lastMsg$
      LED_Off

    ELSE
      ' Opponent's turn — block all input except Q and R
      LED_Off
      DrawSetupCenterCard 0
      ShowSetupMsg "Opponent's turn..."

      DO
        k$ = INKEY$
        IF k$ = CHR$(KEY_Q%) THEN WEB UDP CLOSE : END
        IF k$ = CHR$(KEY_R%) AND lastMsg$ <> "" THEN
          WEB UDP SEND peer$, PORT%, lastMsg$
        END IF
        IF MM.MESSAGE$ <> "" AND MM.MESSAGE$ <> lastRcvd$ THEN
          msg$      = MM.MESSAGE$
          lastRcvd$ = msg$
          IF LEFT$(msg$,5) = "SETUP" THEN
            discarded% = VAL(MID$(msg$,7))
            oppCount%  = oppCount% + 1
            oppHSz%    = oppCount%
            IF discarded% > 0 THEN
              setupDiscard% = discarded%
              DrawSetupDiscard discarded%
            END IF
            DrawOppHand
            EXIT DO
          END IF
        END IF
        PAUSE 10
      LOOP

    END IF

    deckPtr% = deckPtr% + 2
    IF whoseTurn% = 1 THEN whoseTurn% = 2 ELSE whoseTurn% = 1

  NEXT setupTurn%

  SortHand myHand%(), myHSz%
  sel%           = 1
  myPlayedCard%  = 0
  oppPlayedCard% = 0
  trickMyCard%   = 0
  trickOppCard%  = 0

  ShowSetupMsg "Setup complete!"
  PAUSE 1000

  ' Clear setup center area so nothing bleeds into play screen
  BOX PLAYX%-1, PLAYY%, PLAYW%+2, PLAYH%, 1, BG%, BG%

  ' Sync both players before proceeding to bidding
  ' Send SETUPDONE and wait for peer's SETUPDONE
  LED_Off
  lastMsg$ = "SETUPDONE"
  WEB UDP SEND peer$, PORT%, lastMsg$

  LOCAL gotDone%
  gotDone% = 0
  DO
    k$ = INKEY$
    IF k$ = CHR$(KEY_Q%) THEN WEB UDP CLOSE : END
    IF k$ = CHR$(KEY_R%) THEN WEB UDP SEND peer$, PORT%, lastMsg$
    IF MM.MESSAGE$ <> "" AND MM.MESSAGE$ <> lastRcvd$ THEN
      msg$ = MM.MESSAGE$
      lastRcvd$ = msg$
      IF msg$ = "SETUPDONE" THEN gotDone% = 1
    END IF
    PAUSE 10
  LOOP UNTIL gotDone% = 1

  PAUSE 500
END SUB

SUB DrawSetupScreen
  CLS BG%
  TEXT PLAYX%+FCW%\2+2,         PLAYY%+2, "Draw",    "CT", 1, 1, WHITE%, BG%
  TEXT PLAYX%+FCW%*2+FCW%\2+10, PLAYY%+2, "Discard", "CT", 1, 1, WHITE%, BG%
  DrawFullBack PLAYX%+2, PLAYY%+14
  DrawOppHand
  DrawMyHand
END SUB

SUB DrawSetupDiscard(card%)
  LOCAL dx% : dx% = PLAYX% + FCW% * 2 + 10
  BOX dx%, PLAYY%+14, FCW%+2, FCH%+2, 1, BG%, BG%
  IF card% > 0 THEN
    IF faceUpDiscard% THEN
      DrawFullCard dx%, PLAYY%+14, card%
    ELSE
      DrawFullBack dx%, PLAYY%+14
    END IF
  END IF
END SUB

SUB DrawSetupCenterCard(card%)
  LOCAL cx% : cx% = PLAYX% + FCW% + 6
  BOX cx%, PLAYY%+14, FCW%+2, FCH%+2, 1, BG%, BG%
  IF card% > 0 THEN DrawFullCard cx%, PLAYY%+14, card%
END SUB

SUB ShowSetupMsg(msg$)
  LOCAL my% : my% = PLAYY% + FCH% + 18
  BOX PLAYX%, my%, PLAYW%, 12, 1, BG%, BG%
  TEXT ScrW%\2, my%, msg$, "CT", 1, 1, YELLOW%, BG%
END SUB

SUB ShowSetupKept
  LOCAL my% : my% = PLAYY% + FCH% + 18
  BOX PLAYX%, my%, PLAYW%, 12, 1, BG%, BG%
  TEXT ScrW%\2, my%, "Kept!", "CT", 1, 1, RGB(0,220,0), BG%
END SUB

' ============================================================
'  PHASE 3 — BIDDING  (stub)
' ============================================================
SUB DoBidding
  LOCAL k$, msg$, curBid%

  lastRcvd$  = ""   ' clear stale messages from setup phase
  myTricks%  = 0
  oppTricks% = 0
  curBid%    = 3
  myBid%     = -1
  oppBid%    = -1

  ' Second Player bids first, First Player waits then bids
  IF myRole% = 2 THEN
    LED_Green
    DrawBidScreen curBid%
    curBid% = GetMyBid%(curBid%)
    myBid%   = curBid%
    lastMsg$ = "BID " + STR$(myBid%)
    WEB UDP SEND peer$, PORT%, lastMsg$
    LED_Off

    ' Wait for opponent bid
    DrawBidWait
    DO
      k$ = INKEY$
      IF k$ = CHR$(KEY_Q%) THEN WEB UDP CLOSE : END
      IF k$ = CHR$(KEY_R%) THEN WEB UDP SEND peer$, PORT%, lastMsg$
      IF MM.MESSAGE$ <> "" AND MM.MESSAGE$ <> lastRcvd$ THEN
        msg$      = MM.MESSAGE$
        lastRcvd$ = msg$
        IF LEFT$(msg$,3) = "BID" THEN oppBid% = VAL(MID$(msg$,5))
      END IF
      PAUSE 10
    LOOP UNTIL oppBid% >= 0

  ELSE
    ' Wait for Second Player's bid first
    LED_Off
    DrawBidWait
    DO
      k$ = INKEY$
      IF k$ = CHR$(KEY_Q%) THEN WEB UDP CLOSE : END
      IF k$ = CHR$(KEY_R%) AND lastMsg$ <> "" THEN WEB UDP SEND peer$, PORT%, lastMsg$
      IF MM.MESSAGE$ <> "" AND MM.MESSAGE$ <> lastRcvd$ THEN
        msg$      = MM.MESSAGE$
        lastRcvd$ = msg$
        IF LEFT$(msg$,3) = "BID" THEN oppBid% = VAL(MID$(msg$,5))
      END IF
      PAUSE 10
    LOOP UNTIL oppBid% >= 0

    ' Now I bid
    LED_Green
    DrawBidScreen curBid%
    curBid% = GetMyBid%(curBid%)
    myBid%   = curBid%
    lastMsg$ = "BID " + STR$(myBid%)
    WEB UDP SEND peer$, PORT%, lastMsg$
    LED_Off
  END IF

  ' Draw play screen with cards visible so player can bid intelligently
  CLS BG%
  DrawOppHand
  DrawMyHand
  DrawStatPanels
END SUB

' -- Bid selector — returns confirmed bid value ----------------
FUNCTION GetMyBid%(startBid%)
  LOCAL k$, bid%
  bid% = startBid%
  DO
    k$ = INKEY$
    IF k$ = CHR$(KEY_Q%) THEN WEB UDP CLOSE : END
    IF k$ <> "" THEN
      SELECT CASE ASC(k$)
        CASE KEY_UP%
          IF bid% < 13 THEN bid% = bid% + 1 : DrawBidValue bid%
        CASE KEY_DOWN%
          IF bid% > 0  THEN bid% = bid% - 1 : DrawBidValue bid%
        CASE KEY_ENTER%
          IF bid% = 0 THEN
            IF ConfirmNil%() THEN
              GetMyBid% = bid%
              EXIT FUNCTION
            END IF
            DrawBidScreen bid%   ' redraw after dialog
          ELSE
            GetMyBid% = bid%
            EXIT FUNCTION
          END IF
      END SELECT
    END IF
    PAUSE 10
  LOOP
END FUNCTION

' -- Bid screen -----------------------------------------------
SUB DrawBidScreen(bid%)
  BOX PLAYX%-1, PLAYY%, PLAYW%+2, PLAYH%, 1, BG%, BG%
  DrawStatPanels
  TEXT ScrW%\2, ScrH%\2 - 53, "Your bid:",           "CT", 1, 2, WHITE%, BG%
  DrawBidValue bid%
  TEXT ScrW%\2, ScrH%\2 + 50, "UP / DOWN to change", "CT", 1, 1, WHITE%, BG%
  TEXT ScrW%\2, ScrH%\2 + 66, "ENTER to confirm",    "CT", 1, 1, WHITE%, BG%
END SUB

SUB DrawBidValue(bid%)
  ' Scale 4 chars are 32×32px. "10" = 64px wide centred.
  ' Top of box must stay below "Your bid:" text (bottom edge ~ScrH%\2-37)
  BOX ScrW%\2 - 80, ScrH%\2 - 33, 160, 66, 1, BG%, BG%
  TEXT ScrW%\2, ScrH%\2 - 10, STR$(bid%), "CT", 1, 4, YELLOW%, BG%
END SUB

SUB DrawBidWait
  BOX PLAYX%-1, PLAYY%, PLAYW%+2, PLAYH%, 1, BG%, BG%
  DrawStatPanels
  TEXT ScrW%\2, ScrH%\2 - 8, "Waiting for",        "CT", 1, 1, WHITE%, BG%
  TEXT ScrW%\2, ScrH%\2 + 8, "opponent bid...",     "CT", 1, 1, WHITE%, BG%
END SUB

' -- Nil confirmation — returns 1=confirmed 0=cancelled -------
FUNCTION ConfirmNil%()
  LOCAL k$
  BOX PLAYX%-1, PLAYY%, PLAYW%+2, PLAYH%, 1, BG%, BG%
  TEXT ScrW%\2, ScrH%\2 - 50, "Bid NIL (0)?",           "CT", 1, 2, YELLOW%, BG%
  TEXT ScrW%\2, ScrH%\2 - 10, "Win NO tricks: +100 pts", "CT", 1, 1, WHITE%,  BG%
  TEXT ScrW%\2, ScrH%\2 + 8,  "Win ANY trick: -100 pts", "CT", 1, 1, WHITE%,  BG%
  TEXT ScrW%\2, ScrH%\2 + 40, "ENTER = Confirm",         "CT", 1, 1, GREY%,   BG%
  TEXT ScrW%\2, ScrH%\2 + 56, "ESC   = Go back",         "CT", 1, 1, GREY%,   BG%
  DO
    k$ = INKEY$
    IF k$ = CHR$(13) THEN ConfirmNil% = 1 : EXIT FUNCTION
    IF k$ = CHR$(27) THEN ConfirmNil% = 0 : EXIT FUNCTION
    IF k$ = CHR$(KEY_Q%) THEN WEB UDP CLOSE : END
    PAUSE 10
  LOOP
END FUNCTION

' ============================================================
'  PHASE 4 — PLAY
' ============================================================
SUB DoPlay
  LOCAL k$, msg$, comma%, newBroken%

  lastRcvd$ = ""   ' clear stale messages from bidding phase
  trickNum% = 0
  leadCard% = 0
  myTurn%   = (myRole% = 2)
  IF myTurn% THEN LED_Green ELSE LED_Off
  DrawTurnIndicator myTurn%

  DO
    k$ = INKEY$
    IF k$ = CHR$(KEY_Q%) THEN WEB UDP CLOSE : END

    IF k$ = CHR$(KEY_R%) THEN
      IF lastMsg$ <> "" AND peer$ <> "" THEN
        WEB UDP SEND peer$, PORT%, lastMsg$
        ShowMsg "Resent"
      END IF
    END IF

    IF myTurn% THEN
      SELECT CASE ASC(k$ + CHR$(0))
        CASE KEY_LEFT%
          IF sel% > 1 THEN MoveCursor sel% - 1
        CASE KEY_RIGHT%
          IF sel% < myHSz% THEN MoveCursor sel% + 1
        CASE KEY_ENTER%
          IF CanPlayCard%(myHand%(sel%)) THEN
            PlayMyCard sel%
          ELSE
            ShowMsg "Cannot play that card"
          END IF
      END SELECT
    END IF

    IF MM.MESSAGE$ <> "" AND MM.MESSAGE$ <> lastRcvd$ THEN
      msg$      = MM.MESSAGE$
      lastRcvd$ = msg$
      IF LEFT$(msg$,4) = "PLAY" THEN
        comma%         = INSTR(msg$, ",")
        oppPlayedCard% = VAL(MID$(msg$,6))
        newBroken%     = VAL(MID$(msg$, comma%+1))
        IF newBroken% = 1 AND spadesBroken% = 0 THEN
          spadesBroken% = 1
          DrawMyHand
        END IF
        trickOppCard%  = oppPlayedCard%
        IF oppHSz% > 0 THEN oppHSz% = oppHSz% - 1
        DrawOppHand
        DrawTrickArea
        IF leadCard% = 0 THEN leadCard% = oppPlayedCard%
        IF myPlayedCard% = 0 THEN
          myTurn% = 1
          LED_Green
          DrawTurnIndicator 1
        ELSE
          ResolveTrick
        END IF
      END IF
    END IF

    PAUSE 10
  LOOP UNTIL myTricks% + oppTricks% = 13
END SUB

' ============================================================
'  PHASE 5 — SCORING
' ============================================================
SUB DoScoring
  LOCAL myRound%, oppRound%, myBidStr$, oppBidStr$, k$, gotNext%

  ' My scoring
  IF myBid% = 0 THEN
    IF myTricks% = 0 THEN myRound% = 100 ELSE myRound% = -100
  ELSE
    IF myTricks% >= myBid% THEN
      myRound% = myBid% * 10 + (myTricks% - myBid%)
    ELSE
      myRound% = -(myBid% * 10)
    END IF
  END IF

  ' Opponent scoring
  IF oppBid% = 0 THEN
    IF oppTricks% = 0 THEN oppRound% = 100 ELSE oppRound% = -100
  ELSE
    IF oppTricks% >= oppBid% THEN
      oppRound% = oppBid% * 10 + (oppTricks% - oppBid%)
    ELSE
      oppRound% = -(oppBid% * 10)
    END IF
  END IF

  ' Sandbagging penalty already handled live in ResolveTrick

  myScore%  = myScore%  + myRound%
  oppScore% = oppScore% + oppRound%

  ' Summary screen

  IF myBid%  = 0 THEN myBidStr$  = "Nil" ELSE myBidStr$  = STR$(myBid%)
  IF oppBid% = 0 THEN oppBidStr$ = "Nil" ELSE oppBidStr$ = STR$(oppBid%)

  CLS BG%
  TEXT ScrW%\2, 30,  "Hand " + STR$(handNum%) + " complete",                    "CT", 1, 2, WHITE%, BG%
  TEXT ScrW%\2, 75,  "You:  bid " + myBidStr$  + "  took " + STR$(myTricks%),   "CT", 1, 1, WHITE%, BG%
  TEXT ScrW%\2, 95,  "Opp:  bid " + oppBidStr$ + "  took " + STR$(oppTricks%),  "CT", 1, 1, CYAN%,  BG%
  TEXT ScrW%\2, 125, "Your score: " + STR$(myScore%),                            "CT", 1, 1, WHITE%, BG%
  TEXT ScrW%\2, 145, "Opp score:  " + STR$(oppScore%),                           "CT", 1, 1, CYAN%,  BG%
  TEXT ScrW%\2, 185, "Press any key to continue", "CT", 1, 1, WHITE%, BG%
  ' Flush any buffered keypresses from play phase
  DO : LOOP UNTIL INKEY$ = ""
  ' Wait for deliberate keypress
  DO
    PAUSE 10
    IF INKEY$ <> "" THEN EXIT DO
  LOOP

  ' Sync both players before starting next hand
  ' Clear stale messages then exchange NEXTHAND
  lastRcvd$ = ""
  lastMsg$  = "NEXTHAND"
  WEB UDP SEND peer$, PORT%, lastMsg$
  TEXT ScrW%\2, 210, "Waiting for opponent...", "CT", 1, 1, GREY%, BG%

  gotNext% = 0
  DO
    k$ = INKEY$
    IF k$ = CHR$(KEY_Q%) THEN WEB UDP CLOSE : END
    IF k$ = CHR$(KEY_R%) THEN WEB UDP SEND peer$, PORT%, lastMsg$
    IF MM.MESSAGE$ <> "" AND MM.MESSAGE$ <> lastRcvd$ THEN
      lastRcvd$ = MM.MESSAGE$
      IF MM.MESSAGE$ = "NEXTHAND" THEN gotNext% = 1
    END IF
    PAUSE 10
  LOOP UNTIL gotNext% = 1
END SUB

' ============================================================
'  PLAY HELPERS
' ============================================================
FUNCTION CanPlayCard%(card%)
  LOCAL suit% : suit% = card% \ 100
  IF leadCard% = 0 THEN
    IF suit% = SPADE% AND spadesBroken% = 0 THEN
      CanPlayCard% = NOT HandHasNonSpade%()
    ELSE
      CanPlayCard% = 1
    END IF
    EXIT FUNCTION
  END IF
  LOCAL leadSuit% : leadSuit% = leadCard% \ 100
  IF suit% = leadSuit% THEN
    CanPlayCard% = 1
  ELSE
    CanPlayCard% = NOT HandHasSuit%(leadSuit%)
  END IF
END FUNCTION

SUB PlayMyCard(idx%)
  LOCAL card% : card% = myHand%(idx%)
  LOCAL suit% : suit% = card% \ 100
  IF suit% = SPADE% AND spadesBroken% = 0 THEN
    spadesBroken% = 1
    DrawMyHand
  END IF
  IF leadCard% = 0 THEN leadCard% = card%
  myPlayedCard% = card%
  trickMyCard%  = card%
  DrawTrickArea
  lastMsg$ = "PLAY " + STR$(card%) + "," + STR$(spadesBroken%)
  WEB UDP SEND peer$, PORT%, lastMsg$
  RemoveCard idx%
  myTurn% = 0
  LED_Off
  DrawTurnIndicator 0
  IF oppPlayedCard% <> 0 THEN ResolveTrick
END SUB

SUB ResolveTrick
  LOCAL winner%
  winner% = TrickWinner%(myPlayedCard%, oppPlayedCard%, leadCard% \ 100)
  IF winner% = 1 THEN
    myTricks%  = myTricks%  + 1
    myTurn%    = 1
    LED_Green
    ' Count bag immediately if we exceeded our bid (not for nil)
    IF myBid% > 0 AND myTricks% > myBid% THEN
      myBags% = myBags% + 1
      IF myBags% >= 10 THEN
        myScore% = myScore% - 100
        myBags%  = myBags% - 10
      END IF
    END IF
  ELSE
    oppTricks% = oppTricks% + 1
    myTurn%    = 0
    LED_Off
    ' Count opponent bag immediately if they exceeded their bid (not for nil)
    IF oppBid% > 0 AND oppTricks% > oppBid% THEN
      oppBags% = oppBags% + 1
      IF oppBags% >= 10 THEN
        oppScore% = oppScore% - 100
        oppBags%  = oppBags% - 10
      END IF
    END IF
  END IF
  trickNum%      = trickNum% + 1
  leadCard%      = 0
  myPlayedCard%  = 0
  oppPlayedCard% = 0
  DrawStatPanels
  FlashWinningCard winner%
  PAUSE 800
  trickMyCard%  = 0
  trickOppCard% = 0
  DrawTrickArea
  DrawTurnIndicator myTurn%
END SUB

' Briefly highlight the winning card with a yellow border
SUB FlashWinningCard(winner%)
  LOCAL cy%, lx%, rx%, wx%, wy%
  cy% = PLAYY% + (PLAYH% - FCH%) \ 2
  lx% = PLAYX% + PLAYW%\2 - FCW% - 8   ' opponent card x
  rx% = PLAYX% + PLAYW%\2 + 8           ' my card x
  IF winner% = 1 THEN wx% = rx% ELSE wx% = lx%
  wy% = cy%
  RectBorder wx%, wy%, FCW%, FCH%, YELLOW%
  PAUSE 700
  RectBorder wx%, wy%, FCW%, FCH%, BLACK%
END SUB

FUNCTION TrickWinner%(myCard%, oppCard%, leadSuit%)
  LOCAL mySuit%  : mySuit%  = myCard%  \ 100
  LOCAL oppSuit% : oppSuit% = oppCard% \ 100
  LOCAL myVal%   : myVal%   = myCard%  MOD 100
  LOCAL oppVal%  : oppVal%  = oppCard% MOD 100
  LOCAL myEff%   : myEff%   = myVal%  : IF myVal%  = 1 THEN myEff%  = 14
  LOCAL oppEff%  : oppEff%  = oppVal% : IF oppVal% = 1 THEN oppEff% = 14
  IF mySuit% = SPADE% AND oppSuit% <> SPADE% THEN TrickWinner% = 1 : EXIT FUNCTION
  IF oppSuit% = SPADE% AND mySuit% <> SPADE% THEN TrickWinner% = 2 : EXIT FUNCTION
  IF mySuit% = oppSuit% THEN
    IF myEff% > oppEff% THEN TrickWinner% = 1 ELSE TrickWinner% = 2
    EXIT FUNCTION
  END IF
  IF mySuit% = leadSuit% THEN TrickWinner% = 1 ELSE TrickWinner% = 2
END FUNCTION

' ============================================================
'  DECK
' ============================================================
SUB BuildDeck
  LOCAL s%, v%, i%
  i% = 1
  FOR s% = 1 TO 4
    FOR v% = 1 TO 13
      deck%(i%) = s% * 100 + v%
      i% = i% + 1
    NEXT v%
  NEXT s%
END SUB

SUB ShuffleDeck
  LOCAL i%, j%, tmp%
  FOR i% = 52 TO 2 STEP -1
    j%        = INT(RND * i%) + 1
    tmp%      = deck%(i%)
    deck%(i%) = deck%(j%)
    deck%(j%) = tmp%
  NEXT i%
END SUB

SUB SortHand(h%(), sz%)
  LOCAL i%, j%, tmp%
  ' Sort by suit then value, treating Ace (1) as high (14)
  FOR i% = 1 TO sz% - 1
    FOR j% = 1 TO sz% - i%
      IF SortKey%(h%(j%)) > SortKey%(h%(j%+1)) THEN
        tmp%      = h%(j%)
        h%(j%)    = h%(j%+1)
        h%(j%+1)  = tmp%
      END IF
    NEXT j%
  NEXT i%
END SUB

' Returns sort key: suit*100 + effective value (Ace=14)
FUNCTION SortKey%(card%)
  LOCAL s%, v%
  s% = card% \ 100
  v% = card% MOD 100
  IF v% = 1 THEN v% = 14
  SortKey% = s% * 100 + v%
END FUNCTION

' ============================================================
'  HAND QUERIES
' ============================================================
FUNCTION HandHasNonSpade%()
  LOCAL i%
  FOR i% = 1 TO myHSz%
    IF myHand%(i%) \ 100 <> SPADE% THEN HandHasNonSpade% = 1 : EXIT FUNCTION
  NEXT i%
  HandHasNonSpade% = 0
END FUNCTION

FUNCTION HandHasSuit%(suit%)
  LOCAL i%
  FOR i% = 1 TO myHSz%
    IF myHand%(i%) \ 100 = suit% THEN HandHasSuit% = 1 : EXIT FUNCTION
  NEXT i%
  HandHasSuit% = 0
END FUNCTION

' ============================================================
'  CARD REMOVE / CURSOR
' ============================================================
SUB RemoveCard(idx%)
  LOCAL i%
  IF myHSz% < 1 THEN EXIT SUB
  FOR i% = idx% TO myHSz% - 1
    myHand%(i%) = myHand%(i%+1)
  NEXT i%
  myHSz% = myHSz% - 1
  IF sel% > myHSz% THEN sel% = myHSz%
  DrawMyHand
END SUB

SUB MoveCursor(newSel%)
  VisibleCardBorder sel%,    BLACK%
  sel% = newSel%
  VisibleCardBorder sel%, YELLOW%
END SUB

SUB VisibleCardBorder(idx%, col%)
  LOCAL x%, y%, visW%
  x% = CORG% + (idx%-1) * CSTEP%
  y% = MY_Y%
  IF idx% = myHSz% THEN visW% = CW% ELSE visW% = CSTEP%
  LINE x%, y%,        x%+visW%, y%,        1, col%
  LINE x%, y%+1,      x%+visW%, y%+1,      1, col%
  LINE x%, y%+CTH%,   x%+visW%, y%+CTH%,   1, col%
  LINE x%, y%+CTH%-1, x%+visW%, y%+CTH%-1, 1, col%
  LINE x%,   y%, x%,   y%+CTH%, 1, col%
  LINE x%+1, y%, x%+1, y%+CTH%, 1, col%
  IF idx% = myHSz% THEN
    LINE x%+CW%,   y%, x%+CW%,   y%+CTH%, 1, col%
    LINE x%+CW%-1, y%, x%+CW%-1, y%+CTH%, 1, col%
  END IF
END SUB

' ============================================================
'  DRAW ROUTINES
' ============================================================
SUB DrawAll
  CLS BG%
  DrawOppHand
  DrawMyHand
  DrawTrickArea
  DrawStatPanels
END SUB

SUB DrawOppHand
  LOCAL i%
  BOX 0, OPP_Y%-2, ScrW%, CTH%+4, 1, BG%, BG%
  FOR i% = 1 TO oppHSz%
    DrawBackTab CORG% + (i%-1)*CSTEP%, OPP_Y%
  NEXT i%
END SUB

SUB DrawMyHand
  LOCAL i%, x%
  BOX 0, MY_Y%-2, ScrW%, CTH%+4, 1, BG%, BG%
  FOR i% = 1 TO myHSz%
    x% = CORG% + (i%-1)*CSTEP%
    DrawFaceTab x%, MY_Y%, myHand%(i%), (i% = sel%)
  NEXT i%
END SUB

SUB DrawTurnIndicator(myTurn%)
  LOCAL y% : y% = PLAYY% + PLAYH% - 14
  BOX PLAYX%, y%, PLAYW%, 14, 1, BG%, BG%
  IF myTurn% THEN
    TEXT ScrW%\2, y%+2, "YOUR TURN", "CT", 1, 1, YELLOW%, BG%
  END IF
END SUB

SUB DrawTrickArea
  LOCAL cy%, lx%, rx%
  cy% = PLAYY% + (PLAYH% - FCH%) \ 2
  lx% = PLAYX% + PLAYW%\2 - FCW% - 8
  rx% = PLAYX% + PLAYW%\2 + 8
  BOX PLAYX%-1, PLAYY%, PLAYW%+2, PLAYH%, 1, BG%, BG%
  IF trickOppCard% > 0 THEN DrawFullCard lx%, cy%, trickOppCard%
  IF trickMyCard%  > 0 THEN DrawFullCard rx%, cy%, trickMyCard%
END SUB

SUB RectBorder(x%, y%, w%, h%, col%)
  LINE x%,      y%,       x%+w%, y%,       1, col%
  LINE x%,      y%+1,     x%+w%, y%+1,     1, col%
  LINE x%,      y%+h%,    x%+w%, y%+h%,    1, col%
  LINE x%,      y%+h%-1,  x%+w%, y%+h%-1,  1, col%
  LINE x%,      y%,       x%,    y%+h%,    1, col%
  LINE x%+1,    y%,       x%+1,  y%+h%,    1, col%
  LINE x%+w%,   y%,       x%+w%, y%+h%,    1, col%
  LINE x%+w%-1, y%,       x%+w%-1,y%+h%,   1, col%
END SUB

SUB DrawFaceTab(x%, y%, card%, hl%)
  LOCAL s%, v%, sc%, bc%
  s%  = card% \ 100
  v%  = card% MOD 100
  sc% = SuitColor%(s%)
  IF hl% THEN bc% = YELLOW% ELSE bc% = BLACK%
  BOX x%, y%, CW%, CTH%, 1, WHITE%, WHITE%
  RectBorder x%, y%, CW%, CTH%, bc%
  TEXT x%+4, y%+4, ValStr$(v%), "LT", 1, 1, sc%, WHITE%
  DrawSuit s%, x%+CW%\2-7, y%+CTH%-32, 2, sc%
END SUB

SUB DrawBackTab(x%, y%)
  BOX x%, y%, CW%, CTH%, 1, DKBLUE%, DKBLUE%
  RectBorder x%, y%, CW%, CTH%, BLACK%
  BOX x%+4, y%+4, CW%-8, CTH%-8, 1, WHITE%, DKBLUE%
END SUB

SUB DrawFullCard(x%, y%, card%)
  LOCAL s%, v%, sc%
  s%  = card% \ 100
  v%  = card% MOD 100
  sc% = SuitColor%(s%)
  BOX x%, y%, FCW%, FCH%, 1, WHITE%, WHITE%
  RectBorder x%, y%, FCW%, FCH%, BLACK%
  TEXT x%+5, y%+7, ValStr$(v%), "LT", 1, 2, sc%, WHITE%
  DrawSuit s%, x%+FCW%\2, y%+FCH%\2+6, 4, sc%
END SUB

SUB DrawFullBack(x%, y%)
  BOX x%, y%, FCW%, FCH%, 1, DKBLUE%, DKBLUE%
  RectBorder x%, y%, FCW%, FCH%, BLACK%
  BOX x%+5, y%+5,  FCW%-10, FCH%-10, 1, WHITE%, DKBLUE%
  BOX x%+9, y%+9,  FCW%-18, FCH%-18, 1, WHITE%, DKBLUE%
END SUB

SUB DrawStatPanels
  LOCAL mx%, ox%, y%, mySc$, oppSc$
  mx% = STATW%\2 : ox% = ScrW% - STATW%\2
  y%  = OPP_Y% + CTH% + 23
  mySc$  = STR$(myScore%)
  oppSc$ = STR$(oppScore%)
  TEXT mx%, y%, "Score",          "CT", 1, 1, WHITE%, BG%
  TEXT ox%, y%, "Score",          "CT", 1, 1, CYAN%,  BG%
  y% = y% + 13
  TEXT mx%, y%, mySc$,            "CT", 1, 1, WHITE%, BG%
  TEXT ox%, y%, oppSc$,           "CT", 1, 1, CYAN%,  BG%
  y% = y% + 20
  TEXT mx%, y%, "Bid",            "CT", 1, 1, WHITE%, BG%
  TEXT ox%, y%, "Bid",            "CT", 1, 1, CYAN%,  BG%
  y% = y% + 13
  IF myBid%  >= 0 THEN TEXT mx%, y%, STR$(myBid%),  "CT", 1, 1, WHITE%, BG%
  IF oppBid% >= 0 THEN TEXT ox%, y%, STR$(oppBid%), "CT", 1, 1, CYAN%,  BG%
  y% = y% + 20
  TEXT mx%, y%, "Tricks",         "CT", 1, 1, WHITE%, BG%
  TEXT ox%, y%, "Tricks",         "CT", 1, 1, CYAN%,  BG%
  y% = y% + 13
  TEXT mx%, y%, STR$(myTricks%),  "CT", 1, 1, WHITE%, BG%
  TEXT ox%, y%, STR$(oppTricks%), "CT", 1, 1, CYAN%,  BG%
  y% = y% + 20
  TEXT mx%, y%, "Bags",           "CT", 1, 1, WHITE%, BG%
  TEXT ox%, y%, "Bags",           "CT", 1, 1, CYAN%,  BG%
  y% = y% + 13
  TEXT mx%, y%, STR$(myBags%),    "CT", 1, 1, WHITE%, BG%
  TEXT ox%, y%, STR$(oppBags%),   "CT", 1, 1, CYAN%,  BG%
END SUB

SUB ShowMsg(msg$)
  BOX PLAYX%, PLAYY%, PLAYW%, 14, 1, BG%, BG%
  TEXT ScrW%\2, PLAYY%+2, msg$, "CT", 1, 1, YELLOW%, BG%
  PAUSE 1200
  BOX PLAYX%, PLAYY%, PLAYW%, 14, 1, BG%, BG%
END SUB

SUB ShowGameOver
  LOCAL k$
  CLS BG%
  IF myScore% > oppScore% THEN
    TEXT ScrW%\2, ScrH%\2-20, "YOU WIN!",  "CT", 1, 3, YELLOW%, BG%
  ELSEIF oppScore% > myScore% THEN
    TEXT ScrW%\2, ScrH%\2-20, "You lose.", "CT", 1, 2, WHITE%,  BG%
  ELSE
    TEXT ScrW%\2, ScrH%\2-20, "Tie game!", "CT", 1, 2, WHITE%,  BG%
  END IF
  TEXT ScrW%\2, ScrH%\2+20, STR$(myScore%) + " - " + STR$(oppScore%), "CT", 1, 2, CYAN%,  BG%
  TEXT ScrW%\2, ScrH%\2+50, "Press any key",  "CT", 1, 1, WHITE%, BG%
  TEXT ScrW%\2, ScrH%\2+66, "N = Main menu",  "CT", 1, 1, GREY%,  BG%
  DO : LOOP UNTIL INKEY$ = ""   ' flush buffer
  DO
    k$ = INKEY$
    IF k$ = "N" OR k$ = "n" THEN WEB UDP CLOSE : CHAIN "B:menu.bas"
    IF k$ <> "" THEN EXIT DO
    PAUSE 10
  LOOP
END SUB

' ============================================================
'  SUIT PATTERNS
' ============================================================
SUB InitSuitPatterns
  SP%(1)=&H18 : SP%(2)=&H3C : SP%(3)=&H7E : SP%(4)=&HFF
  SP%(5)=&HFF : SP%(6)=&H66 : SP%(7)=&H18 : SP%(8)=&H3C
  HT%(1)=&H66 : HT%(2)=&HFF : HT%(3)=&HFF : HT%(4)=&H7E
  HT%(5)=&H3C : HT%(6)=&H18 : HT%(7)=&H00 : HT%(8)=&H00
  DM%(1)=&H10 : DM%(2)=&H38 : DM%(3)=&H7C : DM%(4)=&HFE
  DM%(5)=&H7C : DM%(6)=&H38 : DM%(7)=&H10 : DM%(8)=&H00
  CL%(1)=&H18 : CL%(2)=&H3C : CL%(3)=&H3C : CL%(4)=&HE7
  CL%(5)=&HE7 : CL%(6)=&H7E : CL%(7)=&H18 : CL%(8)=&H3C
END SUB

SUB DrawSuit(suit%, cx%, cy%, s%, col%)
  LOCAL r%, c%, pat%, x%, y%
  LOCAL x0% : x0% = cx% - 4*s%
  LOCAL y0% : y0% = cy% - 4*s%
  FOR r% = 1 TO 8
    SELECT CASE suit%
      CASE SPADE%   : pat% = SP%(r%)
      CASE HEART%   : pat% = HT%(r%)
      CASE DIAMOND% : pat% = DM%(r%)
      CASE CLUB%    : pat% = CL%(r%)
    END SELECT
    FOR c% = 0 TO 7
      IF (pat% >> (7-c%)) AND 1 THEN
        x% = x0% + c% * s%
        y% = y0% + (r%-1) * s%
        BOX x%, y%, s%, s%, 1, col%, col%
      END IF
    NEXT c%
  NEXT r%
END SUB

' ============================================================
'  LEDs
' ============================================================
SUB InitLEDs
  LED_Off
END SUB

SUB LED_Green
  LOCAL i%
  FOR i% = 1 TO LEDCOUNT : ledBuf%(i%) = &H002000 : NEXT i%
  BITBANG WS2812 O, GP28, LEDCOUNT, ledBuf%()
END SUB

SUB LED_Off
  LOCAL i%
  FOR i% = 1 TO LEDCOUNT : ledBuf%(i%) = 0 : NEXT i%
  BITBANG WS2812 O, GP28, LEDCOUNT, ledBuf%()
END SUB

' ============================================================
'  UTILITIES
' ============================================================
FUNCTION ValStr$(v%)
  SELECT CASE v%
    CASE 1    : ValStr$ = "A"
    CASE 11   : ValStr$ = "J"
    CASE 12   : ValStr$ = "Q"
    CASE 13   : ValStr$ = "K"
    CASE ELSE : ValStr$ = STR$(v%)
  END SELECT
END FUNCTION

FUNCTION SuitColor%(s%)
  IF s% = DIAMOND% OR s% = HEART% THEN
    SuitColor% = RED%
  ELSEIF s% = SPADE% AND spadesBroken% = 0 THEN
    SuitColor% = GREY%
  ELSE
    SuitColor% = BLACK%
  END IF
END FUNCTION