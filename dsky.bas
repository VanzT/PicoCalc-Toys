' AGC DSKY Display for PicoMite/WebMite
' Apollo Guidance Computer Display and Keyboard Simulation
' Fixed version with working V35N00 lamp test

' Display configuration (320x320 square display)
CONST PANEL_X1 = 5           ' Left panel X position
CONST PANEL_X2 = 165         ' Right panel X position  
CONST PANEL_Y = 5            ' Both panels Y position
CONST PANEL_W1 = 150         ' Status panel width
CONST PANEL_W2 = 150         ' DSKY panel width
CONST PANEL_H = 310          ' Panel height (full screen)

' Input mode constants
CONST MODE_IDLE = 0
CONST MODE_INPUT_VERB = 1
CONST MODE_INPUT_NOUN = 2
CONST MODE_DISPLAY_CLOCK = 3
CONST MODE_SET_TIME = 4
CONST MODE_SET_DATE = 5

' Global variables for input state
DIM input_mode AS INTEGER
DIM verb AS INTEGER
DIM noun AS INTEGER
DIM verb_digits(1) AS INTEGER   ' Two digit verb entry
DIM noun_digits(1) AS INTEGER   ' Two digit noun entry
DIM digit_count AS INTEGER
DIM last_key$ AS STRING

' Clock input buffers
DIM time_input(5) AS INTEGER    ' HHMMSS input buffer
DIM date_input(5) AS INTEGER    ' DDMMYY input buffer

input_mode = MODE_IDLE
verb = 0
noun = 0
digit_count = 0
last_key$ = ""

' Lamp state array (0=off, 1=lit)
DIM lamp_state(13) AS INTEGER
' Initialize all lamps to off
FOR i = 0 TO 13
  lamp_state(i) = 0
NEXT i

' Colors
CONST CLR_BACKGROUND = RGB(80, 80, 80)
CONST CLR_PANEL = RGB(100, 100, 100)
CONST CLR_YELLOW = RGB(255, 215, 0)
CONST CLR_WHITE = RGB(255, 255, 255)
CONST CLR_GRAY = RGB(140, 140, 140)
CONST CLR_OFF = RGB(100, 100, 100)
CONST CLR_GREEN = RGB(0, 255, 0)
CONST CLR_DIM_GREEN = RGB(0, 15, 0)
CONST CLR_BLACK = RGB(0, 0, 0)
CONST CLR_DISPLAY_BG = RGB(20, 40, 20)

' Initialize display
CLS CLR_BACKGROUND
COLOUR CLR_WHITE, CLR_BACKGROUND  ' Set text color and background
FONT 1, 1

' Draw main panels initially
DrawStatusPanel
DrawDSKYPanel

' Set initial state to match reference: VERB 00, NOUN 00, PROG 00
' Turn on NO ATT lamp (lamp 2) at startup
lamp_state(2) = 1
UpdateSingleLamp 2

' Main loop - handle input
DO
  ' Check for keyboard input
  k$ = INKEY$
  IF k$ <> "" THEN
    ProcessKey k$
  END IF
  
  ' Update clock display if in display mode
  IF input_mode = MODE_DISPLAY_CLOCK THEN
    UpdateClockDisplay
    PAUSE 100  ' Update 10 times per second
  ELSE
    PAUSE 50  ' Normal delay
  END IF
LOOP

END

' ========================================
' Draw Status/Indicator Panel (Left Side)
' ========================================
SUB DrawStatusPanel
  LOCAL x, y, w, h
  
  ' Panel background
  BOX PANEL_X1, PANEL_Y, PANEL_W1, PANEL_H, 3, RGB(100,100,100), CLR_PANEL
  
  ' Define indicators - check lamp_state array to determine if lit
  ' Row 1
  IF lamp_state(0) = 1 THEN
    DrawIndicator PANEL_X1+5, PANEL_Y+10, 65, 32, "UPLINK~ACTY", CLR_WHITE
  ELSE
    DrawIndicator PANEL_X1+5, PANEL_Y+10, 65, 32, "UPLINK~ACTY", CLR_OFF
  END IF
  
  IF lamp_state(1) = 1 THEN
    DrawIndicator PANEL_X1+78, PANEL_Y+10, 65, 32, "TEMP", CLR_YELLOW
  ELSE
    DrawIndicator PANEL_X1+78, PANEL_Y+10, 65, 32, "TEMP", CLR_OFF
  END IF
  
  ' Row 2
  IF lamp_state(2) = 1 THEN
    DrawIndicator PANEL_X1+5, PANEL_Y+48, 65, 32, "NO ATT", CLR_WHITE
  ELSE
    DrawIndicator PANEL_X1+5, PANEL_Y+48, 65, 32, "NO ATT", CLR_OFF
  END IF
  
  IF lamp_state(3) = 1 THEN
    DrawIndicator PANEL_X1+78, PANEL_Y+48, 65, 32, "GIMBAL~LOCK", CLR_YELLOW
  ELSE
    DrawIndicator PANEL_X1+78, PANEL_Y+48, 65, 32, "GIMBAL~LOCK", CLR_OFF
  END IF
  
  ' Row 3
  IF lamp_state(4) = 1 THEN
    DrawIndicator PANEL_X1+5, PANEL_Y+86, 65, 32, "STBY", CLR_WHITE
  ELSE
    DrawIndicator PANEL_X1+5, PANEL_Y+86, 65, 32, "STBY", CLR_OFF
  END IF
  
  IF lamp_state(5) = 1 THEN
    DrawIndicator PANEL_X1+78, PANEL_Y+86, 65, 32, "PROG", CLR_YELLOW
  ELSE
    DrawIndicator PANEL_X1+78, PANEL_Y+86, 65, 32, "PROG", CLR_OFF
  END IF
  
  ' Row 4
  IF lamp_state(6) = 1 THEN
    DrawIndicator PANEL_X1+5, PANEL_Y+124, 65, 32, "KEY REL", CLR_WHITE
  ELSE
    DrawIndicator PANEL_X1+5, PANEL_Y+124, 65, 32, "KEY REL", CLR_OFF
  END IF
  
  IF lamp_state(7) = 1 THEN
    DrawIndicator PANEL_X1+78, PANEL_Y+124, 65, 32, "RESTART", CLR_WHITE
  ELSE
    DrawIndicator PANEL_X1+78, PANEL_Y+124, 65, 32, "RESTART", CLR_OFF
  END IF
  
  ' Row 5
  IF lamp_state(8) = 1 THEN
    DrawIndicator PANEL_X1+5, PANEL_Y+162, 65, 32, "OPR ERR", CLR_WHITE
  ELSE
    DrawIndicator PANEL_X1+5, PANEL_Y+162, 65, 32, "OPR ERR", CLR_OFF
  END IF
  
  IF lamp_state(9) = 1 THEN
    DrawIndicator PANEL_X1+78, PANEL_Y+162, 65, 32, "TRACKER", CLR_YELLOW
  ELSE
    DrawIndicator PANEL_X1+78, PANEL_Y+162, 65, 32, "TRACKER", CLR_OFF
  END IF
  
  ' Row 6
  IF lamp_state(10) = 1 THEN
    DrawIndicator PANEL_X1+5, PANEL_Y+200, 65, 32, "", CLR_WHITE
  ELSE
    DrawIndicator PANEL_X1+5, PANEL_Y+200, 65, 32, "", CLR_OFF
  END IF
  
  IF lamp_state(11) = 1 THEN
    DrawIndicator PANEL_X1+78, PANEL_Y+200, 65, 32, "ALT", CLR_YELLOW
  ELSE
    DrawIndicator PANEL_X1+78, PANEL_Y+200, 65, 32, "ALT", CLR_OFF
  END IF
  
  ' Row 7
  IF lamp_state(12) = 1 THEN
    DrawIndicator PANEL_X1+5, PANEL_Y+238, 65, 32, "", CLR_WHITE
  ELSE
    DrawIndicator PANEL_X1+5, PANEL_Y+238, 65, 32, "", CLR_OFF
  END IF
  
  IF lamp_state(13) = 1 THEN
    DrawIndicator PANEL_X1+78, PANEL_Y+238, 65, 32, "VEL", CLR_YELLOW
  ELSE
    DrawIndicator PANEL_X1+78, PANEL_Y+238, 65, 32, "VEL", CLR_OFF
  END IF
  
  ' Row 8
  DrawIndicator PANEL_X1+5, PANEL_Y+276, 65, 28, "", CLR_OFF
  DrawIndicator PANEL_X1+78, PANEL_Y+276, 65, 28, "", CLR_OFF
END SUB

' ========================================
' Update Single Lamp (optimized for lamp test)
' ========================================
SUB UpdateSingleLamp lamp_num
  LOCAL x, y, w, h, label$, clr
  
  ' Determine position, size, label and color for this lamp
  SELECT CASE lamp_num
    CASE 0  ' UPLINK ACTY
      x = PANEL_X1+5: y = PANEL_Y+10: w = 65: h = 32
      label$ = "UPLINK~ACTY"
      IF lamp_state(0) = 1 THEN
        clr = CLR_WHITE
      ELSE
        clr = CLR_OFF
      END IF
      
    CASE 1  ' TEMP
      x = PANEL_X1+78: y = PANEL_Y+10: w = 65: h = 32
      label$ = "TEMP"
      IF lamp_state(1) = 1 THEN
        clr = CLR_YELLOW
      ELSE
        clr = CLR_OFF
      END IF
      
    CASE 2  ' NO ATT
      x = PANEL_X1+5: y = PANEL_Y+48: w = 65: h = 32
      label$ = "NO ATT"
      IF lamp_state(2) = 1 THEN
        clr = CLR_WHITE
      ELSE
        clr = CLR_OFF
      END IF
      
    CASE 3  ' GIMBAL LOCK
      x = PANEL_X1+78: y = PANEL_Y+48: w = 65: h = 32
      label$ = "GIMBAL~LOCK"
      IF lamp_state(3) = 1 THEN
        clr = CLR_YELLOW
      ELSE
        clr = CLR_OFF
      END IF
      
    CASE 4  ' STBY
      x = PANEL_X1+5: y = PANEL_Y+86: w = 65: h = 32
      label$ = "STBY"
      IF lamp_state(4) = 1 THEN
        clr = CLR_WHITE
      ELSE
        clr = CLR_OFF
      END IF
      
    CASE 5  ' PROG
      x = PANEL_X1+78: y = PANEL_Y+86: w = 65: h = 32
      label$ = "PROG"
      IF lamp_state(5) = 1 THEN
        clr = CLR_YELLOW
      ELSE
        clr = CLR_OFF
      END IF
      
    CASE 6  ' KEY REL
      x = PANEL_X1+5: y = PANEL_Y+124: w = 65: h = 32
      label$ = "KEY REL"
      IF lamp_state(6) = 1 THEN
        clr = CLR_WHITE
      ELSE
        clr = CLR_OFF
      END IF
      
    CASE 7  ' RESTART
      x = PANEL_X1+78: y = PANEL_Y+124: w = 65: h = 32
      label$ = "RESTART"
      IF lamp_state(7) = 1 THEN
        clr = CLR_WHITE
      ELSE
        clr = CLR_OFF
      END IF
      
    CASE 8  ' OPR ERR
      x = PANEL_X1+5: y = PANEL_Y+162: w = 65: h = 32
      label$ = "OPR ERR"
      IF lamp_state(8) = 1 THEN
        clr = CLR_WHITE
      ELSE
        clr = CLR_OFF
      END IF
      
    CASE 9  ' TRACKER
      x = PANEL_X1+78: y = PANEL_Y+162: w = 65: h = 32
      label$ = "TRACKER"
      IF lamp_state(9) = 1 THEN
        clr = CLR_YELLOW
      ELSE
        clr = CLR_OFF
      END IF
      
    CASE 10  ' Blank
      x = PANEL_X1+5: y = PANEL_Y+200: w = 65: h = 32
      label$ = ""
      IF lamp_state(10) = 1 THEN
        clr = CLR_WHITE
      ELSE
        clr = CLR_OFF
      END IF
      
    CASE 11  ' ALT
      x = PANEL_X1+78: y = PANEL_Y+200: w = 65: h = 32
      label$ = "ALT"
      IF lamp_state(11) = 1 THEN
        clr = CLR_YELLOW
      ELSE
        clr = CLR_OFF
      END IF
      
    CASE 12  ' Blank
      x = PANEL_X1+5: y = PANEL_Y+238: w = 65: h = 32
      label$ = ""
      IF lamp_state(12) = 1 THEN
        clr = CLR_WHITE
      ELSE
        clr = CLR_OFF
      END IF
      
    CASE 13  ' VEL
      x = PANEL_X1+78: y = PANEL_Y+238: w = 65: h = 32
      label$ = "VEL"
      IF lamp_state(13) = 1 THEN
        clr = CLR_YELLOW
      ELSE
        clr = CLR_OFF
      END IF
      
    CASE ELSE
      EXIT SUB
  END SELECT
  
  ' Draw just this one indicator
  DrawIndicator x, y, w, h, label$, clr
END SUB

' ========================================
' Draw individual indicator lamp
' ========================================
SUB DrawIndicator x, y, w, h, label$, clr
  ' Draw box
  BOX x, y, w, h, 2, CLR_BLACK, clr
  
  ' Draw label if present - BLACK text like real DSKY
  IF label$ <> "" THEN
    ' Set font size
    FONT 1, 1
    
    ' Handle multi-line labels (separated by ~)
    LOCAL tilde_pos = INSTR(label$, "~")
    IF tilde_pos > 0 THEN
      ' Two line label
      LOCAL line1$ = LEFT$(label$, tilde_pos-1)
      LOCAL line2$ = MID$(label$, tilde_pos+1)
      TEXT x+w/2, y+h/2-6, line1$, "CM", 1, 1, CLR_BLACK, -1
      TEXT x+w/2, y+h/2+6, line2$, "CM", 1, 1, CLR_BLACK, -1
    ELSE
      ' Single line label
      TEXT x+w/2, y+h/2, label$, "CM", 1, 1, CLR_BLACK, -1
    END IF
  END IF
END SUB

' ========================================
' Draw DSKY Panel (Right Side)
' ========================================
SUB DrawDSKYPanel
  ' Panel background
  BOX PANEL_X2, PANEL_Y, PANEL_W2, PANEL_H, 2, RGB(100,100,100), CLR_PANEL
  
  ' Calculate row height: panel height / 5 rows = 310 / 5 = 62px per row
  LOCAL row_h = 62
  LOCAL digit_w = 18       ' Slimmer digit width to fit better
  LOCAL digit_h = 30       ' Larger digit height - ALL digits same height
  
  ' ROW 1: COMP ACTY (tall) and PROG with digits
  ' COMP ACTY indicator - spans full row height, 60px wide
  DrawIndicator PANEL_X2+8, PANEL_Y+8, 60, row_h-4, "COMP~ACTY", CLR_OFF
  
  ' PROG indicator - larger (28px tall), same width as COMP ACTY (60px)
  DrawIndicator PANEL_X2+78, PANEL_Y+8, 60, 28, "PROG", CLR_GREEN
  
  ' PROG digits (2 digits) - slimmer, centered below PROG
  DrawSevenSegDigit PANEL_X2+89, PANEL_Y+38, digit_w, digit_h, "0", 1
  DrawSevenSegDigit PANEL_X2+110, PANEL_Y+38, digit_w, digit_h, "0", 1
  
  ' ROW 2: VERB and NOUN with digits below
  LOCAL row2_y = PANEL_Y + 8 + row_h
  
  ' VERB indicator - larger (28px tall)
  DrawIndicator PANEL_X2+8, row2_y, 60, 28, "VERB", CLR_GREEN
  
  ' NOUN indicator - larger (28px tall)
  DrawIndicator PANEL_X2+78, row2_y, 60, 28, "NOUN", CLR_GREEN
  
  ' VERB digits (00) - slimmer, same height as all digits
  DrawSevenSegDigit PANEL_X2+19, row2_y+32, digit_w, digit_h, "0", 1
  DrawSevenSegDigit PANEL_X2+40, row2_y+32, digit_w, digit_h, "0", 1
  
  ' NOUN digits (00) - slimmer, same height as all digits
  DrawSevenSegDigit PANEL_X2+89, row2_y+32, digit_w, digit_h, "0", 1
  DrawSevenSegDigit PANEL_X2+110, row2_y+32, digit_w, digit_h, "0", 1
  
  ' ROWS 3-5: Display area with 3 data rows
  LOCAL row3_y = PANEL_Y + 8 + row_h * 2
  
  ' Spacing for data rows to fill space
  LOCAL row_spacing = 56   ' Space between row starts
  LOCAL line_offset = 10   ' Space between line and digits
  
  ' Data Row 1: blank (cleared at startup)
  LOCAL data1_y = row3_y + 18
  LINE PANEL_X2+12, data1_y, PANEL_X2+PANEL_W2-20, data1_y, 1, CLR_GREEN
  DrawSign PANEL_X2+15, data1_y+line_offset, 14, 32, "+"
  DrawSevenSegDigit PANEL_X2+33, data1_y+line_offset, digit_w, digit_h, " ", 0
  DrawSevenSegDigit PANEL_X2+54, data1_y+line_offset, digit_w, digit_h, " ", 0
  DrawSevenSegDigit PANEL_X2+75, data1_y+line_offset, digit_w, digit_h, " ", 0
  DrawSevenSegDigit PANEL_X2+96, data1_y+line_offset, digit_w, digit_h, " ", 0
  DrawSevenSegDigit PANEL_X2+117, data1_y+line_offset, digit_w, digit_h, " ", 0
  
  ' Data Row 2: blank (cleared at startup)
  LOCAL data2_y = data1_y + row_spacing
  LINE PANEL_X2+12, data2_y, PANEL_X2+PANEL_W2-20, data2_y, 1, CLR_GREEN
  DrawSign PANEL_X2+15, data2_y+line_offset, 14, 32, "+"
  DrawSevenSegDigit PANEL_X2+33, data2_y+line_offset, digit_w, digit_h, " ", 0
  DrawSevenSegDigit PANEL_X2+54, data2_y+line_offset, digit_w, digit_h, " ", 0
  DrawSevenSegDigit PANEL_X2+75, data2_y+line_offset, digit_w, digit_h, " ", 0
  DrawSevenSegDigit PANEL_X2+96, data2_y+line_offset, digit_w, digit_h, " ", 0
  DrawSevenSegDigit PANEL_X2+117, data2_y+line_offset, digit_w, digit_h, " ", 0
  
  ' Data Row 3: blank (cleared at startup)
  LOCAL data3_y = data2_y + row_spacing
  LINE PANEL_X2+12, data3_y, PANEL_X2+PANEL_W2-20, data3_y, 1, CLR_GREEN
  DrawSign PANEL_X2+15, data3_y+line_offset, 14, 32, "+"
  DrawSevenSegDigit PANEL_X2+33, data3_y+line_offset, digit_w, digit_h, " ", 0
  DrawSevenSegDigit PANEL_X2+54, data3_y+line_offset, digit_w, digit_h, " ", 0
  DrawSevenSegDigit PANEL_X2+75, data3_y+line_offset, digit_w, digit_h, " ", 0
  DrawSevenSegDigit PANEL_X2+96, data3_y+line_offset, digit_w, digit_h, " ", 0
  DrawSevenSegDigit PANEL_X2+117, data3_y+line_offset, digit_w, digit_h, " ", 0
END SUB

' ========================================
' Draw +/- sign
' ========================================
SUB DrawSign x, y, w, h, sign$
  LOCAL lw = 3  ' line width
  
  IF sign$ = "+" THEN
    ' Vertical line
    LINE x+w/2-lw/2, y+4, x+w/2-lw/2, y+h-4, lw, CLR_GREEN
    ' Horizontal line
    LINE x+2, y+h/2-lw/2, x+w-2, y+h/2-lw/2, lw, CLR_GREEN
  ELSE IF sign$ = "-" THEN
    ' Horizontal line only
    LINE x+2, y+h/2-lw/2, x+w-2, y+h/2-lw/2, lw, CLR_GREEN
  END IF
END SUB

' ========================================
' Draw Seven Segment Display Digit
' ========================================
SUB DrawSevenSegDigit x, y, w, h, digit$, lit
  '     aaa
  '    f   b
  '     ggg
  '    e   c
  '     ddd
  
  LOCAL seg_w = w * 0.15        ' segment width
  LOCAL seg_h = h * 0.08        ' segment height
  LOCAL half_h = h / 2
  LOCAL clr
  
  ' Define which segments are on for each digit
  ' Format: a,b,c,d,e,f,g (1=on, 0=off)
  LOCAL segs(6)
  
  ' Determine color based on lit state
  IF lit = 1 THEN
    clr = CLR_GREEN
  ELSE
    clr = CLR_DIM_GREEN
  END IF
  
  SELECT CASE digit$
    CASE "0"
      segs(0)=1: segs(1)=1: segs(2)=1: segs(3)=1: segs(4)=1: segs(5)=1: segs(6)=0
    CASE "1"
      segs(0)=0: segs(1)=1: segs(2)=1: segs(3)=0: segs(4)=0: segs(5)=0: segs(6)=0
    CASE "2"
      segs(0)=1: segs(1)=1: segs(2)=0: segs(3)=1: segs(4)=1: segs(5)=0: segs(6)=1
    CASE "3"
      segs(0)=1: segs(1)=1: segs(2)=1: segs(3)=1: segs(4)=0: segs(5)=0: segs(6)=1
    CASE "4"
      segs(0)=0: segs(1)=1: segs(2)=1: segs(3)=0: segs(4)=0: segs(5)=1: segs(6)=1
    CASE "5"
      segs(0)=1: segs(1)=0: segs(2)=1: segs(3)=1: segs(4)=0: segs(5)=1: segs(6)=1
    CASE "6"
      segs(0)=1: segs(1)=0: segs(2)=1: segs(3)=1: segs(4)=1: segs(5)=1: segs(6)=1
    CASE "7"
      segs(0)=1: segs(1)=1: segs(2)=1: segs(3)=0: segs(4)=0: segs(5)=0: segs(6)=0
    CASE "8"
      segs(0)=1: segs(1)=1: segs(2)=1: segs(3)=1: segs(4)=1: segs(5)=1: segs(6)=1
    CASE "9"
      segs(0)=1: segs(1)=1: segs(2)=1: segs(3)=1: segs(4)=0: segs(5)=1: segs(6)=1
    CASE ELSE
      ' Blank/off
      segs(0)=0: segs(1)=0: segs(2)=0: segs(3)=0: segs(4)=0: segs(5)=0: segs(6)=0
  END SELECT
  
  ' Draw segments
  ' Segment a (top)
  IF segs(0) = 1 THEN
    BOX x+seg_w, y, w-2*seg_w, seg_h, 0, , clr
  ELSE
    BOX x+seg_w, y, w-2*seg_w, seg_h, 0, , RGB(80, 80, 80)
  END IF
  
  ' Segment b (top right)
  IF segs(1) = 1 THEN
    BOX x+w-seg_w, y+seg_h, seg_w, half_h-seg_h, 0, , clr
  ELSE
    BOX x+w-seg_w, y+seg_h, seg_w, half_h-seg_h, 0, , RGB(80, 80, 80)
  END IF
  
  ' Segment c (bottom right)
  IF segs(2) = 1 THEN
    BOX x+w-seg_w, y+half_h, seg_w, half_h-seg_h, 0, , clr
  ELSE
    BOX x+w-seg_w, y+half_h, seg_w, half_h-seg_h, 0, , RGB(80, 80, 80)
  END IF
  
  ' Segment d (bottom)
  IF segs(3) = 1 THEN
    BOX x+seg_w, y+h-seg_h, w-2*seg_w, seg_h, 0, , clr
  ELSE
    BOX x+seg_w, y+h-seg_h, w-2*seg_w, seg_h, 0, , RGB(80, 80, 80)
  END IF
  
  ' Segment e (bottom left)
  IF segs(4) = 1 THEN
    BOX x, y+half_h, seg_w, half_h-seg_h, 0, , clr
  ELSE
    BOX x, y+half_h, seg_w, half_h-seg_h, 0, , RGB(80, 80, 80)
  END IF
  
  ' Segment f (top left)
  IF segs(5) = 1 THEN
    BOX x, y+seg_h, seg_w, half_h-seg_h, 0, , clr
  ELSE
    BOX x, y+seg_h, seg_w, half_h-seg_h, 0, , RGB(80, 80, 80)
  END IF
  
  ' Segment g (middle)
  IF segs(6) = 1 THEN
    BOX x+seg_w, y+half_h-seg_h/2, w-2*seg_w, seg_h, 0, , clr
  ELSE
    BOX x+seg_w, y+half_h-seg_h/2, w-2*seg_w, seg_h, 0, , RGB(80, 80, 80)
  END IF
END SUB

' ========================================
' Process Keyboard Input
' ========================================
SUB ProcessKey k$
  ' Convert to uppercase
  k$ = UCASE$(k$)
  
  SELECT CASE input_mode
    CASE MODE_IDLE
      ' Check for special keys
      IF k$ = "V" THEN
        ' VERB button pressed
        input_mode = MODE_INPUT_VERB
        digit_count = 0
        verb_digits(0) = 0
        verb_digits(1) = 0
        ' Turn on KEY REL lamp
        lamp_state(6) = 1
        UpdateSingleLamp 6
        UpdateVerbDisplay
        
      ELSE IF k$ = "N" THEN
        ' NOUN button pressed
        input_mode = MODE_INPUT_NOUN
        digit_count = 0
        noun_digits(0) = 0
        noun_digits(1) = 0
        ' Turn on KEY REL lamp
        lamp_state(6) = 1
        UpdateSingleLamp 6
        UpdateNounDisplay
        
      ELSE IF k$ = "K" THEN
        ' RESET key - clear any errors
        lamp_state(8) = 0  ' Turn off OPR ERR
        UpdateSingleLamp 8
        
      END IF
      
    CASE MODE_INPUT_VERB
      ' Entering VERB digits
      IF k$ >= "0" AND k$ <= "9" AND digit_count < 2 THEN
        verb_digits(digit_count) = VAL(k$)
        digit_count = digit_count + 1
        UpdateVerbDisplay
        
      ELSE IF k$ = CHR$(13) OR k$ = CHR$(10) THEN
        ' ENTER key - commit verb
        verb = verb_digits(0) * 10 + verb_digits(1)
        input_mode = MODE_IDLE
        ' Turn off KEY REL lamp
        lamp_state(6) = 0
        UpdateSingleLamp 6
        
      ELSE IF k$ = "C" OR k$ = "K" THEN
        ' CLEAR/RESET key - cancel input
        input_mode = MODE_IDLE
        verb_digits(0) = 0
        verb_digits(1) = 0
        digit_count = 0
        ' Turn off KEY REL lamp
        lamp_state(6) = 0
        UpdateSingleLamp 6
        UpdateVerbDisplay
        
      END IF
      
    CASE MODE_INPUT_NOUN
      ' Entering NOUN digits
      IF k$ >= "0" AND k$ <= "9" AND digit_count < 2 THEN
        noun_digits(digit_count) = VAL(k$)
        digit_count = digit_count + 1
        UpdateNounDisplay
        
      ELSE IF k$ = CHR$(13) OR k$ = CHR$(10) THEN
        ' ENTER key - commit noun and execute verb/noun combination
        noun = noun_digits(0) * 10 + noun_digits(1)
        input_mode = MODE_IDLE
        ' Turn off KEY REL lamp
        lamp_state(6) = 0
        UpdateSingleLamp 6
        ExecuteVerbNoun
        
      ELSE IF k$ = "C" OR k$ = "K" THEN
        ' CLEAR/RESET key - cancel input
        input_mode = MODE_IDLE
        noun_digits(0) = 0
        noun_digits(1) = 0
        digit_count = 0
        ' Turn off KEY REL lamp
        lamp_state(6) = 0
        UpdateSingleLamp 6
        UpdateNounDisplay
        
      END IF
      
    CASE MODE_DISPLAY_CLOCK
      ' Displaying clock - any key exits
      input_mode = MODE_IDLE
      ClearDataRegisters
      
    CASE MODE_SET_TIME
      ' Setting time - accept 4 digits (HHMM), seconds set to 00
      IF k$ >= "0" AND k$ <= "9" AND digit_count < 4 THEN
        time_input(digit_count) = VAL(k$)
        digit_count = digit_count + 1
        DisplayTimeInput
        
        ' Auto-execute when 4 digits entered
        IF digit_count = 4 THEN
          SetTimeFromInput
          ' Turn off KEY REL if input was successful
          IF input_mode = MODE_IDLE THEN
            lamp_state(6) = 0
            UpdateSingleLamp 6
          END IF
        END IF
        
      ELSE IF k$ = "C" OR k$ = "K" THEN
        ' CLEAR/RESET key - cancel
        input_mode = MODE_IDLE
        digit_count = 0
        ' Turn off KEY REL lamp
        lamp_state(6) = 0
        UpdateSingleLamp 6
        ' Turn off OPR ERR if it was on
        lamp_state(8) = 0
        UpdateSingleLamp 8
        ClearDataRegisters
        
      END IF
      
    CASE MODE_SET_DATE
      ' Setting date - accept 6 digits (DDMMYY)
      IF k$ >= "0" AND k$ <= "9" AND digit_count < 6 THEN
        date_input(digit_count) = VAL(k$)
        digit_count = digit_count + 1
        DisplayDateInput
        
        ' Auto-execute when 6 digits entered
        IF digit_count = 6 THEN
          SetDateFromInput
          ' Turn off KEY REL if input was successful
          IF input_mode = MODE_IDLE THEN
            lamp_state(6) = 0
            UpdateSingleLamp 6
          END IF
        END IF
        
      ELSE IF k$ = "C" OR k$ = "K" THEN
        ' CLEAR/RESET key - cancel
        input_mode = MODE_IDLE
        digit_count = 0
        ' Turn off KEY REL lamp
        lamp_state(6) = 0
        UpdateSingleLamp 6
        ' Turn off OPR ERR if it was on
        lamp_state(8) = 0
        UpdateSingleLamp 8
        ClearDataRegisters
        
      END IF
      
  END SELECT
END SUB

' ========================================
' Execute Verb/Noun Combination
' ========================================
SUB ExecuteVerbNoun
  ' V35N00 - Lamp Test
  IF verb = 35 AND noun = 0 THEN
    ExecuteLampTest
  END IF
  
  ' V16N36 - Display Clock Time
  IF verb = 16 AND noun = 36 THEN
    input_mode = MODE_DISPLAY_CLOCK
  END IF
  
  ' V21N36 - Set Time
  IF verb = 21 AND noun = 36 THEN
    input_mode = MODE_SET_TIME
    digit_count = 0
    ' Clear input buffer
    FOR i = 0 TO 5
      time_input(i) = 0
    NEXT i
    ' Turn on KEY REL lamp to indicate input mode
    lamp_state(6) = 1
    UpdateSingleLamp 6
    UpdateVerbDisplay
  END IF
  
  ' V21N37 - Set Date
  IF verb = 21 AND noun = 37 THEN
    input_mode = MODE_SET_DATE
    digit_count = 0
    ' Clear input buffer
    FOR i = 0 TO 5
      date_input(i) = 0
    NEXT i
    ' Turn on KEY REL lamp to indicate input mode
    lamp_state(6) = 1
    UpdateSingleLamp 6
    UpdateVerbDisplay
  END IF
END SUB

' ========================================
' Execute Complete Lamp Test Sequence
' ========================================
SUB ExecuteLampTest
  LOCAL i, j, blink_count
  
  ' Phase 1: Sequential lamp animation (50ms per lamp)
  FOR i = 0 TO 13
    ' Turn on current lamp
    lamp_state(i) = 1
    UpdateSingleLamp i  ' Only redraw this one lamp
    PAUSE 50
  NEXT i
  
  ' Phase 2: Show all 8's on displays (sequentially light up each digit)
  ' We'll light up all the 7-segment displays to show "8"
  LOCAL row_h = 62
  LOCAL digit_w = 18
  LOCAL digit_h = 30
  LOCAL row2_y = PANEL_Y + 8 + row_h
  LOCAL row3_y = PANEL_Y + 8 + row_h * 2
  LOCAL row_spacing = 56
  LOCAL line_offset = 10
  
  ' PROG digits show 88
  DrawSevenSegDigit PANEL_X2+89, PANEL_Y+38, digit_w, digit_h, "8", 1
  PAUSE 25
  DrawSevenSegDigit PANEL_X2+110, PANEL_Y+38, digit_w, digit_h, "8", 1
  PAUSE 25
  
  ' VERB digits show 88
  DrawSevenSegDigit PANEL_X2+19, row2_y+32, digit_w, digit_h, "8", 1
  PAUSE 25
  DrawSevenSegDigit PANEL_X2+40, row2_y+32, digit_w, digit_h, "8", 1
  PAUSE 25
  
  ' NOUN digits show 88
  DrawSevenSegDigit PANEL_X2+89, row2_y+32, digit_w, digit_h, "8", 1
  PAUSE 25
  DrawSevenSegDigit PANEL_X2+110, row2_y+32, digit_w, digit_h, "8", 1
  PAUSE 25
  
  ' Data row 1: show all 8's
  LOCAL data1_y = row3_y + 18
  LOCAL data2_y = data1_y + row_spacing
  LOCAL data3_y = data2_y + row_spacing
  
  DrawSevenSegDigit PANEL_X2+33, data1_y+line_offset, digit_w, digit_h, "8", 1
  PAUSE 25
  DrawSevenSegDigit PANEL_X2+54, data1_y+line_offset, digit_w, digit_h, "8", 1
  PAUSE 25
  DrawSevenSegDigit PANEL_X2+75, data1_y+line_offset, digit_w, digit_h, "8", 1
  PAUSE 25
  DrawSevenSegDigit PANEL_X2+96, data1_y+line_offset, digit_w, digit_h, "8", 1
  PAUSE 25
  DrawSevenSegDigit PANEL_X2+117, data1_y+line_offset, digit_w, digit_h, "8", 1
  PAUSE 25
  
  ' Data row 2: show all 8's
  DrawSevenSegDigit PANEL_X2+33, data2_y+line_offset, digit_w, digit_h, "8", 1
  PAUSE 25
  DrawSevenSegDigit PANEL_X2+54, data2_y+line_offset, digit_w, digit_h, "8", 1
  PAUSE 25
  DrawSevenSegDigit PANEL_X2+75, data2_y+line_offset, digit_w, digit_h, "8", 1
  PAUSE 25
  DrawSevenSegDigit PANEL_X2+96, data2_y+line_offset, digit_w, digit_h, "8", 1
  PAUSE 25
  DrawSevenSegDigit PANEL_X2+117, data2_y+line_offset, digit_w, digit_h, "8", 1
  PAUSE 25
  
  ' Data row 3: show all 8's
  DrawSevenSegDigit PANEL_X2+33, data3_y+line_offset, digit_w, digit_h, "8", 1
  PAUSE 25
  DrawSevenSegDigit PANEL_X2+54, data3_y+line_offset, digit_w, digit_h, "8", 1
  PAUSE 25
  DrawSevenSegDigit PANEL_X2+75, data3_y+line_offset, digit_w, digit_h, "8", 1
  PAUSE 25
  DrawSevenSegDigit PANEL_X2+96, data3_y+line_offset, digit_w, digit_h, "8", 1
  PAUSE 25
  DrawSevenSegDigit PANEL_X2+117, data3_y+line_offset, digit_w, digit_h, "8", 1
  
  ' Hold for 1.5 seconds
  PAUSE 1500
  
  ' Phase 3: Blink OPR ERR and KEY REL lamps 4 times
  ' Turn off all other lamps first
  FOR i = 0 TO 13
    IF lamp_state(i) = 1 THEN
      lamp_state(i) = 0
      UpdateSingleLamp i  ' Update each lamp individually
    END IF
  NEXT i
  
  ' Reuse digit positions already calculated earlier
  ' row_h, digit_w, digit_h, row2_y are already LOCAL variables
  
  FOR blink_count = 1 TO 4
    ' Off phase
    lamp_state(6) = 0  ' KEY REL off
    lamp_state(8) = 0  ' OPR ERR off
    UpdateSingleLamp 6
    UpdateSingleLamp 8
    
    ' Clear only the digit areas (not the lamp boxes or labels)
    ' Clear PROG digits
    BOX PANEL_X2+89, PANEL_Y+38, 42, digit_h, 0, , CLR_PANEL
    ' Clear VERB digits  
    BOX PANEL_X2+19, row2_y+32, 42, digit_h, 0, , CLR_PANEL
    ' Clear NOUN digits
    BOX PANEL_X2+89, row2_y+32, 42, digit_h, 0, , CLR_PANEL
    
    PAUSE 500
    
    ' On phase
    lamp_state(6) = 1  ' KEY REL on
    lamp_state(8) = 1  ' OPR ERR on
    UpdateSingleLamp 6
    UpdateSingleLamp 8
    
    ' Show 8's on PROG, VERB, NOUN
    DrawSevenSegDigit PANEL_X2+89, PANEL_Y+38, digit_w, digit_h, "8", 1
    DrawSevenSegDigit PANEL_X2+110, PANEL_Y+38, digit_w, digit_h, "8", 1
    DrawSevenSegDigit PANEL_X2+19, row2_y+32, digit_w, digit_h, "8", 1
    DrawSevenSegDigit PANEL_X2+40, row2_y+32, digit_w, digit_h, "8", 1
    DrawSevenSegDigit PANEL_X2+89, row2_y+32, digit_w, digit_h, "8", 1
    DrawSevenSegDigit PANEL_X2+110, row2_y+32, digit_w, digit_h, "8", 1
    
    PAUSE 500
  NEXT blink_count
  
  ' Phase 4: Clean up - turn off the two blinking lamps
  lamp_state(6) = 0
  lamp_state(8) = 0
  UpdateSingleLamp 6
  UpdateSingleLamp 8
  
  ' Clear ALL displays including data rows (like reference does)
  BOX PANEL_X2+8, PANEL_Y+8, PANEL_W2-16, PANEL_H-16, 0, , CLR_PANEL
  
  ' Redraw only the lamp indicators and labels (not digits)
  DrawIndicator PANEL_X2+8, PANEL_Y+8, 60, row_h-4, "COMP~ACTY", CLR_OFF
  DrawIndicator PANEL_X2+78, PANEL_Y+8, 60, 28, "PROG", CLR_GREEN
  DrawIndicator PANEL_X2+8, row2_y, 60, 28, "VERB", CLR_GREEN
  DrawIndicator PANEL_X2+78, row2_y, 60, 28, "NOUN", CLR_GREEN
  
  ' Restore the PROG, VERB, NOUN digits to 00
  DrawSevenSegDigit PANEL_X2+89, PANEL_Y+38, digit_w, digit_h, "0", 1
  DrawSevenSegDigit PANEL_X2+110, PANEL_Y+38, digit_w, digit_h, "0", 1
  DrawSevenSegDigit PANEL_X2+19, row2_y+32, digit_w, digit_h, "0", 1
  DrawSevenSegDigit PANEL_X2+40, row2_y+32, digit_w, digit_h, "0", 1
  DrawSevenSegDigit PANEL_X2+89, row2_y+32, digit_w, digit_h, "0", 1
  DrawSevenSegDigit PANEL_X2+110, row2_y+32, digit_w, digit_h, "0", 1
  
  ' Redraw the green lines for data rows (but leave digits blank)
  LINE PANEL_X2+12, data1_y, PANEL_X2+PANEL_W2-20, data1_y, 1, CLR_GREEN
  DrawSign PANEL_X2+15, data1_y+line_offset, 14, 32, "+"
  LINE PANEL_X2+12, data2_y, PANEL_X2+PANEL_W2-20, data2_y, 1, CLR_GREEN
  DrawSign PANEL_X2+15, data2_y+line_offset, 14, 32, "+"
  LINE PANEL_X2+12, data3_y, PANEL_X2+PANEL_W2-20, data3_y, 1, CLR_GREEN
  DrawSign PANEL_X2+15, data3_y+line_offset, 14, 32, "+"
  
  ' Exit lamp test mode
  input_mode = MODE_IDLE
END SUB

' ========================================
' Update VERB Display
' ========================================
SUB UpdateVerbDisplay
  LOCAL row_h = 62
  LOCAL digit_w = 18
  LOCAL digit_h = 30
  LOCAL row2_y = PANEL_Y + 8 + row_h
  
  ' Clear the verb digit area
  BOX PANEL_X2+19, row2_y+32, 42, digit_h, 0, , CLR_PANEL
  
  ' Draw the two digits
  DrawSevenSegDigit PANEL_X2+19, row2_y+32, digit_w, digit_h, STR$(verb_digits(0)), 1
  DrawSevenSegDigit PANEL_X2+40, row2_y+32, digit_w, digit_h, STR$(verb_digits(1)), 1
END SUB

' ========================================
' Update NOUN Display
' ========================================
SUB UpdateNounDisplay
  LOCAL row_h = 62
  LOCAL digit_w = 18
  LOCAL digit_h = 30
  LOCAL row2_y = PANEL_Y + 8 + row_h
  
  ' Clear the noun digit area
  BOX PANEL_X2+89, row2_y+32, 42, digit_h, 0, , CLR_PANEL
  
  ' Draw the two digits
  DrawSevenSegDigit PANEL_X2+89, row2_y+32, digit_w, digit_h, STR$(noun_digits(0)), 1
  DrawSevenSegDigit PANEL_X2+110, row2_y+32, digit_w, digit_h, STR$(noun_digits(1)), 1
END SUB

' ========================================
' Update Clock Display (V16N36)
' ========================================
SUB UpdateClockDisplay
  LOCAL t$, h, m, s
  LOCAL row_h = 62
  LOCAL digit_w = 18
  LOCAL digit_h = 30
  LOCAL row3_y = PANEL_Y + 8 + row_h * 2
  LOCAL row_spacing = 56
  LOCAL line_offset = 10
  LOCAL data1_y = row3_y + 18
  LOCAL data2_y = data1_y + row_spacing
  LOCAL data3_y = data2_y + row_spacing
  STATIC last_sec AS INTEGER
  STATIC last_min AS INTEGER
  STATIC last_hr AS INTEGER
  
  ' Get current time
  t$ = TIME$
  h = VAL(LEFT$(t$, 2))
  m = VAL(MID$(t$, 4, 2))
  s = VAL(RIGHT$(t$, 2))
  
  ' Only update display once per second (when seconds change)
  IF s = last_sec THEN EXIT SUB
  last_sec = s
  
  ' Blink COMP ACTY lamp briefly on each second
  ' Turn on COMP ACTY (it's on the right panel, not in lamp_state array)
  DrawIndicator PANEL_X2+8, PANEL_Y+8, 60, row_h-4, "COMP~ACTY", CLR_GREEN
  
  ' Only redraw hours if they changed
  IF h <> last_hr THEN
    last_hr = h
    ' R1: Hours (00-23) with leading zeros: 00000-00023
    BOX PANEL_X2+33, data1_y+line_offset, 102, digit_h, 0, , CLR_PANEL
    DrawSevenSegDigit PANEL_X2+33, data1_y+line_offset, digit_w, digit_h, "0", 1
    DrawSevenSegDigit PANEL_X2+54, data1_y+line_offset, digit_w, digit_h, "0", 1
    DrawSevenSegDigit PANEL_X2+75, data1_y+line_offset, digit_w, digit_h, "0", 1
    DrawSevenSegDigit PANEL_X2+96, data1_y+line_offset, digit_w, digit_h, STR$((h \ 10) MOD 10), 1
    DrawSevenSegDigit PANEL_X2+117, data1_y+line_offset, digit_w, digit_h, STR$(h MOD 10), 1
  END IF
  
  ' Only redraw minutes if they changed
  IF m <> last_min THEN
    last_min = m
    ' R2: Minutes (00-59) with leading zeros: 00000-00059
    BOX PANEL_X2+33, data2_y+line_offset, 102, digit_h, 0, , CLR_PANEL
    DrawSevenSegDigit PANEL_X2+33, data2_y+line_offset, digit_w, digit_h, "0", 1
    DrawSevenSegDigit PANEL_X2+54, data2_y+line_offset, digit_w, digit_h, "0", 1
    DrawSevenSegDigit PANEL_X2+75, data2_y+line_offset, digit_w, digit_h, "0", 1
    DrawSevenSegDigit PANEL_X2+96, data2_y+line_offset, digit_w, digit_h, STR$((m \ 10) MOD 10), 1
    DrawSevenSegDigit PANEL_X2+117, data2_y+line_offset, digit_w, digit_h, STR$(m MOD 10), 1
  END IF
  
  ' Always redraw seconds (they change every time we get here)
  ' R3: Seconds (00-59) with leading zeros: 00000-00059
  BOX PANEL_X2+33, data3_y+line_offset, 102, digit_h, 0, , CLR_PANEL
  DrawSevenSegDigit PANEL_X2+33, data3_y+line_offset, digit_w, digit_h, "0", 1
  DrawSevenSegDigit PANEL_X2+54, data3_y+line_offset, digit_w, digit_h, "0", 1
  DrawSevenSegDigit PANEL_X2+75, data3_y+line_offset, digit_w, digit_h, "0", 1
  DrawSevenSegDigit PANEL_X2+96, data3_y+line_offset, digit_w, digit_h, STR$((s \ 10) MOD 10), 1
  DrawSevenSegDigit PANEL_X2+117, data3_y+line_offset, digit_w, digit_h, STR$(s MOD 10), 1
  
  ' Brief pause with COMP ACTY on
  PAUSE 100
  
  ' Turn off COMP ACTY
  DrawIndicator PANEL_X2+8, PANEL_Y+8, 60, row_h-4, "COMP~ACTY", CLR_OFF
END SUB

' ========================================
' Set Time Function (V21N36)
' ========================================
SUB SetTimeFromInput
  LOCAL h, m, s, time_str$
  
  ' Build time from 4 digits: HHMM (seconds = 00)
  h = time_input(0) * 10 + time_input(1)
  m = time_input(2) * 10 + time_input(3)
  s = 0  ' Seconds always 00
  
  ' Validate ranges
  IF h > 23 OR m > 59 THEN
    ' Turn on OPR ERR lamp to indicate invalid input
    lamp_state(8) = 1
    UpdateSingleLamp 8
    ' Stay in input mode so user can press K to reset
    EXIT SUB
  END IF
  
  ' Format and set time
  time_str$ = RIGHT$("0" + STR$(h), 2) + ":" + RIGHT$("0" + STR$(m), 2) + ":00"
  TIME$ = time_str$
  
  ' Return to idle mode (successful)
  input_mode = MODE_IDLE
  
  ' Clear the input display
  ClearDataRegisters
END SUB

' ========================================
' Set Date Function (V21N37)
' ========================================
SUB SetDateFromInput
  LOCAL d, m, y, date_str$
  
  ' Build date from 6 digits: DDMMYY
  d = date_input(0) * 10 + date_input(1)
  m = date_input(2) * 10 + date_input(3)
  y = date_input(4) * 10 + date_input(5)
  
  ' Validate ranges (basic check)
  IF d < 1 OR d > 31 OR m < 1 OR m > 12 THEN
    ' Turn on OPR ERR lamp to indicate invalid input
    lamp_state(8) = 1
    UpdateSingleLamp 8
    ' Stay in input mode so user can press K to reset
    EXIT SUB
  END IF
  
  ' Format and set date (DD-MM-YY format)
  date_str$ = RIGHT$("0" + STR$(d), 2) + "-" + RIGHT$("0" + STR$(m), 2) + "-" + RIGHT$("0" + STR$(y), 2)
  DATE$ = date_str$
  
  ' Return to idle mode (successful)
  input_mode = MODE_IDLE
  
  ' Clear the input display
  ClearDataRegisters
END SUB

' ========================================
' Clear Data Registers
' ========================================
SUB ClearDataRegisters
  LOCAL row_h = 62
  LOCAL digit_w = 18
  LOCAL digit_h = 30
  LOCAL row3_y = PANEL_Y + 8 + row_h * 2
  LOCAL row_spacing = 56
  LOCAL line_offset = 10
  LOCAL data1_y = row3_y + 18
  LOCAL data2_y = data1_y + row_spacing
  LOCAL data3_y = data2_y + row_spacing
  
  ' Clear all three data rows
  BOX PANEL_X2+33, data1_y+line_offset, 102, digit_h, 0, , CLR_PANEL
  BOX PANEL_X2+33, data2_y+line_offset, 102, digit_h, 0, , CLR_PANEL
  BOX PANEL_X2+33, data3_y+line_offset, 102, digit_h, 0, , CLR_PANEL
END SUB

' ========================================
' Display Time Input in Progress
' ========================================
SUB DisplayTimeInput
  LOCAL i
  LOCAL row_h = 62
  LOCAL digit_w = 18
  LOCAL digit_h = 30
  LOCAL row3_y = PANEL_Y + 8 + row_h * 2
  LOCAL row_spacing = 56
  LOCAL line_offset = 10
  LOCAL data2_y = row3_y + 18 + row_spacing
  
  ' Show input in R2 (middle row)
  BOX PANEL_X2+33, data2_y+line_offset, 102, digit_h, 0, , CLR_PANEL
  
  FOR i = 0 TO digit_count - 1
    DrawSevenSegDigit PANEL_X2+33+(i*17), data2_y+line_offset, digit_w, digit_h, STR$(time_input(i)), 1
  NEXT i
END SUB

' ========================================
' Display Date Input in Progress
' ========================================
SUB DisplayDateInput
  LOCAL i
  LOCAL row_h = 62
  LOCAL digit_w = 18
  LOCAL digit_h = 30
  LOCAL row3_y = PANEL_Y + 8 + row_h * 2
  LOCAL row_spacing = 56
  LOCAL line_offset = 10
  LOCAL data2_y = row3_y + 18 + row_spacing
  
  ' Show input in R2 (middle row)
  BOX PANEL_X2+33, data2_y+line_offset, 102, digit_h, 0, , CLR_PANEL
  
  FOR i = 0 TO digit_count - 1
    DrawSevenSegDigit PANEL_X2+33+(i*17), data2_y+line_offset, digit_w, digit_h, STR$(date_input(i)), 1
  NEXT i
END SUB