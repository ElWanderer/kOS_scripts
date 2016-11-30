@LAZYGLOBAL OFF.
pOut("lib_rendezvous.ks v1.3.0 20161130").

FOR f IN LIST(
  "lib_runmode.ks",
  "lib_orbit_match.ks",
  "lib_orbit.ks",
  "lib_burn.ks",
  "lib_orbit_phase.ks",
  "lib_hoh.ks",
  "lib_ca.ks"
) { RUNONCEPATH(loadScript(f)). }

GLOBAL RDZ_FN IS "rdz.ks".

GLOBAL RDZ_VEC IS SHIP:VELOCITY:ORBIT.
GLOBAL RDZ_DIST IS 75.
GLOBAL RDZ_MAX_ORBITS IS 5.

GLOBAL RDZ_PHASE_PERIOD IS 0.
GLOBAL RDZ_CA_DIST IS 5000.
GLOBAL RDZ_CA IS "RDZ_CA".
setTime(RDZ_CA).

GLOBAL RDZ_THROTTLE IS 0.

FUNCTION storeRdzDetails
{
  store("SET RDZ_PHASE_PERIOD TO " + RDZ_PHASE_PERIOD + ".", RDZ_FN).
  append("setTime(RDZ_CA," + TIMES[RDZ_CA] + ").", RDZ_FN).
  append("SET RDZ_CA_DIST TO " + RDZ_CA_DIST + ".", RDZ_FN).
}

FUNCTION rdzETA
{
  RETURN -diffTime(RDZ_CA).
}

FUNCTION changeRDZ_DIST
{
  PARAMETER d.
  SET RDZ_DIST TO d.
}

FUNCTION changeRDZ_MAX_ORBITS
{
  PARAMETER n.
  SET RDZ_MAX_ORBITS TO n.
}

FUNCTION orbitTAOffset
{
  PARAMETER orb1, orb2.
  LOCAL ta_offset IS (orb2:LAN + orb2:ARGUMENTOFPERIAPSIS) - (orb1:LAN + orb1:ARGUMENTOFPERIAPSIS).
  RETURN mAngle(ta_offset).
}

FUNCTION findOtherOrbitTA
{
  // given a ship orbit true anomaly v, target orbit true anomaly is v - ta_offset
  PARAMETER orb1, orb2.
  PARAMETER orb1_ta.
  LOCAL ta_offset IS orbitTAOffset(orb1,orb2).
  RETURN mAngle(orb1_ta - ta_offset).
}

FUNCTION minSeparation
{
  PARAMETER orb1, orb2.
  PARAMETER start_ta, end_ta, scale_ta.

  LOCAL minsep IS 9999999.
  LOCAL s_ta IS 0.
  LOCAL t_ta IS 0.

  LOCAL ta_diff IS orbitTAOffset(orb1,orb2).
  LOCAL ta IS start_ta.
  IF end_ta < start_ta { SET end_ta TO end_ta + 360. }
  UNTIL ta > end_ta {
    LOCAL ta1 IS mAngle(ta).
    LOCAL ta2 IS mAngle(ta - ta_diff).
    LOCAL sep IS radiusAtTA(orb1, ta1) - radiusAtTA(orb2, ta2).
    IF ABS(sep) < ABS(minsep) {
      SET minsep TO sep.
      SET s_ta TO ta1.
      SET t_ta TO ta2.
    }
    SET ta TO ta + scale_ta.
  }
  RETURN LIST(minsep,s_ta,t_ta).
}

FUNCTION findOrbitMinSeparation
{
  PARAMETER orb1,orb2.

  LOCAL sepDetails IS LIST(0,0,0).
  // final accuracy between 0.1 and 1 second
  LOCAL min_step IS (36 / orb1:PERIOD).
  LOCAL start_ta IS 0.
  LOCAL end_ta IS 360.
  LOCAL step IS 10.
  UNTIL step < min_step {
    SET sepDetails TO minSeparation(orb1,orb2,start_ta,end_ta,step).
    LOCAL minsep IS sepDetails[0].
    LOCAL minsep_ta IS sepDetails[1].
    SET start_ta TO mAngle(minsep_ta - step).
    SET end_ta TO mAngle(minsep_ta + step).
    SET step TO step / 10.
  }
  RETURN sepDetails.
}

FUNCTION findTargetMinSeparation
{
  PARAMETER t.
  RETURN findOrbitMinSeparation(ORBITAT(SHIP,TIME:SECONDS),ORBITAT(t,TIME:SECONDS)).
}

FUNCTION rdzBestSpeed
{
  PARAMETER d, cv, sdv IS stageDV().
  IF d < 2.5 { RETURN 0. }
  LOCAL bd IS cv * burnTime(cv, sdv).
  IF d < MAX(25, bd) { RETURN 0.5. }
  IF d < MAX(50, 2 * bd) { RETURN 1. }
  IF d < MAX(100, 3 * bd) { RETURN 3. }
  IF d < MAX(250, 4 * bd) { RETURN 5. }
  RETURN MAX(cv, 9).
}

FUNCTION rdzOffsetVector
{
  PARAMETER t.
  LOCAL t_norm IS craftNormal(t,TIME:SECONDS):NORMALIZED.
  LOCAL t_off IS ((8 * t_norm) + VCRS(t:POSITION,t_norm):NORMALIZED):NORMALIZED * RDZ_DIST.
  IF (t:POSITION + t_off):MAG < (t:POSITION - t_off):MAG { RETURN t_off. }
  ELSE { RETURN -t_off. }
}

FUNCTION rdzApproach
{
  PARAMETER t.
  LOCAL ok IS TRUE.
  SET RDZ_THROTTLE TO 0.
  LOCK THROTTLE TO RDZ_THROTTLE.
  SET RDZ_VEC TO FACING:FOREVECTOR.
  steerTo({RETURN RDZ_VEC.}).

  pOut("Beginning rendezvous approach.").
  pDV().
  LOCAL offset_vec IS rdzOffsetVector(t).

  UNTIL NOT ok {
    IF t:POSITION:MAG > MAX(500,RDZ_DIST * 5) { SET offset_vec TO rdzOffsetVector(t). }
    LOCAL p_offset IS t:POSITION + offset_vec.
    LOCAL v_diff IS SHIP:VELOCITY:ORBIT - t:VELOCITY:ORBIT.

    IF p_offset:MAG < 25 AND v_diff:MAG < 0.15 { SET RDZ_THROTTLE TO 0. BREAK. }

    LOCAL sdv IS stageDV().
    LOCAL ideal_v_diff IS rdzBestSpeed(p_offset:MAG,v_diff:MAG,sdv) * p_offset:NORMALIZED.
    SET RDZ_VEC TO ideal_v_diff - v_diff.

    LOCAL throt_on IS (RDZ_THROTTLE > 0).

    LOCAL rdz_dot IS VDOT(FACING:FOREVECTOR,RDZ_VEC:NORMALIZED).
    IF NOT throt_on AND RDZ_VEC:MAG > ideal_v_diff:MAG / 3 AND rdz_dot >= 0.995 { SET throt_on TO TRUE. }
    ELSE IF throt_on AND rdz_dot < 0.95 { SET throt_on TO FALSE. }

    VECDRAW(V(0,0,0),p_offset,RGB(0,0,1),"To target (offset)",1,TRUE).
    VECDRAW(V(0,0,0),5 * v_diff,RGB(1,0,0),"Relative velocity",1,TRUE).
    VECDRAW(V(0,0,0),5 * ideal_v_diff,RGB(1,0,1),"Ideal relative velocity",1,TRUE).

    IF throt_on {
      IF sdv < RDZ_VEC:MAG {
        pOut("Not enough delta-v remaining for rendezvous.").
        SET ok TO FALSE.
        SET RDZ_THROTTLE TO 0.
      } ELSE {
        SET RDZ_THROTTLE TO burnThrottle(burnTime(RDZ_VEC:MAG, sdv)).
      }
      VECDRAW(V(0,0,0),5 * RDZ_VEC,RGB(0,1,0),"Thrust vector",1,TRUE).
    } ELSE {
      SET RDZ_THROTTLE TO 0.
      VECDRAW(V(0,0,0),5 * RDZ_VEC,RGB(0.5,0.5,0.5),"Steer vector",1,TRUE).
    }

    WAIT 0.
    CLEARVECDRAWS().
  }

  LOCK THROTTLE TO 0. WAIT 0.
  pDV().
  pOut("Ending rendezvous approach.").
  dampSteering().
  RETURN ok.
}

FUNCTION nodeRdzInclination
{
  PARAMETER t, u_time IS bufferTime().
  removeAllNodes().
  IF craftRelInc(t,u_time) > 0.05 {
    pOut("Adding node to match inclination with rendezvous target.").
    LOCAL inode IS nodeIncMatchTarget(t,u_time).
    addNode(inode).
    RETURN TRUE.
  }
  RETURN FALSE.
}

FUNCTION nodeRdzHohmann
{
  PARAMETER t, u_time IS bufferTime().

  LOCAL hnode IS nodeHohmann(t, u_time).

  // TBD - run some kind of node improvement?

  addNode(hnode).

  RETURN TRUE.
}

FUNCTION nodeForceIntersect
{
  PARAMETER t, u_time IS bufferTime().

  removeAllNodes().
  LOCAL sepDetails IS findTargetMinSeparation(t).
  LOCAL minsep IS sepDetails[0].
  IF ABS(minsep) > 2000 {
    LOCAL s_orbit IS ORBITAT(SHIP,u_time).
    LOCAL t_orbit IS ORBITAT(t,u_time).
    LOCAL minsep_ta IS sepDetails[1].
    LOCAL minsep_t_ta IS sepDetails[2].

    // either burn opposite closest approach
    LOCAL opp_ca_time IS u_time + secondsToTA(SHIP,u_time,mAngle(minsep_ta + 180)).
    LOCAL n1 IS nodeAlterOrbit(opp_ca_time, radiusAtTA(t_orbit,minsep_t_ta) - BODY:RADIUS).
    LOCAL n1_dv IS nodeDV(n1).

    // or burn opposite target ap
    LOCAL s_ta_at_t_pe IS findOtherOrbitTA(t_orbit,s_orbit,0).
    LOCAL opp_ap_time IS u_time + secondsToTA(SHIP,u_time,s_ta_at_t_pe).
    LOCAL n2 IS nodeAlterOrbit(opp_ap_time, t_orbit:APOAPSIS).
    LOCAL n2_dv IS nodeDV(n2).

    // or burn opposite target pe
    LOCAL s_ta_at_t_ap IS findOtherOrbitTA(t_orbit,s_orbit,180).
    LOCAL opp_pe_time IS u_time + secondsToTA(SHIP,u_time,s_ta_at_t_ap).
    LOCAL n3 IS nodeAlterOrbit(opp_pe_time, t_orbit:PERIAPSIS).
    LOCAL n3_dv IS nodeDV(n3).

    If n1_dv <= MIN(n2_dv,n3_dv) { addNode(n1). }
    ELSE IF n2_dv <= MIN(n1_dv,n3_dv) { addNode(n2). } 
    ELSE { addNode(n3). }
    RETURN TRUE.
  }
  RETURN FALSE.
}

FUNCTION nodePhasingOrbit
{
  PARAMETER t, u_time IS bufferTime().

  removeAllNodes().
  LOCAL sepDetails IS findTargetMinSeparation(t).
  LOCAL minsep IS sepDetails[0].
  LOCAL minsep_ta IS sepDetails[1].
  LOCAL minsep_t_ta IS sepDetails[2].
  LOCAL s_int_eta IS secondsToTA(SHIP,u_time,minsep_ta).
  LOCAL t_int_eta IS secondsToTA(t,u_time,minsep_t_ta).
  LOCAL eta_diff IS ABS(s_int_eta - t_int_eta).

  LOCAL s_orbit IS ORBITAT(SHIP,u_time).
  LOCAL s_p IS s_orbit:PERIOD.
  LOCAL t_orbit IS ORBITAT(t,u_time).
  LOCAL t_p IS t_orbit:PERIOD.

  IF eta_diff < 10 {
    SET RDZ_PHASE_PERIOD TO s_p.
    setTime(RDZ_CA,u_time + s_int_eta).
    storeRdzDetails().
    RETURN FALSE.
  }

  LOCAL min_alt IS 15000.
  IF BODY:ATM:EXISTS { SET min_alt TO BODY:ATM:HEIGHT + 5000. }
  SET min_alt TO MIN(min_alt,t:PERIAPSIS).
  LOCAL max_alt IS BODY:SOIRADIUS - (BODY:RADIUS * 5).

  LOCAL min_p IS orbitPeriodForAlt(BODY,s_orbit,minsep_ta,min_alt).
  LOCAL max_p IS orbitPeriodForAlt(BODY,s_orbit,minsep_ta,max_alt).

  LOCAL phase_p IS s_p.
  LOCAL orbit_num IS 1.

  LOCAL inc_diff IS t_p - eta_diff.
  LOCAL dec_diff IS eta_diff.
  IF t_int_eta > s_int_eta {
    SET inc_diff TO eta_diff.
    SET dec_diff TO t_p - eta_diff.
  }

  LOCAL inc_p IS t_p + inc_diff.
  LOCAL inc_orbit_num IS 1.
  UNTIL inc_p <= s_p OR inc_orbit_num >= RDZ_MAX_ORBITS {
    SET inc_orbit_num TO inc_orbit_num + 1.
    SET inc_p TO t_p + (inc_diff / inc_orbit_num).
  }
  IF inc_p < min_p OR inc_p > max_p { SET inc_p TO -1. }

  LOCAL dec_p IS t_p - dec_diff.
  LOCAL dec_orbit_num IS 1.
  UNTIL dec_p >= s_p OR dec_orbit_num >= RDZ_MAX_ORBITS {
    SET dec_orbit_num TO dec_orbit_num + 1.
    SET dec_p TO t_p - (dec_diff / dec_orbit_num).
  }
  IF dec_p < min_p OR dec_p > max_p { SET dec_p TO -1. }

  IF dec_p < 0 AND inc_p < 0 {
    pOut("ERROR determining phase period.").
    SET phase_p TO 0.
    SET orbit_num TO 0.
  } ELSE IF dec_p > 0 AND (inc_p < 0 OR s_p < t_p) {
    SET phase_p TO dec_p.
    SET orbit_num TO dec_orbit_num.
  } ELSE {
    SET phase_p TO inc_p.
    SET orbit_num TO inc_orbit_num.
  }

  pOut("Selected phase period: " + ROUND(phase_p,1) + "s. Orbits: " + orbit_num).

  SET RDZ_PHASE_PERIOD TO phase_p.
  setTime(RDZ_CA,u_time + s_int_eta + (orbit_num * phase_p)).
  storeRdzDetails().

  pOut("Calculating node to set orbit period to " + ROUND(RDZ_PHASE_PERIOD,1) + "s.").

  LOCAL opp_alt IS orbitAltForPeriod(BODY,s_orbit,minsep_ta,RDZ_PHASE_PERIOD).
  LOCAL pnode IS nodeAlterOrbit(u_time + s_int_eta, opp_alt).
  addNode(pnode).

  RETURN TRUE.
}

FUNCTION recalcCA
{
  PARAMETER t.
  LOCAL slice IS MIN(SHIP:ORBIT:PERIOD / 16, rdzETA()).
  LOCAL ca_time IS targetCA(t,TIMES[RDZ_CA]-slice,TIMES[RDZ_CA]+slice,0.1,10).
  setTime(RDZ_CA,ca_time).
  SET RDZ_CA_DIST TO ROUND(targetDist(t,ca_time)).
  pOut("Closest approach: " + RDZ_CA_DIST + "m in " + ROUND(TIMES[RDZ_CA]-TIME:SECONDS) + "s.").
  storeRdzDetails().
}

FUNCTION passingCA
{
  PARAMETER t, min_dist IS RDZ_CA_DIST * 2.
  LOCAL ts IS TIME:SECONDS.
  LOCAL p_diff IS POSITIONAT(t,ts) - POSITIONAT(SHIP,ts).
  RETURN p_diff:MAG < min_dist AND VDOT(p_diff,VELOCITYAT(SHIP,ts):ORBIT - VELOCITYAT(t,ts):ORBIT) < 0.2.
}

FUNCTION warpToCA
{
  PARAMETER t.
  IF rdzETA() > 99 {
    steerSun().
    WAIT UNTIL steerOk().
    steerOff().

    LOCAL warp_time IS TIMES[RDZ_CA] - 90.
    pOut("Warping to closest approach.").
    doWarp(warp_time, passingCA@:BIND(t)).
  }
}

FUNCTION doRendezvous
{
  PARAMETER exit_mode, t, can_stage.

  LOCAL LOCK rm TO runMode().

  pOut("Attempting rendezvous with " + t:NAME).

  IF rm < 401 OR rm > 449 { runMode(401). }
  resume(RDZ_FN).

UNTIL rm = exit_mode
{
  IF rm = 401 {
    // TBD - what was meant to go here?
    runMode(411).
  } ELSE IF rm = 411 {
    // add node to match inclination if necessary
    IF nodeRdzInclination(t) { runMode(412). } ELSE { runMode(415). }
  } ELSE IF rm = 412 {
    IF NOT HASNODE { runMode(411). }
    ELSE IF execNode(can_stage) { runMode(411). }
    ELSE { runMode(419,412). }
  } ELSE IF rm = 415 {
// TBD - is a Hohmann transfer appropriate? (low eccentricity, large difference in semimajoraxis):
//   yes - calculate a single transfer, avoiding other bodies (421)
//   no  - calculate an intersect and a phasing orbit (431)
    // calculate intersect and then a phasing orbit    
    runMode(431).

//  } ELSE IF rm = 421 {
//  Hohmann TBD

  } ELSE IF rm = 431 {
    // check if we get close to the target's orbit, if not force intersect
    IF nodeForceIntersect(t) { runMode(432). } ELSE { runMode(433). }
  } ELSE IF rm = 432 {
    IF NOT HASNODE { runMode(431). }
    ELSE IF execNode(can_stage) { runMode(433). }
    ELSE { runMode(439,432). }
  } ELSE IF rm = 433 {
    // calculate phasing orbit, store details, generate node
    IF nodePhasingOrbit(t) { runMode(434). } ELSE { runMode(441). }
  } ELSE IF rm = 434 {
    IF NOT HASNODE { runMode(433). }
    ELSE IF execNode(can_stage) { runMode(435). }
    ELSE { runMode(439,434). }
  } ELSE IF rm = 435 {
    // tweak orbital period to match required period closely
    tweakPeriod(RDZ_PHASE_PERIOD).
    runMode(441).

  } ELSE IF rm = 441 {
    recalcCA(t).
    runMode(442).
  } ELSE IF rm = 442 {
    warpToCA(t).
    runMode(445).

  } ELSE IF rm = 445 {
    IF rdzApproach(t) { runMode(exit_mode). } ELSE { runMode(449,445). }

  } ELSE IF MOD(rm,10) = 9 AND rm > 400 AND rm < 450 {
    hudMsg("Error state. Hit abort to switch to recovery mode: " + abortMode() + ".").
    steerSun().
    WAIT UNTIL MOD(runMode(),10) <> 9.
  } ELSE {
    pOut("Rendezvous - unexpected run mode: " + rm).
    runMode(449,401).
  }

  WAIT 0.
}

}
