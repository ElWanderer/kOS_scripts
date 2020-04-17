@LAZYGLOBAL OFF.
pOut("lib_launch_common.ks v1.5.0 20200417").

FOR f IN LIST(
  "lib_burn.ks",
  "lib_runmode.ks",
  "lib_parts.ks",
  "lib_orbit.ks"
) { RUNONCEPATH(loadScript(f)). }

GLOBAL LCH_AP IS 0.
GLOBAL LCH_INIT_AP IS 0.
GLOBAL LCH_MAX_THRUST IS 0.
GLOBAL LCH_ORBIT_VEL IS 0.
GLOBAL LCH_VEC IS UP:VECTOR.
GLOBAL LCH_I IS 0.
GLOBAL LCH_AN IS TRUE.
GLOBAL LCH_PITCH_ALT IS 250.
GLOBAL LCH_CURVE_ALT IS BODY:ATM:HEIGHT * 0.9.
GLOBAL LCH_FAIRING_ALT IS BODY:ATM:HEIGHT * 0.75.
GLOBAL LCH_LES_NAMES IS LIST("LaunchEscapeSystem","NBLAStower").
GLOBAL LCH_LES_PARTS IS LIST().
GLOBAL LCH_HAS_LES IS FALSE.
GLOBAL LCH_HAS_FAIRING IS FALSE.
GLOBAL LCH_CLAMP_PARTS IS LIST().
GLOBAL LCH_HAS_CLAMPS IS FALSE.

FUNCTION killThrot
{
  LOCK THROTTLE TO 0.
  SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
}

FUNCTION mThrust
{
  PARAMETER mt IS -1.
  IF mt >= 0 { SET LCH_MAX_THRUST TO mt. }
  RETURN LCH_MAX_THRUST.
}

FUNCTION hasFairing
{
  RETURN LCH_HAS_FAIRING.
}

FUNCTION hasLES
{
  RETURN LCH_HAS_LES.
}

FUNCTION hasClamps
{
  RETURN LCH_HAS_CLAMPS.
}

FUNCTION disableLES
{
  SET LCH_HAS_LES TO FALSE.
}

FUNCTION checkFairing
{
  SET LCH_HAS_FAIRING TO FALSE.
  FOR m IN SHIP:MODULESNAMED("ModuleProceduralFairing") { IF m:HASEVENT("deploy") {
    SET LCH_HAS_FAIRING TO TRUE.
    BREAK.
  }}
}

FUNCTION checkLES
{
  LCH_LES_PARTS:CLEAR().
  FOR ln IN LCH_LES_NAMES { FOR p IN SHIP:PARTSNAMED(ln) {
    LCH_LES_PARTS:ADD(p).
    SET LCH_HAS_LES TO TRUE.
  } }
}

FUNCTION checkClamps
{
  LCH_CLAMP_PARTS:CLEAR().
  SET LCH_HAS_CLAMPS TO FALSE.
  FOR m IN SHIP:MODULESNAMED("LaunchClamp") { IF m:HASEVENT("Release Clamp") {
    LCH_CLAMP_PARTS:ADD(m:PART).
    SET LCH_HAS_CLAMPS TO TRUE.
  }}
}

FUNCTION releaseClamps
{
  LOCAL can_stage IS TRUE.
  FOR c IN LCH_CLAMP_PARTS { IF c:STAGE <> STAGE:NUMBER-1 { SET can_stage TO FALSE. BREAK. } }

  IF can_stage { IF STAGE:READY { doStage(). } }
  ELSE { FOR c IN LCH_CLAMP_PARTS { partEvent("Release Clamp", "LaunchClamp", c). } }
}

FUNCTION verifyClamps
{
  PARAMETER loud IS TRUE.

  LOCAL clamps_in_first_stage IS FALSE.
  LOCAL engines_in_first_stage IS FALSE.

  FOR c IN LCH_CLAMP_PARTS { IF c:STAGE = STAGE:NUMBER-1 { SET clamps_in_first_stage TO TRUE. BREAK. } }

  LOCAL el IS LIST().
  LIST ENGINES IN el.
  FOR e IN el { IF e:STAGE = STAGE:NUMBER-1 { SET engines_in_first_stage TO TRUE. } }

  IF NOT clamps_in_first_stage OR engines_in_first_stage { RETURN TRUE. }

  IF loud { hudMsg("Check yo' stagin'!", RED, 50). }
  RETURN FALSE.
}

FUNCTION launchAP
{
  parameter ap.
  SET LCH_AP TO ap.
  IF LCH_INIT_AP = 0 { SET LCH_INIT_AP TO ap. }
  SET LCH_ORBIT_VEL TO SQRT(BODY:MU/(BODY:RADIUS + ap)).
}

FUNCTION launchInit
{
  PARAMETER ap,az,i,pitch_alt.
  launchAP(ap).
  SET LCH_I TO i.
  SET LCH_AN TO (az < 90 OR az > 270 OR ((az = 90 OR az = 270) AND LATITUDE < 0)).
  SET LCH_PITCH_ALT TO pitch_alt.

  checkFairing().
  checkLES().
  checkClamps().
  IF NOT verifyClamps() { WAIT UNTIL verifyClamps(FALSE). }

  IF CRAFT_SPECIFIC:HASKEY("LCH_RCS_ON_ALT") {
    IF ALTITUDE > CRAFT_SPECIFIC["LCH_RCS_ON_ALT"] { RCS ON. }
    ELSE { WHEN ALTITUDE > CRAFT_SPECIFIC["LCH_RCS_ON_ALT"] THEN { RCS ON. } }
  }
  IF CRAFT_SPECIFIC:HASKEY("LCH_RCS_OFF_ALT") {
    IF ALTITUDE > CRAFT_SPECIFIC["LCH_RCS_OFF_ALT"] { RCS OFF. }
    ELSE { WHEN ALTITUDE > CRAFT_SPECIFIC["LCH_RCS_OFF_ALT"] THEN { RCS OFF. } }
  }

  IF runMode() < 0 {
    hudMsg("Prepare for launch...").
    pOut("Launch to apoasis: " + ap).
    runMode(1).
  }
}

FUNCTION launchStaging
{
  LOCAL mt IS SHIP:MAXTHRUSTAT(0).
  LOCAL prev_mt IS mThrust().
  IF mt = 0 OR mt < prev_mt {
    IF STAGE:READY AND stageTime() > 0.5 {
      IF moreEngines(TRUE) {
        mThrust(0).
        doStage().
      } ELSE {
        hudMsg("No more engines to fire.").
        SET ABORT TO NOT ABORT.
      }
    }
  } ELSE IF prev_mt = 0 AND mt > 0 AND stageTime() > 0.1 {
    pTWR().
    mThrust(mt).
    IF hasFairing() { checkFairing(). }
    IF hasLES() { checkLES(). }
    IF hasClamps() { checkClamps(). }
  }
}

FUNCTION launchFairing
{
  IF (ALTITUDE > LCH_FAIRING_ALT AND currentThrust() > 0) OR ALTITUDE > (BODY:ATM:HEIGHT * 0.98) {
    FOR f IN SHIP:MODULESNAMED("ModuleProceduralFairing") { modDo("deploy", f). }
    SET LCH_HAS_FAIRING TO FALSE.
  }
}

FUNCTION launchExtend
{
  PANELS ON.
  FOR a IN SHIP:MODULESNAMED("ModuleDeployableAntenna") { modDo("Extend Antenna", a). }
}

FUNCTION sepLauncher
{
  IF SHIP:PARTSTAGGED("LAUNCHER"):LENGTH > 0 {
    steerOrbit().
    WAIT UNTIL steerOk().
    UNTIL SHIP:PARTSTAGGED("LAUNCHER"):LENGTH = 0 {
      WAIT UNTIL STAGE:READY AND stageTime() > 0.5.
      doStage().
    }
    WAIT 2.
    dampSteering().
  }

  IF NOT CRAFT_SPECIFIC:HASKEY("LCH_NO_STAGE_IN_ORBIT") {
    UNTIL SHIP:AVAILABLETHRUST > 0 OR NOT moreEngines() {
      WAIT UNTIL STAGE:READY AND stageTime() > 0.5.
      doStage().
    }
  }
}

FUNCTION rotateVelocity
{
  PARAMETER v0, spot, des_bearing.

  LOCAL spot_up_v IS (spot:ALTITUDEPOSITION(1000)-spot:ALTITUDEPOSITION(0)):NORMALIZED.
  LOCAL north_v IS VXCL(spot_up_v, LATLNG(MIN(90, spot:LAT+1),spot:LNG):POSITION - spot:POSITION):NORMALIZED.
  LOCAL east_v IS VCRS(spot_up_v, north_v):NORMALIZED.
  LOCAL v0_bearing IS ARCTAN2(VDOT(v0, east_v), VDOT(v0, north_v)).

  RETURN ANGLEAXIS(des_bearing - v0_bearing, spot_up_v) * v0.
}

FUNCTION launchCirc
{
  IF NOT HASNODE {
    LOCAL m_time IS TIME:SECONDS + ETA:APOAPSIS.
    LOCAL m_spot IS BODY:GEOPOSITIONOF(POSITIONAT(SHIP,m_time)).
    LOCAL az IS launchBearing(m_spot:LAT, V(0,0,0), -1).
    LOCAL v1 IS rotateVelocity(VELOCITYAT(SHIP,m_time):ORBIT, m_spot, az):NORMALIZED * SQRT(BODY:MU/(BODY:RADIUS + APOAPSIS)).

    addNode(nodeToVector(v1, m_time)).
  }
  RETURN execNode(TRUE) AND PERIAPSIS > BODY:ATM:HEIGHT.
}

FUNCTION launchCoast
{
  PARAMETER exit_mode, flight_mode.
  IF ALTITUDE > BODY:ATM:HEIGHT {
    setIspFuelRate().
    pDV().
    steerOff().
    launchExtend().
    IF launchCirc() {
      sepLauncher().
      IF CRAFT_SPECIFIC:HASKEY("LCH_RCS_OFF_IN_ORBIT") { RCS OFF. }
      pDV().
      runMode(exit_mode,0).
    } ELSE {
      launchAP(APOAPSIS + 10000).
      launchLocks().
      runMode(flight_mode).
    }
  } ELSE IF APOAPSIS < MAX(BODY:ATM:HEIGHT + 2500,LCH_INIT_AP - 2500) {
    launchAP(LCH_INIT_AP + ROUND(ABS(BODY:ATM:HEIGHT-ALTITUDE)/2)).
    launchLocks().
    runMode(flight_mode).
  }
}

FUNCTION launchFlight
{
  PARAMETER next_mode.
  IF NOT isSteerOn() { steerLaunch(). }
  launchSteerUpdate().
  launchStaging().
  IF APOAPSIS > LCH_AP {
    killThrot().
    steerSurf().
    runMode(next_mode).
  }
}

FUNCTION launchLiftOff
{
  PARAMETER next_mode.
  IF NOT isSteerOn() { steerLaunch(). }
  IF hasClamps() {
    LOCAL total_thrust IS 0.
    LOCAL all_engines_go IS TRUE.
    FOR e IN DV_ACTIVE_ENGINES {
      SET total_thrust TO total_thrust + e:THRUST.
      IF e:THRUST < (0.9 * e:AVAILABLETHRUST) { SET all_engines_go TO FALSE. }
    }
    IF all_engines_go {
      IF total_thrust / (g0 * SHIP:MASS) > 1.05 {
        WAIT 0.
        releaseClamps().
        WAIT 0.
        checkClamps().
      } ELSE IF stageTime() > 0.1 AND STAGE:READY AND verifyClamps(FALSE) {
        doStage().
        checkClamps().
      } ELSE IF modeTime() > 30 {
        hudMsg("Not enough thrust to launch!", RED, 40).
        hudMsg("Shutting down engines.", RED, 50).
        LOCK THROTTLE TO 0.
        WAIT 0.
        runMode(99).
      }
    }
  } ELSE {
    hudMsg("Liftoff!").
    runMode(next_mode).
  }
}

FUNCTION launchIgnition
{
  PARAMETER next_mode.
  IF NOT isSteerOn() { steerLaunch(). }
  IF modeTime() > 3 {
    doStage().
    If hasClamps() { checkClamps(). }
    hudMsg("Ignition!").
    runMode(next_mode).
  }
}

FUNCTION launchLocks
{
  steerLaunch().
  mThrust(0).
  LOCK THROTTLE TO 1.
}

FUNCTION bearingSouth
{
  IF ALT:RADAR < (LCH_PITCH_ALT * 10) { RETURN NOT LCH_AN. }
  RETURN BODY:GEOPOSITIONOF(POSITIONAT(SHIP,TIME:SECONDS+5)):LAT < LATITUDE.
}

FUNCTION launchBearing
{
  PARAMETER lat IS SHIP:LATITUDE, v0 IS SHIP:VELOCITY:ORBIT, v1_mag IS LCH_ORBIT_VEL.
  IF (LCH_I > 0 AND ABS(lat) < 90 AND MIN(LCH_I,180 - LCH_I) >= ABS(lat)) {
    LOCAL az IS ARCSIN( COS(LCH_I) / COS(lat) ).
    IF bearingSouth() { SET az TO mAngle(180 - az). }
    IF v0:MAG >= v1_mag { RETURN az. }
    LOCAL x IS (v1_mag * SIN(az)) - VDOT(v0,HEADING(90,0):VECTOR).
    LOCAL y IS (v1_mag * COS(az)) - VDOT(v0,HEADING(0,0):VECTOR).
    RETURN mAngle(90 - ARCTAN2(y, x)).
  } ELSE {
    IF LCH_I < 90 { RETURN 90. }
    ELSE { RETURN 270. }
  }
}

FUNCTION launchPitch
{
  IF ALT:RADAR < LCH_PITCH_ALT { RETURN 90. }
  RETURN MIN(90,MAX(0, MAX(90 * (1 - SQRT(ALTITUDE/LCH_CURVE_ALT)),45-VERTICALSPEED))).
}

FUNCTION launchMaxSteer
{
  IF ALTITUDE > BODY:ATM:HEIGHT / 3 { RETURN (120 * ALTITUDE / BODY:ATM:HEIGHT)-35. }
  IF SHIP:VELOCITY:SURFACE:MAG < 99 { RETURN 15. }
  RETURN 5.
}

FUNCTION launchSteerUpdate
{
  LOCAL cur_v IS SHIP:VELOCITY:SURFACE.
  LOCAL new_v IS HEADING(launchBearing(),launchPitch()):VECTOR.
  LOCAL max_ang IS launchMaxSteer().
  IF VANG(cur_v,new_v) > max_ang { SET new_v TO ANGLEAXIS(max_ang,VCRS(cur_v,new_v)) * cur_v. }
  SET LCH_VEC TO new_v.
}

FUNCTION steerLaunch
{
  steerTo({ RETURN LCH_VEC. }).
}
