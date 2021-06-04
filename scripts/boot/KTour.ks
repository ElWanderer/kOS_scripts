@LAZYGLOBAL OFF.

IF NOT EXISTS("1:/init.ks") { RUNPATH("0:/init_select.ks"). }
RUNONCEPATH("1:/init.ks").

pOut("KTour.ks v1.3.0 20170116").

FOR f IN LIST(
  "lib_runmode.ks",
  "lib_launch_crew.ks",
  "lib_steer.ks",
  "lib_reentry.ks"
) { RUNONCEPATH(loadScript(f)). }

UNTIL runMode() = 99 {
LOCAL rm IS runMode().
IF rm < 0 {
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
  runMode(802).
} ELSE IF rm = 802 {
  IF deorbitNode() { execNode(FALSE). }
  IF PERIAPSIS < 70000 { runMode(803). }
  ELSE {
    pOut("ERROR: Did not lower periapsis below 70km.").
    runMode(809,802).
  }
} ELSE IF rm = 803 {
  store("doReentry(1,99).").
  doReentry(1,99).
}

}
