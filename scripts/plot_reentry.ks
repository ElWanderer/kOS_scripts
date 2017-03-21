@LAZYGLOBAL OFF.
pOut("plot_reentry.ks v1.0.0 20170321").

FOR f IN LIST(
  "lib_reentry.ks",
  "plot_transfer_reentry.ks",
  "lib_orbit.ks",
  "lib_orbit_match.ks",
  "lib_geo.ks",
  "lib_dv.ks"
) { RUNONCEPATH(loadScript(f)). }

GLOBAL PLOT_REENTRY_LOG IS "".

FUNCTION addNodeForPeriapsisVelocity {
  PARAMETER target_vel IS 4000, burn_alt IS 125000, pe_alt IS 30000, ascending IS FALSE.

  IF PERIAPSIS > burn_alt OR (APOAPSIS > 0 AND APOAPSIS < burn_alt) {
    SET burn_alt TO (APOAPSIS + PERIAPSIS) / 2.
  }

  LOCAL u_time IS bufferTime().
  LOCAL r_pe IS BODY:RADIUS + pe_alt.
  LOCAL r IS BODY:RADIUS + burn_alt.
  // secondsToAlt is in lib_reentry.ks
  LOCAL n_time IS u_time + secondsToAlt(SHIP, u_time, burn_alt, ascending).

  // Calculate semimajoraxis based on re-arranging the vis-viva equation
  LOCAL a IS 1 / ((2/r_pe) - (target_vel^2 / BODY:MU)).
  // Calculate eccentricity based on semimajoraxis and periapsis
  LOCAL e IS 1 - (r_pe/a).
  // If we burn at a radius of r to change our orbit to match a and e,
  // what will the true anomaly of this point be, in terms of the new orbit?
  // Note - this assumes will we be descending at this point of the new orbit.
  LOCAL ta IS 360 - calcTa(a, e, r).
  // Now we can calculate the resultant flightpath angle
  LOCAL fang IS ARCTAN2(e * SIN(ta), 1 + (e * COS(ta))).
  // and the velocity
  LOCAL v1 IS SQRT(BODY:MU * ((2/r) - (1/a))).

  // Next, we should be able to plot this velocity and flightpath angle as a vector,
  // and pass it into the nodeToVector(desired_velocity_vector, time_of_node) function,
  // which is currently in lib_orbit_match.ks
  LOCAL s_pro IS velAt(SHIP,n_time).
  LOCAL s_pos IS posAt(SHIP,n_time).
  LOCAL s_nrm IS VCRS(s_pro,s_pos).
  LOCAL s_vel0 IS VCRS(s_pos,s_nrm).
  LOCAL s_vel_fp IS ANGLEAXIS(fang,s_nrm) * s_vel0.
  LOCAL n IS nodeToVector(s_vel_fp:NORMALIZED * v1, n_time).
  addNode(n).
}

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

FUNCTION clamp
{
  PARAMETER low,p,high.
  RETURN MAX(low,MIN(high,p)).
}

// lib_geo.ks has this function latAtTA() which doesn't seem to be used anywhere.
FUNCTION latAtTA
{
  PARAMETER o,ta.

  LOCAL w IS o:ARGUMENTOFPERIAPSIS.
  LOCAL i IS o:INCLINATION.
  LOCAL lat IS ARCSIN(clamp(-1,SIN(i) * SIN(ta + w),1)).
  RETURN lat.
}

// I found this logic for calculating the longitude in my notebook, but it never
// made it into a function.
FUNCTION lngAtTATime
{
  PARAMETER o,ta,u_time.

  LOCAL i IS o:INCLINATION.
  LOCAL w IS o:ARGUMENTOFPERIAPSIS.
  LOCAL rel_ta IS mAngle(ta + w).
  LOCAL rel_lng IS rel_ta.
  IF i > 0 {
    SET rel_lng TO ARCSIN(clamp(-1,TAN(latAtTA(o,ta))/TAN(i),1)).
    IF rel_ta >= 90 AND rel_ta < 270 { SET rel_lng TO 180 - rel_lng. }
  }
  LOCAL geo_lng IS mAngle(o:LAN + rel_lng - o:BODY:ROTATIONANGLE).
  LOCAL lng IS mAngle(geo_lng - ((u_time - TIME:SECONDS) * 360 / o:BODY:ROTATIONPERIOD)).
  RETURN lng.
}

// How far past the plotted periapsis will we land?
FUNCTION predictOvershoot
{
  PARAMETER v_pe, bc IS 1.

  // This function is based on the best-fit line for a craft with a BC of 1.1,
  // albeit one that seems to have suffered from higher drag than other test
  // craft with lower BC values.
  // Eventually the results need to be adjusted for BC.
  LOCAL po IS 0.
  LOCAL x IS v_pe - 2400.
  IF x < 75 { SET po TO (45 * LOG10(x)) -106. }
  ELSE IF x < 210 { SET po TO (31 * LOG10(x)) -80. }
  ELSE IF x < 400 { SET po TO (20 * LOG10(x)) -54.5. }
  ELSE IF x < 750 { SET po TO (15 * LOG10(x)) -41.5. }
  ELSE { SET po TO (9 * LOG10(x)) -24.25. }

  RETURN po.
}

// This seems to work fairly well in roughly predicting the actual touchdown time.
// Naturally, that's heavily influenced by the height at which parachutes deploy and open,
// so this is only a best guess.
FUNCTION predictLandingTime
{
  PARAMETER pe_eta_time, ta_overshoot.
  RETURN pe_eta_time + (160 + (ta_overshoot * 5)).
}

// In order to work out the longitude at which we will land, land_eta_time needs 
// reducing to account for time spent vertical/near-vertical, at which point we're
// barely moving with respect to the rotating ground.
// Interestingly, retrograde orbits seem to need a pretty similar adjustment to
// prograde orbits with a similar angle from the equator. Polar orbits require the
// smallest adjustment.
FUNCTION adjustedLandingTime
{
  PARAMETER land_eta_time, i, pe_vel, bc IS 1.
  LOCAL low_vel_est IS 60 * (2 + ABS(3.75 * COS(i)^2)).
  LOCAL high_vel_est IS 60 * (2 + ABS(2.2 * COS(i))).
  IF pe_vel < 2430 { RETURN land_eta_time - low_vel_est. }
  IF pe_vel > 2440 { RETURN land_eta_time - high_vel_est. }
  RETURN land_eta_time - ((low_vel_est + high_vel_est) / 2).
}

// 
// curr_orb - The current orbit patch or that predicted to follow execution of node.
// dest - The planet we are aiming for (usually KERBIN).
FUNCTION predictReentryForOrbit
{
  PARAMETER curr_orb, dest.

  LOCAL return_details IS LEXICON().

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

  // estimate how far past periapsis we will land
  LOCAL land_ta IS predictOvershoot(pe_vel, bc).
  LOCAL pe_detail_str IS "Velocity at pe: " + ROUND(pe_vel) + "m/s.".
  pOut(pe_detail_str).
  LOCAL land_ta_str IS "Estimated landing " + ROUND(land_ta,2) + " degrees beyond periapsis.".
  pOut(land_ta_str).
  LOCAL land_eta_time IS predictLandingTime(pe_eta_time, land_ta).
  LOCAL land_lat IS latAtTA(orb,land_ta).
  LOCAL land_lng IS lngAtTATime(orb, land_ta, adjustedLandingTime(land_eta_time,orb:INCLINATION,pe_vel)).

  pOut("Re-entry orbit details:").
  LOCAL inc_detail_str IS "Inc: " + ROUND(orb:INCLINATION,2) + " degrees.".
  pOut(inc_detail_str).
  pOut("Ap.: " + ROUND(orb:APOAPSIS) + "m.").
  pOut("Pe.: " + ROUND(orb:PERIAPSIS) + "m.").

  pOut("Lat (atm interface):  " + ROUND(atm_spot:LAT,2) + " degrees.").
  pOut("Lng (atm interface):  " + ROUND(atm_lng,2) + " degrees.").
  LOCAL lat_pe_str IS "Lat (periapsis): " + ROUND(pe_spot:LAT,2) + " degrees.".
  LOCAL lng_pe_str IS "Lng (periapsis): " + ROUND(pe_lng,2) + " degrees.".
  pOut(lat_pe_str).
  pOut(lng_pe_str).
  LOCAL pe_time_str IS "Time (periapsis): " + ROUND(pe_eta_time) + "s " + formatTS(pe_eta_time, TIME:SECONDS - MISSIONTIME).
  pOut(pe_time_str).
  LOCAL land_time_str IS "Time (landing prediction): " + ROUND(land_eta_time) + "s " + formatTS(land_eta_time, TIME:SECONDS - MISSIONTIME).
  pOut(land_time_str).
  LOCAL lat_pred_str IS "Lat (landing prediction): " + ROUND(land_lat,2) + " degrees.".
  LOCAL lng_pred_str IS "Lng (landing prediction): " + ROUND(land_lng,2) + " degrees.".
  pOut(lat_pred_str).
  pOut(lng_pred_str).
  
  IF PLOT_REENTRY_LOG <> "" AND cOk() {
    LOG "--------" TO PLOT_REENTRY_LOG.
    LOG "Details:" TO PLOT_REENTRY_LOG.
    LOG "--------" TO PLOT_REENTRY_LOG.
    LOG ship_detail_str TO PLOT_REENTRY_LOG.
    LOG pe_detail_str TO PLOT_REENTRY_LOG.
    LOG pe_time_str TO PLOT_REENTRY_LOG.
    LOG lat_pe_str TO PLOT_REENTRY_LOG.
    LOG lng_pe_str TO PLOT_REENTRY_LOG.
    LOG inc_detail_str TO PLOT_REENTRY_LOG.
    LOG "-----------" TO PLOT_REENTRY_LOG.
    LOG "Prediction:" TO PLOT_REENTRY_LOG.
    LOG "-----------" TO PLOT_REENTRY_LOG.
    LOG land_ta_str TO PLOT_REENTRY_LOG.
    LOG land_time_str TO PLOT_REENTRY_LOG.
    LOG lat_pred_str TO PLOT_REENTRY_LOG.
    LOG lng_pred_str TO PLOT_REENTRY_LOG.
  }

// details to put in csv:
// ship name, mass, ballistic coefficient, inclination, periapsis, periapsis velocity, ta overshoot,
// periapsis time/lat/lng,
// predicted time/lat/lng,
// actual time/lat/lng, distance between prediction and actual (to be added later)

  return_details:ADD("Name", SHIP:NAME:REPLACE(",","")).
  return_details:ADD("Mass", ROUND(m1,2)).
  return_details:ADD("BC", ROUND(bc,2)).
  return_details:ADD("Inclination", ROUND(orb:INCLINATION,2)).
  return_details:ADD("Periapsis", ROUND(orb:PERIAPSIS)).
  return_details:ADD("V(pe)", ROUND(pe_vel)).
  return_details:ADD("Predicted overshoot", ROUND(land_ta,2)).
  return_details:ADD("Periapsis time", ROUND(pe_eta_time)).
  return_details:ADD("Periapsis lat", ROUND(pe_spot:LAT,2)).
  return_details:ADD("Periapsis lng", ROUND(pe_lng,2)).
  return_details:ADD("Predicted time", ROUND(land_eta_time)).
  return_details:ADD("Predicted lat", ROUND(land_lat,2)).
  return_details:ADD("Predicted lng", ROUND(land_lng,2)).

  RETURN return_details.
}

FUNCTION plotReentry
{
  PARAMETER lf IS PLOT_REENTRY_LOG.
  IF lf <> PLOT_REENTRY_LOG { SET PLOT_REENTRY_LOG TO lf. }
  IF HASNODE { RETURN predictReentryForOrbit(NEXTNODE:ORBIT, KERBIN). }
  ELSE { RETURN predictReentryForOrbit(SHIP:ORBIT, KERBIN). }
}

FUNCTION logReentry
{
  PARAMETER log_file, csv_file IS "", csv_lex IS LEXICON().

  LOCAL lat_land_str IS "Touchdown latitude: " + ROUND(SHIP:LATITUDE,2) + " degrees.".
  LOCAL lng_land_str IS "Touchdown longitude: " + ROUND(mAngle(SHIP:LONGITUDE),2) + " degrees.".
  LOCAL land_time_str IS "Touchdown timestamp: " + ROUND(TIME:SECONDS) + "s " + formatMET().
  pOut(land_time_str).
  pOut(lat_land_str).
  pOut(lng_land_str).

  reentryExtend().
  WAIT UNTIL cOk().

  IF log_file <> "" {
    LOG "--------" TO log_file.
    LOG "Results:" TO log_file.
    LOG "--------" TO log_file.
    LOG land_time_str TO log_file.
    LOG lat_land_str TO log_file.
    LOG lng_land_str TO log_file.
  }

  IF csv_lex:LENGTH > 0 {

    csv_lex:ADD("Actual time", ROUND(TIME:SECONDS)).
    csv_lex:ADD("Actual lat", ROUND(SHIP:LATITUDE,2)).
    csv_lex:ADD("Actual lng", ROUND(mAngle(SHIP:LONGITUDE),2)).

    IF csv_lex:HASKEY("Predicted lat") AND csv_lex:HASKEY("Predicted lng") {
      LOCAL p_lat IS csv_lex["Predicted lat"].
      LOCAL p_lng IS csv_lex["Predicted lng"].
      LOCAL p_spot IS LATLNG(p_lat,p_lng).
      LOCAL a_spot IS LATLNG(SHIP:LATITUDE, SHIP:LONGITUDE).
      LOCAL dist IS greatCircleDistance(BODY, p_spot, a_spot).

      LOCAL dist_str IS "Touchdown distance from prediction: " + ROUND(dist/1000,1) + "km.".
      pOut(dist_str).
      IF log_file <> "" { LOG dist_str TO log_file. }
      csv_lex:ADD("Prediction error (km)",ROUND(dist/1000,1)).
    }

    IF csv_file <> "" {
      IF NOT EXISTS(csv_file) {
        LOCAL csv_header IS "".
        FOR key IN csv_lex:KEYS { SET csv_header TO csv_header + key + ",". }
        LOG csv_header TO csv_file.
      }

      LOCAL csv_values IS "".
      FOR val IN csv_lex:VALUES { SET csv_values TO csv_values + val + ",". }
      LOG csv_values TO csv_file.
    }
  }

}
