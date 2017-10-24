@LAZYGLOBAL OFF.

pOut("lib_burn.ks v1.2.3 20171024").

FOR f IN LIST(
  "lib_dv.ks",
  "lib_node.ks",
  "lib_steer.ks"
) { RUNONCEPATH(loadScript(f)). }

GLOBAL BURN_THROTTLE IS 0.
GLOBAL BURN_MAX_THROT IS 1.
GLOBAL BURN_MIN_THROT IS 0.1.
GLOBAL BURN_SMALL_SECS IS 1.
GLOBAL BURN_SMALL_DV IS 5.
GLOBAL BURN_SMALL_THROT IS 1.
GLOBAL BURN_NODE_IS_SMALL IS FALSE.
GLOBAL BURN_WARP_BUFF IS 15.

FUNCTION changeBURN_WARP_BUFF
{
  PARAMETER wb IS 15.
  IF wb > 0 { SET BURN_WARP_BUFF TO wb. }
}

FUNCTION pointNode
{
  PARAMETER n.
  IF BURN_NODE_IS_SMALL { LOCAL n_v IS n:DELTAV. steerTo({ RETURN n_v. }). }
  ELSE { steerTo({ RETURN n:DELTAV. }). }
  pOut("Aligning with node.").
  WAIT UNTIL steerOk(0.4).
}

FUNCTION checkNodeSize
{
  PARAMETER n_bt, n_dv, s_dv.
  SET BURN_NODE_IS_SMALL TO (s_dv > n_dv AND (n_bt < BURN_SMALL_SECS OR n_dv < BURN_SMALL_DV)).
}

FUNCTION burnThrottle
{
  PARAMETER bt.
  RETURN MIN(BURN_MAX_THROT, MAX(BURN_MIN_THROT, ROUND(bt * 20) / 20)).
}

FUNCTION burnSmallNode
{
  PARAMETER n, bt.

  LOCAL u_time IS TIME:SECONDS.
  SET BURN_THROTTLE TO BURN_SMALL_THROT.
  WAIT UNTIL TIME:SECONDS - u_time >= bt OR SHIP:AVAILABLETHRUST = 0.
  SET BURN_THROTTLE TO 0.
}

FUNCTION burnNode
{
  PARAMETER n, bt, hbt, can_stage.

  LOCAL ok IS TRUE.
  LOCAL o_dv IS n:DELTAV.

  LOCK THROTTLE TO BURN_THROTTLE.
  IF ADDONS:KAC:AVAILABLE AND hbt < 300 {
    WAIT UNTIL n:ETA < 300.
    FOR a IN LISTALARMS("All") { IF a:REMAINING < 300 { DELETEALARM(a:ID). } }
  }

  WAIT UNTIL n:ETA <= hbt.

  LOCAL done IS BURN_NODE_IS_SMALL.
  IF done { burnSmallNode(n, bt). }
  LOCAL follow_node IS TRUE.

  UNTIL done OR NOT ok {
    LOCAL acc IS SHIP:AVAILABLETHRUST / MASS.
    IF acc > 0 {
      SET bt TO n:DELTAV:MAG / acc.
      SET BURN_THROTTLE TO burnThrottle(bt).

      IF VDOT(o_dv, n:DELTAV) < 0 {
        SET BURN_THROTTLE TO 0.
        SET done TO TRUE.
      } ELSE IF follow_node AND n:DELTAV:MAG < BURN_SMALL_DV {
        SET o_dv TO n:DELTAV.
        steerTo({ RETURN o_dv. }).
        SET follow_node TO FALSE.
      }
    } ELSE {
      SET BURN_THROTTLE TO 0.
      IF can_stage AND moreEngines() { IF STAGE:READY AND stageTime() > 0.5 { doStage(). } }
      ELSE {
        pOut("No thrust available for burn.").
        SET ok TO FALSE.
      }
    }
    WAIT 0.
  }

  dampSteering().
  UNLOCK THROTTLE.

  pOrbit(SHIP:OBT).

  IF n:DELTAV:MAG >= 1 { SET ok TO FALSE. }
  IF ok { pOut("Node complete."). }
  ELSE { pOut("ERROR: node has " + ROUND(n:DELTAV:MAG,1) + "m/s remaining."). }
  pDV().

  RETURN ok.
}

FUNCTION warpCloseToNode
{
  PARAMETER n, bt.
  LOCAL warp_time IS TIME:SECONDS + n:ETA - 900.
  IF warp_time > TIME:SECONDS AND bt < 1680 {
    steerSun().
    WAIT UNTIL steerOk().
    doWarp(warp_time).
    WAIT UNTIL TIME:SECONDS > warp_time.
  }
}

FUNCTION warpToNode
{
  PARAMETER n, hbt.
  LOCAL time_to_warp IS n:ETA - hbt - BURN_WARP_BUFF.
  IF time_to_warp > 0 { doWarp(TIME:SECONDS + time_to_warp). }
}

FUNCTION execNode
{
  PARAMETER can_stage.

  pOut("Executing next node.").
  IF NOT HASNODE {
    pOut("ERROR: - no node.").
    RETURN FALSE.
  }

  LOCAL ok IS TRUE.
  LOCAL n IS NEXTNODE.
  LOCAL n_dv IS nodeDV(n).
  LOCAL s_dv IS stageDV(TRUE).
  pOut("Delta-v required: " + ROUND(n_dv,1) + "m/s.").
  pDV().

  IF s_dv >= n_dv OR (can_stage AND moreEngines()) {
    LOCAL bt IS burnTime(n_dv, s_dv).
    LOCAL hbt IS burnTime(n_dv/2, s_dv).
    checkNodeSize(bt, n_dv, s_dv).
    IF BURN_NODE_IS_SMALL {
      SET BURN_SMALL_THROT TO burnThrottle(bt).
      SET bt TO burnTime(n_dv, s_dv, BURN_SMALL_THROT).
    }
    pOut("Full burn time: " + ROUND(bt,1) + "s.").
    pOut("Throttle up " + ROUND(hbt,1) + "s before node.").
    warpCloseToNode(n,bt).
    pointNode(n).
    warpToNode(n,hbt).
    SET ok TO burnNode(n,bt,hbt,can_stage).
    IF ok { REMOVE n. }
  } ELSE {
    SET ok TO FALSE.
    pOut("ERROR: not enough delta-v for node.").
  }

  RETURN ok.
}
