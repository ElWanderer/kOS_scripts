@LAZYGLOBAL OFF.

pOut("lib_warp.ks v1.0.10 20160826").

GLOBAL WARP_MIN_ALT_LEX IS LEXICON(
  "Moho",   10000,
  "Eve",    MAX(90000,EVE:ATM:HEIGHT),
  "Gilly",  8000,
  "Kerbin", MAX(70000,KERBIN:ATM:HEIGHT),
  "Mun",    5000,
  "Minmus", 3000,
  "Duna",   MAX(50000,DUNA:ATM:HEIGHT),
  "Ike",    5000,
  "Dres",   10000,
  "Jool",   MAX(200000,JOOL:ATM:HEIGHT),
  "Laythe", MAX(50000,LAYTHE:ATM:HEIGHT),
  "Vall",   24500,
  "Tylo",   30000,
  "Bop",    24500,
  "Pol",    5000,
  "Eeloo",  4000
).
GLOBAL WARP_MAX_PHYSICS IS 3.
GLOBAL WARP_MAX_RAILS IS 7.
GLOBAL WARP_RAILS_BUFF IS LIST(3, 15, 30, 225, 675, 10000, 150000).

FUNCTION warpTime
{
  RETURN -diffTime("WARP").
}

FUNCTION setMaxWarp
{
  PARAMETER mp IS 3, mr IS 7.
  SET WARP_MAX_PHYSICS TO mp.
  SET WARP_MAX_RAILS TO mr.
}

FUNCTION pickWarpMode
{
  IF WARP_MIN_ALT_LEX:HASKEY(BODY:NAME) AND
     ALTITUDE <= WARP_MIN_ALT_LEX[BODY:NAME] AND
     NOT (LIST("LANDED","SPLASHED","PRELAUNCH"):CONTAINS(STATUS)) { RETURN "PHYSICS". }
  RETURN "RAILS".
}

FUNCTION pickWarp
{
  IF WARPMODE = "PHYSICS" { RETURN WARP_MAX_PHYSICS. }

  LOCAL wt IS warpTime().
  FROM { LOCAL i IS WARP_MAX_RAILS. } UNTIL i < 1 STEP { SET i TO i - 1. } DO {
    IF wt > WARP_RAILS_BUFF[i-1] { RETURN i. }
  }

  RETURN 0.
}

FUNCTION doWarp
{
  PARAMETER wt, stop_func IS { RETURN FALSE. }.

  setTime("WARP",wt).

  IF warpTime() < WARP_RAILS_BUFF[0] { RETURN FALSE. }
  pOut("Engaging time warp.").

  UNTIL stop_func() OR warpTime() <= 0 {
    LOCAL want_mode IS pickWarpMode().
    IF WARPMODE <> want_mode {
      pOut("Switching warp mode to: " + want_mode).
      SET WARP TO 0.
      SET WARPMODE TO want_mode.
    } ELSE {
      LOCAL want_warp IS pickWarp().
      IF WARP <> want_warp { SET WARP TO want_warp. }
    }
    WAIT 0.
  }
  IF WARP <> 0 { SET WARP TO 0. }
  IF warpTime() > 0 { pOut("Ending time warp early."). }
  WAIT UNTIL SHIP:UNPACKED.
  pOut("Time warp over.").
  RETURN TRUE.
}
