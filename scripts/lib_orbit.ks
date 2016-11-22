@LAZYGLOBAL OFF.
pOut("lib_orbit.ks v1.0.3 20161108").

RUNONCEPATH(loadScript("lib_node.ks")).

FUNCTION calcTa
{
  PARAMETER a, e, r.
  LOCAL inv IS ((a * (1 - e^2)) - r)/ (e * r).
  IF ABS(inv) > 1 {
    hudMsg("ERROR: Invalid ARCCOS() in calcTa(). Rebooting in 5s.").
    WAIT 5. REBOOT.
  }
  RETURN ARCCOS( inv ).
}

FUNCTION velAt
{
  PARAMETER c, u_time.
  RETURN VELOCITYAT(c,u_time):ORBIT.
}

FUNCTION posAt
{
  PARAMETER c, u_time.
  LOCAL b IS ORBITAT(c,u_time):BODY.
  LOCAL p IS POSITIONAT(c, u_time).
  IF b <> BODY { SET p TO p - POSITIONAT(b,u_time). }
  ELSE { SET p TO p - BODY:POSITION. }
  RETURN p.
}

FUNCTION taAt
{
  PARAMETER c, u_time.
  LOCAL o IS ORBITAT(c,u_time).
  LOCAL r IS posAt(c,u_time):MAG.
  LOCAL c_ta IS calcTa(o:SEMIMAJORAXIS,o:ECCENTRICITY,r).
  IF posAt(c,u_time+1):MAG < r { SET c_ta TO 360 - c_ta. }
  RETURN c_ta.
}

FUNCTION maFromTA
{
  PARAMETER ta, e.
  LOCAL ma IS 0.
  IF e < 1 {
    LOCAL ea IS ARCCOS( (e + COS(ta)) / (1 + (e * COS(ta))) ).
    IF ta > 180 { SET ea TO 360 - ea. }
    SET ma TO (CONSTANT:DEGTORAD * ea) - (e * SIN(ea)).
  } ELSE IF e > 1 {
    LOCAL x IS (e+COS(ta)) / (1 + (e * COS(ta))).
    LOCAL F IS LN(x + SQRT(x^2 - 1)).
    LOCAL sinhF IS (CONSTANT:E^F - CONSTANT:E^(-F)) / 2.
    SET ma TO ((e * sinhF) - F).
    IF ta > 180 { SET ma TO -ma. }
  }
  RETURN ma.
}

FUNCTION secondsToTA
{
  PARAMETER c, u_time, t_ta.

  LOCAL o IS ORBITAT(c,u_time).
  LOCAL a IS o:SEMIMAJORAXIS.
  LOCAL e IS o:ECCENTRICITY.
  LOCAL s_ta IS taAt(c,u_time).

  LOCAL secs IS SQRT(ABS(a^3) / o:BODY:MU) * (maFromTA(t_ta,e) - maFromTA(s_ta,e)).
  IF e < 1 AND secs < 0 { SET secs TO o:PERIOD + secs. }
  RETURN secs.
}

FUNCTION radiusAtTA
{
  PARAMETER o, ta.
  LOCAL a IS o:SEMIMAJORAXIS.
  LOCAL e IS o:ECCENTRICITY.
  RETURN (a * (1 - e^2))/ (1 + (e * COS(ta))).
}

FUNCTION nodeAlterOrbit
{
  PARAMETER u_time, opp_alt.

  LOCAL b IS ORBITAT(SHIP,u_time):BODY.
  LOCAL p IS posAt(SHIP,u_time).
  LOCAL v IS velAt(SHIP,u_time).
  LOCAL f_ang IS 90 - VANG(v,p).

  LOCAL r IS p:MAG.
  LOCAL a1 IS (r + opp_alt + b:RADIUS) / 2.

  LOCAL v1 IS SQRT(b:MU * ((2/r)-(1/a1))).
  LOCAL pro IS (v1 * COS(f_ang)) - v:MAG.
  LOCAL rad IS -v1 * SIN(f_ang).
  LOCAL n IS NODE(u_time, rad, 0, pro).
  RETURN n.
}
