@LAZYGLOBAL OFF.
pOut("lib_node.ks v1.1.0 20161214").

GLOBAL NODE_BUFF IS 60.

FUNCTION nodeBuffer
{
  PARAMETER s IS 0.
  IF s > 0 { SET NODE_BUFF TO s. }
  RETURN NODE_BUFF.
}

FUNCTION bufferTime
{
  PARAMETER u_time IS TIME:SECONDS.
  RETURN u_time + NODE_BUFF.
}

FUNCTION removeAllNodes
{
  UNTIL NOT HASNODE { REMOVE NEXTNODE. WAIT 0. }
}

FUNCTION nodeDV
{
  PARAMETER n.
  RETURN SQRT(n:RADIALOUT^2 + n:NORMAL^2 + n:PROGRADE^2).
}

FUNCTION pOrbit
{
  PARAMETER o.
  pOut("Orbit:").
  pOut(" Bdy: " + o:BODY:NAME).
  pOut(" Ap:  " + ROUND(o:APOAPSIS) + "m").
  pOut(" Pe:  " + ROUND(o:PERIAPSIS) + "m").
  pOut(" Inc: " + ROUND(o:INCLINATION,1) + " deg").
  pOut(" LAN: " + ROUND(o:LAN,1) + " deg").
  pOut(" Arg: " + ROUND(o:ARGUMENTOFPERIAPSIS,1) + " deg").
  IF o:ECCENTRICITY < 1 { pOut(" Prd: " + ROUND(o:PERIOD) + "s"). }
  IF o:HASNEXTPATCH { pOrbit(o:NEXTPATCH). }
}

FUNCTION addNode
{
  PARAMETER n.
  ADD n.
  WAIT 0.
  pOut("Node:").
  pOut(" DV:  " + ROUND(nodeDV(n),2) + "m/s").
  pOut(" Rad: " + ROUND(n:RADIALOUT,2) + "m/s").
  pOut(" Nrm: " + ROUND(n:NORMAL,2) + "m/s").
  pOut(" Pro: " + ROUND(n:PROGRADE,2) + "m/s").
  pOrbit(n:ORBIT).
}
