@LAZYGLOBAL OFF.

IF NOT EXISTS("1:/init.ks") { RUNPATH("0:/init_select.ks"). }
RUNONCEPATH("1:/init.ks").

pOut("KRescue.ks v1.3.0 20170120").

FOR f IN LIST(
  "lib_runmode.ks",
  "lib_crew.ks",
  "lib_launch_crew.ks",
  "lib_steer.ks",
  "lib_orbit_change.ks",
  "lib_orbit_match.ks",
  "lib_rendezvous.ks",
  "lib_skeep.ks",
  "lib_reentry.ks",
  "lib_dock.ks"  
) { RUNONCEPATH(loadScript(f)). }

FUNCTION validTarget {
  RETURN HASTARGET AND TARGET:OBT:BODY = BODY.
}

UNTIL runMode() = 99 {
LOCAL rm IS runMode().
IF rm < 0 {

  WAIT UNTIL cOk().
  RUNPATH("0:/lib_launch_geo.ks").

  hudMsg("Please select a target").
  pOut("Waiting.").
  WAIT UNTIL validTarget().

  pOut("Valid target. Calculating launch details.").
  LOCAL ap IS MIN(85000, MAX(ROUND(TARGET:PERIAPSIS)+250,75000)).
  LOCAL t_I IS TARGET:OBT:INCLINATION.
  LOCAL t_LAN IS TARGET:OBT:LAN.

  LOCAL launch_details IS calcLaunchDetails(ap,t_I,t_LAN).
  LOCAL az IS launch_details[0].
  LOCAL launch_time IS launch_details[1].
  warpToLaunch(launch_time).

  store("doLaunch(801," + ap + "," + az + "," + t_I + ").").
  doLaunch(801,ap,az,t_I).

} ELSE IF rm < 50 {
  resume().

} ELSE IF rm > 50 AND rm < 99 {
  resume().

} ELSE IF rm > 400 AND rm < 450 {
  resume().

} ELSE IF MOD(rm,10) = 9 AND rm > 800 AND rm < 999 {
  hudMsg("Error state. Hit abort to switch to recovery mode: " + abortMode() + ".").
  steerSun().
  WAIT UNTIL MOD(runMode(),10) <> 9.

} ELSE IF rm = 801 {
  delResume().
  runMode(811).

} ELSE IF rm = 811 {
  IF validTarget() {
    LOCAL t IS TARGET.
    store("changeRDZ_DIST(25).").
    append("doRendezvous(821,VESSEL(" + CHAR(34) + t:NAME + CHAR(34) + "),FALSE).").
    changeRDZ_DIST(25).
    doRendezvous(821,t,FALSE).
  } ELSE {
    pOut("No valid target selected.").
    hudMsg("Select new target or hit abort to re-enter.").
    runMode(812,831).
  }
} ELSE IF rm = 812 {
  IF validTarget() { runMode(811,0). }

} ELSE IF rm = 821 {
  delResume().
  steerNormal().
  pOut("Rendezvous complete.").
  runMode(822).

} ELSE IF rm = 822 {
  IF validTarget() {
    pOut("Initiate docking.").
    IF doDocking(TARGET) {
      pOut("Docking complete.").
      hudMsg("Shutting down. Hit abort on wake to return to Kerbin.").
      runMode(824,831).
      CORE:DOEVENT("Toggle Power").
    } ELSE {
      IF HASTARGET { SET TARGET TO "". }
      pOut("Docking failed. Select new target to try again or hit abort to return to Kerbin.").
      runMode(823,831).
    }

  } ELSE {
    pOut("No valid target selected.").
    hudMsg("Select new target or hit abort to return to Kerbin.").
    runMode(823,831).
  }

} ELSE IF rm = 823 {
  IF validTarget() { 
    IF TARGET:POSITION:MAG < 5000 { runMode(822,0). }
    ELSE { runMode(821). }
  }

} ELSE IF rm = 824 {
  // docked - wait for abort to trigger return

} ELSE IF rm = 831 {
  IF doOrbitChange(FALSE,stageDV() - 60,85000,85000) {
    doOrbitMatch(FALSE,stageDV() - 60,0).
    runMode(841).
  } ELSE {
    IF doOrbitChange(FALSE,stageDV(),APOAPSIS,29500) { runMode(842). }
    ELSE {
      pOut("ERROR: Not enough delta-v to lower periapsis below 30km.").
      runMode(839,831).
    }
  }

} ELSE IF rm = 841 {
  IF deorbitNode() { execNode(FALSE). }
  runMode(842).
} ELSE IF rm = 842 {
  IF PERIAPSIS < 70000 { runMode(843). }
  ELSE {
    pOut("ERROR: Did not lower periapsis below 70km.").
    runMode(849,841).
  }
} ELSE IF rm = 843 {
  store("doReentry(1,99).").
  doReentry(1,99).
}
  WAIT 0.
}
