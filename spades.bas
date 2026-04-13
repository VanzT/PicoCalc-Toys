' ============================================================
' SPADES for PicoCalc
' MMBasic / WebMite  ·  2-player networked
'
' Architecture:
'   Phase 0 — Pairing       (NetPair)
'   Phase 1 — Variant pick  (PickVariant)
'   Phase 2 — Setup         (DoSetup)
'   Phase 3 — Bidding       (DoBidding)
'   Phase 4 — Play          (DoPlay)
'   Phase 5 — Scoring       (DoScoring)
'   Phases 2-5 repeat until someone reaches 500 pts
'
' Networking (UDP port 6000, same pattern as Othello):
'   HELLO n        — broadcast during pairing (n = random ticket)
'   ASSIGN r       — higher-ticket device assigns roles
'                    r=1 ? receiver is Second Player this hand
'                    r=2 ? receiver is First Player this hand
'   VARIANT v      — 0=face-down discards  1=face-up discards
'   SETUP c        — setup turn done; c=discarded card (0 if face-down)
'   BID n          — bid value (0=nil)
'   PLAY c         — card played (encoded as suit*100+value)
'   SYNC           — request full state resend (R key)
'
' Card encoding:  suit×100 + face_value
'   Suit:  1=Club  2=Diamond  3=Heart  4=Spade
'   Value: 1=Ace   2-10       11=J  12=Q  13=K
'
' Role encoding:
'   myRole% = 1  ?  First Player  (draws first in setup)
'   myRole% = 2  ?  Second Player (bids first, leads first trick)
'   The asterisk in the stat panel marks the Second Player.
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
CONST DKGRN%  = RGB(0,110,0)

' -- Suit codes ----------------------------------------------
CONST CLUB%    = 1
CONST DIAMOND% = 2
CONST HEART%   = 3
CONST SPADE%   = 4

' -- Key codes -----------------------------------------------
CONST KEY_LEFT%  = 130
CONST KEY_RIGHT% = 131
CONST KEY_ENTER% = 13
CONST KEY_R%     = 82    ' capital R — resend
CONST KEY_Q%     = 81    ' capital Q — quit

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

' -- Suit bitmaps (1-based rows 1-8) -------------------------
DIM SP%(8)
DIM HT%(8)
DIM DM%(8)
DIM CL%(8)

' -- Deck & hands --------------------------------------------
DIM deck%(52)       ' full shuffled deck
DIM myHand%(13)     ' my 13 cards
DIM oppHand%(13)    ' opponent card count (we only track count + backs)
DIM myHSz%          ' cards remaining in my hand
DIM oppHSz%         ' cards remaining in opp hand

' -- Game state ----------------------------------------------
DIM myRole%         ' 1=First Player  2=Second Player
DIM myScore%        ' cumulative score
DIM oppScore%       ' cumulative score
DIM myBid%          ' bid this hand (0=nil)
DIM oppBid%         ' opponent bid
DIM myTricks%       ' tricks won this hand
DIM oppTricks%      ' tricks won this hand
DIM myBags%         ' cumulative bags
DIM oppBags%        ' cumulative bags
DIM spadesBroken%   ' 0=not broken  1=broken
DIM myTurn%         ' 1 = it is my turn to act
DIM faceUpDiscard%  ' 0=face-down variant  1=face-up variant
DIM gamePhase%      ' 0=pair 1=variant 2=setup 3=bid 4=play 5=score
DIM handNum%        ' which hand we are on (1-based)
DIM trickNum%       ' current trick number (1-13)
DIM leadCard%       ' card led this trick (0 if none yet)
DIM myPlayedCard%   ' card I played this trick
DIM oppPlayedCard%  ' card opp played this trick
DIM sel%            ' cursor index in my hand (1-based)

' -- Networking ----------------------------------------------
DIM peer$           ' opponent IP address
DIM myTicket%       ' random pairing ticket
DIM assigned%       ' 1 once roles are assigned
DIM lastMsg$        ' last sent message (for R-key resend)
DIM lastHello!      ' timer for HELLO broadcasts

' -- Trick play area -----------------------------------------
DIM trickMyCard%    ' card showing in my side of play area (0=none)
DIM trickOppCard%   ' card showing in opp side of play area (0=none)

' ============================================================
'  MAIN
' ============================================================
InitSuitPatterns
InitLEDs

NetPair          ' Phase 0 — blocks until paired
PickVariant      ' Phase 1 — first player chooses face-up/down
BuildDeck

DO
  handNum% = handNum% + 1
  DoSetup          ' Phase 2
  DoBidding        ' Phase 3
  DoPlay           ' Phase 4
  DoScoring        ' Phase 5
  IF myScore% >= 500 OR oppScore% >= 500 THEN EXIT DO
  ' Role does NOT flip — it is re-randomised each hand in real Spades.
  ' For simplicity we keep the same roles; adjust here if desired.
LOOP

ShowGameOver
WEB UDP CLOSE
END

' ============================================================
'  PHASE 0 — NET PAIR
'  Identical handshake pattern to Othello.
'  Higher ticket randomly assigns roles and sends ASSIGN.
'  Lower ticket waits for ASSIGN.
'  Both light LEDs green once paired.
' ============================================================
SUB NetPair
  LOCAL t$, src$, peerTicket%, assignedRole%
  LOCAL comma%

  WEB UDP OPEN PORT%
  myTicket% = INT(RND * 1000000) + 1
  assigned% = 0
  peer$     = ""
  lastHello!= -99

  CLS BG%
  TEXT ScrW%\2, ScrH%\2 - 10, "Waiting for opponent...", "CT", 1, 1, WHITE%, BG%
  TEXT ScrW%\2, ScrH%\2 + 8,  "Searching...",            "CT", 1, 1, GREY%,  BG%

  DO
    ' Broadcast HELLO every 500 ms
    IF TIMER - lastHello! > 500 THEN
      WEB UDP SEND "255.255.255.255", PORT%, "HELLO " + STR$(myTicket%)
      lastHello! = TIMER
    END IF

    ' Handle any incoming message
    IF MM.MESSAGE$ <> "" THEN
      t$   = MM.MESSAGE$
      src$ = MM.ADDRESS$

      IF LEFT$(t$,5) = "HELLO" AND assigned% = 0 THEN
        peerTicket% = VAL(MID$(t$,7))
        IF peerTicket% = myTicket% THEN
          ' Collision — pick a new ticket
          myTicket% = INT(RND * 1000000) + 1
        ELSE
          peer$ = src$
          IF myTicket% > peerTicket% THEN
            ' I am the assigner — randomly give Second Player role
            IF RND > 0.5 THEN assignedRole% = 2 ELSE assignedRole% = 1
            myRole%   = 3 - assignedRole%   ' I get the other role
            assigned% = 1
            lastMsg$  = "ASSIGN " + STR$(assignedRole%)
            WEB UDP SEND peer$, PORT%, lastMsg$
          ELSE
            ' Nudge peer so they see me
            WEB UDP SEND peer$, PORT%, "HELLO " + STR$(myTicket%)
          END IF
        END IF

      ELSEIF LEFT$(t$,6) = "ASSIGN" AND assigned% = 0 THEN
        myRole%   = VAL(MID$(t$,8))
        peer$     = src$
        assigned% = 1
      END IF
    END IF

    ' Q to quit
    IF INKEY$ = CHR$(KEY_Q%) THEN WEB UDP CLOSE : END

    PAUSE 10
  LOOP UNTIL assigned% = 1

  LED_Green
  CLS BG%
  TEXT ScrW%\2, ScrH%\2 - 10, "Opponent found!", "CT", 1, 1, WHITE%, BG%
  IF myRole% = 2 THEN
    TEXT ScrW%\2, ScrH%\2 + 8, "You lead first", "CT", 1, 1, CYAN%, BG%
  ELSE
    TEXT ScrW%\2, ScrH%\2 + 8, "Opponent leads first", "CT", 1, 1, CYAN%, BG%
  END IF
  PAUSE 2000
END SUB

' ============================================================
'  PHASE 1 — PICK VARIANT
'  First Player (role 1) chooses face-up or face-down discards.
'  Choice is sent to opponent via VARIANT message.
' ============================================================
SUB PickVariant
  LOCAL k$, chosen%
  CLS BG%

  IF myRole% = 1 THEN
    ' I choose
    TEXT ScrW%\2, 40,  "Discard variant:", "CT", 1, 1, WHITE%, BG%
    TEXT ScrW%\2, 70,  "ENTER = Face Down", "CT", 1, 1, WHITE%,  BG%
    TEXT ScrW%\2, 90,  "(discards hidden)", "CT", 1, 1, GREY%,   BG%
    TEXT ScrW%\2, 120, "SPACE = Face Up",   "CT", 1, 1, YELLOW%, BG%
    TEXT ScrW%\2, 140, "(discards visible)", "CT", 1, 1, GREY%,  BG%

    chosen% = 0
    DO
      k$ = INKEY$
      IF k$ = CHR$(13)  THEN faceUpDiscard% = 0 : chosen% = 1
      IF k$ = CHR$(32)  THEN faceUpDiscard% = 1 : chosen% = 1
      IF k$ = CHR$(KEY_Q%) THEN WEB UDP CLOSE : END
      PAUSE 10
    LOOP UNTIL chosen% = 1

    lastMsg$ = "VARIANT " + STR$(faceUpDiscard%)
    WEB UDP SEND peer$, PORT%, lastMsg$

  ELSE
    ' I wait
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
'  PHASE 2 — SETUP  (stub)
'  Alternating draw/discard until each player has 13 cards.
'  First Player draws first.
' ============================================================
SUB DoSetup
  ' TODO: implement draw pile, discard pile, alternating turns
  ' For now: deal 13 cards directly to each player
  LOCAL i%, card%, suit%, val%

  ShuffleDeck
  myHSz%  = 13
  oppHSz% = 13
  FOR i% = 1 TO 13
    myHand%(i%) = deck%(i%)
  NEXT i%
  ' Opponent's 13 cards are deck%(14..26) — we only know count, not values
  SortHand myHand%(), myHSz%

  spadesBroken% = 0
  sel%          = 1
  myPlayedCard% = 0
  oppPlayedCard%= 0
  trickMyCard%  = 0
  trickOppCard% = 0
END SUB

' ============================================================
'  PHASE 3 — BIDDING  (stub)
'  Second Player (role 2) bids first.
' ============================================================
SUB DoBidding
  ' TODO: implement bidding UI with nil confirmation
  ' For now: hard-code bids
  myBid%  = 3
  oppBid% = 3
  myTricks%  = 0
  oppTricks% = 0

  CLS BG%
  DrawAll
END SUB

' ============================================================
'  PHASE 4 — PLAY  (stub)
'  13 tricks. Second Player leads first trick.
' ============================================================
SUB DoPlay
  LOCAL k$, msg$, cardSuit%

  trickNum% = 0
  myTurn%   = (myRole% = 2)   ' Second Player leads first

  DO
    k$ = INKEY$

    ' Quit
    IF k$ = CHR$(KEY_Q%) THEN WEB UDP CLOSE : END

    ' Resend
    IF k$ = CHR$(KEY_R%) THEN
      IF lastMsg$ <> "" AND peer$ <> "" THEN
        WEB UDP SEND peer$, PORT%, lastMsg$
        ShowMsg "Resent"
      END IF
    END IF

    ' My turn — handle input
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

    ' Receive opponent move
    IF MM.MESSAGE$ <> "" THEN
      msg$ = MM.MESSAGE$
      IF LEFT$(msg$,4) = "PLAY" THEN
        oppPlayedCard% = VAL(MID$(msg$,6))
        trickOppCard%  = oppPlayedCard%
        DrawTrickArea
        ' If I have not played yet, it is now my turn
        IF myPlayedCard% = 0 THEN
          myTurn% = 1
          LED_Green
        ELSE
          ' Both played — resolve trick
          ResolveTrick
        END IF
      END IF
    END IF

    PAUSE 10
  LOOP UNTIL myTricks% + oppTricks% = 13
END SUB

' ============================================================
'  PHASE 5 — SCORING  (stub)
' ============================================================
SUB DoScoring
  ' TODO: implement full scoring with bags, nil penalties, sandbag rule
  LOCAL myRoundScore%, oppRoundScore%

  IF myTricks% >= myBid% THEN
    myRoundScore%  = myBid% * 10 + (myTricks% - myBid%)
    myBags%  = myBags%  + (myTricks% - myBid%)
  ELSE
    myRoundScore%  = -(myBid% * 10)
  END IF

  IF oppTricks% >= oppBid% THEN
    oppRoundScore% = oppBid% * 10 + (oppTricks% - oppBid%)
    oppBags% = oppBags% + (oppTricks% - oppBid%)
  ELSE
    oppRoundScore% = -(oppBid% * 10)
  END IF

  ' Sandbagging penalty
  IF myBags%  >= 10 THEN myScore%  = myScore%  - 100 : myBags%  = myBags%  - 10
  IF oppBags% >= 10 THEN oppScore% = oppScore% - 100 : oppBags% = oppBags% - 10

  myScore%  = myScore%  + myRoundScore%
  oppScore% = oppScore% + oppRoundScore%

  ' Show summary
  CLS BG%
  TEXT ScrW%\2, 40,  "Hand " + STR$(handNum%) + " complete", "CT", 1, 2, WHITE%, BG%
  TEXT ScrW%\2, 80,  "You:  bid " + STR$(myBid%)  + "  took " + STR$(myTricks%),  "CT", 1, 1, WHITE%, BG%
  TEXT ScrW%\2, 100, "Opp:  bid " + STR$(oppBid%) + "  took " + STR$(oppTricks%), "CT", 1, 1, CYAN%,  BG%
  TEXT ScrW%\2, 130, "Score  You: " + STR$(myScore%)  + "  Opp: " + STR$(oppScore%), "CT", 1, 1, WHITE%, BG%
  TEXT ScrW%\2, 160, "Press any key to continue", "CT", 1, 1, GREY%, BG%

  DO : LOOP UNTIL INKEY$ <> ""
END SUB

' ============================================================
'  PLAY HELPERS
' ============================================================

' Check if a card is legal to play this trick
FUNCTION CanPlayCard%(card%)
  LOCAL suit% : suit% = card% \ 100

  ' If leading (no card played yet this trick):
  IF leadCard% = 0 THEN
    IF suit% = SPADE% AND spadesBroken% = 0 THEN
      ' Can only lead spade if hand has nothing else
      CanPlayCard% = NOT HandHasNonSpade%()
    ELSE
      CanPlayCard% = 1
    END IF
    EXIT FUNCTION
  END IF

  ' Following suit — must follow if possible
  LOCAL leadSuit% : leadSuit% = leadCard% \ 100
  IF suit% = leadSuit% THEN
    CanPlayCard% = 1
  ELSE
    ' Only legal if I have no cards of lead suit
    CanPlayCard% = NOT HandHasSuit%(leadSuit%)
  END IF
END FUNCTION

SUB PlayMyCard(idx%)
  LOCAL card% : card% = myHand%(idx%)
  LOCAL suit% : suit% = card% \ 100

  ' Break spades if needed
  IF suit% = SPADE% AND spadesBroken% = 0 THEN
    spadesBroken% = 1
    DrawMyHand   ' redraw with black spades
  END IF

  ' Set lead card if I am leading
  IF leadCard% = 0 THEN leadCard% = card%

  myPlayedCard% = card%
  trickMyCard%  = card%
  DrawTrickArea

  ' Send to opponent
  lastMsg$ = "PLAY " + STR$(card%)
  WEB UDP SEND peer$, PORT%, lastMsg$

  ' Remove from hand
  RemoveCard idx%
  myTurn% = 0
  LED_Off

  ' If opponent already played, resolve now
  IF oppPlayedCard% <> 0 THEN ResolveTrick
END SUB

SUB ResolveTrick
  LOCAL winner%   ' 1=me  2=opponent
  winner% = TrickWinner%(myPlayedCard%, oppPlayedCard%, leadCard% \ 100)

  IF winner% = 1 THEN
    myTricks%  = myTricks%  + 1
    myTurn%    = 1
    LED_Green
  ELSE
    oppTricks% = oppTricks% + 1
    myTurn%    = 0
    LED_Off
  END IF

  trickNum%    = trickNum% + 1
  leadCard%    = 0
  myPlayedCard%= 0
  oppPlayedCard%= 0

  DrawStatPanels

  ' Brief pause so both players see the trick result
  PAUSE 1500
  trickMyCard%  = 0
  trickOppCard% = 0
  DrawTrickArea
END SUB

' Returns 1 if myCard wins, 2 if oppCard wins
FUNCTION TrickWinner%(myCard%, oppCard%, leadSuit%)
  LOCAL mySuit%  : mySuit%  = myCard%  \ 100
  LOCAL oppSuit% : oppSuit% = oppCard% \ 100
  LOCAL myVal%   : myVal%   = myCard%  MOD 100
  LOCAL oppVal%  : oppVal%  = oppCard% MOD 100

  ' Spades beat non-spades
  IF mySuit% = SPADE% AND oppSuit% <> SPADE% THEN TrickWinner% = 1 : EXIT FUNCTION
  IF oppSuit% = SPADE% AND mySuit% <> SPADE% THEN TrickWinner% = 2 : EXIT FUNCTION

  ' Both same suit — higher value wins (Ace high)
  IF mySuit% = oppSuit% THEN
    LOCAL myEff%  : myEff%  = myVal%  : IF myVal%  = 1 THEN myEff%  = 14
    LOCAL oppEff% : oppEff% = oppVal% : IF oppVal% = 1 THEN oppEff% = 14
    IF myEff% > oppEff% THEN TrickWinner% = 1 ELSE TrickWinner% = 2
    EXIT FUNCTION
  END IF

  ' Different non-spade suits — lead suit wins; off-suit loses
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
  BuildDeck
  FOR i% = 52 TO 2 STEP -1
    j% = INT(RND * i%) + 1
    tmp%      = deck%(i%)
    deck%(i%) = deck%(j%)
    deck%(j%) = tmp%
  NEXT i%
END SUB

' Sort hand: by suit ascending, then value ascending within suit
SUB SortHand(h%(), sz%)
  LOCAL i%, j%, tmp%
  FOR i% = 1 TO sz% - 1
    FOR j% = 1 TO sz% - i%
      IF h%(j%) > h%(j%+1) THEN
        tmp%      = h%(j%)
        h%(j%)    = h%(j%+1)
        h%(j%+1)  = tmp%
      END IF
    NEXT j%
  NEXT i%
END SUB

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

SUB DrawTrickArea
  LOCAL cy%, lx%, rx%
  cy% = PLAYY% + (PLAYH% - FCH%) \ 2
  lx% = PLAYX% + PLAYW%\2 - FCW% - 8
  rx% = PLAYX% + PLAYW%\2 + 8
  ' Clear play area
  BOX PLAYX%, PLAYY%, PLAYW%, PLAYH%, 1, BG%, BG%
  IF trickOppCard% > 0 THEN DrawFullCard lx%, cy%, trickOppCard%
  IF trickMyCard%  > 0 THEN DrawFullCard rx%, cy%, trickMyCard%
END SUB

' -- Border helper --------------------------------------------
SUB RectBorder(x%, y%, w%, h%, col%)
  LINE x%,     y%,     x%+w%, y%,     1, col%
  LINE x%,     y%+1,   x%+w%, y%+1,   1, col%
  LINE x%,     y%+h%,  x%+w%, y%+h%,  1, col%
  LINE x%,     y%+h%-1,x%+w%, y%+h%-1,1, col%
  LINE x%,     y%,     x%,    y%+h%,  1, col%
  LINE x%+1,   y%,     x%+1,  y%+h%,  1, col%
  LINE x%+w%,  y%,     x%+w%, y%+h%,  1, col%
  LINE x%+w%-1,y%,     x%+w%-1,y%+h%, 1, col%
END SUB

' -- Card drawing ---------------------------------------------
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
  BOX x%+5,  y%+5,  FCW%-10, FCH%-10, 1, WHITE%, DKBLUE%
  BOX x%+9,  y%+9,  FCW%-18, FCH%-18, 1, WHITE%, DKBLUE%
END SUB

' -- Stat panels ----------------------------------------------
SUB DrawStatPanels
  LOCAL mx%, ox%, y%, myScoreStr$, oppScoreStr$
  mx% = STATW%\2 : ox% = ScrW% - STATW%\2
  y%  = OPP_Y% + CTH% + 23

  ' Score (* marks the Second Player — leads first)
  IF myRole% = 2 THEN myScoreStr$ = "*" + STR$(myScore%) ELSE myScoreStr$ = STR$(myScore%)
  IF myRole% = 1 THEN oppScoreStr$ = "*" + STR$(oppScore%) ELSE oppScoreStr$ = STR$(oppScore%)

  TEXT mx%, y%, "Score",      "CT", 1, 1, WHITE%, BG%
  TEXT ox%, y%, "Score",      "CT", 1, 1, CYAN%,  BG%
  y% = y% + 13
  TEXT mx%, y%, myScoreStr$,  "CT", 1, 1, WHITE%, BG%
  TEXT ox%, y%, oppScoreStr$, "CT", 1, 1, CYAN%,  BG%
  y% = y% + 20

  TEXT mx%, y%, "Bid",        "CT", 1, 1, WHITE%, BG%
  TEXT ox%, y%, "Bid",        "CT", 1, 1, CYAN%,  BG%
  y% = y% + 13
  TEXT mx%, y%, STR$(myBid%),  "CT", 1, 1, WHITE%, BG%
  TEXT ox%, y%, STR$(oppBid%), "CT", 1, 1, CYAN%,  BG%
  y% = y% + 20

  TEXT mx%, y%, "Tricks",     "CT", 1, 1, WHITE%, BG%
  TEXT ox%, y%, "Tricks",     "CT", 1, 1, CYAN%,  BG%
  y% = y% + 13
  TEXT mx%, y%, STR$(myTricks%),  "CT", 1, 1, WHITE%, BG%
  TEXT ox%, y%, STR$(oppTricks%), "CT", 1, 1, CYAN%,  BG%
  y% = y% + 20

  TEXT mx%, y%, "Bags",       "CT", 1, 1, WHITE%, BG%
  TEXT ox%, y%, "Bags",       "CT", 1, 1, CYAN%,  BG%
  y% = y% + 13
  TEXT mx%, y%, STR$(myBags%),  "CT", 1, 1, WHITE%, BG%
  TEXT ox%, y%, STR$(oppBags%), "CT", 1, 1, CYAN%,  BG%
END SUB

' -- Message flash --------------------------------------------
SUB ShowMsg(msg$)
  BOX PLAYX%, PLAYY%, PLAYW%, 14, 1, BG%, BG%
  TEXT ScrW%\2, PLAYY%+2, msg$, "CT", 1, 1, YELLOW%, BG%
  PAUSE 1200
  BOX PLAYX%, PLAYY%, PLAYW%, 14, 1, BG%, BG%
END SUB

' -- Game over ------------------------------------------------
SUB ShowGameOver
  CLS BG%
  IF myScore% > oppScore% THEN
    TEXT ScrW%\2, ScrH%\2 - 20, "YOU WIN!", "CT", 1, 3, YELLOW%, BG%
  ELSEIF oppScore% > myScore% THEN
    TEXT ScrW%\2, ScrH%\2 - 20, "You lose.", "CT", 1, 2, WHITE%, BG%
  ELSE
    TEXT ScrW%\2, ScrH%\2 - 20, "Tie game!", "CT", 1, 2, WHITE%, BG%
  END IF
  TEXT ScrW%\2, ScrH%\2 + 20, STR$(myScore%) + " - " + STR$(oppScore%), "CT", 1, 2, CYAN%, BG%
  TEXT ScrW%\2, ScrH%\2 + 50, "Press any key", "CT", 1, 1, GREY%, BG%
  DO : LOOP UNTIL INKEY$ <> ""
END SUB

' ============================================================
'  SUIT BITMAP PATTERNS
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

' ============================================================
'  DRAW SUIT BITMAP  centred at (cx%, cy%), scale s%
' ============================================================
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