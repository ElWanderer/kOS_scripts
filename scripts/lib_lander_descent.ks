@LAZYGLOBAL OFF.

pOut("lib_lander_descent.ks v1.2.0 20170629").

FOR f IN LIST(
  "lib_steer.ks",
  "lib_burn.ks",
  "lib_runmode.ks",
  "lib_orbit.ks",
  "lib_slope.ks",
  "lib_geo.ks",
  "lib_lander_common.ks",
  "lib_lander_geo.ks"
) { RUNONCEPATH(loadScript(f)). }

GLOBAL LND_THRUST_ACC IS 0.
GLOBAL LND_RADAR_ADJUST IS 0.
GLOBAL LND_LAT IS 0.
GLOBAL LND_LNG IS 0.
GLOBAL LND_SET_DOWN IS LIST(25,4,10,1.5).
GLOBAL LND_OVERSHOOT IS FALSE.

FUNCTION initDescentValues
{
  PARAMETER l_lat, l_lng, adjust IS 0.

  SET LND_LAT TO l_lat.
  SET LND_LNG TO l_lng.

  setTime("LND_BURN_TIME", 0).

  landerSetMinVSpeed(0).
  SET LND_RADAR_ADJUST TO adjust.

  LOCK LND_THRUST_ACC TO SHIP:AVAILABLETHRUST / MASS.
  initLanderValues().
}

FUNCTION stopDescentValues
{
  UNLOCK LND_THRUST_ACC.
  UNLOCK THROTTLE.
  stopLanderValues().
}

FUNCTION adjustedAltitude
{
  RETURN ALT:RADAR - LND_RADAR_ADJUST.
}

FUNCTION cycleLandingGear
{
  pOut("Cycling landing gear.").
  GEAR OFF.
  WAIT 3.
  GEAR ON.
  WAIT 3.
}

FUNCTION findHighestPointNear
{
  PARAMETER lat,lng.
  LOCAL high_point IS 0.
  FOR x IN RANGE (-10,11,1) {
    LOCAL new_lat IS lat + (x/100).
    FOR y IN RANGE (-10,11,1) {
      LOCAL new_lng IS lng + (y/100).
      LOCAL terrain_height IS LATLNG(new_lat,new_lng):TERRAINHEIGHT.
      SET high_point TO MAX(high_point,terrain_height).
    }
  }
  RETURN high_point.
}

FUNCTION addNodeLowerPeriapsisOverSpot
{
  PARAMETER lat,lng.
  PARAMETER safety_factor,max_dist. // both m
  PARAMETER days_limit.

  pOut("Plotting node to lower periapsis over target spot.").
  IF NOT latOkForInc(lat,SHIP:OBT:INCLINATION) {
    pOut("ERROR: orbit inclination not high enough to overfly target spot.").
    RETURN FALSE.
  }
  LOCAL new_pe IS findHighestPointNear(lat,lng) + safety_factor.
  LOCAL time_over_site IS findNextPass(SHIP,BODY,LATLNG(lat,lng),max_dist,days_limit).
  LOCAL eta IS time_over_site - TIME:SECONDS.
  IF eta < 0 OR eta > (days_limit * ONE_DAY) {
    pOut("ERROR: ship does not overfly target spot within time limit.").
    RETURN FALSE.
  } ELSE IF eta < (SHIP:OBT:PERIOD / 2) + nodeBuffer() {
    pOut("Cannot lower periapsis in time for next time ship overflies target spot.").
    pOut("Warping beyond overflight to recalculate.").
    doWarp(bufferTime() + (SHIP:OBT:PERIOD / 2)).
    RETURN addNodeLowerPeriapsisOverSpot(lat,lng,safety_factor,max_dist,days_limit - (ONE_DAY/eta)).
  } ELSE {
    LOCAL time_of_burn IS time_over_site - (SHIP:OBT:PERIOD / 2).
    LOCAL n IS nodeAlterOrbit(time_of_burn,new_pe).
    addNode(n).
  }

  RETURN TRUE.
}

FUNCTION checkPeriapsis
{
  PARAMETER lat,lng.
  PARAMETER safety_factor. // m

  steerSurf().
  WAIT UNTIL steerOk(1,3).

  LOCAL start_time IS TIME:SECONDS + secondsToAlt(SHIP, TIME:SECONDS, 10000, FALSE).
  LOCAL end_time IS TIME:SECONDS + secondsToTa(SHIP,TIME:SECONDS,0) + 30.
  LOCAL clearance IS pathClearance(start_time, end_time,0.1).
  UNTIL clearance > safety_factor {
    LOCAL new_pe IS PERIAPSIS + (safety_factor - clearance).
    LOCK THROTTLE TO LND_THROTTLE.
    SET LND_THROTTLE TO 0.1.
    WAIT UNTIL PERIAPSIS >= new_pe.
    SET LND_THROTTLE TO 0.
    WAIT 2.
    SET start_time TO TIME:SECONDS + secondsToAlt(SHIP, TIME:SECONDS, 10000, FALSE).
    SET end_time TO TIME:SECONDS + secondsToTa(SHIP,TIME:SECONDS,0) + 30.
    SET clearance TO pathClearance(start_time, end_time,0.1).
  }

  steerOff().
}

FUNCTION refineLandingSite
{
  PARAMETER max_slope, radius.

  LOCAL low_slope_spot IS findLowSlope(max_slope, LND_LAT, LND_LNG, radius).

  SET LND_LAT TO low_slope_spot:LAT.
  SET LND_LNG TO low_slope_spot:LNG.

hudMsg("Landing site chosen: " + ROUND(LND_LAT,5) + " / " + ROUND(LND_LNG,5) + ".").
}

FUNCTION burnDist
{
  PARAMETER dv.
//pOut("burnDist("+ROUND(dv,1)+").").

  LOCAL bt IS burnTime(dv, dv).
  LOCAL a IS -DV_FR.
  LOCAL b IS MASS.
  LOCAL c IS SHIP:AVAILABLETHRUST.

  LOCAL constC IS dv + ((c/a)*LN(b)).
  LOCAL constD IS (c/a) * b * LN(b) / a.
  LOCAL abt IS a*bt.
  LOCAL burn_dist IS constD + (constC*bt) - ((c/a) * (((abt+b)*LN(abt+b))-abt) / a).
//pOut("Calculated burn distance: " + ROUND(burn_dist) + "m.").
  RETURN burn_dist.
}

FUNCTION stepBurnScore
{
  PARAMETER start_time, end_time, step, burn_score, burn_time.

  LOCAL max_acc IS SHIP:AVAILABLETHRUST / MASS.
  LOCAL spot IS LATLNG(LND_LAT, LND_LNG).

  LOCAL check_time IS start_time.
  UNTIL check_time > end_time {

    LOCAL time_diff IS check_time-TIME:SECONDS.
    LOCAL v IS VELOCITYAT(SHIP, check_time):SURFACE.
    LOCAL ship_pos IS POSITIONAT(SHIP, check_time).
    LOCAL spot_pos IS spotRotated(BODY, spot, time_diff):POSITION.
    LOCAL ship_spot IS spotRotated(BODY, BODY:GEOPOSITIONOF(ship_pos), time_diff).
    LOCAL ship_spot_details IS spotDetails(ship_spot:LAT, ship_spot:LNG).
    LOCAL ship_pos_up_v IS ship_spot_details[1].
    LOCAL spot_pos_h IS VXCL(ship_pos_up_v, spot_pos - ship_pos).
    LOCAL v_h IS VXCL(ship_pos_up_v, v).

    LOCAL est_burn_dist IS burnDist(v_h:MAG).
    SET est_burn_dist TO est_burn_dist * 1.05. // 5% safety factor
//pOut("Estimated burn distance: " + ROUND(est_burn_dist) + "m.").

    LOCAL score IS (spot_pos_h - (est_burn_dist * v_h:NORMALIZED)):MAG.

    IF score < burn_score {
      SET burn_score TO score.
      SET burn_time TO check_time.
    }

    SET check_time TO check_time + step.
  }

  IF step > 1 {
    LOCAL new_step IS MAX(1, ROUND(step / 10)).
    RETURN stepBurnScore(burn_time+new_step-step, burn_time+step-new_step, new_step, burn_score, burn_time).
  }

  RETURN burn_time.
}

FUNCTION calcDescentBurnTime
{
  LOCAL pe_time IS TIME:SECONDS + secondsToTa(SHIP,TIME:SECONDS,0).
  LOCAL burn_time IS pe_time.

  IF SHIP:AVAILABLETHRUST > 0 {
    SET burn_time TO stepBurnScore(pe_time-600, pe_time+600, 60, 99999, pe_time).
  }

  setTime("LND_BURN_TIME", burn_time).
pOut("Start descent burn in " + ROUND(-diffTime("LND_BURN_TIME")) + "s.").
pOut("Start descent burn at " + formatTS(TIMES["LND_BURN_TIME"],TIME:SECONDS-MISSIONTIME)).

  LOCAL start_time IS TIME:SECONDS + secondsToAlt(SHIP, TIME:SECONDS, 10000, FALSE).
  LOCAL end_time IS TIMES["LND_BURN_TIME"] + 30.
  pathClearance(start_time, end_time,0.1).

  RETURN burn_time.
}

FUNCTION warpToDescentBurn
{
  PARAMETER ahead IS -20.
  LOCAL warp_time IS TIMES["LND_BURN_TIME"] + ahead.
  IF warp_time - TIME:SECONDS > 5 {
    pOut("Warping to descent burn point.").
    doWarp(warp_time).
  }
}

FUNCTION constantAltitudeVec
{
  CLEARVECDRAWS().
//pOut("constantAltitudeVec").

  LOCAL final_vector IS UP:VECTOR.

  LOCAL spot IS LATLNG(LND_LAT,LND_LNG).
  LOCAL des_h_v IS VXCL(UP:VECTOR,spot:POSITION).
//pOut("Distance to landing site: "+ROUND(des_h_v:MAG)+"m.").
  LOCAL cur_h_v IS VXCL(UP:VECTOR,VELOCITY:SURFACE).
//pOut("Horizontal velocity: " + ROUND(cur_h_v:MAG,1) + "m/s.").

  VECDRAW(V(0,0,0), spot:ALTITUDEPOSITION(spot:TERRAINHEIGHT+1), RGB(1,0,0), "Landing site "+ROUND(des_h_v:MAG/1000,1)+"km", 1, TRUE).
  VECDRAW(V(0,0,0), VELOCITY:SURFACE, RGB(1,1,0), "Current vel", 1, TRUE).

  SET LND_PITCH TO landerPitch().

  LOCAL v_x2 IS VXCL(UP:VECTOR,VELOCITY:ORBIT):SQRMAGNITUDE.
  LOCAL v_xs2 IS VXCL(UP:VECTOR,VELOCITY:SURFACE):SQRMAGNITUDE.

  LOCAL cent_acc IS v_x2 / (BODY:RADIUS + ALTITUDE).
  LOCAL ship_v_acc IS MAX(0,LND_G_ACC - cent_acc + (LND_MIN_VS - SHIP:VERTICALSPEED)).
//pOut("ship_v_acc: " + ROUND(ship_v_acc,2)).
  LOCAL worst_p_ang IS 90.
  LOCAL acc_ratio IS ship_v_acc / LND_THRUST_ACC.
  IF acc_ratio < 0 { SET worst_p_ang TO 0. }
  ELSE IF acc_ratio < 1 { SET worst_p_ang TO ARCSIN(acc_ratio). }
  LOCAL max_h_acc IS LND_THRUST_ACC * COS(worst_p_ang).
//pOut("max_h_acc: " + ROUND(max_h_acc,2)).
  LOCAL ship_h_acc IS v_xs2 / (2 * des_h_v:MAG).
//pOut("ship_h_acc: " + ROUND(ship_h_acc,2)).
  LOCAL des_speed IS SQRT(des_h_v:MAG * max_h_acc) * 0.75.
//pOut("des_speed: " + ROUND(des_speed,1) + "m/s.").
  IF NOT LND_OVERSHOOT AND des_h_v:MAG > 1 AND VDOT(des_h_v:NORMALIZED, cur_h_v:NORMALIZED) < 0 {
    hudMsg("OVERSHOOT (we are travelling away from the landing site).").
    SET LND_OVERSHOOT TO TRUE.
  } ELSE IF LND_OVERSHOOT AND VDOT(des_h_v:NORMALIZED, cur_h_v) > des_speed {
    hudMsg("Ending OVERSHOOT mode.").
    SET LND_OVERSHOOT TO FALSE.
  }

  LOCAL h_thrust_v IS V(0,0,0).
  IF LND_OVERSHOOT {
    IF LND_THROTTLE > 0 { SET LND_THROTTLE TO 1. }
    SET LND_PITCH TO worst_p_ang.
//pOut("Pitch (overshoot case): " + LND_PITCH).

    SET h_thrust_v TO ((des_speed + max_h_acc) * des_h_v:NORMALIZED) - cur_h_v.
  } ELSE {
    IF ABS(max_h_acc) < ABS(ship_h_acc) {
      IF LND_THROTTLE > 0 { SET LND_THROTTLE TO 1. }
      SET LND_PITCH TO worst_p_ang.
//pOut("Pitch (worst case): " + LND_PITCH).
    } ELSE {
      LOCAL total_acc IS SQRT(ship_v_acc^2 + ship_h_acc^2).
//pOut("total_acc: " + ROUND(total_acc,2)).
      LOCAL des_throttle IS MIN(1,total_acc / LND_THRUST_ACC).
      LOCAL des_pitch IS MIN(90,MAX(0,ARCCOS(ship_h_acc/total_acc))).
      IF LND_THROTTLE > 0 { SET LND_THROTTLE TO des_throttle. }
      SET LND_PITCH TO des_pitch.
//pOut("Pitch (normal): " + LND_PITCH).
    }

    SET h_thrust_v TO ((cur_h_v:MAG - ship_h_acc) * des_h_v:NORMALIZED) - cur_h_v.
  }

  IF LND_PITCH < 90 AND h_thrust_v:MAG > 0 {
    VECDRAW(V(0,0,0), 5 * h_thrust_v:NORMALIZED, RGB(0.3,0.3,1), "Horizontal thrust vector ", 1, TRUE).
    SET final_vector TO ANGLEAXIS(LND_PITCH,VCRS(-h_thrust_v,BODY:POSITION)) * h_thrust_v.
  }

  VECDRAW(V(0,0,0), 5 * FACING:VECTOR, RGB(0,1,0), "Current facing", 1, TRUE).
  VECDRAW(V(0,0,0), 5 * final_vector:NORMALIZED, RGB(0,0,1), "Desired facing", 1, TRUE).

  IF VANG(final_vector, FACING:VECTOR) > 15 AND LND_THROTTLE > 0 {
    SET LND_THROTTLE TO MAX(0.01, LND_THROTTLE * VDOT(final_vector:NORMALIZED,FACING:VECTOR)).
  }
//pOut("Throttle: " + ROUND(LND_THROTTLE,2)).

  RETURN final_vector.
}

FUNCTION doConstantAltitudeBurn
{
  pOut("Preparing for constant altitude burn.").

  SET LND_THROTTLE TO 0.
  LOCK THROTTLE TO LND_THROTTLE.
  LOCAL spot IS LATLNG(LND_LAT,LND_LNG).

  LOCAL surface_g IS BODY:MU / BODY:RADIUS^2.
  LOCAL min_safety_factor IS MAX(30,(10 * surface_g)).

  WAIT UNTIL diffTime("LND_BURN_TIME") > -1 OR LND_OVERSHOOT.
  pOut("Executing constant altitude burn.").
  landerResetTimer().
  findMinVSpeed2(-20,10,0.5,min_safety_factor).
  SET LND_THROTTLE TO 1.
  LOCAL done IS FALSE.
  UNTIL done {
    IF landerHeartbeat() > 0.5 {
      landerResetTimer().
      LOCAL safety_factor IS min_safety_factor.
      LOCAL burn_time IS 20.
      LOCAL step IS 1.

      LOCAL cur_h_v IS VXCL(UP:VECTOR,VELOCITY:SURFACE).
      LOCAL acc_v IS VXCL(UP:VECTOR,FACING:VECTOR * LND_THRUST_ACC * LND_THROTTLE).
      LOCAL acc_dot IS VDOT(cur_h_v:NORMALIZED, -acc_v).
      IF acc_dot > 0 {
        SET burn_time TO MIN(60,MAX(1,ROUND(cur_h_v:MAG / acc_dot))).
        IF burn_time <= 5 { SET step tO 0.25. }
        ELSE IF burn_time <= 10 { SET step TO 0.5. }
      }
      LOCAL mod_vs IS SHIP:VERTICALSPEED - (surface_g *0.5).
      IF mod_vs < 0 {
        LOCAL max_acc IS LND_THRUST_ACC - surface_g.
        LOCAL min_burn_dist IS mod_vs^2 / (2 * max_acc).
        SET safety_factor TO MAX(min_burn_dist, safety_factor).
      }
      findMinVSpeed2(-50,burn_time,step,safety_factor).
    }

    IF GROUNDSPEED < 0.25 AND spot:ALTITUDEPOSITION(ALTITUDE):MAG < 5 {
      SET done TO TRUE.
      pOut("Groundspeed close to zero and near landing site.").
      pOut("Ending constant altitude burn.").
    }
  }

  SET LND_THROTTLE TO 0.
  steerSurf(FALSE).
}

FUNCTION stepTerrainImpact
{
  PARAMETER start_time, look_ahead, step.

  LOCAL s_count IS 1.
  UNTIL s_count > (look_ahead / step) {
    LOCAL u_time IS start_time + (s_count * step).
    IF u_time > TIME:SECONDS AND radarAltAtTime(u_time) < LND_RADAR_ADJUST {
      IF step > 1 { RETURN stepTerrainImpact(u_time - step, step * 2, 1). }
      ELSE IF step = 1 { RETURN stepTerrainImpact(u_time-1, 2, 0.1). }
      ELSE { RETURN terrainAltAtTime(u_time). }
    }
    SET s_count TO s_count + 1.
  }
  RETURN 0.
}

FUNCTION calculateImpact
{
  RETURN stepTerrainImpact(TIME:SECONDS,300,10).
}

FUNCTION suicideBurnThrot
{
  PARAMETER imp_alt, surface_g.
  LOCAL burn_throt IS 0.

  LOCAL max_acc IS LND_THRUST_ACC - surface_g.
  LOCAL cur_acc IS (LND_THRUST_ACC * LND_THROTTLE) - surface_g.

  LOCAL sv2 IS SHIP:VELOCITY:SURFACE:SQRMAGNITUDE.
  LOCAL min_burn_dist IS sv2 / (2 * max_acc).
  LOCAL cur_burn_dist IS 99999.
  IF cur_acc > 0 { SET cur_burn_dist TO sv2 / (2 * cur_acc). }

  LOCAL ship_alt IS MIN(ALT:RADAR,ALTITUDE - imp_alt) - LND_RADAR_ADJUST.
  LOCAL dist_adjust IS -SHIP:VERTICALSPEED / 10.

  IF (min_burn_dist + dist_adjust) > ship_alt { SET burn_throt TO 1. }
  ELSE IF LND_THROTTLE > 0 {
    IF (cur_burn_dist + dist_adjust) > ship_alt { SET burn_throt TO MIN(1,LND_THROTTLE+0.05). }
    ELSE { SET burn_throt TO MAX(0,LND_THROTTLE-0.05). }
  }

  RETURN burn_throt.
}

FUNCTION doSuicideBurn
{
  pOut("Waiting to apply suicide burn.").
  LOCK THROTTLE TO LND_THROTTLE.

  LOCAL surface_g IS BODY:MU / BODY:RADIUS^2.
  LOCAL imp_alt IS calculateImpact().
  landerResetTimer().

  UNTIL adjustedAltitude() < LND_SET_DOWN[0] {
    IF landerHeartbeat() > 1 {
      landerResetTimer().
      SET imp_alt TO calculateImpact().
    }
    SET LND_THROTTLE TO suicideBurnThrot(imp_alt, surface_g).
    WAIT 0.
  }
}

FUNCTION doSetDown
{
  pOut("Setting down.").
  LOCK THROTTLE TO LND_THROTTLE.
  PANELS OFF.

  LOCAL aim_speed IS LND_SET_DOWN[1].

  UNTIL adjustedAltitude() < 0.5 OR LIST("LANDED","SPLASHED"):CONTAINS(STATUS) {
    IF adjustedAltitude() < LND_SET_DOWN[2] AND aim_speed > LND_SET_DOWN[3] {
      SET aim_speed TO LND_SET_DOWN[3].
      steerTo({ RETURN UP:VECTOR. }).
    }

    LOCAL des_acc IS 5 * (-SHIP:VERTICALSPEED - aim_speed).
    LOCAL des_throt IS (des_acc + gravAcc()) / LND_THRUST_ACC.
    SET LND_THROTTLE TO MIN(1,MAX(0,des_throt)).
    WAIT 0.
  }

  pOut("Cutting throttle.").
  SET LND_THROTTLE TO 0.
  WAIT UNTIL LIST("LANDED","SPLASHED"):CONTAINS(STATUS).
  hudMsg("Touchdown.").
  pOut("Landed at LAT: " + ROUND(LATITUDE,2) + " LNG: " + ROUND(LONGITUDE,2)).
  VECDRAW(V(0,0,0),LATLNG(LND_LAT,LND_LNG):POSITION,RED,"Landing site aim point",1,TRUE).
  dampSteering().
  WAIT 10. PANELS ON.
  CLEARVECDRAWS().
}

FUNCTION doLanding
{
  PARAMETER l_lat, l_lng.
  PARAMETER radar_adjust. // metres between the root part and bottom of landing gear
  PARAMETER pe_safety_factor, max_dist. // both m
  PARAMETER days_limit, exit_mode.
  PARAMETER max_slope IS 3. // degrees
  PARAMETER lander_radius IS 2.5. // metres

  LOCAL LOCK rm TO runMode().

  IF rm < 201 OR rm > 249 { runMode(201). }
  initDescentValues(l_lat, l_lng, radar_adjust).

UNTIL rm = exit_mode
{
  IF rm = 201 {
    pOut("Beginning landing program.").
    runMode(202).
  } ELSE IF rm = 202 {
    cycleLandingGear().
    runMode(211).

  } ELSE IF rm = 211 {
    IF nodeGeoPhasingOrbit(SHIP, LND_LAT, LND_LNG, days_limit) { runMode(215). }
    ELSE { runMode(212). }

  } ELSE IF rm = 212 {
    // TBD - phasing hasn't worked so plot a direct intercept?
    runMode(221).

  } ELSE IF rm = 215 {
    IF NOT HASNODE { runMode(211). }
    ELSE IF execNode(TRUE) { runMode(221). }

  } ELSE IF rm = 221 {
    IF addNodeLowerPeriapsisOverSpot(LND_LAT,LND_LNG,pe_safety_factor,max_dist,days_limit) { runMode(222). }
    ELSE {
      runMode(229,221).
      pOut("Going into standby mode.").
      steerSun().
    }
  } ELSE IF rm = 222 {
    IF NOT HASNODE { runMode(221). }
    ELSE IF execNode(TRUE) { runMode(223). }
  } ELSE IF rm = 223 {
    checkPeriapsis(LND_LAT,LND_LNG,pe_safety_factor).
    runMode(231).
  } ELSE IF rm = 229 {
    // wait

  } ELSE IF rm = 231 {
    refineLandingSite(max_slope, lander_radius).
    calcDescentBurnTime().
    CLEARVECDRAWS().
    warpToDescentBurn(-120).
    calcDescentBurnTime().
    warpToDescentBurn().
    steerTo(constantAltitudeVec@).
    doConstantAltitudeBurn().
    CLEARVECDRAWS().
    runMode(233).
  } ELSE IF rm = 233 {
    steerSurf(FALSE).
    doSuicideBurn().
    runMode(234).
  } ELSE IF rm = 234 {
    IF NOT isSteerOn() { steerSurf(FALSE). }
    doSetDown().
    runMode(exit_mode).
  } ELSE {
    pOut("Lander - unexpected run mode: " + rm).
    runMode(exit_mode).
  }

  WAIT 0.
}

  stopDescentValues().
}