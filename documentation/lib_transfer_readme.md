## lib\_transfer (inter-body transfer library)

### Description

A library for transferring between different orbital bodies.

Currently, transfers from a body to one of its moons are supported, along with transfers back from a moon to the parent body. Interplanetary transfers are not yet supported.

### Requirements

 * `lib_orbit.ks`
 * `lib_burn.ks`
 * `lib_runmode.ks`
 * `lib_hoh.ks`
 * `lib_ca.ks`

### Global variable reference

#### `CURRENT_BODY`

This is used during sphere of influence transitions to store the body we are expecting to transfer from. When this no longer holds the same value as `BODY`, we know we have transitioned to a new sphere of influence.

The initial value is the current `BODY` when the library is run.

#### `MAX_SCORE`

This is a large value, used by the node scoring functions as an initial value. Due to the availability of "bonus" points, it's possible for a manoeuvre node to score higher than this value.

The initial value is `99999`.

#### `MIN_SCORE`

This is a large, negative value, used by the node scoring functions when the solution is deemed to be so bad, it's not possible to work out *how* bad it is!

The initial value is `-999999999`.

#### `TIME_TO_NODE`

This is the number of seconds in the future that a mid-course correction node will be plotted.

Previously, this was incremented after each correction node, so that corrections got further apart during a transfer. That functionality was removed and so this value is currently left unchanged. Future updates may reimplement the node increments or use it to specify precise times for certain nodes e.g. to apply a correction in the best position to perform an inclination change.

The initial value is `900` seconds.

### Function reference

#### `bodyChange(prev_body)`

This returns `TRUE` if the current `BODY` is the same as the input `prev_body`, and `FALSE` if they are different.

#### `nodeCopy(node1, node2)`

This function copies all of the manoeuvre node details (`ETA`, `PROGRADE`, `RADIALOUT` and `NORMAL`) from `node1` to `node2`. In doing so, `node2` becomes a copy of `node1`.

#### `futureOrbit(initial_orbit, count)`

This function returns the orbit that is `count` patches in the future of `initial_orbit`. Each new patch results from a spere of influence change during the previous orbit.

    // if count is 0, we will return initial_orbit
    // if count is 1, we will return initial_orbit:NEXTPATCH
    // if count is 2, we will return initial_orbit:NEXTPATCH:NEXTPATCH
    // etc.
    
If the `initial_orbit` does not have enough future patches, the last available orbit patch is returned.

Note - the number of patches visible/available may vary depending on various game modes and settings.

#### `futureOrbitETATime(initial_orbit, count)`

This function returns the universal timestamp at which the orbit that is `count` patches in the future of `initial_orbit` begins. Each new patch results from a spere of influence change during the previous orbit.

    // if count is 0, we will return TIME:SECONDS
    // if count is 1, we will return TIME:SECONDS + initial_orbit:NEXTPATCHETA
    // if count is 2, we will return TIME:SECONDS + initial_orbit:NEXTPATCHETA + initial_orbit:NEXTPATCH:NEXTPATCHETA
    // etc.
    
If the `initial_orbit` does not have enough future patches, the universal timestamp returned is based on the beginning of the last available orbit patch, plus the period of that orbit patch.

Note - the number of patches visible/available may vary depending on various game modes and settings.

#### `orbitReachesBody(initial_orbit, destination, count)`

This function returns the number of orbit patches in the future that a craft following the `initial_orbit` patch will reach the `destination` body. Each new patch results from a spere of influence change during the previous orbit.

This function is recursive.

    // if initial_orbit:BODY matches the destination, we will return count
    //
    // else if initial_orbit:HASNEXTPATCH, we will return the result of passing this 
    // next patch into `orbitReachesBody()`, incrementing the count as we do so.
    //
    // else we will return -1

The function returns `-1` if the `initial_orbit` does not have any orbit patches that reach the `destination`.

The optional parameter `count` is an internal counter. It is defaulted to `0` if not provided, then incremented by the recursive function calls.

Note - the return value `count` can be used to look-up the orbit patch via the `futureOrbit()` function.

#### `scoreNodeDestOrbit(destination, periapsis, inclination, longitude_of_ascending_node, node, best_score)`

This function returns a score for the input `node` based on how closely the resultant orbit from executing the node perfectly will resemble the target parameters.

Of the input parameters, `destination` and `periapsis` must have sensible values. The input `inclination` and `longitude_of_ascending_node` can be passed in as `-1` to tell the score function to ignore those orbital parameters.

`orbitReachesBody()` is called to see if the orbit resulting from the input `node` will actually reach the `destination`. Typically, orbits that do not reach the `destination` will have a negative score, whereas orbits that do will have a positive score.

If the orbit does reach the `destination`, the details of the orbit patch are compared to the input parameters. How this works:
* The score is initialised as `MAX_SCORE`.
* The trajectory is then scored, depending on whether the target periapsis is below the 'minimum altitude' (120% of the atmosphere height, or `20`km for airless bodies). If the target periapsis is below the minimum, we assume we are landing/re-entering and try to encourage high accuracy:
  * we add large bonus points if the predicted periapsis is within `2500`m of the target periapsis, with the bonus rising to a maximum of `500` if the two are aligned.
  * otherwise a penalty is subtracted from the score, based on the discrepancy between the two values.
  * In both cases, square root functions are used to try to smooth the points curves - in particular the penalty grows slowly as the discrepancy increases so that the overall score shouldn't become negative (and therefore should always score higher than a trajectory that misses the target altogether).
* If the target periapsis is above the minimum, we assume that we will be entering orbit. The exact periapsis is not so important, compared to making sure that the trajectory is not sub-orbital and minimising delta-v expenditure:
  * If the predicted periapsis is below the minimum, a penalty is subtracted from the score, based on the discrepancy between the two values.
  * The score is reduced by the amount of delta-v (in m/s) required to burn the input `node`.
  * The score is reduced by the amount of delta-v (in m/s) required to make an orbital insertion at the estimated periapsis, with the other side of the orbit being set to the target periapsis (these two values can/will usually be different).
  * The score is reduced by the estimated additional delta-v (in m/s) required to correct the periapsis after orbit insertion, assuming it is different from the target periapsis.
  * If `inclination` is not negative, the score is reduced by the estimated additional delta-v required to correct the orbit plane (`inclination` and `longitude_of_ascending_node`) following circularisation. If the input `longitude_of_ascending_node` is negative, the plane change is estimated assuming only the inclination needs correcting.

If the orbit does not reach the `destination`, the function checks the value of `best_score`. If we have a `best_score` with a positive value, we already have another node that reaches the destination, therefore we can assign this one `MIN_SCORE` and move on.

If we have not yet found a trajectory that reaches the target, the function assigns a negative score based on the closest approach between the craft and the destination, in the sphere of influence of the destination's parent body, in km. If the trajectory does not reach the destination's parent body, it will consider the parent bodies, and will continue up the hierarchy of bodies until either an orbit in the correct sphere of influence is found or we run out of bodies. 

For example, if a transfer is being made to Ike from Kerbin, but does not reach Ike itself:
* The function will first check to see if the trajectory enters Duna's sphere of influence. If it does, the score will be based on the closest approach between the craft's trajectory within Duna's sphere of influence and Ike.
* If necessary, the function will then check to see if the trajectory enters the sphere of influence of the Sun, and if so base the score on the closest approach between that trajectory and Duna.
* The Sun has no parent body, so the function can do no further checking. If the trajectory does not enter the sphere of influence of the Sun, that implies it never left Kerbin's sphere of influence!

If we could not determine a closest approach distance, `MIN_SCORE` is used instead.

The calculated score is returned.

#### `TBD(TBD)`

TBD

#### `TBD(TBD)`

TBD

#### `TBD(TBD)`

TBD

#### `TBD(TBD)`

TBD

Geoff Banks / ElWanderer
