@LAZYGLOBAL OFF.

pOut("lib_reentry.ks v1.1.0 20161101").

FOR f IN LIST(
  "lib_chutes.ks",
  "lib_parts.ks",
  "lib_runmode.ks",
  "lib_node.ks",
  "lib_steer.ks",
  "lib_orbit.ks"
) { RUNONCEPATH(loadScript(f)). }

FUNCTION pReentry
{
  LOCAL u_time IS TIME:SECONDS + 0.05.
  LOCAL pe_eta IS secondsToTA(SHIP,u_time,0).
  LOCAL pe_spot IS BODY:GEOPOSITIONOF(POSITIONAT(SHIP,u_time + pe_eta)).
  LOCAL pe_lng IS mAngle(pe_spot:LNG - (pe_eta * 360 / BODY:ROTATIONPERIOD)).

  LOCAL atm_eta IS secondsToAlt(SHIP,u_time,BODY:ATM:HEIGHT,FALSE).
  LOCAL atm_spot IS BODY:GEOPOSITIONOF(POSITIONAT(SHIP,u_time + atm_eta)).
  LOCAL atm_lng IS mAngle(atm_spot:LNG - (atm_eta * 360 / BODY:ROTATIONPERIOD)).

  pOut("Re-entry orbit details:").
  pOut("Inclination:  " + ROUND(SHIP:OBT:INCLINATION,1) + " degrees.").
  pOut("Apoapsis:  " + ROUND(APOAPSIS) + "m.").
  pOut("Periapsis: " + ROUND(PERIAPSIS) + "m.").
  pOut("Longitude at atmospheric interface:  " + ROUND(atm_lng,1) + " degrees.").
  pOut("Longitude at periapsis:              " + ROUND(pe_lng,1) + " degrees.").
}

FUNCTION deorbitNode
{
  removeAllNodes().
  LOCAL lng_diff IS mAngle(150 - SHIP:LONGITUDE).
  LOCAL lng_speed IS (360/OBT:PERIOD) - (360/BODY:ROTATIONPERIOD).
  LOCAL m_time IS TIME:SECONDS + (lng_diff / lng_speed).
  LOCAL n IS nodeAlterOrbit(m_time,29000).
  addNode(n).
  RETURN TRUE.
}

// move these back to lib_orbit if anything else needs them
FUNCTION firstTAAtRadius
{
  PARAMETER orb, r.
  LOCAL e IS orb:ECCENTRICITY.
  IF e > 0 AND e <> 1 AND r > 0 { RETURN calcTa(orb:SEMIMAJORAXIS,e,r). }
  ELSE { RETURN -1. }
}

FUNCTION secondTAAtRadius
{
  PARAMETER orb, r.
  LOCAL ta2 IS -1.
  LOCAL ta1 IS firstTAAtRadius(orb,r).
  IF ta1 >= 0 { SET ta2 TO 360 - ta1. }
  RETURN ta2.
}

FUNCTION secondsToAlt
{
  PARAMETER craft, u_time, t_alt. // metres
  PARAMETER ascending.

  LOCAL secs IS -1.
  LOCAL orb IS ORBITAT(craft,u_time).
  LOCAL e IS orb:ECCENTRICITY.
  LOCAL t_ta IS -1.
  IF t_alt > orb:PERIAPSIS AND (t_alt < orb:APOAPSIS OR e > 1) {
    IF ascending { SET t_ta TO firstTAAtRadius(orb,orb:BODY:RADIUS + t_alt). }
    ELSE { SET t_ta TO secondTAAtRadius(orb,orb:BODY:RADIUS + t_alt). }
    SET secs TO secondsToTA(craft,u_time,t_ta).
  }
  RETURN secs.
}

FUNCTION doReentry
{
  PARAMETER stages, exit_mode.

  LOCAL LOCK rm TO runMode().

  IF rm < 51 OR rm > 98 { runMode(51). }

  pOut("Re-entry program initiated.").

  LOCAL e IS MAX(0.1,ROUND(SHIP:OBT:ECCENTRICITY,1)).
  LOCAL alt_stage IS BODY:ATM:HEIGHT + (e * 150000).
  LOCAL alt_atm IS BODY:ATM:HEIGHT + (e * 15000).
  LOCAL alt_steer_off IS MAX(BODY:ATM:HEIGHT - 20000, BODY:ATM:HEIGHT / 2).
  LOCAL alt_chutes IS MIN(20000, alt_steer_off - 1000).

  pOut("Stage (if needed) below: " + ROUND(alt_stage/1000) + "km.").
  pOut("Steer retrograde below: " + ROUND(alt_atm/1000) + "km.").
  pOut("Steering off below: " + ROUND(alt_steer_off/1000) + "km.").
  pOut("Prepare parachutes below: " + ROUND(alt_chutes/1000) + "km.").

UNTIL rm = exit_mode
{
  IF rm = 51 {
    pReentry().
    IF ALTITUDE > alt_stage {
      steerSun().
      runMode(52).
    } ELSE { runMode(60). }
  } ELSE IF rm = 52 {
    IF NOT isSteerOn() { runMode(51). }
    IF steerOk() {
      steerOff().
      runMode(54).
    }
  } ELSE IF rm = 54 {
    LOCAL warp_time IS TIME:SECONDS + secondsToAlt(SHIP,TIME:SECONDS+1,alt_stage,FALSE) +1.
    IF warp_time - TIME:SECONDS > 3 AND ALTITUDE > alt_stage {
      pOut("Warping until altitude " + alt_stage + "m.").
      WARPTO(warp_time).
      WAIT UNTIL warp_time < TIME:SECONDS.
    }
    runMode(56).
  } ELSE IF rm = 56 {
    IF ALTITUDE < alt_stage { runMode(60). }
  } ELSE IF rm = 60 {
    pReentry().
    IF stages > 0 OR SHIP:PARTSTAGGED("FINAL"):LENGTH > 0 {
      steerNormal().
      runMode(64).
    } ELSE { runMode(70). }
  } ELSE IF rm = 64 {
    IF NOT isSteerOn() { steerNormal(). }
    IF steerOk() OR ALTITUDE < alt_atm { runMode(66). }
  } ELSE IF rm = 66 {
    LOCAL done IS FALSE.
    IF stages > 0 {
      IF STAGE:READY {
        doStage().
        SET stages TO stages - 1.
        store("doReentry("+stages+","+exit_mode+").").
      }
    } ELSE IF SHIP:PARTSTAGGED("FINAL"):LENGTH > 0 {
      IF STAGE:READY { doStage(). }
    } ELSE {
      steerOff().
      WAIT 1.
      runMode(70).
    }
  } ELSE IF rm = 70 {
    disarmChutes().
    LOCAL warp_time IS TIME:SECONDS + secondsToAlt(SHIP,TIME:SECONDS+1,alt_atm,FALSE) +1.
    IF warp_time - TIME:SECONDS > 3 AND ALTITUDE > alt_atm {
      pOut("Warping until altitude " + alt_atm + "m.").
      WARPTO(warp_time).
      WAIT UNTIL warp_time < TIME:SECONDS.
    }
    runMode(74).
  } ELSE IF rm = 74 {
    IF ALTITUDE < alt_atm { runMode(76). }
  } ELSE IF rm = 76 {
    PANELS OFF.
    steerSurf(FALSE).
    SET alt_atm TO BODY:ATM:HEIGHT.
    runMode(78).
  } ELSE IF rm = 78 {
    IF NOT isSteerOn() { steerSurf(FALSE). }
    IF ALTITUDE > alt_atm AND VERTICALSPEED > 0 { runMode(82). } 
    IF ALTITUDE < alt_steer_off {
      steerOff().
      runMode(80).
    }
  } ELSE IF rm = 80 {
    IF ALTITUDE > alt_atm AND VERTICALSPEED > 0 { runMode(82). } 
    IF ALTITUDE < alt_chutes {
      hudMsg("Will deploy parachutes once safe.").
      listChutes().
      runMode(90).
    }
  } ELSE IF rm = 82 {
    pOut("Leaving atmosphere.").
    PANELS ON.
    steerSun().
    SET alt_atm TO BODY:ATM:HEIGHT + (MAX(0.1,ROUND(SHIP:OBT:ECCENTRICITY,1)) * 15000).
    pOut("Steer retrograde below: " + ROUND(alt_atm/1000) + "km.").
    runMode(86).
  } ELSE IF rm = 86 {
    IF NOT isSteerOn() { steerSun(). }
    IF ALTITUDE < alt_atm AND VERTICALSPEED < 0 { runMode(76). }
    ELSE IF steerOk() {
      steerOff().
      runMode(70).
    }
  } ELSE IF rm = 90 {
    IF hasChutes() { deployChutes(). }
    IF LIST("LANDED","SPLASHED"):CONTAINS(STATUS) {
      hudMsg("Touchdown.").
      pOut("Touchdown longitude: " + ROUND(mAngle(SHIP:LONGITUDE),1) + " degrees.").
      runMode(exit_mode).
    }
  } ELSE {
    pOut("Unexpected run mode: " + rm).
    runMode(exit_mode).
  }

  WAIT 0.
}
  IF isSteerOn() { steerOff(). }
}
