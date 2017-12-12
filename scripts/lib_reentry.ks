@LAZYGLOBAL OFF.
pOut("lib_reentry.ks v1.3.0 20171212").

FOR f IN LIST(
  "lib_chutes.ks",
  "lib_parts.ks",
  "lib_runmode.ks",
  "lib_node.ks",
  "lib_steer.ks",
  "lib_orbit.ks"
) { RUNONCEPATH(loadScript(f)). }

FUNCTION deorbitNode
{
  removeAllNodes().
  LOCAL lng_diff IS mAngle(170 - SHIP:LONGITUDE).
  LOCAL lng_speed IS (360/OBT:PERIOD) - (360/BODY:ROTATIONPERIOD).
  LOCAL m_time IS TIME:SECONDS + (lng_diff / lng_speed).
  LOCAL n IS nodeAlterOrbit(m_time,29000).
  addNode(n).
  RETURN TRUE.
}

FUNCTION reentryExtend
{
  PANELS ON.
  FOR m IN SHIP:MODULESNAMED("ModuleDeployableAntenna") { modDo("Extend Antenna", m). }
}

FUNCTION reentryRetract
{
  PANELS OFF.
  FOR m IN SHIP:MODULESNAMED("ModuleDeployableAntenna") { modDo("Retract Antenna", m). }
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
      doWarp(warp_time).
    }
    runMode(56).
  } ELSE IF rm = 56 {
    IF ALTITUDE < alt_stage { runMode(60). }
  } ELSE IF rm = 60 {
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
      WAIT 10.
      steerOff().
      runMode(70).
    }
  } ELSE IF rm = 70 {
    disarmChutes(FALSE).
    LOCAL warp_time IS TIME:SECONDS + secondsToAlt(SHIP,TIME:SECONDS+1,alt_atm,FALSE) +1.
    IF warp_time - TIME:SECONDS > 3 AND ALTITUDE > alt_atm {
      pOut("Warping until altitude " + alt_atm + "m.").
      doWarp(warp_time).
    }
    runMode(74).
  } ELSE IF rm = 74 {
    IF ALTITUDE < alt_atm {
      WHEN ALTITUDE < (BODY:ATM:HEIGHT * 0.99) THEN {
        UNTIL WARPMODE = "PHYSICS" AND WARP > 0 { SET WARPMODE TO "PHYSICS". SET WARP TO 3. WAIT 0.2. }
        WHEN ALT:RADAR < 1000 OR ALTITUDE > BODY:ATM:HEIGHT THEN { killWarp(). }
      }
      runMode(76).
    }
  } ELSE IF rm = 76 {
    reentryRetract().
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
    reentryExtend().
    steerSun().
    LOCAL alt_atm_by_ecc IS BODY:ATM:HEIGHT + ROUND(SHIP:OBT:ECCENTRICITY,2) * 15000.
    SET alt_atm TO MIN(MAX(BODY:ATM:HEIGHT,APOAPSIS-500),alt_atm_by_ecc).
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
