@LAZYGLOBAL OFF.

COPYPATH("0:/init.ks","1:/init.ks").
RUNONCEPATH("1:/init.ks").

pOut("KTour.ks v1.0.3 20160812").

RUNONCEPATH(loadScript("lib_runmode.ks")).

UNTIL runMode() = 99 {
LOCAL rm IS runMode().
IF rm < 0 {
  RUNONCEPATH(loadScript("lib_launch_crew.ks")).
  store("doLaunch(801,85000,90).").
  doLaunch(801,85000,90).

} ELSE IF rm < 50 {
  RUNONCEPATH(loadScript("lib_launch_crew.ks")).
  resume().

} ELSE IF rm > 50 AND rm < 99 {
  RUNONCEPATH(loadScript("lib_reentry.ks")).
  resume().

} ELSE IF MOD(rm,10) = 9 AND rm > 800 AND rm < 999 {
  RUNONCEPATH(loadScript("lib_steer.ks")).
  hudMsg("Error state. Hit abort to switch to recovery mode: " + abortMode() + ".").
  steerSun().
  WAIT UNTIL MOD(runMode(),10) <> 9.

} ELSE IF rm = 801 {
  delResume().
  delScript("lib_launch_crew.ks").
  delScript("lib_launch_common.ks").
  runMode(802).
} ELSE IF rm = 802 {
  RUNONCEPATH(loadScript("lib_reentry.ks")).
  RUNONCEPATH(loadScript("lib_burn.ks")).
  IF deorbitNode() { execNode(FALSE). }
  IF PERIAPSIS < 70000 { runMode(803). }
  ELSE {
    pOut("ERROR: Did not lower periapsis below 70km.").
    runMode(809,802).
  }
} ELSE IF rm = 803 {
  RUNONCEPATH(loadScript("lib_reentry.ks")).
  store("doReentry(1,99).").
  doReentry(1,99).
}

}
