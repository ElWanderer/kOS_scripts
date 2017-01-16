@LAZYGLOBAL OFF.

IF NOT EXISTS("1:/init.ks") { RUNPATH("0:/init_select.ks"). }
RUNONCEPATH("1:/init.ks").

pOut("KMLanderProbe.ks v1.3.0 20170116").

FOR f IN LIST(
  "lib_runmode.ks",
  "lib_launch_nocrew.ks",
  "lib_orbit_match.ks",
  "lib_orbit_change.ks",
  "lib_transfer.ks",
  "lib_reentry.ks",
  "lib_lander_descent.ks",
  "lib_lander_ascent.ks",
  "lib_science.ks"
) { RUNONCEPATH(loadScript(f)). }

// set these values ahead of launch
GLOBAL SAT_NAME IS "Lander Test 1".
GLOBAL CORE_HEIGHT IS 3.25. // metres

GLOBAL LAND_BODY IS MUN.
GLOBAL LAND_LAT IS 25.
GLOBAL LAND_LNG IS 25.
GLOBAL SAFETY_ALT IS 2000.

GLOBAL PARK_ORBIT IS 60000.
GLOBAL PARK_I IS MAX(87.5,MIN(90,ABS(LAND_LAT)+5)). // try to ensure we fly-over target latitude
GLOBAL RETURN_ORBIT IS 60000.

GLOBAL LAND_BODY_I IS LAND_BODY:OBT:INCLINATION.
GLOBAL LAND_BODY_LAN IS LAND_BODY:OBT:LAN.

FUNCTION dvForBody
{
  PARAMETER planet.
  IF planet = MUN { RETURN 1300. }
  ELSE IF planet = MINMUS { RETURN 500. }
}

IF runMode() > 0 { logOn(). }

UNTIL runMode() = 99 {
LOCAL rm IS runMode().
IF rm < 0 {
  SET SHIP:NAME TO SAT_NAME.
  logOn().

  WAIT UNTIL cOk().
  RUNPATH("0:/lib_launch_geo.ks").

  LOCAL ap IS 85000.
  LOCAL launch_details IS calcLaunchDetails(ap,LAND_BODY_I,LAND_BODY_LAN).
  LOCAL az IS launch_details[0].
  LOCAL launch_time IS launch_details[1].
  warpToLaunch(launch_time).

  store("doLaunch(801," + ap + "," + az + "," + LAND_BODY_I + ").").
  doLaunch(801,ap,az,LAND_BODY_I).

} ELSE IF rm < 50 {
  resume().

} ELSE IF rm > 50 AND rm < 99 {
  resume().

} ELSE IF rm > 100 AND rm < 150 {
  resume().

} ELSE IF rm > 200 AND rm < 250 {
  resume().

} ELSE IF rm > 300 AND rm < 350 {
  resume().

} ELSE IF MOD(rm,10) = 9 AND rm > 800 AND rm < 999 {
  hudMsg("Error state. Hit abort to switch to recovery mode: " + abortMode() + ".").
  steerSun().
  WAIT UNTIL MOD(runMode(),10) <> 9.

} ELSE IF rm = 801 {
  delResume().
  runMode(802).
} ELSE IF rm = 802 {
  IF doOrbitMatch(FALSE,stageDV(),LAND_BODY_I,LAND_BODY_LAN) { runMode(811). }
  ELSE { runMode(809,802). }

} ELSE IF rm = 811 {
  store("doTransfer(812, FALSE, "+LAND_BODY+","+PARK_ORBIT+","+PARK_I+").").
  doTransfer(812, FALSE, LAND_BODY, PARK_ORBIT, PARK_I).
} ELSE IF rm = 812 {
  delResume().
  IF doOrbitMatch(FALSE,stageDV(),PARK_I) { runMode(813). }
  ELSE { runMode(819,812). }
} ELSE IF rm = 813 {
  IF doOrbitChange(FALSE,stageDV(),PARK_ORBIT,PARK_ORBIT) { runMode(821). }
  ELSE { runMode(819,813). }

} ELSE IF rm = 821 {
  IF stageDV() > dvForBody(LAND_BODY) {
    runMode(831).
  } ELSE {
    steerOrbit().
    runMode(822).
  }
} ELSE IF rm = 822 {
  IF NOT isSteerOn() { runMode(821). }
  IF steerOk() { runMode(823). }
} ELSE IF rm = 823 {
  IF stageDV() > dvForBody(LAND_BODY) { runMode(831). }
  ELSE IF STAGE:READY { doStage(). }

} ELSE IF rm = 831 {
  steerOff().
  WAIT 10.
  runMode(832).
} ELSE IF rm = 832 {
  store("doLanding(" + LAND_LAT + "," + LAND_LNG + ","+CORE_HEIGHT+","+SAFETY_ALT+",5000,25,841).").
  doLanding(LAND_LAT,LAND_LNG,CORE_HEIGHT,SAFETY_ALT,5000,25,841).

} ELSE IF rm = 841 {
  delResume().
  doScience(FALSE,FALSE).
  runMode(842).
} ELSE IF rm = 842 {
  UNTIL transmitScience(FALSE,TRUE,300) { doWarp(TIME:SECONDS + 600). }
  runMode(843).
} ELSE IF rm = 843 {
  resetScience().
  doScience(TRUE,TRUE).
  runMode(844).
} ELSE IF rm = 844 {
  IF SHIP:ELECTRICCHARGE > 50 {
    killWarp().
    pOut("Preparing for lift-off.").
    runMode(845).
  } ELSE { doWarp(TIME:SECONDS + 3600, { RETURN SHIP:ELECTRICCHARGE > 50. }). }
} ELSE IF rm = 845 {
  store("doLanderAscent("+RETURN_ORBIT+",90,1,851).").
  doLanderAscent(RETURN_ORBIT,90,1,851).

} ELSE IF rm = 851 {
  delResume().
  store("doTransfer(861, FALSE, KERBIN, 30000).").
  doTransfer(861, FALSE, KERBIN, 30000).

} ELSE IF rm = 861 {
  store("doReentry(1,99).").
  doReentry(1,99).
}
  WAIT 0.
} // end of UNTIL
