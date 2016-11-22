@LAZYGLOBAL OFF.
pOut("lib_launch_crew.ks v1.2.0 20161101").

FOR f IN LIST(
  "lib_launch_common.ks",
  "lib_chutes.ks",
  "lib_parts.ks"
) { RUNONCEPATH(loadScript(f)). }

GLOBAL LCH_LES_ALT IS BODY:ATM:HEIGHT * 0.62.
GLOBAL LCH_CHUTE_ALT IS BODY:ATM:HEIGHT * 0.3.

FUNCTION fireLES
{
  FOR p IN SHIP:PARTSNAMED("LaunchEscapeSystem") {
    p:GETMODULE("ModuleEnginesFX"):DOACTION("activate engine",TRUE).
  }
}

FUNCTION jettisonLES
{
  FOR p IN SHIP:PARTSNAMED("LaunchEscapeSystem") {
    pOut("Jettisoning LES").
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

  launchInit(ap,az,i,pitch_alt).

  LOCAL LOCK rm TO runMode().

UNTIL rm = exit_mode
{
  IF rm = 1 {
    killThrot().
    WAIT 0.
    LOCK THROTTLE TO 1.
    steerLaunch().
    runMode(2,21).
  } ELSE IF rm = 2 {
    IF NOT isSteerOn() { steerLaunch(). }
    IF modeTime() > 3 {
      doStage().
      hudMsg("Liftoff!").
      runMode(11).
    }
  } ELSE IF rm = 11 {
    IF NOT isSteerOn() { steerLaunch(). }
    launchSteerUpdate().
    launchStaging().
    IF APOAPSIS > ap {
      killThrot().
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
      } ELSE { runMode(21,0). }
    }
  } ELSE IF rm = 21 {
    killThrot().
    WAIT 0.
    steerOff().
    IF hasLES() {
      hudMsg("LAUNCH ABORT!", RED, 50).
      fireLES().
      decoupleByTag("FINAL").
    } ELSE { hudMsg("MANUAL STAGING REQUIRED!", RED, 50). }
    runMode(22).
  } ELSE IF rm = 22 {
    IF modeTime() > 6 {
      steerSurf(FALSE).
      IF hasLES() { JettisonLES(). }
      runMode(23).
    }
  } ELSE IF rm = 23 {
    IF modeTime() > 6 { runMode(31). }
  } ELSE IF rm = 31 {
    IF ALTITUDE > LCH_CHUTE_ALT { steerSurf(FALSE). }
    runMode(32).
  } ELSE IF rm = 32 {
    IF ALTITUDE < LCH_CHUTE_ALT {
      steerOff().
      IF hasChutes() { hudMsg("Will deploy parachutes once safe."). }
      runMode(33).
    }
  } ELSE IF rm = 33 {
    IF hasChutes() { deployChutes(). }
    IF LIST("LANDED","SPLASHED"):CONTAINS(STATUS) {
      hudMsg("Touchdown.").
      WAIT 0.
      CORE:DOEVENT("Toggle Power").
    }
  } ELSE {
    pOut("Unexpected run mode: " + rm).
    BREAK.
  }

  IF hasLES() AND rm < 20 { launchLES(). }
  IF hasFairing() { launchFairing(). }
  WAIT 0.
}

}
