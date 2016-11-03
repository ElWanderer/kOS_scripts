@LAZYGLOBAL OFF.
pOut("lib_probe.ks v1.1.0 20161103").

FOR f IN LIST(
  "lib_steer.ks",
  "lib_geo.ks",
  "lib_science.ks"
) { RUNONCEPATH(loadScript(f)). }

GLOBAL WP_BUFFER IS 30.

FUNCTION pointAtSun
{
  steerSun().
  WAIT UNTIL steerOk().
  steerOff().
}

FUNCTION visitContractWaypoints
{
  // max_dist in kilometres
  PARAMETER max_dist,days_limit.

  pointAtSun().

  LOCAL etaList IS LIST().
  SET etaList TO listContractWaypointsbyETA(SHIP, max_dist, days_limit).

  FOR details IN etaList {
    LOCAL wp_time IS details[0].
    LOCAL wp_name IS details[1].
    LOCAL ca_dist IS details[2].
    LOCAL wp_spot IS details[3].

    LOCAL time_str IS formatTS(wp_time,TIME:SECONDS-MISSIONTIME).
    pOut("Next waypoint: " + wp_name + 
       ". Expected closest approach of " + ROUND(ca_dist) + "m at " + time_str).

    LOCAL warp_time IS wp_time - WP_BUFFER.
    WARPTO(warp_time).
    WAIT UNTIL TIME:SECONDS > warp_time.

    LOCAL prev_dist IS greatCircleDistance(BODY,SHIP:GEOPOSITION,wp_spot).
    LOCAL done IS FALSE.
    UNTIL done {
      WAIT 0.25.
      LOCAL wp_dist IS greatCircleDistance(BODY,SHIP:GEOPOSITION,wp_spot).
      IF NOT done AND wp_dist > prev_dist {
        pOut("Closest approach. Triggering science.").
        doScience(TRUE,FALSE).
        resetScience().
        SET done TO TRUE.
      } ELSE { SET prev_dist TO wp_dist. }
    }

    pointAtSun().
  }
}
