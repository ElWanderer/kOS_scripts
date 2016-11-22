@LAZYGLOBAL OFF.

IF NOT EXISTS("1:/init.ks") { RUNPATH("0:/init_select.ks"). }
RUNONCEPATH("1:/init.ks").

pOut("KRescue.ks v1.2.2 20161121").

FOR f IN LIST(
  "lib_runmode.ks",
  "lib_crew.ks",
  "lib_burn.ks"
) { RUNONCEPATH(loadScript(f)). }

FUNCTION validTarget {
  RETURN HASTARGET AND TARGET:OBT:BODY = BODY AND crewCount(TARGET) > 0.
}

UNTIL runMode() = 99 {
LOCAL rm IS runMode().
IF rm < 0 {
  IF crewSpaces() < 1 {
    hudMsg("No space on board for rescued crew!", RED).
    runMode(99).
  } ELSE {
    storeLastCrewCount().
    pCrew().
  }

  RUNONCEPATH(loadScript("lib_launch_geo.ks")).

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

  delScript("lib_launch_geo.ks").
  RUNONCEPATH(loadScript("lib_launch_crew.ks")).

  store("doLaunch(801," + ap + "," + az + "," + t_I + ").").
  doLaunch(801,ap,az,t_I).

} ELSE IF rm < 50 {
  RUNONCEPATH(loadScript("lib_launch_crew.ks")).
  resume().

} ELSE IF rm > 50 AND rm < 99 {
  RUNONCEPATH(loadScript("lib_reentry.ks")).
  resume().

} ELSE IF rm > 400 AND rm < 450 {
  RUNONCEPATH(loadScript("lib_rendezvous.ks")).
  resume().

} ELSE IF MOD(rm,10) = 9 AND rm > 800 AND rm < 999 {
  RUNONCEPATH(loadScript("lib_steer.ks")).
  hudMsg("Error state. Hit abort to switch to recovery mode: " + abortMode() + ".").
  steerSun().
  WAIT UNTIL MOD(runMode(),10) <> 9.

} ELSE IF rm = 801 {
  delResume().
  delScript("lib_launch_crew.ks").
  delScript("lib_launch_common.ks").
  runMode(811).

} ELSE IF rm = 811 {
  IF validTarget() {
    RUNONCEPATH(loadScript("lib_rendezvous.ks")).
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
  pOut("Rendezvous complete. Waiting to be boarded.").
  IF HASTARGET { SET TARGET TO "". }
  runMode(822).
} ELSE IF rm = 822 {
  IF crewCount() > lastCrewCount() {
    hudMsg("Welcome aboard.").
    storeLastCrewCount().
    pCrew().
    runMode(823).
  }
} ELSE IF rm = 823 {
  RUNONCEPATH(loadScript("lib_skeep.ks")).
  IF doSeparation() { runMode(824). }
  ELSE { runMode(829,823). }
} ELSE IF rm = 824 {
  IF crewSpaces() > 0 { runMode(811). }
  ELSE { runMode(831). }

} ELSE IF rm = 831 {
  delScript("lib_rendezvous.ks").
  RUNONCEPATH(loadScript("lib_orbit_match.ks")).
  RUNONCEPATH(loadScript("lib_orbit_change.ks")).

  IF doOrbitChange(FALSE,stageDV() - 60,85000,85000) {
    doOrbitMatch(FALSE,stageDV() - 60,0).
    runMode(841).
  } ELSE {
    IF doOrbitChange(FALSE,stageDV(),APOAPSIS,29500) { runMode(841). }
    ELSE {
      pOut("ERROR: Not enough delta-v to lower periapsis below 30km.").
      runMode(839,831).
    }
  }

} ELSE IF rm = 841 {
  RUNONCEPATH(loadScript("lib_reentry.ks")).
  RUNONCEPATH(loadScript("lib_burn.ks")).
  IF deorbitNode() { execNode(FALSE). }
  runMode(842).
} ELSE IF rm = 842 {
  IF PERIAPSIS < 70000 { runMode(843). }
  ELSE {
    pOut("ERROR: Did not lower periapsis below 70km.").
    runMode(849,841).
  }
} ELSE IF rm = 843 {
  RUNONCEPATH(loadScript("lib_reentry.ks")).
  store("doReentry(1,99).").
  doReentry(1,99).
}
  WAIT 0.
}
