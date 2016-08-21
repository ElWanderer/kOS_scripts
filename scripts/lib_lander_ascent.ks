@LAZYGLOBAL OFF.

pOut("lib_lander_ascent.ks v1.1.0 20160812").

FOR f IN LIST(
  "lib_steer.ks",
  "lib_burn.ks",
  "lib_runmode.ks",
  "lib_orbit.ks",
  "lib_lander_common.ks"
) { RUNONCEPATH(loadScript(f)). }

GLOBAL LND_LAZ IS 0.
GLOBAL LND_LAP IS 0.

FUNCTION initAscentValues
{
  landerSetMinVSpeed(20).
  initLanderValues().
}

FUNCTION stopAscentValues
{
  stopLanderValues().
}

FUNCTION steerAscent
{
  steerTo({ RETURN HEADING(LND_LAZ,landerPitch()):VECTOR. }).
}

FUNCTION ascentCirc
{
  IF NOT HASNODE {
    LOCAL m_time IS TIME:SECONDS + ETA:APOAPSIS.
    LOCAL v0 IS VELOCITYAT(SHIP,m_time):ORBIT:MAG.
    LOCAL v1 IS SQRT(BODY:MU/(BODY:RADIUS + APOAPSIS)).
    LOCAL n IS NODE(m_time, 0, 0, v1 - v0).
    addNode(n).
  }
  execNode(TRUE).
}

FUNCTION doLanderAscent
{
  PARAMETER launch_ap, launch_az.
  PARAMETER stages_on_launch.
  PARAMETER exit_mode.
  SET LND_LAP to launch_ap.
  SET LND_LAZ TO launch_az.

  pOut("Launch to apoasis: " + LND_LAP).
  pOut("Launch heading: " + ROUND(LND_LAZ,2)).

  LOCAL LOCK rm TO runMode().

  IF rm < 301 OR rm > 349 { runMode(301). }

  initAscentValues().
  IF APOAPSIS < LND_LAP {
    IF rm > 305 { steerAscent(). }
    IF rm > 304 { LOCK THROTTLE TO 1. }
  }

UNTIL rm = exit_mode
{
  IF rm = 301 {
    SET WARP TO 0.
    steerTo({ RETURN UP:VECTOR. }).
    hudMsg("Prepare for launch...").
    runMode(304,302).
  } ELSE IF rm = 302 {
    hudMsg("Launch paused. Hit abort to resume.").
    steerOff().
    runMode(303,301).
  } ELSE IF rm = 303 {
    // wait
  } ELSE IF rm = 304 {
    IF modeTime() > 3 {
      LOCK THROTTLE TO 1.
      hudMsg("Liftoff!").
      runMode(305,0).
    }
  } ELSE IF rm = 305 {
    IF stages_on_launch > 0 {
      IF modeTime() > 5 AND STAGE:READY {
        doStage().
        SET stages_on_launch TO stages_on_launch - 1.
        store("doLanderAscent("+LND_LAP+","+LND_LAZ+","+stages_on_launch+","+exit_mode+").").
      }
    } ELSE { runMode(306). }
  } ELSE IF rm = 306 {
    IF modeTime() > 1 {
      steerAscent().
      runMode(307).
    }
  } ELSE IF rm = 307 {
    IF ALTITUDE < 15000 {
      IF landerHeartBeat() > 1 {
        findMinVSpeed(20,600,10).
        landerResetTimer().
      }
    }
    IF APOAPSIS > LND_LAP {
      LOCK THROTTLE TO 0.
      ascentCirc().
      runMode(exit_mode).
    }
  } ELSE {
    pOut("Launch lander - unexpected run mode: " + rm).
    runMode(exit_mode).
  }

  WAIT 0.
}
  stopAscentValues().
}
