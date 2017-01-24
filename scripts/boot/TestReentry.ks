@LAZYGLOBAL OFF.

IF NOT EXISTS("1:/init.ks") { RUNPATH("0:/init_select.ks"). }
RUNONCEPATH("1:/init.ks").

pOut("TestReentry.ks v1.0.0 20170124").

FOR f IN LIST(
  "lib_runmode.ks",
  "lib_launch_crew.ks",
  "lib_steer.ks",
  "lib_orbit_match.ks",
  "lib_transfer.ks",
  "lib_reentry.ks",
  "plot_reentry.ks"
) { RUNONCEPATH(loadScript(f)). }

// set these values ahead of launch
GLOBAL SAT_NAME IS "Reentry Test 1".
GLOBAL SAT_AP IS 9000000.

IF runMode() > 0 { logOn(). }

UNTIL runMode() = 99 {
LOCAL rm IS runMode().
IF rm < 0 {
  SET SHIP:NAME TO SAT_NAME.
  logOn().

  store("doLaunch(801,85000,90,0).").
  doLaunch(801,85000,90,0).

} ELSE IF rm < 50 {
  resume().

} ELSE IF rm > 50 AND rm < 99 {
  resume().

} ELSE IF MOD(rm,10) = 9 AND rm > 800 AND rm < 999 {
  hudMsg("Error state. Hit abort to switch to recovery mode: " + abortMode() + ".").
  steerSun().
  WAIT UNTIL MOD(runMode(),10) <> 9.

} ELSE IF rm = 801 {
  delResume().
  runMode(811).

} ELSE IF rm = 811 {
  IF doOrbitChange(FALSE,stageDV(),SAT_AP,30000) { runMode(821). }
  ELSE { runMode(819,802). }

} ELSE IF rm = 821 {
  plotReentry().
  store("doReentry(1,99).").
  doReentry(1,99).
}

}
