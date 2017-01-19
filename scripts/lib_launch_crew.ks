@LAZYGLOBAL OFF.
pOut("lib_launch_crew.ks v1.3.0 20170119").

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
    launchLocks().
    runMode(2,21).
  } ELSE IF rm = 2 {
    launchLiftOff(11).
  } ELSE IF rm = 11 {
    launchFlight(12).
  } ELSE IF rm = 12 {
    launchCoast(exit_mode,11).
  } ELSE IF rm = 21 {
    killThrot().
    hudMsg("LAUNCH ABORT!", RED, 40).
    WAIT 0.
    IF hasLES() { steerOff(). fireLES(). }
    ELSE { steerSurf(). }
    decoupleByTag("FINAL").
    runMode(22).
  } ELSE IF rm = 22 {
    IF modeTime() > 6 AND hasLES() { JettisonLES(). }
    IF modeTime() > 7 {
      steerSurf(FALSE).
      runMode(23).
    }
  } ELSE IF rm = 23 {
    IF modeTime() > 6 { runMode(31). }
  } ELSE IF rm = 31 {
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
