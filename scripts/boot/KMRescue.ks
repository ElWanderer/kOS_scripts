@LAZYGLOBAL OFF.

IF NOT EXISTS("1:/init.ks") { RUNPATH("0:/init_select.ks"). }
RUNONCEPATH("1:/init.ks").

pOut("KMRescue.ks v1.3.0 20170116").

FOR f IN LIST(
  "lib_runmode.ks",
  "lib_crew.ks",
  "lib_launch_crew.ks",
  "lib_steer.ks",
  "lib_orbit_change.ks",
  "lib_orbit_match.ks",
  "lib_transfer.ks",
  "lib_rendezvous.ks",
  "lib_skeep.ks",
  "lib_reentry.ks"
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
    storeLastCrewCount().
    pCrew().
  }

  WAIT UNTIL cOk().
  RUNPATH("0:/lib_launch_geo.ks").
  
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

  store("doLaunch(801," + ap + "," + az + "," + b_I + ").").
  doLaunch(801,ap,az,b_I).

} ELSE IF rm < 50 {
  resume().

} ELSE IF rm > 50 AND rm < 99 {
  resume().

} ELSE IF rm > 100 AND rm < 150 {
  resume().

} ELSE IF rm > 400 AND rm < 450 {
  resume().

} ELSE IF MOD(rm,10) = 9 AND rm > 800 AND rm < 999 {
  hudMsg("Error state. Hit abort to switch to recovery mode: " + abortMode() + ".").
  steerSun().
  WAIT UNTIL MOD(runMode(),10) <> 9.

} ELSE IF rm = 801 {
  delResume().
  runMode(802).
} ELSE IF rm = 802 {
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
  steerNormal().
  pOut("Rendezvous complete. Waiting to be boarded.").
  IF HASTARGET { SET TARGET TO "". }
  runMode(832).
} ELSE IF rm = 832 {
  IF crewCount() > lastCrewCount() {
    hudMsg("Welcome aboard.").
    storeLastCrewCount().
    pCrew().
    runMode(833).
  }
} ELSE IF rm = 833 {
  IF doSeparation() { runMode(834). }
  ELSE { runMode(839,833). }
} ELSE IF rm = 834 {
  IF crewSpaces() > 0 { runMode(821). }
  ELSE { runMode(851). }

} ELSE IF rm = 851 {
  store("doTransfer(861, FALSE, KERBIN, 30000).").
  doTransfer(861, FALSE, KERBIN, 30000).

} ELSE IF rm = 861 {
  delResume().
  store("doReentry(1,99).").
  doReentry(1,99).
}
  WAIT 0.
}
