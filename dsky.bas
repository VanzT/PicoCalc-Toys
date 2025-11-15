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
CONST MODE_LUNAR_DESCENT = 5
CONST MODE_ALARM = 6         ' New: Alarm mode for 1201/1202

' V16 N68 - Lunar Descent Data Arrays
DIM descent_time_keys(23) AS INTEGER    ' Audio time in deciseconds
DIM descent_alt_keys(23) AS INTEGER     ' Altitude in feet
DIM descent_rate_keys(23) AS INTEGER    ' Descent rate in ft/sec (negative)

' Global variables for input state
DIM input_mode AS INTEGER
DIM verb AS INTEGER
DIM noun AS INTEGER
DIM verb_digits(1) AS INTEGER   ' Two digit verb entry
DIM noun_digits(1) AS INTEGER   ' Two digit noun entry
DIM digit_count AS INTEGER
DIM last_key$ AS STRING
DIM clock_reset AS INTEGER      ' Flag to reset clock display

' Alarm handling variables
DIM alarm_active AS INTEGER
DIM restart_timer AS INTEGER
DIM restart_active AS INTEGER
DIM alarm_code AS INTEGER    ' Store which alarm (1201 or 1202)

' Activity lamp blink variables
DIM uplink_blink AS INTEGER
DIM comp_blink AS INTEGER
DIM last_uplink_blink AS INTEGER
DIM last_comp_blink AS INTEGER

' Clock input buffers
DIM time_input(5) AS INTEGER    ' HHMMSS input buffer

input_mode = MODE_IDLE
verb = 0
noun = 0
digit_count = 0
last_key$ = ""
clock_reset = 0
alarm_active = 0
restart_active = 0
alarm_code = 0
uplink_blink = 0
comp_blink = 0

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

' Initialize blink timers
last_uplink_blink = TIMER
last_comp_blink = TIMER + 150  ' Offset by 150ms

' Draw main panels initially
DrawStatusPanel
DrawDSKYPanel

' Set initial state to match reference: VERB 00, NOUN 00, PROG 00
' NO ATT lamp should be OFF for simulation
lamp_state(2) = 0

' Main loop - handle input
DO
  ' Check for keyboard input
  k$ = INKEY$
  IF k$ <> "" THEN
    ProcessKey k$
  END IF
  
  ' Handle RESTART lamp timer (turn off after 2 seconds)
  IF restart_active = 1 AND TIMER - restart_timer >= 2000 THEN
    restart_active = 0
    lamp_state(7) = 0  ' Turn off RESTART lamp
    lamp_state(5) = 0  ' Turn off PROG lamp
    UpdateSingleLamp 7
    UpdateSingleLamp 5
    ' Resume displaying digits on row 5
    IF input_mode <> MODE_DISPLAY_CLOCK AND input_mode <> MODE_LUNAR_DESCENT THEN
      UpdateRow5Display
    END IF
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
    DrawIndicator PANEL_X1+5, PANEL_Y+8, 65, 40, "UPLINK~ACTY", CLR_WHITE
  ELSE
    DrawIndicator PANEL_X1+5, PANEL_Y+8, 65, 40, "UPLINK~ACTY", CLR_OFF
  END IF
  
  IF lamp_state(1) = 1 THEN
    DrawIndicator PANEL_X1+78, PANEL_Y+8, 65, 40, "TEMP", CLR_YELLOW
  ELSE
    DrawIndicator PANEL_X1+78, PANEL_Y+8, 65, 40, "TEMP", CLR_OFF
  END IF
  
  ' Row 2
  ' NO ATT lamp is always OFF for the simulation
  DrawIndicator PANEL_X1+5, PANEL_Y+50, 65, 40, "NO ATT", CLR_OFF
  
  IF lamp_state(3) = 1 THEN
    DrawIndicator PANEL_X1+78, PANEL_Y+50, 65, 40, "GIMBAL~LOCK", CLR_YELLOW
  ELSE
    DrawIndicator PANEL_X1+78, PANEL_Y+50, 65, 40, "GIMBAL~LOCK", CLR_OFF
  END IF
  
  ' Row 3
  IF lamp_state(4) = 1 THEN
    DrawIndicator PANEL_X1+5, PANEL_Y+92, 65, 40, "STBY", CLR_WHITE
  ELSE
    DrawIndicator PANEL_X1+5, PANEL_Y+92, 65, 40, "STBY", CLR_OFF
  END IF
  
  IF lamp_state(5) = 1 THEN
    DrawIndicator PANEL_X1+78, PANEL_Y+92, 65, 40, "PROG", CLR_YELLOW
  ELSE
    DrawIndicator PANEL_X1+78, PANEL_Y+92, 65, 40, "PROG", CLR_OFF
  END IF
  
  ' Row 4
  IF lamp_state(6) = 1 THEN
    DrawIndicator PANEL_X1+5, PANEL_Y+134, 65, 40, "KEY REL", CLR_WHITE
  ELSE
    DrawIndicator PANEL_X1+5, PANEL_Y+134, 65, 40, "KEY REL", CLR_OFF
  END IF
  
  ' RESTART lamp - now YELLOW
  IF lamp_state(7) = 1 THEN
    DrawIndicator PANEL_X1+78, PANEL_Y+134, 65, 40, "RESTART", CLR_YELLOW
  ELSE
    DrawIndicator PANEL_X1+78, PANEL_Y+134, 65, 40, "RESTART", CLR_OFF
  END IF
  
  ' 1-pixel spacing row after Row 4
  LINE PANEL_X1+5, PANEL_Y+175, PANEL_X1+PANEL_W1-5, PANEL_Y+175, 1, CLR_PANEL
  
  ' Row 5
  IF lamp_state(8) = 1 THEN
    DrawIndicator PANEL_X1+5, PANEL_Y+177, 65, 40, "OPR ERR", CLR_WHITE
  ELSE
    DrawIndicator PANEL_X1+5, PANEL_Y+177, 65, 40, "OPR ERR", CLR_OFF
  END IF
  
  IF lamp_state(9) = 1 THEN
    DrawIndicator PANEL_X1+78, PANEL_Y+177, 65, 40, "TRACKER", CLR_YELLOW
  ELSE
    DrawIndicator PANEL_X1+78, PANEL_Y+177, 65, 40, "TRACKER", CLR_OFF
  END IF
  
  ' 1-pixel spacing row after Row 5
  LINE PANEL_X1+5, PANEL_Y+218, PANEL_X1+PANEL_W1-5, PANEL_Y+218, 1, CLR_PANEL
  
  ' Row 6
  IF lamp_state(10) = 1 THEN
    DrawIndicator PANEL_X1+5, PANEL_Y+220, 65, 40, "", CLR_WHITE
  ELSE
    DrawIndicator PANEL_X1+5, PANEL_Y+220, 65, 40, "", CLR_OFF
  END IF
  
  IF lamp_state(11) = 1 THEN
    DrawIndicator PANEL_X1+78, PANEL_Y+220, 65, 40, "ALT", CLR_YELLOW
  ELSE
    DrawIndicator PANEL_X1+78, PANEL_Y+220, 65, 40, "ALT", CLR_OFF
  END IF
  
  ' Row 7
  IF lamp_state(12) = 1 THEN
    DrawIndicator PANEL_X1+5, PANEL_Y+262, 65, 40, "", CLR_WHITE
  ELSE
    DrawIndicator PANEL_X1+5, PANEL_Y+262, 65, 40, "", CLR_OFF
  END IF
  
  IF lamp_state(13) = 1 THEN
    DrawIndicator PANEL_X1+78, PANEL_Y+262, 65, 40, "VEL", CLR_YELLOW
  ELSE
    DrawIndicator PANEL_X1+78, PANEL_Y+262, 65, 40, "VEL", CLR_OFF
  END IF
  
END SUB

' ========================================
' Update Single Lamp (optimized for lamp test)
' ========================================
SUB UpdateSingleLamp lamp_num
  LOCAL x, y, w, h, label$, clr
  
  ' Determine position, size, label and color for this lamp
  SELECT CASE lamp_num
    CASE 0  ' UPLINK ACTY
      x = PANEL_X1+5: y = PANEL_Y+8: w = 65: h = 40
      label$ = "UPLINK~ACTY"
      IF lamp_state(0) = 1 THEN
        clr = CLR_WHITE
      ELSE
        clr = CLR_OFF
      END IF
      
    CASE 1  ' TEMP
      x = PANEL_X1+78: y = PANEL_Y+8: w = 65: h = 40
      label$ = "TEMP"
      IF lamp_state(1) = 1 THEN
        clr = CLR_YELLOW
      ELSE
        clr = CLR_OFF
      END IF
      
    CASE 2  ' NO ATT
      x = PANEL_X1+5: y = PANEL_Y+50: w = 65: h = 40
      label$ = "NO ATT"
      IF lamp_state(2) = 1 THEN
        clr = CLR_WHITE
      ELSE
        clr = CLR_OFF
      END IF
      
    CASE 3  ' GIMBAL LOCK
      x = PANEL_X1+78: y = PANEL_Y+50: w = 65: h = 40
      label$ = "GIMBAL~LOCK"
      IF lamp_state(3) = 1 THEN
        clr = CLR_YELLOW
      ELSE
        clr = CLR_OFF
      END IF
      
    CASE 4  ' STBY
      x = PANEL_X1+5: y = PANEL_Y+92: w = 65: h = 40
      label$ = "STBY"
      IF lamp_state(4) = 1 THEN
        clr = CLR_WHITE
      ELSE
        clr = CLR_OFF
      END IF
      
    CASE 5  ' PROG
      x = PANEL_X1+78: y = PANEL_Y+92: w = 65: h = 40
      label$ = "PROG"
      IF lamp_state(5) = 1 THEN
        clr = CLR_YELLOW
      ELSE
        clr = CLR_OFF
      END IF
      
    CASE 6  ' KEY REL
      x = PANEL_X1+5: y = PANEL_Y+134: w = 65: h = 40
      label$ = "KEY REL"
      IF lamp_state(6) = 1 THEN
        clr = CLR_WHITE
      ELSE
        clr = CLR_OFF
      END IF
      
    CASE 7  ' RESTART
      x = PANEL_X1+78: y = PANEL_Y+134: w = 65: h = 40
      label$ = "RESTART"
      IF lamp_state(7) = 1 THEN
        clr = CLR_YELLOW
      ELSE
        clr = CLR_OFF
      END IF
      
    CASE 8  ' OPR ERR
      x = PANEL_X1+5: y = PANEL_Y+177: w = 65: h = 40
      label$ = "OPR ERR"
      IF lamp_state(8) = 1 THEN
        clr = CLR_WHITE
      ELSE
        clr = CLR_OFF
      END IF
      
    CASE 9  ' TRACKER
      x = PANEL_X1+78: y = PANEL_Y+177: w = 65: h = 40
      label$ = "TRACKER"
      IF lamp_state(9) = 1 THEN
        clr = CLR_YELLOW
      ELSE
        clr = CLR_OFF
      END IF
      
    CASE 10  ' Blank
      x = PANEL_X1+5: y = PANEL_Y+220: w = 65: h = 40
      label$ = ""
      IF lamp_state(10) = 1 THEN
        clr = CLR_WHITE
      ELSE
        clr = CLR_OFF
      END IF
      
    CASE 11  ' ALT
      x = PANEL_X1+78: y = PANEL_Y+220: w = 65: h = 40
      label$ = "ALT"
      IF lamp_state(11) = 1 THEN
        clr = CLR_YELLOW
      ELSE
        clr = CLR_OFF
      END IF
      
    CASE 12  ' Blank
      x = PANEL_X1+5: y = PANEL_Y+262: w = 65: h = 40
      label$ = ""
      IF lamp_state(12) = 1 THEN
        clr = CLR_WHITE
      ELSE
        clr = CLR_OFF
      END IF
      
    CASE 13  ' VEL
      x = PANEL_X1+78: y = PANEL_Y+262: w = 65: h = 40
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
  
  ' Clear the sign area first
  BOX x, y, w, h, 0, , CLR_PANEL
  
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
        
      ELSE IF k$ = "P" THEN
        ' PRO key - used to acknowledge alarms
        IF alarm_active = 1 THEN
          ' Clear alarm and activate RESTART lamp
          alarm_active = 0
          lamp_state(5) = 0  ' Turn off PROG lamp
          lamp_state(7) = 1  ' Turn on RESTART lamp
          restart_active = 1
          restart_timer = TIMER
          UpdateSingleLamp 5
          UpdateSingleLamp 7
          ' Resume displaying digits if not in special mode
          IF input_mode <> MODE_DISPLAY_CLOCK AND input_mode <> MODE_LUNAR_DESCENT THEN
            UpdateRow5Display
          END IF
        END IF
        
      ELSE IF k$ = "1" THEN
        ' Simulate 1201 alarm (for testing)
        IF alarm_active = 0 THEN
          alarm_active = 1
          alarm_code = 1201
          lamp_state(5) = 1  ' Turn on PROG lamp
          UpdateSingleLamp 5
          ' Dim row 5 digits if not in special display mode
          IF input_mode <> MODE_DISPLAY_CLOCK AND input_mode <> MODE_LUNAR_DESCENT THEN
            DimRow5Display
          END IF
        END IF
        
      ELSE IF k$ = "2" THEN
        ' Simulate 1202 alarm (for testing)
        IF alarm_active = 0 THEN
          alarm_active = 1
          alarm_code = 1202
          lamp_state(5) = 1  ' Turn on PROG lamp
          UpdateSingleLamp 5
          ' Dim row 5 digits if not in special display mode
          IF input_mode <> MODE_DISPLAY_CLOCK AND input_mode <> MODE_LUNAR_DESCENT THEN
            DimRow5Display
          END IF
        END IF
        
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
    clock_reset = 1  ' Force all registers to display
  END IF
  
  ' V16N68 - Lunar Powered Descent Simulation
  IF verb = 16 AND noun = 68 THEN
    input_mode = MODE_LUNAR_DESCENT
    ' Update verb and noun displays
    verb_digits(0) = 1
    verb_digits(1) = 6
    noun_digits(0) = 6
    noun_digits(1) = 8
    UpdateVerbDisplay
    UpdateNounDisplay
    ' Start simulation
    RunLunarDescent
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
  LOCAL uplink_interval
  STATIC last_sec AS INTEGER = -1
  STATIC last_min AS INTEGER = -1
  STATIC last_hr AS INTEGER = -1
  STATIC comp_off_time AS INTEGER
  
  ' Handle UPLINK ACTY blinking (spastic chatter with brief pauses)
  IF uplink_blink = 1 THEN
    ' Currently on - short off time
    uplink_interval = 30 + INT(RND * 30)
  ELSE
    ' Currently off - mostly quick on, occasionally longer pause
    IF RND < 0.15 THEN
      ' 15% chance of a pause
      uplink_interval = 200 + INT(RND * 200)
    ELSE
      ' 85% chance of quick chatter
      uplink_interval = 30 + INT(RND * 40)
    END IF
  END IF
  
  IF TIMER - last_uplink_blink >= uplink_interval THEN
    uplink_blink = 1 - uplink_blink
    lamp_state(0) = uplink_blink
    last_uplink_blink = TIMER
    UpdateSingleLamp 0
  END IF
  
  ' Get current time
  t$ = TIME$
  h = VAL(LEFT$(t$, 2))
  m = VAL(MID$(t$, 4, 2))
  s = VAL(RIGHT$(t$, 2))
  
  ' Check if we need to reset (force display of all registers)
  IF clock_reset = 1 THEN
    last_sec = -1
    last_min = -1
    last_hr = -1
    clock_reset = 0  ' Clear the flag
  END IF
  
  ' Only update display once per second (when seconds change)
  IF s = last_sec THEN
    ' Not a new second yet - check if we need to turn off COMP ACTY
    IF TIMER >= comp_off_time AND comp_off_time > 0 THEN
      DrawIndicator PANEL_X2+8, PANEL_Y+8, 60, row_h-4, "COMP~ACTY", CLR_OFF
      comp_off_time = 0  ' Mark as handled
    END IF
    EXIT SUB
  END IF
  last_sec = s
  
  ' Schedule COMP ACTY to turn on 400ms from now
  LOCAL comp_acty_on_time = TIMER + 400
  LOCAL temp_key$
  
  ' Wait until 400ms have passed to turn on COMP ACTY
  ' BUT check for V or N key to allow immediate exit
  DO WHILE TIMER < comp_acty_on_time
    temp_key$ = INKEY$
    IF temp_key$ = "V" OR temp_key$ = "v" OR temp_key$ = "N" OR temp_key$ = "n" THEN
      ' User wants to enter a verb or noun - exit clock mode immediately
      input_mode = MODE_IDLE
      ProcessKey UCASE$(temp_key$)
      EXIT SUB
    END IF
    PAUSE 10
  LOOP
  
  ' Now turn on COMP ACTY
  DrawIndicator PANEL_X2+8, PANEL_Y+8, 60, row_h-4, "COMP~ACTY", CLR_GREEN
  
  ' Schedule it to turn off 200ms later
  comp_off_time = TIMER + 200
  
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
' V16 N68 - Initialize Lunar Descent Data
' ========================================
SUB InitLunarDescentData
  ' Accurate Apollo 11 descent data from PicoCalc
  ' Time is audio elapsed time in deciseconds
  ' R1 is MET seconds, converted to audio time: (MET - 534) * 10 = deciseconds
  
  ' Add initial keyframes to cover from audio start to first PicoCalc data
  ' MET 534: Audio start (estimated values for smooth descent)
  descent_time_keys(0) = 0      ' Audio 0:00 - MET 534
  descent_alt_keys(0) = 3368
  descent_rate_keys(0) = -737
  
  ' MET 558: Intermediate point (estimated)
  descent_time_keys(1) = 240    ' Audio 0:24 - MET 558
  descent_alt_keys(1) = 2000
  descent_rate_keys(1) = -500
  
  ' MET 580: Intermediate point (estimated for 1202 alarm period)
  descent_time_keys(2) = 460    ' Audio 0:46 - MET 580
  descent_alt_keys(2) = 1000
  descent_rate_keys(2) = -300
  
  ' MET 595: R1=595, R2=-170, R3=600 (First PicoCalc data point)
  descent_time_keys(3) = 610    ' Audio 1:01 - MET 595
  descent_alt_keys(3) = 600
  descent_rate_keys(3) = -170
  
  ' MET 599: R1=599, R2=-150, R3=540
  descent_time_keys(4) = 650    ' Audio 1:05 - MET 599
  descent_alt_keys(4) = 540
  descent_rate_keys(4) = -150
  
  ' MET 610: R1=610, R2=-90, R3=400
  descent_time_keys(5) = 760    ' Audio 1:16 - MET 610
  descent_alt_keys(5) = 400
  descent_rate_keys(5) = -90
  
  ' MET 617: R1=617, R2=-40, R3=350
  descent_time_keys(6) = 830    ' Audio 1:23 - MET 617
  descent_alt_keys(6) = 350
  descent_rate_keys(6) = -40
  
  ' MET 630: R1=630, R2=-35, R3=300
  descent_time_keys(7) = 960    ' Audio 1:36 - MET 630
  descent_alt_keys(7) = 300
  descent_rate_keys(7) = -35
  
  ' MET 637: R1=637, R2=-15, R3=281 (interpolated)
  descent_time_keys(8) = 1030   ' Audio 1:43 - MET 637
  descent_alt_keys(8) = 281
  descent_rate_keys(8) = -15
  
  ' MET 641: R1=641, R2=-15, R3=270 (R2 interpolated)
  descent_time_keys(9) = 1070   ' Audio 1:47 - MET 641
  descent_alt_keys(9) = 270
  descent_rate_keys(9) = -15
  
  ' MET 652: R1=652, R2=-15, R3=250
  descent_time_keys(10) = 1180  ' Audio 1:58 - MET 652
  descent_alt_keys(10) = 250
  descent_rate_keys(10) = -15
  
  ' MET 660: R1=660, R2=-35, R3=220
  descent_time_keys(11) = 1260  ' Audio 2:06 - MET 660
  descent_alt_keys(11) = 220
  descent_rate_keys(11) = -35
  
  ' MET 668: R1=668, R2=-45, R3=200
  descent_time_keys(12) = 1340  ' Audio 2:14 - MET 668
  descent_alt_keys(12) = 200
  descent_rate_keys(12) = -45
  
  ' MET 675: R1=675, R2=-65, R3=160
  descent_time_keys(13) = 1410  ' Audio 2:21 - MET 675
  descent_alt_keys(13) = 160
  descent_rate_keys(13) = -65
  
  ' MET 676: R1=676, R2=-65, R3=156 (R3 interpolated)
  descent_time_keys(14) = 1420  ' Audio 2:22 - MET 676
  descent_alt_keys(14) = 156
  descent_rate_keys(14) = -65
  
  ' MET 684: R1=684, R2=-47, R3=120 (R2 interpolated)
  descent_time_keys(15) = 1500  ' Audio 2:30 - MET 684
  descent_alt_keys(15) = 120
  descent_rate_keys(15) = -47
  
  ' MET 689: R1=689, R2=-35, R3=100
  descent_time_keys(16) = 1550  ' Audio 2:35 - MET 689
  descent_alt_keys(16) = 100
  descent_rate_keys(16) = -35
  
  ' MET 698: R1=698, R2=-31, R3=75 (R2 interpolated)
  descent_time_keys(17) = 1640  ' Audio 2:44 - MET 698
  descent_alt_keys(17) = 75
  descent_rate_keys(17) = -31
  
  ' MET 711: R1=711, R2=-25, R3=55 (R3 interpolated)
  descent_time_keys(18) = 1770  ' Audio 2:57 - MET 711
  descent_alt_keys(18) = 55
  descent_rate_keys(18) = -25
  
  ' MET 721: R1=721, R2=-25, R3=40
  descent_time_keys(19) = 1870  ' Audio 3:07 - MET 721
  descent_alt_keys(19) = 40
  descent_rate_keys(19) = -25
  
  ' MET 724: R1=724, R2=-25, R3=30
  descent_time_keys(20) = 1900  ' Audio 3:10 - MET 724
  descent_alt_keys(20) = 30
  descent_rate_keys(20) = -25
  
  ' MET 734: R1=734, R2=-5, R3=17 (R3 interpolated)
  descent_time_keys(21) = 2000  ' Audio 3:20 - MET 734
  descent_alt_keys(21) = 17
  descent_rate_keys(21) = -5
  
  ' MET 743: R1=743, R2=-9, R3=5 CONTACT LIGHT (R2/R3 estimated)
  descent_time_keys(22) = 2090  ' Audio 3:29 - MET 743
  descent_alt_keys(22) = 5
  descent_rate_keys(22) = -9
  
  ' MET 747: R1=747, R2=0, R3=0 TOUCHDOWN
  descent_time_keys(23) = 2130  ' Audio 3:33 - MET 747
  descent_alt_keys(23) = 0
  descent_rate_keys(23) = 0
END SUB

' ========================================
' V16 N68 - Main Lunar Descent Simulation
' ========================================
SUB RunLunarDescent
  InitLunarDescentData
  
  ' Clear data registers
  ClearDataRegisters
  
  ' Start audio
  PLAY FLAC "a11_descent.flac"
  
  LOCAL audio_start = TIMER
  LOCAL last_comp_blink = TIMER + 150  ' Offset by 150ms
  LOCAL last_uplink_blink = TIMER
  LOCAL comp_state = 0
  LOCAL uplink_state = 0
  
  ' Alarm tracking
  LOCAL in_alarm = 0
  LOCAL alarm_blink_state = 0
  LOCAL alarm_blink_timer = TIMER
  LOCAL alarm_type = 0  ' 1=1201, 2=1202
  LOCAL alarm_1201_acked = 0  ' Track if 1201 was acknowledged
  LOCAL alarm_1202_acked = 0  ' Track if 1202 was acknowledged
  LOCAL alarm_start_time = 0  ' When alarm started
  LOCAL restart_active = 0    ' RESTART lamp showing
  LOCAL restart_start_time = 0
  LOCAL should_acknowledge = 0 ' Flag for alarm acknowledgment
  LOCAL last_prog_state = -1  ' Track PROG lamp state to avoid flicker
  
  ' Loop variables
  LOCAL elapsed_ds
  LOCAL k$
  LOCAL altitude
  LOCAL desc_rate
  LOCAL pdi_seconds
  LOCAL uplink_interval
  LOCAL comp_interval
  LOCAL alt_vel_on
  LOCAL r1_int
  LOCAL r2_int
  LOCAL r3_int
  
  ' Track last displayed register values to avoid unnecessary redraws
  LOCAL last_r1 = -1
  LOCAL last_r2 = -9999
  LOCAL last_r3 = -1
  
  ' Initialize
  alt_vel_on = 0
  
  ' Main simulation loop
  DO WHILE MM.INFO$(SOUND) <> "OFF"
    ' Calculate elapsed time in deciseconds
    elapsed_ds = (TIMER - audio_start) / 100
    
    ' Check for keyboard input
    k$ = INKEY$
    
    ' Check for keyboard interrupt (V, N, K, or C keys)
    IF k$ = "V" OR k$ = "v" OR k$ = "N" OR k$ = "n" OR k$ = "K" OR k$ = "k" OR k$ = "C" OR k$ = "c" THEN
      PLAY STOP
      input_mode = MODE_IDLE
      ' Turn off RESTART and PROG lamps
      lamp_state(7) = 0
      lamp_state(5) = 0
      UpdateSingleLamp 7
      UpdateSingleLamp 5
      ProcessKey UCASE$(k$)
      EXIT SUB
    END IF
    
    ' Check for alarm periods (only if not already acknowledged)
    in_alarm = 0
    alarm_type = 0
    
    ' 1201 alarm from 0:08 to 0:19 (80-190 deciseconds) - MET 542-553
    IF elapsed_ds >= 80 AND elapsed_ds < 190 AND alarm_1201_acked = 0 THEN
      in_alarm = 1
      alarm_type = 1
    END IF
    
    ' Check if 1201 needs acknowledgment at 0:19 (MET 553 - RESTART)
    IF elapsed_ds >= 190 AND elapsed_ds < 210 AND alarm_1201_acked = 0 AND restart_active = 0 THEN
      ' Trigger RESTART sequence
      alarm_1201_acked = 1
      lamp_state(5) = 0  ' Turn off PROG
      UpdateSingleLamp 5
      lamp_state(7) = 1  ' Turn on RESTART
      UpdateSingleLamp 7
      restart_active = 1
      restart_start_time = TIMER
    END IF
    
    ' 1202 alarm from 0:46 (460 deciseconds) - MET 580
    ' RESTART lights at 0:49 (490 deciseconds) - 3 seconds after alarm - MET 583
    ' Both PROG and RESTART clear at 0:50 (500 deciseconds) - 1 second after RESTART - MET 584
    IF elapsed_ds >= 460 AND elapsed_ds < 500 AND alarm_1202_acked = 0 THEN
      in_alarm = 1
      alarm_type = 2
      ' Mark when alarm started (only first time we see it)
      IF alarm_start_time = 0 THEN
        alarm_start_time = TIMER
      END IF
    END IF
    
    ' Turn on RESTART lamp 3 seconds after 1202 alarm starts (at 490 deciseconds)
    IF elapsed_ds >= 490 AND elapsed_ds < 500 AND alarm_1202_acked = 0 AND alarm_type = 2 THEN
      lamp_state(7) = 1  ' Turn on RESTART
      UpdateSingleLamp 7
      restart_active = 1
    END IF
    
    ' Handle alarm display
    IF in_alarm = 1 THEN
      ' Check if it's time to clear both PROG and RESTART at 0:50 (500 deciseconds)
      should_acknowledge = 0
      
      ' 1202 alarm cleared at 0:50 (500 deciseconds) - MET 584
      IF alarm_type = 2 AND elapsed_ds >= 500 THEN
        should_acknowledge = 1
      END IF
      
      IF should_acknowledge = 1 THEN
        ' Mark alarm as acknowledged
        alarm_1202_acked = 1
        
        ' Turn off BOTH PROG and RESTART lamps
        lamp_state(5) = 0
        lamp_state(7) = 0
        UpdateSingleLamp 5
        UpdateSingleLamp 7
        restart_active = 0
        
        ' Clear alarm state
        in_alarm = 0
        alarm_start_time = 0
        
        ' Reset tracking variables to force redraw when resuming
        last_r1 = -1
        last_r2 = -9999
        last_r3 = -1
      ELSE
        ' Still in alarm - show PROG lamp and blink alarm code
        IF lamp_state(5) = 0 THEN  ' Only turn on if currently off
          lamp_state(5) = 1
          UpdateSingleLamp 5
        END IF
        
        ' Blink alarm code in R1 and R2
        IF TIMER - alarm_blink_timer >= 500 THEN
          alarm_blink_state = 1 - alarm_blink_state
          alarm_blink_timer = TIMER
          
          IF alarm_blink_state = 1 THEN
            ' Show alarm code in R1 and R2
            IF alarm_type = 1 THEN
              DisplayAlarmCode 1201
            ELSE
              DisplayAlarmCode 1202
            END IF
          ELSE
            ' Blank R1 and R2
            ClearRegisters12
          END IF
        END IF
        
        ' Blank R3 (row 5) during alarm
        BlankRow5
      END IF
      
    ELSE IF restart_active = 1 THEN
      ' RESTART lamp is showing - ensure PROG is off
      IF lamp_state(5) = 1 THEN  ' Only turn off if currently on
        lamp_state(5) = 0
        UpdateSingleLamp 5
      END IF
      
      ' Check if 2 seconds have passed
      IF (TIMER - restart_start_time) >= 2000 THEN
        ' Turn off RESTART lamp
        lamp_state(7) = 0
        UpdateSingleLamp 7
        restart_active = 0
        
        ' Resume normal display - force redraw after RESTART clears
        altitude = InterpolateAltitude(elapsed_ds)
        desc_rate = InterpolateDescentRate(elapsed_ds)
        pdi_seconds = (elapsed_ds / 10) + 534  ' Add 534 seconds MET offset
        UpdateDescentDisplay pdi_seconds, desc_rate, altitude
        
        ' Update tracking variables
        last_r1 = INT(pdi_seconds)
        last_r2 = INT(ABS(desc_rate))
        last_r3 = INT(altitude)
      END IF
      
    ELSE
      ' Normal display - ensure PROG is off
      IF lamp_state(5) = 1 THEN  ' Only turn off if currently on
        lamp_state(5) = 0
        UpdateSingleLamp 5
      END IF
      
      ' Interpolate and show values
      altitude = InterpolateAltitude(elapsed_ds)
      desc_rate = InterpolateDescentRate(elapsed_ds)
      
      ' MET in seconds (starts at 534 seconds)
      pdi_seconds = (elapsed_ds / 10) + 534
      
      ' Only update registers that changed
      r1_int = INT(pdi_seconds)
      r2_int = INT(ABS(desc_rate))
      r3_int = INT(altitude)
      
      IF r1_int <> last_r1 THEN
        UpdateR1Display pdi_seconds
        last_r1 = r1_int
      END IF
      
      IF r2_int <> last_r2 THEN
        UpdateR2Display desc_rate
        last_r2 = r2_int
      END IF
      
      IF r3_int <> last_r3 THEN
        UpdateR3Display altitude
        last_r3 = r3_int
      END IF
    END IF
    
    ' Turn on ALT and VEL lamps at MET 658 (audio 2:04)
    IF elapsed_ds >= 1240 THEN
      lamp_state(11) = 1  ' ALT lamp
      lamp_state(13) = 1  ' VEL lamp
      ' Only update lamps once when we first cross the threshold
      IF alt_vel_on = 0 THEN
        UpdateSingleLamp 11
        UpdateSingleLamp 13
        alt_vel_on = 1
      END IF
    END IF
    
    ' Activity lamp blinking with realistic patterns
    ' UPLINK ACTY - spastic chatter with brief pauses
    ' Quick bursts: 30-60ms, occasional pause: 200-400ms
    IF uplink_state = 1 THEN
      ' Currently on - short off time (chatter continues)
      uplink_interval = 30 + INT(RND * 30)
    ELSE
      ' Currently off - mostly quick on, occasionally longer pause
      IF RND < 0.15 THEN
        ' 15% chance of a pause
        uplink_interval = 200 + INT(RND * 200)
      ELSE
        ' 85% chance of quick chatter
        uplink_interval = 30 + INT(RND * 40)
      END IF
    END IF
    
    IF TIMER - last_uplink_blink >= uplink_interval THEN
      uplink_state = 1 - uplink_state
      lamp_state(0) = uplink_state
      last_uplink_blink = TIMER
      UpdateSingleLamp 0
    END IF
    
    ' COMP ACTY - thinks hard (stays on), then brief break
    ' On time: 800-1500ms (thinking), Off time: 100-300ms (brief break)
    IF comp_state = 1 THEN
      ' Currently on - long thinking time
      comp_interval = 800 + INT(RND * 700)
    ELSE
      ' Currently off - short break
      comp_interval = 100 + INT(RND * 200)
    END IF
    
    IF TIMER - last_comp_blink >= comp_interval THEN
      comp_state = 1 - comp_state
      IF comp_state = 1 THEN
        DrawIndicator PANEL_X2+8, PANEL_Y+8, 60, 58, "COMP~ACTY", CLR_GREEN
      ELSE
        DrawIndicator PANEL_X2+8, PANEL_Y+8, 60, 58, "COMP~ACTY", CLR_OFF
      END IF
      last_comp_blink = TIMER
    END IF
    
    PAUSE 10
  LOOP
  
  ' Simulation complete
  input_mode = MODE_IDLE
  ' Turn off RESTART lamp
  lamp_state(7) = 0
  UpdateSingleLamp 7
END SUB

' ========================================
' Interpolate Altitude Value
' ========================================
FUNCTION InterpolateAltitude(current_time)
  LOCAL i, t1, t2, v1, v2, fraction
  
  ' Find which keyframe pair we're between
  FOR i = 0 TO 22
    IF current_time >= descent_time_keys(i) AND current_time <= descent_time_keys(i+1) THEN
      t1 = descent_time_keys(i)
      t2 = descent_time_keys(i+1)
      v1 = descent_alt_keys(i)
      v2 = descent_alt_keys(i+1)
      
      ' Calculate interpolation fraction
      IF t2 - t1 > 0 THEN
        fraction = (current_time - t1) / (t2 - t1)
      ELSE
        fraction = 0
      END IF
      
      ' Linear interpolation
      InterpolateAltitude = v1 + (v2 - v1) * fraction
      EXIT FUNCTION
    END IF
  NEXT i
  
  ' If past last keyframe, return last value
  InterpolateAltitude = descent_alt_keys(23)
END FUNCTION

' ========================================
' Interpolate Descent Rate Value
' ========================================
FUNCTION InterpolateDescentRate(current_time)
  LOCAL i, t1, t2, v1, v2, fraction
  
  ' Find which keyframe pair we're between
  FOR i = 0 TO 22
    IF current_time >= descent_time_keys(i) AND current_time <= descent_time_keys(i+1) THEN
      t1 = descent_time_keys(i)
      t2 = descent_time_keys(i+1)
      v1 = descent_rate_keys(i)
      v2 = descent_rate_keys(i+1)
      
      ' Calculate interpolation fraction
      IF t2 - t1 > 0 THEN
        fraction = (current_time - t1) / (t2 - t1)
      ELSE
        fraction = 0
      END IF
      
      ' Linear interpolation
      InterpolateDescentRate = v1 + (v2 - v1) * fraction
      EXIT FUNCTION
    END IF
  NEXT i
  
  ' If past last keyframe, return last value
  InterpolateDescentRate = descent_rate_keys(23)
END FUNCTION

' ========================================
' Update R1 Display (MET Time)
' ========================================
SUB UpdateR1Display pdi_time
  LOCAL row_h = 62
  LOCAL digit_w = 18
  LOCAL digit_h = 30
  LOCAL row3_y = PANEL_Y + 8 + row_h * 2
  LOCAL line_offset = 10
  LOCAL data1_y = row3_y + 18
  
  ' R1: Time from PDI (seconds, format +0SSS)
  BOX PANEL_X2+33, data1_y+line_offset, 102, digit_h, 0, , CLR_PANEL
  DrawSign PANEL_X2+15, data1_y+line_offset, 14, 32, "+"
  DrawDescentFourDigits PANEL_X2+54, data1_y+line_offset, digit_w, digit_h, INT(pdi_time)
END SUB

' ========================================
' Update R2 Display (Descent Rate)
' ========================================
SUB UpdateR2Display descent_rate
  LOCAL row_h = 62
  LOCAL digit_w = 18
  LOCAL digit_h = 30
  LOCAL row3_y = PANEL_Y + 8 + row_h * 2
  LOCAL row_spacing = 56
  LOCAL line_offset = 10
  LOCAL data1_y = row3_y + 18
  LOCAL data2_y = data1_y + row_spacing
  
  ' R2: Descent speed (ft/sec, always negative during descent, format -0FFF)
  BOX PANEL_X2+33, data2_y+line_offset, 102, digit_h, 0, , CLR_PANEL
  ' Always show minus sign for descent
  DrawSign PANEL_X2+15, data2_y+line_offset, 14, 32, "-"
  ' Take absolute value for display
  DrawDescentFourDigits PANEL_X2+54, data2_y+line_offset, digit_w, digit_h, INT(ABS(descent_rate))
END SUB

' ========================================
' Update R3 Display (Altitude)
' ========================================
SUB UpdateR3Display altitude
  LOCAL row_h = 62
  LOCAL digit_w = 18
  LOCAL digit_h = 30
  LOCAL row3_y = PANEL_Y + 8 + row_h * 2
  LOCAL row_spacing = 56
  LOCAL line_offset = 10
  LOCAL data1_y = row3_y + 18
  LOCAL data2_y = data1_y + row_spacing
  LOCAL data3_y = data2_y + row_spacing
  
  ' R3: Altitude (feet, format +FFFF)
  BOX PANEL_X2+33, data3_y+line_offset, 102, digit_h, 0, , CLR_PANEL
  DrawSign PANEL_X2+15, data3_y+line_offset, 14, 32, "+"
  DrawDescentFourDigits PANEL_X2+54, data3_y+line_offset, digit_w, digit_h, INT(altitude)
END SUB

' ========================================
' Update Descent Display (R1, R2, R3) - All registers
' ========================================
SUB UpdateDescentDisplay pdi_time, descent_rate, altitude
  UpdateR1Display pdi_time
  UpdateR2Display descent_rate
  UpdateR3Display altitude
END SUB

' ========================================
' Display Alarm Code (1201 or 1202) in R1 and R2
' ========================================
SUB DisplayAlarmCode alarm_code
  LOCAL row_h = 62
  LOCAL digit_w = 18
  LOCAL digit_h = 30
  LOCAL row3_y = PANEL_Y + 8 + row_h * 2
  LOCAL row_spacing = 56
  LOCAL line_offset = 10
  LOCAL data1_y = row3_y + 18
  LOCAL data2_y = data1_y + row_spacing
  
  LOCAL d1, d2, d3, d4
  
  ' Extract digits from alarm code
  d1 = (alarm_code \ 1000) MOD 10
  d2 = (alarm_code \ 100) MOD 10
  d3 = (alarm_code \ 10) MOD 10
  d4 = alarm_code MOD 10
  
  ' Display in R1
  BOX PANEL_X2+33, data1_y+line_offset, 102, digit_h, 0, , CLR_PANEL
  DrawSign PANEL_X2+15, data1_y+line_offset, 14, 32, "+"
  DrawSevenSegDigit PANEL_X2+54, data1_y+line_offset, digit_w, digit_h, STR$(d1), 1
  DrawSevenSegDigit PANEL_X2+75, data1_y+line_offset, digit_w, digit_h, STR$(d2), 1
  DrawSevenSegDigit PANEL_X2+96, data1_y+line_offset, digit_w, digit_h, STR$(d3), 1
  DrawSevenSegDigit PANEL_X2+117, data1_y+line_offset, digit_w, digit_h, STR$(d4), 1
  
  ' Display in R2
  BOX PANEL_X2+33, data2_y+line_offset, 102, digit_h, 0, , CLR_PANEL
  DrawSign PANEL_X2+15, data2_y+line_offset, 14, 32, "+"
  DrawSevenSegDigit PANEL_X2+54, data2_y+line_offset, digit_w, digit_h, STR$(d1), 1
  DrawSevenSegDigit PANEL_X2+75, data2_y+line_offset, digit_w, digit_h, STR$(d2), 1
  DrawSevenSegDigit PANEL_X2+96, data2_y+line_offset, digit_w, digit_h, STR$(d3), 1
  DrawSevenSegDigit PANEL_X2+117, data2_y+line_offset, digit_w, digit_h, STR$(d4), 1
END SUB

' ========================================
' Clear R1 and R2 (for alarm blinking)
' ========================================
SUB ClearRegisters12
  LOCAL row_h = 62
  LOCAL digit_h = 30
  LOCAL row3_y = PANEL_Y + 8 + row_h * 2
  LOCAL row_spacing = 56
  LOCAL line_offset = 10
  LOCAL data1_y = row3_y + 18
  LOCAL data2_y = data1_y + row_spacing
  
  BOX PANEL_X2+33, data1_y+line_offset, 102, digit_h, 0, , CLR_PANEL
  BOX PANEL_X2+33, data2_y+line_offset, 102, digit_h, 0, , CLR_PANEL
END SUB

' ========================================
' Blank Row 5 (R3) during alarm
' ========================================
SUB BlankRow5
  LOCAL row_h = 62
  LOCAL digit_h = 30
  LOCAL row3_y = PANEL_Y + 8 + row_h * 2
  LOCAL row_spacing = 56
  LOCAL line_offset = 10
  LOCAL data1_y = row3_y + 18
  LOCAL data2_y = data1_y + row_spacing
  LOCAL data3_y = data2_y + row_spacing
  
  ' Clear the entire R3 area (sign + digits)
  BOX PANEL_X2+15, data3_y+line_offset, 120, digit_h, 0, , CLR_PANEL
END SUB

' ========================================
' Draw Four Digits for Descent Display
' ========================================
SUB DrawDescentFourDigits x, y, w, h, value
  LOCAL d1 = (value \ 1000) MOD 10
  LOCAL d2 = (value \ 100) MOD 10
  LOCAL d3 = (value \ 10) MOD 10
  LOCAL d4 = value MOD 10
  
  DrawSevenSegDigit x, y, w, h, STR$(d1), 1
  DrawSevenSegDigit x+21, y, w, h, STR$(d2), 1
  DrawSevenSegDigit x+42, y, w, h, STR$(d3), 1
  DrawSevenSegDigit x+63, y, w, h, STR$(d4), 1
END SUB
' ========================================
' Update COMP ACTY indicator with blink state
' ========================================
SUB UpdateCompActy
  LOCAL row_h = 62
  
  IF comp_blink = 1 THEN
    DrawIndicator PANEL_X2+8, PANEL_Y+8, 60, row_h-4, "COMP~ACTY", CLR_WHITE
  ELSE
    DrawIndicator PANEL_X2+8, PANEL_Y+8, 60, row_h-4, "COMP~ACTY", CLR_OFF
  END IF
END SUB

' ========================================
' Dim Row 5 Display (for alarm state)
' ========================================
SUB DimRow5Display
  LOCAL row_h = 62
  LOCAL digit_w = 18
  LOCAL digit_h = 30
  LOCAL row_spacing = 56
  LOCAL line_offset = 10
  
  ' Calculate position for row 5 (data row 3)
  LOCAL row3_y = PANEL_Y + 8 + row_h * 2
  LOCAL data1_y = row3_y + 18
  LOCAL data2_y = data1_y + row_spacing
  LOCAL data3_y = data2_y + row_spacing
  
  ' Clear the area
  BOX PANEL_X2+15, data3_y+line_offset, 120, digit_h, 0, , CLR_PANEL
  
  ' Draw blank sign and unlit digits
  DrawSign PANEL_X2+15, data3_y+line_offset, 14, 32, ""
  DrawSevenSegDigit PANEL_X2+33, data3_y+line_offset, digit_w, digit_h, "8", 0
  DrawSevenSegDigit PANEL_X2+54, data3_y+line_offset, digit_w, digit_h, "8", 0
  DrawSevenSegDigit PANEL_X2+75, data3_y+line_offset, digit_w, digit_h, "8", 0
  DrawSevenSegDigit PANEL_X2+96, data3_y+line_offset, digit_w, digit_h, "8", 0
  DrawSevenSegDigit PANEL_X2+117, data3_y+line_offset, digit_w, digit_h, "8", 0
END SUB

' ========================================
' Update Row 5 Display (restore after alarm)
' ========================================
SUB UpdateRow5Display
  LOCAL row_h = 62
  LOCAL digit_w = 18
  LOCAL digit_h = 30
  LOCAL row_spacing = 56
  LOCAL line_offset = 10
  
  ' Calculate position for row 5 (data row 3)
  LOCAL row3_y = PANEL_Y + 8 + row_h * 2
  LOCAL data1_y = row3_y + 18
  LOCAL data2_y = data1_y + row_spacing
  LOCAL data3_y = data2_y + row_spacing
  
  ' Clear the area
  BOX PANEL_X2+15, data3_y+line_offset, 120, digit_h, 0, , CLR_PANEL
  
  ' For now, just clear it - specific modes will update as needed
  DrawSign PANEL_X2+15, data3_y+line_offset, 14, 32, ""
  DrawSevenSegDigit PANEL_X2+33, data3_y+line_offset, digit_w, digit_h, " ", 0
  DrawSevenSegDigit PANEL_X2+54, data3_y+line_offset, digit_w, digit_h, " ", 0
  DrawSevenSegDigit PANEL_X2+75, data3_y+line_offset, digit_w, digit_h, " ", 0
  DrawSevenSegDigit PANEL_X2+96, data3_y+line_offset, digit_w, digit_h, " ", 0
  DrawSevenSegDigit PANEL_X2+117, data3_y+line_offset, digit_w, digit_h, " ", 0
END SUB