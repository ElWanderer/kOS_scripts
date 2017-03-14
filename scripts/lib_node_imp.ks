@LAZYGLOBAL OFF.
pOut("lib_node_imp.ks v1.0.0 20170314").

RUNONCEPATH(loadScript("lib_node.ks")).

GLOBAL IMP_MAX_SCORE IS 99999.
GLOBAL IMP_MIN_SCORE IS -999999999.

FUNCTION nodeCopy
{
  PARAMETER n1, n2.
  SET n2:PROGRADE TO n1:PROGRADE.
  SET n2:NORMAL TO n1:NORMAL.
  SET n2:RADIALOUT TO n1:RADIALOUT.
  SET n2:ETA TO n1:ETA.
}

FUNCTION updateBestNode
{
  PARAMETER score_func, nn, bn, bs.
  LOCAL ns IS score_func(nn, bs).
  IF ns > bs { nodeCopy(nn, bn). }
  RETURN MAX(ns, bs).
}

FUNCTION newNodeByDiff
{
  PARAMETER n, eta_diff, rad_diff, nrm_diff, pro_diff.
  RETURN NODE(TIME:SECONDS+n:ETA+eta_diff, n:RADIALOUT+rad_diff, n:NORMAL+nrm_diff, n:PROGRADE+pro_diff).
}

FUNCTION improveNode
{
  PARAMETER n, score_func, improve_time IS TRUE.

  LOCAL ubn IS updateBestNode@:BIND(score_func).
  LOCAL best_node IS newNodeByDiff(n,0,0,0,0).
  LOCAL best_score IS score_func(best_node,IMP_MIN_SCORE).

  IF improve_time AND nodeDV(n) >= 1 {
    LOCAL time_delta IS 2^11. // 2048s (34:08)
    LOCAL min_node_time IS TIME:SECONDS + n:ETA - 1.
    LOCAL done IS FALSE.
    UNTIL done {
      LOCAL curr_score IS best_score.

      FOR mult IN LIST(-1,1) {
        LOCAL t_diff IS time_delta * mult.
        IF TIME:SECONDS + n:ETA + t_diff >= min_node_time {
          SET best_score TO ubn(newNodeByDiff(n,t_diff,0,0,0), best_node, best_score).
        }
      }

      IF ROUND(best_score,3) > ROUND(curr_score,3) { nodeCopy(best_node, n). }
      ELSE IF time_delta < 1 { SET done TO TRUE. }
      ELSE { SET time_delta TO time_delta / 2. }
    }
  }

  LOCAL orig_score IS best_score.
  LOCAL dv_delta_power IS 4.
  FOR dv_power IN RANGE(-2,5,1) {
    FOR mult IN LIST(-1,1) {
      LOCAL curr_score IS best_score.
      LOCAL dv_delta IS mult * 2^dv_power.

      SET best_score TO ubn(newNodeByDiff(n,0,0,0,dv_delta), best_node, best_score).
      SET best_score TO ubn(newNodeByDiff(n,0,0,dv_delta,0), best_node, best_score).
      SET best_score TO ubn(newNodeByDiff(n,0,dv_delta,0,0), best_node, best_score).

      IF best_score > curr_score { SET dv_delta_power TO dv_power. }
    }
  }
  IF best_score > orig_score { nodeCopy(best_node, n). }

  LOCAL dv_delta IS 2^dv_delta_power.
  LOCAL done IS FALSE.
  UNTIL done {
    LOCAL curr_score IS best_score.

    FOR p_loop IN RANGE(-1,2,1) { FOR n_loop IN RANGE(-1,2,1) { FOR r_loop IN RANGE(-1,2,1) {
      LOCAL p_diff IS dv_delta * p_loop.
      LOCAL n_diff IS dv_delta * n_loop.
      LOCAL r_diff IS dv_delta * r_loop.
      SET best_score TO ubn(newNodeByDiff(n,0,r_diff,n_diff,p_diff), best_node, best_score).
    } } }

    IF ROUND(best_score,3) > ROUND(curr_score,3) { nodeCopy(best_node, n). }
    ELSE IF dv_delta < 0.02 { SET done TO TRUE. }
    ELSE { SET dv_delta TO dv_delta / 2. }
  }
}
