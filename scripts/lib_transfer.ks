@LAZYGLOBAL OFF.
pOut("lib_transfer.ks v1.3.2 20161214").

FOR f IN LIST(
  "lib_orbit.ks",
  "lib_burn.ks",
  "lib_orbit_match.ks",
  "lib_runmode.ks",
  "lib_hoh.ks",
  "lib_ca.ks"
) { RUNONCEPATH(loadScript(f)). }

GLOBAL CURRENT_BODY IS BODY.
GLOBAL MAX_SCORE IS 99999.
GLOBAL MIN_SCORE IS -999999999.
GLOBAL TIME_TO_NODE IS 900.

FUNCTION bodyChange
{
  PARAMETER cb.
  RETURN BODY <> cb.
}

FUNCTION minAltForBody
{
  PARAMETER b.
  RETURN MAX(25000, b:RADIUS / 4).
}

FUNCTION nodeCopy
{
  PARAMETER n1, n2.
  SET n2:PROGRADE TO n1:PROGRADE.
  SET n2:NORMAL TO n1:NORMAL.
  SET n2:RADIALOUT TO n1:RADIALOUT.
  SET n2:ETA TO n1:ETA.
}

FUNCTION futureOrbit
{
  PARAMETER init_orb, count.

  LOCAL orb IS init_orb.
  LOCAL i IS 0.
  UNTIL i >= count {
    IF NOT orb:HASNEXTPATCH {
      pOut("WARNING: futureOrbit("+count+") called but patch "+i+" is the last.").
      SET i TO count.
    } ELSE { SET orb TO orb:NEXTPATCH. }
    SET i TO i + 1.
  }
  
  RETURN orb.
}

FUNCTION futureOrbitETATime
{
  PARAMETER init_orb, count.

  LOCAL eta_time IS TIME:SECONDS.
  LOCAL orb IS init_orb.
  LOCAL i IS 0.
  UNTIL i >= count {
    IF orb:HASNEXTPATCH {
      SET eta_time TO TIME:SECONDS + orb:NEXTPATCHETA.
      SET orb TO orb:NEXTPATCH.
    } ELSE { 
      IF orb:ECCENTRICITY < 1 { SET eta_time TO eta_time + orb:PERIOD. }
      SET i TO count.
    }
    SET i TO i + 1.
  }
  RETURN eta_time.
}

FUNCTION orbitReachesBody
{
  PARAMETER orb, dest, count IS 0.

  IF orb:BODY = dest { RETURN count. }
  ELSE IF orb:HASNEXTPATCH { RETURN orbitReachesBody(orb:NEXTPATCH,dest,count+1). }
  ELSE { RETURN -1. }
}

FUNCTION scoreNodeDestOrbit
{
  PARAMETER dest, pe, i, lan, n, bs.
  LOCAL score IS 0.
  LOCAL min_pe IS minAltForBody(dest).
  ADD n. WAIT 0.
  LOCAL orb IS n:ORBIT.
  LOCAL orb_count IS orbitReachesBody(orb,dest).
  IF orb_count >= 0 {
    SET score TO MAX_SCORE - nodeDV(n).

    LOCAL next_orb IS futureOrbit(orb,orb_count).
    LOCAL next_pe IS next_orb:PERIAPSIS.
    LOCAL next_i IS next_orb:INCLINATION.
    LOCAL next_lan IS next_orb:LAN.

    IF pe < min_pe {

      LOCAL pe_diff IS ABS(next_pe - pe).
      IF pe_diff < 2500 { SET score TO score + (10 * SQRT(2500-pe_diff)). }
      ELSE { SET score TO score - SQRT(pe_diff / 10). }

    } ELSE {

      IF next_pe < min_pe {
        SET score TO score - SQRT((min_pe - next_pe) / 10).
      }

      LOCAL r0 IS dest:RADIUS + next_pe.
      LOCAL r1 IS dest:RADIUS + pe.

      LOCAL a0 IS dest:RADIUS + ((next_pe + next_orb:APOAPSIS) / 2).
      LOCAL a1 IS dest:RADIUS + ((next_pe + pe) / 2).
      LOCAL v0 IS SQRT(dest:MU * ((2/r0)-(1/a0))).
      LOCAL v1 IS SQRT(dest:MU * ((2/r0)-(1/a1))).
      LOCAL dv_oi IS ABS(v1 - v0).
      SET score TO score - dv_oi.

      LOCAL v2 IS SQRT(dest:MU * ((2/r1)-(1/a1))).
      LOCAL v3 IS SQRT(dest:MU/r1).
      LOCAL dv_pe IS ABS(v3 - v2).
      SET score TO score - dv_pe.

      IF i >= 0 {
        IF lan < 0 { SET lan TO next_lan. }
        LOCAL ang IS VANG(orbitNormal(dest,i,lan),orbitNormal(dest,next_i,next_lan)).
        LOCAL v_circ IS SQRT(dest:MU/r1).
        LOCAL dv_inc IS 2 * v_circ * SIN(ang/2).
        SET score TO score - dv_inc.
      }

      // TBD - check for other safety issues (e.g. orbit ranges of satellites)
    }

  } ELSE IF bs < 0 AND dest:HASBODY {
  
    LOCAL pb IS dest:BODY.
    SET orb_count TO orbitReachesBody(orb,pb).
    UNTIL orb_count >= 0 OR NOT pb:HASBODY {
      SET dest TO pb.
      SET pb TO pb:BODY.
      SET orb_count TO orbitReachesBody(orb,pb).
    }
    IF orb_count >= 0 {
      LOCAL u_time1 IS futureOrbitETATime(orb,orb_count).
      LOCAL u_time2 IS futureOrbitETATime(orb,orb_count+1).
      SET score TO -targetDist(dest,targetCA(dest,u_time1,u_time2,5,10)) / 1000.
    } ELSE { SET score TO MIN_SCORE. }

  } ELSE { SET score TO MIN_SCORE. }
  REMOVE n.

  RETURN score.
}

FUNCTION updateBest
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
  PARAMETER n, score_func.
  LOCAL ubn IS updateBest@:BIND(score_func).

  LOCAL best_node IS newNodeByDiff(n,0,0,0,0).
  LOCAL best_score IS score_func(best_node,MIN_SCORE).
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

FUNCTION nodeBodyToMoon
{
  PARAMETER u_time, dest, dest_pe, i IS -1, lan IS -1.

  LOCAL t_pe IS (dest:RADIUS + dest_pe) * COS(MAX(i,0)).

  LOCAL hnode IS nodeHohmann(dest, u_time, t_pe).
  improveNode(hnode,scoreNodeDestOrbit@:BIND(dest,dest_pe,i,lan)).

  RETURN hnode.
}

FUNCTION nodeMoonToBody
{
  PARAMETER u_time, moon, dest_pe, i IS -1, lan IS -1.

  LOCAL dest IS moon:OBT:BODY.

  LOCAL mu IS moon:MU.
  LOCAL hoh_mu IS dest:MU.
  LOCAL r_soi IS moon:SOIRADIUS.
  LOCAL r_pe IS ORBITAT(SHIP,u_time):SEMIMAJORAXIS.

  LOCAL r1 IS ORBITAT(moon,u_time):SEMIMAJORAXIS.
  LOCAL r2 IS dest_pe + dest:RADIUS.
  LOCAL v_soi IS SQRT(hoh_mu/r1) * (SQRT((2*r2)/(r1+r2)) -1).
  LOCAL v_pe IS SQRT(v_soi^2 + (2 * mu/r_pe) - (2 * mu/r_soi)).
  LOCAL v_orbit IS SQRT(mu/r_pe).
  LOCAL dv IS ABS(v_pe) - v_orbit.
  LOCAL a IS 1/((2/r_pe)-(v_pe^2 / mu)).
  LOCAL r_ap IS (2 * a) - r_pe.
  LOCAL energy IS (v_pe^2 / 2)-(mu / r_pe).
  LOCAL h IS r_pe * v_pe.
  LOCAL e IS 0.
  IF energy >= 0 { SET e TO SQRT(1 + (2 * energy * h^2 / mu^2)). }
  ELSE { SET e TO (r_ap - r_pe) / (r_ap + r_pe). }

  LOCAL theta_eject IS 100.
  IF e > 1 { SET theta_eject TO ARCCOS(-1/e). }
  ELSE { pOut("WARNING: Cannot calculate ejection angle as required orbit is not a hyperbola."). }

  LOCAL man_node IS NODE(u_time, 0, 0, ABS(dv)).

  LOCAL c_time IS u_time.
  LOCAL done IS FALSE.
  UNTIL done {
    LOCAL moon_pos IS POSITIONAT(moon,c_time).
    LOCAL moon_vel IS VELOCITYAT(moon,c_time):ORBIT.
    LOCAL s_pos IS posAt(SHIP,c_time).
    LOCAL s_normal IS VCRS(velAt(SHIP,c_time),s_pos).

    LOCAL ang IS VANG(s_normal,-moon_vel).
    LOCAL eff_i IS ABS(ang-90).
    LOCAL ret_xcl IS VXCL(s_normal,-moon_vel).
    LOCAL s_ang IS VANG(s_pos,ret_xcl).
    IF VDOT(VCRS(ret_xcl,s_pos),s_normal) < 0 { SET s_ang TO 360 - s_ang. }
    IF ABS(s_ang - theta_eject) < 0.5 AND eff_i < 25 {
      SET done TO TRUE.
      SET man_node:ETA TO c_time - TIME:SECONDS.
      LOCAL score_func IS scoreNodeDestOrbit@:BIND(dest,dest_pe,i,lan).
      improveNode(man_node,score_func).
    }
    SET c_time TO c_time + 15.
  }

  RETURN man_node.
}

FUNCTION taEccOk
{
  PARAMETER orb, ta.
  LOCAL e IS orb:ECCENTRICITY.
  IF e < 1 { RETURN TRUE. }
  RETURN (MIN(ta,360-ta) < ARCCOS(-1/e)).
}

FUNCTION orbitNeedsCorrection
{
  PARAMETER curr_orb,dest,pe,i,lan.

  IF (SHIP:OBT:HASNEXTPATCH AND ETA:TRANSITION < (TIME_TO_NODE + 900)) OR
      ETA:PERIAPSIS < (TIME_TO_NODE + 900) { RETURN FALSE. }

  LOCAL orb_count IS orbitReachesBody(curr_orb,dest).
  IF orb_count < 0 { RETURN TRUE. }
  LOCAL orb IS futureOrbit(curr_orb,orb_count).

  LOCAL orb_pe IS orb:PERIAPSIS.
  LOCAL pe_diff IS ABS(orb_pe - pe).
  LOCAL min_diff IS 1000 * 10^orb_count.
  LOCAL min_pe IS minAltForBody(dest) * 0.8.

  IF orb_pe < min_pe { IF pe >= min_pe { RETURN TRUE. } }
  ELSE IF orb_pe < MAX(min_pe * 2, 250000) { SET min_diff TO min_diff * 10. }
  ELSE { SET min_diff TO min_diff * 25. }
  IF pe_diff > min_diff { RETURN TRUE. }

  IF orb_count = 0 AND i >= 0 {
    IF lan < 0 { IF ABS(i - orb:INCLINATION) > 0.05 { RETURN TRUE. } }
    ELSE IF VANG(orbitNormal(dest,i,lan),orbitNormal(dest,orb:INCLINATION,orb:LAN)) > 0.05 {
      LOCAL u_time IS TIME:SECONDS + 1.
      LOCAL n_ta1 IS taAN(u_time,orbitNormal(dest,i,lan)).
      IF taEccOk(orb,n_ta1) { 
        LOCAL eta1 IS secondsToTA(SHIP,u_time,n_ta1) + 1.
        IF eta1 > 900 AND eta1 < (ETA:PERIAPSIS - 900) { SET TIME_TO_NODE TO eta1. RETURN TRUE. }
      }
      LOCAL n_ta2 IS mAngle(n_ta1 + 180).
      IF taEccOk(orb, n_ta2) {
        LOCAL eta2 IS secondsToTA(SHIP,u_time,mAngle(n_ta1 + 180)) + 1.
        IF eta2 > 900 AND eta2 < (ETA:PERIAPSIS - 900) { SET TIME_TO_NODE TO eta2. RETURN TRUE. }
      }
    }
  }

  RETURN FALSE.
}

FUNCTION doTransfer
{
  PARAMETER exit_mode, can_stage, dest, dest_pe, dest_i IS -1, dest_lan IS -1.

  LOCAL LOCK rm TO runMode().

  pOut("Transferring to " + dest:NAME + " with target periapsis of " + dest_pe + "m.").

  IF rm < 101 OR rm > 149 { runMode(101). }

UNTIL rm = exit_mode
{
  IF rm = 101 {
    removeAllNodes().
    LOCAL t_time IS TIME:SECONDS+600.
    LOCAL node_ok IS FALSE.
    LOCAL n1 IS NODE(0,0,0,0).
    IF dest:BODY = BODY {
      SET n1 TO nodeBodyToMoon(t_time,dest,dest_pe,dest_i,dest_lan).
    } ELSE IF dest = BODY:OBT:BODY {
      SET n1 TO nodeMoonToBody(t_time,BODY,dest_pe,dest_i,dest_lan).
    } ELSE {
      // other transfers not supported yet - TBD
    }

    IF n1:ETA > 0 {
      addNode(n1).
      IF orbitReachesBody(n1:ORBIT,dest) > 0 {
        pOut("Trans-"+dest:NAME+" Injection node added.").
        SET node_ok TO TRUE.
      } ELSE { pOut("ERROR: transfer node does not reach "+dest:NAME+"."). }
    } ELSE { pOut("ERROR: transfer node was not created successfully or is in past."). }

    IF node_ok { runMode(102). }
    ELSE {
      removeAllNodes().
      runMode(109,101).
    }
  } ELSE IF rm = 102 {
    IF HASNODE {
      IF execNode(can_stage) { runMode(111). } ELSE { runMode(109,102). }
    } ELSE {
      IF BODY = dest { runMode(131). }
      ELSE IF orbitReachesBody(SHIP:OBT,dest) > 0 { runMode(111). }
      ELSE { runMode(109,101). }
    }
  } ELSE IF rm = 111 {
    LOCAL pe_eta IS secondsToTA(SHIP,TIME:SECONDS+1,0) + 1.
    IF BODY = dest AND (pe_eta < 0 OR (SHIP:OBT:HASNEXTPATCH AND ETA:TRANSITION < pe_eta)) { runMode(131). }
    ELSE { runMode(112). }
  } ELSE IF rm = 112 {
    SET TIME_TO_NODE TO 900.
    runMode(113).
  } ELSE IF rm = 113 {
    IF NOT isSteerOn() {
      steerSun().
      WAIT UNTIL steerOk().
    }

    IF orbitNeedsCorrection(SHIP:ORBIT,dest,dest_pe,dest_i,dest_lan) {
      LOCAL mcc IS NODE(TIME:SECONDS+TIME_TO_NODE,0,0,0).
      LOCAL score_func IS scoreNodeDestOrbit@:BIND(dest,dest_pe,dest_i,dest_lan).
      improveNode(mcc,score_func).
      IF nodeDV(mcc) >= 0.2 {
        addNode(mcc).
        pOut("Mid-course correction node added.").
        runMode(114).
      } ELSE { runMode(115). }
    } ELSE { runMode(115). }
  } ELSE IF rm = 114 {
    IF HASNODE {
      IF execNode(can_stage) { runMode(112). } ELSE { runMode(119,114). }
    } ELSE {
      IF BODY = dest { runMode(131). }
      ELSE IF orbitReachesBody(SHIP:OBT,dest) > 0 { runMode(112). }
      ELSE { runMode(119,112). }
    }
  } ELSE IF rm = 115 {
    IF BODY = dest { runMode(131). } ELSE { runMode(121). }

  } ELSE IF rm = 121 {
    IF BODY = CURRENT_BODY AND BODY <> dest AND SHIP:OBT:HASNEXTPATCH {
      LOCAL next_body IS SHIP:OBT:NEXTPATCH:BODY.
      pOut("Sphere of influence transition from "+BODY:NAME+" to "+next_body:NAME+
           " in "+ROUND(ETA:TRANSITION)+"s.").
      LOCAL on_body_change IS bodyChange@:BIND(CURRENT_BODY).

      pOut("Warping to transition.").
      UNTIL on_body_change() OR NOT SHIP:OBT:HASNEXTPATCH {
        LOCAL warp_time IS TIME:SECONDS + ETA:TRANSITION - 180.
        IF warp_time > TIME:SECONDS { doWarp(warp_time, on_body_change). }
        ELSE { doWarp(TIME:SECONDS + 360, on_body_change). }
      }
      IF on_body_change() { hudMsg("Sphere of influence body now: " + BODY:NAME). }
      IF ADDONS:KAC:AVAILABLE {
        LOCAL al IS LIST().
        SET al TO LISTALARMS("All").
        FOR a IN al { IF a:REMAINING < 0 { DELETEALARM(a:ID). } }
      }
    }
    SET CURRENT_BODY TO BODY.
    runMode(111).

  } ELSE IF rm = 131 {
    IF BODY:ATM:EXISTS AND PERIAPSIS < BODY:ATM:HEIGHT { runMode(133). }
    ELSE {
      LOCAL pe_eta IS secondsToTA(SHIP,TIME:SECONDS+1,0) + 1.
      IF (SHIP:OBT:HASNEXTPATCH AND ETA:TRANSITION < pe_eta) OR pe_eta < 0 { SET pe_eta TO 60. }
      LOCAL oi IS nodeAlterOrbit(TIME:SECONDS+pe_eta,dest_pe).
      addNode(oi).
      pOut(dest:NAME + " Orbit Insertion node added.").
      runMode(132).
    }
  } ELSE IF rm = 132 {
    IF HASNODE {
      IF execNode(can_stage) { runMode(133). } ELSE { runMode(139,132). }
    } ELSE {
      IF SHIP:OBT:HASNEXTPATCH { runMode(131). } ELSE { runMode(133). }
    }
  } ELSE IF rm = 133 {
    steerSun().
    WAIT UNTIL steerOk().
    dampSteering().
    runMode(exit_mode).

  } ELSE IF MOD(rm,10) = 9 AND rm > 100 AND rm < 150 {
    hudMsg("Error state. Hit abort to switch to recovery mode: " + abortMode() + ".").
    steerSun().
    WAIT UNTIL MOD(runMode(),10) <> 9.
  } ELSE {
    pOut("Transfer - unexpected run mode: " + rm).
    runMode(149,101).
  }

  WAIT 0.
}

}
