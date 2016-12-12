## lib\_dock (docking library)

### Description

A library for docking the active vessel with a target, using the RCS translation functions.

#### Assumptions

The active vessel doing the docking must have RCS.

Docking ports are assumed to face out into open space. Any that point back towards the same vessel could cause problems if selected i.e. collisions or an inability to plot a valid route.

The state change on a docking port is assumed to herald a successful docking. In my testing so far, this has always been the case, but it is conceivable that two large vessels docking at an awkward angle may bounce off each other despite the magnets activating.

At the time of writing, the docking waypoints that are created during docking are fixed. This has the advantage of reducing monopropellent expenditure, but has the disadvantage of not handling a target that is rotating. It is recommended that a docking target be controlled and pointed in a set direction, rather than being allowed to drift. [Issue #84](https://github.com/ElWanderer/kOS_scripts/issues/84) exists for making the waypoints rotate with the target, but the initial solution to this introduced other issues.

### Requirements

 * `lib_rcs.ks`
 * `lib_steer.ks`

### Global variable reference

#### `DOCK_VEL`

The velocity at which the active vessel will translate between docking waypoints. Higher values speed up docking, at the cost of monopropellant (and the higher chance of a collision).

Note - close to docking waypoints, the velocity is stepped down. `DOCK_VEL` does not define the speed at which two vessels will attempt to push their docking ports together!

The initial value is `1`m/s.

#### `DOCK_DIST`

The default distance between docking waypoints. This may need to be increased for docking with a large craft, or could be reduced considerably if docking with a small probe.

The initial value is `50`m.

#### `DOCK_AVOID`

The minimum distance that the plotted docking route must maintain from all parts on the target craft. This may need to be increased for docking together larger vessels. It may also need to be increased if parts are particularly large, as we can only calculate the distance to the part's centre.

The initial value is `10`m.

#### `DOCK_START_MONO`

This sets a minimum level of monopropellant that the active vessel must have before the docking process will start. The aim of this is to avoid a vessel running out of monopropellant mid-docking, resulting in a collision. Naturally, the amount of monopropellant needed will vary wildly depending on the size of the craft and the initial alignment with the target.

The initial value is `5` units.

#### `DOCK_LOW_MONO`

This sets a minimum level of monopropellant that the active vessel must maintain during docking. If the amount falls below this level, the docking will be aborted and the remaining monopropellant used to match velocity with the target, to prevent a collision and keep the docking craft where it can be reached.

The initial value is `2` units.

#### `DOCK_POINTS`

A stored list of docking waypoints. As part of the docking procedure, this list may be populated with a set of points. As the active vessel reaches each one, they will be removed. Once the list is empty, the vessel will proceed directly to the target docking port.

Note - docking points are stored as vectors starting from the target's docking port.

#### `DOCK_ACTIVE_WP`

This stores a vector pointing to the currently active docking waypoint.

It is initialised as a zero vector, `V(0,0,0)`.

#### `S_FACE`

This stores a vector that points outwards from the active vessel's docking port. This makes use of the `PORTFACING` suffix that docking port parts have access to.

It is initialised as a zero vector, `V(0,0,0)`.

#### `S_NODE`

This stores a position vector that points to the active vessel's docking port. This makes use of the `NODEPOSITION` suffix that docking port parts have access to.

It is initialised as a zero vector, `V(0,0,0)`.

#### `T_FACE`

This stores a vector that points outwards from the target vessel's docking port. This makes use of the `PORTFACING` suffix that docking port parts have access to.

It is initialised as a zero vector, `V(0,0,0)`.

#### `T_NODE`

This stores a position vector that points to the target vessel's docking port. This makes use of the `NODEPOSITION` suffix that docking port parts have access to.

It is initialised as a zero vector, `V(0,0,0)`.

### Function reference

#### `setupPorts(ship_port, target_port)`

This sets up four `LOCK` statements to define `S_FACE`, `S_NODE`, `T_FACE` and `T_NODE`. By this point, the two docking ports must have been selected, as they are the input parameters.

#### `clearPorts()`

This function unlocks the four `LOCK` statements set up by `setupPorts()`.

#### `readyPorts(craft)`

This returns a list of available docking ports on the input `craft`.

Available ports have a `STATE` of `READY`. Ports can be made unavailable (and so prevented from being returned in this list) by tagging them as `DISABLED`.

#### `hasReadyPort(craft)`

This function calls `readyPorts(craft)` and counts the number of ports in the returned list. It then returns `TRUE` if the length was non-zero, `FALSE` if the list was empty.

#### `bestPort(port_list, facing_vector, position_vector)`

This function takes a list of ports and returns the 'best' one to use for docking, based on the input `facing_vector` and `position_vector`.

The function loops through each port in the list, assigning a score. The port with the highest score is returned.

The scoring system primarily goes by facing:

    // p is the docking port
    LOCAL score IS VDOT(p:PORTFACING:VECTOR,facing_vector).
    IF score < 0 { SET score TO -score * 0.8. }

A port that is facing in the same way as the input `facing_vector` will score very highly. A port that is facing directly away will also score fairly highly. This is deliberately done to prioritise them over side-facing ports. Side-facing ports are more likely to be awkward to use as the main port on the active vessel. Forward and backward-facing ports on the target are easier to dock with if we have set the `facing_vector` towards the the orbit normal vector. That's because the normal direction won't change during the craft's orbit, whereas a port facing prograde would slowly be rotated around the vessel during the orbit.

The score is penalised slightly, based on the distance between the docking port and the input `position_vector`. Nearer ports have a smaller penalty. This is mainly used as a tie-breaker where multiple ports are facing the same way:

    SET score TO score - ((p:NODEPOSITION-position_vector):MAG / 10000).

#### `selectOurPort(target_craft)`

This function chooses which docking port on the active vessel to use for docking. This is done by passing the list of available ports (returned by `readyPorts(SHIP)`) into `bestPort()`. The vessel's current facing vector is passed in, along with a position vector `100`m in front of the vessel's centre of mass. Together should prioritise docking ports that are pointing forwards and that are at the front of the active vessel.

#### `selectTargetPort(target_craft)`

This function chooses which docking port on the target vessel to use for docking with. This is done by passing the list of available ports (returned by `readyPorts(target_craft)`) into `bestPort()`. 

There are two different set of scoring criteria used:
* if the `target_craft` is within `DOCK_DIST` of the vessel, we prioritise docking ports pointing towards the active vessel.
* otherwise we prioritise docking ports that are aligned towards the target_craft's orbit normal vector
In both cases, for ports facing in the same direction, the port closest to the active vessel will be selected.

#### `checkRouteStep(target_craft, start_position_vector, end_position_vector)`

This function checks that a given step on the docking route will not come too close to the `target_craft`. It is called both when trying to plot a docking route and when trying to navigate a route that has been set-up. 

It loops through all parts on the `target_craft`, comparing two vectors:
* the vector from the `start_position_vector` to the position of the part,
* the vector from the `start_position_vector` to the `end_position_vector`.
If the angle between these two vectors is less than `90` degrees, then the 'closest approach' is calculated. If this is below `DOCK_AVOID`, the function will immediately return `FALSE`.

If no obstructions are found, the function will return `TRUE`.

Note - the 'closest approach' is based on the position of each part, which defines the centre rather than the extremities. Where parts are very large, this function may not spot that a route is obstructed. In such cases, the size of `DOCK_AVOID` should be increased.

Note 2 - the input vector parameters are both expected to be position vectors from the centre of the active vessel. This is different to the inputs expected by `VECDRAW()`, and also to the way in which the waypoints are stored in `DOCK_POINTS`.

#### `activeDockingPoint(target_craft, do_draw, wait_then_blank_secs)`

The primary purpose of this function is to set/update `DOCK_ACTIVE_WP` to be a position vector that the active vessel should follow to reach the next ('active') docking waypoint.

Each step in the route is plotted and checked for obstructions by calling checkRouteStep(), working backwards from the target docking port to the active vessel's docking port. As part of this, it will draw the route using `VECDRAW()`s if `do_draw` is `TRUE`. The usual colour scheme is blue, but steps will turn red if an obstruction is detected. If `wait_then_blank_secs` is not negative, the function will wait that long then clear the drawn vectors from the screen.

Note - the route to the final waypoint (to the docking port of the `target_craft`) is not checked for obstructions, as by definition it will get very close to the `target_craft`.

The function will return `TRUE` if the docking route is ok, `FALSE` if an obstruction was found.

If not specified, the default value for `do_draw` is `TRUE`. If not specified, the default value for `wait_then_blank_secs` is `-1`.

#### `plotDockingRoute(ship_port, target_port, do_draw)`

This function has the difficult job of plotting a set of waypoints leading from `ship_port` to `target_port`. The resulting waypoints end up in `DOCK_POINTS`.

The function starts at the `target_port` and plots up to three waypoints, so that the docking route has up to four legs/steps. Three waypoints was felt to be enough as it allows the docking route to form a square/rectangle and thereby get from one side of the target vessel to the other.

Note - each waypoint is defined by a position vector from the previous waypoint (starting with `target_port`). As such, my explanation often talks about how long they are.

Note 2 - each waypoint is defined by a LOCK statement as the idea was that they would update if/when the target moves. Unfortunately, testing showed that this does not happen and that the waypoints are fixed once the route has been finalised. It should be possible to define each waypoint as a function and store a list of delegates so that they do update, but testing showed that this requires further changes to prevent it from breaking down completely due to the route flip-flopping between two opposite directions.

The waypoint placement logic is as follows:

If the active vessel is within `DOCK_DIST` of port and the angle between the position vector from `target_port` to `ship_port` and the `target_port`'s facing vector (`T_FACE`) is less than `1` degree, no waypoints are added. The active vessel can proceed directly to the `target_port`. Otherwise, at least one waypoint is required.

##### Waypoint 1

If the active vessel is within `DOCK_DIST` of `target_port`, plot a single waypoint facing directly outwards from the `target_port`, with a length that matches our separation distance. If the route from `ship_port` to this waypoint is obstructed, extend the length of the waypoint until either the route to it is clear, or the length reaches `DOCK_DIST`

Otherwise, plot a single waypoint facing directly outwards from the `target_port`, with a length of `DOCK_DIST`.

If we have plotted a waypoint, and our route to it is unobstructed, the active vessel can proceed to waypoint 1 then the `target_port`. If the route is obstructed, at least one more waypoint is required.

##### Waypoint 2

If required, plot a second waypoint of length `DOCK_DIST` at `90` degrees to the first waypoint. If the route to this new waypoint from the first waypoint is obstructed, rotate it around (using the first waypoint as the axis of rotation) until clear or we have gone round full circle.

If we went full circle, we go back and double the length of the first waypoint, then repeat placement of second waypoint.

This continues indefinitely - it assumes we will eventually find a clear route from waypoint 2 to waypoint 1.

Once waypoint 2 has been plotted, we check our route to it from the active vessel to see if it is obstructed. If it is obstructed, we will need a third waypoint.

##### Waypoint 3

If required, we initially place this waypoint in the opposite direction to waypoint 1, those ensuring it will be at `90` degrees to the second waypoint. It is deliberately quite short, `4`m, but this will be extended if necessary.

This waypoint will be the last one added. As such, each possibility must be checked for obstructions twice - once between the active vessel and waypoint 3, once between waypoint 3 and waypoint 2. Both legs must be clear for the third waypoint to be valid.

If either route is obstructed, rotate the waypoint around (using the second waypoint as the axis) until clear or we have gone round full circle. If we go full circle, double the length of this waypoint and repeat the rotation.

This should eventually result in a clear route, but to prevent an infinite loop we'll give up once the length of this third waypoint goes over `500`m.

##### Return

If a set of waypoints has been plotted and the route from the active vessel to the `target_port` is clear, the function will return `TRUE`. Otherwise it will return `FALSE`.

#### `dockingVelForDist(distance)`

This function returns the desired relative velocity between the active vessel and the docking target, based on the `distance` between the active vessel's docking port and the target waypoint/port.

This steps down the velocity as the vessel gets close to its destination. Otherwise, the desired velocity is `DOCK_VEL`.

For craft with under/over-powered RCS systems, these velocities may need changing, but I have tried to err on the careful side.

#### `checkDockingOkay(target_craft, do_draw, velocity_difference, is_start)`

This function performs a set of checks to see if it is okay to start/continue docking. The docking route is checked for obstructions and the level of monopropellant remaining compared to various thresholds. As part of this check, activeDockingPoint is called which set/updates `DOCK_ACTIVE_WP` to point at the currently active docking waypoint.

There is also an abort check that activates if RCS is turned off. If the relative velocity is significant, RCS gets re-enabled so that the active vessel can match velocity with the target.

#### `followDockingRoute(ship_port, target_port, do_draw)`

This function is in control of the translation of the active vessel. It 'flies' the craft from waypoint to waypoint using the `doTranslation()` function from `lib_rcs.ks`.

At its core, the function has a loop whereby we:
* Check the docking route so that the current active waypoint is updated. This is normalised and multiplied by the appropriate docking velocity returned by `dockingVelForDist()`. This gives us the direction we want to be going in.
* Calculate the current difference in velocities between the vessel and target. This is where we are actually going.
* Push the difference between the two velocities into `doTranslation()`.
* Once close to a waypoint (defined as being within `0.1`m with relative velocity below `0.1`m/s), the waypoint is removed from the list so the craft can move onto the next one.

Endpoints:
* The `STATE` of the craft's docking port is monitored. If it changes from `Ready`, it is assumed to be because it has got close enough to the target docking port and the magnets have activated. This is the only successful endpoint.
* If the docking route becomes obscured, docking is aborted.
* If the craft runs low on monopropellent, docking is aborted.
* If the RCS is turned off, docking is aborted.

If docking is aborted, `doTranslation()` is called again to reduce the relative velocity to zero, or until the craft runs very, very low on monopropellent. This is intended to leave the craft in a safe mode.

The function will return `FALSE` if docking was aborted, `TRUE` if it was successful.

If not specified, the default value for `do_draw` is `TRUE`.

#### `doDocking(target_craft, do_draw)`

This is the main function. It calls the other functions in sequence to perform a docking.

It selects a suitable, available docking port on both the active vessel and the `target_craft`. It sets the ship control from the selected docking port then steers to point in the opposite direction to the facing of the target docking port. It then plots a route between the two ports; if successful it turns on the RCS and follows this route.

Once the docking has finished, either because it has been aborted or because the docking ports' magnets have activated, the function disengages the steering and turns off RCS.

The function will then return `TRUE` or `FALSE` to indicate success or failure. It is expected that the script that called this function will handle those two states appropriately.

Geoff Banks / ElWanderer
