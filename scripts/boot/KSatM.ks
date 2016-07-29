@LAZYGLOBAL OFF.

COPYPATH("0:/init_multi.ks","1:/init_multi.ks").
RUNONCEPATH("1:/init_multi.ks").

pOut("KSatM.ks v1.0.0 20160726").

RUNONCEPATH(loadScript("lib_runmode.ks")).

// set these values ahead of launch
GLOBAL NEW_NAME IS "MultiCPU Test Sat 1".
GLOBAL SAT_AP IS 300000.
GLOBAL SAT_PE IS 250000.
GLOBAL SAT_I IS 0.
GLOBAL SAT_LAN IS 0.
GLOBAL SAT_W IS 0.

IF runMode() > 0 { logOn(). }

UNTIL runMode() = 99 {
LOCAL rm IS runMode().
IF rm < 0 {
  SET SHIP:NAME TO NEW_NAME.
  logOn().

  RUNONCEPATH(loadScript("lib_launch_geo.ks")).

  LOCAL ap IS 85000.
  LOCAL launch_details IS calcLaunchDetails(ap,SAT_I,SAT_LAN).
  LOCAL az IS launch_details[0].
  LOCAL launch_time IS launch_details[1].
  warpToLaunch(launch_time).

  delScript("lib_launch_geo.ks").
  RUNONCEPATH(loadScript("lib_launch_nocrew.ks")).

  store("doLaunchNoCrew(801," + ap + "," + az + ").").
  doLaunchNoCrew(801,ap,az).

} ELSE IF rm < 50 {
  RUNONCEPATH(loadScript("lib_launch_nocrew.ks")).
  resume().

} ELSE IF MOD(rm,10) = 9 AND rm > 800 AND rm < 999 {
  RUNONCEPATH(loadScript("lib_steer.ks")).
  hudMsg("Error state. Hit abort to switch to recovery mode: " + abortMode() + ".").
  steerSun().
  WAIT UNTIL MOD(rm,10) <> 9.

} ELSE IF rm = 801 {
  delResume().
  delScript("lib_launch_nocrew.ks").
  delScript("lib_launch_common.ks").
  runMode(802).
} ELSE IF rm = 802 {
  RUNONCEPATH(loadScript("lib_orbit_change.ks")).
  IF doOrbitChange(FALSE,stageDV(),SAT_AP,SAT_PE,SAT_W) { runMode(803,802). }
  ELSE { runMode(809,802). }
} ELSE IF rm = 803 {
  RUNONCEPATH(loadScript("lib_steer.ks")).
  hudMsg("Mission complete. Hit abort to switch back to mode: " + abortMode() + ".").
  steerSun().
  WAIT UNTIL rm <> 803.
}

}