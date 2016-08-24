@LAZYGLOBAL OFF.

pOut("lib_launch_crew.ks v1.1.1 20160824").

FOR f IN LIST(
  "lib_launch_common.ks",
  "lib_chutes.ks",
  "lib_parts.ks"
) { RUNONCEPATH(loadScript(f)). }

GLOBAL LCH_LES_ALT IS BODY:ATM:HEIGHT * 0.62.
GLOBAL LCH_CHUTE_ALT IS BODY:ATM:HEIGHT * 0.3.

FUNCTION fireLES
{
  FOR les IN SHIP:PARTSNAMED("LaunchEscapeSystem") {
    pOut("Firing Launch Escape System").
    les:GETMODULE("ModuleEnginesFX"):DOACTION("activate engine",TRUE).
  }
}

FUNCTION jettisonLES
{
  // LES parent must be decoupler/docking port
  FOR les IN SHIP:PARTSNAMED("LaunchEscapeSystem") {
    LOCAL p IS les:PARENT.
    pOut("Jettisoning Launch Escape System").
    decouplePart(p).
  }
  disableLES().
}

FUNCTION launchLES
{
  IF ALTITUDE > LCH_LES_ALT {
    fireLES().
    jettisonLES().
  }
}

FUNCTION doLaunch
{
  PARAMETER exit_mode, ap, az IS 90, i IS SHIP:LATITUDE, pitch_alt IS 250.

  launchInit(exit_mode,ap,az,i,pitch_alt).

  LOCAL LOCK rm TO runMode().

UNTIL rm = exit_mode
{
  IF rm = 1 {
    killThrot().
    LOCK THROTTLE TO 1.
    steerLaunch().
    runMode(2,18).
  } ELSE IF rm = 2 {
    IF modeTime() > 3 {
      doStage().
      hudMsg("Liftoff!").
      runMode(11).
    }
  } ELSE IF rm = 11 {
    launchSteerUpdate().
    launchStaging().
    IF APOAPSIS > ap {
      LOCK THROTTLE TO 0.
      pDV().
      steerSurf().
      runMode(12).
    }
  } ELSE IF rm = 12 {
    IF ALTITUDE > BODY:ATM:HEIGHT {
      steerOff().
      PANELS ON.
      launchCirc().
      IF PERIAPSIS > BODY:ATM:HEIGHT {
        sepLauncher().
        pDV().
        runMode(exit_mode,0).
      } ELSE { runMode(31,0). }
    }
  } ELSE IF rm = 18 {
    pOut("Abort mode: " + rm).
    killThrot().
    WAIT 0.
    steerOff().
    IF hasLES() {
      hudMsg("LAUNCH ABORT!", RED, 50).
      fireLES().
      decoupleByTag("FINAL").
    } ELSE { hudMsg("MANUAL STAGING REQUIRED!", RED, 50). }
    runMode(19).
  } ELSE IF rm = 19 {
    IF modeTime() > 6 { 
      steerSurf(FALSE).
      IF hasLES() { JettisonLES(). }
      runMode(20).
    }
  } ELSE IF rm = 20 {
    IF modeTime() > 6 { runMode(31). }
  } ELSE IF rm = 31 {
    IF ALTITUDE > LCH_CHUTE_ALT { steerSurf(FALSE). }
    runMode(32).
  } ELSE IF rm = 32 {
    IF ALTITUDE < LCH_CHUTE_ALT {
      steerOff().
      pOut("Arming parachutes.").
      runMode(33).
    }
  } ELSE IF rm = 33 {
    deployChutes().
    IF LIST("LANDED","SPLASHED"):CONTAINS(STATUS) {
      hudMsg("Touchdown.").
      runMode(exit_mode).
    }
  } ELSE {
    pOut("Unexpected run mode: " + rm).
    BREAK.
  }

  IF hasLES() AND rm < 18 { launchLES(). }
  IF hasFairing() { launchFairing(). }
  WAIT 0.
}

}
