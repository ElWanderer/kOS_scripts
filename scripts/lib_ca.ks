@LAZYGLOBAL OFF.
pOut("lib_ca.ks v1.0.0 20170607").

FUNCTION targetDist
{
  PARAMETER t, u_time.
  RETURN (POSITIONAT(SHIP,u_time)-POSITIONAT(t,u_time)):MAG.
}

FUNCTION targetCA
{
  PARAMETER t, u_time1, u_time2, min_step IS 1, num_slices IS 20.
  LOCAL time_diff IS u_time2 - u_time1.
  LOCAL step IS time_diff / num_slices.
  IF step < min_step { RETURN ((u_time1 + u_time2) / 2). }

  LOCAL ca_time IS u_time1.
  LOCAL ca_dist IS targetDist(t,ca_time).

  LOCAL temp_time IS u_time1 + step.
  UNTIL temp_time > u_time2 {
    LOCAL temp_dist IS targetDist(t,temp_time).
    IF temp_dist < ca_dist {
      SET ca_dist TO temp_dist.
      SET ca_time TO temp_time.
    }
    SET temp_time TO temp_time + step.
  }
  SET u_time1 TO MAX(u_time1, ca_time-step).
  SET u_time2 TO MIN(u_time2, ca_time+step).
  RETURN targetCA(t, u_time1, u_time2, min_step, num_slices).
}
