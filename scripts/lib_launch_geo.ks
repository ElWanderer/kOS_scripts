@LAZYGLOBAL OFF.
pOut("lib_launch_geo.ks v1.1.0 20170215").

GLOBAL HALF_LAUNCH IS 145.

FUNCTION changeHALF_LAUNCH
{
  PARAMETER h.
  IF h > 0 { SET HALF_LAUNCH TO h. }
}

FUNCTION latIncOk
{
  PARAMETER lat,i.
  RETURN (i > 0 AND ABS(lat) < 90 AND MIN(i,180-i) >= ABS(lat)).
}

FUNCTION etaToOrbitPlane
{
  PARAMETER is_AN, orb_lan, i, ship_lat, ship_lng.

  LOCAL eta IS -1.
  IF latIncOk(ship_lat,i) {
    LOCAL rel_lng IS ARCSIN(TAN(ship_lat)/TAN(i)).
    IF NOT is_AN { SET rel_lng TO 180 - rel_lng. }
    LOCAL g_lan IS mAngle(orb_lan + rel_lng - BODY:ROTATIONANGLE).
    LOCAL node_angle IS mAngle(g_lan - ship_lng).
    SET eta TO (node_angle / 360) * BODY:ROTATIONPERIOD.
  }
  RETURN eta.
}

FUNCTION azimuth
{
  PARAMETER i.
  IF latIncOk(LATITUDE,i) { RETURN mAngle(ARCSIN(COS(i) / COS(LATITUDE))). }
  RETURN -1.
}

FUNCTION launchAzimuth
{
  PARAMETER az, ap.

  LOCAL v_orbit IS SQRT(BODY:MU/(BODY:RADIUS + ap)).
  LOCAL v_rot IS SHIP:GEOPOSITION:ALTITUDEVELOCITY(ALTITUDE):ORBIT:MAG.
  LOCAL v_orbit_x IS v_orbit * SIN(az).
  LOCAL v_orbit_y IS v_orbit * COS(az).
  RETURN mAngle(90 - ARCTAN2(v_orbit_y, v_orbit_x - v_rot)).
}

FUNCTION noPassLaunchDetails
{
  PARAMETER ap,i,lan.

  LOCAL az IS 90.
  LOCAL lat IS MIN(i, 180-i).
  IF i > 90 { SET az TO 270. }

  IF i = 0 OR i = 180 { RETURN LIST(az,0). }

  LOCAL eta IS 0.
  IF LATITUDE > 0 { SET eta TO etaToOrbitPlane(TRUE,lan,i,lat,LONGITUDE). }
  ELSE { SET eta TO etaToOrbitPlane(FALSE,lan,i,-lat,LONGITUDE). }
  LOCAL launch_time IS TIME:SECONDS + eta - HALF_LAUNCH.
  RETURN LIST(az,launch_time).
}

FUNCTION launchDetails
{
  PARAMETER ap,i,lan,az.

  LOCAL eta IS 0.
  SET az TO launchAzimuth(az,ap).
  LOCAL eta_to_AN IS etaToOrbitPlane(TRUE,lan,i,LATITUDE,LONGITUDE).
  LOCAL eta_to_DN IS etaToOrbitPlane(FALSE,lan,i,LATITUDE,LONGITUDE).

  IF eta_to_DN < 0 AND eta_to_AN < 0 { RETURN noPassLaunchDetails(ap,i,lan). }
  ELSE IF (eta_to_DN < eta_to_AN OR eta_to_AN < HALF_LAUNCH) AND eta_to_DN >= HALF_LAUNCH {
    SET eta TO eta_to_DN.
    SET az TO mAngle(180 - az).
  } ELSE IF eta_to_AN >= HALF_LAUNCH { SET eta TO eta_to_AN. }
  ELSE { SET eta TO eta_to_AN + BODY:ROTATIONPERIOD. }
  LOCAL launch_time IS TIME:SECONDS + eta - HALF_LAUNCH.
  RETURN LIST(az,launch_time).
}

FUNCTION calcLaunchDetails
{
  PARAMETER ap,i,lan.

  LOCAL az IS azimuth(i).
  IF az < 0 { RETURN noPassLaunchDetails(ap,i,lan). }
  RETURN launchDetails(ap,i,lan,az).
}

FUNCTION warpToLaunch
{
  PARAMETER launch_time.
  IF launch_time - TIME:SECONDS > 5 {
    pOut("Waiting for orbit plane to pass overhead.").
    UNTIL WARPMODE = "RAILS" { SET WARPMODE TO "RAILS". SET WARP TO 1. WAIT 0.2. }
    doWarp(launch_time).
  }
}
