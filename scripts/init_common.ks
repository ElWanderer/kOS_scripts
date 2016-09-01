@LAZYGLOBAL OFF.
IF WARP <> 0 { SET WARP TO 0. }
WAIT UNTIL SHIP:UNPACKED.

GLOBAL pad2Z IS padRep@:BIND(2,"0").
GLOBAL pad3Z IS padRep@:BIND(3,"0").

GLOBAL TIMES IS LEXICON().
GLOBAL LOG_FILE IS "".
GLOBAL g0 IS 9.80665.
GLOBAL INIT_MET_TS IS -1.
GLOBAL INIT_MET IS "".
setTime("STAGE").
GLOBAL stageTime IS diffTime@:BIND("STAGE").

CORE:DOEVENT("Open Terminal").
CLEARSCREEN.
pOut("init_common.ks v1.1.0 20160901").

FUNCTION padRep
{
  PARAMETER l, s, t.
  RETURN (""+t):PADLEFT(l):REPLACE(" ",s).
}

FUNCTION formatTS
{
  PARAMETER u_time1, u_time2.
  LOCAL ts IS (TIME - TIME:SECONDS) + ABS(u_time1 - u_time2).
  RETURN "[T+" + pad2Z(ts:YEAR - 1) + " " + pad3Z(ts:DAY - 1) + " "
    + pad2Z(ts:HOUR) + ":" + pad2Z(ts:MINUTE) + ":" + pad2Z(ROUND(ts:SECOND)) + "]".
}

FUNCTION formatMET
{
  LOCAL m IS ROUND(MISSIONTIME).
  IF m > INIT_MET_TS {
    SET INIT_MET_TS TO m.
    SET INIT_MET TO formatTS(TIME:SECONDS - m, TIME:SECONDS).
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
  IF LOG_FILE <> "" { LOG t TO LOG_FILE. }
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
