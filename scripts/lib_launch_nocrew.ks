@LAZYGLOBAL OFF.

pOut("lib_launch_nocrew.ks v1.1.0 20160823").

RUNONCEPATH(loadScript("lib_launch_common.ks")).

FUNCTION doLaunch
{
  PARAMETER exit_mode, ap, az IS 90, i IS SHIP:LATITUDE, pitch_alt IS 250.

  launchInit(exit_mode,ap,az,i,is_AN,pitch_alt).

  LOCAL LOCK rm TO runMode().

UNTIL rm = exit_mode
{
  IF rm = 1 {
    killThrot().
    LOCK THROTTLE TO 1.
    steerLaunch().
    runMode(2).
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
      sepLauncher().
      pDV().
      runMode(exit_mode).
    }
  } ELSE {
    pOut("Unexpected run mode: " + rm).
    BREAK.
  }

  IF hasFairing() { launchFairing(). }
  WAIT 0.
}

}
