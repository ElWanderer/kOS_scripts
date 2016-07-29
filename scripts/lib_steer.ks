@LAZYGLOBAL OFF.


pOut("lib_steer.ks v1.0 20160714").

GLOBAL STEER_TIME IS TIME:SECONDS.
GLOBAL STEER_OK_TIME IS TIME:SECONDS.
GLOBAL STEER_ON IS FALSE.

FUNCTION isSteerOn
{
  RETURN STEER_ON.
}

FUNCTION steerOn
{
  resetSteerTime().
  resetSteerOkTime().
  SET STEER_ON TO TRUE.
  pOut("Steering engaged.").
}

FUNCTION steerOff
{
  SET STEER_ON TO FALSE.
  pOut("Steering disengaged.").
  UNLOCK STEERING.
}

FUNCTION steerTo
{
  PARAMETER fore, top IS FACING:TOPVECTOR.
  steerOn().
  LOCK STEERING TO LOOKDIRUP(fore,top).
}

FUNCTION steerSurf
{
  PARAMETER pro IS TRUE.
  LOCAL mult IS 1.
  IF NOT pro { SET mult TO -1. }
  steerOn().
  LOCK STEERING TO LOOKDIRUP(mult * SRFPROGRADE:VECTOR, FACING:TOPVECTOR).
}

FUNCTION steerOrbit
{
  PARAMETER pro IS TRUE.
  LOCAL mult IS 1.
  IF NOT pro { SET mult TO -1. }
  steerOn().
  LOCK STEERING TO LOOKDIRUP(mult * PROGRADE:VECTOR, FACING:TOPVECTOR).
}

FUNCTION steerNormal
{
  steerTo(VCRS(VELOCITY:ORBIT,-BODY:POSITION), SUN:POSITION).
}

FUNCTION steerSun
{
  steerTo(SUN:POSITION).
}

FUNCTION resetSteerOkTime
{
  SET STEER_OK_TIME TO TIME:SECONDS.
}

FUNCTION steerOkTime
{
  RETURN TIME:SECONDS - STEER_OK_TIME.
}

FUNCTION resetSteerTime
{
  SET STEER_TIME TO TIME:SECONDS.
}

FUNCTION steerTime
{
  RETURN TIME:SECONDS - STEER_TIME.
}

FUNCTION steerOk
{
  PARAMETER aoa IS 1, secs IS 4, timeout_secs IS 60.
  IF steerTime() <= 0.1 { RETURN FALSE. }
  IF NOT STEERINGMANAGER:ENABLED { pOut("CRASH: Steering Manager not enabled when expected to be."). }
  IF VANG(STEERINGMANAGER:TARGET:VECTOR,FACING:FOREVECTOR) < aoa {
    IF steerOkTime() > secs {
      pOut("Steering aligned.").
      RETURN TRUE.
    }
  } ELSE { resetSteerOkTime(). }
  IF steerTime() > timeout_secs {
    pOut("Steering alignment timed out.").
    RETURN TRUE.
  }
  RETURN FALSE.
}

FUNCTION dampSteering
{
  pOut("Damping steering.").
  steerTo(FACING:FOREVECTOR,FACING:TOPVECTOR).
  WAIT UNTIL steerOk(1,2).
  steerOff().
  SAS ON.
  WAIT 3.
  SAS OFF.
}