@LAZYGLOBAL OFF.

pOut("lib_orbit_match.ks v1.1.0test 20161114").

FOR f IN LIST(
  "lib_orbit.ks",
  "lib_burn.ks"
) { RUNONCEPATH(loadScript(f)). }

FUNCTION orbitNormal
{
  PARAMETER planet, i, lan.
  
  LOCAL o_pos IS R(0,-lan,0) * SOLARPRIMEVECTOR:NORMALIZED.
  LOCAL o_vec IS ANGLEAXIS(-i,o_pos) * VCRS(planet:ANGULARVEL,o_pos):NORMALIZED.
  RETURN VCRS(o_vec,o_pos).
}

FUNCTION craftNormal
{
  PARAMETER c, u_time.
  RETURN VCRS(velAt(c,u_time),posAt(c,u_time)).
}

FUNCTION orbitRelInc
{
  PARAMETER u_time, i, lan.
  RETURN VANG(craftNormal(SHIP,u_time), orbitNormal(ORBITAT(SHIP,u_time):BODY,i,lan)).
}

FUNCTION craftRelInc
{
  PARAMETER t, u_time.
  RETURN VANG(craftNormal(SHIP,u_time), craftNormal(t,u_time)).
}

FUNCTION taAN
{
  PARAMETER u_time, o_normal.
  LOCAL s_pos IS posAt(SHIP,u_time).
  LOCAL s_normal IS craftNormal(SHIP,u_time).
  LOCAL nodes IS VCRS(s_normal,o_normal).
  LOCAL ang IS VANG(s_pos,nodes).
  IF VDOT(s_normal,VCRS(nodes,s_pos)) < 0 { SET ang TO 360 - ang. }
  RETURN mAngle(ang + taAt(SHIP,u_time)).
}

FUNCTION nodeMatchAtNode
{
  PARAMETER u_time, o_normal, ascending.

  LOCAL n_ta IS taAN(u_time,o_normal).
  IF NOT ascending { SET n_ta TO mAngle(n_ta + 180). }

  LOCAL n_time IS u_time + secondsToTA(SHIP,u_time,n_ta).
  LOCAL s_normal IS craftNormal(SHIP,n_time).
  LOCAL ang IS VANG(s_normal,o_normal).

// remove this
  pOut("Angle between normals: " + ROUND(ang,2)).
  
// remove this (old vector way)
  LOCAL n_r IS radiusAtTA(ORBITAT(SHIP,u_time),n_ta).
  LOCAL n_normal IS s_normal:MAG * o_normal:NORMALIZED.
  LOCAL dv IS (n_normal - s_normal):MAG / n_r.

// and this (new vector way)
  LOCAL s_vel IS velAt(SHIP,n_time).
  LOCAL dv2 IS ((ANGLEAXIS(ang,s_normal) * s_vel) - s_vel):MAG.

// and this (law of cosines)
  LOCAL dv3 IS SQRT(2 * velAt(SHIP,n_time):SQRMAGNITUDE * (1-COS(ang))).

// if this works (law of cosines with versine identity to simplify)
  LOCAL dv4 IS 2 * velAt(SHIP,n_time):MAG * SIN(ang/2).

// remove all this
  pOut("dv (old vector way):  " + ROUND(dv,2) + "m/s.").
  pOut("dv2 (new vector way): " + ROUND(dv2,2) + "m/s.").
  pOut("dv3 (law of cosines): " + ROUND(dv3,2) + "m/s.").
  pOut("dv4 (law of cosines): " + ROUND(dv4,2) + "m/s.").

  LOCAL dv_pro IS -1 * ABS(dv * SIN(ang / 2)).
  LOCAL dv_norm IS dv * COS(ang / 2).
  IF ascending { SET dv_norm TO -1 * dv_norm. }

// remove all this
  pOut("---").
  pOut("Using old vector way:").
  LOCAL n IS NODE(n_time,0,dv_norm,dv_pro).
  LOCAL old_vel IS velAt(SHIP,n_time+0.2).
  pOut("Velocity vector before burn: " + old_vel).
  pOut("Velocity before burn: " + ROUND(old_vel:MAG,2)).
  pOrbit(SHIP:ORBIT).
  addNode(n).
  LOCAL new_vel IS velAt(SHIP,n_time+0.2).
  pOut("Velocity vector after burn: " + new_vel).
  pOut("Velocity after burn: " + ROUND(new_vel:MAG,2)).
  REMOVE n. WAIT 0.
  pOut("---").
  pOut("Using law of cosines:").
  LOCAL dv_pro4 IS -1 * ABS(dv4 * SIN(ang / 2)).
  LOCAL dv_norm4 IS dv4 * COS(ang / 2).
  IF ascending { SET dv_norm4 TO -1 * dv_norm4. }
  LOCAL n4 IS NODE(n_time,0,dv_norm4,dv_pro4).
  pOut("Velocity vector before burn: " + old_vel).
  pOut("Velocity before burn: " + ROUND(old_vel:MAG,2)).
  pOrbit(SHIP:ORBIT).
  addNode(n4).
  pOut("Velocity vector after burn: " + new_vel).
  SET new_vel TO velAt(SHIP,n_time+0.2).
  pOut("Velocity after burn: " + ROUND(new_vel:MAG,2)).
  REMOVE n4. WAIT 0.
  pOut("---").

  RETURN NODE(n_time,0,dv_norm,dv_pro).
}

FUNCTION nodeIncMatch
{
  PARAMETER u_time, o_normal.

  LOCAL n_AN IS nodeMatchAtNode(u_time,o_normal,TRUE).
  LOCAL n_DN IS nodeMatchAtNode(u_time,o_normal,FALSE).

  LOCAL dv_AN is nodeDV(n_AN).
  LOCAL dv_DN is nodeDV(n_DN).
  IF (2 * ABS(dv_AN-dv_DN) / (dv_AN + dv_DN)) > 0.2 {
    IF dv_AN < dv_DN { RETURN n_AN. }
    RETURN n_DN.
  }
  IF n_AN:ETA < n_DN:ETA { RETURN n_AN. }
  RETURN n_DN.
}

FUNCTION nodeIncMatchTarget
{
  PARAMETER t, u_time.
  RETURN nodeIncMatch(u_time,craftNormal(t,u_time)).
}

FUNCTION nodeIncMatchOrbit
{
  PARAMETER u_time, i, lan.
  RETURN nodeIncMatch(u_time,orbitNormal(ORBITAT(SHIP,u_time):BODY,i,lan)).
}

FUNCTION matchOrbitInc
{
  PARAMETER can_stage, limit_dv, u_time, i, lan.

  LOCAL ok IS TRUE.
  IF lan = -1 { SET lan TO ORBITAT(SHIP,u_time):LAN. }

// checking...
  pOut("---------------------------").
  pOut("Target inclination: " + ROUND(i,3)).
  pOut("Target LAN:         " + ROUND(lan,3)).
  pOut("---------------------------").

  IF orbitRelInc(u_time, i, lan) > 0.05 {
    LOCAL n1 IS nodeIncMatchOrbit(u_time, i, lan).
    addNode(n1).
    LOCAL dv_req IS nodeDV(n1).
    pOut("Delta-v requirement: " + ROUND(dv_req,1) + "m/s.").
    IF dv_req > limit_dv {
      SET ok TO FALSE.
      pOut("ERROR: exceeds delta-v allowance ("+ROUND(limit_dv,1)+"m/s).").
    } ELSE { SET ok TO execNode(can_stage). }
  }

// checking...
  pOut("---------------------------").
  pOut("Result inclination: " + ROUND(SHIP:ORBIT:INCLINATION,3)).
  pOut("Result LAN:         " + ROUND(SHIP:ORBIT:LAN,3)).
  pOut("---------------------------").

  RETURN ok.
}

FUNCTION doOrbitMatch
{
  PARAMETER can_stage, limit_dv, i, lan IS -1.

  LOCAL ok IS TRUE.
  IF HASNODE {
    IF NEXTNODE:ETA > nodeBuffer() { SET ok TO execNode(can_stage). }
    removeAllNodes().
  }

  LOCAL u_time IS bufferTime().
  IF ok { SET ok TO matchOrbitInc(can_stage,limit_dv,u_time,i,lan). }
  removeAllNodes().
  RETURN ok.
}
