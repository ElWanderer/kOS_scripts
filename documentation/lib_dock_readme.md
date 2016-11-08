## lib\_dock (docking library)

### Description

Text

#### Subtitle

Text

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

Text

#### `dockingVelForDist(distance)`

Text

#### `checkDockingOkay(target_craft, do_draw, velocity_difference, is_start)`

Text

#### `followDockingRoute(ship_port, target_port, do_draw)`

Text

#### `doDocking(target_craft, do_draw)`

Text

Geoff Banks / ElWanderer
