@LAZYGLOBAL OFF.

pOut("lib_probe.ks v1.1.1 20161104").

FOR f IN LIST(
  "lib_steer.ks",
  "lib_geo.ks",
  "lib_science.ks"
) { RUNONCEPATH(loadScript(f)). }

GLOBAL WP_BUFFER IS 30.

FUNCTION pointAtSun
{
  steerSun().
  WAIT UNTIL steerOk(0.5,5).
  steerOff().
}

FUNCTION visitContractWaypoints
{
  PARAMETER max_dist. // kilometres
  PARAMETER days_limit.

  pointAtSun().

  LOCAL etaList IS LIST().
  SET etaList TO listContractWaypointsbyETA(SHIP, max_dist, days_limit).

  FOR details IN etaList {
    LOCAL wp_time IS details[0].
    LOCAL wp_name IS details[1].
    LOCAL ca_dist IS details[2].
    LOCAL wp_spot IS details[3].

    LOCAL time_str IS formatTime(wp_time - TIME:SECONDS).
    pOut("Next waypoint: " + wp_name + 
       ". Expected closest approach of " + ROUND(ca_dist) + "m in " + time_str).

    doWarp(wp_time - WP_BUFFER).

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
