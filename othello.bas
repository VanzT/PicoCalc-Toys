' Othello board display
' Date: 2025-07-10
' Version: 1.1

OPTION BASE 1
OPTION EXPLICIT
RANDOMIZE TIMER

'––– Constants –––
CONST BOARD_SIZE%         = 8
CONST SQUARE_SIZE%        = 320 \ BOARD_SIZE%   ' = 40
CONST BOARD_COLOR%        = RGB(0,160,0)
CONST LINE_COLOR%         = RGB(0,0,0)
CONST BLACK_PIECE_COLOR%  = RGB(0,0,0)
CONST WHITE_PIECE_COLOR%  = RGB(255,255,255)
CONST SELECTOR_COLOR%     = RGB(255, 0, 0)
CONST ERASE_COLOR%        = BOARD_COLOR%
CONST SELECTOR_EXTRA_RADIUS% = 2
CONST SELECTOR_RADIUS% = (SQUARE_SIZE% \ 2) - 1

'––– Variables –––
DIM k$                    ' for INKEY$ under OPTION EXPLICIT
DIM board%(BOARD_SIZE%, BOARD_SIZE%)

'––– Main Routine –––
draw_board

' Standard starting four
draw_piece 4, 4, WHITE_PIECE_COLOR%
draw_piece 5, 5, WHITE_PIECE_COLOR%
draw_piece 4, 5, BLACK_PIECE_COLOR%
draw_piece 5, 4, BLACK_PIECE_COLOR%

board%(4,4) = 1
board%(5,5) = 1
board%(4,5) = 2
board%(5,4) = 2

'––– Selector Movement –––
DIM sel_col% = 1, sel_row% = 1
draw_selector sel_col%, sel_row%, SELECTOR_COLOR%

DO
  k$ = INKEY$
  IF k$ = "" THEN
    PAUSE 20
    CONTINUE DO
  END IF
  ' Erase old position
  draw_selector sel_col%, sel_row%, ERASE_COLOR%
  SELECT CASE ASC(k$)
    CASE 128 ' Up
      IF sel_row% > 1 THEN sel_row% = sel_row% - 1
    CASE 129 ' Down
      IF sel_row% < BOARD_SIZE% THEN sel_row% = sel_row% + 1
    CASE 130 ' Left
      IF sel_col% > 1 THEN sel_col% = sel_col% - 1
    CASE 131 ' Right
      IF sel_col% < BOARD_SIZE% THEN sel_col% = sel_col% + 1
    CASE 13 ' Enter key
      IF board%(sel_col%, sel_row%) = 0 THEN
        board%(sel_col%, sel_row%) = 1
        draw_piece sel_col%, sel_row%, WHITE_PIECE_COLOR%
      END IF
  END SELECT
    ' Draw new position
  draw_selector sel_col%, sel_row%, SELECTOR_COLOR%
LOOP


SUB draw_selector(col%, row%, sel_color%)
  LOCAL x%, y%, r%
  x% = (col% - 1) * SQUARE_SIZE% + SQUARE_SIZE% \ 2
  y% = (row% - 1) * SQUARE_SIZE% + SQUARE_SIZE% \ 2
  r% = ((SQUARE_SIZE% - 5) \ 2) + SELECTOR_EXTRA_RADIUS%
  CIRCLE x%, y%, r%, 1, 1.0, sel_color%, -1
END SUB

'––– Draw the green board and grid –––
SUB draw_board
  LOCAL i%
  CLS BOARD_COLOR%        ' clear to green
  FOR i% = 0 TO BOARD_SIZE%
    ' vertical line
    LINE i%*SQUARE_SIZE%, 0, i%*SQUARE_SIZE%, BOARD_SIZE%*SQUARE_SIZE%, 1, LINE_COLOR%
    ' horizontal line
    LINE 0, i%*SQUARE_SIZE%, BOARD_SIZE%*SQUARE_SIZE%, i%*SQUARE_SIZE%, 1, LINE_COLOR%
  NEXT i%
END SUB

'––– Draw one piece (filled circle) –––
SUB draw_piece(col%, row%, piece_color%)
  LOCAL x%, y%, r%, outline_color%
  x% = (col% - 1) * SQUARE_SIZE% + SQUARE_SIZE% \ 2
  y% = (row% - 1) * SQUARE_SIZE% + SQUARE_SIZE% \ 2
  r% = (SQUARE_SIZE% - 5) \ 2
  IF piece_color% = BLACK_PIECE_COLOR% THEN
    outline_color% = BLACK_PIECE_COLOR%
  ELSE
    outline_color% = BLACK_PIECE_COLOR%
  END IF
  CIRCLE x%, y%, r%, 1, 1, outline_color%, piece_color%
END SUB









