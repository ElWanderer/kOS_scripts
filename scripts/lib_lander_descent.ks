@LAZYGLOBAL OFF.

pOut("lib_lander_descent.ks v1.2.0 20180110").

FOR f IN LIST(
  "lib_steer.ks",
  "lib_burn.ks",
  "lib_runmode.ks",
  "lib_orbit.ks",
  "lib_slope.ks",
  "lib_geo.ks",
  "lib_lander_common.ks",
  "lib_lander_geo.ks",
  "lib_draw.ks"
) { RUNONCEPATH(loadScript(f)). }

// needs tuning...
GLOBAL LND_PID IS PIDLOOP(1, 0, 5, -999, 999).

GLOBAL LND_THRUST_ACC IS 0.
GLOBAL LND_RADAR_ADJUST IS 0.
GLOBAL LND_LAT IS 0.
GLOBAL LND_LNG IS 0.
GLOBAL LND_SET_DOWN IS LIST(30,6,8,2).
GLOBAL LND_OVERSHOOT IS FALSE.
GLOBAL LND_ALLOWED_DRIFT IS 0.5.
GLOBAL LND_ALLOWED_DIST IS 4.
GLOBAL LND_VS_LIMIT IS -99.
GLOBAL LND_SURF_G IS BODY:MU / BODY:RADIUS^2.

GLOBAL LND_LEG_LEX IS LEXICON(
  "LT-2 Landing Strut", 1.7,
  "LT-1 Landing Struts", 1.75,
  "LT-05 Micro Landing Strut", 1.2).

FUNCTION calcRadarAltAdjust
{
  LOCAL core_height IS 0.
  LOCAL pl IS LIST().
  LIST PARTS IN pl.
  FOR p IN pl {
    LOCAL p_pos IS p:POSITION - CORE:PART:POSITION.
    LOCAL p_height IS VDOT(-FACING:VECTOR,p_pos).
    IF LND_LEG_LEX:HASKEY(p:TITLE) { 
      SET p_height TO p_height + LND_LEG_LEX[p:TITLE].
    } ELSE IF p:TITLE:CONTAINS("Strut") OR p:TITLE:CONTAINS("Land") OR p:TITLE:CONTAINS("Gear") {
      SET p_height TO p_height + 1.5.
    }
    SET core_height tO MAX(p_height, core_height).
  }
  RETURN core_height.
}

FUNCTION initDescentValues
{
  PARAMETER l_lat, l_lng, vs_limit IS LND_VS_LIMIT.

  SET LND_LAT TO l_lat.
  SET LND_LNG TO l_lng.
  SET LND_RADAR_ADJUST TO calcRadarAltAdjust().
  SET LND_VS_LIMIT TO vs_limit.
  setTime("LND_BURN_TIME", 0).
  landerSetMinVSpeed(0).
  LOCK LND_THRUST_ACC TO SHIP:AVAILABLETHRUST / MASS.
  initLanderValues().
}

FUNCTION stopDescentValues
{
  UNLOCK LND_THRUST_ACC.
  UNLOCK THROTTLE.
}

FUNCTION isLanded
{
  RETURN LIST("LANDED","SPLASHED"):CONTAINS(STATUS).
}

FUNCTION adjustedAltitude
{
  RETURN ALT:RADAR - LND_RADAR_ADJUST.
}

FUNCTION cycleLandingGear
{
  pOut("Cycling landing gear.").
  GEAR OFF.
  WAIT 5.
  GEAR ON.
  WAIT 5.
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
  IF start_time > (end_time - 1) { SET start_time TO MIN(TIME:SECONDS, end_time - 30). }
  LOCAL clearance IS pathClearance(start_time, end_time,0.1).
  UNTIL clearance > safety_factor {
    LOCAL new_pe IS PERIAPSIS + (safety_factor - clearance).
    LOCK THROTTLE TO LND_THROTTLE.
    SET LND_THROTTLE TO 0.1.
    WAIT UNTIL PERIAPSIS >= new_pe.
    SET LND_THROTTLE TO 0.
    WAIT 1.
    SET start_time TO TIME:SECONDS + secondsToAlt(SHIP, TIME:SECONDS, 10000, FALSE).
    SET end_time TO TIME:SECONDS + secondsToTa(SHIP,TIME:SECONDS,0) + 30.
    IF start_time > (end_time - 1) { SET start_time TO MIN(TIME:SECONDS, end_time - 30). }
    SET clearance TO pathClearance(start_time, end_time,0.1).
  }

  steerOff().
}

FUNCTION refineLandingSite
{
  PARAMETER max_slope, radius.

LOCAL slope_details IS slopeDetails(LND_LAT, LND_LNG, radius).
LOCAL th IS ROUND(slope_details[2],1).
LOCAL sa IS ROUND(slope_details[4],2).
hudMsg("Initial site " + ROUND(LND_LAT,4) + " / " + ROUND(LND_LNG,4) + " with terrain height: " + th + "m, slope angle: " + sa + " degrees.", YELLOW, 20).

  LOCAL low_slope_spot IS findLowSlope(max_slope, LND_LAT, LND_LNG, radius).

  SET LND_LAT TO low_slope_spot:LAT.
  SET LND_LNG TO low_slope_spot:LNG.

SET slope_details TO slopeDetails(LND_LAT, LND_LNG, radius).
SET th TO ROUND(slope_details[2],1).
SET sa TO ROUND(slope_details[4],2).

hudMsg("Improved site " + ROUND(LND_LAT,4) + " / " + ROUND(LND_LNG,4) + " with terrain height: " + th + "m, slope angle: " + sa + " degrees.", YELLOW, 20).
}

FUNCTION burnDist
{
  PARAMETER dv.

  LOCAL bt IS burnTime(dv, dv).
  LOCAL a IS -DV_FR.
  LOCAL b IS MASS.
  LOCAL c IS SHIP:AVAILABLETHRUST.

  LOCAL constC IS dv + ((c/a)*LN(b)).
  LOCAL constD IS (c/a) * b * LN(b) / a.
  LOCAL abt IS a*bt.
  LOCAL burn_dist IS constD + (constC*bt) - ((c/a) * (((abt+b)*LN(abt+b))-abt) / a).

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

    LOCAL theta IS VANG(spot_pos_h, v_h).
    LOCAL correction_dv IS 2 * v_h:MAG * SIN(theta/2).
    LOCAL correction_time IS burnTime(correction_dv).
    LOCAL correction_dist IS correction_time * v_h:MAG.

    LOCAL est_burn_dist IS burnDist(v_h:MAG).
    SET est_burn_dist TO (est_burn_dist + correction_dist) * 1.05.

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
  IF start_time > (end_time - 1) { SET start_time TO MIN(TIME:SECONDS, end_time - 30). }
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
//pOut("***___constantAltitudeVec___***").

  LOCAL final_vector IS UP:VECTOR.
  IF LND_THRUST_ACC = 0 { RETURN final_vector. }

//pOut("Radar altitude: " + ROUND(adjustedAltitude()) + "m.").

  LOCAL max_ang IS 15.

  LOCAL spot IS LATLNG(LND_LAT,LND_LNG).
  LOCAL des_h_v IS VXCL(UP:VECTOR,spot:POSITION).
  LOCAL h_dist IS des_h_v:MAG.
//pOut("Distance to landing site: "+ROUND(h_dist)+"m.").
  LOCAL cur_h_v IS VXCL(UP:VECTOR,VELOCITY:SURFACE).
//pOut("Horizontal velocity: " + ROUND(GROUNDSPEED,1) + "m/s.").
//pOut("Vertical velocity: " + ROUND(SHIP:VERTICALSPEED,1) + "m/s.").

  // display-only code
  LOCAL spot_draw_v IS spot:ALTITUDEPOSITION(ALTITUDE).
  LOCAL spot_dist_string IS ROUND(h_dist/1000,1)+"km".
  IF h_dist < 1000 {
    SET spot_dist_string TO ROUND(h_dist)+"m".
  }
  drawVector("land", V(0,0,0), spot_draw_v, "Landing site "+spot_dist_string, RGB(1,0,0)).
  drawVector("spot", spot_draw_v, spot:ALTITUDEPOSITION(spot:TERRAINHEIGHT)-spot_draw_v, "", RGB(1,0,0)).
  drawVector("svel", V(0,0,0), VELOCITY:SURFACE, "Current vel", RGB(1,1,0)).
  // end of display

  LOCAL v_xs2 IS VXCL(UP:VECTOR,VELOCITY:SURFACE):SQRMAGNITUDE.

  LOCAL ship_v_acc IS 0.
  IF LND_THROTTLE > 0 {
    LOCAL v_x2 IS VXCL(UP:VECTOR,VELOCITY:ORBIT):SQRMAGNITUDE.
    LOCAL cent_acc IS v_x2 / (BODY:RADIUS + ALTITUDE).
    SET ship_v_acc TO MAX(0,LND_PID:UPDATE(TIME:SECONDS,SHIP:VERTICALSPEED) + (gravAcc() - cent_acc)).
//pOut("PID output: " + ROUND(LND_PID:OUTPUT,2) + "m/s^2.").
  }
//pOut("ship_v_acc: " + ROUND(ship_v_acc,2) + "m/s^2.").

  LOCAL worst_p_ang IS 90.
  LOCAL acc_ratio IS ship_v_acc / LND_THRUST_ACC.
  IF ship_v_acc < 0 { SET worst_p_ang TO 0. SET ship_v_acc TO 0. }
  ELSE IF acc_ratio < 1 { SET worst_p_ang TO ARCSIN(acc_ratio). }
  LOCAL max_h_acc IS LND_THRUST_ACC * COS(worst_p_ang).
//pOut("max_h_acc: " + ROUND(max_h_acc,2) + "m/s^2.").
  LOCAL ship_h_acc IS v_xs2 / (2 * h_dist).
  IF h_dist < LND_ALLOWED_DIST AND VDOT(cur_h_v,des_h_v) > 0 { SET ship_h_acc TO 5 * cur_h_v:MAG. }
//pOut("ship_h_acc: " + ROUND(ship_h_acc,2) + "m/s^2.").
  LOCAL des_speed IS SQRT(h_dist * LND_THRUST_ACC) / 2.
  IF h_dist < 150 { SET des_speed TO (SQRT(h_dist) / 2). }

  IF NOT LND_OVERSHOOT AND VDOT(des_h_v, cur_h_v) < 0 {
    IF h_dist < LND_ALLOWED_DIST AND GROUNDSPEED >= LND_ALLOWED_DRIFT AND GROUNDSPEED < (2 * LND_ALLOWED_DRIFT) { 
      // passing point or moving away slowly, but close enough we may as well attempt to land
      SET LND_ALLOWED_DRIFT TO 2 * LND_ALLOWED_DRIFT.
      hudMsg("Bounce").
    } ELSE IF h_dist > LND_ALLOWED_DIST OR GROUNDSPEED >= (2 * LND_ALLOWED_DRIFT) {
      hudMsg("OVERSHOOT mode.").
      SET LND_OVERSHOOT TO TRUE.
    }
  } ELSE IF LND_OVERSHOOT AND VDOT(des_h_v:NORMALIZED, cur_h_v) > des_speed {
    hudMsg("Ending OVERSHOOT mode.").
    SET LND_OVERSHOOT TO FALSE.
    SET LND_ALLOWED_DRIFT TO LND_ALLOWED_DRIFT * 1.25.
    SET LND_ALLOWED_DIST TO LND_ALLOWED_DIST * 1.25.
  }

  LOCAL h_thrust_v IS V(0,0,0).
  IF LND_OVERSHOOT {
//pOut("des_speed: " + ROUND(des_speed,1) + "m/s.").
    SET h_thrust_v TO (des_speed * des_h_v:NORMALIZED) - cur_h_v.
    LOCAL des_h_acc IS MIN(max_h_acc, h_thrust_v:MAG * 5).
//pOut("des_h_acc: " + ROUND(des_h_acc,2) + "m/s^2.").
    LOCAL total_acc IS SQRT(ship_v_acc^2 + des_h_acc^2).
    LOCAL des_throttle IS MIN(1,total_acc / LND_THRUST_ACC).
    LOCAL des_pitch IS MIN(90,MAX(0,ARCCOS(des_h_acc/total_acc))).
    IF LND_THROTTLE > 0 { SET LND_THROTTLE TO des_throttle. }
    SET LND_PITCH TO des_pitch.
//pOut("Pitch (overshoot case): " + LND_PITCH).

  } ELSE {
    IF ABS(max_h_acc) < ABS(ship_h_acc) {
      IF LND_THROTTLE > 0 { SET LND_THROTTLE TO 1. }
      SET LND_PITCH TO worst_p_ang.
//pOut("Pitch (worst case): " + LND_PITCH).
    } ELSE {
      LOCAL total_acc IS SQRT(ship_v_acc^2 + ship_h_acc^2).
//pOut("total_acc: " + ROUND(total_acc,2) + "m/s^2.").
      LOCAL des_throttle IS MIN(1,total_acc / LND_THRUST_ACC).
      LOCAL des_pitch IS MIN(90,MAX(0,ARCCOS(ship_h_acc/total_acc))).
      IF LND_THROTTLE > 0 { SET LND_THROTTLE TO des_throttle. }
      SET LND_PITCH TO des_pitch.
//pOut("Pitch (normal): " + LND_PITCH).
    }

    // if we're going to pass close, stop worrying about any radial component and burn retrograde
    IF h_dist < LND_ALLOWED_DIST OR (h_dist * SIN(VANG(des_h_v,cur_h_v))) < LND_ALLOWED_DIST/2 {
      SET h_thrust_v TO -cur_h_v.
    } ELSE IF h_dist < (LND_ALLOWED_DIST * 1000) {
      SET h_thrust_v TO ((cur_h_v:MAG - ship_h_acc) * des_h_v:NORMALIZED) - cur_h_v.
    } ELSE {
      SET h_thrust_v TO ((cur_h_v:MAG * 0.9) * des_h_v:NORMALIZED) - cur_h_v.
    }
  }

  IF LND_PITCH < 90 AND h_thrust_v:MAG > 0 {
//    drawVector("hthv", V(0,0,0), 5 * h_thrust_v:NORMALIZED, "Horizontal thrust vector ", RGB(0.3,0.3,1)).
    SET final_vector TO ANGLEAXIS(LND_PITCH,VCRS(-h_thrust_v,BODY:POSITION)) * h_thrust_v.
  } ELSE { hideVector("hthv"). }

//  drawVector("face", V(0,0,0), 5 * FACING:VECTOR, "Current facing", RGB(0,1,0)).
//  drawVector("dfac", V(0,0,0), 5 * final_vector:NORMALIZED, "Desired facing", RGB(0,0,1)).

  IF LND_THROTTLE > 0 {
    LOCAL facing_dot IS VDOT(final_vector:NORMALIZED,FACING:VECTOR).
//pOut("Facing VDOT: " + ROUND(facing_dot,2)).
    IF facing_dot < 0.8 { SET LND_THROTTLE TO MAX(0.01, LND_THROTTLE * facing_dot). }

    // actual pitch
    LOCAL actual_pitch IS 90 - VANG(UP:VECTOR,FACING:VECTOR).
//pOut("actual_pitch: " + ROUND(actual_pitch,2) + " degrees.").
    IF h_dist < LND_ALLOWED_DIST * 3 AND actual_pitch < 90 {
      SET max_ang TO 1.
      // if close to the target site, use the throttle setting that gives us the 
      // horizontal acceleration we want
//pOut("Horizontal throttle override").
      LOCAL h_throttle IS MAX(0,MIN(1,(ship_h_acc / LND_THRUST_ACC) / COS(actual_pitch))).
      SET LND_THROTTLE TO h_throttle.
    }
    IF ship_v_acc > 0 AND adjustedAltitude() < (LND_SURF_G*10) {
      SET max_ang TO 45.
      IF actual_pitch > 20 {
        // if a higher throttle setting would maintain the v_acc we want, use it
        // this is to prevent catastrophic loss of altitude whilst manoeuvring
//pOut("Vertical throttle override").
        LOCAL min_throttle IS MIN(1,(ship_v_acc / LND_THRUST_ACC) / SIN(actual_pitch)).
        SET LND_THROTTLE TO MAX(min_throttle, LND_THROTTLE).
      }
    }
//pOut("Throttle: " + ROUND(LND_THROTTLE,2)).
//pOut("Estimated v_acc: " + ROUND(LND_THROTTLE*LND_THRUST_ACC*SIN(actual_pitch),2) + "m/s^2.").
//pOut("Estimated h_acc: " + ROUND(LND_THROTTLE*LND_THRUST_ACC*COS(actual_pitch),2) + "m/s^2.").
  } ELSE { SET max_ang TO 45. }

  IF LND_OVERSHOOT { SET max_ang TO MAX(max_ang,45). }
  ELSE IF VDOT(FACING:VECTOR,final_vector:NORMALIZED) < 0 { SET max_ang TO 60. }

  // restrict how far we try to move our facing at any one time
  LOCAL cv IS FACING:VECTOR.
  IF VANG(cv,final_vector) > max_ang {
    SET final_vector TO ANGLEAXIS(max_ang,VCRS(cv,final_vector)) * cv.
    IF VDOT(final_vector,UP:VECTOR) < 0 { SET final_vector TO ANGLEAXIS(max_ang,VCRS(cv,UP:VECTOR)) * cv. }
  }

  drawVector("steer", V(0,0,0), 10 * final_vector:NORMALIZED, "Steer vector", RGB(0,1,1)).

  RETURN final_vector.
}

FUNCTION switchBurnType
{
  hudMsg("Switching to non-precision landing.").
  steerSurf(FALSE).
  SET LND_THROTTLE TO 0.
  RETURN FALSE.
}

FUNCTION doConstantAltitudeBurn
{
  PARAMETER initial_abort.
  hudMsg("Preparing for precision landing burn.", YELLOW, 25).

  SET LND_THROTTLE TO 0.
  LOCK THROTTLE TO LND_THROTTLE.
  LOCAL spot IS LATLNG(LND_LAT,LND_LNG).

  LOCAL min_safety_factor IS MAX(50,(20 * LND_SURF_G)).

  hudMsg("Hit ABORT to switch to non-precision landing", YELLOW, 25).
  UNTIL diffTime("LND_BURN_TIME") > -1 OR LND_OVERSHOOT {
    IF ABORT <> initial_abort {
      hudMsg("ABORT OVERRIDE", RED, 40).
      RETURN switchBurnType().
    }
    WAIT 0.
  }
  pOut("Executing constant altitude burn.").
  landerResetTimer().
  LND_PID:RESET().
  SET LND_THROTTLE TO 1.
  findMinVSpeed2(LND_VS_LIMIT,30,0.5,min_safety_factor).
  SET LND_PID:SETPOINT TO LND_MIN_VS.
  LOCAL vs_limit IS LND_VS_LIMIT.
  LOCAL precision_dv IS 0.
  LOCAL LOCK h_dist TO VXCL(UP:VECTOR,spot:POSITION):MAG.
  UNTIL GROUNDSPEED < LND_ALLOWED_DRIFT AND h_dist < LND_ALLOWED_DIST {
    IF landerHeartbeat() > 0.5 {
      landerResetTimer().
      LOCAL land_acc IS LND_THRUST_ACC.

      IF LND_VS_LIMIT > 0 { SET vs_limit TO LND_VS_LIMIT. }
      ELSE IF LND_OVERSHOOT OR h_dist < 1000 { SET vs_limit TO 0. }
      ELSE IF h_dist < (LND_ALLOWED_DIST+1) * 1000 { SET vs_limit TO LND_VS_LIMIT * (h_dist-1000) / (LND_ALLOWED_DIST * 1000). }
      ELSE { SET vs_limit TO LND_VS_LIMIT. }
      LOCAL safety_factor IS min_safety_factor.

      LOCAL burn_time IS 20.
      LOCAL step IS 1.

      LOCAL cur_h_v IS VXCL(UP:VECTOR,VELOCITY:SURFACE).
      LOCAL acc_v IS VXCL(UP:VECTOR,FACING:VECTOR * land_acc * LND_THROTTLE).
      LOCAL acc_dot IS VDOT(cur_h_v:NORMALIZED, -acc_v).
      IF acc_dot > 0 { SET burn_time TO MIN(300,MAX(1,ROUND(cur_h_v:MAG / acc_dot))). }
      LOCAL mod_vs IS SHIP:VERTICALSPEED - (LND_SURF_G *0.5).
      IF mod_vs < 0 {
        LOCAL max_acc IS land_acc - LND_SURF_G.
        LOCAL min_burn_dist IS mod_vs^2 / (2 * max_acc).
        SET safety_factor TO MAX(min_burn_dist, safety_factor).
      }
      findMinVSpeed2(vs_limit,burn_time,step,safety_factor).
      SET LND_PID:SETPOINT TO LND_MIN_VS.
      SET LND_PID:MAXOUTPUT TO land_acc.
      SET LND_PID:MINOUTPUT TO -land_acc.

      LOCAL des_h_v IS VXCL(UP:VECTOR,LATLNG(LND_LAT,LND_LNG):POSITION).
      LOCAL correction_dv IS 2 * cur_h_v:MAG * SIN(VANG(des_h_v, cur_h_v)/2).
      LOCAL velocity_dv IS (VELOCITY:SURFACE:MAG * 1.1) + (LND_SURF_G * 15).
      SET precision_dv TO correction_dv + velocity_dv + land_acc.
      IF stageDV() < precision_dv {
        hudMsg("FUEL LOW", RED, 40).
        RETURN switchBurnType().
      }
    }

    IF ABORT <> initial_abort {
      hudMsg("ABORT OVERRIDE", RED, 40).
      RETURN switchBurnType().
    }

    WAIT 0.
  }
  steerSurf(FALSE).
  SET LND_THROTTLE TO 0.
  pOut("Groundspeed close to zero, near landing site; ending landing burn.").
  RETURN TRUE.
}

// cut-down versions of the old constant-altitude-burn code:
FUNCTION nonPrecisionConstantAltitudeVec
{
  RETURN ANGLEAXIS(landerPitch(),VCRS(VELOCITY:SURFACE,BODY:POSITION)) 
         * VXCL(UP:VECTOR,-VELOCITY:SURFACE).
}

FUNCTION doNonPrecisionConstantAltitudeBurn
{
  SET LND_THROTTLE TO 0.
  LOCK THROTTLE TO LND_THROTTLE.
  WAIT UNTIL steerOk(5,1).
  hudMsg("Executing non-precision landing burn.").
  landerResetTimer().
  SET LND_THROTTLE TO 1.
  LOCAL done IS FALSE.
  UNTIL done {
    IF landerHeartbeat() > 1 {
      landerResetTimer().
      findMinVSpeed(LND_VS_LIMIT,30,1).
    }

    IF GROUNDSPEED < LND_ALLOWED_DRIFT {
      SET done TO TRUE.
      pOut("Groundspeed close to zero; ending landing burn.").
      SET LND_THROTTLE TO 0.
    } ELSE IF GROUNDSPEED < (LND_THRUST_ACC-LND_SURF_G) {
      LOCAL v_acc IS LND_SURF_G + LND_MIN_VS - SHIP:VERTICALSPEED.
      SET LND_THROTTLE TO MIN(1,(v_acc + GROUNDSPEED) / LND_THRUST_ACC).
    }
  }

  SET LND_THROTTLE TO 0.
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
  PARAMETER imp_alt.
  LOCAL burn_throt IS 0.

  LOCAL max_acc IS LND_THRUST_ACC - LND_SURF_G.
  LOCAL cur_acc IS (LND_THRUST_ACC * LND_THROTTLE) - LND_SURF_G.

  LOCAL sv2 IS SHIP:VERTICALSPEED^2.
  LOCAL min_burn_dist IS sv2 / (2 * max_acc).
  LOCAL cur_burn_dist IS 99999.
  IF cur_acc > 0 { SET cur_burn_dist TO sv2 / (2 * cur_acc). }
  LOCAL ship_alt IS MIN(ALT:RADAR,ALTITUDE - imp_alt) - LND_RADAR_ADJUST.
  LOCAL dist_adjust IS -SHIP:VERTICALSPEED / 10.

  IF SHIP:VERTICALSPEED > 0 { SET burn_throt TO 0. }
  ELSE IF (min_burn_dist + dist_adjust) > ship_alt { SET burn_throt TO 1. }
  ELSE IF LND_THROTTLE > 0 AND LND_THRUST_ACC > 0 {
    LOCAL des_acc IS sv2 / (2 * (ship_alt - dist_adjust)).
    SET burn_throt TO MIN(1,(des_acc + gravAcc()) / LND_THRUST_ACC).
  }

  RETURN burn_throt.
}

FUNCTION doSuicideBurn
{
  hudMsg("Waiting to apply suicide burn.").
  LOCK THROTTLE TO LND_THROTTLE.

  LOCAL imp_alt IS calculateImpact().
  landerResetTimer().

  UNTIL adjustedAltitude() < LND_SET_DOWN[0] {
    IF landerHeartbeat() > 1 {
      landerResetTimer().
      SET imp_alt TO calculateImpact().
    }
    SET LND_THROTTLE TO suicideBurnThrot(imp_alt).
    WAIT 0.
  }
}

FUNCTION doSetDown
{
  hudMsg("Setting down.").
  LOCK THROTTLE TO LND_THROTTLE.
  PANELS OFF.

  LOCAL aim_speed IS LND_SET_DOWN[1].

  UNTIL adjustedAltitude() < 0.5 OR isLanded() {
    IF adjustedAltitude() < LND_SET_DOWN[2] AND aim_speed > LND_SET_DOWN[3] {
      SET aim_speed TO LND_SET_DOWN[3].
      steerTo({ RETURN UP:VECTOR. }).
    }

    LOCAL des_acc IS 5 * (-SHIP:VERTICALSPEED - aim_speed).
    LOCAL des_throt IS 1.
    IF LND_THRUST_ACC > 0 { SET des_throt TO (des_acc + gravAcc()) / LND_THRUST_ACC. }
    SET LND_THROTTLE TO MIN(1,MAX(0,des_throt)).
    WAIT 0.
  }

  pOut("Cutting throttle.").
  SET LND_THROTTLE TO 0.
  WAIT UNTIL isLanded().
  hudMsg("Touchdown.").
  pOut("Landed at LAT: " + ROUND(LATITUDE,2) + " LNG: " + ROUND(LONGITUDE,2)).
  LOCAL site_dist IS greatCircleDistance(BODY, SHIP:GEOPOSITION, LATLNG(LND_LAT,LND_LNG)).
  pOut("Distance from landing site: " + ROUND(site_dist) + "m.").
  drawVector("Site", V(0,0,0),LATLNG(LND_LAT,LND_LNG):POSITION,"Landing site aim point",RED).
  dampSteering().
  WAIT 10. PANELS ON.
  wipeVectors().
}

FUNCTION retrogradeVec
{
  IF SHIP:VERTICALSPEED < 0 { RETURN SRFRETROGRADE:VECTOR. }
  ELSE { RETURN UP:VECTOR. }
}

FUNCTION doLanding
{
  PARAMETER l_lat, l_lng.
  PARAMETER radar_adjust. // deprecated - has no effect
  PARAMETER pe_safety_factor, max_dist. // both m
  PARAMETER days_limit, exit_mode.
  PARAMETER max_slope IS 5. // degrees
  PARAMETER lander_radius IS 2.5. // metres
  PARAMETER vs_limit IS LND_VS_LIMIT. // m/s

  LOCAL LOCK rm TO runMode().

  IF rm < 201 OR rm > 249 { runMode(201). }

  initDescentValues(l_lat, l_lng, vs_limit).
  refineLandingSite(max_slope, lander_radius).

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
    //     - might now happen if the landing site is 'improved' to a point we don't overfly
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
    calcDescentBurnTime().
    warpToDescentBurn(-120).
    runMode(232).
  } ELSE IF rm = 232 {
    calcDescentBurnTime().
    warpToDescentBurn().
    runMode(233).
  } ELSE IF rm = 233 {
    steerTo(constantAltitudeVec@).
    LOCAL ok IS doConstantAltitudeBurn(ABORT).
    IF ok { runMode(235). } ELSE { runMode(234). }
  } ELSE IF rm = 234 {
    steerTo(nonPrecisionConstantAltitudeVec@).
    wipeVectors().
    doNonPrecisionConstantAltitudeBurn().
    runMode(235).
  } ELSE IF rm = 235 {
    steerTo(retrogradeVec@).
    wipeVectors().
    doSuicideBurn().
    runMode(236).
  } ELSE IF rm = 236 {
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