@LAZYGLOBAL OFF.
pOut("lib_orbit_match2.ks v1.0.0 20171109").

FOR f IN LIST(
  "lib_orbit_match.ks"
) { RUNONCEPATH(loadScript(f)). }

FUNCTION orbitRadiusAtTA
{
  PARAMETER planet, ap, pe, ta.
  LOCAL pe_r IS pe + planet:RADIUS.
  LOCAL ap_r IS ap + planet:RADIUS.
  LOCAL a IS (pe_r + ap_r) / 2.
  LOCAL e IS (ap_r - pe_r) / (ap_r + pe_r).
  RETURN (a * (1 - e^2))/ (1 + (e * COS(ta))).
}

FUNCTION nodeMatchAtNode2
{
  PARAMETER u_time, o_normal, ascending, ap, pe, w, i, lan.
pOut("nodeMatchAtNode2").

  LOCAL n_ta IS taAN(u_time,o_normal).
  IF NOT ascending { SET n_ta TO mAngle(n_ta + 180). }
  LOCAL n_time IS u_time + secondsToTA(SHIP,u_time,n_ta).

  LOCAL b IS ORBITAT(SHIP,u_time):BODY.

  LOCAL s_pos IS posAt(SHIP,n_time).
  LOCAL r IS s_pos:MAG.
pOut("Radius at node: " + r + "m.").
  IF r < (pe+b:RADIUS) OR r > (ap+b:RADIUS) { pOut("Node is inside or outside target orbit."). RETURN NODE(n_time,0,0,999999). }

  LOCAL new_a IS ((ap+pe) / 2) + b:RADIUS.
pOut("New semimajoraxis: " + new_a + "m.").
  LOCAL new_e IS (ap-pe) / (ap+pe + (2*b:RADIUS)).
pOut("New eccentricity: " + new_e).

  LOCAL an_vec IS R(0,-lan,0) * SOLARPRIMEVECTOR:NORMALIZED * r.
  LOCAL pe_vec IS ANGLEAXIS(w,o_normal) * an_vec.
  LOCAL new_ta IS VANG(pe_vec,s_pos).
  IF VDOT(o_normal,VCRS(pe_vec,s_pos)) < 0 { SET new_ta TO 360 - new_ta. }
pOut("New true anomaly: " + new_ta).

  LOCAL r_should_be IS orbitRadiusAtTA(b, ap, pe, new_ta).
pOut("Radius of target orbit at this point: " + ROUND(r_should_be) + "m.").
  LOCAL diff_r IS ABS(r - r_should_be).
pOut("Difference: " + ROUND(diff_r) + "m.").

  IF (diff_r > r_should_be/100) { pOut("Too far from target orbit!"). RETURN NODE(n_time,0,0,999999). }

  LOCAL new_fang IS ARCTAN2(new_e*SIN(new_ta),(1 + (new_e * COS(new_ta)))).
 
pOut("New flight angle: " + new_fang).
  LOCAL v1 IS SQRT(b:MU * ((2/r)-(1/new_a))).
pOut("New velocity: " + v1 + "m/s.").
  LOCAL new_vel IS v1 * (ANGLEAXIS(new_fang,o_normal) * VCRS(s_pos,o_normal)):NORMALIZED.
  RETURN nodeToVector(new_vel, n_time).
}

FUNCTION nodeIncMatch2
{
  PARAMETER u_time, o_normal, ap, pe, w, i, lan.

  LOCAL n_AN IS nodeMatchAtNode2(u_time,o_normal,TRUE,ap,pe,w,i,lan).
  LOCAL n_DN IS nodeMatchAtNode2(u_time,o_normal,FALSE,ap,pe,w,i,lan).

  LOCAL dv_AN is nodeDV(n_AN).
  LOCAL dv_DN is nodeDV(n_DN).
  IF (2 * ABS(dv_AN-dv_DN) / (dv_AN + dv_DN)) > 0.2 {
    IF dv_AN < dv_DN { RETURN n_AN. }
    RETURN n_DN.
  }
  IF n_AN:ETA < n_DN:ETA { RETURN n_AN. }
  RETURN n_DN.
}

FUNCTION nodeIncMatchOrbit2
{
  PARAMETER u_time, ap, pe, w, i, lan.
  RETURN nodeIncMatch2(u_time,orbitNormal(ORBITAT(SHIP,u_time):BODY,i,lan),ap,pe,w,i,lan).
}

FUNCTION matchOrbitInc2
{
  PARAMETER can_stage, limit_dv, u_time, ap, pe, w, i, lan.

  LOCAL ok IS TRUE.
  IF lan = -1 { SET lan TO ORBITAT(SHIP,u_time):LAN. }

  IF orbitRelInc(u_time, i, lan) > 0.05 {
    LOCAL n1 IS nodeIncMatchOrbit2(u_time, ap, pe, w, i, lan).
    addNode(n1).
    LOCAL dv_req IS nodeDV(n1).
    pOut("Delta-v requirement: " + ROUND(dv_req,1) + "m/s.").
    IF dv_req > limit_dv AND NOT (can_stage AND moreEngines()) {
      SET ok TO FALSE.
      pOut("ERROR: exceeds delta-v allowance ("+ROUND(limit_dv,1)+"m/s).").
    } ELSE { SET ok TO execNode(can_stage). }
  }

  RETURN ok.
}

FUNCTION doOrbitMatch2
{
  PARAMETER can_stage, limit_dv, ap, pe, w, i, lan IS -1.

  LOCAL ok IS TRUE.
  IF HASNODE {
    IF NEXTNODE:ETA > nodeBuffer() { SET ok TO execNode(can_stage). }
    removeAllNodes().
  }

  LOCAL u_time IS bufferTime().
  IF ok { SET ok TO matchOrbitInc2(can_stage,limit_dv,u_time,ap,pe,w,i,lan). }
  removeAllNodes().
  RETURN ok.
}
