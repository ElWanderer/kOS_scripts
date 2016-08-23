@LAZYGLOBAL OFF.

pOut("lib_launch_common.ks v1.2.0 20160823").

FOR f IN LIST(
  "lib_burn.ks",
  "lib_runmode.ks"
) { RUNONCEPATH(loadScript(f)). }

GLOBAL LCH_MAX_THRUST IS 0.
GLOBAL LCH_VEC IS UP:VECTOR.
GLOBAL LCH_I IS 0.
GLOBAL LCH_AN IS TRUE.
GLOBAL LCH_PITCH_ALT IS 250.
GLOBAL LCH_CURVE_ALT IS BODY:ATM:HEIGHT.
GLOBAL LCH_FAIRING_ALT IS BODY:ATM:HEIGHT * 0.6.
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

FUNCTION launchInit
{
  PARAMETER exit_mode,ap,az,i,pitch_alt.

  SET LCH_ORBIT_VEL TO SQRT(BODY:MU/(BODY:RADIUS + ap)).
  SET LCH_I TO i.
  SET LCH_AN TO (az <= 90 OR az >= 270).
  SET LCH_PITCH_ALT TO pitch_alt.

  checkFairing().
  checkLES().
  mThrust(0).

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
  execNode(TRUE).
}

FUNCTION launchBearing
{
  LOCAL lat IS SHIP:LATITUDE.
  LOCAL vo IS SHIP:VELOCITY:ORBIT.
  IF (LCH_I > 0 AND ABS(lat) < 90 AND MIN(LCH_I,180 - LCH_I) >= ABS(lat)) {
    LOCAL az IS ARCSIN( COS(LCH_I) / COS(lat) ).
    IF NOT LCH_AN { SET az TO mAngle(180 - az). }
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
  IF ALTITUDE < LCH_CURVE_ALT { RETURN 90 * (1 - SQRT(ALTITUDE/LCH_CURVE_ALT)). }
  RETURN 0.
}

FUNCTION launchMaxSteer
{
  IF ALTITUDE > LCH_FAIRING_ALT { RETURN 30. }
  IF ALTITUDE > LCH_FAIRING_ALT / 2 OR SHIP:VELOCITY:SURFACE:MAG < 75 { RETURN 5. }
  RETURN 2.
}

FUNCTION launchSteerUpdate
{
  LOCAL cur_v IS SHIP:VELOCITY:SURFACE.
  LOCAL new_v IS HEADING(launchBearing(),launchPitch()):VECTOR.
  LOCAL max_ang IS launchMaxSteer().
  IF VANG(cur_v,new_v) > max_ang { SET new_v TO ANGLEAXIS(max_ang,VCRS(new_v,cur_v)) * cur_v. }
  SET LCH_VEC TO new_v.
}

FUNCTION steerLaunch
{
  steerTo({ RETURN LCH_VEC. }).
}
