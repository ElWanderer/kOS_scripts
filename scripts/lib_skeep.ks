@LAZYGLOBAL OFF.
pOut("lib_skeep.ks v1.1.1 20170106").

FOR f IN LIST(
  "lib_orbit.ks",
  "lib_burn.ks"
) { RUNONCEPATH(loadScript(f)). }

GLOBAL SKEEP_VESSELS IS LIST().
GLOBAL SKEEP_FACTOR IS 1.

FUNCTION listNearbyVessels
{
  PARAMETER u_time.
  SKEEP_VESSELS:CLEAR.
  LOCAL all_vessels IS LIST().
  LIST TARGETS IN all_vessels.
  FOR c IN all_vessels {
    IF ORBITAT(c,u_time):BODY = ORBITAT(SHIP,u_time):BODY AND
       NOT LIST("LANDED","SPLASHED","PRELAUNCH"):CONTAINS(c:STATUS) AND
       (posAt(c,u_time)-posAt(SHIP,u_time)):MAG < 2500 { SKEEP_VESSELS:ADD(c). }
  }
  RETURN SKEEP_VESSELS:LENGTH.
}

FUNCTION sepTime
{
  LOCAL start_time IS TIME:SECONDS + 1.
  LOCAL u_time IS start_time.
  UNTIL listNearbyVessels(u_time) = 0 {
    SET u_time TO u_time + 60.
    IF OBT:ECCENTRICITY > 1 { IF u_time - TIME:SECONDS > ETA:TRANSITION { RETURN 0. } }
    ELSE IF u_time - start_time > OBT:PERIOD { RETURN 0. }
  }
  RETURN u_time.
}

FUNCTION minSepAngle
{
  PARAMETER d.
  IF d <= 100 { RETURN 45. }
  ELSE IF d <= 500 { RETURN 30. }
  RETURN 15.
}

FUNCTION sepBurnOK
{
  PARAMETER burn_vec, burn_dv, u_time.
  FOR c IN SKEEP_VESSELS {
    LOCAL c_pos IS posAt(c,u_time)-posAt(SHIP,u_time).
    LOCAL v_vec IS velAt(SHIP,u_time)-velAt(c,u_time).
    LOCAL v_diff IS (burn_dv * burn_vec) + v_vec.
    IF VANG(c_pos,v_diff) < minSepAngle(c_pos:MAG) { RETURN FALSE. }
  }
  RETURN TRUE.
}

FUNCTION sepBurn
{
  LOCAL u_time IS bufferTime().
  listNearbyVessels(u_time).

  LOCAL s_vel IS velAt(SHIP,u_time).
  LOCAL dv IS SKEEP_FACTOR * SQRT(s_vel:MAG) / 5.
  LOCAL dv_r IS SQRT(2) * dv / 2.
  LOCAL pro_vec IS s_vel:NORMALIZED.
  LOCAL norm_vec IS VCRS(s_vel,posAt(SHIP,u_time)):NORMALIZED.
  LOCAL n IS NODE(u_time, 0, 0, 0).

  IF sepBurnOK(norm_vec,dv,u_time) {
    SET n:NORMAL TO dv.
  } ELSE IF sepBurnOK(pro_vec+norm_vec,dv,u_time) {
    SET n:PROGRADE TO dv_r.
    SET n:NORMAL TO dv_r.
  } ELSE IF sepBurnOK(pro_vec-norm_vec,dv,u_time) {
    SET n:PROGRADE TO dv_r.
    SET n:NORMAL TO -dv_r.
  }

  IF nodeDV(n) > dv_r {
    addNode(n).
    RETURN execNode(FALSE).
  }

  pOut("Could not plot separation burn.").
  RETURN FALSE.
}

FUNCTION doSeparation
{
  LOCAL ok IS TRUE.
  LOCAL sep_time IS sepTime().
  IF sep_time = 0 {
    SET ok TO sepBurn().
    IF ok { SET sep_time TO sepTime(). }
  }
  IF sep_time > 0 AND ok { doWarp(sep_time). RETURN ok. }
  pOut("ERROR: did not achieve separation.").
  RETURN FALSE.
}
