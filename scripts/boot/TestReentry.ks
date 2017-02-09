@LAZYGLOBAL OFF.

IF NOT EXISTS("1:/init.ks") { RUNPATH("0:/init_select.ks"). }
RUNONCEPATH("1:/init.ks").

pOut("TestReentry.ks v1.0.0 20170209").

FOR f IN LIST(
  "lib_runmode.ks",
  "lib_launch_crew.ks",
  "lib_steer.ks",
  "lib_orbit_change.ks",
  "lib_reentry.ks",
  "plot_reentry.ks"
) { RUNONCEPATH(loadScript(f)). }

// set these values ahead of launch
GLOBAL SAT_NAME IS "Reentry Test 17".
GLOBAL SAT_AP IS 80000.
GLOBAL SAT_LAUNCH_AP IS 125000.
GLOBAL SAT_I IS 90.
GLOBAL SAT_LAN IS -1.
GLOBAL REENTRY_LOG_FILE IS "0:/log/TestReentry2.txt".
GLOBAL REENTRY_CRAFT_FILE IS "0:/craft/" + padRep(0,"_",SAT_NAME) + ".ks".

GLOBAL SAT_NEXT_AP IS LEXICON(
     80000,    85000,
     85000,    92000,
     92000,   100000,
    100000,   110000,
    110000,   125000,
    125000,   150000,
    150000,   175000,
    175000,   200000,
    200000,   250000,
    250000,   300000,
    300000,   400000,
    400000,   500000,
    500000,   640000,
    640000,   800000,
    800000,  1000000,
   1000000,  1250000,
   1250000,  1500000,
   1500000,  2000000,
   2000000,  4000000,
   4000000,  8000000,
   8000000, 12000000,
  12000000, 46400000).

FUNCTION saveNewCraftFileAndReload {
  IF EXISTS(REENTRY_CRAFT_FILE) { DELETEPATH(REENTRY_CRAFT_FILE). }
  IF SAT_NEXT_AP:HASKEY(SAT_AP) {
    LOG "FUNCTION updateReentryAP { SET SAT_AP TO " + SAT_NEXT_AP[SAT_AP] + ". }" TO REENTRY_CRAFT_FILE.
    hudMsg("Craft file updated, preparing to quickload.").
    UNTIL FALSE {
      WAIT 0.5.
      KUNIVERSE:QUICKLOAD().
      WAIT 5.
    }
  } ELSE {
    hudMsg("Simulation finished.").
    WAIT UNTIL FALSE.
  }
}

IF runMode() > 0 { logOn(). }

UNTIL runMode() = 99 {
LOCAL rm IS runMode().
IF rm < 0 {
  SET SHIP:NAME TO SAT_NAME.
  logOn().

  WAIT UNTIL cOk().
  RUNPATH("0:/lib_launch_geo.ks").

  LOCAL ap IS SAT_LAUNCH_AP.
  LOCAL launch_details IS calcLaunchDetails(ap,SAT_I,SAT_LAN).
  LOCAL az IS launch_details[0].
  IF SAT_LAN >= 0 {
    LOCAL launch_time IS launch_details[1].
    warpToLaunch(launch_time).
  }

  store("doLaunch(801," + ap + "," + az + "," + SAT_I + ").").
  doLaunch(801,ap,az,SAT_I).

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
  LOCAL do_save IS TRUE.
  LOCAL do_load IS FALSE.
  IF EXISTS(CRAFT_FILE) {
    LOCAL old_ap IS SAT_AP.
    updateReentryAP().
    IF SAT_AP <> old_ap {
      pOut("SAT_AP now has value: " + SAT_AP + "m.").
      SET do_save TO FALSE.
    } ELSE { SET do_load TO TRUE. }
  }
  IF do_save {
    IF EXISTS(CRAFT_FILE) { DELETEPATH(CRAFT_FILE). }
    KUNIVERSE:QUICKSAVE().
    hudMsg("Quicksaving").
    WAIT 5.
  }
  IF do_load {
    saveNewCraftFileAndReload().
  }
  runMode(812).
} ELSE IF rm = 812 {
  IF doOrbitChange(FALSE,stageDV(),SAT_AP,30000) { runMode(821). }
  ELSE { runMode(819,802). }

} ELSE IF rm = 821 {
  plotReentry(REENTRY_LOG_FILE).
  store("doReentry(1,831).").
  doReentry(1,831).
} ELSE IF rm = 831 {
  LOCAL lat_land_str IS "Touchdown latitude: " + ROUND(SHIP:LATITUDE,2) + " degrees.".
  LOCAL lng_land_str IS "Touchdown longitude: " + ROUND(mAngle(SHIP:LONGITUDE),2) + " degrees.".
  LOCAL land_time_str IS "Touchdown timestamp: " + ROUND(TIME:SECONDS) + "s " + formatMET().
  pOut(lat_land_str).
  pOut(lng_land_str).
  pOut(land_time_str).

  reentryExtend().
  WAIT UNTIL cOk().

  IF REENTRY_LOG_FILE <> "" {
    LOG "--------" TO REENTRY_LOG_FILE.
    LOG "Results:" TO REENTRY_LOG_FILE.
    LOG "--------" TO REENTRY_LOG_FILE.
    LOG lat_land_str TO REENTRY_LOG_FILE.
    LOG lng_land_str TO REENTRY_LOG_FILE.
    LOG land_time_str TO REENTRY_LOG_FILE.
  }

  saveNewCraftFileAndReload().
}

}
