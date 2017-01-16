@LAZYGLOBAL OFF.

IF NOT EXISTS("1:/init.ks") { RUNPATH("0:/init_select.ks"). }
RUNONCEPATH("1:/init.ks").

pOut("KMSat.ks v1.3.0 20170116").

FOR f IN LIST(
  "lib_runmode.ks",
  "lib_launch_nocrew.ks",
  "lib_steer.ks",
  "lib_orbit_change.ks",
  "lib_orbit_match.ks",
  "lib_transfer.ks"
) { RUNONCEPATH(loadScript(f)). }

// set these values ahead of launch
GLOBAL SAT_BODY IS MUN.
GLOBAL SAT_NAME IS "Rendezvous Test Target".
GLOBAL SAT_AP IS 75000.
GLOBAL SAT_PE IS 75000.
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

  WAIT UNTIL cOk().
  RUNPATH("0:/lib_launch_geo.ks").

  LOCAL ap IS 85000.
  LOCAL launch_details IS calcLaunchDetails(ap,SAT_BODY_I,SAT_BODY_LAN).
  LOCAL az IS launch_details[0].
  LOCAL launch_time IS launch_details[1].
  warpToLaunch(launch_time).

  store("doLaunch(801," + ap + "," + az + "," + SAT_BODY_I + ").").
  doLaunch(801,ap,az,SAT_BODY_I).

} ELSE IF rm < 50 {
  resume().

} ELSE IF rm > 100 AND rm < 150 {
  resume().

} ELSE IF MOD(rm,10) = 9 AND rm > 800 AND rm < 999 {
  hudMsg("Error state. Hit abort to switch to recovery mode: " + abortMode() + ".").
  steerSun().
  WAIT UNTIL MOD(runMode(),10) <> 9.

} ELSE IF rm = 801 {
  delResume().
  runMode(802).
} ELSE IF rm = 802 {
  IF doOrbitMatch(FALSE,stageDV(),SAT_BODY_I,SAT_BODY_LAN) { runMode(811). }
  ELSE { runMode(809,802). }

} ELSE IF rm = 811 {
  store("doTransfer(821, FALSE, "+SAT_BODY+","+SAT_AP+","+SAT_I+","+SAT_LAN+").").
  doTransfer(821, FALSE, SAT_BODY, SAT_AP, SAT_I, SAT_LAN).

} ELSE IF rm = 821 {
  delResume().
  IF doOrbitMatch(FALSE,stageDV(),SAT_I,SAT_LAN) { runMode(822). }
  ELSE { runMode(829,821). }
} ELSE IF rm = 822 {
  IF doOrbitChange(FALSE,stageDV(),SAT_AP,SAT_PE,SAT_W) { runMode(831,821). }
  ELSE { runMode(829,822). }

} ELSE IF rm = 831 {
  hudMsg("Mission complete. Hit abort to switch back to mode: " + abortMode() + ".").
  steerSun().
  WAIT UNTIL runMode() <> 831.
}
}
