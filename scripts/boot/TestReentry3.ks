@LAZYGLOBAL OFF.

// TestReentry3.ks
//
// Launch into LKO then transfer to a moon of Kerbin.
// Once in orbit of that moon, quicksave.
// From the savepoint, transfer back to Kerbin a few times with different start times.
// For each transfer, plot where we think we will land before the burn, after the burn and
// once committed to re-entry. Log the actual results then quickload following landing.
//
// Initially, this test is to see whether the predictReentryForOrbit() function works outside
// of Kerbin orbit.
// Eventually, we would want to test whether we can time a return to Kerbin in such a way as
// to target a spot or set of spots.

IF NOT EXISTS("1:/init.ks") { RUNPATH("0:/init_select.ks"). }
RUNONCEPATH("1:/init.ks").

pOut("TestReentry3.ks v1.0.0 20170321").

FOR f IN LIST(
  "lib_runmode.ks",
  "lib_launch_crew.ks",
  "lib_steer.ks",
  "lib_orbit_match.ks",
  "plot_reentry.ks",
  "plot_transfer_reentry.ks",
  "lib_reentry.ks"
) { RUNONCEPATH(loadScript(f)). }

// set these values ahead of launch
GLOBAL SAT_NAME IS "Reentry Test3 1".
GLOBAL SAT_BODY IS MUN.
GLOBAL SAT_AP IS 120000.
GLOBAL SAT_I IS 0.
GLOBAL SAT_LAN IS 0.
GLOBAL SAT_BODY_I IS SAT_BODY:OBT:INCLINATION.
GLOBAL SAT_BODY_LAN IS SAT_BODY:OBT:LAN.
GLOBAL SAT_ORBITS IS 0.
GLOBAL SAT_MAX_ORBITS IS 10.
GLOBAL SAT_ORBIT_JUMP IS 2.
GLOBAL REENTRY_LEX IS LEXICON().
GLOBAL REENTRY_LOG_FILE IS "0:/log/TestReentry7.txt".
GLOBAL REENTRY_CSV_FILE IS "".
GLOBAL REENTRY_CRAFT_FILE IS "0:/craft/" + padRep(0,"_",SAT_NAME) + ".ks".

FUNCTION saveNewCraftFileAndReload {
  IF EXISTS(REENTRY_CRAFT_FILE) { DELETEPATH(REENTRY_CRAFT_FILE). }
  IF SAT_ORBITS < SAT_MAX_ORBITS {
    LOCAL new_orbits IS SAT_ORBITS + SAT_ORBIT_JUMP.
    LOG "FUNCTION updateOrbits { SET SAT_ORBITS TO " + new_orbits + ". }" TO REENTRY_CRAFT_FILE.
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
IF runMode() > 811 AND EXISTS(CRAFT_FILE) { updateOrbits(). }

UNTIL runMode() = 99 {
LOCAL rm IS runMode().
IF rm < 0 {
  SET SHIP:NAME TO SAT_NAME.
  logOn().

  WAIT UNTIL cOk().
  RUNPATH("0:/lib_launch_geo.ks").

  LOCAL ap IS SAT_LAUNCH_AP.
  LOCAL launch_details IS calcLaunchDetails(ap,SAT_BODY_I,SAT_BODY_LAN).
  LOCAL az IS launch_details[0].
  LOCAL launch_time IS launch_details[1].
  warpToLaunch(launch_time).

  store("doLaunch(801," + ap + "," + az + "," + SAT_BODY_I + ").").
  doLaunch(801,ap,az,SAT_BODY_I).

} ELSE IF rm < 50 {
  resume().

} ELSE IF rm > 50 AND rm < 99 {
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
  store("doTransfer(851, FALSE, "+SAT_BODY+","+SAT_AP+","+SAT_I+","+SAT_LAN+").").
  doTransfer(821, FALSE, SAT_BODY, SAT_AP, SAT_I, SAT_LAN).

} ELSE IF rm = 821 {
  LOCAL do_save IS TRUE.
  LOCAL do_load IS FALSE.
  IF EXISTS(CRAFT_FILE) {
    LOCAL old_orbits IS SAT_ORBITS.
    updateOrbits().
    IF SAT_ORBITS <> old_orbits {
      pOut("SAT_ORBITS now has value: " + SAT_ORBITS + ".").
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
  runMode(831).

} ELSE IF rm = 831 {
  LOCAL warp_time IS TIME:SECONDS + (SAT_ORBITS * SHIP:ORBIT:PERIOD).
  doWarp(warp_time).
  runMode(851).

} ELSE IF rm = 851 {
  store("doTransfer(861, FALSE, KERBIN, 30000, -1, -1, "+REENTRY_LOG_FILE+").").
  doTransfer(861, FALSE, KERBIN, 30000, -1, -1, REENTRY_LOG_FILE).

} ELSE IF rm = 861 {
  SET REENTRY_LEX TO plotReentry(REENTRY_LOG_FILE).
  store("doReentry(1,871).").
  doReentry(1,871).

} ELSE IF rm = 871 {
  logReentry(REENTRY_LOG_FILE, REENTRY_CSV_FILE, REENTRY_LEX).
  saveNewCraftFileAndReload().
}

}
