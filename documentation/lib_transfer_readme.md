## lib\_transfer (inter-body transfer library)

### Description

A library for transferring between different orbital bodies.

Currently, transfers from a body to one of its moons are supported, along with transfers back from a moon to the parent body. Interplanetary transfers are not yet supported.

### Requirements

 * `lib_orbit.ks`
 * `lib_burn.ks`
 * `lib_runmode.ks`
 * `lib_hoh.ks`

### Global variable reference

#### `CURRENT_BODY`

This is used during sphere of influence transitions to store the body we are expecting to transfer from. When this no longer holds the same value as `BODY`, we know we have transitioned to a new sphere of influence.

The initial value is the current `BODY` when the library is run.

#### `MAX_SCORE`

This is a large value, used by the node scoring functions as an initial value.

The initial value is `99999`.

#### `TIME_TO_NODE`

TBD - how is this actually used?

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

Note - the internal counter index `i` is initialised at `1` whereas the lowest valid index value for `count` is `0`. This leads to the slightly confusing reference to `i-2` when displaying a warning about the index of the last available patch.

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

#### `scoreNodeDestOrbit(destination, periapsis, inclination, longitude_of_ascending_node, node)`

This function returns a score for the input `node` based on how closely the resultant orbit from executing the node perfectly will resemble the target parameters.

Of the input parameters, `destination` and `periapsis` must have sensible values. The input `inclination` and `longitude_of_ascending_node` can be passed in as `-1` to tell the score function to ignore those orbital parameters.

`orbitReachesBody()` is called to see if the orbit resulting from the input `node` will actually reach the `destination`. Typically, orbits that do not reach the `destination` will have a negative score, whereas orbits that do will have a positive score.

If the orbit does reach the `destination`, the details of the orbit patch are compared to the input parameters. How this works:
* The score is initialised as `MAX_SCORE`,
* The score is reduced by the amount of delta-v (in m/s) required to burn the input `node`,
* The score is reduced by the difference in the predicted periapsis and `periapsis`, divided by `10`,
* If `inclination` is not negative:
  * The difference between `inclination` and the predicted inclination (`i_diff`) is calculated,
  * The difference between `longitude_of_ascending_node` and the predicted LAN (`lan_diff`) is calculated,
  * If `longitude_of_ascending_node` is not negative, `inclination` is not `0` or `180` and `lan_diff` is greater than `90` but less than `270`:
    * `i_diff` is incremented by the *total* of `inclination` and the predicted inclination. This is to discourage trajectories when the LAN is further than `90` degrees from the target.
  * The score is reduced by `i_diff` x `100`,
* Lastly, if the predicted periapsis is below a safe minimum (either `20000`m above sea-level or `15000`m above the top of the atmosphere, if there is one) and the target `periapsis` is not also below this minimum:
  * The difference between the safe minimum and the predicted periapsis is calculated, and a further `5000`m added. This is then divided by `250` and subtracted from the score. This is to discourage trajectories that result in a collision with the target body.

If the orbit does not reach the `destination`, the function estimates that the initial orbit patch is a transfer orbit and that the `destination` should be reached at the next apsis. This is only really applicable for planet->moon transfers, and needs replacing when support is added for other transfers. The separation distance between the craft and the `destination` at the next apsis is calculated, negated and returned. This way, nodes with a reduced separation distance between the craft and the `destination` are favoured.

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
