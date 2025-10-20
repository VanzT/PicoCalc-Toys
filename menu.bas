' Retro Menu (collision-safe, uniform speed, header battery, skip MENU.BAS)
' - Battery on top row; files start on row 1
' - A->Z sort
' - Type-on: current char WHITE, previous GREEN
' - After filename, a single WHITE underscore sweeps to right edge
' - Uses unique variable names to avoid clashes after returning from other programs

Dim file$(25)

' colors (locals to this file; not CONST to avoid clashes)
mFG%     = RGB(0,255,0)
mBG%     = RGB(0,0,0)
mHiBG%   = RGB(0,40,0)
mCurFG%  = RGB(255,255,255)

Color mFG%, mBG%
CLS

' screen geometry
scrRows% = MM.VRES \ MM.FONTHEIGHT
scrCols% = MM.HRES \ MM.FONTWIDTH
mFirstRow% = 1                 ' reserve row 0 for battery

' collect *.BAS on B:, skipping MENU.BAS
Drive "B:"
mCount% = 0
fName$ = Dir$("*.bas", FILE)
Do While fName$ <> "" And mCount% < 25
  If UCase$(fName$) <> "MENU.BAS" Then
    mCount% = mCount% + 1
    file$(mCount%) = fName$
  EndIf
  fName$ = Dir$()
Loop

If mCount% = 0 Then
  Gosub DrawBattery
  Print @(0, mFirstRow% * MM.FONTHEIGHT) "No .BAS files found on B:"
  End
EndIf

' cap to visible rows (header uses 1 row)
maxVisible% = scrRows% - 1
If mCount% > maxVisible% Then mCount% = maxVisible%

' sort A->Z case-insensitive
For sA% = 1 To mCount% - 1
  For sB% = sA% + 1 To mCount%
    If UCase$(file$(sB%)) < UCase$(file$(sA%)) Then
      t$ = file$(sA%)
      file$(sA%) = file$(sB%)
      file$(sB%) = t$
    EndIf
  Next sB%
Next sA%

' timing: 0 = as fast as possible, ~2000 for ~2s total
TOTAL_MS% = 1000
stepsTotal% = mCount% * scrCols%
If stepsTotal% < 1 Then stepsTotal% = 1
If TOTAL_MS% <= 0 Then
  charDelay% = 0
Else
  charDelay% = TOTAL_MS% \ stepsTotal%
  If charDelay% < 1 Then charDelay% = 1
EndIf

Gosub DrawBattery

' animate each filename (starts on row 1)
For mLine% = 1 To mCount%
  nm$ = file$(mLine%)
  mY% = (mFirstRow% + (mLine% - 1)) * MM.FONTHEIGHT
  showmax% = Len(nm$)
  If showmax% > scrCols% Then showmax% = scrCols%

  Color mFG%, mBG%
  Print @(0, mY%) Space$(scrCols%)

  ' type-on: previous char green, current char white
  For j% = 1 To showmax%
    If j% > 1 Then
      Color mFG%, mBG%
      Print @((j% - 2) * MM.FONTWIDTH, mY%) Mid$(nm$, j% - 1, 1)
    EndIf
    Color mCurFG%, mBG%
    Print @((j% - 1) * MM.FONTWIDTH, mY%) Mid$(nm$, j%, 1)
    If charDelay% > 0 Then Pause charDelay%
  Next j%

  ' finalize last typed char to green
  If showmax% > 0 Then
    Color mFG%, mBG%
    Print @((showmax% - 1) * MM.FONTWIDTH, mY%) Mid$(nm$, showmax%, 1)
  EndIf

  ' underscore tail to right edge
  undXPrev% = -1
  If showmax% < scrCols% Then
    For ux% = showmax% + 1 To scrCols%
      If undXPrev% >= 0 Then
        Color mFG%, mBG%
        Print @(undXPrev% * MM.FONTWIDTH, mY%) " "
      EndIf
      Color mCurFG%, mBG%
      Print @((ux% - 1) * MM.FONTWIDTH, mY%) "_"
      If charDelay% > 0 Then Pause charDelay%
      undXPrev% = ux% - 1
    Next ux%
  EndIf

  If undXPrev% >= 0 Then
    Color mFG%, mBG%
    Print @(undXPrev% * MM.FONTWIDTH, mY%) " "
  EndIf

  Gosub DrawBattery
  If charDelay% > 0 Then Pause charDelay%
Next mLine%

' initial highlight
mSel% = 1
mSelPrev% = 1
Gosub DrawItemUnselected
Gosub DrawItemSelected
Gosub DrawBattery

' main loop
mainLoop:
  key$ = Inkey$
  If key$ = "" Then GoTo mainLoop

  If Asc(key$) = 129 Then mSelPrev% = mSel%: mSel% = mSel% + 1   ' down
  If Asc(key$) = 128 Then mSelPrev% = mSel%: mSel% = mSel% - 1   ' up

  If mSel% < 1 Then mSel% = mCount%
  If mSel% > mCount% Then mSel% = 1

  If Asc(key$) = 13 Then GoTo selectedFile  ' enter

  Gosub DrawItemUnselected
  Gosub DrawItemSelected
  Gosub DrawBattery
  GoTo mainLoop

selectedFile:
  Color mFG%, mBG%
  CLS
  Run file$(mSel%)

' draw helpers
DrawItemUnselected:
  Color mFG%, mBG%
  mY% = (mFirstRow% + (mSelPrev% - 1)) * MM.FONTHEIGHT
  Print @(0, mY%) Space$(scrCols%)
  Print @(0, mY%) file$(mSelPrev%)
Return

DrawItemSelected:
  Color mFG%, mHiBG%
  mY% = (mFirstRow% + (mSel% - 1)) * MM.FONTHEIGHT
  Print @(0, mY%) Space$(scrCols%)
  Print @(0, mY%) file$(mSel%)
Return

' battery helper
DrawBattery:
  ' compute "NN%"
  Local p%, s$, batt$
  p% = MM.INFO(BATTERY)
  If p% < 0 Or p% > 100 Then
    batt$ = "??%"
  Else
    s$ = STR$(p%)
    If Left$(s$,1) = " " Then s$ = Mid$(s$,2)
    batt$ = s$ + "%"
  EndIf
  Local bx%
  bx% = MM.HRES - Len(batt$) * MM.FONTWIDTH
  If bx% < 0 Then bx% = 0
  Color mFG%, mBG%
  Print @(bx%, 0) batt$
Return
