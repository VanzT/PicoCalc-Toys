' ==============================================
' PicoMite / PicoCalc System Status Dashboard
' Green-on-black, bordered, grouped readouts
' ==============================================

OPTION EXPLICIT

' ---------- colors ----------
CONST COL_BG = RGB(0,0,0)
CONST COL_FG = RGB(0,255,0)
CONST COL_GRID = RGB(0,100,0)

' ---------- layout ----------
CONST PAD = 8
CONST LABEL_X = 16
CONST VALUE_X = 170
CONST ROW_GAP = 2
CONST SECTION_GAP = 6

' ---------- helpers ----------
FUNCTION STRNUM$(x)
  ' STR$ adds a leading space for positives; remove it if present
  LOCAL t$
  t$ = STR$(x)
  IF LEFT$(t$,1) = " " THEN t$ = MID$(t$,2)
  STRNUM$ = t$
END FUNCTION

FUNCTION OneDec$(x)
  LOCAL n
  n = INT(x * 10 + 0.5) / 10
  OneDec$ = STRNUM$(n)
END FUNCTION

FUNCTION FormatBytes$(b!)
  LOCAL val!, unit$
  IF b! < 1000 THEN
    val! = b!           : unit$ = " B"
  ELSEIF b! < 1000^2 THEN
    val! = b! / 1000    : unit$ = " KB"
  ELSEIF b! < 1000^3 THEN
    val! = b! / 1000^2  : unit$ = " MB"
  ELSE
    val! = b! / 1000^3  : unit$ = " GB"
  ENDIF
  FormatBytes$ = STRNUM$(INT(val! * 100 + 0.5) / 100) + " " + unit$
END FUNCTION



FUNCTION FormatUptime$(uptime!)
  LOCAL totalsecs%, hh%, mm%, ss%
  totalsecs% = INT(uptime!)
  hh% = totalsecs% \ 3600
  mm% = (totalsecs% MOD 3600) \ 60
  ss% = totalsecs% MOD 60
  FormatUptime$ = STRNUM$(hh%) + " hrs. " + STRNUM$(mm%) + " min. "
END FUNCTION

FUNCTION HumanIP$(ip$)
  IF ip$ = "" OR ip$ = "0.0.0.0" THEN
    HumanIP$ = "No IP assigned"
  ELSE
    HumanIP$ = ip$
  ENDIF
END FUNCTION

FUNCTION HumanWiFi$(s$)
  LOCAL code%
  IF s$ = "" THEN
    ON ERROR SKIP 1 : code% = MM.INFO(WIFI STATUS) : ON ERROR ABORT
    SELECT CASE code%
      CASE 0  : HumanWiFi$ = "Wi-Fi down"
      CASE 1  : HumanWiFi$ = "Wi-Fi connected"
      CASE 2  : HumanWiFi$ = "Wi-Fi conn., no IP"
      CASE 3  : HumanWiFi$ = "Wi-Fi + IP addr"
      CASE -1 : HumanWiFi$ = "Connection failed"
      CASE -2 : HumanWiFi$ = "No SSID found"
      CASE -3 : HumanWiFi$ = "Auth failure"
      CASE ELSE : HumanWiFi$ = "Unknown"
    END SELECT
  ELSE
    HumanWiFi$ = s$
  ENDIF
END FUNCTION


FUNCTION HumanTCPIP$(s$)
  LOCAL code%
  IF s$ = "" THEN
    ' Try numeric query for WebMite/Pico W
    ON ERROR SKIP 1 : code% = MM.INFO(TCPIP STATUS) : ON ERROR ABORT
    SELECT CASE code%
      CASE 0 : HumanTCPIP$ = "Inactive"
      CASE 1 : HumanTCPIP$ = "Starting"
      CASE 2 : HumanTCPIP$ = "Connecting"
      CASE 3 : HumanTCPIP$ = "Ready"
      CASE 4 : HumanTCPIP$ = "Error"
      CASE ELSE : HumanTCPIP$ = "Unknown"
    END SELECT
  ELSE
    HumanTCPIP$ = s$
  ENDIF
END FUNCTION


SUB KV(x%, y%, label$, value$)
  PRINT @(x%, y%); label$; ":"
  PRINT @(VALUE_X, y%); value$
END SUB

SUB SectionHeader(x%, y%, title$)
  LINE x%, y%-2, MM.HRES-PAD, y%-2, 1, COL_GRID
  PRINT @(x%, y%); "["; title$; "]"
END SUB

' ---------- draw background ----------
CLS COL_BG
COLOUR COL_FG, COL_BG
' border box (outline only)
BOX 0,0,MM.HRES,MM.VRES,1,COL_FG
BOX 2,2,MM.HRES-4,MM.VRES-4,1,COL_GRID


' ---------- gather values ----------
DIM id$, plat$, ip$, wifi$, tcp$, cpus$
DIM ver!, bootcnt%, uptime!, disksz!, freespc!

' strings
id$    = MM.INFO$(ID)
plat$  = MM.INFO$(PLATFORM)
cpus$  = MM.INFO$(CPUSPEED)

' network strings (guard if networking keywords not available)
ON ERROR SKIP 1 : ip$   = MM.INFO$(IP address)   : ON ERROR ABORT
ON ERROR SKIP 1 : wifi$ = MM.INFO$(WIFI STATUS)  : ON ERROR ABORT
ON ERROR SKIP 1 : tcp$  = MM.INFO$(TCPIP STATUS) : ON ERROR ABORT

' numerics
ver!     = MM.INFO(VERSION)       ' numeric version (float)
bootcnt% = MM.INFO(BOOT COUNT)
uptime!  = MM.INFO(UPTIME)        ' seconds (float)
disksz!  = MM.INFO(DISK SIZE)     ' bytes (float ok)
freespc! = MM.INFO(FREE SPACE)    ' bytes (float ok)

' ---------- render ----------
DIM y%: y% = PAD + 6
PRINT @(LABEL_X, y%); "System Status"
y% = y% + MM.FONTHEIGHT + SECTION_GAP

' Device
SectionHeader LABEL_X, y%, "Device"
y% = y% + MM.FONTHEIGHT + ROW_GAP
KV LABEL_X, y%, "ID", id$
y% = y% + MM.FONTHEIGHT + ROW_GAP
KV LABEL_X, y%, "Platform", plat$
y% = y% + MM.FONTHEIGHT + ROW_GAP
KV LABEL_X, y%, "MMBasic Version", STRNUM$(ver!)
y% = y% + MM.FONTHEIGHT + ROW_GAP
KV LABEL_X, y%, "Boot Count", STRNUM$(bootcnt%)
y% = y% + MM.FONTHEIGHT + SECTION_GAP

' Performance
SectionHeader LABEL_X, y%, "Performance"
y% = y% + MM.FONTHEIGHT + ROW_GAP
KV LABEL_X, y%, "CPU Speed", STRNUM$(INT(VAL(cpus$)/1000000)) + " MHz"
y% = y% + MM.FONTHEIGHT + ROW_GAP
KV LABEL_X, y%, "Uptime", FormatUptime$(uptime!)
y% = y% + MM.FONTHEIGHT + SECTION_GAP

' Storage
SectionHeader LABEL_X, y%, "Storage"
y% = y% + MM.FONTHEIGHT + ROW_GAP
KV LABEL_X, y%, "Disk Size", FormatBytes$(disksz!)
y% = y% + MM.FONTHEIGHT + ROW_GAP
KV LABEL_X, y%, "Free Space", FormatBytes$(freespc!)
y% = y% + MM.FONTHEIGHT + SECTION_GAP

' Network
SectionHeader LABEL_X, y%, "Network"
y% = y% + MM.FONTHEIGHT + ROW_GAP
KV LABEL_X, y%, "IP Address", HumanIP$(ip$)
y% = y% + MM.FONTHEIGHT + ROW_GAP
KV LABEL_X, y%, "TCP/IP Status", HumanTCPIP$(tcp$)
y% = y% + MM.FONTHEIGHT + ROW_GAP
KV LABEL_X, y%, "Wi-Fi Status", HumanWiFi$(wifi$)
y% = y% + MM.FONTHEIGHT + SECTION_GAP

' bottom prompt
PRINT @(LABEL_X, MM.VRES - PAD - MM.FONTHEIGHT);
PRINT "Press any key to exit...";

' ---------- wait for key ----------
DO
  IF INKEY$ <> "" THEN EXIT DO
  PAUSE 50
LOOP
run "B:menu.bas"
END
