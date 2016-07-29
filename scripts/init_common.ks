@LAZYGLOBAL OFF.
IF WARP <> 0 { SET WARP TO 0. }
WAIT UNTIL SHIP:UNPACKED.

GLOBAL STAGE_TIME IS TIME:SECONDS.
GLOBAL LOG_FILE IS "".
GLOBAL g0 IS 9.80665.

CORE:DOEVENT("Open Terminal").
CLEARSCREEN.
pOut("init_common.ks v1.0.0 20160726").

FUNCTION padZ
{
  PARAMETER t, l IS 2.
  RETURN (""+t):PADLEFT(l):REPLACE(" ","0").
}

FUNCTION formatMET
{
  LOCAL ts IS TIME + MISSIONTIME - TIME:SECONDS.
  RETURN "[T+" + padZ(ts:YEAR - 1) + "-" + padZ(ts:DAY - 1,3) + " "
   + padZ(ts:HOUR) + ":" + padZ(ts:MINUTE) + ":" + padZ(ROUND(ts:SECOND)) + "] ".
}

FUNCTION logOn
{
  PARAMETER lf IS "0:/log/" + SHIP:NAME:REPLACE(" ","_") + ".txt".
  IF lf <> "" {
    SET LOG_FILE TO lf.
    doLog(SHIP:NAME).
    pOut("Log enabled: " + LOG_FILE).
  }
}

FUNCTION logOff
{
  pOut("Log disabled.").
  SET LOG_FILE TO "".
}

FUNCTION doLog
{
  PARAMETER t.
  LOG t TO LOG_FILE.
}

FUNCTION pOut
{
  PARAMETER t, wt IS TRUE.
  IF wt { SET t TO formatMET() + t. }
  PRINT t.
  IF LOG_FILE <> "" { doLog(t). }
}

FUNCTION hudMsg
{
  PARAMETER t, c IS YELLOW, s IS 40.
  HUDTEXT(t, 3, 2, s, c, FALSE).
  pOut(t).
}

FUNCTION doStage
{
  pOut("Staging.").
  SET STAGE_TIME TO TIME:SECONDS.
  STAGE.
}

FUNCTION stageTime
{
  RETURN TIME:SECONDS - STAGE_TIME.
}

FUNCTION mAngle
{
  PARAMETER a.
  UNTIL a >= 0 { SET a TO a + 360. }
  RETURN MOD(a,360).
}