@LAZYGLOBAL OFF.
pOut("plot_reentry.ks v1.0.0 20170206").

FOR f IN LIST(
  "lib_reentry.ks",
  "lib_transfer.ks",
  "lib_orbit.ks",
  "lib_geo.ks",
  "lib_dv.ks"
) { RUNONCEPATH(loadScript(f)). }

GLOBAL PLOT_REENTRY_LOG IS "".

// find parts tagged "FINAL" and how much mass would be detached with them
// (assumes that where multiple parts are tagged as such, they are not children of eachother).
FUNCTION finalMass
{
  LOCAL dMass IS 0.
  FOR d IN SHIP:PARTSTAGGED("FINAL") { SET dMass TO dMass + partMass(d). }
  RETURN SHIP:MASS - dMass.
}

FUNCTION shipArea
{
  LOCAL a1 IS CONSTANT:PI*0.625^2. // area of heat shield with diameter 1.25m
  IF SHIP:PARTSNAMED("HeatShield3"):LENGTH > 0 { RETURN a1 * 9. }
  IF SHIP:PARTSNAMED("HeatShield2"):LENGTH > 0 { RETURN a1 * 4. }
  IF SHIP:PARTSNAMED("HeatShield1"):LENGTH > 0 { RETURN a1. }
  IF SHIP:PARTSNAMED("HeatShield0"):LENGTH > 0 { RETURN a1 / 4. }
  pOut("Could not find a heat shield. Assuming 1.25m shield for ballistic purposes.").
  RETURN a1.
}

// lib_geo.ks has a function latAtTA() which doesn't seem to be used anywhere.
// I found this logic for calculating the longitude in my notebook, but it never
// made it into a function.
FUNCTION lngAtTATime
{
  PARAMETER o,ta,u_time.

  LOCAL i IS o:INCLINATION.
  LOCAL rel_ta IS mAngle(ta + o:ARGUMENTOFPERIAPSIS).
  LOCAL rel_lng IS rel_ta.
  IF i > 0 {
    SET rel_lng TO ARCSIN(MAX(-1,MIN(1,TAN(latAtTA(o,ta))/TAN(i)))).
    IF rel_ta >= 90 AND rel_ta < 270 { SET rel_lng TO 180 - rel_lng. }
  }
  LOCAL geo_lng IS mAngle(o:LAN + rel_lng - o:BODY:ROTATIONANGLE).

  RETURN mAngle(geo_lng - ((u_time - TIME:SECONDS) * 360 / o:BODY:ROTATIONPERIOD)).
}

// 
// curr_orb - The current orbit patch or that predicted to follow execution of node.
// dest - The planet we are aiming for (usually KERBIN).
// land_ta - The number of degrees beyond the periapsis, where we predict we will land
//           (can pass in negative numbers for cases where we never reach periapsis).
//           This varies depending on both craft and orbit.
//
// based on testing in KSP v1.1.3, suggested values for returning from a moon of Kerbin
// are as follows:
//   command pods: 20
//   probes:       6
// and for a 85km x 29km Kerbin de-orbit:
//   command pods: -30
// These values may need adjusting for the KSP v1.2.2 atmosphere. We had to shift the
// standard de-orbit burn by 20 degrees, suggesting the land_ta is now actually -50.
//
// Ultimately, we want to be able to predict these based on periapsis velocity and 
// ballistic co-efficient (mass / heat shield surface area).
//
FUNCTION predictReentryForOrbit
{
  PARAMETER curr_orb, dest, land_ta.

  pOut("Current ship mass: " + ROUND(SHIP:MASS,2) + " tonnes.").
  LOCAL m1 IS finalMass().
  pOut("Mass following staging: " + ROUND(m1,2) + " tonnes.").
  LOCAL ca IS shipArea().
  LOCAL bc IS m1/ca.
  LOCAL ship_detail_str IS "Ballistic co-efficient: " + ROUND(bc,2) + ".".
  pOut(ship_detail_str).

  LOCAL orb IS curr_orb.
  LOCAL patch_eta_time IS TIME:SECONDS.
  LOCAL count IS orbitReachesBody(curr_orb, dest).
  IF count > 0 {
    SET patch_eta_time TO futureOrbitETATime(curr_orb,count).
    SET orb TO futureOrbit(curr_orb,count).
  }

  LOCAL u_time IS patch_eta_time + 1.

  LOCAL r IS orb:PERIAPSIS + orb:BODY:RADIUS.
  LOCAL a IS orb:SEMIMAJORAXIS.
  LOCAL pe_vel IS SQRT(orb:BODY:MU * ((2/r)-(1/a))).

  LOCAL atm_eta_time IS u_time + secondsToAlt(SHIP,u_time,BODY:ATM:HEIGHT,FALSE).
  LOCAL atm_spot IS dest:GEOPOSITIONOF(POSITIONAT(SHIP,atm_eta_time)).
  LOCAL atm_lng IS mAngle(atm_spot:LNG - ((atm_eta_time-TIME:SECONDS) * 360 / BODY:ROTATIONPERIOD)).

  LOCAL pe_eta_time IS u_time + secondsToTA(SHIP,u_time,0).
  LOCAL pe_spot IS dest:GEOPOSITIONOF(POSITIONAT(SHIP,pe_eta_time)).
  LOCAL pe_lng IS mAngle(pe_spot:LNG - ((pe_eta_time-TIME:SECONDS) * 360 / BODY:ROTATIONPERIOD)).

  // put estimation of land_ta in here (replacing input parameter), based on pe_vel and bc
  // assuming pe is fixed for now, but may eventually need to vary it too

  //LOCAL land_ta_str IS "Estimated landing " + land_ta + " degrees beyond periapsis.".
  //pOut(land_ta_str).
  LOCAL land_eta_time IS pe_eta_time + (60 * (land_ta / 10)). // rough guess
  LOCAL land_lat IS latAtTA(orb,land_ta).
  LOCAL land_lng IS lngAtTATime(orb, land_ta, land_eta_time).

  pOut("Re-entry orbit details:").
  LOCAL inc_detail_str IS "Inc: " + ROUND(orb:INCLINATION,2) + " degrees.".
  pOut(inc_detail_str).
  pOut("Ap.: " + ROUND(orb:APOAPSIS) + "m.").
  pOut("Pe.: " + ROUND(orb:PERIAPSIS) + "m.").
  LOCAL pe_detail_str IS "Velocity at pe: " + ROUND(pe_vel) + "m/s.".
  pOut(pe_detail_str).
  pOut("Lat (atm interface):  " + ROUND(atm_spot:LAT,2) + " degrees.").
  pOut("Lng (atm interface):  " + ROUND(atm_lng,2) + " degrees.").
  LOCAL lat_pe_str IS "Lat (periapsis): " + ROUND(pe_spot:LAT,2) + " degrees.".
  LOCAL lng_pe_str IS "Lng (periapsis): " + ROUND(pe_lng,2) + " degrees.".
  pOut(lat_pe_str).
  pOut(lng_pe_str).
  //LOCAL lat_pred_str IS "Lat (landing prediction): " + ROUND(land_lat,2) + " degrees.".
  //LOCAL lng_pred_str IS "Lng (landing prediction): " + ROUND(land_lng,2) + " degrees.".
  //pOut(lat_pred_str).
  //pOut(lng_pred_str).
  
  IF PLOT_REENTRY_LOG <> "" AND cOk() {
    LOG "--------" TO PLOT_REENTRY_LOG.
    LOG "Details:" TO PLOT_REENTRY_LOG.
    LOG "--------" TO PLOT_REENTRY_LOG.
    LOG ship_detail_str TO PLOT_REENTRY_LOG.
    LOG pe_detail_str TO PLOT_REENTRY_LOG.
    LOG lat_pe_str TO PLOT_REENTRY_LOG.
    LOG lng_pe_str TO PLOT_REENTRY_LOG.
    LOG inc_detail_str TO PLOT_REENTRY_LOG.
    //LOG "-----------" TO PLOT_REENTRY_LOG.
    //LOG "Prediction:" TO PLOT_REENTRY_LOG.
    //LOG "-----------" TO PLOT_REENTRY_LOG.
    //LOG land_ta_str TO PLOT_REENTRY_LOG.
    //LOG lat_pred_str TO PLOT_REENTRY_LOG.
    //LOG lng_pred_str TO PLOT_REENTRY_LOG.
  }
}

FUNCTION plotReentry
{
  PARAMETER lf IS PLOT_REENTRY_LOG, ta_diff IS 20.
  IF lf <> PLOT_REENTRY_LOG { SET PLOT_REENTRY_LOG TO lf. }
  IF HASNODE { predictReentryForOrbit(NEXTNODE:ORBIT, KERBIN, ta_diff). }
  ELSE { predictReentryForOrbit(SHIP:ORBIT, KERBIN, ta_diff). }
}
