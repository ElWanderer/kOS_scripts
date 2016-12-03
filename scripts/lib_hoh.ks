@LAZYGLOBAL OFF.
pOut("lib_hoh.ks v1.0.1 20161130").

RUNONCEPATH(loadScript("lib_orbit.ks")).

FUNCTION nodeHohmann
{
  PARAMETER t, u_time, t_pe IS 0.

  LOCAL o1 IS ORBITAT(SHIP,u_time).
  LOCAL o2 IS ORBITAT(t,u_time).
  LOCAL b IS o1:BODY.
  LOCAL r1 IS o1:SEMIMAJORAXIS.
  LOCAL r2 IS o2:SEMIMAJORAXIS + t_pe.

  LOCAL dv IS SQRT(b:MU/r1) * (SQRT((2*r2)/(r1+r2)) -1).
  IF r2 < r1 { SET dv TO -dv. }

  LOCAL transfer_t IS CONSTANT:PI * SQRT( ((r1+r2)^3) / (8 * b:MU) ).
  LOCAL desired_phi IS 180 - (transfer_t * 360 / o2:PERIOD).

  LOCAL rel_angv IS (360 / o1:PERIOD) - (360 / o2:PERIOD).

  LOCAL s_pos IS posAt(SHIP, u_time).
  LOCAL t_pos IS posAt(t, u_time).
  LOCAL s_normal IS VCRS(velAt(SHIP,u_time),s_pos).
  LOCAL s_t_cross IS VCRS(s_pos,t_pos).

  LOCAL start_phi IS VANG(s_pos,t_pos).
  IF VDOT(s_normal, s_t_cross) > 0 { SET start_phi TO 360 - start_phi. }

  LOCAL phi_delta IS mAngle(start_phi - desired_phi).
  IF rel_angv < 0 { SET phi_delta TO phi_delta - 360. }

  LOCAL hnode IS NODE(u_time + (phi_delta / rel_angv), 0, 0, dv).

  ADD hnode. WAIT 0.
  UNTIL NOT hnode:ORBIT:HASNEXTPATCH OR ETA:TRANSITION > hnode:ETA + transfer_t 
        OR hnode:ORBIT:NEXTPATCH:BODY:NAME = t:NAME {
    SET hnode:ETA TO hnode:ETA + ABS(360/rel_angv).
    WAIT 0.
  }
  REMOVE hnode. WAIT 0.

  RETURN hnode.
}
