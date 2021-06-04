@LAZYGLOBAL OFF.

// based on Kevin Gisi's episode 43 hover test

IF NOT EXISTS("1:/init.ks") { RUNPATH("0:/init_select.ks"). }
RUNONCEPATH("1:/init.ks").

pOut("TestHover.ks v1.0.0 20180112").

FOR f IN LIST(
  "lib_steer.ks",
  "lib_draw.ks"
) { RUNONCEPATH(loadScript(f)). }

GLOBAL LND_LEG_LEX IS LEXICON(
  "LT-2 Landing Strut", 1.7,
  "LT-1 Landing Struts", 1.6,
  "LT-05 Micro Landing Strut", 0.95).

FUNCTION calcRadarAltAdjust
{
  LOCAL rh IS 0.
  LOCAL pl IS LIST().
  LIST PARTS IN pl.
  FOR p IN pl {
    LOCAL p_pos IS p:POSITION - SHIP:ROOTPART:POSITION.
    LOCAL ph IS VDOT(-FACING:VECTOR,p_pos).
    IF LND_LEG_LEX:HASKEY(p:TITLE) { 
      SET ph TO ph + LND_LEG_LEX[p:TITLE].
    } ELSE IF p:TITLE:CONTAINS("Strut") OR p:TITLE:CONTAINS("Land") OR p:TITLE:CONTAINS("Gear") {
      SET ph TO ph + 1.5.
    }
    SET rh TO MAX(ph, rh).
  }
  RETURN rh.
}

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

// these values may only be good for Kevin's craft! PIDLOOP(2.7, 4.4, 0.12, 0, 0).

// revision a
//GLOBAL alt_vel_pid IS PIDLOOP(2,0.05,0.05,-50,50).
//GLOBAL vel_throt_pid IS PIDLOOP(1,0.1,0.1,0,1).

// revision b
//GLOBAL alt_vel_pid IS PIDLOOP(2,0.05,0.05,-50,50).
//GLOBAL vel_throt_pid IS PIDLOOP(1,0.25,0.25,0,1).

// revision c
GLOBAL alt_vel_pid IS PIDLOOP(3,0.1,0.1,-50,50).
GLOBAL vel_throt_pid IS PIDLOOP(1,0.25,0.25,0,1).


FUNCTION hoverVec
{
  RETURN (UP:VECTOR * alt_vel_pid:MAXOUTPUT) - VXCL(UP:VECTOR,VELOCITY:SURFACE).
}
FUNCTION translateVec
{
  //RETURN (UP:VECTOR * g_local) + (UP:VECTOR * my_pid:SETPOINT) + des_v - VELOCITY:SURFACE.
  RETURN (UP:VECTOR * (g_local+  vel_throt_pid:SETPOINT)) + des_v - VELOCITY:SURFACE.
}
LOCK STEERING TO LOOKDIRUP(hoverVec(), FACING:TOPVECTOR).

GLOBAL ALT_ADJUST IS calcRadarAltAdjust().

FUNCTION adjustedRadarAlt
{
  RETURN ALT:RADAR-ALT_ADJUST.
}

pOut("Waiting 2 seconds").
WAIT 2.
STAGE.
pOut("Ignition").

LOCK maxtwr TO MAX(1, SHIP:AVAILABLETHRUST / (g_local * MASS)).

GLOBAL t IS 0.
LOCK THROTTLE TO t.

GLOBAL step IS 0. // asent

SET alt_vel_pid:SETPOINT TO adjustedRadarAlt().

until FALSE {

  IF RCS {
    RCS OFF.
    SET LND_LNG TO LND_LNG-0.001.
    SET spot TO LATLNG(LND_LAT, LND_LNG).
  }

  IF step = 0 {
    IF adjustedRadarAlt() >= 50 AND h_dist > 5 {
      pOut("Beginning hover.").
      SET alt_vel_pid:SETPOINT TO 50.
      SET step TO 1.
    } ELSE {
      SET alt_vel_pid:SETPOINT TO adjustedRadarAlt() + 5.
    }
  } ELSE IF step = 1 AND ABS(adjustedRadarAlt()-alt_vel_pid:SETPOINT) < 1 AND ABS(VERTICALSPEED < 0.5) {
    pOut("Beginning translation.").
    LOCK STEERING TO LOOKDIRUP(translateVec(), FACING:TOPVECTOR).
    SET step TO 2.
  } ELSE IF step = 2 AND h_dist < 2.5 AND GROUNDSPEED < 0.5 {
    SET alt_vel_pid:SETPOINT TO adjustedRadarAlt()-(g_local/2).
    IF adjustedRadarAlt() < 15 { SET step TO 3. }
//  } ELSE IF step = 2 AND h_dist < 100 AND alt_vel_pid:SETPOINT > 20 {
//    SET alt_vel_pid:SETPOINT TO 20 + (30 * h_dist/100).
  } ELSE IF step = 3 {
    SET alt_vel_pid:SETPOINT TO adjustedRadarAlt()-1.
    IF adjustedRadarAlt() < 0.5 { SET step TO 4. }
  } ELSE IF step = 4 {
    pOut("Touching down.").
    UNLOCK THROTTLE.
    UNLOCK STEERING.
    hideVector("DesV").
    hideVector("Steer").
    SET step TO 5.
  }

  SET vel_throt_pid:MAXOUTPUT TO maxtwr.
  LOCAL target_vel IS alt_vel_pid:UPDATE(TIME:SECONDS, adjustedRadarAlt()).
  SET vel_throt_pid:SETPOINT TO target_vel.
  LOCAL target_acc IS vel_throt_pid:UPDATE(TIME:SECONDS, VERTICALSPEED).
  LOCAL target_twr IS target_acc / COS(VANG(UP:VECTOR, FACING:VECTOR)).
  SET t TO target_twr / MAX(0.0001, maxtwr).

pOut("alt_vel_pid SET: " + ROUND(alt_vel_pid:SETPOINT,1) + "m OUTPUT: " + ROUND(target_vel,1) + "m/s").
pOut("vel_throt_pid SET: " + ROUND(vel_throt_pid:SETPOINT,1) + "m/s OUTPUT: " + ROUND(target_acc,1) + "m/s^2").
pOut("Throttle: " + ROUND(t, 3)).
pOut("***").

  drawVector("Site", V(0,0,0),spot:POSITION,"Landing site aim point",RED).

  IF step > 1 AND step < 5 {
    drawVector("DesV", V(0,0,0),des_v,"Desired Velocity " + ROUND(des_v:MAG,1) + "m/s",GREEN).
    drawVector("Steer", V(0,0,0),translateVec(),"Steer",BLUE).
  }

  WAIT 0.
}