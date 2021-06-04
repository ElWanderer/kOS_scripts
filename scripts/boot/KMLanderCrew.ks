@LAZYGLOBAL OFF.

IF NOT EXISTS("1:/init.ks") { RUNPATH("0:/init_select.ks"). }
RUNONCEPATH("1:/init.ks").

pOut("KMLanderCrew.ks v1.2.0 20171101").

FOR f IN LIST(
  "lib_runmode.ks",
  "lib_burn.ks",
  "lib_lander_descent.ks",
  "lib_launch_geo.ks",
  "lib_lander_ascent.ks",
  "lib_skeep.ks",
  "lib_rendezvous.ks",
  "lib_dock.ks"
) { RUNONCEPATH(loadScript(f)). }

// set these values ahead of launch
GLOBAL NEW_NAME IS "Minmus Lander 1 - MM".
GLOBAL CORE_HEIGHT IS 2.3.

GLOBAL LAND_LAT IS 0.
GLOBAL LAND_LNG IS 0.
GLOBAL SAFETY_ALT IS 2000.

GLOBAL RETURN_ORBIT IS 40000.

FUNCTION validLocalTarget {
  RETURN HASTARGET AND TARGET:OBT:BODY = BODY.
}

IF SHIP:NAME = NEW_NAME { logOn(). }

UNTIL runMode() = 99 {
LOCAL rm IS runMode().
IF rm < 0 {
  hudMsg("Lander boot complete. Shutting down.").
  hudMsg("On reboot, hit abort to initiate landing.").
  runMode(801).
  CORE:DOEVENT("Toggle Power").

} ELSE IF rm > 200 AND rm < 250 {
  resume().

} ELSE IF rm > 300 AND rm < 350 {
  resume().

} ELSE IF rm > 400 AND rm < 450 {
  resume().

} ELSE IF MOD(rm,10) = 9 AND rm > 800 AND rm < 999 {
  hudMsg("Error state. Hit abort to switch to recovery mode: " + abortMode() + ".").
  steerSun().
  WAIT UNTIL MOD(runMode(),10) <> 9.

} ELSE IF rm = 801 {
  hudMsg("Hit abort to initiate landing sequence.").
  runMode(802,803).

} ELSE IF rm = 802 {
  // wait

} ELSE IF rm = 803 {
  SET SHIP:NAME TO NEW_NAME.
  logOn().
  IF doSeparation() { runMode(811,0). }
  ELSE { runMode(809,803). }

} ELSE IF rm = 811 {
  store("doLanding(" + LAND_LAT + "," + LAND_LNG + ","+CORE_HEIGHT+","+SAFETY_ALT+",5000,25,821).").
  doLanding(LAND_LAT,LAND_LNG,CORE_HEIGHT,SAFETY_ALT,5000,25,821).

} ELSE IF rm = 821 {
  delResume().
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

  LOCAL t_I IS TARGET:OBT:INCLINATION.
  LOCAL t_LAN IS TARGET:OBT:LAN.

  LOCAL launch_details IS calcLaunchDetails(RETURN_ORBIT,t_I,t_LAN).
  LOCAL az IS launch_details[0].
  LOCAL launch_time IS launch_details[1].
  warpToLaunch(launch_time).

  store("doLanderAscent("+RETURN_ORBIT+","+az+",0,851).").
  doLanderAscent(RETURN_ORBIT,az,0,851).

} ELSE IF rm = 851 {
  delResume().
  IF validLocalTarget() {
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
  steerNormal().
  pOut("Rendezvous complete.").
  runMode(862).

} ELSE IF rm = 862 {
  IF validLocalTarget() {
    pOut("Initiate docking.").
    IF doDocking(TARGET) {
      pOut("Docking complete.").
      hudMsg("Shutting down.").
      runMode(801).
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
}

  WAIT 0.
} // end of UNTIL
