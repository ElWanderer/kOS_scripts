@LAZYGLOBAL OFF.

pOut("lib_lander_common.ks v1.1.0 20180201").

GLOBAL LND_THROTTLE IS 0.
GLOBAL LND_PITCH IS 0.
GLOBAL LND_MIN_VS IS 0.

setTime("LND").
GLOBAL landerHeartBeat IS diffTime@:BIND("LND").
GLOBAL landerResetTimer IS setTime@:BIND("LND").

FUNCTION landerSetMinVSpeed
{
  PARAMETER s.
  SET s TO ROUND(MIN(s,LND_MIN_VS+25),1).
  IF ABS(s - LND_MIN_VS) >= 0.5 {
    SET LND_MIN_VS TO s.
    pOut("LND_MIN_VS now: " + s + "m/s").
  }
}

FUNCTION landerMinVSpeed
{
  RETURN LND_MIN_VS.
}

FUNCTION gravAcc
{
  RETURN BODY:MU / (BODY:RADIUS+ALTITUDE)^2.
}

FUNCTION landerPitch
{
  LOCAL lp_throt IS LND_THROTTLE.
  IF lp_throt = 0 { SET lp_throt TO 1. }
  LOCAL p_ang IS 90.
  IF SHIP:AVAILABLETHRUST > 0 {
    LOCAL v_x2 IS VXCL(UP:VECTOR,VELOCITY:ORBIT):SQRMAGNITUDE.
    LOCAL cent_acc IS v_x2 / (BODY:RADIUS + ALTITUDE).
    LOCAL ship_acc IS gravAcc() - cent_acc + (LND_MIN_VS - SHIP:VERTICALSPEED).
    LOCAL acc_ratio IS ship_acc * lp_throt * MASS / SHIP:AVAILABLETHRUST.
    IF acc_ratio < 0 { SET p_ang TO 0. }
    ELSE IF acc_ratio < 1 { SET p_ang TO ARCSIN(acc_ratio). }
  }
  RETURN p_ang.
}

FUNCTION terrainAltAtTime
{
  PARAMETER u_time.
  LOCAL eta IS u_time - TIME:SECONDS.
  LOCAL spot IS BODY:GEOPOSITIONOF(POSITIONAT(SHIP,u_time)).
  LOCAL new_lng IS mAngle(spot:LNG - (eta * 360 / BODY:ROTATIONPERIOD)).
  RETURN LATLNG(spot:LAT,new_lng):TERRAINHEIGHT.
}

FUNCTION radarAltAtTime
{
  PARAMETER u_time.
  RETURN (posAt(SHIP,u_time):MAG - BODY:RADIUS) - terrainAltAtTime(u_time).
}

FUNCTION pathClearance
{
  PARAMETER start_time, end_time, step.

  LOCAL min_clearance IS 999999.

  LOCAL u_time IS start_time + step.
  UNTIL u_time > end_time {
    SET min_clearance TO MIN(radarAltAtTime(u_time), min_clearance).
    SET u_time TO u_time + step.
  }
pOut("Minimum clearance above terrain: " + ROUND(min_clearance) + "m.").
  RETURN min_clearance.
}

FUNCTION findMinVSpeed2
{
  PARAMETER init_min_vs, look_ahead, step, safety_factor.

  LOCAL min_vs IS init_min_vs.
  LOCAL start_time IS TIME:SECONDS.
  LOCAL end_time IS start_time + look_ahead.
  LOCAL u_time IS start_time + MAX(step,2).

  LOCAL cur_h_v IS VXCL(UP:VECTOR,VELOCITY:SURFACE).
  LOCAL acc_v IS VXCL(UP:VECTOR,FACING:VECTOR * LND_THRUST_ACC * LND_THROTTLE).
  LOCAL pos_v IS V(0,0,0).

//  LOCAL count IS 1.
LOCAL eta_count IS -1.

  UNTIL u_time > end_time {
    SET cur_h_v TO cur_h_v + (acc_v * step).
    SET pos_v TO pos_v + (cur_h_v * step).

    LOCAL eta IS u_time - TIME:SECONDS.
    IF eta > 0 {
      LOCAL spot IS BODY:GEOPOSITIONOF(pos_v).
      LOCAL new_lng IS mAngle(spot:LNG - (eta * 360 / BODY:ROTATIONPERIOD)).
      LOCAL th IS LATLNG(spot:LAT,new_lng):TERRAINHEIGHT.
      SET th TO th + safety_factor - (eta * LND_THRUST_ACC).
      LOCAL safe_vs IS (th - ALTITUDE) / eta.
//pOut("Step/Count: " + step + "/" + count).
//pOut("eta: " + ROUND(eta,1) + "s.").
//pOut("terrain height + safety allowance: " + ROUND(th) + "m.").
//pOut("our altitude: " + ROUND(ALTITUDE) + "m.").
//pOut("safe_vs: " + ROUND(safe_vs,1) + "m/s.").
IF safe_vs > min_vs { SET eta_count TO ROUND(eta). }
      SET min_vs TO MAX(min_vs, safe_vs).
    }

    SET u_time TO u_time + step.
//    SET count TO count + 1.

//    IF count > 10 {
//      SET step TO step * 2.
//      SET count TO 1.
//    }
  }

IF eta_count > 0 { pOut("LND_MIN_VS based on the terrainheight in " + eta_count + "s."). }

  landerSetMinVSpeed(min_vs).
}

FUNCTION stepTerrainVS
{
  PARAMETER init_min_vs, start_time, look_ahead, step.

  LOCAL min_vs IS init_min_vs.
  LOCAL s_count IS 1 / step.
  LOCAL p IS BODY:ROTATIONPERIOD.

  UNTIL s_count > (look_ahead / step) {
    LOCAL u_time IS start_time + (s_count * step).
    LOCAL time_ahead IS u_time - TIME:SECONDS.

    IF time_ahead > 0 {
      LOCAL terrain_alt IS terrainAltAtTime(u_time).
      LOCAL imp_vs IS (50 + terrain_alt - ALTITUDE) / time_ahead.
      SET min_vs TO MAX(min_vs, imp_vs+(2*gravAcc())).
    }

    SET s_count TO s_count + 1.
  }

  RETURN min_vs.
}

FUNCTION findMinVSpeed
{
  PARAMETER init_min_vs.
  PARAMETER look_ahead, step.
  LOCAL u_time IS TIME:SECONDS.
  LOCAL min_vs IS stepTerrainVS(init_min_vs,u_time,15,0.5).
  SET min_vs TO stepTerrainVS(min_vs,u_time,look_ahead,step).
  landerSetMinVSpeed(min_vs).
}

FUNCTION initLanderValues
{
  landerResetTimer().
  WAIT 0.
}