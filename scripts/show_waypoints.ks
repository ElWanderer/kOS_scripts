@LAZYGLOBAL OFF.

IF NOT EXISTS("1:/init.ks") { RUNPATH("0:/init_select.ks"). }
RUNONCEPATH("1:/init.ks").

pOut("show_waypoints.ks v1.0.0 20201102").
FOR f IN LIST(
  "lib_draw.ks",
  "lib_steer.ks",
  "lib_probe.ks"
) { RUNONCEPATH(loadScript(f)). }

LOCAL abortValue IS ABORT.
LOCAL waypointCount IS 0.

UNTIL abortValue <> ABORT {

  LOCAL waypoints IS waypointsForBody(BODY).

  IF waypoints:LENGTH <> waypointCount {
    wipeVectors().
    SET waypointCount TO waypoints:LENGTH.
  }

  FOR wp IN waypoints {
    IF wp:NAME<>"Site" AND wp:NAME<>SHIP:NAME {
      LOCAL label IS wp:NAME + " " + ROUND(wp:POSITION:MAG) + "m".
      drawVector(wp:NAME, V(0,0,0), wp:POSITION, label, RED).

      LOCAL geo IS wp:GEOPOSITION.
      LOCAL TODO1 IS geo:ALTITUDEPOSITION(geo:TERRAINHEIGHT+1000).
      drawVector(wp:NAME + "v", TODO1, wp:POSITION-TODO1, "", YELLOW, 1, 1).
    }
  }

  WAIT 0.
}

wipeVectors().
