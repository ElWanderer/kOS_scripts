@LAZYGLOBAL OFF.
pOut("lib_geo.ks v1.2.0 20170208").

RUNONCEPATH(loadScript("lib_orbit.ks")).

GLOBAL ONE_DAY IS KUNIVERSE:HOURSPERDAY * 3600.

FUNCTION latOkForInc
{
  PARAMETER lat,i.
  RETURN (i > 0 AND MIN(i,180-i) >= ABS(lat)).
}

FUNCTION firstTAAtLat
{
  PARAMETER o,lat.

  LOCAL i IS o:INCLINATION.
  IF NOT latOkForInc(lat,i) { RETURN -1. }
  LOCAL w IS mAngle(o:ARGUMENTOFPERIAPSIS).
  RETURN mAngle(ARCSIN((SIN(lat)/SIN(i))) - w).
}

FUNCTION secondTAAtLat
{
  PARAMETER o,lat.

  LOCAL i IS o:INCLINATION.
  IF NOT latOkForInc(lat,i) { RETURN -1. }
  LOCAL w IS o:ARGUMENTOFPERIAPSIS.
  LOCAL ta_extreme_lat IS mAngle(90 - w).
  IF lat < 0 { SET ta_extreme_lat TO mAngle(270 - w). }
  LOCAL ta1 IS firstTAAtLat(o,lat).
  RETURN mAngle((2 * ta_extreme_lat) - ta1).
}

FUNCTION spotAtTime
{
  PARAMETER planet,craft,u_time.

  LOCAL p IS planet:ROTATIONPERIOD.
  LOCAL spot IS planet:GEOPOSITIONOF(POSITIONAT(craft,u_time)).
  LOCAL time_diff IS MOD(u_time - TIME:SECONDS,p).
  LOCAL new_lng IS mAngle(spot:LNG - (time_diff * 360 / p)).
  RETURN LATLNG(spot:LAT,new_lng).
}

FUNCTION greatCircleDistance
{
  PARAMETER planet,spot1,spot2.

  LOCAL latD IS spot2:LAT - spot1:LAT.
  LOCAL lngD IS spot2:LNG - spot1:LNG.
  LOCAL h IS ((SIN(latD/2))^2) + (COS(spot1:LAT) * COS(spot2:LAT) * ((SIN(lngD/2))^2)).
  IF h < 0 OR h > 1 { RETURN -1. }
  RETURN (2 * planet:RADIUS * ARCSIN(SQRT(h)) * CONSTANT:DEGTORAD).
}

FUNCTION distAtTime
{
  PARAMETER craft,planet,spot,u_time.
  RETURN greatCircleDistance(planet,spot,spotAtTime(planet,craft,u_time)).
}

FUNCTION findNextPassCA
{
  PARAMETER craft,planet,t_spot,u_time.

  LOCAL step IS 0.04.

  LOCAL ca_dist IS distAtTime(craft,planet,t_spot,u_time).
  LOCAL ca_time IS u_time.

  LOCAL mod_time IS u_time - step.
  IF distAtTime(craft,planet,t_spot,mod_time) < ca_dist { SET step TO -step. }

  LOCAL mod_dist IS ca_dist.
  SET mod_time TO ca_time.
  UNTIL mod_dist > ca_dist {
    SET ca_dist TO mod_dist.
    SET ca_time TO mod_time.
    SET mod_time TO mod_time + step.
    SET mod_dist TO distAtTime(craft,planet,t_spot,mod_time).
  }
  RETURN ca_time.
}

FUNCTION findNextPass
{
  // max_dist in metres
  PARAMETER craft,planet,t_spot,max_dist,days_limit.

  LOCAL u_time IS TIME:SECONDS.
  LOCAL return_time IS 0.
  LOCAL orbit_count IS 0.
  LOCAL found_pass IS FALSE.

  LOCAL s_period IS craft:OBT:PERIOD.
  LOCAL max_orbits IS CEILING(days_limit * ONE_DAY / s_period).

  LOCAL ta1 IS firstTAAtLat(craft:OBT, t_spot:LAT).
  LOCAL ta2 IS secondTAAtLat(craft:OBT, t_spot:LAT).
  LOCAL ta1_time IS u_time + secondsToTA(craft, u_time, ta1).
  LOCAL ta2_time IS u_time + secondsToTA(craft, u_time, ta2).

  LOCAL ta1_first IS TRUE.
  IF ta2_time < ta1_time { SET ta1_first TO FALSE. }

  UNTIL found_pass OR orbit_count >= max_orbits {
    SET orbit_count TO orbit_count + 1.

    LOCAL pass_count IS 0.
    UNTIL found_pass OR pass_count > 1 {
      LOCAL pass_time IS 0.
      IF (pass_count = 0 AND ta1_first) OR
         (pass_count = 1 AND NOT ta1_first) { SET pass_time TO ta1_time. }
      ELSE { SET pass_time TO ta2_time. }

      LOCAL spot IS spotAtTime(planet,craft,pass_time).
      IF ABS(spot:LNG - t_spot:LNG) < 3 {
        LOCAL ca_time IS findNextPassCA(craft,planet,t_spot,pass_time).
        LOCAL dist IS distAtTime(craft,planet,t_spot,ca_time).
        LOCAL eta IS ca_time - TIME:SECONDS.
        IF dist < max_dist AND dist >= 0 {
          SET found_pass TO TRUE.
          SET return_time TO ca_time.
        }
      }
      SET pass_count TO pass_count + 1.
    }

    SET ta1_time TO ta1_time + s_period.
    SET ta2_time TO ta2_time + s_period.
  }
  RETURN return_time.
}

FUNCTION waypointsForBody
{
  PARAMETER planet.

  LOCAL wayList IS LIST().
  FOR wp IN ALLWAYPOINTS() { IF wp:BODY:NAME = planet:NAME { wayList:ADD(wp). } }

  RETURN wayList.
}

FUNCTION addWaypointToList
{
  // first element of wayDetails list should be the ETA
  PARAMETER wayDetails,etaList.

  LOCAL len IS etaList:LENGTH.
  IF len = 0 { etaList:ADD(wayDetails). }
  ELSE {
    LOCAL i IS 0.
    LOCAL inserted IS FALSE.
    UNTIL inserted OR (i >= len) {
      IF wayDetails[0] < etaList[i][0] {
        etaList:INSERT(i,wayDetails).
        SET inserted TO TRUE.
      }
      SET i TO i + 1.
    }
    IF NOT inserted { etaList:ADD(wayDetails). }
  }
  RETURN etaList.
}

FUNCTION listContractWaypointsByETA
{
  // max_dist here is in kilometres
  PARAMETER craft,max_dist,days_limit.

  LOCAL planet IS craft:OBT:BODY.
  LOCAL i IS craft:OBT:INCLINATION.
  LOCAL wayList IS wayPointsForBody(planet).
  LOCAL etaList IS LIST().

  FOR wp IN wayList {
    LOCAL wp_spot IS wp:GEOPOSITION.
    IF wp:NAME<>"Site" AND wp:NAME<>craft:NAME AND latOkForInc(wp_spot:LAT,i) {
      LOCAL wp_eta_time IS findNextPass(craft,planet,wp_spot,max_dist*1000,days_limit).
      LOCAL eta IS wp_eta_time - TIME:SECONDS.
      IF eta >= 0 AND eta <= (days_limit * ONE_DAY) {
        LOCAL wp_dist IS distAtTime(craft,planet,wp_spot,wp_eta_time).
        LOCAL wayDetails IS LIST(wp_eta_time, wp:NAME, wp_dist, wp_spot).
        SET etaList TO addWaypointToList(wayDetails, etaList).
      }
    }
  }
  IF etaList:LENGTH > 0 { pOut("Waypoints passed (times in MET):"). }
  ELSE { pOut("No waypoints passed within time limit."). }
  FOR details IN etaList { IF details[0] > TIME:SECONDS {
    LOCAL time_str IS formatTS(details[0],TIME:SECONDS-MISSIONTIME).
    pOut("At " + time_str + ": " + details[1] + " " + ROUND(details[2]) + "m.",FALSE).
  } }
  RETURN etaList.
}
