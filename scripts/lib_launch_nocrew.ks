@LAZYGLOBAL OFF.
pOut("lib_launch_nocrew.ks v1.3.0 20170112").

RUNONCEPATH(loadScript("lib_launch_common.ks")).

FUNCTION doLaunch
{
  PARAMETER exit_mode, ap, az IS 90, i IS SHIP:LATITUDE, pitch_alt IS 250.

  launchInit(ap,az,i,pitch_alt).

  LOCAL LOCK rm TO runMode().

UNTIL rm = exit_mode
{
  IF rm = 1 {
    killThrot().
    launchPilot().
    runMode(2).
  } ELSE IF rm = 2 {
    launchLiftOff(11).
  } ELSE IF rm = 11 {
    launchFlight(12).
  } ELSE IF rm = 12 {
    launchCoast(exit_mode,11).
  } ELSE {
    pOut("Unexpected run mode: " + rm).
    BREAK.
  }

  IF hasFairing() { launchFairing(). }
  WAIT 0.
}

}
