@LAZYGLOBAL OFF.


pOut("lib_orbit_match.ks v1.0 20160714").

FOR f IN LIST(
  "lib_orbit.ks",
  "lib_burn.ks"
) { RUNONCEPATH(loadScript(f)). }

FUNCTION orbitNormal
{
  PARAMETER planet.
  PARAMETER ap, pe, i, lan, w.

  LOCAL r_AP IS ap + planet:RADIUS.
  LOCAL r_PE IS pe + planet:RADIUS.

  LOCAL o_ta IS mAngle(-w).
  LOCAL o_a IS (r_AP + r_PE) / 2.
  LOCAL o_e IS (r_AP - r_PE) / (r_AP + r_PE).
  LOCAL o_r IS (o_a * (1 - o_e^2))/ (1 + (o_e * COS(o_ta))).

  LOCAL o_pos IS (R(0,-lan,0) * SOLARPRIMEVECTOR):NORMALIZED * o_r.

  LOCAL o_vel_mag IS SQRT(planet:MU * ((2/o_r)-(1/o_a))).
  LOCAL o_vec IS (VCRS(planet:ANGULARVEL,o_pos)):NORMALIZED * o_vel_mag.
  SET o_vec TO ANGLEAXIS(-i,o_pos) * o_vec.

  LOCAL o_normal IS VCRS(o_vec,o_pos).
  RETURN o_normal.
}

FUNCTION craftNormal
{
  PARAMETER c, u_time.
  RETURN VCRS(velAt(c,u_time),posAt(c,u_time)).
}

FUNCTION orbitRelInc
{
  PARAMETER u_time.
  PARAMETER ap, pe, i, lan, w.
  RETURN VANG(craftNormal(SHIP,u_time), orbitNormal(ORBITAT(SHIP,u_time):BODY,ap,pe,i,lan,w)).
}

FUNCTION craftRelInc
{
  PARAMETER t, u_time.
  RETURN VANG(craftNormal(SHIP,u_time), craftNormal(t,u_time)).
}

FUNCTION taAN
{
  PARAMETER u_time.
  PARAMETER o_normal.
  LOCAL s_pos IS posAt(SHIP,u_time).
  LOCAL s_normal IS craftNormal(SHIP,u_time).
  LOCAL nodes IS VCRS(s_normal,o_normal).
  LOCAL ang IS VANG(s_pos,nodes).
  IF VDOT(s_normal,VCRS(nodes,s_pos)) < 0 { SET ang TO 360 - ang. }
  RETURN mAngle(ang + taAt(SHIP,u_time)).
}

FUNCTION nodeMatchAtNode
{
  PARAMETER u_time.
  PARAMETER o_normal.
  PARAMETER ascending.

  LOCAL n_ta IS taAN(u_time,o_normal).
  IF NOT ascending { SET n_ta TO mAngle(n_ta + 180). }

  LOCAL n_time IS u_time + secondsToTA(SHIP,u_time,n_ta).
  LOCAL n_r IS radiusAtTA(ORBITAT(SHIP,u_time),n_ta).
  LOCAL s_normal IS craftNormal(SHIP,n_time).
  LOCAL n_normal IS s_normal:MAG * o_normal:NORMALIZED.
  LOCAL ang IS VANG(s_normal,o_normal).
  LOCAL dv IS ABS((n_normal - s_normal):MAG / n_r).
  LOCAL dv_pro IS -1 * ABS(dv * SIN(ang / 2)).
  LOCAL dv_norm IS dv * COS(ang / 2).
  IF ascending { SET dv_norm TO -1 * dv_norm. }
  RETURN NODE(n_time,0,dv_norm,dv_pro).
}

FUNCTION nodeIncMatch
{
  PARAMETER u_time.
  PARAMETER o_normal.

  LOCAL n_AN IS nodeMatchAtNode(u_time,o_normal,TRUE).
  LOCAL n_DN IS nodeMatchAtNode(u_time,o_normal,FALSE).

  LOCAL dv_AN is nodeDV(n_AN).
  LOCAL dv_DN is nodeDV(n_DN).
  IF (2 * ABS(dv_AN-dv_DN) / (dv_AN + dv_DN)) > 0.2 {
    IF dv_AN < dv_DN { RETURN n_AN. }
    ELSE { RETURN n_DN. }
  } ELSE {
    IF n_AN:ETA < n_DN:ETA { RETURN n_AN. }
    ELSE { RETURN n_DN. }
  }
}

FUNCTION nodeIncMatchTarget
{
  PARAMETER t, u_time.
  RETURN nodeIncMatch(u_time,craftNormal(t,u_time)).
}

FUNCTION nodeIncMatchOrbit
{
  PARAMETER u_time.
  PARAMETER ap, pe, i, lan, w.
  RETURN nodeIncMatch(u_time,orbitNormal(ORBITAT(SHIP,u_time):BODY,ap,pe,i,lan,w)).
}

FUNCTION matchOrbitInc
{
  PARAMETER doExec, can_stage, limit_dv.
  PARAMETER u_time.
  PARAMETER i, lan.

  LOCAL ok IS TRUE.
  LOCAL dv_req IS 0.

  LOCAL o IS ORBITAT(SHIP,u_time).
  LOCAL ap IS o:APOAPSIS.
  LOCAL pe IS o:PERIAPSIS.
  LOCAL w IS o:ARGUMENTOFPERIAPSIS.
  IF lan = -1 { SET lan TO o:LAN. }

  IF orbitRelInc(u_time, ap, pe, i, lan, w) > 0.05 {
    LOCAL n1 IS nodeIncMatchOrbit(u_time, ap, pe, i, lan, w).
    addNode(n1).
    IF doExec {
      SET ok TO execNode(can_stage).
      SET u_time TO bufferTime().
    } ELSE {
      SET dv_req TO dv_req + nodeDV(n1).
      SET u_time TO bufferTime(u_time) + n1:ETA.
    }
  }

  IF ok AND NOT doExec AND dv_req > 0 {
    pOut("Delta-v requirement: " + ROUND(dv_req,1) + "m/s.").
    IF dv_req > limit_dv {
      SET ok TO FALSE.
      pOut("ERROR: exceeds delta-v allowance ("+ROUND(limit_dv,1)+"m/s).").
    }
  }

  RETURN ok.
}

FUNCTION doOrbitMatch
{
  PARAMETER can_stage,limit_dv.
  PARAMETER i.
  PARAMETER lan IS -1.

  LOCAL ok IS TRUE.
  IF HASNODE {
    IF NEXTNODE:ETA > nodeBuffer() { SET ok TO execNode(FALSE). }
    removeAllNodes().
  }

  LOCAL u_time IS bufferTime().
  IF ok { SET ok TO matchOrbitInc(FALSE,FALSE,limit_dv,u_time,i,lan). }
  removeAllNodes().
  IF ok { SET ok TO matchOrbitInc(TRUE,can_stage,0,u_time,i,lan). }
  removeAllNodes().
  RETURN ok.
}