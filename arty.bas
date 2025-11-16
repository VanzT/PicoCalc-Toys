' Artillery Wi-Fi Multiplayer (PicoCalc)
' Version: 2.1

OPTION BASE 1
OPTION EXPLICIT

' === Constants ===
CONST PORT% = 6000
CONST SCREEN_W% = 320
CONST SCREEN_H% = 240
CONST GROUND_Y% = 200
CONST LEDCOUNT% = 8

' Colors
CONST BG_COLOR% = RGB(0,0,0)
CONST LINE_COLOR% = RGB(255,255,255)
CONST P1_COLOR% = RGB(0,255,0)
CONST P2_COLOR% = RGB(255,0,0)
CONST PROJ_COLOR% = RGB(255,255,0)
CONST TEXT_COLOR% = RGB(255,255,255)

' Physics
CONST GRAVITY! = 0.3
CONST MAX_POWER% = 100
CONST MIN_POWER% = 2
CONST ANGLE_STEP% = 2
CONST POWER_STEP% = 2

' === Globals ===
DIM myPlayer% = 0
DIM peer$ = ""
DIM assigned% = 0
DIM myTicket%
DIM lastHello! = -1

' Terrain
DIM terrain%(SCREEN_W%)
DIM terrainSeed% = 0
DIM p1_x%, p1_y%
DIM p2_x%, p2_y%

' Game state
DIM p1_score% = 0
DIM p2_score% = 0
DIM currentPlayer% = 1
DIM angle% = 46
DIM power% = 50
DIM prev_angle% = 46

' Per-player settings
DIM p1_angle% = 46
DIM p1_power% = 50
DIM p2_angle% = 46
DIM p2_power% = 50

' Projectile
DIM proj_active% = 0
DIM proj_x!, proj_y!
DIM proj_vx!, proj_vy!
DIM proj_prev_x!, proj_prev_y!

' Wind
DIM wind! = 0.0

DIM lastMessage$ = ""

' Seed acknowledgment tracking
DIM seedAck% = 1
DIM seedSentTime! = 0
DIM seedRetryCount% = 0
DIM pendingSeed% = 0

' Custom RNG state for deterministic terrain generation
DIM rngState% = 0
DIM rngValue! = 0.0

' LED effects
DIM ledBuffer%(LEDCOUNT%)
DIM ledFadeActive% = 0

' === SUB: Send Hello ===
SUB SendHello
  WEB UDP SEND "255.255.255.255", PORT%, "HELLO " + STR$(myTicket%)
END SUB

' === SUB: Set all LEDs to a color ===
SUB SetLEDs(red%, green%, blue%)
  LOCAL i%
  FOR i% = 1 TO LEDCOUNT%
    ' Pack as GRB: (G * &H10000) + (R * &H100) + B
    ledBuffer%(i%) = (green% * &H10000) + (red% * &H100) + blue%
  NEXT i%
  BITBANG WS2812 O, GP28, LEDCOUNT%, ledBuffer%()
END SUB

' === SUB: Trigger cannon fire effects ===
SUB CannonFireEffects
  ' Flash screen white for 50ms
  BOX 0, 0, SCREEN_W%, SCREEN_H%, 1, RGB(255,255,255), RGB(255,255,255)
  PAUSE 50

  ' Set LEDs to white and mark fade as active
  SetLEDs 255, 255, 255
  ledFadeActive% = 1

  ' Redraw game (screen returns to normal immediately)
  RedrawAll
END SUB

' === SUB: Update LED fade (call from main loop) ===
SUB UpdateLEDFade
  LOCAL brightness%, fadeTime!
  STATIC fadeStart! = 0
  STATIC lastActive% = 0

  IF ledFadeActive% = 0 THEN
    fadeStart! = 0
    lastActive% = 0
    EXIT SUB
  ENDIF

  ' Reset timer if this is a new fade (ledFadeActive just became 1)
  IF lastActive% = 0 THEN
    fadeStart! = TIMER
    lastActive% = 1
  ENDIF

  fadeTime! = TIMER - fadeStart!

  ' Fade linearly over 1 second
  IF fadeTime! >= 1.0 THEN
    ' Fade complete - turn off LEDs
    SetLEDs 0, 0, 0
    ledFadeActive% = 0
  ELSE
    ' Linear fade: brightness decreases at constant rate
    brightness% = INT(255.0 * (1.0 - fadeTime!))
    IF brightness% < 0 THEN brightness% = 0
    IF brightness% > 255 THEN brightness% = 255
    SetLEDs brightness%, brightness%, brightness%
  ENDIF
END SUB

' === SUB: Seed custom RNG ===
SUB SeedRNG(seed%)
  rngState% = seed%
  IF rngState% <= 0 THEN rngState% = 1
END SUB

' === SUB: Get deterministic random number (0.0 to 1.0) ===
SUB GetRND
  ' Linear Congruential Generator: (a * x + c) mod m
  ' Using parameters from Numerical Recipes
  rngState% = (1103515245 * rngState% + 12345) AND &H7FFFFFFF
  rngValue! = rngState% / 2147483647.0
END SUB

' === SUB: Generate terrain from seed ===
SUB GenerateTerrain(seed%)
  LOCAL i%, x%, h%, variation%

  ' Use custom RNG to generate identical terrain on both devices
  SeedRNG seed%

  ' Generate cannon positions from seed
  GetRND
  p1_x% = 40 + INT(rngValue! * 40)
  GetRND
  p2_x% = SCREEN_W% - 80 + INT(rngValue! * 40)

  IF p2_x% - p1_x% < SCREEN_W% \ 3 THEN
    p2_x% = p1_x% + SCREEN_W% \ 3 + 20
  ENDIF

  ' Generate wind from seed
  GetRND
  wind! = (rngValue! - 0.5) * 0.6

  ' Generate terrain
  FOR x% = 1 TO SCREEN_W%
    IF ABS(x% - p1_x%) < 10 OR ABS(x% - p2_x%) < 10 THEN
      IF x% = 1 THEN
        h% = GROUND_Y% - 30
      ELSE
        h% = terrain%(x%-1)
      ENDIF
    ELSE
      IF x% = 1 THEN
        GetRND
        h% = GROUND_Y% - 20 - INT(rngValue! * 30)
      ELSE
        GetRND
        variation% = INT(rngValue! * 20) - 10
        h% = terrain%(x%-1) + variation%
        IF h% < GROUND_Y% - 60 THEN h% = GROUND_Y% - 60
        IF h% > GROUND_Y% - 10 THEN h% = GROUND_Y% - 10
      ENDIF
    ENDIF
    terrain%(x%) = h%
  NEXT x%
  
  ' Smooth terrain
  FOR i% = 1 TO 2
    FOR x% = 2 TO SCREEN_W% - 1
      IF ABS(x% - p1_x%) < 10 OR ABS(x% - p2_x%) < 10 THEN
        ' Keep flat
      ELSE
        terrain%(x%) = (terrain%(x%-1) + terrain%(x%) + terrain%(x%+1)) \ 3
      ENDIF
    NEXT x%
  NEXT i%
  
  p1_y% = terrain%(p1_x%)
  p2_y% = terrain%(p2_x%)
END SUB

' === SUB: Draw terrain ===
SUB DrawTerrain
  LOCAL x%
  FOR x% = 1 TO SCREEN_W% - 1
    LINE x%, terrain%(x%), x%+1, terrain%(x%+1), 1, LINE_COLOR%
  NEXT x%
END SUB

' === SUB: Draw just the barrel ===
SUB DrawBarrel(x%, y%, barrel_angle%, col%)
  LOCAL barrel_len% = 15
  LOCAL angle_rad!, bx%, by%

  angle_rad! = barrel_angle% * 3.14159 / 180.0

  IF myPlayer% = 1 THEN
    bx% = x% + INT(barrel_len% * COS(angle_rad!))
    by% = y% - INT(barrel_len% * SIN(angle_rad!))
  ELSE
    bx% = x% - INT(barrel_len% * COS(angle_rad!))
    by% = y% - INT(barrel_len% * SIN(angle_rad!))
  ENDIF

  LINE x%, y% - 5, bx%, by%, 2, col%
END SUB

' === SUB: Draw cannon ===
SUB DrawCannon(x%, y%, col%)
  LOCAL barrel_len% = 15
  LOCAL angle_rad!, x1%, y1%, x2%, y2%, x3%, y3%, bx%, by%
  
  x1% = x% - 8 : y1% = y%
  x2% = x% + 8 : y2% = y%
  x3% = x% : y3% = y% - 10
  
  LINE x1%, y1%, x2%, y2%, 1, col%
  LINE x2%, y2%, x3%, y3%, 1, col%
  LINE x3%, y3%, x1%, y1%, 1, col%
  
  IF (myPlayer% = 1 AND x% = p1_x%) OR (myPlayer% = 2 AND x% = p2_x%) THEN
    angle_rad! = angle% * 3.14159 / 180.0
    IF myPlayer% = 1 THEN
      bx% = x% + INT(barrel_len% * COS(angle_rad!))
      by% = y% - INT(barrel_len% * SIN(angle_rad!))
    ELSE
      bx% = x% - INT(barrel_len% * COS(angle_rad!))
      by% = y% - INT(barrel_len% * SIN(angle_rad!))
    ENDIF
    LINE x%, y% - 5, bx%, by%, 2, col%
  ENDIF
END SUB

' === SUB: Draw HUD ===
SUB DrawHUD
  LOCAL windStr$

  COLOR TEXT_COLOR%, BG_COLOR%
  PRINT @(5, 5) "P1:" + STR$(p1_score%) + " P2:" + STR$(p2_score%)

  IF myPlayer% = currentPlayer% THEN
    PRINT @(5, 15) "YOUR TURN"
  ELSE
    PRINT @(5, 15) "WAIT...  "
  ENDIF

  IF myPlayer% = currentPlayer% THEN
    PRINT @(5, 220) "PWR:" + STR$(power%) + " ANG:" + STR$(angle%)

    IF wind! > 0 THEN
      windStr$ = "WIND:>" + STR$(INT(ABS(wind!) * 10))
    ELSEIF wind! < 0 THEN
      windStr$ = "WIND:<" + STR$(INT(ABS(wind!) * 10))
    ELSE
      windStr$ = "WIND:0"
    ENDIF
    PRINT @(200, 220) windStr$
  ENDIF
END SUB

' === SUB: Fire ===
SUB FireProjectile
  LOCAL angle_rad!, v0!

  ' Trigger visual effects only if this is my turn (I'm firing)
  IF currentPlayer% = myPlayer% THEN
    CannonFireEffects
  ENDIF

  v0! = power% / 8.0
  angle_rad! = angle% * 3.14159 / 180.0

  IF currentPlayer% = 1 THEN
    proj_x! = p1_x%
    proj_y! = p1_y% - 10
    proj_vx! = v0! * COS(angle_rad!)
    proj_vy! = -v0! * SIN(angle_rad!)
  ELSE
    proj_x! = p2_x%
    proj_y! = p2_y% - 10
    proj_vx! = -v0! * COS(angle_rad!)
    proj_vy! = -v0! * SIN(angle_rad!)
  ENDIF

  ' Initialize previous position
  proj_prev_x! = proj_x!
  proj_prev_y! = proj_y!

  proj_active% = 1
END SUB

' === SUB: Update projectile ===
SUB UpdateProjectile
  LOCAL hit%, px%, py%, check_x%, t!, interp_x!, interp_y!

  IF proj_active% = 0 THEN EXIT SUB

  ' Store previous position
  proj_prev_x! = proj_x!
  proj_prev_y! = proj_y!

  ' Update velocity
  proj_vy! = proj_vy! + GRAVITY!
  proj_vx! = proj_vx! + wind! * 0.1

  ' Update position
  proj_x! = proj_x! + proj_vx!
  proj_y! = proj_y! + proj_vy!
  
  ' Draw trail
  px% = INT(proj_x!)
  py% = INT(proj_y!)
  IF px% >= 0 AND px% <= SCREEN_W% AND py% >= 0 AND py% <= SCREEN_H% THEN
    PIXEL px%, py%, PROJ_COLOR%
    PIXEL px%-1, py%, PROJ_COLOR%
    PIXEL px%+1, py%, PROJ_COLOR%
    PIXEL px%, py%-1, PROJ_COLOR%
    PIXEL px%, py%+1, PROJ_COLOR%
  ENDIF
  
  ' Check if too far down
  IF proj_y! > GROUND_Y% + 20 THEN
    proj_active% = 0
    IF currentPlayer% = myPlayer% THEN
      SwitchTurn
    ENDIF
    EXIT SUB
  ENDIF

  ' Check if off screen (outside terrain bounds)
  IF proj_x! < 0 OR proj_x! > SCREEN_W% + 1 THEN
    proj_active% = 0
    IF currentPlayer% = myPlayer% THEN
      SwitchTurn
    ENDIF
    EXIT SUB
  ENDIF
  
  ' Check terrain collision using line segment test
  ' Sample every x position between previous and current
  LOCAL min_x%, max_x%, dx!, dy!, step_count%, i%

  min_x% = INT(proj_prev_x!)
  max_x% = INT(proj_x!)
  IF min_x% > max_x% THEN
    ' Swap if moving left
    min_x% = INT(proj_x!)
    max_x% = INT(proj_prev_x!)
  ENDIF

  ' Check each x position along the path
  FOR check_x% = min_x% TO max_x%
    IF check_x% >= 1 AND check_x% <= SCREEN_W% THEN
      ' Calculate interpolated y position at this x
      IF ABS(proj_x! - proj_prev_x!) > 0.1 THEN
        t! = (check_x% - proj_prev_x!) / (proj_x! - proj_prev_x!)
        interp_y! = proj_prev_y! + t! * (proj_y! - proj_prev_y!)
      ELSE
        interp_y! = proj_y!
      ENDIF

      ' Check if interpolated position is at or below terrain
      IF interp_y! >= terrain%(check_x%) THEN
        ' Collision detected!
        proj_active% = 0
        hit% = 0

        ' Use actual current position for hit detection
        px% = INT(proj_x!)
        py% = INT(proj_y!)
      
      ' Check P1 hit - within 10 pixel width
      IF ABS(proj_x! - p1_x%) <= 10 AND ABS(proj_y! - p1_y%) <= 15 THEN
        hit% = 1
        IF currentPlayer% = 1 THEN
          p1_score% = p1_score% + 1
        ELSE
          p2_score% = p2_score% + 1
        ENDIF
        ShowHitMessage 1
      ENDIF
      
      ' Check P2 hit - within 10 pixel width
      IF ABS(proj_x! - p2_x%) <= 10 AND ABS(proj_y! - p2_y%) <= 15 THEN
        hit% = 2
        IF currentPlayer% = 1 THEN
          p1_score% = p1_score% + 1
        ELSE
          p2_score% = p2_score% + 1
        ENDIF
        ShowHitMessage 2
      ENDIF
      
      IF hit% > 0 THEN
        PAUSE 1500
        ' Generate new terrain - only shooting player generates seed
        terrainSeed% = INT(RND * 1000000)
        GenerateTerrain terrainSeed%

        ' Send terrain seed to peer with acknowledgment
        IF peer$ <> "" THEN
          seedAck% = 0
          pendingSeed% = terrainSeed%
          seedSentTime! = TIMER
          seedRetryCount% = 0
          WEB UDP SEND peer$, PORT%, "NEWSEED " + STR$(terrainSeed%)

          ' Wait for ACK with retry
          DO WHILE seedAck% = 0 AND seedRetryCount% < 5
            PAUSE 200
            IF seedAck% = 0 THEN
              IF (TIMER - seedSentTime!) > 1 THEN
                seedRetryCount% = seedRetryCount% + 1
                WEB UDP SEND peer$, PORT%, "NEWSEED " + STR$(terrainSeed%)
                seedSentTime! = TIMER
              ENDIF
            ENDIF
          LOOP

          WEB UDP SEND peer$, PORT%, "NEWSCORE " + STR$(p1_score%) + "," + STR$(p2_score%)
        ENDIF

        RedrawAll
      ENDIF
      
        ' Switch turn only if it's my turn (avoid race condition)
        IF currentPlayer% = myPlayer% THEN
          SwitchTurn
        ENDIF
        EXIT SUB
      ENDIF
    ENDIF
  NEXT check_x%
END SUB

' === SUB: Show hit ===
SUB ShowHitMessage(player%)
  COLOR RGB(255, 255, 0), BG_COLOR%
  IF player% = 1 THEN
    PRINT @(100, 100) "PLAYER 1 HIT!"
  ELSE
    PRINT @(100, 100) "PLAYER 2 HIT!"
  ENDIF
END SUB

' === SUB: Switch turn ===
SUB SwitchTurn
  ' Save current player's settings
  IF currentPlayer% = 1 THEN
    p1_angle% = angle%
    p1_power% = power%
  ELSE
    p2_angle% = angle%
    p2_power% = power%
  ENDIF

  ' Switch to other player
  currentPlayer% = 3 - currentPlayer%

  ' Restore new player's settings
  IF currentPlayer% = 1 THEN
    angle% = p1_angle%
    power% = p1_power%
  ELSE
    angle% = p2_angle%
    power% = p2_power%
  ENDIF

  ' Update prev_angle to match current angle
  prev_angle% = angle%

  ' Tell peer it's their turn now
  IF peer$ <> "" THEN
    WEB UDP SEND peer$, PORT%, "YOURTURN"
  ENDIF

  ' Redraw all to clear projectile trails
  RedrawAll
END SUB

' === SUB: Redraw all ===
SUB RedrawAll
  CLS BG_COLOR%
  DrawTerrain
  DrawCannon p1_x%, p1_y%, P1_COLOR%
  DrawCannon p2_x%, p2_y%, P2_COLOR%
  DrawHUD
END SUB

' === SUB: UDP handler ===
SUB OnUDP
  LOCAL t$, src$, comma%, hostPlayer%, startPlayer%, peerTicket%, seed%
  LOCAL ang%, pwr%
  
  t$ = MM.MESSAGE$
  src$ = MM.ADDRESS$
  
  ' === Handshake ===
  IF assigned% = 0 THEN
    IF LEFT$(t$,5) = "HELLO" THEN
      peerTicket% = VAL(MID$(t$, 7))
      
      IF peerTicket% = myTicket% THEN
        myTicket% = INT(RND * 1000000)
        EXIT SUB
      ENDIF
      
      peer$ = src$
      
      IF myTicket% > peerTicket% THEN
        IF RND > 0.5 THEN hostPlayer% = 1 ELSE hostPlayer% = 2
        startPlayer% = 1
        myPlayer% = hostPlayer%
        currentPlayer% = startPlayer%
        assigned% = 1

        ' Generate initial terrain
        terrainSeed% = INT(RND * 1000000)
        GenerateTerrain terrainSeed%

        ' Send assignment with terrain seed and wait for ACK
        seedAck% = 0
        pendingSeed% = terrainSeed%
        seedSentTime! = TIMER
        seedRetryCount% = 0
        WEB UDP SEND peer$, PORT%, "ASSIGN " + STR$(hostPlayer%) + "," + STR$(startPlayer%) + "," + STR$(terrainSeed%)
      ELSE
        WEB UDP SEND peer$, PORT%, "HELLO " + STR$(myTicket%)
      ENDIF
      EXIT SUB
    ENDIF
    
    IF LEFT$(t$,6) = "ASSIGN" THEN
      comma% = INSTR(t$, ",")
      hostPlayer% = VAL(MID$(t$, 8, comma% - 8))
      t$ = MID$(t$, comma% + 1)
      comma% = INSTR(t$, ",")
      startPlayer% = VAL(LEFT$(t$, comma% - 1))
      terrainSeed% = VAL(MID$(t$, comma% + 1))

      myPlayer% = 3 - hostPlayer%
      currentPlayer% = startPlayer%
      assigned% = 1
      peer$ = src$

      GenerateTerrain terrainSeed%

      ' Send acknowledgment of terrain seed
      WEB UDP SEND peer$, PORT%, "SEEDACK " + STR$(terrainSeed%)
      EXIT SUB
    ENDIF
  ENDIF
  
  ' === Game messages ===
  IF LEFT$(t$,4) = "FIRE" THEN
    comma% = INSTR(t$, ",")
    ang% = VAL(MID$(t$, 6, comma% - 6))
    pwr% = VAL(MID$(t$, comma% + 1))
    
    angle% = ang%
    power% = pwr%
    FireProjectile
    EXIT SUB
  ENDIF
  
  IF t$ = "YOURTURN" THEN
    ' Peer says it's my turn now
    ' Force end any active projectile
    proj_active% = 0

    currentPlayer% = myPlayer%

    ' Restore my player's settings
    IF myPlayer% = 1 THEN
      angle% = p1_angle%
      power% = p1_power%
    ELSE
      angle% = p2_angle%
      power% = p2_power%
    ENDIF

    ' Update prev_angle to match current angle
    prev_angle% = angle%

    ' Redraw all to clear projectile trails
    RedrawAll
    EXIT SUB
  ENDIF
  
  IF LEFT$(t$,7) = "NEWSEED" THEN
    seed% = VAL(MID$(t$, 9))
    terrainSeed% = seed%
    GenerateTerrain terrainSeed%
    RedrawAll

    ' Send acknowledgment of terrain seed
    WEB UDP SEND peer$, PORT%, "SEEDACK " + STR$(terrainSeed%)
    EXIT SUB
  ENDIF
  
  IF LEFT$(t$,8) = "NEWSCORE" THEN
    comma% = INSTR(t$, ",")
    p1_score% = VAL(MID$(t$, 10, comma% - 10))
    p2_score% = VAL(MID$(t$, comma% + 1))
    EXIT SUB
  ENDIF

  IF LEFT$(t$,7) = "SEEDACK" THEN
    seed% = VAL(MID$(t$, 9))
    ' Verify ACK matches our pending seed
    IF seed% = pendingSeed% THEN
      seedAck% = 1
    ENDIF
    EXIT SUB
  ENDIF
END SUB

' ========================================
' === MAIN ===
' ========================================

RANDOMIZE TIMER

' Initialize LEDs to off
SetLEDs 0, 0, 0

WEB UDP OPEN SERVER PORT PORT%
WEB UDP INTERRUPT OnUDP
PAUSE 500
myTicket% = INT(RND * 1000000)
SendHello
lastHello! = TIMER

CLS BG_COLOR%
COLOR TEXT_COLOR%, BG_COLOR%
PRINT @(10, 20) "Artillery Wi-Fi Setup"
PRINT @(10, 50) "My Player: ";
PRINT @(10, 70) "Peer: ";
PRINT @(10, 100) "Press key when connected"

DO WHILE INKEY$ = ""
  COLOR TEXT_COLOR%, BG_COLOR%
  PRINT @(120, 50);
  IF myPlayer% = 0 THEN
    PRINT "Unassigned"
  ELSEIF myPlayer% = 1 THEN
    PRINT "Player 1  "
  ELSE
    PRINT "Player 2  "
  ENDIF
  
  PRINT @(120, 70);
  IF peer$ = "" THEN
    PRINT "Waiting...         "
  ELSE
    PRINT peer$
  ENDIF
  
  IF assigned% = 0 AND (TIMER - lastHello!) >= 1 THEN
    SendHello
    lastHello! = TIMER
  ENDIF

  ' Retry ASSIGN message if no ACK received
  IF assigned% = 1 AND seedAck% = 0 AND myPlayer% <> 0 AND myTicket% > 0 THEN
    IF (TIMER - seedSentTime!) > 1 AND seedRetryCount% < 5 THEN
      seedRetryCount% = seedRetryCount% + 1
      WEB UDP SEND peer$, PORT%, "ASSIGN " + STR$(myPlayer%) + ",1," + STR$(terrainSeed%)
      seedSentTime! = TIMER
    ENDIF
  ENDIF

  PAUSE 250
LOOP

' Wait for terrain
DO WHILE terrainSeed% = 0
  PAUSE 100
LOOP

PAUSE 200
RedrawAll

' === Game loop ===
DIM k$
DO
  k$ = INKEY$
  
  IF proj_active% THEN
    UpdateProjectile
    PAUSE 30
    CONTINUE DO
  ENDIF
  
  IF k$ <> "" AND myPlayer% = currentPlayer% THEN
    SELECT CASE ASC(k$)
      CASE 130  ' Left arrow
        ' Erase old barrel in black
        IF myPlayer% = 1 THEN
          DrawBarrel p1_x%, p1_y%, prev_angle%, BG_COLOR%
        ELSE
          DrawBarrel p2_x%, p2_y%, prev_angle%, BG_COLOR%
        ENDIF

        ' Update angle
        prev_angle% = angle%
        IF myPlayer% = 1 THEN
          angle% = angle% + ANGLE_STEP%
          IF angle% > 90 THEN angle% = 90
        ELSE
          angle% = angle% - ANGLE_STEP%
          IF angle% < 0 THEN angle% = 0
        ENDIF

        ' Draw new barrel in player color
        IF myPlayer% = 1 THEN
          DrawBarrel p1_x%, p1_y%, angle%, P1_COLOR%
        ELSE
          DrawBarrel p2_x%, p2_y%, angle%, P2_COLOR%
        ENDIF

        ' Update HUD only
        BOX 0, 210, SCREEN_W%, 30, 1, BG_COLOR%, BG_COLOR%
        DrawHUD

      CASE 131  ' Right arrow
        ' Erase old barrel in black
        IF myPlayer% = 1 THEN
          DrawBarrel p1_x%, p1_y%, prev_angle%, BG_COLOR%
        ELSE
          DrawBarrel p2_x%, p2_y%, prev_angle%, BG_COLOR%
        ENDIF

        ' Update angle
        prev_angle% = angle%
        IF myPlayer% = 1 THEN
          angle% = angle% - ANGLE_STEP%
          IF angle% < 0 THEN angle% = 0
        ELSE
          angle% = angle% + ANGLE_STEP%
          IF angle% > 90 THEN angle% = 90
        ENDIF

        ' Draw new barrel in player color
        IF myPlayer% = 1 THEN
          DrawBarrel p1_x%, p1_y%, angle%, P1_COLOR%
        ELSE
          DrawBarrel p2_x%, p2_y%, angle%, P2_COLOR%
        ENDIF

        ' Update HUD only
        BOX 0, 210, SCREEN_W%, 30, 1, BG_COLOR%, BG_COLOR%
        DrawHUD
        
      CASE 128
        power% = power% + POWER_STEP%
        IF power% > MAX_POWER% THEN power% = MAX_POWER%
        BOX 0, 0, SCREEN_W%, 30, 1, BG_COLOR%, BG_COLOR%
        BOX 0, 210, SCREEN_W%, 30, 1, BG_COLOR%, BG_COLOR%
        DrawHUD
        DrawCannon p1_x%, p1_y%, P1_COLOR%
        DrawCannon p2_x%, p2_y%, P2_COLOR%
        
      CASE 129
        power% = power% - POWER_STEP%
        IF power% < MIN_POWER% THEN power% = MIN_POWER%
        BOX 0, 0, SCREEN_W%, 30, 1, BG_COLOR%, BG_COLOR%
        BOX 0, 210, SCREEN_W%, 30, 1, BG_COLOR%, BG_COLOR%
        DrawHUD
        DrawCannon p1_x%, p1_y%, P1_COLOR%
        DrawCannon p2_x%, p2_y%, P2_COLOR%
        
      CASE 13, 32
        FireProjectile
        IF peer$ <> "" THEN
          lastMessage$ = "FIRE " + STR$(angle%) + "," + STR$(power%)
          WEB UDP SEND peer$, PORT%, lastMessage$
        ENDIF
    END SELECT
  ENDIF

  ' Update LED fade effect
  UpdateLEDFade

  PAUSE 20
LOOP