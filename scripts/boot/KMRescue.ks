@LAZYGLOBAL OFF.

COPYPATH("0:/init.ks","1:/init.ks").
RUNONCEPATH("1:/init.ks").

pOut("KMRescue.ks v1.0.1 20160812").

FOR f IN LIST(
  "lib_runmode.ks",
  "lib_crew.ks",
  "lib_burn.ks"
) { RUNONCEPATH(loadScript(f)). }

FUNCTION validMoonTarget {
  RETURN HASTARGET AND TARGET:OBT:BODY:OBT:BODY = BODY AND crewCount(TARGET) > 0.
}

FUNCTION validLocalTarget {
  RETURN HASTARGET AND TARGET:OBT:BODY = BODY AND crewCount(TARGET) > 0.
}

UNTIL runMode() = 99 {
LOCAL rm IS runMode().
IF rm < 0 {
  IF crewSpaces() < 1 {
    hudMsg("No space on board for rescued crew!", RED).
    runMode(99).
  } ELSE {
    updateLastCrewCount().
    printCrew().
  }

  RUNONCEPATH(loadScript("lib_launch_geo.ks")).

  hudMsg("Please select a target").
  pOut("Waiting.").
  WAIT UNTIL validMoonTarget().

  pOut("Valid target. Calculating launch details.").
  LOCAL ap IS 85000.
  LOCAL b_I IS TARGET:OBT:BODY:OBT:INCLINATION.
  LOCAL b_LAN IS TARGET:OBT:BODY:OBT:LAN.

  LOCAL launch_details IS calcLaunchDetails(ap,b_I,b_LAN).
  LOCAL az IS launch_details[0].
  LOCAL launch_time IS launch_details[1].
  warpToLaunch(launch_time).

  delScript("lib_launch_geo.ks").
  RUNONCEPATH(loadScript("lib_launch_crew.ks")).

  store("doLaunch(801," + ap + "," + az + ").").
  doLaunch(801,ap,az).

} ELSE IF rm < 50 {
  RUNONCEPATH(loadScript("lib_launch_crew.ks")).
  resume().

} ELSE IF rm > 50 AND rm < 99 {
  RUNONCEPATH(loadScript("lib_reentry.ks")).
  resume().

} ELSE IF rm > 100 AND rm < 150 {
  RUNONCEPATH(loadScript("lib_transfer.ks")).
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
  runMode(802).
} ELSE IF rm = 802 {
  RUNONCEPATH(loadScript("lib_orbit_match.ks")).
  IF validMoonTarget() {
    LOCAL b_I IS TARGET:OBT:BODY:OBT:INCLINATION.
    LOCAL b_LAN IS TARGET:OBT:BODY:OBT:LAN.
    IF doOrbitMatch(FALSE,stageDV(),b_I,b_LAN) { runMode(811). }
    ELSE { runMode(809,802). }
  } ELSE {
    pOut("No valid target selected.").
    hudMsg("Select new target.").
    runMode(803).
  }
} ELSE IF rm = 803 {
  IF validMoonTarget() { runMode(802). }

} ELSE IF rm = 811 {
  RUNONCEPATH(loadScript("lib_transfer.ks")).
  IF validMoonTarget() {
    LOCAL t_B IS TARGET:OBT:BODY.
    LOCAL t_AP IS TARGET:APOAPSIS.
    LOCAL t_I IS TARGET:OBT:INCLINATION.
    LOCAL t_LAN IS TARGET:OBT:LAN.
    store("doTransfer(821, FALSE, "+t_B+","+t_AP+","+t_I+","+t_LAN+").").
    doTransfer(821, FALSE, t_B, t_AP, t_I, t_LAN).
  } ELSE {
    pOut("No valid target selected.").
    hudMsg("Select new target.").
    runMode(803).
  }

} ELSE IF rm = 821 {
  delResume().
  IF validLocalTarget() {
    RUNONCEPATH(loadScript("lib_rendezvous.ks")).
    LOCAL t IS TARGET.
    store("changeRDZ_DIST(25).").
    append("doRendezvous(831,VESSEL(" + CHAR(34) + t:NAME + CHAR(34) + "),FALSE).").
    changeRDZ_DIST(25).
    doRendezvous(831,t,FALSE).
  } ELSE {
    pOut("No valid target selected.").
    hudMsg("Select new target or hit abort to return to Kerbin.").
    runMode(822,851).
  }
} ELSE IF rm = 822 {
  IF validLocalTarget() { runMode(821,0). }

} ELSE IF rm = 831 {
  delResume().
  RUNONCEPATH(loadScript("lib_steer.ks")).
  steerNormal().
  pOut("Rendezvous complete. Waiting to be boarded.").
  IF HASTARGET { SET TARGET TO "". }
  runMode(832).
} ELSE IF rm = 832 {
  IF crewCount() > lastCrewCount() {
    hudMsg("Welcome aboard.").
    updateLastCrewCount().
    printCrew().
    runMode(833).
  }
} ELSE IF rm = 833 {
  RUNONCEPATH(loadScript("lib_skeep.ks")).
  IF sepMan(5,30) { runMode(834). }
  ELSE { runMode(839,833). }
} ELSE IF rm = 834 {
  IF crewSpaces() > 0 { runMode(821). }
  ELSE { runMode(851). }

} ELSE IF rm = 851 {
  delScript("lib_rendezvous.ks").
  RUNONCEPATH(loadScript("lib_transfer.ks")).
  RUN ONCE lib_gtb_transfer.ks.
  store("doTransfer(861, FALSE, KERBIN, 30000).").
  doTransfer(861, FALSE, KERBIN, 30000).

} ELSE IF rm = 861 {
  delResume().
  delScript("lib_transfer.ks").
  RUNONCEPATH(loadScript("lib_reentry.ks")).
  store("doReentry(1,99).").
  doReentry(1,99).
}
  WAIT 0.
}
