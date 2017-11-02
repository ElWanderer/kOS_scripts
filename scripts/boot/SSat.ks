@LAZYGLOBAL OFF.

IF NOT EXISTS("1:/init.ks") { RUNPATH("0:/init_select.ks"). }
RUNONCEPATH("1:/init.ks").

pOut("SSat.ks v1.0.0 20171102").

FOR f IN LIST(
  "lib_runmode.ks",
  "lib_launch_nocrew.ks",
  "lib_steer.ks",
  "lib_orbit_change.ks",
  "lib_orbit_match.ks",
  "lib_transfer.ks"
) { RUNONCEPATH(loadScript(f)). }

// set these values ahead of launch
GLOBAL SAT_NAME IS "SunSatTest 1".

GLOBAL UNIT_GM IS 1000000000.
GLOBAL SAT_AP IS 15.5.
GLOBAL SAT_PE IS 14.5.
GLOBAL SAT_I IS 0.
GLOBAL SAT_LAN IS 0.
GLOBAL SAT_W IS 293.

IF runMode() > 0 { logOn(). }

UNTIL runMode() = 99 {
LOCAL rm IS runMode().
IF rm < 0 {
  SET SHIP:NAME TO SAT_NAME.
  logOn().

  WAIT UNTIL cOk().
  RUNPATH("0:/lib_launch_geo.ks").

  LOCAL ap IS 85000.
  LOCAL launch_details IS calcLaunchDetails(ap,0,-1).
  LOCAL az IS launch_details[0].
  LOCAL launch_time IS launch_details[1].
  warpToLaunch(launch_time).

  store("doLaunch(801," + ap + "," + az + ",0).").
  doLaunch(801,ap,az,0).

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
  store("doTransfer(821, FALSE, SUN,"+SAT_AP+"*"+UNIT_GM+","+SAT_I+","+SAT_LAN+").").
  doTransfer(821, FALSE, SUN, SAT_AP*UNIT_GM, SAT_I, SAT_LAN).

} ELSE IF rm = 821 {
  delResume().
  IF doOrbitMatch(FALSE,stageDV(),SAT_I,SAT_LAN) { runMode(822). }
  ELSE { runMode(829,821). }
} ELSE IF rm = 822 {
  IF doOrbitChange(FALSE,stageDV(),SAT_AP*UNIT_GM,SAT_PE*UNIT_GM,SAT_W) { runMode(831,821). }
  ELSE { runMode(829,822). }

} ELSE IF rm = 831 {
  hudMsg("Mission complete. Hit abort to switch back to mode: " + abortMode() + ".").
  steerSun().
  WAIT UNTIL runMode() <> 831.
}
}
