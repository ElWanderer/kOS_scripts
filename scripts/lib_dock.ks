@LAZYGLOBAL OFF.

pOut("lib_dock.ks v1.1.0 20160812").

FOR f IN LIST(
  "lib_rcs.ks",
  "lib_steer.ks"
) { RUNONCEPATH(loadScript(f)). }

GLOBAL DOCK_VEL IS 1.   // max translation velocity (m/s)
GLOBAL DOCK_DIST IS 50. // distance (m) between docking waypoints
GLOBAL DOCK_AVOID IS 10.// minimum close approach distance (m) between docking route and ship parts

GLOBAL DOCK_POINTS IS LIST().

GLOBAL S_FACE IS V(0,0,0).
GLOBAL S_NODE IS V(0,0,0).
GLOBAL T_FACE IS V(0,0,0).
GLOBAL T_NODE IS V(0,0,0).

FUNCTION changeDockParams
{
  PARAMETER vel IS 1, d IS 50, av IS 10.
  SET DOCK_VEL TO vel.
  SET DOCK_DIST TO d.
  SET DOCK_AVOID TO av.
}

FUNCTION setupPorts
{
  PARAMETER s_port, t_port.
  LOCK S_FACE TO s_port:PORTFACING:VECTOR.
  LOCK S_NODE TO s_port:NODEPOSITION.
  LOCK T_FACE TO t_port:PORTFACING:VECTOR.
  LOCK T_NODE TO t_port:NODEPOSITION.
}

FUNCTION clearPorts
{
  UNLOCK S_FACE.
  UNLOCK S_NODE.
  UNLOCK T_FACE.
  UNLOCK T_NODE.
}

FUNCTION readyPorts
{
  PARAMETER t.
  LOCAL ports IS LIST().
  FOR p IN t:DOCKINGPORTS { IF p:STATE = "Ready" AND p:TAG <> "DISABLED" { ports:ADD(p). } }
  RETURN ports.
}

FUNCTION hasReadyPort
{
  PARAMETER t.
  LOCAL np IS readyPorts(t):LENGTH.
  pOut(t:NAME + " has " + np + " available docking ports.").
  RETURN np > 0.
}

FUNCTION bestPort
{
  PARAMETER ports.
  PARAMETER face_vec, pos_vec.

  LOCAL best_port IS ports[0].
  LOCAL best_score IS 0.
  FOR p IN ports {
    LOCAL face_score IS VDOT(p:PORTFACING:VECTOR,face_vec).
    // a port facing backwards is prefered to one pointing sideways
    IF face_score < 0 { SET face_score TO -face_score * 0.8. }
    // distance score is small - used mainly as a tie-breaker where ports are facing the same way
    LOCAL pos_score IS -(p:NODEPOSITION-pos_vec):MAG / 10000.
    LOCAL score IS face_score + pos_score.
    IF score > best_score {
      SET best_port TO p.
      SET best_score TO score.
    }
  }
  RETURN best_port.
}

FUNCTION selectOurPort
{
  PARAMETER t.
  // prioritise pointing fowards
  LOCAL fwd IS FACING:FOREVECTOR.
  RETURN bestPort(readyPorts(SHIP),fwd,100 * fwd).
}

FUNCTION selectTargetPort
{
  PARAMETER t.
  IF t:POSITION:MAG < DOCK_DIST {
    // prioritise pointing towards our ship
    RETURN bestPort(readyPorts(t),-t:POSITION,-t:POSITION).
  } ELSE {
    // prioritise pointing towards the target's normal vector
    RETURN bestPort(readyPorts(t),VCRS(t:VELOCITY:ORBIT,t:POSITION-BODY:POSITION),-t:POSITION).
  }
}

FUNCTION checkRouteStep
{
  PARAMETER t, p1, p2.

  FOR p IN t:PARTS {
    LOCAL ang IS VANG(p2-p1,p:POSITION-p1).
    IF ang < 90 AND p:POSITION:MAG * SIN(ang) < DOCK_AVOID { RETURN FALSE. }
  }
  RETURN TRUE.
}

FUNCTION plotDockingRoute
{
  PARAMETER s_port,t_port.
  LOCAL t IS t_port:SHIP.
  LOCAL ok IS TRUE.
  DOCK_POINTS:CLEAR.
  pOut("Calculating docking route.").

  // are we within the DOCK_DIST and if so, are we on this side of the target craft?
  //   YES - plot a single waypoint in line with the target port facing, keeping our distance to target
  //   NO  - plot a waypoint DOCK_DIST out from the docking port. Plot route to this point
  LOCAL port_pos IS T_NODE - S_NODE.
  LOCAL port_ang IS VANG(T_FACE,-port_pos).
  IF port_pos:MAG < DOCK_DIST AND port_ang < 1 {
    // aligned with port
    pOut("Proceed directly to docking port.").
  } ELSE {
    LOCAL p1_dist IS DOCK_DIST.
    IF port_pos:MAG < DOCK_DIST {
      LOCAL temp_dist IS port_pos:MAG * SIN(port_ang).
      UNTIL checkRouteStep(t,S_NODE,temp_dist * T_FACE) OR temp_dist >= p1_dist {
        SET temp_dist TO temp_dist + 2.
      }
      SET p1_dist TO temp_dist.
    }
    LOCK POINT1 TO p1_dist * T_FACE.
    pOut("Adding first docking waypoint.").
    DOCK_POINTS:ADD(POINT1).

    IF NOT checkRouteStep(t,S_NODE,T_NODE+POINT1) {
      pOut("Route to first docking waypoint obstructed.").
      // plot avoiding route around target vessel
      LOCAL rot_ang IS 0.
      LOCK POINT2 TO DOCK_DIST * (ANGLEAXIS(rot_ang,POINT1) * VXCL(POINT1,T_NODE - S_NODE):NORMALIZED).

      UNTIL checkRouteStep(t,T_NODE+POINT1,T_NODE+POINT1+POINT2) {
        SET rot_ang TO rot_ang + 15.
        IF rot_ang >= 360 {
          SET rot_ang TO 0.
          SET p1_dist TO p1_dist * 2.
          DOCK_POINTS:CLEAR.
          LOCK POINT1 TO p1_dist * T_FACE.
          pOut("Doubling length of first docking waypoint.").
          DOCK_POINTS:ADD(POINT1).
        }
        LOCK POINT2 TO DOCK_DIST * (ANGLEAXIS(rot_ang,POINT1) * VXCL(POINT1,T_NODE - S_NODE):NORMALIZED).
      }
      pOut("Adding second docking waypoint.").
      DOCK_POINTS:ADD(POINT2).

      IF NOT checkRouteStep(t,S_NODE,T_NODE+POINT1+POINT2) {
        pOut("Route to second docking waypoint obstructed.").
        // TBD - we need at least one more waypoint.
        SET ok TO FALSE.
      }
    }
  }
  RETURN ok.
}

FUNCTION dockingVelForDist
{
  PARAMETER d.
  IF d < 0.1 { RETURN 0. }
  ELSE IF d < 2 { RETURN 0.2. }
  ELSE IF d < 5 { RETURN MIN(0.4,DOCK_VEL). }
  ELSE IF d < 8 { RETURN MIN(0.6,DOCK_VEL). }
  ELSE { RETURN DOCK_VEL. } 
}

FUNCTION followDockingRoute
{
  PARAMETER s_port,t_port.
  LOCAL t IS t_port:SHIP.

  UNTIL s_port:STATE <> "Ready" {
    LOCAL pos IS T_NODE.
    LOCAL pts IS DOCK_POINTS:LENGTH.
    LOCAL count IS 1.
    FOR p IN DOCK_POINTS {
      VECDRAW(pos + p,-p,RGB(0,0,0.8),"Docking Waypoint " +  count,1,TRUE).
      SET pos TO pos + p.
      SET count TO count + 1.
    }
    VECDRAW(S_NODE,pos,RGB(0.2,0,1),"Docking Waypoint " + count,1,TRUE).

    LOCAL v_diff IS SHIP:VELOCITY:ORBIT - t:VELOCITY:ORBIT.
    LOCAL pos_diff IS pos - S_NODE.

    LOCAL rcs_vec IS (dockingVelForDist(pos_diff:MAG) * pos_diff:NORMALIZED) - v_diff.

    VECDRAW(S_NODE,5 * v_diff,RGB(1,0,0),"Velocity difference",1,TRUE).
    VECDRAW(S_NODE,5 * rcs_vec,RGB(0,1,0),"Translate",1,TRUE).

    IF v_diff:MAG < 0.1 AND pos_diff:MAG < 0.1 AND pts > 0 {
      stopTranslation().
      pOut("Docking waypoint " + (pts + 1) + " reached.").
      DOCK_POINTS:REMOVE(pts - 1).
    } ELSE {
      doTranslation(rcs_vec, 2*rcs_vec:MAG).
    }

    WAIT 0.
    CLEARVECDRAWS().
  }
  pOut("Docking port has changed state - ending docking sequence.").
  stopTranslation().
  RETURN TRUE.
}

FUNCTION doDocking
{
  PARAMETER t.

  pOut("Preparing to dock with " + t:NAME).
  LOCAL ok IS TRUE.

  IF NOT hasReadyPort(SHIP) OR NOT hasReadyPort(t) { RETURN FALSE. }

  LOCAL s_port IS selectOurPort(t).
  s_port:CONTROLFROM.
  LOCAL t_port IS selectTargetPort(t).
  setupPorts(s_port,t_port).

  IF ok { SET ok TO plotDockingRoute(s_port,t_port). }

  IF ok {
    steerTo({ RETURN -T_FACE. }).
    WAIT UNTIL steerOk().
    enableRCS().
    SET ok TO followDockingRoute(s_port,t_port).
  }
  steerOff().
  disableRCS().
  clearPorts().

  RETURN ok.
}
