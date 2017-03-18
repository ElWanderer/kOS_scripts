@LAZYGLOBAL OFF.

IF NOT EXISTS("1:/init.ks") { RUNPATH("0:/init_select.ks"). }
RUNONCEPATH("1:/init.ks").

pOut("TestReentry2.ks v1.0.0 20170318").

FOR f IN LIST(
  "lib_runmode.ks",
  "lib_launch_crew.ks",
  "lib_steer.ks",
  "lib_reentry.ks",
  "plot_reentry.ks"
) { RUNONCEPATH(loadScript(f)). }

// set these values ahead of launch
GLOBAL SAT_NAME IS "Reentry Test2 3".
GLOBAL SAT_PE_VEL IS 2800.
GLOBAL SAT_PE_VEL_JUMP IS 200.
GLOBAL SAT_MAX_PE_VEL IS 4000.
GLOBAL SAT_LAUNCH_AP IS 500000.

// Estimated delta-v required to go from 125km by 125km orbit to re-entry test orbit
//
// periapsis velocity |  delta-v
//-------------------------------
//            2600m/s |  435m/s
//            2800m/s |  710m/s
//            3000m/s |  945m/s
//            3200m/s | 1170m/s
//            3400m/s | 1385m/s
//            3600m/s | 1600m/s
//            3800m/s | 1810m/s
//            4000m/s | 2015m/s
//            4200m/s | 2220m/s
//            4400m/s | 2425m/s

GLOBAL SAT_I IS 45.
GLOBAL SAT_LAN IS -1.
GLOBAL REENTRY_LEX IS LEXICON().
GLOBAL REENTRY_LOG_FILE IS "0:/log/TestReentry6.txt".
GLOBAL REENTRY_CSV_FILE IS "0:/log/TestReentry6.csv".
GLOBAL REENTRY_CRAFT_FILE IS "0:/craft/" + padRep(0,"_",SAT_NAME) + ".ks".

FUNCTION saveNewCraftFileAndReload {
  IF EXISTS(REENTRY_CRAFT_FILE) { DELETEPATH(REENTRY_CRAFT_FILE). }
  IF SAT_PE_VEL < SAT_MAX_PE_VEL {
    LOCAL new_pe_vel IS SAT_PE_VEL + SAT_PE_VEL_JUMP.
    LOG "FUNCTION updateReentryVel { SET SAT_PE_VEL TO " + new_pe_vel + ". }" TO REENTRY_CRAFT_FILE.
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
IF runMode() > 811 AND EXISTS(CRAFT_FILE) { updateReentryVel(). }

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
    LOCAL old_pe_vel IS SAT_PE_VEL.
    updateReentryVel().
    IF SAT_PE_VEL <> old_pe_vel {
      pOut("SAT_PE_VEL now has value: " + SAT_PE_VEL + "m/s.").
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
  runMode(821).

} ELSE IF rm = 821 {
  LOCAL node_time IS TIME:SECONDS + 300.
  LOCAL node_alt IS posAt(SHIP,node_time):MAG - BODY:RADIUS.
  LOCAL ascending IS posAt(SHIP,node_time):MAG > posAt(SHIP,node_time-1):MAG.
  addNodeForPeriapsisVelocity(SAT_PE_VEL,node_alt,30000,ascending).
  IF execNode(TRUE) OR PERIAPSIS < BODY:ATM:HEIGHT { runMode(822). }
  ELSE { runMode(829, 821). }
} ELSE IF rm = 822 {
  LOCAL node_time IS TIME:SECONDS + 75.
  LOCAL node_alt IS posAt(SHIP,node_time):MAG - BODY:RADIUS.
  IF ABS(30000-PERIAPSIS) > 250 AND node_alt > (BODY:ATM:HEIGHT + 5000) {
    LOCAL a1 IS SHIP:ORBIT:SEMIMAJORAXIS.
    IF a1 > 0 { SET a1 TO BODY:RADIUS + ((APOAPSIS + 30000) /2). }
    LOCAL r_pe IS 30000 + BODY:RADIUS.
    LOCAL pe_vel IS SQRT(BODY:MU * ((2/r_pe)-(1/a1))).
    LOCAL ascending IS posAt(SHIP,node_time):MAG > posAt(SHIP,node_time-1):MAG.
    addNodeForPeriapsisVelocity(pe_vel,node_alt,30000,ascending).
    IF NOT execNode(FALSE) { runMode(823). }
  }
  ELSE { runMode(823). }
} ELSE IF rm = 823 {
  SET REENTRY_LEX TO plotReentry(REENTRY_LOG_FILE).
  store("doReentry(1,831).").
  doReentry(1,831).

} ELSE IF rm = 831 {
  logReentry(REENTRY_LOG_FILE, REENTRY_CSV_FILE, REENTRY_LEX).
  saveNewCraftFileAndReload().
}

}
