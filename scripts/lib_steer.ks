@LAZYGLOBAL OFF.
pOut("lib_steer.ks v1.2.4 20161121").

setTime("STEER").
GLOBAL STEER_ON IS FALSE.

FUNCTION isSteerOn
{
  RETURN STEER_ON.
}

FUNCTION steerOff
{
  IF STEER_ON { pOut("Steering disengaged."). }
  SET STEER_ON TO FALSE.
  UNLOCK STEERING.
}

FUNCTION steerTo
{
  PARAMETER fore IS { RETURN FACING:FOREVECTOR. }, top IS { RETURN FACING:TOPVECTOR. }.
  IF NOT STEER_ON { pOut("Steering engaged."). }
  SET STEER_ON TO TRUE.
  LOCK STEERING TO LOOKDIRUP(fore(),top()).
  setTime("STEER").
}

FUNCTION steerSurf
{
  PARAMETER pro IS TRUE.
  IF pro { steerTo({ RETURN SRFPROGRADE:VECTOR. }). }
  ELSE { steerTo({ RETURN SRFRETROGRADE:VECTOR. }). }
}

FUNCTION steerOrbit
{
  PARAMETER pro IS TRUE.
  IF pro { steerTo({ RETURN PROGRADE:VECTOR. }). }
  ELSE { steerTo({ RETURN RETROGRADE:VECTOR. }). }
}

FUNCTION steerNormal
{
  steerTo({ RETURN VCRS(VELOCITY:ORBIT,-BODY:POSITION). }, { RETURN SUN:POSITION. }).
}

FUNCTION steerSun
{
  steerTo({ RETURN SUN:POSITION. }).
}

FUNCTION steerAV
{
  IF LIST("LANDED","SPLASHED"):CONTAINS(STATUS) { RETURN (2 * CONSTANT:PI / BODY:ROTATIONPERIOD). }
  RETURN VANG(VELOCITYAT(SHIP,TIME:SECONDS):ORBIT,VELOCITYAT(SHIP,TIME:SECONDS+1):ORBIT) * CONSTANT:DEGTORAD.
}

FUNCTION steerOk
{
  PARAMETER aoa IS 1, precision IS 4, timeout_secs IS 60.
  IF diffTime("STEER") <= 0.1 { RETURN FALSE. }
  IF NOT STEERINGMANAGER:ENABLED { hudMsg("ERROR: Steering Manager not enabled!"). }

  IF VANG(STEERINGMANAGER:TARGET:VECTOR,FACING:FOREVECTOR) < aoa AND
     SHIP:ANGULARVEL:MAG * precision / 10 < MAX(steerAV(), 0.0005) {
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
  LOCAL cur_f IS FACING:FOREVECTOR.
  steerTo({ RETURN cur_f. }).
  WAIT UNTIL steerOk().
  steerOff().
}
