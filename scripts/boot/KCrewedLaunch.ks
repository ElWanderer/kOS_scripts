@LAZYGLOBAL OFF.

IF NOT EXISTS("1:/init.ks") { RUNPATH("0:/init_select.ks"). }
RUNONCEPATH("1:/init.ks").

pOut("KCrewedLaunch.ks v1.0.0 20201116").

FOR f IN LIST(
  "lib_runmode.ks",
  "lib_launch_crew.ks",
  "lib_steer.ks",
  "lib_orbit_change.ks",
  "lib_orbit_match.ks"
) { RUNONCEPATH(loadScript(f)). }

IF cOk() { runpath("0:/update.ks"). }

// set these values ahead of launch
GLOBAL NEW_NAME IS "Ikarus 9B". // Next: Hermes 9, Ikarus 10, Endeavour 3, Emerald 6, Magellan 6
GLOBAL SAT_AP IS 160000.
GLOBAL SAT_PE IS 160000.
GLOBAL SAT_I IS 0.
GLOBAL SAT_LAN IS -1.
GLOBAL SAT_W IS -1.

IF runMode() > 0 { logOn(). }

UNTIL runMode() = 99 {
LOCAL rm IS runMode().
IF rm < 0 {
  SET SHIP:NAME TO NEW_NAME.
  logOn().

  WAIT UNTIL cOk().
  RUNPATH("0:/lib_launch_geo.ks").

  LOCAL ap IS 85000.
  IF SAT_PE < 205000 { SET ap TO SAT_PE. }
  LOCAL launch_details IS calcLaunchDetails(ap,SAT_I,SAT_LAN).
  LOCAL az IS launch_details[0].
  LOCAL launch_time IS launch_details[1].
  warpToLaunch(launch_time).

  store("doLaunch(801," + ap + "," + az + "," + SAT_I + ").").
  doLaunch(801,ap,az,SAT_I).

} ELSE IF rm < 50 {
  resume().

} ELSE IF MOD(rm,10) = 9 AND rm > 800 AND rm < 999 {
  hudMsg("Error state. Hit abort to recover (mode " + abortMode() + ").").
  steerSun().
  WAIT UNTIL MOD(runMode(),10) <> 9.

} ELSE IF rm = 801 {
  delResume().
  runMode(804). // Changed from 802
} ELSE IF rm = 802 {
  IF doOrbitChange(FALSE,stageDV(),SAT_AP,SAT_PE,SAT_W,SAT_LAN) { runMode(803). }
  ELSE { runMode(809,802). }
} ELSE IF rm = 803 {
  IF doOrbitMatch(FALSE,stageDV(),SAT_I,SAT_LAN) { runMode(804,802). }
  ELSE { runMode(809,802). }
} ELSE IF rm = 804 {
  hudMsg("Steering sunwards").
  runMode(805, 802).
} ELSE IF rm = 805 {
  steerSun().
  WAIT 5.
}

}
