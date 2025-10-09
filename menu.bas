' Retro Menu (uniform speed, header battery, skip MENU.BAS)
' - Battery on top row; files start from row 2
' - A->Z sort
' - Type-on: current char WHITE, previous GREEN
' - After filename finishes, a single WHITE underscore sweeps to right edge
' - Skips listing MENU.BAS (case-insensitive)

Dim file$(25)

' colors
CONST FG%        = RGB(0,255,0)
CONST BG%        = RGB(0,0,0)
CONST HILITE_BG% = RGB(0,40,0)
CONST CURSOR_FG% = RGB(255,255,255)

Color FG%, BG%
CLS

' screen geometry
rows% = MM.VRES \ MM.FONTHEIGHT
cols% = MM.HRES \ MM.FONTWIDTH
firstFileRow% = 1

' collect *.BAS on B:, skipping MENU.BAS
Drive "B:"
nFiles% = 0
f$ = Dir$("*.bas", FILE)
Do While f$ <> "" And nFiles% < 25
  If UCase$(f$) <> "MENU.BAS" Then
    nFiles% = nFiles% + 1
    file$(nFiles%) = f$
  EndIf
  f$ = Dir$()
Loop

If nFiles% = 0 Then
  Gosub DrawBattery
  Print @(0, firstFileRow% * MM.FONTHEIGHT) "No .BAS files found on B:"
  End
EndIf

' cap to visible rows (header uses 1 row)
maxVisible% = rows% - 1
If nFiles% > maxVisible% Then nFiles% = maxVisible%

' sort A->Z case-insensitive
For sA% = 1 To nFiles% - 1
  For sB% = sA% + 1 To nFiles%
    If UCase$(file$(sB%)) < UCase$(file$(sA%)) Then
      tmp$ = file$(sA%)
      file$(sA%) = file$(sB%)
      file$(sB%) = tmp$
    EndIf
  Next sB%
Next sA%

' timing: 0 = as fast as possible, ~2000 for ~2s total
TOTAL_MS% = 2000
stepsTotal% = nFiles% * cols%
If stepsTotal% < 1 Then stepsTotal% = 1
If TOTAL_MS% <= 0 Then
  charDelay% = 0
Else
  charDelay% = TOTAL_MS% \ stepsTotal%
  If charDelay% < 1 Then charDelay% = 1
EndIf

Gosub DrawBattery

' animate each filename (starts on row 1)
For iLine% = 1 To nFiles%
  name$ = file$(iLine%)
  y% = (firstFileRow% + (iLine% - 1)) * MM.FONTHEIGHT
  showmax% = Len(name$)
  If showmax% > cols% Then showmax% = cols%

  Color FG%, BG%
  Print @(0, y%) Space$(cols%)

  ' type-on: previous char green, current char white
  For jdx% = 1 To showmax%
    If jdx% > 1 Then
      Color FG%, BG%
      Print @((jdx% - 2) * MM.FONTWIDTH, y%) Mid$(name$, jdx% - 1, 1)
    EndIf
    Color CURSOR_FG%, BG%
    Print @((jdx% - 1) * MM.FONTWIDTH, y%) Mid$(name$, jdx%, 1)
    If charDelay% > 0 Then Pause charDelay%
  Next jdx%

  ' finalize last char to green
  If showmax% > 0 Then
    Color FG%, BG%
    Print @((showmax% - 1) * MM.FONTWIDTH, y%) Mid$(name$, showmax%, 1)
  EndIf

  ' underscore tail to right edge
  prevUndX% = -1
  If showmax% < cols% Then
    For ux% = showmax% + 1 To cols%
      If prevUndX% >= 0 Then
        Color FG%, BG%
        Print @(prevUndX% * MM.FONTWIDTH, y%) " "
      EndIf
      Color CURSOR_FG%, BG%
      Print @((ux% - 1) * MM.FONTWIDTH, y%) "_"
      If charDelay% > 0 Then Pause charDelay%
      prevUndX% = ux% - 1
    Next ux%
  EndIf

  If prevUndX% >= 0 Then
    Color FG%, BG%
    Print @(prevUndX% * MM.FONTWIDTH, y%) " "
  EndIf

  Gosub DrawBattery
  If charDelay% > 0 Then Pause charDelay%
Next iLine%

' initial highlight
iSel% = 1
iPrev% = 1
Gosub DrawItemUnselected
Gosub DrawItemSelected
Gosub DrawBattery

' main loop
mainLoop:
  k$ = Inkey$
  If k$ = "" Then GoTo mainLoop

  If Asc(k$) = 129 Then iPrev% = iSel%: iSel% = iSel% + 1
  If Asc(k$) = 128 Then iPrev% = iSel%: iSel% = iSel% - 1

  If iSel% < 1 Then iSel% = nFiles%
  If iSel% > nFiles% Then iSel% = 1

  If Asc(k$) = 13 Then GoTo selectedFile

  Gosub DrawItemUnselected
  Gosub DrawItemSelected
  Gosub DrawBattery
  GoTo mainLoop

selectedFile:
  Color FG%, BG%
  CLS
  Run file$(iSel%)

' draw helpers
DrawItemUnselected:
  Color FG%, BG%
  y% = (firstFileRow% + (iPrev% - 1)) * MM.FONTHEIGHT
  Print @(0, y%) Space$(cols%)
  Print @(0, y%) file$(iPrev%)
Return

DrawItemSelected:
  Color FG%, HILITE_BG%
  y% = (firstFileRow% + (iSel% - 1)) * MM.FONTHEIGHT
  Print @(0, y%) Space$(cols%)
  Print @(0, y%) file$(iSel%)
Return

' battery helpers
DrawBattery:
  Color FG%, BG%
  batt$ = BatteryStr$()
  bx% = MM.HRES - Len(batt$) * MM.FONTWIDTH
  If bx% < 0 Then bx% = 0
  Print @(bx%, 0) batt$
Return

Function BatteryStr$()
  Local p%, s$
  p% = MM.INFO(BATTERY)
  If p% < 0 Or p% > 100 Then
    BatteryStr$ = "??%"
    Exit Function
  EndIf
  s$ = STR$(p%)
  If Left$(s$,1) = " " Then s$ = Mid$(s$,2)
  BatteryStr$ = s$ + "%"
End Function
