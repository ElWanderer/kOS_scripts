@LAZYGLOBAL OFF.
pOut("lib_rcs_burn.ks v1.0.0 20170110").

FOR f IN LIST(
  "lib_rcs.ks",
  "lib_burn.ks"
) { RUNONCEPATH(loadScript(f)). }

//GLOBAL RCS_BURN_FUELS IS LIST("MONOPROP").
GLOBAL RCS_BURN_ISP IS 0.
GLOBAL RCS_BURN_T IS 0.

rcsSetISPAndThrust().

FUNCTION rcsSetISPAndThrust
{
  // how to find these?
  SET RCS_BURN_ISP TO 240. // 4-way and 1-way thrusters have this ISP
  SET RCS_BURN_T TO 8.     // 8 x 4-way thrusters or 4 x 1-way thrusters
}

FUNCTION rcsDV
{
  LOCAL fm IS 0.
  FOR r IN SHIP:RESOURCES {
    IF r:NAME = "MonoPropellant" { SET fm TO r:AMOUNT * r:DENSITY. }
  }
  RETURN (g0 * RCS_BURN_ISP * LN(MASS / (MASS-fm))).
}

FUNCTION rcsPDV
{
  pOut("RCS delta-v: " + ROUND(rcsDV(),1) + "m/s.").
}

FUNCTION rcsBurnTime
{
  PARAMETER dv, sdv IS rcsDV(), limiter IS 1.
  RETURN btCalc(dv, MASS, RCS_BURN_ISP, fuelRate(RCS_BURN_T * limiter,RCS_BURN_ISP)).
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
    doTranslation(n:DELTAV).

    IF VDOT(o_dv, n:DELTAV) < 0 { SET done TO TRUE. stopTranslation(). }
    ELSE IF rcsDV() < nodeDV(n) { SET ok TO FALSE. stopTranslation(). }

    WAIT 0.
  }

  SET RCS to rcs_o_state.
  dampSteering().
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

  rcsSetISPAndThrust().
  LOCAL s_dv IS rcsDV().
  pOut("Delta-v required: " + ROUND(n_dv,1) + "m/s.").
  rcsPDV().

  IF s_dv >= n_dv {
    SET BURN_NODE_IS_SMALL TO TRUE.
    LOCAL bt IS rcsBurnTime(n_dv, s_dv).
    pOut("Burn time: " + ROUND(bt,1) + "s.").
    warpCloseToNode(n,bt).
    pointNode(n).
    warpToNode(n,bt).
    SET ok TO rcsBurnNode(n,bt).
    IF ok { REMOVE n. }
  } ELSE {
    SET ok TO FALSE.
    pOut("ERROR: not enough delta-v for node.").
  }

  RETURN ok.
}
