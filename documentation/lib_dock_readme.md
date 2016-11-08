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

The minimum distance that the plotted docking route must maintain from all parts on the target craft. This may need to be increased for docking together larger vessels.

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

Text

#### `selectOurPort(taret_craft)`

Text

#### `selectTargetPort(target_craft)`

Text

#### `checkRouteStep(target_craft, start_position_vector, end_position_vector)`

Text

#### `activeDockingPoint(target_craft, do_draw, wait_then_blank_secs)`

Text

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
