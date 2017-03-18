@LAZYGLOBAL OFF.

IF NOT EXISTS("1:/init.ks") { RUNPATH("0:/init_select.ks"). }
RUNONCEPATH("1:/init.ks").

pOut("TestReentry.ks v1.0.0 20170318").

FOR f IN LIST(
  "lib_runmode.ks",
  "lib_launch_crew.ks",
  "lib_steer.ks",
  "lib_orbit_change.ks",
  "lib_reentry.ks",
  "plot_reentry.ks"
) { RUNONCEPATH(loadScript(f)). }

// set these values ahead of launch
GLOBAL SAT_NAME IS "Reentry Test 45".
GLOBAL SAT_AP IS 80000.
GLOBAL SAT_LAUNCH_AP IS 125000.
GLOBAL SAT_I IS 45.
GLOBAL SAT_LAN IS -1.
GLOBAL REENTRY_LEX IS LEXICON().
GLOBAL REENTRY_LOG_FILE IS "0:/log/TestReentry6.txt".
GLOBAL REENTRY_CSV_FILE IS "0:/log/TestReentry6.csv".
GLOBAL REENTRY_CRAFT_FILE IS "0:/craft/" + padRep(0,"_",SAT_NAME) + ".ks".


// long version - replaced by short version unless that is commented out
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

// short version!
SET SAT_NEXT_AP TO LEXICON(
     80000,    85000,
     85000,   100000,
    100000,   125000,
    125000,  1000000,
   1000000, 12000000,
  12000000, 46400000).

FUNCTION saveNewCraftFileAndReload {
  IF EXISTS(REENTRY_CRAFT_FILE) { DELETEPATH(REENTRY_CRAFT_FILE). }
  IF SAT_NEXT_AP:HASKEY(SAT_AP) {
    LOG "FUNCTION updateReentryAP { SET SAT_AP TO " + SAT_NEXT_AP[SAT_AP] + ". }" TO REENTRY_CRAFT_FILE.
    hudMsg("Craft file updated.").
    UNTIL FALSE {
      WAIT 1.
      hudMsg("Waiting until not moving.").
      WAIT UNTIL SHIP:VELOCITY:SURFACE:MAG < 0.1.
      hudMsg("Quickloading...").
      KUNIVERSE:QUICKLOAD().
      WAIT 5.
    }
  } ELSE {
    hudMsg("Simulation finished.").
    WAIT UNTIL FALSE.
  }
}

IF runMode() > 0 { logOn(). }
IF runMode() > 811 AND EXISTS(CRAFT_FILE) { updateReentryAP(). }

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
  ELSE { runMode(819,812). }

} ELSE IF rm = 821 {
  LOCAL node_time IS TIME:SECONDS + 75.
  LOCAL node_alt IS posAt(SHIP,node_time):MAG - BODY:RADIUS.
  IF ABS(30000-PERIAPSIS) > 250 AND node_alt > (BODY:ATM:HEIGHT + 5000) {
    LOCAL a1 IS BODY:RADIUS + ((APOAPSIS + 30000) /2).
    LOCAL r_pe IS 30000 + BODY:RADIUS.
    LOCAL pe_vel IS SQRT(b:MU * ((2/r_pe)-(1/a1))).
    LOCAL ascending IS posAt(SHIP,node_time):MAG > posAt(SHIP,node_time-1):MAG.
    addNodeForPeriapsisVelocity(pe_vel,node_alt,30000,ascending).
    IF NOT execNode(FALSE) { runMode(822). }
  }
  ELSE { runMode(822). }
} ELSE IF rm = 822 {
  SET REENTRY_LEX TO plotReentry(REENTRY_LOG_FILE).
  store("doReentry(1,831).").
  doReentry(1,831).

} ELSE IF rm = 831 {
  logReentry(REENTRY_LOG_FILE, REENTRY_CSV_FILE, REENTRY_LEX).
  saveNewCraftFileAndReload().
}

}
