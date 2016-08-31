@LAZYGLOBAL OFF.

pOut("lib_runmode.ks v1.1.2 20160831").

GLOBAL RM_FN IS "rm.ks".
GLOBAL RM_RM IS -1.
GLOBAL RM_AM IS -1.

setTime("RM").
GLOBAL modeTime IS diffTime@:BIND("RM").
resume(RM_FN).

ON ABORT {
  PRINT "INPUT: ABORT".
  IF RM_AM > 0 { pOut("Abort to mode: " + RM_AM,FALSE). runMode(RM_AM, 0, FALSE). }
  PRESERVE.
}

FUNCTION pMode
{
  LOCAL s IS "Run mode: " + RM_RM.
  IF RM_AM > 0 { SET s TO s + ", Abort mode: " + RM_AM. }
  pOut(s).
}

FUNCTION logModes
{
  store("SET RM_RM TO " + RM_RM + ".", RM_FN).
  IF RM_AM > 0 { append("SET RM_AM TO " + RM_AM + ".", RM_FN). }
  append("pMode().", RM_FN).
}

FUNCTION runMode
{
  PARAMETER rm IS -1, am IS -1, p IS TRUE.

  IF rm >= 0 {
    IF am >= 0 { SET RM_AM TO am. }
    SET RM_RM TO rm.
    setTime("RM").
    logModes().
    if p { pMode(). }
  }
  RETURN RM_RM.
}

FUNCTION abortMode
{
  PARAMETER am IS -1.
  IF am >= 0 { SET RM_AM TO am. logModes(). }
  RETURN RM_AM.
}
