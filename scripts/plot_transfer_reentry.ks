@LAZYGLOBAL OFF.
pOut("plot_transfer_reentry.ks v1.0.0 20171019").

FOR f IN LIST(
  "lib_orbit.ks",
  "lib_burn.ks",
  "lib_node_imp.ks",
  "lib_orbit_match.ks",
  "lib_runmode.ks",
  "lib_hoh.ks",
  "lib_ca.ks"
) { RUNONCEPATH(loadScript(f)). }

GLOBAL TFR_CURR_BODY IS BODY.
GLOBAL TFR_NODE_SECS IS 900.

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
    SET score TO IMP_MAX_SCORE - nodeDV(n).

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
    } ELSE { SET score TO IMP_MIN_SCORE. }

  } ELSE { SET score TO IMP_MIN_SCORE. }
  REMOVE n.

  RETURN score.
}

FUNCTION scoreNodeDestReentry
{
  PARAMETER dest, pe, i, lan, lat, lng, n, bs.

  LOCAL reentry_score IS 0.
  LOCAL score IS scoreNodeDestOrbit(dest, pe, i, lan, n, bs).

  ADD n. WAIT 0.
  LOCAL orb IS n:ORBIT.
  LOCAL orb_count IS orbitReachesBody(orb,dest).
  IF orb_count >= 0 {
    LOCAL next_orb IS futureOrbit(orb,orb_count).
    LOCAL next_pe IS next_orb:PERIAPSIS.
    IF ABS(next_pe-30000) <= 1000 {
      LOCAL reentry_details IS predictReentryForOrbit(orb, dest, FALSE).
      LOCAL p_lat IS reentry_details["Predicted lat"].
      LOCAL p_lng IS reentry_details["Predicted lng"].

      LOCAL t_spot IS LATLNG(lat,lng).
      LOCAL p_spot IS LATLNG(p_lat,p_lng).
      LOCAL p_dist IS greatCircleDistance(dest, t_spot, p_spot).
      LOCAL max_dist IS dest:RADIUS * CONSTANT:PI.
      SET reentry_score TO 10000 * (1 - (p_dist / max_dist)).
    }
  }
  REMOVE n.

  RETURN score + reentry_score.
}

FUNCTION nodeBodyToMoon
{
  PARAMETER u_time, dest, dest_pe, i IS -1, lan IS -1.

  LOCAL t_pe IS (dest:RADIUS + dest_pe) * COS(MAX(i,0)).

  LOCAL hnode IS nodeHohmann(dest, u_time, t_pe).
  improveNode(hnode,scoreNodeDestOrbit@:BIND(dest,dest_pe,i,lan)).

  RETURN hnode.
}

FUNCTION ejectionAngles
{
  PARAMETER c, u_time, eject_body.

  LOCAL body_vel IS velAt(eject_body,u_time).
  LOCAL s_pos IS posAt(c,u_time).
  LOCAL s_normal IS VCRS(velAt(c,u_time),s_pos).
  LOCAL ret_xcl IS VXCL(s_normal,-body_vel).
  LOCAL s_ang IS VANG(s_pos,ret_xcl).
  IF VDOT(VCRS(ret_xcl,s_pos),s_normal) < 0 { SET s_ang TO 360 - s_ang. }
// s_ang is the ejection angle at u_time
  LOCAL ang IS VANG(s_normal,-body_vel).
  LOCAL eff_i IS ABS(ang-90).
// eff_i is the "effective inclination" at u_time, i.e. the angle between the plane of the ship's orbit and that of the body

pOut("=================").
pOut("ejectionAngles().").
LOCAL eta IS ROUND(u_time - TIME:SECONDS).
pOut("Time in future: " + eta + "s.").
pOut("Ejection angle: " + s_ang + " degrees.").
pOut("Effective inc.: " + eff_i + " degrees.").

  RETURN LIST(s_ang, eff_i).
}

FUNCTION predictNextEjection
{
  PARAMETER c, u_time, eject_body, eject_ang, min_ang IS 0.5, min_eff_i IS 25.

  LOCAL min_time IS u_time.
  LOCAL eject_details IS ejectionAngles(c, u_time, eject_body).

  LOCAL s_ang IS eject_details[0].
  LOCAL eff_i IS eject_details[1].

  IF ABS(s_ang - eject_ang) < min_ang AND eff_i < min_eff_i { RETURN u_time. }

  LOCAL o IS ORBITAT(c,u_time).
  LOCAL i IS o:INCLINATION.
  LOCAL s_p IS o:PERIOD.
  LOCAL b_p IS eject_body:ORBIT:PERIOD.
  LOCAL rel_period IS (s_p * b_p) / (b_p - (s_p * COS(i))).
pOut("Ship period: " + ROUND(s_p) + "s.").
pOut("Body period: " + ROUND(b_p) + "s.").
pOut("Relative period: " + ROUND(rel_period) + "s.").

  LOCAL ang_diff IS mAngle(s_ang - eject_ang).
  LOCAL time_diff IS rel_period * ang_diff / 360.

  SET u_time TO u_time + time_diff.
  UNTIL FALSE {
    SET eject_details TO ejectionAngles(c, u_time, eject_body).
    SET s_ang TO eject_details[0].
    SET eff_i TO eject_details[1].

    IF ABS(s_ang - eject_ang) < min_ang {
      IF eff_i < min_eff_i { RETURN u_time. }
      // angle good but relative inclination outside bounds
      // add another orbit then try again
      SET u_time TO u_time + rel_period.
    } ELSE {
      // angle is not good - perhaps our orbit is not very circular
      SET ang_diff TO s_ang - eject_ang.
      LOCAL new_time IS u_time + (0.5 * ang_diff * rel_period / 360).
      IF new_time < min_time {
        SET ang_diff TO mAngle(ang_diff).
        SET new_time TO u_time + (0.5 * ang_diff * rel_period / 360).
      }
      SET u_time TO new_time.
    }
  }
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

  LOCAL e_time IS predictNextEjection(SHIP, u_time, moon, theta_eject).
  SET man_node:ETA TO e_time - TIME:SECONDS.
  LOCAL score_func IS scoreNodeDestReentry@:BIND(dest,dest_pe,i,lan,0,290).
  improveNode(man_node,score_func).

  LOCAL best_score IS score_func(man_node, IMP_MIN_SCORE).

  LOCAL count IS 1.
  UNTIL count > 9 {
    SET e_time TO e_time + (SHIP:ORBIT:PERIOD / 2).
    SET e_time TO predictNextEjection(SHIP, e_time, moon, theta_eject).
    LOCAL e_man_node IS NODE(e_time, 0, 0, ABS(dv)).
    improveNode(e_man_node,score_func).

    LOCAL this_score IS score_func(e_man_node,IMP_MIN_SCORE).
    IF this_score > best_score {
      pOut("New node is better than all previous nodes.").
      SET best_score TO this_score.
      nodeCopy(e_man_node,man_node).
    } ELSE {
      pOut("New node is not better than the previous best.").
    }

    SET count TO count + 1.
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

  IF (SHIP:OBT:HASNEXTPATCH AND ETA:TRANSITION < (TFR_NODE_SECS + 900)) OR
      ETA:PERIAPSIS < (TFR_NODE_SECS + 900) { RETURN FALSE. }

  LOCAL orb_count IS orbitReachesBody(curr_orb,dest).
  IF orb_count < 0 { RETURN TRUE. }
  LOCAL orb IS futureOrbit(curr_orb,orb_count).

  LOCAL orb_pe IS orb:PERIAPSIS.
  LOCAL pe_diff IS ABS(orb_pe - pe).
  LOCAL min_diff IS 1000 * 10^orb_count.
  LOCAL min_pe IS minAltForBody(dest) * 0.8.

  IF pe < min_pe AND orb_count = 0 { SET min_diff TO 100. } // improve accuracy for re-entry

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
        IF eta1 > 900 AND eta1 < (ETA:PERIAPSIS - 900) { SET TFR_NODE_SECS TO eta1. RETURN TRUE. }
      }
      LOCAL n_ta2 IS mAngle(n_ta1 + 180).
      IF taEccOk(orb, n_ta2) {
        LOCAL eta2 IS secondsToTA(SHIP,u_time,mAngle(n_ta1 + 180)) + 1.
        IF eta2 > 900 AND eta2 < (ETA:PERIAPSIS - 900) { SET TFR_NODE_SECS TO eta2. RETURN TRUE. }
      }
    }
  }

  RETURN FALSE.
}

FUNCTION doTransfer
{
  PARAMETER exit_mode, can_stage, dest, dest_pe, dest_i IS -1, dest_lan IS -1, log_file IS "".

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
    }

    IF n1:ETA > 0 {
      addNode(n1).
      IF orbitReachesBody(n1:ORBIT,dest) > 0 {
        pOut("Trans-"+dest:NAME+" Injection node added.").
        IF dest = KERBIN { plotReentry(log_file). }
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
      IF execNode(can_stage) {
        IF dest = KERBIN { plotReentry(log_file). }
        runMode(111). 
      } ELSE { runMode(109,102). }
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
    SET TFR_NODE_SECS TO 900.
    runMode(113).
  } ELSE IF rm = 113 {
    IF NOT isSteerOn() {
      steerSun().
      WAIT UNTIL steerOk().
    }

    IF orbitNeedsCorrection(SHIP:ORBIT,dest,dest_pe,dest_i,dest_lan) {
      LOCAL mcc IS NODE(TIME:SECONDS+TFR_NODE_SECS,0,0,0).
      LOCAL score_func IS scoreNodeDestReentry@:BIND(dest,dest_pe,dest_i,dest_lan,0,290).
      improveNode(mcc,score_func).
      IF nodeDV(mcc) >= 0.2 {
        addNode(mcc).
        pOut("Mid-course correction node added.").
        IF dest = KERBIN { plotReentry(log_file). }
        runMode(114).
      } ELSE { runMode(115). }
    } ELSE { runMode(115). }
  } ELSE IF rm = 114 {
    IF HASNODE {
      IF execNode(can_stage) {
        IF dest = KERBIN { plotReentry(log_file). }
        runMode(112).
      } ELSE { runMode(119,114). }
    } ELSE {
      IF BODY = dest { runMode(131). }
      ELSE IF orbitReachesBody(SHIP:OBT,dest) > 0 { runMode(112). }
      ELSE { runMode(119,112). }
    }
  } ELSE IF rm = 115 {
    IF BODY = dest { runMode(131). } ELSE { runMode(121). }

  } ELSE IF rm = 121 {
    IF BODY = TFR_CURR_BODY AND BODY <> dest AND SHIP:OBT:HASNEXTPATCH {
      LOCAL next_body IS SHIP:OBT:NEXTPATCH:BODY.
      pOut("Sphere of influence transition from "+BODY:NAME+" to "+next_body:NAME+
           " in "+ROUND(ETA:TRANSITION)+"s.").
      LOCAL on_body_change IS bodyChange@:BIND(TFR_CURR_BODY).

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
    SET TFR_CURR_BODY TO BODY.
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
