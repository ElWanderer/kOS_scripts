@LAZYGLOBAL OFF.

COPYPATH("0:/init.ks","1:/init.ks").
RUNONCEPATH("1:/init.ks").

pOut("KMLanderCrew.ks v1.0.1 20160812").

RUNONCEPATH(loadScript("lib_runmode.ks")).

// set these values ahead of launch
GLOBAL NEW_NAME IS "Endeavour II".
GLOBAL CORE_HEIGHT IS 2.3.

GLOBAL LAND_LAT IS 0.
GLOBAL LAND_LNG IS 20.
GLOBAL SAFETY_ALT IS 2000.

GLOBAL RETURN_ORBIT IS 30000.

FUNCTION validLocalTarget {
  RETURN HASTARGET AND TARGET:OBT:BODY = BODY.
}

IF runMode() > 0 { logOn(). }

UNTIL runMode() = 99 {
LOCAL rm IS runMode().
IF rm < 0 {
  SET SHIP:NAME TO NEW_NAME.
  logOn().

  runMode(801).

} ELSE IF rm > 200 AND rm < 250 {
  RUNONCEPATH(loadScript("lib_lander_descent.ks")).
  resume().

} ELSE IF rm > 300 AND rm < 350 {
  RUNONCEPATH(loadScript("lib_lander_ascent.ks")).
  resume().

} ELSE IF MOD(rm,10) = 9 AND rm > 800 AND rm < 999 {
  RUNONCEPATH(loadScript("lib_steer.ks")).
  hudMsg("Error state. Hit abort to switch to recovery mode: " + abortMode() + ".").
  steerSun().
  WAIT UNTIL MOD(runMode(),10) <> 9.

} ELSE IF rm = 801 {
  hudMsg("Hit abort to initiate landing sequence.").
  runMode(802,803).

} ELSE IF rm = 802 {
  // wait

} ELSE IF rm = 803 {
  RUNONCEPATH(loadScript("lib_skeep.ks")).
  IF sepMan(5,30) { runMode(811,0). }
  ELSE { runMode(809,803). }

} ELSE IF rm = 811 {
  RUNONCEPATH(loadScript("lib_lander_descent.ks")).
  store("doLanding(" + LAND_LAT + "," + LAND_LNG + ","+CORE_HEIGHT+","+SAFETY_ALT+",5000,25,821).").
  doLanding(LAND_LAT,LAND_LNG,CORE_HEIGHT,SAFETY_ALT,5000,25,821).

} ELSE IF rm = 821 {
  delResume().
  delScript("lib_lander_descent.ks").
  runMode(831).

} ELSE IF rm = 831 {
  hudMsg("Hit abort to initiate ascent, rendezvous and docking sequence.").
  runMode(832,841).

} ELSE IF rm = 832 {
  // wait

} ELSE IF rm = 841 {
  IF validLocalTarget() { runMode(843,0). }
  ELSE {
    pOut("No valid target selected.").
    hudMsg("Select a target to rendezvous with.").
    runMode(842,0).
  }

} ELSE IF rm = 842 {
  IF validLocalTarget() { runMode(843). }

} ELSE IF rm = 843 {
  pOut("Preparing for lift-off.").

  RUNONCEPATH(loadScript("lib_launch_geo.ks")).

  LOCAL b_I IS TARGET:OBT:BODY:OBT:INCLINATION.
  LOCAL b_LAN IS TARGET:OBT:BODY:OBT:LAN.

  LOCAL launch_details IS calcLaunchDetails(RETURN_ORBIT,b_I,b_LAN).
  LOCAL az IS launch_details[0].
  LOCAL launch_time IS launch_details[1].
  warpToLaunch(launch_time).

  delScript("lib_launch_geo.ks").
  RUNONCEPATH(loadScript("lib_lander_ascent.ks")).
  store("doLanderAscent("+RETURN_ORBIT+",az,0,851).").
  doLanderAscent(RETURN_ORBIT,az,0,851).

} ELSE IF rm = 851 {
  delResume().
  IF validLocalTarget() {
    RUNONCEPATH(loadScript("lib_rendezvous.ks")).
    LOCAL t IS TARGET.
    store("changeRDZ_DIST(75).").
    append("doRendezvous(861,VESSEL(" + CHAR(34) + t:NAME + CHAR(34) + "),FALSE).").
    changeRDZ_DIST(75).
    doRendezvous(861,t,FALSE).
  } ELSE {
    pOut("No valid target selected.").
    hudMsg("Select target to rendezvous with.").
    runMode(852).
  }
} ELSE IF rm = 852 {
  IF validLocalTarget() { runMode(851). }

} ELSE IF rm = 861 {
  delResume().
  RUNONCEPATH(loadScript("lib_steer.ks")).
  steerNormal().
  pOut("Rendezvous complete.").
  runMode(862).

} ELSE IF rm = 862 {
  IF validLocalTarget() {
    RUNONCEPATH(loadScript("lib_dock.ks")).
    pOut("Initiate docking.").
    IF doDocking(TARGET) {
      pOut("Docking complete.").
      hudMsg("Shutting down.").
      runMode(-1).
      CORE:DOEVENT("Toggle Power").
    } ELSE {
      IF HASTARGET { SET TARGET TO "". }
      pOut("Docking failed. Select new target to try again.").
      runMode(863).
    }

  } ELSE {
    pOut("No valid target selected.").
    hudMsg("Select target for docking.").
    runMode(863).
  }

} ELSE IF rm = 863 {
  IF validLocalTarget() { 
    IF TARGET:POSITION:MAG < 5000 { runMode(862,0). }
    ELSE { runMode(851). }
  }
} ELSE IF rm = 871 {
  // docked - wait for abort to trigger return
}

  WAIT 0.
} // end of UNTIL
