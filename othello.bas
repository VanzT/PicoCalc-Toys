' Othello Wi-Fi Multiplayer (PicoCalc)
' Author: Vance Thompson
' Version: 1.4
' Date: 2025-09-13

OPTION BASE 1
OPTION EXPLICIT
RANDOMIZE TIMER

' === Constants ===
CONST BOARD_SIZE% = 8
CONST SQUARE_SIZE% = 320 \ BOARD_SIZE%
CONST BOARD_COLOR% = RGB(0,160,0)
CONST LINE_COLOR% = RGB(0,0,0)
CONST BLACK_PIECE_COLOR% = RGB(0,0,0)
CONST WHITE_PIECE_COLOR% = RGB(255,255,255)
CONST SELECTOR_COLOR% = RGB(255, 0, 0)
CONST ERASE_COLOR% = BOARD_COLOR%
CONST SELECTOR_EXTRA_RADIUS% = 2
CONST PORT% = 6000

' === Globals ===
DIM board%(BOARD_SIZE%, BOARD_SIZE%)
DIM k$
DIM sel_col% = 1, sel_row% = 1
DIM turn% = 1         ' 1 = Black, 2 = White
DIM myColor% = 0      ' 1 = Black, 2 = White (assigned after handshake)
DIM peer$ = ""
DIM pieceCol!
DIM x%, y%, legalMove%

' === SUB: Count pieces on board ===
SUB count_score(BYREF b%, BYREF w%)
  LOCAL x%, y%
  b% = 0 : w% = 0
  FOR x% = 1 TO BOARD_SIZE%
    FOR y% = 1 TO BOARD_SIZE%
      SELECT CASE board%(x%, y%)
        CASE 1: b% = b% + 1
        CASE 2: w% = w% + 1
      END SELECT
    NEXT y%
  NEXT x%
END SUB

' === SUB: Display the score ===
SUB draw_score_display
  LOCAL b%, w%
  count_score b%, w%
  COLOR RGB(255,255,255), BOARD_COLOR%
  PRINT @(10, 4) "Black: " + STR$(b%) + "  White: " + STR$(w%)
END SUB


' === SUB: Draw the green board and grid ===
SUB draw_board
  LOCAL i%
  CLS BOARD_COLOR%
  FOR i% = 0 TO BOARD_SIZE%
    LINE i%*SQUARE_SIZE%, 0, i%*SQUARE_SIZE%, BOARD_SIZE%*SQUARE_SIZE%, 1, LINE_COLOR%
    LINE 0, i%*SQUARE_SIZE%, BOARD_SIZE%*SQUARE_SIZE%, i%*SQUARE_SIZE%, 1, LINE_COLOR%
  NEXT i%
END SUB

' === FUNCTION: Check if a move is legal ===
FUNCTION is_legal_move(col%, row%, player%) AS INTEGER
  LOCAL dx%, dy%, x%, y%, opponent%, found%
  IF board%(col%, row%) <> 0 THEN
    is_legal_move = 0
    EXIT FUNCTION
  END IF
  opponent% = 3 - player%
  FOR dx% = -1 TO 1
    FOR dy% = -1 TO 1
      IF dx% = 0 AND dy% = 0 THEN CONTINUE FOR
      x% = col% + dx%
      y% = row% + dy%
      found% = 0
      DO
        IF x% < 1 OR x% > BOARD_SIZE% OR y% < 1 OR y% > BOARD_SIZE% THEN EXIT DO
        IF board%(x%, y%) = opponent% THEN
          found% = 1
        ELSEIF board%(x%, y%) = player% THEN
          IF found% THEN
            is_legal_move = 1
            EXIT FUNCTION
          ELSE
            EXIT DO
          END IF
        ELSE
          EXIT DO
        END IF
        x% = x% + dx% : y% = y% + dy%
      LOOP
    NEXT dy%
  NEXT dx%
  is_legal_move = 0
END FUNCTION

FUNCTION has_legal_moves(player%) AS INTEGER
  LOCAL x%, y%
  FOR x% = 1 TO BOARD_SIZE%
    FOR y% = 1 TO BOARD_SIZE%
      IF board%(x%, y%) = 0 AND is_legal_move(x%, y%, player%) THEN
        has_legal_moves = 1
        EXIT FUNCTION
      END IF
    NEXT y%
  NEXT x%
  has_legal_moves = 0
END FUNCTION


' === SUB: Check game over and show winner ===
SUB check_game_over
  LOCAL legal1%, legal2%, x%, y%, b%, w%
  legal1% = 0 : legal2% = 0
  FOR x% = 1 TO BOARD_SIZE%
    FOR y% = 1 TO BOARD_SIZE%
      IF board%(x%, y%) = 0 THEN
        IF is_legal_move(x%, y%, 1) THEN legal1% = 1
        IF is_legal_move(x%, y%, 2) THEN legal2% = 1
      END IF
    NEXT y%
  NEXT x%

  IF legal1% = 0 AND legal2% = 0 THEN
    count_score b%, w%
    COLOR RGB(255,255,255)
    PRINT @(20, 140) "Game Over"
    PRINT @(20, 170) "Black: "; b%; "   White: "; w%
    IF b% > w% THEN
      PRINT @(20, 200) "Black wins!"
    ELSEIF w% > b% THEN
      PRINT @(20, 200) "White wins!"
    ELSE
      PRINT @(20, 200) "It's a tie!"
    END IF
    PRINT @(20, 240) "Press any key to return to menu..."
    DO WHILE INKEY$ = "": PAUSE 50: LOOP
    CHAIN "b:menu.bas"
  END IF
END SUB

' === SUB: Draw one piece (filled circle) ===
SUB draw_piece(col%, row%, pieceCol!)
  LOCAL x%, y%, r%
  x% = (col% - 1) * SQUARE_SIZE% + SQUARE_SIZE% \ 2
  y% = (row% - 1) * SQUARE_SIZE% + SQUARE_SIZE% \ 2
  r% = (SQUARE_SIZE% - 5) \ 2
  CIRCLE x%, y%, r%, 1, 1.0, pieceCol!, pieceCol!
END SUB

' === SUB: Draw red selector circle ===
SUB draw_selector(col%, row%, sel_color%)
  LOCAL x%, y%, r%
  x% = (col% - 1) * SQUARE_SIZE% + SQUARE_SIZE% \ 2
  y% = (row% - 1) * SQUARE_SIZE% + SQUARE_SIZE% \ 2
  r% = ((SQUARE_SIZE% - 5) \ 2) + SELECTOR_EXTRA_RADIUS%
  CIRCLE x%, y%, r%, 1, 1.0, sel_color%, -1
END SUB

' === SUB: Flip opponent's pieces ===
SUB flip_pieces(col%, row%, player%)
  LOCAL dx%, dy%, x%, y%, i%, count%, path%(64, 2), opponent%, done%
  opponent% = 3 - player%
  FOR dx% = -1 TO 1
    FOR dy% = -1 TO 1
      IF dx% = 0 AND dy% = 0 THEN CONTINUE FOR
      x% = col% + dx%
      y% = row% + dy%
      count% = 0
      done% = 0
      DO
        IF x% < 1 OR x% > BOARD_SIZE% OR y% < 1 OR y% > BOARD_SIZE% THEN
          done% = 1
        ELSEIF board%(x%, y%) = opponent% THEN
          count% = count% + 1
          path%(count%, 1) = x%
          path%(count%, 2) = y%
          x% = x% + dx% : y% = y% + dy%
        ELSEIF board%(x%, y%) = player% AND count% > 0 THEN
          IF turn% = 1 THEN
            pieceCol! = BLACK_PIECE_COLOR%
          ELSE
            pieceCol! = WHITE_PIECE_COLOR%
          END IF
          draw_piece col%, row%, pieceCol!
          FOR i% = 1 TO count%
            board%(path%(i%, 1), path%(i%, 2)) = player%
            draw_piece path%(i%, 1), path%(i%, 2), pieceCol!
          NEXT i%
          done% = 1
        ELSE
          done% = 1
        END IF
      LOOP UNTIL done%
    NEXT dy%
  NEXT dx%
END SUB

' === SUB: Handle received message ===
SUB OnUDP
  LOCAL t$, x%, y%
  t$ = MM.MESSAGE$
  peer$ = MM.ADDRESS$
  IF t$ = "HELLO" AND myColor% = 0 THEN
    myColor% = 2
    WEB UDP SEND peer$, PORT%, "ACK"
  ELSEIF t$ = "ACK" AND myColor% = 0 THEN
    myColor% = 1
  ELSEIF LEFT$(t$, 4) = "MOVE" THEN
    x% = VAL(MID$(t$, 6, 1))
    y% = VAL(MID$(t$, 8, 1))
    IF is_legal_move(x%, y%, turn%) THEN
      board%(x%, y%) = turn%
      IF turn% = 1 THEN pieceCol! = BLACK_PIECE_COLOR% ELSE pieceCol! = WHITE_PIECE_COLOR%
      draw_piece x%, y%, pieceCol!
      flip_pieces x%, y%, turn%
      draw_score_display
      turn% = 3 - turn%
      check_game_over
    ELSEIF t$ = "PASS" THEN
      turn% = 3 - turn%
      check_game_over
    END IF
  END IF
END SUB

' === INIT: Open UDP and handshake ===
WEB UDP OPEN SERVER PORT PORT%
WEB UDP INTERRUPT OnUDP
PAUSE 500
WEB UDP SEND "255.255.255.255", PORT%, "HELLO"

' === Pre-Game HUD ===
CLS RGB(0,0,0)
COLOR RGB(255,255,255)
PRINT @(10, 20) "Othello Wi-Fi Setup"
PRINT @(10, 50) "My Color: ";
PRINT @(10, 80) "Peer Address: ";
PRINT @(10, 110) "Press any key to start when both sides show a peer address."
DO WHILE INKEY$ = ""
  COLOR RGB(255,255,255)
  PRINT @(150, 50);
  IF myColor% = 0 THEN
    PRINT "Unassigned"
  ELSEIF myColor% = 1 THEN
    PRINT "Black          "
  ELSE
    PRINT "White          "
  END IF
  PRINT @(150, 80);
  IF peer$ = "" THEN
    PRINT "Waiting..."
  ELSE
    PRINT peer$
  END IF
  PAUSE 250
LOOP

' === Setup board ===
CLS
draw_board
draw_score_display
board%(4,4) = 2 : board%(5,5) = 2 : board%(4,5) = 1 : board%(5,4) = 1
draw_piece 4, 4, WHITE_PIECE_COLOR%
draw_piece 5, 5, WHITE_PIECE_COLOR%
draw_piece 4, 5, BLACK_PIECE_COLOR%
draw_piece 5, 4, BLACK_PIECE_COLOR%
draw_selector sel_col%, sel_row%, SELECTOR_COLOR%

' === Main Loop ===
DO
  k$ = INKEY$
  IF k$ = "" THEN PAUSE 20: CONTINUE DO
  draw_selector sel_col%, sel_row%, ERASE_COLOR%
  SELECT CASE ASC(k$)
    CASE 128: IF sel_row% > 1 THEN sel_row% = sel_row% - 1
    CASE 129: IF sel_row% < BOARD_SIZE% THEN sel_row% = sel_row% + 1
    CASE 130: IF sel_col% > 1 THEN sel_col% = sel_col% - 1
    CASE 131: IF sel_col% < BOARD_SIZE% THEN sel_col% = sel_col% + 1
    CASE 13
      IF myColor% = turn% AND is_legal_move(sel_col%, sel_row%, turn%) THEN
        board%(sel_col%, sel_row%) = turn%
        IF turn% = 1 THEN pieceCol! = BLACK_PIECE_COLOR% ELSE pieceCol! = WHITE_PIECE_COLOR%
        draw_piece sel_col%, sel_row%, pieceCol!
        flip_pieces sel_col%, sel_row%, turn%
        draw_score_display
        turn% = 3 - turn%
        check_game_over
        IF peer$ <> "" THEN
          WEB UDP SEND peer$, PORT%, "MOVE " + STR$(sel_col%) + "," + STR$(sel_row%)
        END IF
      END IF
    CASE 112  ' F1 key – try to pass
      legalMove% = 0
      FOR x% = 1 TO BOARD_SIZE%
        FOR y% = 1 TO BOARD_SIZE%
          IF is_legal_move(x%, y%, turn%) THEN
            legalMove% = 1
            EXIT FOR
          END IF
        NEXT y%
        IF legalMove% THEN EXIT FOR
      NEXT x%
      IF legalMove% = 0 THEN
        turn% = 3 - turn%
      ELSE
        COLOR RGB(255,255,0), BOARD_COLOR%
        PRINT @(20, 300) "Cannot pass: legal moves available";
        PAUSE 1000

        ' Clear message by redrawing everything
        draw_board
        FOR x% = 1 TO BOARD_SIZE%
          FOR y% = 1 TO BOARD_SIZE%
            SELECT CASE board%(x%, y%)
              CASE 1: draw_piece x%, y%, BLACK_PIECE_COLOR%
              CASE 2: draw_piece x%, y%, WHITE_PIECE_COLOR%
            END SELECT
          NEXT y%
        NEXT x%
        draw_score_display
      END IF

  END SELECT
  draw_selector sel_col%, sel_row%, SELECTOR_COLOR%
LOOP
