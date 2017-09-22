@LAZYGLOBAL OFF.
pOut("lib_orbit.ks v1.1.0 20170922").

RUNONCEPATH(loadScript("lib_node.ks")).

FUNCTION calcTa
{
  PARAMETER a, e, r.
  LOCAL inv IS ((a * (1 - e^2)) - r) / (e * r).
  IF ABS(inv) > 1 {
    hudMsg("ERROR: Invalid ARCCOS() in calcTa(). Rebooting in 5s.").
    pOut("a: " + ROUND(a) + "m.").
    pOut("e: " + ROUND(e,5) + ".").
    pOut("r: " + ROUND(r) + "m.").
    WAIT 5. REBOOT.
  }
  RETURN ARCCOS( inv ).
}

FUNCTION velAt
{
  PARAMETER c, u_time.
  RETURN VELOCITYAT(c,u_time):ORBIT.
}

FUNCTION radiusAt
{
  PARAMETER c, u_time.
  LOCAL o IS ORBITAT(c,u_time).
  RETURN 2 / ((velAt(c,u_time):SQRMAGNITUDE / o:BODY:MU) + (1/o:SEMIMAJORAXIS)).
}

// test functions
// 1  - Sun
// 2  - Planet
// 3  - Moon
// 4+ - none of the above (should not be possible in stock solar system)
FUNCTION bodyLevel
{
  PARAMETER b.
  IF b:HASBODY { RETURN 1 + bodyLevel(b:BODY). }
  RETURN 1.
}

// What relation is b2 to b1?
// These numbers should match the numbers used in Github issue #122
// 1  - same body
// 2  - b2 is child of b1
// 3  - b2 is parent of b1
// 4  - b2 is grandchild of b1 (implies b1 is the sun, b2 is a moon)
// 5  - b2 is grandparent of b1 (implies b2 is the sun, b1 is a moon)
// 6  - b2 and b1 are children of a common parent (which is not the sun, b1 and b2 are moons)
// 7  - b2 and b1 are children of a common parent (which is the sun, b1 and b2 are planets)
// 8  - b2 and b1 are not children of a common parent, but share a common grandparent (which is the sun, b1 and b2 are moons)
// 9  - b1's grandparent (i.e. the sun) is b2's parent, but b2 is not b1's parent (b1 is a moon, b2 is an unrelated planet)
// 10 - b2's grandparent (i.e. the sun) is b1's parent, but b1 is not b2's parent (b2 is a moon, b1 is an unrelated planet)
// 11 - none of the above (should not be possible in the stock system)
FUNCTION bodyRelationship
{
  PARAMETER b1, b2.
  IF b1 = b2 { RETURN 1. }
  LOCAL h1 IS bodyLevel(b1).
  LOCAL h2 IS bodyLevel(b2).
  IF h2 > h1 AND b2:BODY = b1 { RETURN 2. }
  IF h1 > h2 AND b1:BODY = b2 { RETURN 3. }
  IF h1 = 1 AND h2 = 3 { RETURN 4. }
  IF h2 = 1 AND h1 = 3 { RETURN 5. }
  IF h1 > 1 AND h2 > 1 {
    IF b1:BODY = b2:BODY { IF h1 = 2 { RETURN 6. } ELSE { RETURN 7. } }
    IF h1 = 3 AND h2 = 3 { RETURN 8. }
    IF h1 = 3 AND h2 = 2 { RETURN 9. }
    IF h1 = 2 AND h2 = 3 { RETURN 10. }
  }
  RETURN 11.
}
// end of test functions

FUNCTION posAt
{
  PARAMETER c, u_time.
  LOCAL b IS ORBITAT(c,u_time):BODY.
  LOCAL p IS POSITIONAT(c, u_time).
  LOCAL b_p IS POSITIONAT(b,u_time).
  
  LOCAL relationship = bodyRelationship(BODY, b).
// test line
  pOut("Relationship type: " + relationship + ".").
// end of test line

// testing style, if test lines removed, this will need changing back to something along the lines of
// IF b:HASBODY AND (b:BODY = BODY OR (b:BODY:HASBODY and b:BODY:BODY = BODY)) { SET p TO p - b_p. }
  IF LIST(2,4):CONTAINS(relationship) { SET p TO p - b_p. }
// end of testing style
  ELSE { SET p TO p - b:POSITION. }

// test lines
  LOCAL r1 IS p:MAG.
  LOCAL r2 IS radiusAt(c,u_time).
  pOut("-----------------------------------------------------").
  pOut("posAt() called, comparing return value to radiusAt().").
  pOut("posAt() returns a vector with magnitude: " + ROUND(r1) + "m.").
  pOut("radiusAt() returns a magnitude of:       " + ROUND(r2) + "m.").
  LOCAL diff IS 100 * (ABS(r1 - r2) / r1).
  pOut("Difference: " + ROUND(diff,2) + "%.").
  pOut("Current body: " + BODY:NAME + ".").
  pOut("Future body: " + b:NAME + ".").
  pOut("-----------------------------------------------------").
// end of test lines

  RETURN p.
}

FUNCTION taAt
{
  PARAMETER c, u_time.
  LOCAL o IS ORBITAT(c,u_time).
  
  // test line, result not used:
  LOCAL r1 IS posAt(c,u_time):MAG.
  
  LOCAL r IS radiusAt(c,u_time).
  LOCAL c_ta IS calcTa(o:SEMIMAJORAXIS,o:ECCENTRICITY,r).
  IF radiusAt(c,u_time+1) < r { SET c_ta TO 360 - c_ta. }
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

FUNCTION firstTAAtRadius
{
  PARAMETER o, r.
  LOCAL e IS o:ECCENTRICITY.
  IF e > 0 AND e <> 1 AND r > 0 { RETURN calcTa(o:SEMIMAJORAXIS,e,r). }
  ELSE { RETURN -1. }
}

FUNCTION secondTAAtRadius
{
  PARAMETER o, r.
  LOCAL ta2 IS -1.
  LOCAL ta1 IS firstTAAtRadius(o,r).
  IF ta1 >= 0 { SET ta2 TO 360 - ta1. }
  RETURN ta2.
}

FUNCTION secondsToAlt
{
  PARAMETER craft, u_time, t_alt, ascending.

  LOCAL secs IS -1.
  LOCAL o IS ORBITAT(craft,u_time).
  LOCAL e IS o:ECCENTRICITY.
  LOCAL t_ta IS -1.
  IF t_alt > o:PERIAPSIS AND (t_alt < o:APOAPSIS OR e > 1) {
    IF ascending { SET t_ta TO firstTAAtRadius(o,o:BODY:RADIUS + t_alt). }
    ELSE { SET t_ta TO secondTAAtRadius(o,o:BODY:RADIUS + t_alt). }
    SET secs TO secondsToTA(craft,u_time,t_ta).
  }
  RETURN secs.
}
