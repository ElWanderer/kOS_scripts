@LAZYGLOBAL OFF.
pOut("lib_rcs_burn.ks v1.1.1 20200930").

FOR f IN LIST(
  "lib_rcs.ks",
  "lib_burn.ks"
) { RUNONCEPATH(loadScript(f)). }

GLOBAL RCS_BURN_FUELS IS LIST("MonoPropellant").
GLOBAL RCS_BURN_ISP IS 240.
GLOBAL RCS_BURN_T IS 0.

rcsSetThrust().

FUNCTION rcsPartThrust
{
  PARAMETER p.

  IF p:NAME:CONTAINS("RCSBlock") { RETURN 1 - ABS(VDOT(p:FACING:STARVECTOR,FACING:VECTOR)). }
  IF p:NAME:CONTAINS("linearRCS") { RETURN 2 * MAX(0,VDOT(p:FACING:VECTOR,-FACING:VECTOR)). }
  RETURN 0.
}

FUNCTION rcsSetThrust
{
  LOCAL t IS 0.
  FOR m IN SHIP:MODULESNAMED("ModuleRCSFX") { SET t TO t + rcsPartThrust(m:PART). }
  SET RCS_BURN_T TO t.
}

FUNCTION rcsDV
{
  RETURN (g0 * RCS_BURN_ISP * LN(MASS / (MASS-fuelMass(SHIP:RESOURCES,RCS_BURN_FUELS)))).
}

FUNCTION rcsPDV
{
  pOut("RCS delta-v: " + ROUND(rcsDV(),1) + "m/s.").
}

FUNCTION rcsBurnTime
{
  PARAMETER dv.
  RETURN btCalc(dv, MASS, RCS_BURN_ISP, fuelRate(RCS_BURN_T,RCS_BURN_ISP)).
}

FUNCTION rcsBurnNode
{
  PARAMETER n, bt.

  LOCAL ok IS TRUE.
  LOCAL done IS FALSE.
  LOCAL o_dv IS n:DELTAV.
  LOCAL rcs_o_state IS RCS.

  IF ADDONS:KAC:AVAILABLE AND (bt / 2) < 300 {
    WAIT UNTIL n:ETA < 300.
    FOR a IN LISTALARMS("All") { IF a:REMAINING < 300 { DELETEALARM(a:ID). } }
  }

  WAIT UNTIL n:ETA <= (bt / 2).

  IF NOT RCS { toggleRCS(). }

  UNTIL done OR NOT ok {
    doTranslation(n:DELTAV, burnThrottle(rcsBurnTime(n:DELTAV:MAG))).

    IF VDOT(o_dv, n:DELTAV) < 0 OR n:DELTAV:MAG <= RCS_DEADBAND { SET done TO TRUE. stopTranslation(). }
    ELSE IF rcsDV() < n:DELTAV:MAG { SET ok TO FALSE. stopTranslation(). }

    WAIT 0.
  }

  SET RCS to rcs_o_state.
  pOrbit(SHIP:OBT).

  IF n:DELTAV:MAG >= 1 { SET ok TO FALSE. }
  IF ok { pOut("Node complete."). }
  ELSE { pOut("ERROR: node has " + ROUND(n:DELTAV:MAG,1) + "m/s remaining."). }
  rcsPDV().

  RETURN ok.
}

FUNCTION rcsExecNode
{
  pOut("Executing next node.").
  IF NOT HASNODE {
    pOut("ERROR: - no node.").
    RETURN FALSE.
  }

  LOCAL ok IS TRUE.
  LOCAL n IS NEXTNODE.
  LOCAL n_dv IS nodeDV(n).

  rcsSetThrust().
  LOCAL s_dv IS rcsDV().
  pOut("Delta-v required: " + ROUND(n_dv,1) + "m/s.").
  rcsPDV().

  IF s_dv >= n_dv {
    SET BURN_NODE_IS_SMALL TO TRUE.
    LOCAL bt IS rcsBurnTime(n_dv).
    pOut("Burn time: " + ROUND(bt,1) + "s.").
    warpCloseToNode(n,bt).
    pointNode(n).
    warpToNode(n,bt).
    SET ok TO rcsBurnNode(n,bt).
    IF ok { REMOVE n. }
    dampSteering().
  } ELSE {
    SET ok TO FALSE.
    pOut("ERROR: not enough delta-v for node.").
  }

  RETURN ok.
}
