@LAZYGLOBAL OFF.


pOut("lib_steer.ks v1.1.0 20160801").

GLOBAL STEER_TIME IS TIME:SECONDS.
GLOBAL STEER_ON IS FALSE.

FUNCTION isSteerOn
{
  RETURN STEER_ON.
}

FUNCTION steerOn
{
  IF NOT STEER_ON { pOut("Steering engaged."). }
  resetSteerTime().
  SET STEER_ON TO TRUE.
}

FUNCTION steerOff
{
  IF STEER_ON { pOut("Steering disengaged."). }
  SET STEER_ON TO FALSE.
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
  LOCAL mult IS -1.
  IF pro { SET mult TO 1. }
  steerOn().
  LOCK STEERING TO LOOKDIRUP(mult * SRFPROGRADE:VECTOR, FACING:TOPVECTOR).
}

FUNCTION steerOrbit
{
  PARAMETER pro IS TRUE.
  LOCAL mult IS -1.
  IF pro { SET mult TO 1. }
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
  PARAMETER aoa IS 1, precision IS 4, timeout_secs IS 60.
  IF steerTime() <= 0.1 { RETURN FALSE. }
  IF NOT STEERINGMANAGER:ENABLED { hudMsg("ERROR: Steering Manager not enabled!"). }

  IF VANG(STEERINGMANAGER:TARGET:VECTOR,FACING:FOREVECTOR) < aoa {
    LOCAL ang_vel_diff IS ABS(SHIP:ANGULARVEL:MAG - (2 * CONSTANT:PI / SHIP:ORBIT:PERIOD)).
    IF ang_vel_diff < (0.001 / precision) {
      pOut("Steering aligned.").
      RETURN TRUE.
    }
  }
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
  WAIT UNTIL steerOk().
  steerOff().
}
