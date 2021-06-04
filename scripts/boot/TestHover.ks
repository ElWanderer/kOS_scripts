@LAZYGLOBAL OFF.

// based on Kevin Gisi's episode 43 hover test

IF NOT EXISTS("1:/init.ks") { RUNPATH("0:/init_select.ks"). }
RUNONCEPATH("1:/init.ks").

pOut("TestHover.ks v1.0.0 20180112").

FOR f IN LIST(
  "lib_steer.ks",
  "lib_draw.ks"
) { RUNONCEPATH(loadScript(f)). }

RCS OFF.
LOCK THROTTLE TO 0.
SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.

LOCK g_local TO BODY:MU / ((ALTITUDE + BODY:RADIUS)^2).

GLOBAL LND_LAT IS SHIP:LATITUDE + 0.1.
GLOBAL LND_LNG IS SHIP:LONGITUDE.
GLOBAL spot IS LATLNG(LND_LAT, LND_LNG).
LOCK h_v TO VXCL(UP:VECTOR,spot:ALTITUDEPOSITION(ALTITUDE)).
LOCK h_dist TO h_v:MAG.

LOCK des_v TO MAX(0,MIN(100,MIN(GROUNDSPEED+2,h_dist / 5))) * h_v:NORMALIZED.

// these values may only be good for Kevin's craft!
GLOBAL my_pid is PIDLOOP(2.7, 4.4, 0.12, 0, 0).
//GLOBAL my_pid is PIDLOOP(1.25, 0.25, 0.125, 0, 0).
//GLOBAL my_pid is PIDLOOP(1, 0, 5, 0, 0).

FUNCTION hoverVec
{
  RETURN (UP:VECTOR * g_local) - VELOCITY:SURFACE.
}
FUNCTION translateVec
{
  RETURN (UP:VECTOR * g_local) + (UP:VECTOR * my_pid:SETPOINT) + des_v - VELOCITY:SURFACE.
}
LOCK STEERING TO LOOKDIRUP(hoverVec(), FACING:TOPVECTOR).

pOut("Waiting 2 seconds").
WAIT 2.
STAGE.
pOut("Ignition").

GLOBAL target_twr is 0.
LOCK maxtwr TO MAX(1, SHIP:AVAILABLETHRUST / (g_local * MASS)).
LOCK THROTTLE TO MIN(target_twr / maxtwr, 1).
SET my_pid:MAXOUTPUT TO maxtwr.

GLOBAL step IS 0. // asent

SET my_pid:SETPOINT to 5. // ascend at 5m/s
until FALSE {

  IF RCS {
    RCS OFF.
    SET LND_LNG TO LND_LNG-0.001.
    SET spot TO LATLNG(LND_LAT, LND_LNG).
  }

  IF step = 0 AND ALT:RADAR > 50 AND h_dist > 5 {
    pOut("Beginning hover.").
    SET my_pid:SETPOINT TO 0.
    SET step TO 1.
  } ELSE IF step = 1 AND ABS(VERTICALSPEED < 0.5) {
    pOut("Beginning translation.").
    LOCK STEERING TO LOOKDIRUP(translateVec(), FACING:TOPVECTOR).
    SET step TO 2.
  } ELSE IF step = 2 AND h_dist < 2.5 AND GROUNDSPEED < 0.5 {
    pOut("Beginning descent at 5m/s.").
    SET my_pid:SETPOINT TO -5.
    SET step TO 3.
  } ELSE IF step = 3 AND ALT:RADAR < 12 {
    pOut("Slowing descent to 1m/s.").
    SET my_pid:SETPOINT TO -1.
    SET step TO 4.
  } ELSE IF step = 4 AND ALT:RADAR < 3 {
    pOut("Touching down.").
    UNLOCK THROTTLE.
    UNLOCK STEERING.
    hideVector("DesV").
    hideVector("Steer").
    SET step TO 5.
  }

  IF step = 2 {
    SET my_pid:SETPOINT TO (50 - ALT:RADAR) / 2. // try to maintain altitude
  }
  SET my_pid:MAXOUTPUT TO maxtwr.
  SET target_twr TO my_pid:UPDATE(TIME:SECONDS, VERTICALSPEED) / COS(VANG(UP:VECTOR, FACING:VECTOR)).

  drawVector("Site", V(0,0,0),spot:POSITION,"Landing site aim point",RED).

  IF step > 1 AND step < 5 {
    drawVector("DesV", V(0,0,0),des_v,"Desired Velocity " + ROUND(des_v:MAG,1) + "m/s",GREEN).
    drawVector("Steer", V(0,0,0),translateVec(),"Steer",BLUE).
  }

  WAIT 0.
}