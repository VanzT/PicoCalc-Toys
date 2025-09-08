' UDP Chat (clean discovery, dual broadcast, auto-ACK) • WebMite / PicoCalc
' Before first run (once per device at prompt):
'   OPTION WIFI "CHATNET","pass123"
'   OPTION UDP SERVER PORT 6000
'
' Load this SAME file on BOTH devices and RUN.

OPTION BASE 1
OPTION EXPLICIT

' ---- Config ----
CONST PORT%          = 6000
CONST PROMPT$        = "> "
CONST HELLO_TAG$     = "[HELLO]"
CONST HELLO_RETRY_MS = 1000

' ---- State ----
DIM buf$, k$, myIP$, peerIP$, bcast$, bcast255$
DIM havePeer%: havePeer% = 0
DIM newMsgReady%, lastFrom$, lastMsg$
DIM lastHello!: lastHello! = 0

' ---- Setup ----
CLS
PRINT "WebMite UDP Chat"
PRINT STRING$(30,"-")

' Wait for Wi-Fi (after OPTION WIFI)
PRINT "Waiting for Wi-Fi..."
DO WHILE MM.INFO(IP ADDRESS) = "0.0.0.0": PAUSE 100: LOOP
myIP$     = MM.INFO(IP ADDRESS)
bcast$    = BroadcastIP$()        ' e.g., 192.168.4.255
bcast255$ = "255.255.255.255"

PRINT "My IP: "; myIP$
PRINT "Broadcasts: "; bcast$; " and "; bcast255$
PRINT "UDP port: "; STR$(PORT%)
PRINT STRING$(30,"-")

WEB UDP INTERRUPT OnUDP

' Start discovery (dual broadcast)
lastHello! = TIMER
SendHello myIP$

PRINT PROMPT$;
DO
  ' Retry discovery until we learn a peer
  IF havePeer% = 0 THEN
    IF TIMER - lastHello! > HELLO_RETRY_MS THEN
      lastHello! = TIMER
      SendHello myIP$
    END IF
  END IF

  ' Keyboard input
  k$ = INKEY$
  IF k$ <> "" THEN
    SELECT CASE ASC(k$)
      CASE 27       ' ESC
        PRINT : PRINT "Bye.": END

      CASE 8        ' Backspace
        IF LEN(buf$) > 0 THEN
          buf$ = LEFT$(buf$, LEN(buf$)-1)
          PRINT CHR$(8);" ";CHR$(8);
        END IF

      CASE 13,10    ' Enter -> send
        IF LEN(buf$) > 0 THEN
          IF havePeer% THEN
            WEB UDP SEND peerIP$, PORT%, buf$
          ELSE
            ' still discovering: send to both broadcast addrs
            WEB UDP SEND bcast$,    PORT%, buf$
            WEB UDP SEND bcast255$, PORT%, buf$
          END IF
          PRINT : PRINT "Sent: "; buf$
        ELSE
          PRINT
        END IF
        buf$ = ""
        PRINT PROMPT$;

      CASE ELSE     ' printable ASCII
        IF ASC(k$) >= 32 AND ASC(k$) <= 126 THEN
          buf$ = buf$ + k$
          PRINT k$;
        END IF
    END SELECT
  END IF

  ' Show any received NON-HELLO datagrams
  IF newMsgReady% THEN
    newMsgReady% = 0
    PRINT
    PRINT lastMsg$
    PRINT PROMPT$; buf$;
  END IF

  PAUSE 5
LOOP

' ---- Subs/Functions ----

' Send dual-broadcast HELLO with our IP embedded
SUB SendHello(me$)
  WEB UDP SEND bcast$,    PORT%, HELLO_TAG$ + " " + me$
  WEB UDP SEND bcast255$, PORT%, HELLO_TAG$ + " " + me$
END SUB

' Compute subnet broadcast (x.y.z.255) from our current IP
FUNCTION BroadcastIP$()
  LOCAL ip$, i%
  ip$ = MM.INFO(IP ADDRESS)
  FOR i% = LEN(ip$) TO 1 STEP -1
    IF MID$(ip$, i%, 1) = "." THEN EXIT FOR
  NEXT i%
  BroadcastIP$ = LEFT$(ip$, i% - 1) + ".255"
END FUNCTION

' UDP receive interrupt:
' - Consume HELLOs for discovery (and ACK them via unicast)
' - Surface ONLY non-HELLO messages to UI
SUB OnUDP
  LOCAL a$, m$, isHello%

  a$ = MM.ADDRESS$
  m$ = MM.MESSAGE$
  isHello% = (LEFT$(m$, LEN(HELLO_TAG$)) = HELLO_TAG$)

  ' Ignore our own traffic
  IF a$ = MM.INFO(IP ADDRESS) THEN EXIT SUB

  ' If HELLO, ACK and learn peer; do not surface to UI
  IF isHello% THEN
    ' Unicast an ACK (HELLO with our IP) back to sender
    WEB UDP SEND a$, PORT%, HELLO_TAG$ + " " + MM.INFO(IP ADDRESS)

    ' Learn peer if not yet set
    IF havePeer% = 0 THEN
      peerIP$   = a$
      havePeer% = 1
    END IF

    EXIT SUB
  END IF

  ' Non-HELLO payload -> surface to UI
  lastFrom$     = a$
  lastMsg$      = m$
  newMsgReady%  = 1
END SUB
