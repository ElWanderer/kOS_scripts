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

GLOBAL NEW_NAME IS "Spaceplane Test 8".
GLOBAL SPC_APOAPSIS_INCREMENT IS 5000.
GLOBAL SPC_APOAPSIS_MULT IS 1.
GLOBAL SPC_MAX_APOAPSIS IS BODY:ATM:HEIGHT+20000.
GLOBAL SPC_MIN_APOAPSIS IS BODY:ATM:HEIGHT+10000.
GLOBAL SPC_MID_APOAPSIS IS (BODY:ATM:HEIGHT / 2) - SPC_APOAPSIS_INCREMENT.
GLOBAL SPC_MIN_SWITCH_VEL IS 1000.
GLOBAL SPC_PITCH_ANGLE IS 0.
GLOBAL SPC_INIT_ALT_RADAR IS 0.
GLOBAL SPC_THROTTLE IS 0.

// TODO - move functions to a spaceplane library?
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
  SET SPC_INIT_ALT_RADAR TO ALT:RADAR.
  LOCAL airBreathing IS TRUE.
  LOCAL lastVelocity IS 0.

  BRAKES ON.
  RCS OFF.
  LOCK THROTTLE TO SPC_THROTTLE.
  SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.

  WAIT 3.

  SET SPC_PITCH_ANGLE TO 90 - VANG(SHIP:FACING:VECTOR, UP:VECTOR).

  SET SPC_THROTTLE TO 1.
  steerSpaceplaneLaunch().

  STAGE.
  hudMsg("Engines on!").

  WAIT 1.

  BRAKES OFF.
  hudMsg("Brakes off").

  UNTIL ALT:RADAR > (SPC_INIT_ALT_RADAR + 10) {
    LOCAL currentVelocity IS SHIP:VELOCITY:SURFACE:MAG.
    SET SPC_PITCH_ANGLE TO MAX(SPC_PITCH_ANGLE, ((currentVelocity - 30) / 10)).

    pOut("Vel: " + ROUND(currentVelocity) + "m/s, Pitch: " + ROUND(SPC_PITCH_ANGLE, 1)).
    WAIT 0.25.
  }

  GEAR OFF.
  SET SPC_PITCH_ANGLE TO 10.
  hudMsg("Airborne!").

  UNTIL APOAPSIS > SPC_MAX_APOAPSIS {

    LOCAL currentVelocity IS SHIP:VELOCITY:SURFACE:MAG.

    IF NOT airBreathing {
      IF SPC_THROTTLE > 0 {
        // when firing rockets, turn them off once our Ap is high enough, to avoid going too fast too low
        // but if we are close to apoapsis, raise the target apoapsis
        IF APOAPSIS > SPC_MID_APOAPSIS AND ALTITUDE < SPC_MID_APOAPSIS {
          IF ALTITUDE > (APOAPSIS - SPC_APOAPSIS_INCREMENT) {
            SET SPC_MID_APOAPSIS TO SPC_MID_APOAPSIS + (SPC_APOAPSIS_INCREMENT / 2).
            hudMsg("Raising initial target apoapsis to " + SPC_MID_APOAPSIS + "m").
          } ELSE {
            hudMsg("Cruising until near apoapsis").
            SET SPC_THROTTLE TO 0.
          }
        }
      } ELSE {
        // when cruising, relight the engines if the apoapsis drops too far, and as we approach apoapsis
        IF APOAPSIS < (SPC_MID_APOAPSIS - SPC_APOAPSIS_INCREMENT) {
          SET SPC_THROTTLE TO 1.
          hudMsg("Apoapsis well below initial target - boost").
        } ELSE IF ALTITUDE > (APOAPSIS - SPC_APOAPSIS_INCREMENT) {
          hudMsg("Nearing apoapsis - burn to raise").
          SET SPC_THROTTLE TO 1.
          SET SPC_MID_APOAPSIS TO SPC_MID_APOAPSIS + (SPC_APOAPSIS_MULT * SPC_APOAPSIS_INCREMENT).
          SET SPC_APOAPSIS_MULT TO SPC_APOAPSIS_MULT + 1.
// typical apoapsis targets will be: 30000m, 35000m, 45000m, 60000m, 90000m
          IF SPC_MID_APOAPSIS >= BODY:ATM:HEIGHT { SET SPC_MID_APOAPSIS TO SPC_MAX_APOAPSIS. }
          hudMsg("Raising initial target apoapsis to " + SPC_MID_APOAPSIS + "m").
        }
      }
    } ELSE {
      // when velocity stops increasing, switch to rockets
      // TODO - monitor fuel levels
      IF currentVelocity > SPC_MIN_SWITCH_VEL AND currentVelocity < lastVelocity {
        hudMsg("Switching engine mode").
        // TODO - switch engine mode/intakes rather than relying on action group
        TOGGLE AG1.
        SET airBreathing TO FALSE.
        steerSpaceplaneSurf().
      }
    }

    SET lastVelocity TO currentVelocity.
    pOut("Alt: " + ROUND(ALTITUDE) + "m, Vel: " + ROUND(lastVelocity) + "m/s").
    WAIT 0.25.
  }

  SET SPC_THROTTLE TO 0.
  steerSpaceplaneSurf().
  hudMsg("Coasting to apoapsis").

  UNTIL ALTITUDE > BODY:ATM:HEIGHT {

    IF SPC_THROTTLE = 0 AND APOAPSIS < SPC_MIN_APOAPSIS {
      hudMsg("Boost required").
      SET SPC_THROTTLE TO 1.
    } ELSE IF SPC_THROTTLE > 0 AND APOAPSIS > SPC_MAX_APOAPSIS {
      hudMsg("Boost complete").
      SET SPC_THROTTLE TO 0.
    }

    pOut("Alt: " + ROUND(ALTITUDE) + "m, Vel: " + ROUND(SHIP:VELOCITY:SURFACE:MAG) + "m/s").
    WAIT 0.25.
  }

  setIspFuelRate().
  pDV().
  steerOff().

  basicLaunchCirc().

  // TODO - extend solar panels etc (borrow from lib_launch_common) ?

  runMode(49, 21).
} ELSE IF rm = 21 {
  hudMsg("Reentry not implemented yet!").
  runMode(49, 21).

} ELSE IF rm = 49 {
  steerSun().
  WAIT UNTIL runMode() <> 49.
}

}