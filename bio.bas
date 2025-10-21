' =======================================================
' Biorhythm Plotter (Y2K-safe) for MMBasic / PicoMite 320x320
' Version 1.14 - fixed Y mapping + snug frame, pixel text
' =======================================================

OPTION EXPLICIT
OPTION BASE 1

' -------------------- constants --------------------
CONST WIDTH = 320
CONST HEIGHT = 320

' Left/right margins (top/bottom handled by header/legend bands)
CONST MARGIN_L = 6
CONST MARGIN_R = 14

CONST BORDER_BOTTOM_LIFT = 12   ' pixels to raise the bottom border

' Colors
CONST COL_BG   = RGB(0,0,0)
CONST COL_AXES = RGB(180,180,180)
CONST COL_GRID = RGB(70,70,70)
CONST COL_TEXT = RGB(220,220,220)
CONST COL_P23  = RGB(0,220,0)
CONST COL_P28  = RGB(220,160,0)
CONST COL_P33  = RGB(0,160,240)
CONST COL_ZERO = RGB(120,120,120)

' Cycles
CONST P23 = 23.0
CONST P28 = 28.0
CONST P33 = 33.0

' -------------------- globals --------------------
DIM g_birth_y%, g_birth_m%, g_birth_d%
DIM g_target_y%, g_target_m%, g_target_d%
DIM g_days0
DIM p_y%, p_m%, p_d%
DIM k$

' Layout globals (computed each frame)
DIM g_plot_y0%, g_plot_y1%     ' base plot band (fixed)
DIM g_header_h%, g_legend_h%   ' reserved header/legend heights
DIM g_line_h%                  ' text line height (font-dependent)

' Frame that hugs data (computed each frame)
DIM g_frame_y0%, g_frame_y1%

GOTO Main

' ==================== helpers ====================

FUNCTION TrimLeadSpace$(s$)
  IF LEN(s$) > 0 AND LEFT$(s$,1) = " " THEN
    TrimLeadSpace$ = MID$(s$,2)
  ELSE
    TrimLeadSpace$ = s$
  END IF
END FUNCTION

FUNCTION Trim2$(t$)
  LOCAL s$
  s$ = t$
  DO WHILE LEN(s$) > 0 AND RIGHT$(s$,1) = " "
    s$ = LEFT$(s$, LEN(s$) - 1)
  LOOP
  DO WHILE LEN(s$) > 0 AND LEFT$(s$,1) = " "
    s$ = MID$(s$, 2)
  LOOP
  Trim2$ = s$
END FUNCTION

FUNCTION Pad2$(n%)
  LOCAL s$
  s$ = TrimLeadSpace$(STR$(n%))
  IF LEN(s$) = 1 THEN s$ = "0" + s$
  Pad2$ = s$
END FUNCTION

FUNCTION FmtDate$(y%, m%, d%)
  LOCAL ys$, ms$, ds$
  ys$ = TrimLeadSpace$(STR$(y%))
  ms$ = Pad2$(m%)
  ds$ = Pad2$(d%)
  FmtDate$ = ys$ + "-" + ms$ + "-" + ds$
END FUNCTION

FUNCTION Pct1$(x!)
  LOCAL p!, s$
  p! = INT(x! * 1000.0 + SGN(x!) * 0.5) / 10.0
  s$ = TrimLeadSpace$(STR$(p!))
  Pct1$ = s$
END FUNCTION

FUNCTION DayToX(d%)
  LOCAL x0%, x1%
  x0% = MARGIN_L
  x1% = WIDTH - MARGIN_R
  DayToX = x0% + (d% + 15) * (x1% - x0%) \ 30
END FUNCTION

' Map y in [-1..+1] into the current plot band pixels
FUNCTION YtoPix(y!)
  YtoPix = g_plot_y0% + INT((1.0 - (y! + 1.0) / 2.0) * (g_plot_y1% - g_plot_y0%) + 0.5)
END FUNCTION

FUNCTION JDN(y%, m%, d%)
  LOCAL a%, y2, m2, j
  a% = (14 - m%) \ 12
  y2 = y% + 4800 - a%
  m2 = m% + 12 * a% - 3
  j  = d% + ((153 * m2 + 2) \ 5) + 365 * y2 + (y2 \ 4) - (y2 \ 100) + (y2 \ 400) - 32045
  JDN = j
END FUNCTION

SUB JDN_to_YMD(j, y%, m%, d%)
  LOCAL a, b, c, d1, e, m1
  a  = j + 32044
  b  = (4 * a + 3) \ 146097
  c  = a - (146097 * b) \ 4
  d1 = (4 * c + 3) \ 1461
  e  = c - (1461 * d1) \ 4
  m1 = (5 * e + 2) \ 153
  d% = e - (153 * m1 + 2) \ 5 + 1
  m% = m1 + 3 - 12 * (m1 \ 10)
  y% = 100 * b + d1 - 4800 + (m1 \ 10)
END SUB

FUNCTION ParseDateToYMD(s$)
  LOCAL a$, b$, c$, sep$
  LOCAL p1%, p2%
  LOCAL j, ry%, rm%, rd%
  LOCAL aa%, y2, m2

  s$ = Trim2$(s$)

  IF INSTR(s$, "-") > 0 THEN
    sep$ = "-"
  ELSEIF INSTR(s$, "/") > 0 THEN
    sep$ = "/"
  ELSE
    ParseDateToYMD = 0
    EXIT FUNCTION
  END IF

  p1% = INSTR(s$, sep$)
  p2% = INSTR(p1% + 1, s$, sep$)
  IF p1% = 0 OR p2% = 0 THEN
    ParseDateToYMD = 0
    EXIT FUNCTION
  END IF

  a$ = LEFT$(s$, p1% - 1)
  b$ = MID$(s$, p1% + 1, p2% - p1% - 1)
  c$ = MID$(s$, p2% + 1)

  p_y% = VAL(a$)
  p_m% = VAL(b$)
  p_d% = VAL(c$)

  IF p_y% < 1583 OR p_m% < 1 OR p_m% > 12 OR p_d% < 1 OR p_d% > 31 THEN
    ParseDateToYMD = 0
    EXIT FUNCTION
  END IF

  SELECT CASE p_m%
    CASE 4, 6, 9, 11
      IF p_d% > 30 THEN ParseDateToYMD = 0 : EXIT FUNCTION
    CASE 2
      IF p_d% > 29 THEN ParseDateToYMD = 0 : EXIT FUNCTION
  END SELECT

  aa% = (14 - p_m%) \ 12
  y2  = p_y% + 4800 - aa%
  m2  = p_m% + 12 * aa% - 3
  j   = p_d% + ((153 * m2 + 2) \ 5) + 365 * y2 + (y2 \ 4) - (y2 \ 100) + (y2 \ 400) - 32045

  JDN_to_YMD j, ry%, rm%, rd%
  IF ry% <> p_y% OR rm% <> p_m% OR rd% <> p_d% THEN ParseDateToYMD = 0 : EXIT FUNCTION

  ParseDateToYMD = 1
END FUNCTION

' -------------------- layout --------------------
SUB ComputeLayout
  FONT 1
  g_line_h%  = 8

  ' header: 1 line + margin
  g_header_h% = g_line_h% + 4

  ' legend: 3 lines + generous padding
  g_legend_h% = 3 * g_line_h% + 18   ' ~42 px total reserved

  ' plot band between them, leaving a full gap above legend
  g_plot_y0% = g_header_h% + 4
  g_plot_y1% = HEIGHT - g_legend_h% - 10
  IF g_plot_y1% < g_plot_y0% + 40 THEN g_plot_y1% = g_plot_y0% + 40
END SUB




' Frame that hugs the actually plotted pixels (with a tiny pad)
SUB ComputeFrameFromData
  LOCAL d%, y%, minPix%, maxPix%, pad%
  minPix% =  9999
  maxPix% = -9999
  FOR d% = -15 TO 15
    y% = YtoPix(SIN(2.0 * PI * ((g_days0 + d%) / P23))) : IF y% < minPix% THEN minPix% = y% : IF y% > maxPix% THEN maxPix% = y%
    y% = YtoPix(SIN(2.0 * PI * ((g_days0 + d%) / P28))) : IF y% < minPix% THEN minPix% = y% : IF y% > maxPix% THEN maxPix% = y%
    y% = YtoPix(SIN(2.0 * PI * ((g_days0 + d%) / P33))) : IF y% < minPix% THEN minPix% = y% : IF y% > maxPix% THEN maxPix% = y%
  NEXT d%
  pad% = 2
  g_frame_y0% = minPix% - pad% : IF g_frame_y0% < g_plot_y0% THEN g_frame_y0% = g_plot_y0%
  g_frame_y1% = maxPix% + pad% : IF g_frame_y1% > g_plot_y1% THEN g_frame_y1% = g_plot_y1%
  IF g_frame_y1% < g_frame_y0% + 10 THEN g_frame_y1% = g_frame_y0% + 10
END SUB

SUB DoCalcDays0
  g_days0 = JDN(g_target_y%, g_target_m%, g_target_d%) - JDN(g_birth_y%, g_birth_m%, g_birth_d%)
END SUB

SUB ShiftTargetByDays(n%)
  LOCAL j, y%, m%, d%
  j = JDN(g_target_y%, g_target_m%, g_target_d%) + n%
  JDN_to_YMD j, y%, m%, d%
  g_target_y% = y%
  g_target_m% = m%
  g_target_d% = d%
END SUB

SUB PlotOne(period!, col%)
  LOCAL d%, x_prev%, y_prev%, x%, y%
  COLOR col%
  FOR d% = -15 TO 15
    x% = DayToX(d%)
    y% = YtoPix(SIN(2.0 * PI * ((g_days0 + d%) / period!)))
    IF d% > -15 THEN LINE x_prev%, y_prev%, x%, y%
    x_prev% = x%
    y_prev% = y%
  NEXT d%
END SUB

SUB PlotCurves
  PlotOne P23, COL_P23
  PlotOne P28, COL_P28
  PlotOne P33, COL_P33
END SUB

SUB DrawFrame
  LOCAL x0%, x1%, d%, x%, gy!, y%, y1frame%
  x0% = MARGIN_L
  x1% = WIDTH - MARGIN_R
  y1frame% = g_plot_y1% - BORDER_BOTTOM_LIFT
  IF y1frame% < g_plot_y0% + 20 THEN y1frame% = g_plot_y0% + 20

  ' vertical grid (skip outer edges)
  FOR d% = -15 TO 15 STEP 5
    x% = DayToX(d%)
    IF x% <> x0% AND x% <> x1% THEN
      IF d% = 0 THEN COLOR COL_AXES ELSE COLOR COL_GRID
      LINE x%, g_plot_y0%, x%, y1frame%
    END IF
  NEXT d%

  ' horizontal zero line (only if inside lifted frame)
  y% = YtoPix(0.0)
  IF y% >= g_plot_y0% AND y% <= y1frame% THEN
    COLOR COL_ZERO
    LINE x0%, y%, x1%, y%
  END IF

  ' frame on top, using lifted bottom
  COLOR COL_AXES
  BOX x0%, g_plot_y0%, x1%, y1frame%
END SUB



SUB DrawLegendAndHeader
  LOCAL x0%, x1%
  LOCAL v23!, v28!, v33!
  LOCAL yHeader%, yLegendTop%
  LOCAL xZero%, y1frame%

  x0% = MARGIN_L
  x1% = WIDTH - MARGIN_R

  ' ---- Header (single line) ----
  FONT 1 : COLOR COL_TEXT
  yHeader% = 2
  TEXT x0%, yHeader%, "Birth " + FmtDate$(g_birth_y%, g_birth_m%, g_birth_d%) + "   Target " + FmtDate$(g_target_y%, g_target_m%, g_target_d%)

  ' ---- Current values ----
  v23! = SIN(2.0 * PI * (g_days0 / P23))
  v28! = SIN(2.0 * PI * (g_days0 / P28))
  v33! = SIN(2.0 * PI * (g_days0 / P33))

  ' ---- Use lifted bottom border for alignment ----
  y1frame% = g_plot_y1% - BORDER_BOTTOM_LIFT
  IF y1frame% < g_plot_y0% + 20 THEN y1frame% = g_plot_y0% + 20

  ' ---- Vertical centerline inside lifted frame ----
  COLOR COL_AXES
  xZero% = DayToX(0)
  LINE xZero%, g_plot_y0%, xZero%, y1frame%

  ' ---- Legend: start below lifted border with clean spacing ----
  yLegendTop% = y1frame% + 18          ' gap under border
  COLOR COL_P23
  TEXT x0%, yLegendTop% + 0 * (g_line_h% + 2), "Physical (23): "  + Pct1$(v23!) + "%"
  COLOR COL_P28
  TEXT x0%, yLegendTop% + 1 * (g_line_h% + 3), "Emotional(28): " + Pct1$(v28!) + "%"
  COLOR COL_P33
  TEXT x0%, yLegendTop% + 2 * (g_line_h% + 3), "Intellect(33): " + Pct1$(v33!) + "%"
END SUB


SUB DrawAll
  CLS
  ComputeLayout
  'ComputeFrameFromData
  DrawFrame
  PlotCurves
  DrawLegendAndHeader
END SUB

' ==================== MAIN ====================
Main:
CLS
COLOR COL_TEXT
PRINT "Biorhythm Plotter"

DIM ok%, tmp$, in$

PRINT "Enter birth date (YYYY-MM-DD): "
LINE INPUT tmp$
ok% = ParseDateToYMD(tmp$)
IF ok% = 0 THEN PRINT "Invalid birth date.": END
g_birth_y% = p_y% : g_birth_m% = p_m% : g_birth_d% = p_d%

PRINT "Enter target date (YYYY-MM-DD) or blank for today: "
LINE INPUT in$
IF Trim2$(in$) = "" THEN in$ = DATE$

ok% = ParseDateToYMD(in$)
IF ok% = 0 THEN PRINT "Invalid target date.": END
g_target_y% = p_y% : g_target_m% = p_m% : g_target_d% = p_d%

DoCalcDays0
DrawAll

DO
  k$ = INKEY$

  SELECT CASE k$
    CASE "q", "Q"
      RUN "menu.bas"

    CASE CHR$(130)   ' Left arrow
      ShiftTargetByDays -1
      DoCalcDays0
      DrawAll

    CASE CHR$(131)   ' Right arrow
      ShiftTargetByDays 1
      DoCalcDays0
      DrawAll
  END SELECT

  PAUSE 10
LOOP
END


