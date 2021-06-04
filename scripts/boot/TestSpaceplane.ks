@LAZYGLOBAL OFF.

IF NOT EXISTS("1:/init.ks") { RUNPATH("0:/init_select.ks"). }
RUNONCEPATH("1:/init.ks").

pOut("TestSpaceplane.ks v1.0.5 20210319").

IF cOk() { RUNPATH("0:/update.ks"). }

FOR f IN LIST(
  "lib_steer.ks",
  "lib_dv.ks",
  "lib_burn.ks",
  "lib_orbit.ks",
  "lib_node.ks",
  "lib_runmode.ks",
  "lib_reentry.ks",
  "lib_parts.ks"
) { RUNONCEPATH(loadScript(f)). }

GLOBAL NEW_NAME IS "Spaceplane Test 42".
GLOBAL SPC_APOAPSIS_INCREMENT IS 5000.
GLOBAL SPC_APOAPSIS_MULT IS 1.
GLOBAL SPC_MAX_APOAPSIS IS BODY:ATM:HEIGHT+20000.
GLOBAL SPC_MIN_APOAPSIS IS BODY:ATM:HEIGHT+10000.
GLOBAL SPC_MID_APOAPSIS IS (BODY:ATM:HEIGHT / 2) - SPC_APOAPSIS_INCREMENT.
GLOBAL SPC_MIN_SWITCH_VEL IS 1000.
GLOBAL SPC_ASCENT_PITCH_ANGLE IS 6.25.
GLOBAL SPC_PITCH_ANGLE IS 0.
GLOBAL SPC_INIT_ALT_RADAR IS 0.
GLOBAL SPC_THROTTLE IS 0.
GLOBAL SPC_HEADING IS 90.

GLOBAL SPC_HAS_JATO IS FALSE. // jet-assisted take-off
GLOBAL SPC_HAS_JASS IS FALSE. // jet-assisted supersonic
GLOBAL SPC_JASS_ACTIVE IS FALSE.
GLOBAL SPC_JASS_MIN_VEL IS 240.
GLOBAL SPC_JASS_MAX_VEL IS 320.

GLOBAL SPC_IMPACT_ADJUST IS 1.5.
GLOBAL SPC_RUNWAY_LAT IS -0.0486.
GLOBAL SPC_RUNWAY_WEST_LNG IS mAngle(-74.7245).
GLOBAL SPC_RUNWAY_EAST_LNG IS mAngle(-74.5). // TODO - this is a guess!

// TODO - move functions to a spaceplane library?
FUNCTION steerSpaceplane
{
  steerTo({ RETURN HEADING(SPC_HEADING,SPC_PITCH_ANGLE):VECTOR. }, { RETURN UP:VECTOR. }).
}

FUNCTION steerSpaceplaneAscent
{
  steerTo({ IF SPC_THROTTLE > 0 {
              IF ALTITUDE < (BODY:ATM:HEIGHT / 3) {
                RETURN HEADING(SPC_HEADING,SPC_PITCH_ANGLE):VECTOR.
              }
              LOCAL progradePitch IS 90 - VANG(SRFPROGRADE:VECTOR, UP:VECTOR).
              RETURN HEADING(SPC_HEADING, MAX(SPC_PITCH_ANGLE/2, MIN(SPC_PITCH_ANGLE,progradePitch))):VECTOR.
            } ELSE { RETURN SRFPROGRADE:VECTOR. } },
          { RETURN UP:VECTOR. }).
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

FUNCTION deorbitLongitude
{
  LOCAL massAdjust IS MASS / 10.
  RETURN SPC_RUNWAY_WEST_LNG - (150 + massAdjust).
}

FUNCTION deorbitSpaceplaneNode
{
  removeAllNodes().
  LOCAL lng_diff IS mAngle(deorbitLongitude() - SHIP:LONGITUDE).
  LOCAL lng_speed IS (360/OBT:PERIOD) - (360/BODY:ROTATIONPERIOD).
  LOCAL m_time IS TIME:SECONDS + (lng_diff / lng_speed).
  LOCAL n IS nodeAlterOrbit(m_time,35000).
  addNode(n).
  RETURN TRUE.
}

FUNCTION pFuelLevels {
  pOut("Liquid fuel: " + ROUND(SHIP:LIQUIDFUEL) + " units").
  pOut("Oxidiser:    " + ROUND(SHIP:OXIDIZER) + " units").
  LOCAL reqLF IS SHIP:OXIDIZER * 9 / 11.
  LOCAL reqOx IS SHIP:LIQUIDFUEL * 11 / 9.
  IF reqLF < SHIP:LIQUIDFUEL {
    pOut("Excess liquid fuel: " + ROUND(SHIP:LIQUIDFUEL - reqLF) + " units").
  }
  IF reqOx < SHIP:OXIDIZER {
    pOut("Excess oxidiser: " + ROUND(SHIP:OXIDIZER - reqOx) + " units").
  }
}

FUNCTION pAltAndVel {
  pOut("Alt: " + ROUND(ALTITUDE) + "m, Vel: " + ROUND(SHIP:VELOCITY:SURFACE:MAG) + "m/s").
}

IF runMode() > 0 { logOn(). }

UNTIL runMode() = 99 {
LOCAL rm IS runMode().
IF rm < 0 {
  LOCAL oldName IS SHIP:NAME.
  SET SHIP:NAME TO NEW_NAME.
  logOn().
  pOut("Vessel class: " + oldName).
  pFuelLevels().
  pOut("Ascent pitch angle: " + SPC_ASCENT_PITCH_ANGLE + " degrees").

  LOCAL jatoList IS SHIP:PARTSTAGGED("JATO").
  IF jatoList:LENGTH > 0 {
    pOut("Found " + jatoList:LENGTH + " JATO unit(s)").
    SET SPC_HAS_JATO TO TRUE.
  }
  LOCAL jassList IS SHIP:PARTSTAGGED("JASS").
  IF jassList:LENGTH > 0 {
    pOut("Found " + jassList:LENGTH + " JASS unit(s)").
    SET SPC_HAS_JASS TO TRUE.
  }
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

  WAIT 10.

  SET SPC_PITCH_ANGLE TO 90 - VANG(SHIP:FACING:VECTOR, UP:VECTOR).

  SET SPC_THROTTLE TO 1.
  steerSpaceplane().

  STAGE.
  hudMsg("Engines on!").

  WAIT 2.

  BRAKES OFF.
  hudMsg("Brakes off").

  IF SPC_HAS_JATO {
    WAIT UNTIL GROUNDSPEED > 10.
    hudMsg("JATO").
    FOR p IN SHIP:PARTSTAGGED("JATO") {
      IF p:ISTYPE("ENGINE") AND NOT p:IGNITION AND NOT p:FLAMEOUT {
        pOut("Triggering JATO unit").
        p:ACTIVATE.
      }
    }
  }

  UNTIL ALT:RADAR > (SPC_INIT_ALT_RADAR + 10) {
    SET SPC_PITCH_ANGLE TO MIN(SPC_ASCENT_PITCH_ANGLE, MAX(SPC_PITCH_ANGLE, ((GROUNDSPEED - 30) / 10))).
    WAIT 0.
  }

  pAltAndVel().
  GEAR OFF.
  SET SPC_PITCH_ANGLE TO SPC_ASCENT_PITCH_ANGLE.
  hudMsg("Retracting landing gear").

  UNTIL APOAPSIS > SPC_MAX_APOAPSIS {

    LOCAL currentVelocity IS SHIP:VELOCITY:SURFACE:MAG.

    IF SPC_HAS_JATO {
      FOR p IN SHIP:PARTSTAGGED("JATO") {
        IF p:ISTYPE("ENGINE") AND p:FLAMEOUT {
          pOut("Ditching JATO unit").
          decouplePart(p).
        }
      }

      IF SHIP:PARTSTAGGED("JATO"):LENGTH = 0 { SET SPC_HAS_JATO TO FALSE. }
    }

    IF SPC_HAS_JASS AND NOT SPC_JASS_ACTIVE {
      IF currentVelocity > SPC_JASS_MAX_VEL OR (currentVelocity > SPC_JASS_MIN_VEL AND currentVelocity < lastVelocity) {
        FOR p IN SHIP:PARTSTAGGED("JASS") {
          IF p:ISTYPE("ENGINE") AND NOT p:IGNITION AND NOT p:FLAMEOUT {
            pOut("Activating JASS unit").
            p:ACTIVATE.
          }
        }
        SET SPC_JASS_ACTIVE TO TRUE.
      }
    }

    IF SPC_HAS_JASS AND SPC_JASS_ACTIVE {
      FOR p IN SHIP:PARTSTAGGED("JASS") {
        IF p:ISTYPE("ENGINE") {
          IF p:FLAMEOUT {
            pOut("Ditching JASS unit").
            decouplePart(p).
          }
        }
      }

      IF SHIP:PARTSTAGGED("JASS"):LENGTH = 0 { 
        SET SPC_HAS_JASS TO FALSE.
        SET SPC_JASS_ACTIVE TO FALSE.
      }
    }

    IF NOT airBreathing {
      IF SPC_THROTTLE > 0 {
        // when firing rockets, turn them off once our Ap is high enough, to avoid going too fast too low
        // but if we are close to apoapsis, raise the target apoapsis
        IF APOAPSIS > SPC_MID_APOAPSIS AND ALTITUDE < SPC_MID_APOAPSIS {
          IF ALTITUDE > (APOAPSIS - SPC_APOAPSIS_INCREMENT) {
            SET SPC_MID_APOAPSIS TO SPC_MID_APOAPSIS + (SPC_APOAPSIS_INCREMENT / 2).
            pAltAndVel().
            hudMsg("Raising initial target apoapsis to " + SPC_MID_APOAPSIS + "m").
          } ELSE {
            pAltAndVel().
            hudMsg("Cruising until near apoapsis").
            SET SPC_THROTTLE TO 0.
          }
        }
      } ELSE {
        // when cruising, relight the engines if the apoapsis drops too far, and as we approach apoapsis
        IF APOAPSIS < (SPC_MID_APOAPSIS - SPC_APOAPSIS_INCREMENT) {
          SET SPC_THROTTLE TO 1.
          pAltAndVel().
          hudMsg("Apoapsis well below initial target - boost").
        } ELSE IF ALTITUDE > (APOAPSIS - SPC_APOAPSIS_INCREMENT) {
          pAltAndVel().
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
        pAltAndVel().
        hudMsg("Switching engine mode").
        // TODO - switch engine mode/intakes rather than relying on action group
        TOGGLE AG1.
        SET airBreathing TO FALSE.
        steerSpaceplaneAscent().
      }
    }

    SET lastVelocity TO currentVelocity.
    WAIT 0.
  }

  SET SPC_THROTTLE TO 0.
  steerSpaceplaneSurf().
  pAltAndVel().
  hudMsg("Coasting to apoapsis").

  UNTIL ALTITUDE > BODY:ATM:HEIGHT {

    IF SPC_THROTTLE = 0 AND APOAPSIS < SPC_MIN_APOAPSIS {
      pAltAndVel().
      hudMsg("Boost required").
      SET SPC_THROTTLE TO 1.
    } ELSE IF SPC_THROTTLE > 0 AND APOAPSIS > SPC_MAX_APOAPSIS {
      pAltAndVel().
      hudMsg("Boost complete").
      SET SPC_THROTTLE TO 0.
    }

    WAIT 0.
  }

  setIspFuelRate().
  pDV().
  steerOff().

  // TODO - extend solar panels etc (borrow from lib_launch_common) ?
  PANELS ON.

  basicLaunchCirc().

  pFuelLevels().

  runMode(49, 21).

} ELSE IF rm = 21 {

  deorbitSpaceplaneNode().
  runMode(22).

} ELSE IF rm = 22 {

  if execNode(TRUE) {
    runMode(23).
  } else {
    hudMsg("Deorbit burn not successful").
    runMode(49, 21).
  }

} ELSE IF rm = 23 {

  IF ALTITUDE > SPC_MIN_APOAPSIS {
    steerSun().
    runMode(24).
  } ELSE {
    runMode(25).
  }

} ELSE IF rm = 24 {

  IF NOT isSteerOn() { steerSun(). }
  WAIT UNTIL steerOk().
  LOCAL alt_modifier IS MAX(2500,ROUND(MASS)*100).
  LOCAL next_alt IS BODY:ATM:HEIGHT+alt_modifier.
  LOCAL warp_time IS TIME:SECONDS + secondsToAlt(SHIP,TIME:SECONDS+1,next_alt,FALSE) +1.
  IF warp_time - TIME:SECONDS > 3 AND ALTITUDE > next_alt {
    pOut("Warping until altitude " + next_alt + "m.").
    doWarp(warp_time).
  }
  runMode(25).

} ELSE IF rm = 25 {

  reentryRetract().
  PANELS OFF.
  steerSpaceplane().
  runMode(26, 27).

} ELSE IF rm = 26 {

  SET SPC_PITCH_ANGLE TO 60.
  SET SPC_HEADING TO 90. // TODO - improve
  IF NOT isSteerOn() { steerSpaceplane(). }

  hudMsg("Waiting for atmospheric interface").
  WAIT UNTIL ALTITUDE < BODY:ATM:HEIGHT.
  hudMsg("In atmosphere - waiting until periapsis dips below surface").
  WAIT UNTIL PERIAPSIS < 0.
  hudMsg("Hit abort to take manual control").
  UNTIL runMode() <> 26 {
    LOCAL impact_time IS TIME:SECONDS + secondsToAlt(SHIP,TIME:SECONDS+1,MAX(0,PERIAPSIS),FALSE) +1.
    LOCAL impact_spot IS BODY:GEOPOSITIONOF(POSITIONAT(SHIP, impact_time)).
    
    LOCAL impact_lng IS mAngle(impact_spot:LNG).

    pOut("Predicted lng: " + ROUND(impact_lng, 5) + " KSC lng: " + SPC_RUNWAY_WEST_LNG).
    SET SPC_PITCH_ANGLE TO MAX(-15, MIN(75, (SPC_IMPACT_ADJUST + impact_lng - SPC_RUNWAY_WEST_LNG) * 10)). // TODO - this is rubbish!
    
    WAIT 0.5.
  }

} ELSE IF rm = 27 {

  hudMsg("Ending Automatic Pilot!!").
  UNLOCK STEERING.
  UNLOCK THROTTLE.
  hudMsg("SAS on").
  SAS ON.
  runMode(28,99).

} ELSE IF rm = 28 {
  UNTIL runMode() <> 28 {
    pOut("Latitude: " + ROUND(LATITUDE, 3)).
    WAIT 1.
  }

} ELSE IF rm = 49 {
  steerSun().
  WAIT UNTIL runMode() <> 49.
}

}