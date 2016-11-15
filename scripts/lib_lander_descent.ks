@LAZYGLOBAL OFF.

pOut("lib_lander_descent.ks v1.1.2 20161115").

FOR f IN LIST(
  "lib_steer.ks",
  "lib_burn.ks",
  "lib_runmode.ks",
  "lib_orbit.ks",
  "lib_geo.ks",
  "lib_lander_common.ks",
  "lib_lander_geo.ks"
) { RUNONCEPATH(loadScript(f)). }

GLOBAL LND_THRUST_ACC IS 0.
GLOBAL LND_RADAR_ADJUST IS 0.

FUNCTION initDescentValues
{
  PARAMETER adjust IS 0.

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

  LOCAL new_pe IS findHighestPointNear(lat,lng) + safety_factor.
  IF PERIAPSIS < new_pe {
    LOCK THROTTLE TO LND_THROTTLE.
    SET LND_THROTTLE TO 0.1.
    WAIT UNTIL PERIAPSIS >= new_pe.
    SET LND_THROTTLE TO 0.
    WAIT 2.
  }

  steerOff().
}

FUNCTION warpToPeriapsis
{
  PARAMETER safety_factor. // m
  LOCAL warp_time IS TIME:SECONDS + ETA:PERIAPSIS - 30.
  IF warp_time - TIME:SECONDS > 5 {
    pOut("Warping until close to periapsis.").
    doWarp(warp_time, { RETURN ALT:RADAR < (safety_factor / 2). }).
  }
}

FUNCTION constantAltitudeVec
{
  RETURN ANGLEAXIS(landerPitch(),VCRS(VELOCITY:SURFACE,BODY:POSITION)) 
         * VXCL(UP:VECTOR,-VELOCITY:SURFACE).
}

FUNCTION doConstantAltitudeBurn
{
  PARAMETER safety_factor. // m
  pOut("Preparing for constant altitude burn.").
  SET LND_THROTTLE TO 0.
  LOCK THROTTLE TO LND_THROTTLE.

  LOCAL done IS FALSE.
  UNTIL done {
    WAIT 1.
    findMinVSpeed(-50,24,4).
    IF VERTICALSPEED < landerMinVSpeed() {
      pOut("Terrain proximity.").
      SET done TO TRUE.
    } ELSE IF ETA:PERIAPSIS < 10 OR ABS(VERTICALSPEED) < 0.5 {
      pOut("Approaching periapsis.").
      SET done TO TRUE.
    }
  }

  WAIT UNTIL steerOk(5,1).
  pOut("Executing constant altitude burn.").
  landerResetTimer().
  SET LND_THROTTLE TO 1.
  SET done TO FALSE.
  UNTIL done {
    IF landerHeartbeat() > 1 {
      landerResetTimer().
      findMinVSpeed(-50,90,3).
    }

    IF GROUNDSPEED < 4 {
      SET done TO TRUE.
      pOut("Groundspeed close to zero; ending constant altitude burn.").
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
    LOCAL ship_alt IS posAt(SHIP,u_time):MAG - BODY:RADIUS.
    LOCAL terrain_alt IS terrainAltAtTime(u_time).

    IF ship_alt < (terrain_alt + 5) {
      IF step > 1 { RETURN stepTerrainImpact(u_time - step, step * 2, 1). }
      ELSE IF step = 1 { RETURN stepTerrainImpact(u_time-1, 2, 0.1). }
      ELSE { RETURN terrain_alt. }
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

  UNTIL adjustedAltitude() < 25 {
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

  // aim for 5m/s until below 12m, then aim for 2m/s
  LOCAL aim_speed IS 5.

  UNTIL adjustedAltitude() < 1 {
    IF adjustedAltitude() < 12 AND aim_speed > 2 {
      SET aim_speed TO 2.
      steerTo({ RETURN UP:VECTOR. }).
    }

    LOCAL des_acc IS -SHIP:VERTICALSPEED - aim_speed.
    LOCAL des_throt IS (des_acc + gravAcc()) / LND_THRUST_ACC.
    SET LND_THROTTLE TO MIN(1,MAX(0,des_throt)).
    WAIT 0.
  }

  pOut("Cutting throttle.").
  SET LND_THROTTLE TO 0.
  WAIT UNTIL LIST("LANDED","SPLASHED"):CONTAINS(STATUS).
  hudMsg("Touchdown.").
  pOut("Landed at LAT: " + ROUND(LATITUDE,2) + " LNG: " + ROUND(LONGITUDE,2)).
  PANELS ON.
  dampSteering().
}

FUNCTION doLanding
{
  PARAMETER l_lat, l_lng.
  PARAMETER radar_adjust. // metres between the root part and bottom of landing gear
  PARAMETER pe_safety_factor, max_dist. // both m
  PARAMETER days_limit.
  PARAMETER exit_mode.

  LOCAL LOCK rm TO runMode().

  IF rm < 201 OR rm > 249 { runMode(201). }
  initDescentValues(radar_adjust).

UNTIL rm = exit_mode
{
  IF rm = 201 {
    pOut("Beginning landing program.").
    runMode(202).
  } ELSE IF rm = 202 {
    cycleLandingGear().
    runMode(211).

  } ELSE IF rm = 211 {
    IF nodeGeoPhasingOrbit(SHIP, l_lat, l_lng, days_limit) { runMode(215). }
    ELSE { runMode(212). }

  } ELSE IF rm = 212 {
    // TBD - phasing hasn't worked so plot a direct intercept?
    runMode(221).

  } ELSE IF rm = 215 {
    IF NOT HASNODE { runMode(211). }
    ELSE IF execNode(TRUE) { runMode(221). }

  } ELSE IF rm = 221 {
    IF addNodeLowerPeriapsisOverSpot(l_lat,l_lng,pe_safety_factor,max_dist,days_limit) { runMode(222). }
    ELSE {
      runMode(229,221).
      pOut("Going into standby mode.").
      steerSun().
    }
  } ELSE IF rm = 222 {
    IF NOT HASNODE { runMode(221). }
    ELSE IF execNode(TRUE) { runMode(223). }
  } ELSE IF rm = 223 {
    checkPeriapsis(l_lat,l_lng,pe_safety_factor).
    runMode(231).
  } ELSE IF rm = 229 {
    // wait

  } ELSE IF rm = 231 {
    warpToPeriapsis(pe_safety_factor).
    runMode(232).
  } ELSE IF rm = 232 {
    steerTo(constantAltitudeVec@).
    doConstantAltitudeBurn(pe_safety_factor).
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
