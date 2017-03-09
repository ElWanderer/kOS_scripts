@LAZYGLOBAL OFF.
pOut("lib_launch_common.ks v1.4.0 20170309").

FOR f IN LIST(
  "lib_burn.ks",
  "lib_runmode.ks"
) { RUNONCEPATH(loadScript(f)). }

GLOBAL LCH_AP IS 0.
GLOBAL LCH_MAX_THRUST IS 0.
GLOBAL LCH_ORBIT_VEL IS 0.
GLOBAL LCH_VEC IS UP:VECTOR.
GLOBAL LCH_I IS 0.
GLOBAL LCH_AN IS TRUE.
GLOBAL LCH_PITCH_ALT IS 250.
GLOBAL LCH_CURVE_ALT IS BODY:ATM:HEIGHT * 0.9.
GLOBAL LCH_FAIRING_ALT IS BODY:ATM:HEIGHT * 0.75.
GLOBAL LCH_HAS_LES IS FALSE.
GLOBAL LCH_HAS_FAIRING IS FALSE.

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
  SET LCH_HAS_LES TO (SHIP:PARTSNAMED("LaunchEscapeSystem"):LENGTH > 0 AND CAREER():CANDOACTIONS).
}

FUNCTION launchAP
{
  parameter ap.
  SET LCH_AP TO ap.
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
      mThrust(0).
      doStage().
    }
  } ELSE IF prev_mt = 0 AND mt > 0 AND stageTime() > 0.1 {
    LOCAL at IS SHIP:AVAILABLETHRUST.
    LOCAL twr IS at / (g0 * SHIP:MASS).
    pOut("Current TWR: " + ROUND(twr,2)).
    mThrust(mt).
    IF hasFairing() { checkFairing(). }
    IF hasLES() { checkLES(). }
  }
}

FUNCTION launchFairing
{
  IF ALTITUDE > LCH_FAIRING_ALT {
    FOR f IN SHIP:MODULESNAMED("ModuleProceduralFairing") {
      IF f:HASEVENT("deploy") { f:DOEVENT("deploy"). }
    }
    SET LCH_HAS_FAIRING TO FALSE.
  }
}

FUNCTION launchExtend
{
  PANELS ON.
  FOR a IN SHIP:MODULESNAMED("ModuleDeployableAntenna") {
    IF a:HASEVENT("Extend Antenna") { a:DOEVENT("Extend Antenna"). }
  }
}

FUNCTION sepLauncher
{
  IF SHIP:PARTSTAGGED("LAUNCHER"):LENGTH > 0 {
    steerOrbit().
    WAIT UNTIL steerOk().
    UNTIL SHIP:PARTSTAGGED("LAUNCHER"):LENGTH = 0 {
      WAIT UNTIL STAGE:READY AND stageTime() > 0.5.
      doStage().
      WAIT 0.
    }
    WAIT 2.
    dampSteering().
  }
}

FUNCTION launchCirc
{
  IF NOT HASNODE {
    LOCAL m_time IS TIME:SECONDS + ETA:APOAPSIS.
    LOCAL v0 IS VELOCITYAT(SHIP,m_time):ORBIT:MAG.
    LOCAL v1 IS SQRT(BODY:MU/(BODY:RADIUS + APOAPSIS)).
    LOCAL n IS NODE(m_time, 0, 0, v1 - v0).
    addNode(n).
  }
  LOCAL ok IS execNode(TRUE).
  RETURN ok AND PERIAPSIS > BODY:ATM:HEIGHT.
}

FUNCTION launchCoast
{
  PARAMETER exit_mode, flight_mode.
  IF ALTITUDE > BODY:ATM:HEIGHT {
    steerOff().
    launchExtend().
    IF launchCirc() {
      sepLauncher().
      pDV().
      runMode(exit_mode,0).
    } ELSE {
      launchAP(APOAPSIS + 10000).
      launchLocks().
      runMode(flight_mode).
    }
  } ELSE IF APOAPSIS < MAX(BODY:ATM:HEIGHT + 1000,LCH_AP - 5000) {
    launchAP(LCH_AP + ROUND(ABS(BODY:ATM:HEIGHT-ALTITUDE)/3)).
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
    pDV().
    steerSurf().
    runMode(next_mode).
  }
}

FUNCTION launchLiftOff
{
  PARAMETER next_mode.
  IF NOT isSteerOn() { steerLaunch(). }
  IF modeTime() > 3 {
    doStage().
    hudMsg("Liftoff!").
    runMode(next_mode).
  }
}

FUNCTION launchLocks
{
  steerLaunch().
  mThrust(0).
  LOCK THROTTLE TO 1.
}

FUNCTION launchBearing
{
  LOCAL lat IS SHIP:LATITUDE.
  LOCAL vo IS SHIP:VELOCITY:ORBIT.
  IF (LCH_I > 0 AND ABS(lat) < 90 AND MIN(LCH_I,180 - LCH_I) >= ABS(lat)) {
    LOCAL az IS ARCSIN( COS(LCH_I) / COS(lat) ).
    IF NOT LCH_AN { SET az TO mAngle(180 - az). }
    IF vo:MAG >= LCH_ORBIT_VEL { RETURN az. }
    LOCAL x IS (LCH_ORBIT_VEL * SIN(az)) - VDOT(vo,HEADING(90,0):VECTOR).
    LOCAL y IS (LCH_ORBIT_VEL * COS(az)) - VDOT(vo,HEADING(0,0):VECTOR).
    RETURN mAngle(90 - ARCTAN2(y, x)).
  } ELSE {
    IF LCH_I < 90 { RETURN 90. }
    ELSE { RETURN 270. }
  }
}

FUNCTION launchPitch
{
  IF ALT:RADAR < LCH_PITCH_ALT { RETURN 90. }
  RETURN MIN(90,MAX(0, MAX(90 * (1 - SQRT(ALTITUDE/LCH_CURVE_ALT)),30-VERTICALSPEED))).
}

FUNCTION launchMaxSteer
{
  IF ALTITUDE > LCH_FAIRING_ALT { RETURN 45. }
  IF ALTITUDE > LCH_FAIRING_ALT / 2 OR SHIP:VELOCITY:SURFACE:MAG < 99 { RETURN 15. }
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
