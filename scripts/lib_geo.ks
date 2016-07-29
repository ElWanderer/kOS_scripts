@LAZYGLOBAL OFF.


pOut("lib_geo.ks v1.0 20160714").

RUNONCEPATH(loadScript("lib_orbit.ks")).

GLOBAL ONE_MINUTE IS 60.
GLOBAL ONE_HOUR IS 60 * ONE_MINUTE.
GLOBAL ONE_DAY IS 6 * ONE_HOUR.

FUNCTION latOkForInc
{
  PARAMETER lat.
  PARAMETER i.
  RETURN (i > 0 AND i >= ABS(lat) AND (180 - i) >= ABS(lat)).
}

FUNCTION latAtTA
{
  PARAMETER orb.
  PARAMETER ta.

  LOCAL w IS orb:ARGUMENTOFPERIAPSIS.
  LOCAL i IS orb:INCLINATION.
  RETURN ARCSIN(SIN(i) * SIN(mAngle(ta + w))).
}

FUNCTION firstTAAtLat
{
  PARAMETER orb.
  PARAMETER lat.

  LOCAL ta1 IS -1.
  LOCAL i IS orb:INCLINATION.
  IF latOkForInc(lat,i) {
    LOCAL w IS mAngle(orb:ARGUMENTOFPERIAPSIS).
    SET ta1 TO mAngle(ARCSIN((SIN(lat)/SIN(i))) - w).
  }
  RETURN ta1.
}

FUNCTION secondTAAtLat
{
  PARAMETER orb.
  PARAMETER lat.

  LOCAL ta2 IS -1.
  LOCAL i IS orb:INCLINATION.
  IF latOkForInc(lat,i) {
    LOCAL w IS orb:ARGUMENTOFPERIAPSIS.
    LOCAL ta_extreme_lat IS mAngle(90 - w).
    IF lat < 0 { SET ta_extreme_lat TO mAngle(270 - w). }
    LOCAL ta1 IS firstTAAtLat(orb,lat).
    SET ta2 TO mAngle((2 * ta_extreme_lat) - ta1).
  }
  RETURN ta2.
}

FUNCTION spotAtTime
{
  PARAMETER planet.
  PARAMETER craft.
  PARAMETER u_time.

  LOCAL p IS planet:ROTATIONPERIOD.
  LOCAL spot IS planet:GEOPOSITIONOF(POSITIONAT(craft,u_time)).
  LOCAL time_diff IS MOD(u_time - TIME:SECONDS,p).
  LOCAL new_lng IS mAngle(spot:LNG - (time_diff * 360 / p)).
  RETURN LATLNG(spot:LAT,new_lng).
}

FUNCTION greatCircleDistance
{
  PARAMETER planet.
  PARAMETER spot1.
  PARAMETER spot2.

  LOCAL d IS -1.
  LOCAL latD IS spot2:LAT - spot1:LAT.
  LOCAL lngD IS spot2:LNG - spot1:LNG.
  LOCAL h IS ((SIN(latD/2))^2) + (COS(spot1:LAT) * COS(spot2:LAT) * ((SIN(lngD/2))^2)).
  IF h >= 0 AND h <= 1 { SET d TO 2 * planet:RADIUS * ARCSIN(SQRT(h)) * CONSTANT:DEGTORAD. }
  RETURN d.
}

FUNCTION findNextPassCA
{
  PARAMETER craft.
  PARAMETER planet.
  PARAMETER t_spot. // target geoposition
  PARAMETER u_time.
  LOCAL STEP_TIME IS 0.05. // seconds

  LOCAL spot IS spotAtTime(planet,craft,u_time).
  LOCAL ca_dist IS greatCircleDistance(planet,t_spot,spot).
  LOCAL ca_time IS u_time.

  LOCAL mod_time IS u_time - STEP_TIME.
  SET spot TO spotAtTime(planet,craft,mod_time).
  IF greatCircleDistance(planet,t_spot,spot) < ca_dist { SET STEP_TIME TO -STEP_TIME. }

  LOCAL mod_dist IS ca_dist.
  SET mod_time TO ca_time.
  UNTIL mod_dist > ca_dist {
    SET ca_dist TO mod_dist.
    SET ca_time TO mod_time.
    SET mod_time TO mod_time + STEP_TIME.
    SET spot TO spotAtTime(planet,craft,mod_time).
    SET mod_dist TO greatCircleDistance(planet,t_spot,spot).
  }
  RETURN ca_time.
}

FUNCTION findNextPass
{
  PARAMETER craft.
  PARAMETER planet.
  PARAMETER t_spot. // target geoposition

  PARAMETER max_dist. // metres
  PARAMETER days_limit.

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
        SET spot TO spotAtTime(planet,craft,ca_time).
        LOCAL dist IS greatCircleDistance(planet,t_spot,spot).
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
  PARAMETER wayDetails. // first element of this list should be the ETA
  PARAMETER etaList.

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

FUNCTION padTime
{
  PARAMETER t.
  PARAMETER digits.
  RETURN ("" + t):PADLEFT(digits).
}

FUNCTION formatTime
{
  PARAMETER secs.
  LOCAL ret_time IS "".

  If secs < ONE_DAY { SET ret_time TO "      ". }
  ELSE {
    SET ret_time TO ret_time + padTime(FLOOR(secs/ONE_DAY),4) + "d ".
    SET secs TO MOD(secs,ONE_DAY).
  }

  SET ret_time TO ret_time + padTime(FLOOR(secs/ONE_HOUR),1) + "h ".
  SET secs TO MOD(secs,ONE_HOUR).

  SET ret_time TO ret_time + padTime(FLOOR(secs/ONE_MINUTE),2) + "m ".
  SET secs TO ROUND(MOD(secs,ONE_MINUTE)).

  SET ret_time TO ret_time + padTime(secs,2) + "s".

  RETURN ret_time.
}

FUNCTION listContractWaypointsByETA
{
  PARAMETER craft.
  PARAMETER max_dist. // kilometres
  PARAMETER days_limit.

  LOCAL u_time IS TIME:SECONDS.
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
        LOCAL spot IS spotAtTime(planet,craft,wp_eta_time).
        LOCAL wp_dist IS greatCircleDistance(planet,wp_spot,spot).
        LOCAL wayDetails IS LIST(wp_eta_time, wp:NAME, wp_dist, wp_spot).
        SET etaList TO addWaypointToList(wayDetails, etaList).
      }
    }
  }
  IF etaList:LENGTH > 0 { pOut("Waypoints in order of ETA of closest approach:"). }
  ELSE { pOut("No waypoints passed within time limit."). }
  SET u_time TO TIME:SECONDS.
  FOR details IN etaList {
    LOCAL eta IS ROUND(details[0] - u_time).
    IF eta >= 0 {
      LOCAL time_str IS formatTime(eta).
      PRINT time_str + "   " + details[1] + " " + ROUND(details[2]) + "m.".
    }
  }
  RETURN etaList.
}