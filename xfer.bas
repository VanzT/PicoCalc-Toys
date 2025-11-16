' ===========================================================================
' PicoCalc UDP Discovery + File Transfer (stop-and-wait, hex-encoded)
' One program runs on both devices. Either side can send or receive.
' ===========================================================================
OPTION EXPLICIT
OPTION BASE 1

' -------------------- configuration --------------------
CONST UDP_DISC_PORT%   = 6000           ' discovery + protocol port
CONST HELLO_REPEAT_CT% = 6
CONST HELLO_INTERVAL_MS% = 300
CONST QUEUE_MAX%       = 16
CONST CHUNK_BYTES%     = 100            ' raw bytes pre-hex; 512 -> 1024 hex chars
CONST SEND_RETRY_MAX%  = 10
CONST ACK_TIMEOUT_MS%  = 1200           ' per-chunk wait before retry
CONST GLOBAL_POLL_MS%  = 10
CONST MIN_MENU_REDRAW_MS% = 250  ' debounce window for redraws

' -------------------- LED configuration --------------------
CONST LED_COUNT% = 8
CONST LED_GPIO%  = 28
CONST LED_FLASH_MS% = 20        ' duration of each flash


' -------------------- globals (system/network) --------------------
DIM g_udp_opened%
DIM g_key$
DIM g_last_hello!
DIM g_peer_known%
DIM g_my_ip$
DIM g_broadcast_ip$
DIM g_device_name$

' -------------------- inbound message queue (ISR -> main) --------------------
DIM q_cmd$(QUEUE_MAX%), q_arg$(QUEUE_MAX%), q_ip$(QUEUE_MAX%)
DIM q_head%, q_tail%


' -------------------- deferred actions requested by main --------------------
DIM pending_reply_needed%
DIM pending_reply_ip$, pending_reply_name$

' -------------------- peer book-keeping --------------------
DIM g_peer_ip$, g_peer_name$

' -------------------- sender state --------------------
DIM s_active%                      ' 0 idle, 1 sending
DIM s_file_name_full$
DIM s_file_basename$
DIM s_file_size%
DIM s_file_handle%
DIM s_total_chunks%
DIM s_next_seq%
DIM s_sent_sum%                   ' 16-bit rolling sum
DIM s_retry_count%
DIM s_waiting_ack_seq%
DIM s_last_send_ts!

' -------------------- receiver state --------------------
DIM r_active%
DIM r_expect_name$
DIM r_file_handle%
DIM r_target_path$
DIM r_total_size%
DIM r_recv_sum%
DIM r_expected_seq%
DIM r_total_chunks_announced%
DIM r_start_time!

DIM msg_cmd$, msg_arg$, msg_ip$
DIM work_file_size%, work_sum16%
DIM work_chunk$

DIM l1$, l2$, l3$
DIM g_last_menu_draw_ms!         ' last time we drew the menu (ms)

DIM g_connected%          ' 0=not confirmed, 1=confirmed with a peer
DIM g_status$             ' one-line status shown on the menu
DIM g_menu_dirty%         ' 1 when the menu needs a redraw
DIM g_last_peer_str$      ' "ip name" cache for the menu
DIM g_debug_silent%       ' 1 = suppress debug prints during transfer
g_debug_silent% = 1

' -------------------- LED state --------------------
DIM led_buf%(LED_COUNT%)       ' LED color buffer (1-based due to OPTION BASE 1)
DIM led_last_flash!            ' timestamp of last LED flash


' ===========================================================================
'                              UTIL FUNCTIONS
' ===========================================================================
FUNCTION ExtractIP$(addr$)
  LOCAL p%
  p% = INSTR(addr$, ":")
  IF p% = 0 THEN ExtractIP$ = addr$ ELSE ExtractIP$ = LEFT$(addr$, p% - 1)
END FUNCTION

FUNCTION DeviceName$()
  ' Derive a quick-unique suffix from TIMER; change to taste if you have a true ID
  LOCAL t%, hexid$
  t% = TIMER
  hexid$ = RIGHT$("0000" + HEX$(t% AND &HFFFF), 4)
  DeviceName$ = "PicoCalc-" + hexid$
END FUNCTION

FUNCTION GetMyIP$()
  LOCAL ip$
  ON ERROR SKIP 1
  ip$ = MM.INFO$(IP ADDRESS)
  ON ERROR ABORT
  IF INSTR(ip$, ".") = 0 THEN ip$ = ""
  GetMyIP$ = ip$
END FUNCTION

FUNCTION SubnetBroadcast$(ip$)
  LOCAL p1%, p2%, p3%, a$, b$, c$
  p1% = INSTR(ip$, ".") : IF p1% = 0 THEN SubnetBroadcast$ = "" : EXIT FUNCTION
  p2% = INSTR(p1% + 1, ip$, ".") : IF p2% = 0 THEN SubnetBroadcast$ = "" : EXIT FUNCTION
  p3% = INSTR(p2% + 1, ip$, ".") : IF p3% = 0 THEN SubnetBroadcast$ = "" : EXIT FUNCTION
  a$ = LEFT$(ip$, p1% - 1)
  b$ = MID$(ip$, p1% + 1, p2% - p1% - 1)
  c$ = MID$(ip$, p2% + 1, p3% - p2% - 1)
  SubnetBroadcast$ = a$ + "." + b$ + "." + c$ + ".255"
END FUNCTION

FUNCTION FileBaseName$(full$)
  LOCAL pathNorm$, p%, lastSlashPos%

  ' normalize backslashes to forward slashes without REPLACE$
  pathNorm$ = full$
  DO WHILE INSTR(pathNorm$, "\") <> 0
    p% = INSTR(pathNorm$, "\")
    pathNorm$ = LEFT$(pathNorm$, p% - 1) + "/" + MID$(pathNorm$, p% + 1)
  LOOP

  ' find last slash using forward scan (no reverse INSTR in some builds)
  lastSlashPos% = 0
  DO
    p% = INSTR(lastSlashPos% + 1, pathNorm$, "/")
    IF p% = 0 THEN EXIT DO
    lastSlashPos% = p%
  LOOP

  IF lastSlashPos% = 0 THEN
    FileBaseName$ = pathNorm$
  ELSE
    FileBaseName$ = MID$(pathNorm$, lastSlashPos% + 1)
  ENDIF
END FUNCTION


FUNCTION FileExists%(path$)
  FileExists% = MM.INFO(EXISTS FILE path$)
END FUNCTION

FUNCTION Min%(a%, b%)
  IF a% < b% THEN Min% = a% ELSE Min% = b%
END FUNCTION

FUNCTION Hexify$(bin$)
  ' convert each byte in bin$ to two hex chars
  LOCAL i%, h$, ch%
  h$ = ""
  FOR i% = 1 TO LEN(bin$)
    ch% = ASC(MID$(bin$, i%, 1))
    h$ = h$ + RIGHT$("0" + HEX$(ch%), 2)
  NEXT
  Hexify$ = h$
END FUNCTION

FUNCTION Dehexify$(hx$)
  ' convert two-hex-digit pairs back to bytes
  LOCAL i%, out1$, pair$, v%
  out1$ = ""
  IF (LEN(hx$) MOD 2) <> 0 THEN
    Dehexify$ = out1$
    EXIT FUNCTION
  ENDIF
  FOR i% = 1 TO LEN(hx$) STEP 2
    pair$ = MID$(hx$, i%, 2)
    v% = VAL("&H" + pair$)
    out1$ = out1$ + CHR$(v%)
  NEXT
  Dehexify$ = out1$
END FUNCTION

FUNCTION Sum16%(bin$)
  ' simple 16-bit rolling sum of bytes
  LOCAL i%, s%, ch%
  s% = 0
  FOR i% = 1 TO LEN(bin$)
    ch% = ASC(MID$(bin$, i%, 1))
    s% = (s% + ch%) AND &HFFFF
  NEXT
  Sum16% = s%
END FUNCTION

FUNCTION LeftOf$(s$, delim$)
  LOCAL p%
  p% = INSTR(s$, delim$)
  IF p% = 0 THEN
    LeftOf$ = s$
  ELSE
    LeftOf$ = LEFT$(s$, p% - 1)
  ENDIF
END FUNCTION

FUNCTION MidAfter$(s$, delim$)
  LOCAL p%
  p% = INSTR(s$, delim$)
  IF p% = 0 THEN
    MidAfter$ = ""
  ELSE
    MidAfter$ = MID$(s$, p% + LEN(delim$))
  ENDIF
END FUNCTION

' ===========================================================================
'                              UDP / QUEUE
' ===========================================================================
SUB OpenUDP()
  IF g_udp_opened% THEN EXIT SUB
  ON ERROR SKIP 1 : WEB UDP CLOSE
  WEB UDP OPEN SERVER PORT UDP_DISC_PORT%
  WEB UDP INTERRUPT UdpISR
  g_udp_opened% = 1
END SUB

SUB UdpSend(ip$, payload$)
  WEB UDP SEND ip$, UDP_DISC_PORT%, payload$
END SUB

SUB EnqueueMessage(cmd$, arg$, ip$)
  LOCAL nxt%
  nxt% = (q_tail% MOD QUEUE_MAX%) + 1
  ' simple drop-if-full
  IF nxt% = q_head% THEN EXIT SUB
  q_cmd$(q_tail%) = cmd$
  q_arg$(q_tail%) = arg$
  q_ip$(q_tail%)  = ip$
  q_tail% = nxt%
END SUB

FUNCTION QueueHasItem%()
  QueueHasItem% = (q_head% <> q_tail%)
END FUNCTION

SUB DequeueMessage(cmd$, arg$, ip$)
  IF q_head% = q_tail% THEN
    cmd$ = "" : arg$ = "" : ip$ = ""
    EXIT SUB
  ENDIF
  cmd$ = q_cmd$(q_head%)
  arg$ = q_arg$(q_head%)
  ip$  = q_ip$(q_head%)
  q_head% = (q_head% MOD QUEUE_MAX%) + 1
END SUB

' -------------------- Interrupt: decode + enqueue only --------------------
SUB UdpISR
  LOCAL raw$, src$, bar%, c$, a$
  raw$ = MM.MESSAGE$
  src$ = ExtractIP$(MM.ADDRESS$)
  bar% = INSTR(raw$, "|")
  IF bar% = 0 THEN
    c$ = raw$ : a$ = ""
  ELSE
    c$ = LEFT$(raw$, bar% - 1)
    a$ = MID$(raw$, bar% + 1)
  ENDIF
  EnqueueMessage c$, a$, src$
END SUB

' ===========================================================================
'                       PROTOCOL: HIGH-LEVEL SENDERS
' ===========================================================================
SUB BroadcastHello()
  LOCAL i%
  'PRINT "Broadcasting HELLO..."
  FOR i% = 1 TO HELLO_REPEAT_CT%
    UdpSend "255.255.255.255", "HELLO|" + g_device_name$
    PAUSE HELLO_INTERVAL_MS%
  NEXT
  g_last_hello! = TIMER
  'PRINT "Done."
END SUB

SUB AnnouncePeer(ip$)
  pending_reply_ip$ = ip$
  pending_reply_name$ = g_device_name$
  pending_reply_needed% = 1
END SUB

SUB SendFileOffer(peer_ip$, full_path$)
  LOCAL fsz%, fh%, sum%, base$
  IF FileExists%(full_path$) = 0 THEN
    PRINT "No such file: "; full_path$
    EXIT SUB
  ENDIF

  base$ = FileBaseName$(full_path$)

  ' compute size + sum
  OPEN full_path$ FOR INPUT AS #1
  fsz% = LOF(#1)
  sum% = 0
  LOCAL chunk$
  DO WHILE EOF(#1) = 0
    chunk$ = INPUT$(255, #1)
    sum% = (sum% + Sum16%(chunk$)) AND &HFFFF
  LOOP
  CLOSE #1

  UdpSend peer_ip$, "FILE_OFFER|" + base$ + "|" + STR$(fsz%) + "|" + STR$(sum%)
  PRINT "Offered "; base$; " ("; fsz%; " bytes, sum="; HEX$(sum%); ") to "; peer_ip$
END SUB

SUB StartSending(peer_ip$, full_path$, base$, fsz%, sum16%)
  ' setup sender state and send first chunk
  s_active% = 1
  s_file_name_full$ = full_path$
  s_file_basename$ = base$
  s_file_size% = fsz%
  s_sent_sum% = 0
  s_next_seq% = 1
  s_waiting_ack_seq% = 1
  s_retry_count% = 0
  s_total_chunks% = (fsz% + CHUNK_BYTES% - 1) \ CHUNK_BYTES%
  OPEN s_file_name_full$ FOR INPUT AS #9
  PRINT "Sending "; base$; " in "; s_total_chunks%; " chunk(s)..."
  ' immediately push first chunk
  SendNextChunk peer_ip$
END SUB

SUB SendNextChunk(peer_ip$)
  LOCAL remainingBytes%, takeBytes%, rawChunk$, hexChunk$, packet$

  remainingBytes% = s_file_size% - ((s_next_seq% - 1) * CHUNK_BYTES%)
  IF remainingBytes% <= 0 THEN
    UdpSend peer_ip$, "FILE_DONE|" + STR$(s_sent_sum%) + "|" + STR$(s_total_chunks%)
    PRINT "All chunks sent; waiting for checksum confirm..."
    EXIT SUB
  ENDIF

  takeBytes% = Min%(CHUNK_BYTES%, remainingBytes%)
  rawChunk$  = INPUT$(takeBytes%, #9)
  s_sent_sum% = (s_sent_sum% + Sum16%(rawChunk$)) AND &HFFFF

  hexChunk$  = Hexify$(rawChunk$)
  packet$    = "FILE_CHUNK|" + STR$(s_next_seq%) + "|" + hexChunk$
  UdpSend peer_ip$, packet$

  ' Flash LEDs blue for sending
  LED_Flash 0, 0, 255

  s_waiting_ack_seq% = s_next_seq%
  s_last_send_ts!    = TIMER
  ' advance happens on ack in HandleAck
END SUB


SUB HandleAck(peer_ip$, seqnum%)
  IF s_active% = 0 THEN EXIT SUB
  IF seqnum% <> s_waiting_ack_seq% THEN EXIT SUB
  ' good ack; advance
  s_next_seq% = s_next_seq% + 1
  s_retry_count% = 0
  ' next send
  SendNextChunk peer_ip$
END SUB

SUB MaybeResendChunk(peer_ip$)
  IF s_active% = 0 THEN EXIT SUB
  IF (TIMER - s_last_send_ts!) < ACK_TIMEOUT_MS% THEN EXIT SUB

  IF s_retry_count% >= SEND_RETRY_MAX% THEN
    PRINT "Send failed: too many retries."
    UdpSend peer_ip$, "FILE_CANCEL|timeout"
    CLOSE #9
    s_active% = 0
    EXIT SUB
  ENDIF

  s_retry_count% = s_retry_count% + 1
  'PRINT "Resend seq "; s_waiting_ack_seq%; " (attempt "; s_retry_count%; ")"

  LOCAL resendPos%, takeBytes%, rawChunk$, hexChunk$
  resendPos%  = (s_waiting_ack_seq% - 1) * CHUNK_BYTES%
  SEEK #9, resendPos% + 1
  takeBytes%  = Min%(CHUNK_BYTES%, s_file_size% - resendPos%)
  rawChunk$   = INPUT$(takeBytes%, #9)
  hexChunk$   = Hexify$(rawChunk$)

  UdpSend peer_ip$, "FILE_CHUNK|" + STR$(s_waiting_ack_seq%) + "|" + hexChunk$
  s_last_send_ts! = TIMER
END SUB


' ===========================================================================
'                       PROTOCOL: HIGH-LEVEL RECEIVER
' ===========================================================================
SUB HandleFileOffer(from_ip$, arg$)
  LOCAL nm$, rest$, sz$, su$, size_i%, sum_i%

  nm$ = LeftOf$(arg$, "|")
  rest$ = MidAfter$(arg$, "|")
  sz$ = LeftOf$(rest$, "|")
  su$ = MidAfter$(rest$, "|")
  size_i% = VAL(sz$)
  sum_i%  = VAL(su$)

  ' store directly to current drive (assumed B:)
  r_target_path$ = nm$
  OPEN r_target_path$ FOR OUTPUT AS #8
  CLOSE #8
  OPEN r_target_path$ FOR RANDOM AS #8

  r_active% = 1
  r_expect_name$ = nm$
  r_total_size% = size_i%
  r_recv_sum% = 0
  r_expected_seq% = 1
  r_total_chunks_announced% = (size_i% + CHUNK_BYTES% - 1) \ CHUNK_BYTES%
  r_start_time! = TIMER

  UdpSend from_ip$, "FILE_ACCEPT|" + nm$
  PRINT "Accepting "; nm$; " ("; size_i%; " bytes, sum="; HEX$(sum_i%); ")"
END SUB


SUB HandleChunk(from_ip$, arg$)
  IF r_active% = 0 THEN EXIT SUB

  ' avoid reserved names: POS/HEX$
  LOCAL seqStr$, payloadHex$, seqIndex%, payloadBin$, writePos%

  seqStr$     = LeftOf$(arg$, "|")
  payloadHex$ = MidAfter$(arg$, "|")
  seqIndex%   = VAL(seqStr$)

  ' stop-and-wait: only accept the exact expected sequence
  IF seqIndex% <> r_expected_seq% THEN EXIT SUB

  payloadBin$ = Dehexify$(payloadHex$)
  r_recv_sum% = (r_recv_sum% + Sum16%(payloadBin$)) AND &HFFFF

  writePos% = (r_expected_seq% - 1) * CHUNK_BYTES%
  SEEK #8, writePos% + 1
  PRINT #8, payloadBin$;         ' no CRLF

  ' Flash LEDs orange for receiving
  LED_Flash 255, 165, 0

  ' ack and advance
  UdpSend from_ip$, "FILE_ACK|" + STR$(seqIndex%)
  r_expected_seq% = r_expected_seq% + 1

  ' if we just wrote the last bytes, we'll verify when FILE_DONE arrives
  IF writePos% + LEN(payloadBin$) >= r_total_size% THEN
    ' waiting for FILE_DONE for checksum confirm
  ENDIF
END SUB


SUB HandleFileDone(from_ip$, arg$)
  ' FILE_DONE|sum|total_chunks
  IF r_active% = 0 THEN EXIT SUB
  LOCAL su$, tc$, sum_i%, chunks_i%
  su$ = LeftOf$(arg$, "|")
  tc$ = MidAfter$(arg$, "|")
  sum_i% = VAL(su$)
  chunks_i% = VAL(tc$)

  CLOSE #8
  IF (r_recv_sum% AND &HFFFF) = (sum_i% AND &HFFFF) THEN
    ' success
    UdpSend from_ip$, "FILE_DONE|" + STR$(r_recv_sum%) + "|" + STR$(chunks_i%)

    ' Flash LEDs 3 times to indicate completion
    LED_CompletionFlash

    ' Build summary lines
    LOCAL l1$, l2$, l3$
    l1$ = "Received: " + r_target_path$
    l2$ = "Bytes: " + STR$(r_total_size%) + "  Chunks: " + STR$(chunks_i%)
    l3$ = "Checksum: " + HEX$(r_recv_sum%)
    ShowSummaryAndWait "Transfer complete (receiver)", l1$, l2$, l3$

    r_active% = 0
  ELSE
    PRINT "Checksum mismatch: got "; HEX$(r_recv_sum%); " expected "; HEX$(sum_i%)
    UdpSend from_ip$, "FILE_CANCEL|checksum"
    r_active% = 0
    MarkMenuDirty("Receive failed: checksum mismatch")
  ENDIF

  r_active% = 0
END SUB

SUB HandleCancel(reason$)
  IF s_active% THEN
    PRINT "Sender canceled: "; reason$
    CLOSE #9
    s_active% = 0
  ENDIF
  IF r_active% THEN
    PRINT "Receiver canceled: "; reason$
    CLOSE #8
    r_active% = 0
  ENDIF
END SUB

' ===========================================================================
'                                 UI
' ===========================================================================
SUB ShowSummaryAndWait(title$, line1$, line2$, line3$)
  LOCAL k$
  CLS
  PRINT title$
  PRINT STRING$(LEN(title$), "-")
  IF LEN(line1$) THEN PRINT line1$
  IF LEN(line2$) THEN PRINT line2$
  IF LEN(line3$) THEN PRINT line3$
  PRINT
  PRINT "Press any key to return to menu..."
  DO
    k$ = INKEY$
    IF LEN(k$) THEN EXIT DO
    PAUSE 10
  LOOP
  MarkMenuDirty("")
END SUB

SUB SetConnectionConfirmed(ip$, name$)
  LOCAL newPeerStr$
  newPeerStr$ = ip$ + "  " + name$

  ' update only if something actually changed
  IF g_connected% = 0 OR (newPeerStr$ <> g_last_peer_str$) THEN
    g_connected% = 1
    g_last_peer_str$ = newPeerStr$
    MarkMenuDirty("Connection confirmed")
  ENDIF
END SUB

SUB DrawMenu()
  CLS
  PRINT "PicoCalc UDP Discovery + File Transfer"
  PRINT STRING$(34, "-")
  IF g_connected% THEN
    PRINT "Connection: Confirmed"
    IF LEN(g_last_peer_str$) THEN PRINT "Peer: "; g_last_peer_str$
  ELSE
    PRINT "Connection: Searching..."
    PRINT "(Press H to send beacons)"
  ENDIF
  IF LEN(g_status$) THEN
    PRINT
    PRINT "Status: "; g_status$
  ENDIF
  PRINT
  PRINT "Keys:"
  PRINT "  H = HELLO beacons"
  PRINT "  P = show peer"
  PRINT "  S = send a file to peer"
  PRINT "  W = listen 5s"
  PRINT "  Q = quit"
  g_menu_dirty% = 0
  g_last_menu_draw_ms! = TIMER   ' record when we drew
END SUB


SUB MarkMenuDirty(status$)
  g_status$ = status$
  g_menu_dirty% = 1
END SUB

SUB PromptAndOffer()
  IF LEN(g_peer_ip$) = 0 THEN
    PRINT "No peer yet. Press H to discover."
    EXIT SUB
  ENDIF

  LOCAL path$
  print "File path to send (e.g. A:/foo.bin): "
  line input "", path$
  IF LEN(path$) = 0 THEN EXIT SUB
  IF FileExists%(path$) = 0 THEN
    PRINT "Not found: "; path$
    EXIT SUB
  ENDIF

  ' compute metadata again to keep logic in one place
  LOCAL fsz%, sum%, base$
  OPEN path$ FOR INPUT AS #3
  fsz% = LOF(#3)
  sum% = 0
  LOCAL tmp1$
  DO WHILE EOF(#3) = 0
    tmp1$ = INPUT$(255, #3)
    sum% = (sum% + Sum16%(tmp1$)) AND &HFFFF
  LOOP
  CLOSE #3

  base$ = FileBaseName$(path$)
  s_file_name_full$ = path$
  SendFileOffer g_peer_ip$, path$
END SUB

' ===========================================================================
'                              LED FUNCTIONS
' ===========================================================================
SUB LED_Init()
  ' Initialize all LEDs to off
  LOCAL i%
  FOR i% = 1 TO LED_COUNT%
    led_buf%(i%) = 0
  NEXT
  BITBANG WS2812 O, GP28, LED_COUNT%, led_buf%()
  led_last_flash! = 0
END SUB

SUB LED_Clear()
  ' Clear all LEDs
  LOCAL i%
  FOR i% = 1 TO LED_COUNT%
    led_buf%(i%) = 0
  NEXT
  BITBANG WS2812 O, GP28, LED_COUNT%, led_buf%()
END SUB

SUB LED_Flash(r%, g%, b%)
  ' Flash LEDs with specified color (throttled to be visible)
  ' Color format: RGB packed as (R * &H10000) + (G * &H100) + B
  LOCAL now!, i%, col%

  now! = TIMER
  ' Throttle updates so flashes are visible (minimum LED_FLASH_MS% between flashes)
  IF (now! - led_last_flash!) < LED_FLASH_MS% THEN EXIT SUB

  col% = (r% * &H10000) + (g% * &H100) + b%
  FOR i% = 1 TO LED_COUNT%
    led_buf%(i%) = col%
  NEXT
  BITBANG WS2812 O, GP28, LED_COUNT%, led_buf%()
  PAUSE LED_FLASH_MS%
  LED_Clear
  led_last_flash! = now!
END SUB

SUB LED_CompletionFlash()
  ' Flash all LEDs 3 times in green to indicate transfer completion
  LOCAL i%, flash%
  FOR flash% = 1 TO 3
    ' Green flash
    FOR i% = 1 TO LED_COUNT%
      led_buf%(i%) = &H00FF00  ' Green: (0 * &H10000) + (255 * &H100) + 0
    NEXT
    BITBANG WS2812 O, GP28, LED_COUNT%, led_buf%()
    PAUSE 150
    ' Clear
    LED_Clear
    PAUSE 150
  NEXT
END SUB

' ===========================================================================
'                                MAIN
' ===========================================================================
CLS
PRINT "PicoCalc UDP Discovery + File Transfer"

' initialize indices for 1-based arrays BEFORE enabling interrupts
q_head% = 1
q_tail% = 1

OpenUDP
LED_Init

g_device_name$ = DeviceName$()
g_my_ip$ = GetMyIP$()
g_broadcast_ip$ = "255.255.255.255"
PRINT "Wi-Fi status: "; MM.INFO(TCPIP STATUS)
PRINT "My IP: "; g_my_ip$
PRINT "Name: "; g_device_name$
DrawMenu

' initial gentle beaconing until a peer appears
DO
  IF g_peer_known% = 0 AND (TIMER - g_last_hello!) >= 1 THEN
    UdpSend "255.255.255.255", "HELLO|" + g_device_name$
    g_last_hello! = TIMER
  ENDIF

  ' drain queue
  IF QueueHasItem%() THEN
    DequeueMessage msg_cmd$, msg_arg$, msg_ip$

    IF msg_cmd$ = "HELLO" THEN
      g_peer_ip$ = msg_ip$ : g_peer_name$ = msg_arg$ : g_peer_known% = 1
      SetConnectionConfirmed msg_ip$, msg_arg$



    ELSEIF msg_cmd$ = "PEER" THEN
      g_peer_ip$ = msg_ip$ : g_peer_name$ = msg_arg$ : g_peer_known% = 1
      SetConnectionConfirmed msg_ip$, msg_arg$


    ELSEIF msg_cmd$ = "FILE_OFFER" THEN
      HandleFileOffer msg_ip$, msg_arg$

    ELSEIF msg_cmd$ = "FILE_ACCEPT" THEN
      IF s_active% = 0 THEN
        IF FileExists%(s_file_name_full$) = 0 THEN
          PRINT "File missing; canceling."
          UdpSend msg_ip$, "FILE_CANCEL|missing"
        ELSE
          OPEN s_file_name_full$ FOR INPUT AS #4
          work_file_size% = LOF(#4)
          work_sum16% = 0
          DO WHILE EOF(#4) = 0
            work_chunk$ = INPUT$(255, #4)
            work_sum16% = (work_sum16% + Sum16%(work_chunk$)) AND &HFFFF
          LOOP
          CLOSE #4
          s_file_basename$ = msg_arg$
          s_file_size% = work_file_size%
          s_sent_sum% = 0
          s_total_chunks% = (work_file_size% + CHUNK_BYTES% - 1) \ CHUNK_BYTES%
          OPEN s_file_name_full$ FOR INPUT AS #9
          s_active% = 1
          s_next_seq% = 1
          s_waiting_ack_seq% = 1
          s_retry_count% = 0
          MarkMenuDirty("Sending " + msg_arg$ + "...")
          SendNextChunk msg_ip$
        ENDIF
      ENDIF

    ELSEIF msg_cmd$ = "FILE_ACK" THEN
      HandleAck msg_ip$, VAL(msg_arg$)

    ELSEIF msg_cmd$ = "FILE_CHUNK" THEN
      HandleChunk msg_ip$, msg_arg$

    ELSEIF msg_cmd$ = "FILE_DONE" THEN
      IF r_active% THEN
        HandleFileDone msg_ip$, msg_arg$
    ELSEIF s_active% THEN
      CLOSE #9
      ' Flash LEDs 3 times to indicate completion
      LED_CompletionFlash
      ' Build sender summary (mirrors receiver UX)
      l1$ = "Sent: " + s_file_basename$ + " ? " + msg_ip$
      l2$ = "Bytes: " + STR$(s_file_size%) + "  Chunks: " + STR$(s_total_chunks%)
      l3$ = "Checksum: " + HEX$(s_sent_sum%)
      ShowSummaryAndWait "Transfer complete (sender)", l1$, l2$, l3$
      s_active% = 0
      MarkMenuDirty("")
    END IF


    ELSEIF msg_cmd$ = "FILE_CANCEL" THEN
      HandleCancel msg_arg$

    ELSEIF LEN(msg_cmd$) > 0 THEN
      PRINT "RX "; msg_cmd$; " from "; msg_ip$
    ENDIF
  ENDIF

  ' deferred reply (peer handshake) outside ISR
  IF pending_reply_needed% THEN
    UdpSend pending_reply_ip$, "PEER|" + pending_reply_name$
    pending_reply_needed% = 0
    IF LEN(g_peer_ip$) = 0 THEN g_peer_ip$ = pending_reply_ip$
    IF LEN(g_peer_name$) = 0 THEN g_peer_name$ = pending_reply_name$
    SetConnectionConfirmed g_peer_ip$, g_peer_name$

  END IF


  ' sender timeout handling
  IF s_active% THEN
    MaybeResendChunk g_peer_ip$
  ENDIF

  ' keys
  g_key$ = INKEY$
  IF g_key$ = "H" OR g_key$ = "h" THEN
    BroadcastHello
  ELSEIF g_key$ = "P" OR g_key$ = "p" THEN
    IF LEN(g_peer_ip$) THEN
      PRINT "Peer: "; g_peer_ip$; "  name="; g_peer_name$
    ELSE
      PRINT "No peer recorded yet."
    ENDIF
  ELSEIF g_key$ = "S" OR g_key$ = "s" THEN
    IF LEN(g_peer_ip$) = 0 THEN PRINT "No peer yet." ELSE PromptAndOffer
  ELSEIF g_key$ = "W" OR g_key$ = "w" THEN
    PRINT "Listening for 5 seconds..." : PAUSE 5000 : PRINT "Done."
  ELSEIF g_key$ = "Q" OR g_key$ = "q" THEN
    EXIT DO
  ENDIF
  IF g_menu_dirty% THEN
    IF (TIMER - g_last_menu_draw_ms!) >= MIN_MENU_REDRAW_MS% THEN
      DrawMenu
    ENDIF
  END IF
  PAUSE GLOBAL_POLL_MS%
LOOP

PRINT "Bye."
Pause 2000
run "B:menu.bas"
END
