@LAZYGLOBAL OFF.

pOut("lib_rcs.ks v1.1.0 20161102").

GLOBAL RCS_MAX_THROT IS 1. // max and minimum RCS throttles
GLOBAL RCS_MIN_THROT IS 0. //  - reduce these if RCS thrusters tend to rotate ship too much?
GLOBAL RCS_DEADBAND IS 0.  // don't fire RCS thrusters unless RCS vector magnitude is greater than this

FUNCTION changeRCSParams
{
  PARAMETER mxr IS 1, mnr IS 0, dead IS 0.
  SET RCS_MAX_THROT TO mxr.
  SET RCS_MIN_THROT TO mnr.
  SET RCS_DEADBAND TO dead.
}

FUNCTION toggleRCS
{
  PARAMETER r IS NOT RCS.
  stopTranslation().
  SET RCS TO r.
  WAIT 0.
}

FUNCTION doTranslation
{
  PARAMETER v1, m IS v1:MAG.
  IF v1:MAG > RCS_DEADBAND AND m <> 0 {
    LOCAL rcs_throt IS MIN(RCS_MAX_THROT,MAX(RCS_MIN_THROT,ABS(m))).
    IF m < 0 { SET rcs_throt TO -rcs_throt. }
    SET v1 TO v1:NORMALIZED * rcs_throt.
    SET SHIP:CONTROL:FORE TO VDOT(v1,FACING:FOREVECTOR).
    SET SHIP:CONTROL:STARBOARD TO VDOT(v1,FACING:STARVECTOR).
    SET SHIP:CONTROL:TOP TO VDOT(v1,FACING:TOPVECTOR).
  } ELSE {
    stopTranslation().
  }
}

FUNCTION stopTranslation
{
  SET SHIP:CONTROL:FORE TO 0.
  SET SHIP:CONTROL:STARBOARD TO 0.
  SET SHIP:CONTROL:TOP TO 0.
}
