@LAZYGLOBAL OFF.

IF NOT EXISTS("1:/init.ks") { RUNPATH("0:/init_select.ks"). }
RUNONCEPATH("1:/init.ks").

pOut("test_orbit_match.ks v1.0.0 20201005").

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

  LOCAL s_vel iS velAt(SHIP,n_time).
  LOCAL s_pos IS posAt(SHIP,n_time).
  LOCAL f_ang IS 90 - VANG(s_vel,s_pos).
  LOCAL new_vel IS s_vel:MAG * (ANGLEAXIS(f_ang,o_normal) * VCRS(s_pos,o_normal)):NORMALIZED.
  RETURN nodeToVector(new_vel, n_time).
}

FUNCTION nodeIncMatch
{
  PARAMETER u_time, o_normal.

  LOCAL n_AN IS nodeMatchAtNode(u_time,o_normal,TRUE).
  LOCAL n_DN IS nodeMatchAtNode(u_time,o_normal,FALSE).

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

  IF orbitRelInc(u_time, i, lan) > 0.005 {
    LOCAL n1 IS nodeIncMatchOrbit(u_time, i, lan).
    addNode(n1).
  }

  RETURN ok.
}

IF NOT HASTARGET {
  hudMsg("No target selected.").
} ELSE IF TARGET:BODY <> BODY {
  hudMsg("Target is orbiting a different body").
} ELSE {
  matchOrbitInc(false, 9999, bufferTime(), TARGET:ORBIT:INCLINATION, TARGET:ORBIT:LAN).
}