@LAZYGLOBAL OFF.

pOut("lib_lander_common.ks v1.0 20160714").

GLOBAL LND_THROTTLE IS 0.
GLOBAL LND_TIME IS 0.

GLOBAL LND_G_ACC IS 0.
GLOBAL LND_MIN_VS IS 0.

FUNCTION landerSetMinVSpeed
{
  PARAMETER s.
  IF s <> LND_MIN_VS {
    SET LND_MIN_VS TO s.
    pOut("LND_MIN_VS now: " + ROUND(s,1) + "m/s").
  }
}

FUNCTION landerMinVSpeed
{
  RETURN LND_MIN_VS.
}

FUNCTION gravAcc
{
  RETURN LND_G_ACC.
}

FUNCTION landerHeartbeat
{
  RETURN TIME:SECONDS - LND_TIME.
}

FUNCTION landerResetTimer
{
  SET LND_TIME TO TIME:SECONDS.
}

FUNCTION landerPitch
{
  LOCAL p_ang IS 90.
  IF SHIP:AVAILABLETHRUST > 0 {
    LOCAL v_x2 IS VXCL(UP:VECTOR,VELOCITY:ORBIT):SQRMAGNITUDE.
    LOCAL cent_acc IS v_x2 / (BODY:RADIUS + ALTITUDE).
    LOCAL ship_acc IS LND_G_ACC - cent_acc + (LND_MIN_VS - SHIP:VERTICALSPEED).
    LOCAL acc_ratio IS ship_acc * MASS / SHIP:AVAILABLETHRUST.
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
  LOCAL new_lng IS mAngle(spot:LNG + (eta * 360 / BODY:ROTATIONPERIOD)).
  RETURN LATLNG(spot:LAT,new_lng):TERRAINHEIGHT.
}

FUNCTION stepTerrainVS
{
  PARAMETER init_min_vs.
  PARAMETER start_time, look_ahead, step.

  LOCAL min_vs IS init_min_vs.
  LOCAL s_count IS 1 / step.
  LOCAL p IS BODY:ROTATIONPERIOD.

  UNTIL s_count > (look_ahead / step) {
    LOCAL u_time IS start_time + (s_count * step).
    LOCAL time_ahead IS u_time - TIME:SECONDS.

    IF time_ahead > 0 {
      LOCAL terrain_alt IS terrainAltAtTime(u_time).
      LOCAL imp_vs IS (50 + terrain_alt - ALTITUDE) / time_ahead.
      SET min_vs TO MAX(min_vs, imp_vs+(2*LND_G_ACC)).
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
  LOCK LND_G_ACC TO BODY:MU / (BODY:RADIUS+ALTITUDE)^2.
  landerResetTimer().
  WAIT 0.
}

FUNCTION stopLanderValues
{
  UNLOCK LND_G_ACC.
  WAIT 0.
}