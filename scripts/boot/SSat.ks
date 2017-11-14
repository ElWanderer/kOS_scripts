@LAZYGLOBAL OFF.

IF NOT EXISTS("1:/init.ks") { RUNPATH("0:/init_select.ks"). }
RUNONCEPATH("1:/init.ks").

pOut("SSat.ks v1.0.0 20171114").

FOR f IN LIST(
  "lib_runmode.ks",
  "lib_launch_nocrew.ks",
  "lib_steer.ks",
  "lib_orbit_change.ks",
  "lib_orbit_match2.ks",
  "lib_transfer.ks"
) { RUNONCEPATH(loadScript(f)). }

// set these values ahead of launch
GLOBAL SAT_NAME IS "Solar Relay 5".

GLOBAL SAT_CAN_STAGE IS TRUE.

GLOBAL UNIT_GM IS 1000000000.

GLOBAL SAT_AP IS 50.
GLOBAL SAT_PE IS 50.
GLOBAL SAT_I IS 0.
GLOBAL SAT_LAN IS -1.
GLOBAL SAT_W IS -1.

GLOBAL SAT_LAUNCH_AP IS 150000.

// BODY must not be Sun for this to work!
FUNCTION bodyOrbitRelInc
{
  PARAMETER u_time, i, lan.
  RETURN VANG(craftNormal(BODY,u_time), orbitNormal(ORBITAT(BODY,u_time):BODY,i,lan)).
}

FUNCTION bodyTAAN
{
  PARAMETER u_time, o_normal.
  LOCAL b_pos IS posAt(BODY,u_time).
  LOCAL b_normal IS craftNormal(BODY,u_time).
  LOCAL nodes IS VCRS(b_normal,o_normal).
  LOCAL ang IS VANG(b_pos,nodes).
  IF VDOT(b_normal,VCRS(nodes,b_pos)) < 0 { SET ang TO 360 - ang. }
  RETURN mAngle(ang + taAt(BODY,u_time)).
}

FUNCTION determineTBD {
  LOCAL pe_r IS (SAT_PE * UNIT_GM) + SUN:RADIUS.
  LOCAL ap_r IS (SAT_AP * UNIT_GM) + SUN:RADIUS.
  LOCAL a IS (pe_r + ap_r) / 2.
  LOCAL e IS (ap_r - pe_r) / (ap_r + pe_r).
  LOCAL an_r IS (a * (1 - e^2))/ (1 + (e * COS(-SAT_W))).
  LOCAL an_vec IS R(0,-SAT_LAN,0) * SOLARPRIMEVECTOR:NORMALIZED * an_r.

  LOCAL o_normal IS orbitNormal(SUN, SAT_I, SAT_LAN).

  LOCAL pe_vec IS (ANGLEAXIS(-SAT_W,o_normal) * an_vec):NORMALIZED * pe_r.
  LOCAL ap_vec IS (ANGLEAXIS(180,o_normal) * pe_vec):NORMALIZED * ap_r.

  VECDRAW(SUN:POSITION,SOLARPRIMEVECTOR:NORMALIZED * a,RGB(1,0,0),"SOLAR PRIME VECTOR",1,TRUE).
  VECDRAW(SUN:POSITION,an_vec,RGB(0,0,1),"Ascending Node",1,TRUE).
  VECDRAW(SUN:POSITION,pe_vec,RGB(0,1,0),"Periapsis",1,TRUE).
  VECDRAW(SUN:POSITION,ap_vec,RGB(0,1,0),"Apoapsis",1,TRUE).

  VECDRAW(SUN:POSITION,KERBIN:POSITION-SUN:POSITION,RGB(1,1,0),"Body, position from Sun",1,TRUE).

  LOCAL opp_vec IS VXCL(o_normal,SUN:POSITION-KERBIN:POSITION):NORMALIZED.
  LOCAL ang IS VANG(opp_vec, pe_vec).
  IF VDOT(o_normal,VCRS(pe_vec,opp_vec)) < 0 { SET ang TO 360 - ang. }
  LOCAL opp_ta IS ang.
pOut("True anomaly of opposition: " + ROUND(opp_ta,2) + " degrees.").
  LOCAL opp_r IS orbitRadiusAtTA(SUN, (SAT_AP * UNIT_GM), (SAT_PE * UNIT_GM), opp_ta).
pOut("Orbital radius of opposition: " + ROUND(opp_r) + "m.").
  VECDRAW(SUN:POSITION,opp_vec:NORMALIZED * opp_r,RGB(1,1,1),"Opposition from body",1,TRUE).

  LOCAL fiddle IS 0.
  LOCAL jump IS 30.
  LOCAL body_normal IS craftNormal(KERBIN,TIME:SECONDS+1).
  UNTIL fiddle + jump >= 360 {
    SET fiddle TO fiddle + jump.
    LOCAL body_pos_opp_vec IS SUN:POSITION-KERBIN:POSITION.
    LOCAL body_pos_rotated_vec IS ANGLEAXIS(-fiddle, body_normal) * body_pos_opp_vec.
    LOCAL new_vec IS VXCL(o_normal,body_pos_rotated_vec).
    LOCAL new_ang IS VANG(new_vec, pe_vec).
    IF VDOT(o_normal,VCRS(pe_vec,new_vec)) < 0 { SET new_ang TO 360 - new_ang. }
    LOCAL new_ta IS new_ang.
    LOCAL new_r IS orbitRadiusAtTA(SUN, (SAT_AP * UNIT_GM), (SAT_PE * UNIT_GM), new_ta).
    VECDRAW(SUN:POSITION,new_vec:NORMALIZED * new_r,RGB(1,1,1),"Oppsition + " + fiddle,1,TRUE).
  }
  RETURN opp_r - SUN:RADIUS.
}

// assumes we are not in sphere of influence of the Sun
FUNCTION determineSolarTransferAP {
  PARAMETER u_time IS TIME:SECONDS.
  LOCAL curr_body_ta IS taAt(BODY, TIME:SECONDS).
  LOCAL body_ta IS taAt(BODY, u_time).
  IF ABS(u_time - TIME:SECONDS) < 1 { SET body_ta TO curr_body_ta. }
  LOCAL ta_diff IS mAngle(body_ta - curr_body_ta).

  LOCAL pe_r IS (SAT_PE * UNIT_GM) + SUN:RADIUS.
  LOCAL ap_r IS (SAT_AP * UNIT_GM) + SUN:RADIUS.
  LOCAL a IS (pe_r + ap_r) / 2.
  LOCAL e IS (ap_r - pe_r) / (ap_r + pe_r).
  LOCAL an_r IS (a * (1 - e^2))/ (1 + (e * COS(-SAT_W))).
  LOCAL an_vec IS R(0,-SAT_LAN,0) * SOLARPRIMEVECTOR:NORMALIZED * an_r.

  LOCAL o_normal IS orbitNormal(SUN, SAT_I, SAT_LAN).

  LOCAL pe_vec IS (ANGLEAXIS(-SAT_W,o_normal) * an_vec):NORMALIZED * pe_r.

  LOCAL body_normal IS craftNormal(BODY,TIME:SECONDS).
  LOCAL opp_vec IS ANGLEAXIS(-ta_diff,body_normal) * SUN:POSITION-BODY:POSITION.
  SET opp_vec TO VXCL(o_normal,opp_vec):NORMALIZED.
  LOCAL ang IS VANG(opp_vec, pe_vec).
  IF VDOT(o_normal,VCRS(pe_vec,opp_vec)) < 0 { SET ang TO 360 - ang. }
  LOCAL opp_ta IS ang.
  LOCAL opp_r IS orbitRadiusAtTA(SUN, (SAT_AP * UNIT_GM), (SAT_PE * UNIT_GM), opp_ta).

  RETURN opp_r - SUN:RADIUS.
}

// assumes we are not in sphere of influence of the Sun
// assumes the body we are leaving has an orbit plane that is well-aligned
// with the target orbit
FUNCTION determineLaunchTimeToSolarApoapsis {
  // needs testing
  LOCAL u_time IS TIME:SECONDS.
  LOCAL o_normal IS orbitNormal(SUN, SAT_I, SAT_LAN).
  LOCAL an_vec IS R(0,-SAT_LAN,0) * SOLARPRIMEVECTOR:NORMALIZED.
  LOCAL pe_vec IS (ANGLEAXIS(-SAT_W,o_normal) * an_vec).
  LOCAL body_pos IS posAt(BODY,u_time).
  LOCAL ta_diff IS VANG(body_pos, pe_vec).
  IF VDOT(o_normal, VCRS(pe_vec,body_pos)) < 0 { SET ta_diff TO 360-ta_diff. }

  LOCAL curr_body_ta IS taAt(BODY, u_time).
  LOCAL launch_ta IS mAngle(curr_body_ta + ta_diff).
  RETURN u_time + secondsToTA(BODY, u_time, launch_ta).
}

// assumes we are not in sphere of influence of the Sun
FUNCTION determineLaunchTimeToSolarNode {
  LOCAL o_normal IS orbitNormal(SUN, SAT_I, SAT_LAN).
  LOCAL u_time IS TIME:SECONDS.

  LOCAL body_ta IS taAt(BODY,u_time).

  LOCAL an_ta IS bodyTAAN(u_time, o_normal).
  LOCAL an_time IS u_time + secondsToTA(BODY, u_time, an_ta).
  LOCAL an_ap IS determineSolarTransferAP(an_time).

pOut("Ascending node is " + ROUND(an_time-TIME:SECONDS) + "s away.").
pOut("Ascending node is at " + ROUND(an_ap,2) + "Gm.").

  LOCAL dn_ta IS mAngle(an_ta + 180).
  LOCAL dn_time IS u_time + secondsToTA(BODY, u_time, dn_ta).
  LOCAL dn_ap IS determineSolarTransferAP(dn_time).

pOut("Descending node is " + ROUND(dn_time-TIME:SECONDS) + "s away.").
pOut("Descending node is at " + ROUND(dn_ap,2) + "Gm.").

  IF (ABS(an_ap-dn_ap) / (an_ap+dn_ap)) > 0.1 {
    LOCAL cheapest_node_time IS an_time.
    IF dn_ap > an_ap { SET cheapest_node_time TO dn_time. }
    RETURN cheapest_node_time.
  } ELSE {
    LOCAL next_node_time IS an_time.
    IF dn_time < an_time { SET next_node_time TO dn_time. }
    RETURN next_node_time.
  }
}

FUNCTION determineSolarLaunchTime {
  LOCAL rel_inc IS bodyOrbitRelInc(TIME:SECONDS, SAT_I, SAT_LAN).

  IF ABS(90-rel_inc) < 89.5 {
    RETURN determineLaunchTimeToSolarNode().
  } ELSE IF ((SAT_AP-SAT_PE)/(SAT_AP+SAT_PE)) > 0.1 {
    RETURN determineLaunchTimeToSolarApoapsis().
  } ELSE {
    RETURN TIME:SECONDS.
  }
}

//LOCAL ri IS bodyOrbitRelInc(TIME:SECONDS, SAT_I, SAT_LAN).
//pOut("Relative inclination: " + ROUND(ri,2) + " degrees.").
CLEARVECDRAWS().
//UNTIL FALSE {
//determineTBD().
//  WAIT 60.
//  CLEARVECDRAWS().
//}

IF runMode() > 0 { logOn(). }

UNTIL runMode() = 99 {
LOCAL rm IS runMode().
IF rm < 0 {
  SET SHIP:NAME TO SAT_NAME.
  logOn().

  WAIT UNTIL cOk().
  RUNPATH("0:/lib_launch_geo.ks").

  LOCAL ap IS SAT_LAUNCH_AP.
  LOCAL launch_details IS calcLaunchDetails(ap,0,-1).
  LOCAL az IS launch_details[0].
  LOCAL launch_time IS determineSolarLaunchTime() - (3*3600).
//CLEARVECDRAWS().
  warpToLaunch(launch_time).
RCS ON.
  store("doLaunch(801," + ap + "," + az + ",0).").
  doLaunch(801,ap,az,0).

} ELSE IF rm < 50 {
  resume().

} ELSE IF rm > 100 AND rm < 150 {
  resume().

} ELSE IF MOD(rm,10) = 9 AND rm > 800 AND rm < 999 {
  hudMsg("Error state. Hit abort to switch to recovery mode: " + abortMode() + ".").
  steerSun().
  WAIT UNTIL MOD(runMode(),10) <> 9.

} ELSE IF rm = 801 {
  delResume().
RCS OFF.
  LOCAL transfer_ap IS SAT_AP.
  IF BODY <> SUN { SET transfer_ap TO ROUND(determineSolarTransferAP()) / UNIT_GM. }
pOut("Desired orbit AP      : " + SAT_AP + "Gm.").
pOut("Calculated transfer AP: " + transfer_ap + "Gm.").
  store("doTransfer(821, SAT_CAN_STAGE, SUN,"+transfer_AP+"*"+UNIT_GM+","+SAT_I+","+SAT_LAN+").").
  doTransfer(821, SAT_CAN_STAGE, SUN, transfer_AP*UNIT_GM, SAT_I, SAT_LAN).

} ELSE IF rm = 821 {
  delResume().
  IF doOrbitMatch2(SAT_CAN_STAGE,stageDV(),SAT_AP*UNIT_GM,SAT_PE*UNIT_GM,SAT_W,SAT_I,SAT_LAN) { runMode(822). }
  ELSE { runMode(829,821). }
} ELSE IF rm = 822 {
  //CLEARVECDRAWS().
  //determineTBD().
  WAIT UNTIL RCS. // TBD!
  IF doOrbitChange(SAT_CAN_STAGE,stageDV(),SAT_AP*UNIT_GM,SAT_PE*UNIT_GM,SAT_W) { runMode(831,821). }
  ELSE { runMode(829,822). }
  //CLEARVECDRAWS().
  //determineTBD().

} ELSE IF rm = 831 {
  hudMsg("Mission complete. Hit abort to switch back to mode: " + abortMode() + ".").
  steerSun().
  WAIT UNTIL runMode() <> 831.
}
}
