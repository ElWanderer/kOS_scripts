@LAZYGLOBAL OFF.


pOut("lib_warp.ks v1.0.6 20160728").

GLOBAL WARP_TIME IS TIME:SECONDS.
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

FUNCTION setMaxPhysicsWarp
{
  PARAMETER m.
  SET WARP_MAX_PHYSICS TO m.
}

FUNCTION setWarpTime
{
  PARAMETER wt.
  SET WARP_TIME TO wt.
}

FUNCTION warpTime
{
  RETURN WARP_TIME - TIME:SECONDS.
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
  PARAMETER wm.

  IF wm = "PHYSICS" { RETURN WARP_MAX_PHYSICS. }

  LOCAL wt IS warpTime().
  FROM { LOCAL i IS WARP_MAX_RAILS. } UNTIL i < 1 STEP { SET i TO i - 1. } DO {
    IF wt > WARP_RAILS_BUFF[i-1] { RETURN i. }
  }

  RETURN 0.
}

FUNCTION noStop
{
  RETURN FALSE.
}

FUNCTION doWarp
{
  PARAMETER wt, stop_func IS noStop@.

  setWarpTime(wt).

  IF warpTime() < WARP_RAILS_BUFF[o] { RETURN FALSE. }
  pOut("Engaging time warp.").

  UNTIL stop_func() OR warpTime() <= 0 {
    LOCAL want_mode IS pickWarpMode().
    IF WARPMODE <> want_mode {
      pOut("Switching warp mode to: " + want_mode).
      SET WARPMODE TO want_mode.
      SET WARP TO 1.
    } ELSE {
      LOCAL want_warp IS pickWarp(WARPMODE).
      IF WARP <> want_warp { SET WARP TO want_warp. }
    }
    WAIT 0.
  }
  IF WARP <> 0 { SET WARP TO 0. }
  IF warpTime() > 0 { pOut("Ending time warp early."). }
  ELSE { pOut("Ending time warp."). }
  RETURN TRUE.
}