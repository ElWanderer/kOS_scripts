@LAZYGLOBAL OFF.


pOut("lib_skeep.ks v1.0.1 20160728").

RUNONCEPATH(loadScript("lib_burn.ks")).

GLOBAL SKEEP_TIME IS TIME:SECONDS.
GLOBAL SKEEP_VESSELS IS LIST().

FUNCTION updateSkeepTime
{
  SET SKEEP_TIME TO TIME:SECONDS.
}

FUNCTION skeepTime
{
  RETURN TIME:SECONDS - SKEEP_TIME.
}

FUNCTION listNearbyVessels
{
  PARAMETER u_time.
  SKEEP_VESSELS:CLEAR.
  LOCAL all_vessels IS LIST().
  LIST TARGETS IN all_vessels.
  FOR craft IN all_vessels {
    IF ORBITAT(craft,u_time):BODY = ORBITAT(SHIP,u_time):BODY AND
       NOT LIST("LANDED","SPLASHED","PRELAUNCH"):CONTAINS(craft:STATUS) {
      IF (POSITIONAT(craft,u_time)-POSITIONAT(SHIP,u_time)):MAG < 2500 { SKEEP_VESSELS:ADD(craft). }
    }
  }
}

FUNCTION minSepAngle
{
  PARAMETER d.
  LOCAL min_ang IS 25.
  IF d <= 100 { SET min_ang TO 40. }
  ELSE IF d <= 500 { SET min_ang TO 30. }
  ELSE IF d <= 1500 { SET min_ang TO 15. }
  RETURN min_ang.
}

FUNCTION sepOK
{
  PARAMETER burn_vec, burn_dv.
  PARAMETER u_time.
  LOCAL ok IS TRUE.
  FOR craft IN SKEEP_VESSELS {
    LOCAL craft_pos IS POSITIONAT(craft,u_time)-POSITIONAT(SHIP,u_time).
    LOCAL v_vec IS VELOCITYAT(SHIP,u_time):ORBIT-VELOCITYAT(craft,u_time):ORBIT.
    LOCAL v_diff IS (burn_dv * burn_vec) + v_vec.
    IF VANG(craft_pos,v_diff) < minSepAngle(craft_pos:MAG) { SET ok TO FALSE. }
  }
  RETURN ok.
}

FUNCTION sepMan
{
  PARAMETER dv.
  PARAMETER man_secs.

  LOCAL ok IS TRUE.
  LOCAL done IS FALSE.
  LOCAL start_time IS TIME:SECONDS.
  LOCAL dv_r IS SQRT(2) * dv / 2.

  listNearbyVessels(start_time).
  UNTIL SKEEP_VESSELS:LENGTH = 0 OR done {
    IF TIME:SECONDS - start_time > SHIP:OBT:PERIOD {
      pOut("ERROR: did not achieve separation.").
      SET ok TO FALSE.
      BREAK.
    }

    LOCAL u_time IS TIME:SECONDS+man_secs.
    LOCAL pro_vec IS VELOCITYAT(SHIP,u_time):ORBIT:NORMALIZED.
    LOCAL norm_vec IS VCRS(pro_vec,-POSITIONAT(SHIP:BODY,u_time)):NORMALIZED.
    LOCAL node_ok IS TRUE.
    LOCAL n IS NODE(u_time, 0, 0, 0).
    IF sepOK(norm_vec,dv,u_time) { SET n:NORMAL TO dv. }
    ELSE IF sepOK(pro_vec+norm_vec,dv,u_time) {
      SET n:PROGRADE TO dv_r.
      SET n:NORMAL TO dv_r.
    } ELSE IF sepOK(pro_vec-norm_vec,dv,u_time) {
      SET n:PROGRADE TO dv_r.
      SET n:NORMAL TO -dv_r.
    } ELSE { SET node_ok TO FALSE. }

    IF node_ok {
      addNode(n).
      SET ok TO execNode(FALSE).
      SET done TO TRUE.
    }

    WAIT man_secs.
    listNearbyVessels(u_time).
  }

  RETURN ok.
}
