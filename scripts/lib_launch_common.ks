@LAZYGLOBAL OFF.

pOut("lib_launch_common.ks v1.0.5 20160728").

FOR f IN LIST(
  "lib_burn.ks",
  "lib_runmode.ks"
) { RUNONCEPATH(loadScript(f)). }

GLOBAL LCH_MAX_THRUST IS 0.
GLOBAL LCH_PITCH IS 90.
GLOBAL LCH_HEADING IS 90.
GLOBAL LCH_PITCH_ALT IS 800.
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
  PARAMETER exit_mode,launch_ap,launch_az,pitch_alt.

  pOut("Launch to apoasis: " + launch_ap).
  pOut("Launch heading: " + ROUND(launch_az,2)).

  checkFairing().
  checkLES().
  mThrust(0).

  SET LCH_HEADING TO launch_az.
  IF pitch_alt > 0 { SET LCH_PITCH_ALT TO pitch_alt. }

  IF runMode() < 0 {
    IF LIST("LANDED","PRELAUNCH"):CONTAINS(STATUS) {
      runMode(1).
      abortMode(exit_mode).
      hudMsg("Prepare for launch...").
    } ELSE {
      pOut("Unexpected ship status: " + STATUS + ".").
      runMode(exit_mode).
    }
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
    pOut("Max thrust: " + mt + "kN. Current thrust: " + ROUND(at,2) + "kN.").
    pOut("Craft mass: " + ROUND(SHIP:MASS,1)+ "t. Current TWR: " + ROUND(twr,2)+ ".").
    mThrust(mt).
    IF hasFairing() { checkFairing(). }
    IF hasLES() { checkLES(). }
  }
}

FUNCTION launchFairing
{
  IF ALTITUDE > LCH_FAIRING_ALT {
    pOut("Deploying fairing.").
    FOR f IN SHIP:MODULESNAMED("ModuleProceduralFairing") {
      IF f:HASEVENT("deploy") { f:DOEVENT("deploy"). }
    }
    SET LCH_HAS_FAIRING TO FALSE.
  }
}

FUNCTION sepLauncher
{
  IF SHIP:PARTSTAGGED("LAUNCHER"):LENGTH > 0 {
    pOut("Staging until payload separated from launcher.").
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

FUNCTION launchPitch
{
  IF ALT:RADAR < LCH_PITCH_ALT { SET LCH_PITCH TO 90. }
  ELSE IF ALTITUDE < LCH_CURVE_ALT { SET LCH_PITCH TO 90 * (1 - SQRT(ALTITUDE/LCH_CURVE_ALT)). }
  ELSE { SET LCH_PITCH TO 0. }
}

FUNCTION steerLaunch
{
  steerOn().
  LOCK STEERING TO LOOKDIRUP(HEADING(LCH_HEADING,LCH_PITCH):VECTOR,FACING:TOPVECTOR).
}