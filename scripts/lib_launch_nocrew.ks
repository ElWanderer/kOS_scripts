@LAZYGLOBAL OFF.

pOut("lib_launch_nocrew.ks v1.0.1 20160714").

RUNONCEPATH(loadScript("lib_launch_common.ks")).

FUNCTION doLaunchNoCrew
{
  PARAMETER exit_mode.
  PARAMETER launch_ap IS BODY:ATM:HEIGHT + 15000.
  PARAMETER launch_az IS 90.
  PARAMETER pitch_alt IS 800.

  launchInit(exit_mode,launch_ap,launch_az,pitch_alt).

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
    launchPitch().
    launchStaging().
    IF APOAPSIS > launch_ap {
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
      }
      runMode(exit_mode,0).
    }
  } ELSE IF rm = 18 {
    pOut("Abort mode: " + rm).
    LOCK THROTTLE TO 0.
    WAIT 0.
    steerOff().
    runMode(exit_mode).
  } ELSE {
    pOut("Unexpected run mode: " + rm).
    runMode(exit_mode).
  }

  IF hasFairing() { launchFairing(). }
  WAIT 0.
}

}