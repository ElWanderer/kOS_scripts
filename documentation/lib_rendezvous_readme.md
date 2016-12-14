## lib\_rendezvous (intercept and rendezvous library)

### Description

A library for achieving a rendezvous with a target craft.

Rendezvous consists of multiple steps, from ensuring that the orbits of the two craft are in the same plane, through arranging an intersection of the two orbits, then a phasing orbit so that the two craft are in the same place at the same time, to a final approach that closes on the target before matching orbital velocity.

A lot of this is either very complicated, or hard to express in short code blocks. It has been improved considerably over time, but is still a rather large library.

### Requirements

 * `lib_runmode.ks`
 * `lib_orbit_match.ks`
 * `lib_orbit.ks`
 * `lib_burn.ks`
 * `lib_orbit_phase.ks`
 * `lib_hoh.ks`
 * `lib_ca.ks`

### Global variable reference

#### `RDZ_FN`

The filename of the rendezvous-specific resume file. The default filename is `rdz.ks`.

This is used to store commands to be run to recover a previous state following a reboot. This avoids the `doRendezvous()` function having to recalculate various details of the rendezvous.

#### `RDZ_VEC`

The vector to steer to when performing the final stages of a rendezvous.

This is used during final approach as a vector to steer towards. Burning in the direction of this vector will reduce the relative velocity between the active vessel and the rendezvous target and/or reduce the expected closest approach between the two.

This is initialised as `SHIP:VELOCITY:ORBIT` so as not to be empty, but will be set to a more useful value before being used.

#### `RDZ_DIST`

The distance in metres at which the active vessel should take station from the rendezvous target. This affects the final approach, as the active vessel will effectively target a point `RDZ_DIST` away from the target rather than the target itself, to avoid collisions and hitting the target with rocket exhaust.

The default value is `75`m.

This has its own function for changing the value: `changeRDZ_DIST()`. It is recommended to set a value based on the sizes of the two craft taking part in the rendezvous. The Rescue boot scripts assume small vessels are involved and reset the value to be `25`m. 

#### `RDZ_MAX_ORBITS`

This is used when calculating a phasing orbit. A high maximum number of orbits will potential allow a small delta-v correction that results in an intercept several orbits later. A low maximum will encourage a high delta-v correction that results in an intercept much sooner.

The default value is `5`.

This has its own function for changing the value: `changeRDZ_MAX_ORBITS()`. It is recommended that the value is set based on the individual requirements of the mission, typically fuel versus time.

#### `RDZ_PHASE_PERIOD`

This is used to store the period of the phasing orbit that has been determined. It is one of three global variables that are stored and so recovered on a reboot, to avoid needing to recalculate it.

The initial value is `0`.

#### `RDZ_CA_DIST`

This is used to store the expected closest approach between the active vessel and the rendezvous target. It is one of three global variables that are stored and so recovered on a reboot, to avoid needing to recalculate it.

The initial value is `5000`m.

#### `RDZ_CA`

This is a string that is used as the key name in the `TIMES` lexicon. On initialisation, the current time is pushed into `TIMES[RDZ_CA]` by calling `setTime(RDZ_CA)`, but this is replaced with the expected *future* time of closest approach later on. This closest approach time is one of three global variables that are stored and so recovered on a reboot, to avoid needing to recalculate it.

The value is itself the string `RDZ_CA`. This is used in place of string literals because it makes the store command easier to write: `append("setTime(RDZ_CA," + TIMES[RDZ_CA] + ").", RDZ_FN).` instead of `append("setTime("+CHAR(34)+RDZ_CA+CHAR(34)+","+TIMES["RDZ_CA"]+").", RDZ_FN).` where `CHAR(34)` is the `"` character (and to demonstrate the benefit, I've had to rewrite the second example as I got confused where to put quotes).

#### `RDZ_THROTTLE`

This is used during final approach to control the throttle. The main `THROTTLE` is locked to this value, which is then varied by the script as necessary.

The initial value is `0`.

### Function reference

#### `storeRdzDetails()`

This function writes out multiple statements to the `RDZ_FN` file, so that the values of certain global variables can be recovered following a reboot.

The values that are stored are:
* `RDZ_PHASE_PERIOD`
* `TIMES[RDZ_CA]`
* `RDZ_CA_DIST`
See the global variable reference above for details.

#### `rdzETA()`

This function returns the time in seconds until the expected closest approach during a rendezvous.

This is achieved by returning `-diffTime(RDZ_CA)`. This is a negative because the time is in the future and by default `diffTime()` is used to return the time elapsed since a certain timestamp.

#### `changeRDZ_DIST(distance)`

This function is used to change `RDZ_DIST` to the input `distance`. It is recommended to set a value based on the sizes of the two craft taking part in the rendezvous. See the description of the `RDZ_DIST` global variable above.

#### `changeRDZ_MAX_ORBITS(number)`

This function is used to change `RDZ_MAX_ORBITS` to the input `number`. It is recommended that the value is set based on the individual requirements of the mission, typically fuel versus time. See the description of the `RDZ_MAX_ORBITS` global variable above.

#### `orbitTAOffset(orbit1, orbit2)`

This function returns the offset between the two input orbits, assuming that they are co-planar (i.e. matching inclination and longitude of the ascending node). This can then be used to convert a true anomaly in `orbit1` to the equivalent true anomaly in `orbit2`. By equivalent, I mean that a straight line between two craft at these true anomalies in the two orbits would also pass through the centre of the body around which the two are orbiting.

For each orbit, the argument of periapsis defines how far around the orbit from the ascending node that the periapsis (true anomaly of `0`) is located. The difference between the two values for the two orbits indicates the offset.

Note - the function actually adds together the longitude of the ascending node (LAN) and argument of periapsis for each orbit, before comparing the two. If the two orbits are perfectly aligned and non-equatorial, the values for LAN will be the same and so including them is unnecessary. For equatorial orbits, depending on how close to `0` (or `180`) the inclination is, the LAN values may actually be quite different even for well-aligned orbits. Hence it is safest to take both into account.

#### `findOtherOrbitTA(orbit1, orbit2, orbit1_trueanomaly)`

This function returns the equivalent true anomaly in `orbit2` that is aligned with `orbit1_trueanomaly` in `orbit1`.

This is done by calling `orbitTAOffset()` and subtracting the result from `orbit1_trueanomaly`.

#### `minSeparation(orbit1, orbit2, start_trueanomaly, end_trueanomaly, step_size)`

TBD.

#### `findOrbitMinSeparation(orbit1, orbit2)`

TBD.

#### `findTargetMinSeparation(target)`

TBD.

#### `rdzBestSpeed(distance, velocity_diff, stage_delta-v)`

TBD.

#### `rdzOffsetVector(target)`

TBD.

#### `rdzApproach(target)`

TBD.

#### `rdzOffsetVector(target)`

TBD.

#### `nodeRdzInclination(target, universal_timestamp)`

TBD.

#### `nodeRdzHohmann(target, universal_timestamp)`

TBD.

#### `nodeForceIntersect(target, universal_timestamp)`

TBD.

#### `nodePhasingOrbit(target, universal_timestamp)`

TBD.

#### `recalcCA(target)`

TBD.

#### `passingCA(target, min_distance)`

TBD.

#### `warpToCA(target)`

TBD.

#### `doRendezvous(exit_mode, target, can_stage)`

This function provides the main interface for controlling a craft during a rendezvous with `target`.

`exit_mode`: This is the runmode that the script will switch back to following a successful rendezvous. The function itself has its own set of runmodes in the range `401`-`449`.

`can_stage`: `TRUE`/`FALSE`. This is passed into each call to `execNode()` (`lib_burn.ks`).

*EVERYTHING BELOW THIS LINE IS A COPY OF THE lib_transfer README THAT HASN'T BEEN REPLACED YET!*

##### Steps

The `doTransfer()` function initially calculates a transfer node from the current body to the `destination`. As orbits are not usually perfectly circular, this may not even intercept the target body let alone match the desired orbital parameters. The node is passed into the `improveNode()` function which should ensure a fairly accurate trajectory.

The initial node is executed if it is predicted to result in a trajacetory that (eventually) meets the `destination`. Otherwise, it'll drop into a pending failed state (which waits for the player to hit `ABORT` before trying again from the beginning).

Unless the node was executed perfectly, chances are that the trajectory will be quite different to that intended. The function will loop through a set of runmodes whereby mid-course correction nodes are generated and burnt as necessary, until the trajectory has the desired accuracy (see the `orbitNeedsCorrection()` function description for details).

Once the trajectory is considered good enough, the script will time-warp forwards until the next sphere of influence transition.

Once in the next sphere of influence, the script will loop, and consider making mid-course corrections again. Being closer to the `destination`, the required accuracy will be higher than the previous set of corrections, but if the initial set of burns was good enough, no further changes will be needed.

Once in the sphere of influence of the `destination`, a further set of corrections is possible. In particular, it is here that any required inclination changes are most likely to occur. 

Note - if the craft appears in orbit of the `destination` and is already beyond the periapsis, a node to put the craft into orbit is plotted and burned. This is done because KSP's intercept predictions can prove to be incorrect, and it's possible to warp through the sphere of influence transition at a high warp rate. Though the warp will be killed on detecting the change of body, this may not be fast enough. This occurred regularly in KSP v1.0.5, but hasn't been so much of a problem in KSP v1.1.3. It is something that may prove to be even better in KSP v1.2.*.

Once any necessary final corrections have been made, there are two possibilities:
 * The current periapsis is above the atmosphere. In this case we are assumed to be entering orbit. To achieve this an orbital insertion node is placed at the periapsis that will put the craft in a stable orbit. One apsis will be the current periapsis. The other apsis will have the input `periapsis` altitude. Ideally, these altitudes will be virtually identical, but that may not be the case.
 * The current periapsis is below the atmosphere height. In this case we are assumed to be aerobraking or re-entering. The script cannot tell the difference between the two, so it will take no further action and exit. Re-entry or aerobraking is assumed to be handled separately. Currently, `lib_reentry.ks` provides an interface for re-entry, but we don't have any libraries for aerobraking.

Geoff Banks / ElWanderer
