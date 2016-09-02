@LAZYGLOBAL OFF.

IF NOT EXISTS("1:/init.ks") { RUNPATH("0:/init_select.ks"). }
RUNONCEPATH("1:/init.ks").

pOut("KMTour.ks v1.2.0 20160902").

RUNONCEPATH(loadScript("lib_runmode.ks")).

// set these values ahead of launch
GLOBAL SAT_BODY IS MINMUS.
GLOBAL SAT_NAME IS "Minmus Tour Test 6".
GLOBAL SAT_AP IS 60000.
GLOBAL SAT_PE IS 60000.
GLOBAL SAT_I IS 0.
GLOBAL SAT_LAN IS 0.
GLOBAL SAT_W IS 0.

GLOBAL SAT_BODY_I IS SAT_BODY:OBT:INCLINATION.
GLOBAL SAT_BODY_LAN IS SAT_BODY:OBT:LAN.

IF runMode() > 0 { logOn(). }

UNTIL runMode() = 99 {
LOCAL rm IS runMode().
IF rm < 0 {
  SET SHIP:NAME TO SAT_NAME.
  logOn().

  RUNONCEPATH(loadScript("lib_launch_geo.ks")).

  LOCAL ap IS 85000.
  LOCAL launch_details IS calcLaunchDetails(ap,SAT_BODY_I,SAT_BODY_LAN).
  LOCAL az IS launch_details[0].
  LOCAL launch_time IS launch_details[1].
  warpToLaunch(launch_time).

  delScript("lib_launch_geo.ks").
  RUNONCEPATH(loadScript("lib_launch_crew.ks")).

  store("doLaunch(801," + ap + "," + az + "," + SAT_BODY_I + ").").
  doLaunch(801,ap,az,SAT_BODY_I).

} ELSE IF rm < 50 {
  RUNONCEPATH(loadScript("lib_launch_crew.ks")).
  resume().

} ELSE IF rm > 50 AND rm < 99 {
  RUNONCEPATH(loadScript("lib_reentry.ks")).
  resume().

} ELSE IF rm > 100 AND rm < 150 {
  RUNONCEPATH(loadScript("lib_transfer.ks")).
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
  RUNONCEPATH(loadScript("lib_orbit_match.ks")).
  IF doOrbitMatch(FALSE,stageDV(),SAT_BODY_I,SAT_BODY_LAN) { runMode(811). }
  ELSE { runMode(809,802). }

} ELSE IF rm = 811 {
  RUNONCEPATH(loadScript("lib_transfer.ks")).
  store("doTransfer(821, FALSE, "+SAT_BODY+","+SAT_AP+","+SAT_I+","+SAT_LAN+").").
  doTransfer(821, FALSE, SAT_BODY, SAT_AP, SAT_I, SAT_LAN).

} ELSE IF rm = 821 {
  delResume().
  RUNONCEPATH(loadScript("lib_orbit_match.ks")).
  IF doOrbitMatch(FALSE,stageDV(),SAT_I,SAT_LAN) { runMode(822). }
  ELSE { runMode(829,821). }
} ELSE IF rm = 822 {
  RUNONCEPATH(loadScript("lib_orbit_change.ks")).
  IF doOrbitChange(FALSE,stageDV(),SAT_AP,SAT_PE,SAT_W) { runMode(851). }
  ELSE { runMode(829,822). }

} ELSE IF rm = 851 {
  RUNONCEPATH(loadScript("lib_transfer.ks")).
  store("doTransfer(861, FALSE, KERBIN, 30000).").
  doTransfer(861, FALSE, KERBIN, 30000).

} ELSE IF rm = 861 {
  delScript("lib_transfer.ks").
  RUNONCEPATH(loadScript("lib_reentry.ks")).
  store("doReentry(1,99).").
  doReentry(1,99).
}

}
