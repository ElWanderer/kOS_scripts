## lib\_rendezvous (intercept and rendezvous library)

### Description

A library for achieving a rendezvous with a target craft.

Rendezvous consists of multiple steps, from ensuring that the orbits of the two craft are in the same plane, through arranging an intersection of the two orbits, then a phasing orbit so that the two craft are in the same place at the same time, to a final approach that closes on the target before matching orbital velocity.

A lot of this is either very complicated, or hard to express in short code blocks. It has been improved considerably over time, but is still a rather large library.

#### Terminology: Closest Approach v. Minimum Separation

For two craft, the closest approach is the minimum distance between the two craft over a set period of time. During rendezvous, the aim is to get the closest approach between the active vessel and the rendezvous target as close to `0`km as possible.

Minimum separation is a similar concept, but relates to how close two *orbits* get. For two orbits that intersect (cross each other), the minimum separation is `0`. If the orbits do not cross, the minimum separation will be some positive value. During rendezvous, the aim is typically to change one of the orbits so that the two intersect, but due to burn inaccuracy, this may not happen. Still, if the orbit tracks pass very close to each other, it is possible to get the two craft equally close.

Note - having two craft following two orbits that have a low minimum separation does not ensure that there will be a similarly low closest approach. If the two orbits have similar periods (or are synchronised), the two craft may never get close to each other (or at least not within a reasonable time frame).

#### Terminology: Intersection v. Intercept

Similar to the difference between closest approach and minimum separation, the difference in terminology here is down to whether we are talking about the positions of space craft or the orbits that they are following.

An intersection is where two orbits cross (or at least lie very close to each other).

An intercept is where one craft times its approach to an intersection such that it will be there at the same time as the target craft following the other orbit.

In order to achieve an intercept, we usually have to make sure there is an intersection first. For a phasing approach, we ensure an intersection and then calculate an appropriate orbital period to ensure that the target is intercepted at the intersection, potentially several orbits in the future. For a Hohmann transfer approach, the intercept is achieved by timing the creation of the intersection to meet the target at the first opportunity.

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

This function will return the details of the minimum separation found between portions of `orbit1` and `orbit2`, assuming that the two orbits are co-planar (i.e. matching inclination and longitude of the ascending node).

The function starts at `start_trueanomaly` (defined in terms of `orbit1`) and steps through to `end_trueanomaly` at intervals of `step_size`. It will increase one of the values if necessary so that the `end_trueanomaly` is higher than the `start_trueanomaly` e.g. if asked to start at `355` degrees and end at `5` degrees, it will iterate from `355` to `365`, but then convert these values back to the range `0`-`360` when passed into the calculations.

For each `orbit1` true anomaly value, the equivalent true anomaly for `orbit2` is found by subtracting the `orbitTAOffset()`. The separation is calculated taking the difference in the `radiusAtTA()` values. It's important to re-iterate that this assumes the orbits are co-planar.

The lowest value for the minimum separation (and the true anomaly values at which it occurs) is stored and returned.

The return value is a list: `LIST(minimum_separation_distance, active_vessel_trueanomaly, target_trueanomaly)`.

#### `findOrbitMinSeparation(orbit1, orbit2)`

This function will return the details of the minimum separation found between `orbit1` and `orbit2`, assuming that the two orbits are co-planar.

This is achieved by calling `minSeparation()` to step through the whole orbit (`360` degrees) in `10` degree steps. Then the function iterates through smaller and smaller steps (dividing by `10` each time), calling `minSeparation()` again around the minimum separation that was found, until the step size drops below a minimum. 

The minimum step size is calculated as `36 / orbit:PERIOD` (equivalent to `0.1` degrees per second). As the step size is divided by `10` each time, this means that the final step value will be somewhere between `0.1` and `1` degrees per second. This means that while the value returned is a true anomaly, the final accuracy is effectively within a time range of `0.1` to `1`s.

Note that there may be situations where this doesn't find the smallest separation. This is always the danger of calculating via sampling, if the values at the sample points are unrepresentative of those in between.

The return value is a list: `LIST(minimum_separation_distance, active_vessel_trueanomaly, target_trueanomaly)`.

#### `findTargetMinSeparation(target)`

This function will return the details of the minimum separation found between the active vessel's orbit and the orbit of the `target`, assuming that the two orbits are co-planar.

Note that this is achieved by calling `findOrbitMinSeparation()` which in turn iterates through the orbits finding the minimum separation. As described above, that may not find the lowest minimum separation in all cases.

The return value is a list: `LIST(minimum_separation_distance, active_vessel_trueanomaly, target_trueanomaly)`.

#### `rdzBestSpeed(distance, velocity_diff, stage_delta-v)`

This function returns the desired current velocity difference between the active vessel and the target craft, based on the current `distance` between the two, the current `velocity_diff` and the time it would take to kill this current velocity with a burn (which requires knowing the delta-v available).

This function is effectively a look-up table, with the desired velocity difference stepping down as the distance to the target decreases.

#### `rdzOffsetVector(target)`

This function returns an offset to be added to the current position vector to the target, in order to ensure that the active vessel will aim for a point `RDZ_DIST` from the target, reducing the risk of collision or thrusting directly at the target. 

This offset is `RDZ_DIST` in magnitude. It is creating by adding together two normal vectors in the ratio `8:1`: the target's orbit normal and a vector cross between that normal and the target's current position vector. This is then normalised and multipled by `RDZ_DIST`. The vector will largely point normal to the target, with a smaller offset pointing at `90` degrees from the target's position vector. This is to ensure that the offset does not point directly towards (or away from) the active vessel.

#### `rdzApproach(target)`

This function is used to perform the final approach section of a rendezvous, i.e. going from being within a few kilometres to taking station `RDZ_DIST` away from the target, with the velocities matched.

This function has been rewritten a couple of times and is still far from perfect. It was written to account for early career rescue missions, and so does not use RCS to kill the relative velocity (yet). This can result in the craft performing `180` degree rotations in order to ensure the relative velocity is killed when it would be easier to trigger a short burst of RCS. That's covered by [issue #21](https://github.com/ElWanderer/kOS_scripts/issues/21)

The function works by trying to keep the relative velocity between the craft and `target` from pointing too far away from the target (to maintain the approach) and to keep its velocity from growing too large or small, in particular ramping down the magnitude as the `target` gets closer. This way, a series of correction burns should take place, until the vessel is about `RDZ_DIST` from the `target` with a relative velocity below `0.2`m/s.

The function returns `TRUE` if the rendezvous was completed successfully, `FALSE` if the vessel ran out of fuel.

##### In Detail

This version consists of a loop. Each tick, the function calculates the target point (offset from the position of the `target` by `RDZ_DIST`m as determined by the `rdzOffsetVector()` function) and the relative velocity between the active vessel and the `target`. The function loops until either of two conditions are met:
* The active vessel is within `25`m of the target point and the relative velocity is below `0.15`m/s. In this case, the function will return `TRUE`.
* The active vessel has less delta-v remaining than the magnitude of the relative velocity. This is a somewhat extreme situation, but the check prevents the loop from continuing forever. In this case, the function will return `FALSE`.

An 'ideal' relative velocity vector is calculated. This points towards the target point, with a magnitude determined by calling `rdzBestSpeed()`, which decreases the desired velocity as the distance to the target point decreases. `RDZ_VEC`, to which the craft's steering is locked, is then calculated as the vector that would change the current relative velocity to the ideal relative velocity.

It currently draws a set of vectors on the screen to show its working (and that it's working!):
* Target point position vector, "To target (offset)"
* The relative velocity
* The 'ideal' relative velocity
* `RDZ_VEC`, labelled "Thrust vector" or "Steer vector" depending on whether the throttle is on or off.

The magnitude of `RDZ_VEC` is 'allowed' to grow as high as one third of the 'ideal' relative velocity's magnitude. If the magnitude goes over that limit, the throttle is allowed to be engaged. This could be because the relative velocity vector and the target point position vector are not pointing in the same direction, because the desired velocity magnitude is different to the current relative velocity or a combination of the two. Note that this does not mean the engine will fire immediately - the craft has to be pointing towards the `RDZ_VEC` vector first, as determined by `VDOT()`ing the two vectors and checking if the value is greater than or equal to `0.995`.

Once the throttle has been turned on, it is set to a value based on the estimated burn time to reduce the `RDZ_VEC` to `0`: `SET RDZ_THROTTLE TO burnThrottle(burnTime(RDZ_VEC:MAG, sdv))`. With the throttle engaged, the burn is ended (possibly temporarily) if the `VDOT()` between the facing and `RDZ_VEC` drops below `0.95`. This should react fairly quickly if the `RDZ_VEC` vector moves (e.g. due to pointing into the opposite direction).

These steps are fairly useful for keeping the active vessel moving towards the `target` but there are two drawbacks:
* The very end of final approach can be fairly clumsy due to not using RCS (see above), particularly for large, unwieldy vessels
* If final approach is initiated too soon, when the `target` is still quite far away, the relative velocity is likely to point away from the `target`, but could be expected to close naturally due to the curvature of orbits. Instead the function will immediately trigger a burn. In turn, this will require a lot of corrections. In short, pointing and burning straight at the `target` is only effective when very close to it, due to orbital mechanics.

#### `nodeRdzInclination(target, universal_timestamp)`

This function generates and adds a manoeuvre node (if necessary) to align the inclination of the active vessel's orbit with that of the rendezvous `target`, using the `lib_orbit_match.ks` functions.

The function returns `TRUE` if a node was added, `FALSE` otherwise. This return value explicitly says whether the next step should be to call `execNode()` or not.

#### `nodeRdzHohmann(target, universal_timestamp)`

This function generates a manoeuvre node to perform a Hohmann transfer from the current orbit to that of the `target`, in such a way as to intercept the target.

While this function was written to transfer between two non-intersecting, roughly-circular orbits, it has never actually been used. That's because the node improvement function that would be needed to refine the intercept hasn't been written. Nothing currently calls this function. [issue #19](https://github.com/ElWanderer/kOS_scripts/issues/19) exists to implement this fully.

The function returns `TRUE` if a node was added, `FALSE` otherwise. This return value explicitly says whether the next step should be to call `execNode()` or not. Currently, a node is always added.

#### `nodeForceIntersect(target, universal_timestamp)`

This function generates a manoeuvre node (if necessary) that would bring the minimum separation between the active vessel's current orbit and that of the `target` below `2`km.

Three nodes are considered, each opposite a point of interest on the orbit of the `target`.
* opposite the point of minimum separation
* opposite the target's apoapsis
* opposite the target's periapsis
In each case, the node will change the current orbit's radius at that point to match that of the `target`'s orbit.

Whichever node costs the least delta-v is chosen.

The function returns `TRUE` if a node was added, `FALSE` otherwise. This return value explicitly says whether the next step should be to call `execNode()` or not.

#### `nodePhasingOrbit(target, universal_timestamp)`

TBD - another complicated one!

The function returns `TRUE` if a node was added, `FALSE` otherwise. This return value explicitly says whether the next step should be to call `execNode()` or not.

#### `recalcCA(target)`

This calls the `lib_ca.ks` function `targetCA()` to predict the precise time of the closest approach `target`, based on a small segment (one eighth) of the orbit, centred on the currently-predicted time of closest approach. The current prediction may have been made by `nodePhasingOrbit()`, in which case it was made based on a manoeuvre node that hadn't been executed yet. The burn was unlikely to be precisely accurate, so we re-evaluate the approach.

#### `passingCA(target, min_distance)`

This is a helper function used by `warpToCA()`. It is meant to be used to kill time warp if the active vessel finds itself passing within `min_distance` of the `target`, and with the distance increasing (relative velocity points away from the target).

If not specified, the default value for `min_distance` is twice the predicted close approach distance (`RDZ_CA_DIST`).

#### `warpToCA(target)`

If the predicted closest approach is more than `99` seconds in the future, this function will time warp until `90` seconds prior to closest approach. Otherwise it does nothing.

The warping functionality is handled by the `init_common.ks` function `doWarp()`, passing in `passingCA()` as a function delegate to kill warp if we seem to be overshooting the target.

#### `doRendezvous(exit_mode, target, can_stage)`

This function provides the main interface for controlling a craft during a rendezvous with `target`.

`exit_mode`: This is the runmode that the script will switch back to following a successful rendezvous. The function itself has its own set of runmodes in the range `401`-`449`.

`can_stage`: `TRUE`/`FALSE`. This is passed into each call to `execNode()` (`lib_burn.ks`).

*EVERYTHING BELOW THIS LINE IS A COPY OF THE lib_transfer README THAT HASN'T BEEN REPLACED YET!*

TBD

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
