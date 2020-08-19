@LAZYGLOBAL OFF.

pOut("lib_orbit_change.ks v1.2.0 20201819").

FOR f IN LIST(
  "lib_orbit.ks",
  "lib_burn.ks"
) { RUNONCEPATH(loadScript(f)). }

FUNCTION changeOrbit
{
  PARAMETER doExec, can_stage, limit_dv.
  PARAMETER u_time.
  PARAMETER ap, pe, w, lan.

  LOCAL ok IS TRUE.
  LOCAL dv_req IS 0.

  LOCAL o IS ORBITAT(SHIP,u_time).
  LOCAL w_diff IS 0.
  IF w >= 0 {
    IF lan >= 0 AND (o:INCLINATION < 1 OR o:INCLINATION > 179) {
      SET w_diff TO mAngle(w + lan - (o:ARGUMENTOFPERIAPSIS + o:LAN)).
    } ELSE {
      SET w_diff TO mAngle(w - o:ARGUMENTOFPERIAPSIS).
    }
  }
  LOCAL ap_diff IS ap - o:APOAPSIS.
  LOCAL pe_diff IS pe - o:PERIAPSIS.
  LOCAL double_pe_burn IS (ap < o:PERIAPSIS).

  IF w_diff > 0.05 OR ABS(ap_diff) > (ap / 50) {
    LOCAL n2 IS nodeAlterOrbit(u_time + secondsToTA(SHIP,u_time,w_diff), ap).
    addNode(n2).
    UNTIL NOT n2:ORBIT:HASNEXTPATCH { SET n2:ETA TO n2:ETA + o:PERIOD. }
    IF doExec {
      SET ok TO execNode(can_stage).
      SET u_time TO bufferTime().
    } ELSE {
      SET dv_req TO dv_req + nodeDV(n2).
      SET u_time TO bufferTime(u_time) + n2:ETA.
    }
    SET o TO ORBITAT(SHIP,u_time).
  }

  IF ok AND (w_diff > 0.05 OR ABS(pe_diff) > (pe / 50)) {
    LOCAL ap_ta IS 180.
    IF double_pe_burn { SET ap_ta TO 0. }
    LOCAL n3 IS nodeAlterOrbit(u_time + secondsToTA(SHIP,u_time,ap_ta), pe).
    addNode(n3).
    UNTIL NOT n3:ORBIT:HASNEXTPATCH { SET n3:ETA TO n3:ETA + o:PERIOD. }
    IF doExec { SET ok TO execNode(can_stage). }
    ELSE { SET dv_req TO dv_req + nodeDV(n3). }
  }

  IF ok AND NOT doExec AND dv_req > 0 {
    pOut("Delta-v requirement: " + ROUND(dv_req,1) + "m/s.").
    IF dv_req > limit_dv AND NOT (can_stage AND moreEngines()) {
      SET ok TO FALSE.
      pOut("ERROR: exceeds delta-v allowance ("+ROUND(limit_dv,1)+"m/s).").
    }
  }

  RETURN ok.
}

FUNCTION doOrbitChange
{
  PARAMETER can_stage,limit_dv, ap, pe.
  PARAMETER w IS -1, lan IS -1.

  LOCAL ok IS TRUE.
  IF HASNODE {
    IF NEXTNODE:ETA > nodeBuffer() { SET ok TO execNode(can_stage). }
    removeAllNodes().
  }
  LOCAL u_time IS bufferTime().
  IF ok { SET ok TO changeOrbit(FALSE,can_stage,limit_dv,u_time,ap,pe,w,lan). }
  removeAllNodes().
  IF ok { SET ok TO changeOrbit(TRUE,can_stage,0,u_time,ap,pe,w,lan). }
  removeAllNodes().
  RETURN ok.
}
