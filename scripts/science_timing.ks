@LAZYGLOBAL OFF.

IF NOT EXISTS("1:/init.ks") { RUNPATH("0:/init_select.ks"). }
RUNONCEPATH("1:/init.ks").

pOut("science_timing.ks v1.0.0 20200909").
FOR f IN LIST(
  "lib_steer.ks",
  "lib_probe.ks"
) { RUNONCEPATH(loadScript(f)). }

timingOfContractWaypoints(7,15).

FUNCTION timingOfContractWaypoints
{
  // max_dist in kilometres
  PARAMETER max_dist,days_limit.

  LOCAL etaList IS LIST().
  SET etaList TO listContractWaypointsbyETA(SHIP, max_dist, days_limit).

  FOR details IN etaList {
    LOCAL wp_time IS details[0].
    LOCAL wp_name IS details[1].
    LOCAL ca_dist IS details[2].
    LOCAL wp_spot IS details[3].

LOCAL latitude IS ROUND(wp_spot:LAT,3) + "".
LOCAL longitude IS ROUND(wp_spot:LNG,3) + "".

    LOCAL time_str IS formatTS(wp_time,TIME:SECONDS-MISSIONTIME).
    pOut("Waypoint: " + wp_name + " (" + longitude  + ", " + latitude + ")" +
       ". Expected closest approach of " + ROUND(ca_dist) + "m at " + time_str).
  }
}
