@LAZYGLOBAL OFF.

GLOBAL TIMES IS LEXICON().
GLOBAL LOG_FILE IS "".
GLOBAL g0 IS 9.80665.
GLOBAL INIT_MET_TS IS -1.
GLOBAL INIT_MET IS "".
GLOBAL stageTime IS diffTime@:BIND("STAGE").
GLOBAL CRAFT_SPECIFIC IS LEXICON().
GLOBAL CRAFT_FILE IS "1:/craft.ks".

killWarp().
setTime("STAGE").
IF NOT EXISTS (CRAFT_FILE) AND cOk() {
  LOCAL afp IS "0:/craft/" + padRep(0,"_",SHIP:NAME) + ".ks".
  IF EXISTS (afp) { COPYPATH(afp,CRAFT_FILE). }
}
IF EXISTS(CRAFT_FILE) { RUNONCEPATH(CRAFT_FILE). }
CORE:DOEVENT("Open Terminal").
CLEARSCREEN.
pOut("init_common.ks v1.3.0 20170106").

FUNCTION padRep
{
  PARAMETER l, s, t.
  RETURN (""+t):PADLEFT(l):REPLACE(" ",s).
}

FUNCTION formatTS
{
  PARAMETER u_time1, u_time2 IS TIME:SECONDS.
  LOCAL ts IS (TIME - TIME:SECONDS) + ABS(u_time1 - u_time2).
  RETURN "[T+" + padRep(2,"0",ts:YEAR - 1) + " " + padRep(3,"0",ts:DAY - 1) + " " + ts:CLOCK + "]".
}

FUNCTION formatMET
{
  LOCAL m IS ROUND(MISSIONTIME).
  IF m > INIT_MET_TS {
    SET INIT_MET_TS TO m.
    SET INIT_MET TO formatTS(TIME:SECONDS - m).
  }
  RETURN INIT_MET.
}

FUNCTION logOn
{
  PARAMETER lf IS "0:/log/" + padRep(0,"_",SHIP:NAME) + ".txt".
  SET LOG_FILE TO lf.
  doLog(SHIP:NAME).
  IF lf <> "" { pOut("Log file: " + LOG_FILE). }
}

FUNCTION doLog
{
  PARAMETER t.
  IF LOG_FILE <> "" AND cOk() { LOG t TO LOG_FILE. }
}

FUNCTION pOut
{
  PARAMETER t, wt IS TRUE.
  IF wt { SET t TO formatMET() + " " + t. }
  PRINT t.
  doLog(t).
}

FUNCTION hudMsg
{
  PARAMETER t, c IS YELLOW, s IS 40.
  HUDTEXT(t, 3, 2, s, c, FALSE).
  pOut("HUD: " + t).
}

FUNCTION setTime
{
  PARAMETER n, t IS TIME:SECONDS.
  SET TIMES[n] TO t.
}

FUNCTION diffTime
{
  PARAMETER n.
  RETURN TIME:SECONDS - TIMES[n].
}

FUNCTION doStage
{
  pOut("Staging.").
  setTime("STAGE").
  STAGE.
}

FUNCTION mAngle
{
  PARAMETER a.
  UNTIL a >= 0 { SET a TO a + 360. }
  RETURN MOD(a,360).
}

FUNCTION killWarp
{
  KUNIVERSE:TIMEWARP:CANCELWARP().
  WAIT UNTIL SHIP:UNPACKED.
}

FUNCTION doWarp
{
  PARAMETER wt, stop_func IS { RETURN FALSE. }.
  pOut("Engaging time warp.").
  WARPTO(wt).
  WAIT UNTIL stop_func() OR wt < TIME:SECONDS.
  killWarp().
  pOut("Time warp over.").
}
