@LAZYGLOBAL OFF.

IF NOT EXISTS("1:/init.ks") { RUNPATH("0:/init_select.ks"). }
RUNONCEPATH("1:/init.ks").

pOut("TestSpaceplane.ks v1.0.0 20210305").

IF cOk() { RUNPATH("0:/update.ks"). }

FOR f IN LIST(
  "lib_steer.ks",
  "lib_dv.ks",
  "lib_burn.ks",
  "lib_node.ks",
  "lib_runmode.ks"
) { RUNONCEPATH(loadScript(f)). }

GLOBAL NEW_NAME IS "Spaceplane Test 5".
GLOBAL SPC_PITCH_ANGLE IS 0.

FUNCTION steerSpaceplaneLaunch
{
  steerTo({ RETURN HEADING(90,SPC_PITCH_ANGLE):VECTOR. }, { RETURN UP:VECTOR. }).
}

FUNCTION steerSpaceplaneSurf
{
  steerTo({ RETURN SRFPROGRADE:VECTOR. }, { RETURN UP:VECTOR. }).
}

FUNCTION basicLaunchCirc
{
  IF NOT HASNODE {
    LOCAL m_time IS TIME:SECONDS + ETA:APOAPSIS.
    LOCAL v0 IS VELOCITYAT(SHIP,m_time):ORBIT:MAG.
    LOCAL v1 IS SQRT(BODY:MU/(BODY:RADIUS + APOAPSIS)).
    LOCAL n IS NODE(m_time, 0, 0, v1 - v0).
    addNode(n).
  }
  RETURN execNode(TRUE) AND PERIAPSIS > BODY:ATM:HEIGHT.
}

IF runMode() > 0 { logOn(). }

UNTIL runMode() = 99 {
LOCAL rm IS runMode().
IF rm < 0 {
  SET SHIP:NAME TO NEW_NAME.
  logOn().
  runMode(1).

} ELSE IF rm = 1 {
  // TODO - break this up!
  LOCAL initialRadarAlt IS ALT:RADAR.
  LOCAL airBreathing IS TRUE.
  LOCAL lastVelocity IS 0.

  BRAKES ON.
  RCS OFF.
  LOCK THROTTLE TO 0.
  SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.

  WAIT 3.

  SET SPC_PITCH_ANGLE TO 90 - VANG(SHIP:FACING:VECTOR, UP:VECTOR).

  LOCK THROTTLE TO 1.
  steerSpaceplaneLaunch().

  STAGE.
  hudMsg("Engines on!").

  WAIT 1.

  BRAKES OFF.
  hudMsg("Brakes off").

  UNTIL ALT:RADAR > (initialRadarAlt + 5) {
    LOCAL currentVelocity IS SHIP:VELOCITY:SURFACE:MAG.
    SET SPC_PITCH_ANGLE TO MAX(SPC_PITCH_ANGLE, ((currentVelocity - 40) / 10)).

    pOut("Vel: " + ROUND(currentVelocity) + "m/s, Pitch: " + ROUND(SPC_PITCH_ANGLE, 1)).
    WAIT 0.25.
  }

  GEAR OFF.
  SET SPC_PITCH_ANGLE TO 10.
  hudMsg("Airborne!").

  UNTIL APOAPSIS > (BODY:ATM:HEIGHT + 20000) {

    // TODO - monitor altitude/velocity
    // TODO - monitor engine performance
    // TODO - monitor fuel levels
    // TODO - switch engine mode/intakes

    LOCAL currentVelocity IS SHIP:VELOCITY:SURFACE:MAG.

    IF currentVelocity > 1000 AND currentVelocity < lastVelocity {
      hudMsg("Switching engine modes").
      TOGGLE AG1.
    }

    SET lastVelocity TO currentVelocity.
    pOut("Alt: " + ROUND(ALTITUDE) + "m, Vel: " + ROUND(lastVelocity) + "m/s").
    WAIT 0.25.
  }

  LOCK THROTTLE TO 0.
  steerSpaceplaneSurf().
  hudMsg("Coasting to apoapsis").

  UNTIL ALTITUDE > BODY:ATM:HEIGHT {
  // TODO - boost if apoapsis drops too far
    pOut("Alt: " + ROUND(ALTITUDE) + "m, Vel: " + ROUND(SHIP:VELOCITY:SURFACE:MAG) + "m/s").
    WAIT 0.25.
  }

  setIspFuelRate().
  pDV().
  steerOff().

  basicLaunchCirc().

  runMode(49).

} ELSE IF rm = 49 {
  steerSun().
  WAIT UNTIL runMode() <> 49.
}

}