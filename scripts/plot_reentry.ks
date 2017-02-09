@LAZYGLOBAL OFF.
pOut("plot_reentry.ks v1.0.0 20170208").

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
  IF x < 70 { SET po TO (40 * LOG10(x)) -95. }
  ELSE IF x < 170 { SET po TO (32 * LOG10(x)) -80. }
  ELSE IF x < 400 { SET po TO (19 * LOG10(x)) -50.75. }
  ELSE IF x < 750 { SET po TO (14 * LOG10(x)) -38. }
  ELSE { SET po TO (5 * LOG10(x)) -12.15. }

  RETURN po.
}

// 
// curr_orb - The current orbit patch or that predicted to follow execution of node.
// dest - The planet we are aiming for (usually KERBIN).
FUNCTION predictReentryForOrbit
{
  PARAMETER curr_orb, dest.

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
  LOCAL land_eta_time IS pe_eta_time + (60 * (land_ta / 10)). // rough guess
  LOCAL land_lat IS latAtTA(orb,land_ta).
  LOCAL land_lng IS lngAtTATime(orb, land_ta, land_eta_time).

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
}

FUNCTION plotReentry
{
  PARAMETER lf IS PLOT_REENTRY_LOG.
  IF lf <> PLOT_REENTRY_LOG { SET PLOT_REENTRY_LOG TO lf. }
  IF HASNODE { predictReentryForOrbit(NEXTNODE:ORBIT, KERBIN). }
  ELSE { predictReentryForOrbit(SHIP:ORBIT, KERBIN). }
}
