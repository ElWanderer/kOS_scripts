@LAZYGLOBAL OFF.

pOut("lib_launch_nocrew.ks v1.2.0#1 20160830").

RUNONCEPATH(loadScript("lib_launch_common.ks")).

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
    runMode(2).
  } ELSE IF rm = 2 {
    IF NOT steerOn() { steerLaunch(). }
    IF modeTime() > 3 {
      doStage().
      hudMsg("Liftoff!").
      runMode(11).
    }
  } ELSE IF rm > 10 {
    IF NOT steerOn() { steerLaunch(). }
    launchQUpdate().
    launchSteerUpdate().
    launchStaging().

    IF rm = 11 {
      IF ALTITUDE > BODY:ATM:HEIGHT {
        PANELS ON.
        runMode(12).
      }
    } ELSE IF rm = 12 {
      IF ABS(PERIAPSIS - ap) < 500 {
        killThrot().
        sepLauncher().
        steerOff().
        runMode(exit_mode).
      }
    }
  } ELSE {
    pOut("Unexpected run mode: " + rm).
    BREAK.
  }

  IF hasFairing() { launchFairing(). }
  WAIT 0.
}

}
