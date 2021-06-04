@LAZYGLOBAL OFF.

IF NOT EXISTS("1:/init.ks") {
  WAIT UNTIL HOMECONNECTION:ISCONNECTED.
  RUNPATH("0:/init_select.ks").
}
RUNONCEPATH("1:/init.ks").

pOut("circ.ks v1.0.0 20210305").

FOR f IN LIST(
  "lib_burn.ks",
  "lib_node.ks",
  "lib_steer.ks",
  "lib_launch_common.ks"
) { RUNONCEPATH(loadScript(f)). }

FUNCTION basicLaunchCirc
{
  IF NOT HASNODE {
    LOCAL m_time IS TIME:SECONDS + ETA:APOAPSIS.
    LOCAL v0 IS VELOCITYAT(SHIP,m_time):ORBIT:MAG.
    LOCAL v1 IS SQRT(BODY:MU/(BODY:RADIUS + APOAPSIS)).
    LOCAL n IS NODE(m_time, 0, 0, v1 - v0).
    addNode(n).
  }
  RETURN execNode(TRUE) AND PERIAPSIS > BODY:ATM:HEIGHT.
}

FUNCTION basicLaunchCoast
{
  IF NOT BODY:ATM:EXISTS OR ALTITUDE > BODY:ATM:HEIGHT {
    setIspFuelRate().
    pDV().
    steerOff().
    launchExtend().
    IF basicLaunchCirc() {
      sepLauncher().
      IF CRAFT_SPECIFIC:HASKEY("LCH_RCS_OFF_IN_ORBIT") { RCS OFF. }
      pDV().
    }
    RETURN TRUE.
  } ELSE {
    RETURN FALSE.
  }
}

WAIT UNTIL basicLaunchCoast().

