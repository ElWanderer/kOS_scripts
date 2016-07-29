@LAZYGLOBAL OFF.


pOut("lib_node.ks v1.0 20160714").

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

FUNCTION printOrbit
{
  PARAMETER o.
  pOut("Orbit details:").
  pOut("  Body:   " + o:BODY:NAME+".").
  pOut("  Ap:     " + ROUND(o:APOAPSIS) + "m.").
  pOut("  Pe:     " + ROUND(o:PERIAPSIS) + "m.").
  pOut("  Period: " + ROUND(o:PERIOD) + "s.").
  pOut("  Inc:    " + ROUND(o:INCLINATION,1) + " deg.").
  pOut("  LAN:    " + ROUND(o:LAN,1) + " deg.").
  IF o:HASNEXTPATCH { printOrbit(o:NEXTPATCH). }
}

FUNCTION addNode
{
  PARAMETER n.
  ADD n.
  WAIT 0.
  pOut("Node added. Details:").
  pOut("  Delta-v:  " + ROUND(nodeDV(n),1) + "m/s.").
  pOut("  Radial:   " + ROUND(n:RADIALOUT,2) + "m/s.").
  pOut("  Normal:   " + ROUND(n:NORMAL,2) + "m/s.").
  pOut("  Prograde: " + ROUND(n:PROGRADE,2) + "m/s.").
  printOrbit(n:ORBIT).
}