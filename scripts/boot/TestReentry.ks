@LAZYGLOBAL OFF.

IF NOT EXISTS("1:/init.ks") { RUNPATH("0:/init_select.ks"). }
RUNONCEPATH("1:/init.ks").

pOut("TestReentry.ks v1.0.0 20170314").

FOR f IN LIST(
  "lib_runmode.ks",
  "lib_launch_crew.ks",
  "lib_steer.ks",
  "lib_orbit_change.ks",
  "lib_orbit_match.ks",
  "lib_reentry.ks",
  "plot_reentry.ks"
) { RUNONCEPATH(loadScript(f)). }

// set these values ahead of launch
GLOBAL SAT_NAME IS "Reentry Test5 1".
GLOBAL SAT_AP IS 80000.
GLOBAL SAT_LAUNCH_AP IS 125000.
GLOBAL SAT_I IS 0.
GLOBAL SAT_LAN IS -1.
GLOBAL REENTRY_LOG_FILE IS "0:/log/TestReentry5.txt".
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

// short version!
SET SAT_NEXT_AP TO LEXICON(
     80000,   125000,
    125000,   500000,
    500000,  2000000,
   2000000, 12000000,
  12000000, 46400000).

FUNCTION addNodeForPeriapsisVelocity {
  PARAMETER target_vel IS 4000, burn_alt IS 125000, pe_alt IS 30000.

  IF APOAPSIS < burn_alt OR PERIAPSIS > burn_alt {
    SET burn_alt TO (APOAPSIS + PERIAPSIS) / 2.
  }

  LOCAL u_time IS bufferTime().
  LOCAL r_pe IS BODY:RADIUS + pe_alt.
  LOCAL r IS BODY:RADIUS + burn_alt.
  // secondsToAlt is in lib_reentry.ks
  LOCAL n_time IS u_time + secondsToAlt(SHIP, u_time, burn_alt, FALSE).

  // Calculate semimajoraxis based on re-arranging the vis-viva equation
  LOCAL a IS 1 / ((2/r_pe) - (target_vel^2 / BODY:MU)).
  // Calculate eccentricity based on semimajoraxis and periapsis
  LOCAL e IS 1 - (r_pe/a).
  // If we burn at a radius of r to change our orbit to match a and e,
  // what will the true anomaly of this point be, in terms of the new orbit?
  LOCAL ta IS calcTa(a, e, r).
  // Now we can calculate the resultant flightpath angle
  LOCAL fang IS ARCTAN(e * SIN(ta) / (1 + (e * COS(ta)))).
  // and the velocity
  LOCAL v1 IS SQRT(BODY:MU * ((2/r) - (1/a))).

  // Next, we should be able to plot this velocity and flightpath angle as a vector,
  // and pass it into the nodeToVector(desired_velocity_vector, time_of_node) function,
  // which is currently in lib_orbit_match.ks
  LOCAL s_pro IS velAt(SHIP,n_time).
  LOCAL s_pos IS posAt(SHIP,n_time).
  LOCAL s_nrm IS VCRS(s_pro,s_pos).
  LOCAL s_vel0 IS VCRS(s_pos,s_nrm).
  LOCAL s_vel_fp IS ANGLEAXIS(-fang,s_nrm) * s_vel0.
  LOCAL n IS nodeToVector(s_vel_fp:NORMALIZED * v1, n_time).
  addNode(n).
}

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
  LOCAL node_alt IS posAt(SHIP,TIME:SECONDS + 60):MAG - BODY:RADIUS.
  IF ABS(30000-PERIAPSIS) > 250 AND node_alt > (BODY:ATM:HEIGHT + 5000) {
    LOCAL pe_time IS TIME:SECONDS + ETA:PERIAPSIS.
    addNodeForPeriapsisVelocity(velAt(SHIP,pe_time):MAG,node_alt,30000).
    IF NOT execNode(FALSE) { runMode(822). }
  }
  ELSE { runMode(822). }
} ELSE IF rm = 822 {
  plotReentry(REENTRY_LOG_FILE).
  store("doReentry(1,831).").
  doReentry(1,831).

} ELSE IF rm = 831 {
  LOCAL lat_land_str IS "Touchdown latitude: " + ROUND(SHIP:LATITUDE,2) + " degrees.".
  LOCAL lng_land_str IS "Touchdown longitude: " + ROUND(mAngle(SHIP:LONGITUDE),2) + " degrees.".
  LOCAL land_time_str IS "Touchdown timestamp: " + ROUND(TIME:SECONDS) + "s " + formatMET().
  pOut(land_time_str).
  pOut(lat_land_str).
  pOut(lng_land_str).

  reentryExtend().
  WAIT UNTIL cOk().

  IF REENTRY_LOG_FILE <> "" {
    LOG "--------" TO REENTRY_LOG_FILE.
    LOG "Results:" TO REENTRY_LOG_FILE.
    LOG "--------" TO REENTRY_LOG_FILE.
    LOG land_time_str TO REENTRY_LOG_FILE.
    LOG lat_land_str TO REENTRY_LOG_FILE.
    LOG lng_land_str TO REENTRY_LOG_FILE.
  }

  saveNewCraftFileAndReload().
}

}
