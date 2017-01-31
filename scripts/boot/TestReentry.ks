@LAZYGLOBAL OFF.

IF NOT EXISTS("1:/init.ks") { RUNPATH("0:/init_select.ks"). }
RUNONCEPATH("1:/init.ks").

pOut("TestReentry.ks v1.0.0 20170131").

FOR f IN LIST(
  "lib_runmode.ks",
  "lib_launch_crew.ks",
  "lib_steer.ks",
  "lib_orbit_change.ks",
  "lib_reentry.ks",
  "plot_reentry.ks"
) { RUNONCEPATH(loadScript(f)). }

// set these values ahead of launch
GLOBAL SAT_NAME IS "Reentry Test 5".
GLOBAL SAT_AP IS 8000000.
GLOBAL ESTIMATED_TA_DIFF IS 20.
GLOBAL REENTRY_LOG_FILE IS "0:/log/TestReentry.txt".
GLOBAL REENTRY_CRAFT_FILE IS "0:/craft/" + padRep(0,"_",SAT_NAME) + ".ks".

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
  IF EXISTS(REENTRY_CRAFT_FILE) { updateReentryAP(). pOut("SAT_AP now has value: " + SAT_AP + "m."). }
  ELSE { KUNIVERSE:QUICKSAVE(). hudMsg("Quicksaving"). WAIT 5. }
  runMode(812).
} ELSE IF rm = 812 {
  IF doOrbitChange(FALSE,stageDV(),SAT_AP,30000) { runMode(821). }
  ELSE { runMode(819,802). }

} ELSE IF rm = 821 {
  plotReentry(REENTRY_LOG_FILE,ESTIMATED_TA_DIFF).
  store("doReentry(1,99).").
  doReentry(1,99).
  LOCAL lat_land_str IS "Touchdown latitude: " + ROUND(mAngle(SHIP:LATITUDE),2) + " degrees.".
  LOCAL lng_land_str IS "Touchdown longitude: " + ROUND(mAngle(SHIP:LONGITUDE),2) + " degrees.".
  pOut(lat_land_str).
  pOut(lng_land_str).

  reentryExtend().
  WAIT UNTIL cOk().

  IF REENTRY_LOG_FILE <> "" {
    LOG "--------" TO REENTRY_LOG_FILE.
    LOG "Results:" TO REENTRY_LOG_FILE.
    LOG "--------" TO REENTRY_LOG_FILE.
    LOG lat_land_str TO REENTRY_LOG_FILE.
    LOG lng_land_str TO REENTRY_LOG_FILE.
  }

  IF EXISTS(REENTRY_CRAFT_FILE) { DELETEPATH(REENTRY_CRAFT_FILE). }
  LOCAL factor IS 0.
  IF SAT_AP > 1000000 { SET factor TO 0.5. }
  ELSE IF SAT_AP > 85000 { SET factor TO 0.8. }
  IF factor > 0 {
    LOG "FUNCTION updateReentryAP { SET SAT_AP TO " + ROUND(SAT_AP * factor) + ". }" TO REENTRY_CRAFT_FILE.
    hudMsg("Craft file updated, preparing to quickload.").
    UNTIL FALSE {
      WAIT 5.
      KUNIVERSE:QUICKLOAD().
    }
  } ELSE {
    hudMsg("Simulation finished.").
  }
}

}
