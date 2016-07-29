@LAZYGLOBAL OFF.


pOut("lib_transfer.ks v1.1.0 20160727").

FOR f IN LIST(
  "lib_orbit.ks",
  "lib_burn.ks",
  "lib_runmode.ks",
  "lib_hoh.ks",
  "lib_warp.ks"
) { RUNONCEPATH(loadScript(f)). }

GLOBAL CURRENT_BODY IS BODY.
GLOBAL MAX_SCORE IS 99999.
GLOBAL TIME_TO_NODE IS 900.

FUNCTION bodyChange
{
  PARAMETER cb.
  RETURN BODY <> cb.
}

FUNCTION futureOrbit
{
  PARAMETER init_orb, count.

  LOCAL orb IS init_orb.
  LOCAL i IS 1.
  UNTIL i > count {
    SET i TO i + 1.
    IF orb:HASNEXTPATCH { SET orb TO orb:NEXTPATCH. }
    ELSE { pOut("WARNING: futureOrbit("+count+") called but orbit does not have that many patches."). }
  }
  
  RETURN orb.
}

FUNCTION orbitReachesBody
{
  PARAMETER orb, dest.
  PARAMETER count IS 0.

  IF orb:BODY = dest { RETURN count. }
  ELSE IF orb:HASNEXTPATCH { RETURN orbitReachesBody(orb:NEXTPATCH,dest,count+1). }
  ELSE { RETURN -1. }
}

FUNCTION scoreNode
{
  PARAMETER n.
  PARAMETER dest.
  PARAMETER pe, i, lan.
  LOCAL score IS 0.

  ADD n.
  LOCAL orb IS n:ORBIT.
  LOCAL orb_count IS orbitReachesBody(orb,dest).
  IF orb_count >= 0 {
    SET score TO MAX_SCORE - nodeDV(n).
    LOCAL next_orb IS futureOrbit(orb,orb_count).
    LOCAL next_pe IS next_orb:PERIAPSIS.
    LOCAL next_i IS next_orb:INCLINATION.
    LOCAL next_lan IS next_orb:LAN.

    IF i >= 0 {
      LOCAL i_diff IS ABS(next_i - i).
      LOCAL lan_diff IS ABS(next_lan - lan).
      IF lan >=0 AND lan_diff > 90 AND lan_diff < 270 AND i > 0 AND i < 180 {
        SET i_diff TO next_i + i.
      }
      SET score TO score - (i_diff * 100).
    }

    SET score TO score - (ABS(next_pe - pe) / 10).
    
    LOCAL min_pe IS 20000.
    IF dest:ATM:EXISTS { SET min_pe TO dest:ATM:HEIGHT + 15000. }
    IF next_pe < min_pe AND pe > min_pe { SET score TO score - ((5000 + min_pe - next_pe) / 250). }

  } ELSE {
    LOCAL apsis_time IS TIME:SECONDS + n:ETA + (orb:PERIOD / 2).
    LOCAL s_pos IS posAt(SHIP,apsis_time).
    LOCAL d_pos IS posAt(dest,apsis_time).
    LOCAL sep_dist IS ABS((s_pos - d_pos):MAG).
    SET score TO -sep_dist.
  }
  REMOVE n.

  RETURN score.
}

FUNCTION improveNode
{
  PARAMETER n.
  PARAMETER dest, dest_pe.
  PARAMETER i IS -1.
  PARAMETER lan IS -1.

  LOCAL curr_pro IS n:PROGRADE.
  LOCAL curr_norm IS n:NORMAL.
  LOCAL curr_rad IS n:RADIALOUT.
  LOCAL curr_man_time IS TIME:SECONDS + n:ETA.
  LOCAL best_node IS NODE(curr_man_time,curr_rad,curr_norm,curr_pro).
  LOCAL best_score IS scoreNode(best_node,dest,dest_pe,i,lan).

  LOCAL dv_delta IS 0.004 * 2^10.
  LOCAL eta_delta IS 0.016 * 2^10.
  LOCAL delta_change_count IS 1.

  LOCAL done IS FALSE.
  UNTIL done {
    LOCAL is_new_best_score IS FALSE.

    FOR t_loop IN RANGE(-1,2,1) {
      LOCAL new_man_time IS curr_man_time + (eta_delta * t_loop).
      FOR p_loop IN RANGE(-1,2,1) {
        LOCAL new_pro IS curr_pro + (dv_delta * p_loop).
        FOR n_loop IN RANGE(-1,2,1) {
          LOCAL new_norm IS curr_norm + (dv_delta * n_loop).
          FOR r_loop IN RANGE(-1,2,1) {
            LOCAL new_rad IS curr_rad + (dv_delta * r_loop).
            LOCAL new_node IS NODE(new_man_time,new_rad,new_norm,new_pro).
            LOCAL new_score IS scoreNode(new_node,dest,dest_pe,i,lan).
            IF new_score > best_score {
              SET is_new_best_score TO TRUE.
              SET best_score TO new_score.
              SET best_node TO NODE(new_man_time,new_rad,new_norm,new_pro).
            }
          }
        }
      }
    }

    IF is_new_best_score {
      SET curr_pro TO best_node:PROGRADE.
      SET curr_norm TO best_node:NORMAL.
      SET curr_rad TO best_node:RADIALOUT.
      SET curr_man_time TO TIME:SECONDS + best_node:ETA.
    } ELSE {
      IF delta_change_count > 11 {
        SET n:PROGRADE to best_node:PROGRADE.
        SET n:NORMAL to best_node:NORMAL.
        SET n:RADIALOUT to best_node:RADIALOUT.
        
SET n:ETA TO best_node:ETA.
        SET done TO TRUE.
      } ELSE {
        SET delta_change_count TO delta_change_count + 1.
        SET dv_delta TO dv_delta / 2.
        SET eta_delta TO eta_delta / 2.
      }
    }
  }
}

FUNCTION nodeBodyToMoon
{
  PARAMETER u_time, dest, dest_pe.
  PARAMETER i IS -1, lan IS -1.

  LOCAL t_pe IS 0.
  IF i < 45 { SET t_pe TO dest:RADIUS + dest_pe. }
  ELSE IF i > 135 { SET t_pe TO -dest:RADIUS - dest_pe. }

  LOCAL hnode IS nodeHohmann(dest, u_time, t_pe).

  improveNode(hnode,dest,dest_pe,i,lan).

  RETURN hnode.
}


FUNCTION nodeMoonToBody
{
  PARAMETER u_time.
  PARAMETER moon.
  PARAMETER dest_pe.

  LOCAL planet IS moon:OBT:BODY.

  LOCAL mu IS moon:MU.
  LOCAL hoh_mu IS planet:MU.
  LOCAL r_soi IS moon:SOIRADIUS.
  LOCAL r_pe IS ORBITAT(SHIP,u_time):SEMIMAJORAXIS.

  LOCAL r1 IS ORBITAT(moon,u_time):SEMIMAJORAXIS.
  LOCAL r2 IS dest_pe + planet:RADIUS.
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
  ELSE { pOut("Cannot calculate ejection angle as required orbit is not a hyperbola."). }

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
      improveNode(man_node,planet,dest_pe).
    }
    SET c_time TO c_time + 15.
  }

  RETURN man_node.
}


FUNCTION doTransfer
{
  PARAMETER exit_mode, can_stage.
  PARAMETER dest, dest_pe.
  PARAMETER dest_i IS -1.
  PARAMETER dest_lan IS -1.

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
      // planet to moon
      SET n1 TO nodeBodyToMoon(t_time,dest,dest_pe,dest_i,dest_lan).
    } ELSE IF dest = BODY:OBT:BODY {
      // moon to planet (or planet to sun)
      SET n1 TO nodeMoonToBody(t_time,BODY,dest_pe).
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
    // check if we've appeared in the orbit of the destination beyond the periapsis
    LOCAL secs_to_pe IS secondsToTA(SHIP,TIME:SECONDS+1,0) - 1.
    IF BODY = dest AND 
      (secs_to_pe < 0 OR (SHIP:OBT:HASNEXTPATCH AND ETA:TRANSITION < secs_to_pe)) {
      runMode(131).
    } ELSE { runMode(112). }
  } ELSE IF rm = 112 {
    SET TIME_TO_NODE TO 900.
    runMode(113).
  } ELSE IF rm = 113 {
    IF NOT isSteerOn() {
      steerSun().
      WAIT UNTIL steerOk().
    }
    // check node would not be too close to SoI transition / periapsis before continuing
    IF (SHIP:OBT:HASNEXTPATCH AND ETA:TRANSITION < (TIME_TO_NODE + 900)) OR
        ETA:PERIAPSIS < (TIME_TO_NODE + 900) { runMode(115). }
    ELSE {
      // check accuracy of orbit
      // TBD - work out when we can sensibly try to change the inclination
      LOCAL mcc IS NODE(TIME:SECONDS+TIME_TO_NODE,0,0,0).
      ADD mcc.
      WAIT 0.
      LOCAL orb_pe IS 0.
      LOCAL orb_count IS orbitReachesBody(mcc:ORBIT,dest).
      IF orb_count >= 0 { SET orb_pe TO futureOrbit(mcc:ORBIT,orb_count):PERIAPSIS. }
      REMOVE mcc.
      IF orb_count < 0 OR ABS(orb_pe - dest_pe) > (1000 * 25^orb_count) {
        improveNode(mcc,dest,dest_pe,dest_i,dest_lan).
        addNode(mcc).
        pOut("Mid-course correction node added.").
        runMode(114).
      } ELSE { runMode(115). }
    }
  } ELSE IF rm = 114 {
    IF HASNODE {
      IF execNode(can_stage) { runMode(113). } ELSE { runMode(119,114). }
    } ELSE {
      IF BODY = dest { runMode(131). }
      ELSE IF orbitReachesBody(SHIP:OBT,dest) > 0 { runMode(113). }
      ELSE { runMode(119,112). }
    }
  } ELSE IF rm = 115 {
    // go to next SoI transition if not already in SoI of destination:
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
    // once in sphere of influence of destination, enter orbit or exit function
    // re-entry or aerobraking handled separately by other scripts
    IF NOT BODY:ATM:EXISTS OR PERIAPSIS > BODY:ATM:HEIGHT {
      // check in case we're beyond the periapsis
      LOCAL secs_to_pe IS secondsToTA(SHIP,TIME:SECONDS+1,0) - 1.
      IF (SHIP:OBT:HASNEXTPATCH AND ETA:TRANSITION < secs_to_pe) OR secs_to_pe < 0 {
        SET secs_to_pe TO 60.
      }

      LOCAL oi IS nodeAlterOrbit(TIME:SECONDS+secs_to_pe,dest_pe).
      addNode(oi).
      pOut(dest:NAME + " Orbit Insertion node added.").
      runMode(132).
    } ELSE {
      runMode(133).
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
    WAIT UNTIL MOD(rm,10) <> 9.
  } ELSE {
    pOut("Transfer - unexpected run mode: " + rm).
    runMode(149,101).
  }

  WAIT 0.
}

}