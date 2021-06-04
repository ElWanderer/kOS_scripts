@LAZYGLOBAL OFF.

IF NOT EXISTS("1:/init.ks") { RUNPATH("0:/init_select.ks"). }
RUNONCEPATH("1:/init.ks").

pOut("TestLander.ks v1.0.0 20170814").

FOR f IN LIST(
  "lib_runmode.ks",
  "lib_launch_common.ks",
  "lib_orbit_match.ks",
  "lib_orbit_change.ks",
  "lib_lander_descent.ks"
) { RUNONCEPATH(loadScript(f)). }

// set these values ahead of launch
GLOBAL SAT_NAME IS "Lander Test 1".

GLOBAL LAND_LAT IS 0.
GLOBAL LAND_LNG IS 2.
GLOBAL SAFETY_ALT IS 1000.

IF runMode() > 0 { logOn(). }

UNTIL runMode() = 99 {
LOCAL rm IS runMode().
IF rm < 0 {
  SET SHIP:NAME TO SAT_NAME.
  logOn().

  killThrot().

  hudMsg("Hit abort to trigger landing when ready.").
  runMode(809,801).

} ELSE IF rm < 50 {
  resume().

} ELSE IF rm > 50 AND rm < 99 {
  resume().

} ELSE IF rm > 100 AND rm < 150 {
  resume().

} ELSE IF rm > 200 AND rm < 250 {
  resume().

} ELSE IF rm > 300 AND rm < 350 {
  resume().

} ELSE IF MOD(rm,10) = 9 AND rm > 800 AND rm < 999 {
  pOut("Error state. Hit abort to switch to recovery mode: " + abortMode() + ".").
  steerSun().
  WAIT UNTIL MOD(runMode(),10) <> 9.

} ELSE IF rm = 801 {
  killWarp().
  UNTIL SHIP:MAXTHRUST > 0 { doStage(). WAIT 1. }
  store("doLanding(" + LAND_LAT + "," + LAND_LNG + ",0,"+SAFETY_ALT+",5000,25,841).").
  doLanding(LAND_LAT,LAND_LNG,0,SAFETY_ALT,5000,25,841).

} ELSE IF rm = 841 {
  delResume().
  pOut("Test finished.").
  pDV().
  runMode(99).
}
  WAIT 0.
} // end of UNTIL
