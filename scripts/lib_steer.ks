@LAZYGLOBAL OFF.

pOut("lib_steer.ks v1.1.2 20160812").

setTime("STEER").
GLOBAL STEER_ON IS FALSE.

FUNCTION isSteerOn
{
  RETURN STEER_ON.
}

FUNCTION steerOn
{
  IF NOT STEER_ON { pOut("Steering engaged."). }
  setTime("STEER").
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
  PARAMETER fore IS FACING:FOREVECTOR, top IS FACING:TOPVECTOR.
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

FUNCTION steerOk
{
  PARAMETER aoa IS 1, precision IS 4, timeout_secs IS 60.
  IF diffTime("STEER") <= 0.1 { RETURN FALSE. }
  IF NOT STEERINGMANAGER:ENABLED { hudMsg("ERROR: Steering Manager not enabled!"). }

  IF VANG(STEERINGMANAGER:TARGET:VECTOR,FACING:FOREVECTOR) < aoa AND 
     SHIP:ANGULARVEL:MAG < ((10 / precision) * 2 * CONSTANT:PI / SHIP:ORBIT:PERIOD) {
    pOut("Steering aligned.").
    RETURN TRUE.
  }
  IF diffTime("STEER") > timeout_secs {
    pOut("Steering alignment timed out.").
    RETURN TRUE.
  }
  RETURN FALSE.
}

FUNCTION dampSteering
{
  pOut("Damping steering.").
  steerTo().
  WAIT UNTIL steerOk().
  steerOff().
}
