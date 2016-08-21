@LAZYGLOBAL OFF.

pOut("lib_runmode.ks v1.1.1 20160812").

GLOBAL RM_FN IS "rm.ks".
GLOBAL RM_MODE IS -1.
GLOBAL RM_ABORT IS -1.

setTime("RM").
GLOBAL modeTime IS diffTime@:BIND("RM").
resume(RM_FN).

ON ABORT {
  PRINT "ABORT TRIGGER.".
  IF RM_ABORT > 0 { runMode(RM_ABORT, 0, FALSE). }
  PRESERVE.
}

FUNCTION pMode
{
  LOCAL str IS "Run mode: " + RM_MODE + ".".
  IF RM_ABORT > 0 { SET str TO str + " Abort mode: " + RM_ABORT + ".". }
  pOut(str).
}

FUNCTION logModes
{
  store("SET RM_MODE TO " + RM_MODE + ".", RM_FN).
  append("SET RM_ABORT TO " + RM_ABORT + ".", RM_FN).
  append("pMode().", RM_FN).
}

FUNCTION runMode
{
  PARAMETER rm IS -1, am IS -1, verbose IS TRUE.

  IF rm >= 0 {
    IF am >= 0 { SET RM_ABORT TO am. }
    SET RM_MODE TO rm.
    setTime("RM").
    IF verbose {
      logModes().
      pMode().
    }
  }
  RETURN RM_MODE.
}

FUNCTION abortMode
{
  PARAMETER am IS -1.
  IF am >= 0 {
    SET RM_ABORT TO am.
    logModes().
  }
  RETURN RM_ABORT.
}
