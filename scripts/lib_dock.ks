@LAZYGLOBAL OFF.
pOut("lib_dock.ks v1.2.0 20161102").

FOR f IN LIST(
  "lib_rcs.ks",
  "lib_steer.ks"
) { RUNONCEPATH(loadScript(f)). }

GLOBAL DOCK_VEL IS 1.       // max translation velocity (m/s)
GLOBAL DOCK_DIST IS 50.     // distance (m) between docking waypoints
GLOBAL DOCK_AVOID IS 10.    // minimum close approach distance (m) between docking route and ship parts
GLOBAL DOCK_START_MONO IS 5.// minimum units of monoprop for us to start docking
GLOBAL DOCK_LOW_MONO IS 2.  // minimum units of monoprop - drop below this and we cancel docking

GLOBAL DOCK_POINTS IS LIST().
GLOBAL DOCK_ACTIVE_WP IS V(0,0,0).
GLOBAL S_FACE IS V(0,0,0).
GLOBAL S_NODE IS V(0,0,0).
GLOBAL T_FACE IS V(0,0,0).
GLOBAL T_NODE IS V(0,0,0).

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
  pOut(t:NAME + " has " + np + " available docking port(s).").
  RETURN np > 0.
}

FUNCTION bestPort
{
  PARAMETER ports, face_vec, pos_vec.

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

FUNCTION activeDockingPoint
{
  PARAMETER t, do_draw IS TRUE, wait_then_blank IS -1.
  
  LOCAL ok IS TRUE.
  IF do_draw { CLEARVECDRAWS(). }

  LOCAL pos IS T_NODE.
  LOCAL count IS 1.
  LOCAL vec_colour IS RGB(1,1,1).
  FOR p IN DOCK_POINTS {
    IF count = 1 OR checkRouteStep(t,pos+p,pos) { SET vec_colour TO RGB(0,0,1). }
    ELSE { SET ok TO FALSE. SET vec_colour TO RGB(1,0,0). }
    IF do_draw { VECDRAW(pos + p,-p,vec_colour,"Waypoint " +  count,1,TRUE). }
    SET pos TO pos + p.
    SET count TO count + 1.
  }
  IF do_draw {
    IF count = 1 OR checkRouteStep(t,S_NODE,pos) { SET vec_colour TO RGB(0,1,1). }
    ELSE { SET ok TO FALSE. SET vec_colour TO RGB(1,0,0). }
    VECDRAW(S_NODE,pos - S_NODE,vec_colour,"Waypoint " + count + " (ACTIVE)",1,TRUE).
  }
  IF do_draw AND wait_then_blank >= 0 {
    WAIT wait_then_blank.
    CLEARVECDRAWS().
  }
  IF ok { SET DOCK_ACTIVE_WP TO pos. }
  RETURN ok.
}

FUNCTION plotDockingRoute
{
  PARAMETER s_port,t_port,do_draw IS TRUE.
  LOCAL t IS t_port:SHIP.
  LOCAL ok IS TRUE.
  DOCK_POINTS:CLEAR.
  pOut("Calculating docking route.").

  // if within DOCK_DIST of port and within 1 degree of angle to port, proceed directly to port
  // else if within DOCK_DIST of port
  //   - plot a single waypoint in line with the target port facing, keeping our distance to target
  //   - if route to this waypoint is obstructed, extend it until we are clear or the length reaches DOCK_DIST
  // else, plot a waypoint in line with the target port, DOCK_DIST out
  //
  // if we plotted a waypoint and the route to it is obstructed, place another leg at 90 degrees to the first leg.
  // if this leg is obstructed, rotate it around (using the first leg as the axis) until clear or full circle
  // if we went full circle, go back and double the length of the first leg, then repeat placement of second leg
  // this assumes we will eventually find a clear second leg
  //
  // if we plotted a second waypoint and the route to it is obstructed, place another leg at 90 degrees to the second
  // if this leg or our route to it is obstructed, rotate it around (using the first leg as the axis) until clear
  // or full circle. If we go full circle, double the length and go around again.
  // This should eventually result in a clear route, but it may not, in which case we'll return FALSE.
    LOCAL port_pos IS T_NODE - S_NODE.
  LOCAL port_ang IS VANG(T_FACE,-port_pos).
  IF port_pos:MAG < DOCK_DIST AND port_ang < 1 {
    // aligned with port
    pOut("Proceed directly to docking port.").
  } ELSE {
    LOCAL p1_dist IS DOCK_DIST.
    IF port_pos:MAG < DOCK_DIST {
      LOCAL temp_dist IS port_pos:MAG * SIN(port_ang).
      UNTIL checkRouteStep(t,S_NODE,T_NODE + (temp_dist * T_FACE)) OR temp_dist >= p1_dist {
        SET temp_dist TO temp_dist + 2.
      }
      SET p1_dist TO temp_dist.
    }
    LOCK POINT1 TO p1_dist * T_FACE.
    pOut("Adding first docking waypoint.").
    DOCK_POINTS:ADD(POINT1).
    activeDockingPoint(t,do_draw,1).

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
          activeDockingPoint(t,do_draw,1).
        }
        LOCK POINT2 TO DOCK_DIST * (ANGLEAXIS(rot_ang,POINT1) * VXCL(POINT1,T_NODE - S_NODE):NORMALIZED).
      }
      pOut("Adding second docking waypoint.").
      DOCK_POINTS:ADD(POINT2).
      activeDockingPoint(t,do_draw,1).

      IF NOT checkRouteStep(t,S_NODE,T_NODE+POINT1+POINT2) {
        pOut("Route to second docking waypoint obstructed.").
        // Plot third waypoint that allows obstacle-free course between ship and
        // second waypoint, if one can be found
        LOCAL p3_dist IS -4.
        LOCAL rot_ang IS 0.
        LOCK POINT3 TO p3_dist * (ANGLEAXIS(rot_ang,POINT2) * T_FACE):NORMALIZED.
        UNTIL (checkRouteStep(t,T_NODE+POINT1+POINT2,T_NODE+POINT1+POINT2+POINT3) AND
               checkRouteStep(t,S_NODE,T_NODE+POINT1+POINT2+POINT3)) OR NOT ok {
          SET rot_ang TO rot_ang + 45.
          IF rot_ang >= 360 {
            SET rot_ang TO 0.
            SET p3_dist TO p3_dist * 2.
          }
          LOCK POINT3 TO p3_dist * (ANGLEAXIS(rot_ang,POINT2) * T_FACE):NORMALIZED.
          IF ABS(p3_dist) > 500 {
            pOut("ERROR: third docking waypoint obstructed.").
            SET ok TO FALSE.
          }
        }
        pOut("Adding third docking waypoint.").
        DOCK_POINTS:ADD(POINT3).
        activeDockingPoint(t,do_draw,1).
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

FUNCTION checkDockingOkay
{
  PARAMETER t, do_draw, v_diff, is_start.

  IF NOT RCS {
    hudMsg("ABORT: RCS disengaged.").
    IF v_diff:MAG >= 0.1 {
      hudMsg("Re-engaging RCS to kill relative velocity.").
      toggleRCS(TRUE).
    }
  } ELSE IF NOT activeDockingPoint(t, do_draw) {
    hudMsg("ERROR: docking route obstruction.").
  } ELSE IF NOT is_start AND SHIP:MONOPROPELLANT < DOCK_LOW_MONO {
    hudMsg("ERROR: monoproprellant very low.").
  } ELSE IF is_start AND SHIP:MONOPROPELLANT < DOCK_START_MONO {
    hudMsg("ERROR: monoproprellant too low.").
  } ELSE {
    IF is_start AND SHIP:MONOPROPELLANT < (1.5 * DOCK_START_MONO) {
      hudMsg("WARNING: monoproprellant low.").
    }
    RETURN TRUE.
  }

  RETURN FALSE.
}

FUNCTION followDockingRoute
{
  PARAMETER s_port,t_port,do_draw IS TRUE.
  LOCAL ok IS TRUE.
  LOCAL t IS t_port:SHIP.
  LOCAL LOCK v_diff TO SHIP:VELOCITY:ORBIT - t:VELOCITY:ORBIT.

  hudMsg("Docking with " + t:NAME).
  LOCAL ok IS checkDockingOkay(t, do_draw, v_diff, TRUE).

  UNTIL s_port:STATE <> "Ready" OR NOT ok {
    LOCAL pos_diff IS DOCK_ACTIVE_WP - S_NODE.
    LOCAL rcs_vec IS (dockingVelForDist(pos_diff:MAG) * pos_diff:NORMALIZED) - v_diff.

    IF do_draw {
      VECDRAW(S_NODE,5 * v_diff,RGB(1,0,0),"Relative velocity",1,TRUE).
      VECDRAW(S_NODE,5 * rcs_vec,RGB(0,1,0),"Translate",1,TRUE).
    }

    IF v_diff:MAG < 0.1 AND pos_diff:MAG < 0.1 AND DOCK_POINTS:LENGTH > 0 {
      stopTranslation().
      DOCK_POINTS:REMOVE(DOCK_POINTS:LENGTH-1).
    } ELSE { doTranslation(rcs_vec, 2*rcs_vec:MAG). }

    WAIT 0.
    SET ok TO checkDockingOkay(t, do_draw, v_diff, FALSE).
  }
  IF ok {
    pOut("Docking port state change. Ending docking sequence.").
    hudMsg("Docking port magnets active.").
  } ELSE {
    UNTIL v_diff:MAG < 0.1 OR SHIP:MONOPROPELLANT < 0.2 { doTranslation(-v_diff). }
  }
  stopTranslation().
  IF do_draw { CLEARVECDRAWS(). }
  RETURN ok.
}

FUNCTION doDocking
{
  PARAMETER t, do_draw IS TRUE.

  pOut("Preparing to dock with " + t:NAME).
  LOCAL ok IS TRUE.

  IF NOT hasReadyPort(SHIP) OR NOT hasReadyPort(t) { RETURN FALSE. }

  LOCAL s_port IS selectOurPort(t).
  s_port:CONTROLFROM.
  LOCAL t_port IS selectTargetPort(t).
  setupPorts(s_port,t_port).

  IF ok { SET ok TO plotDockingRoute(s_port,t_port,do_draw). }

  IF ok {
    steerTo({ RETURN -T_FACE. }).
    WAIT UNTIL steerOk().
    toggleRCS(TRUE).
    SET ok TO followDockingRoute(s_port,t_port,do_draw).
  }
  steerOff().
  clearPorts().
  toggleRCS(FALSE).

  RETURN ok.
}
