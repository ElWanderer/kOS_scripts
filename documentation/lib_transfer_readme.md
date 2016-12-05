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

This is the number of seconds in the future that a mid-course correction node will be plotted. This is not used as a setting, it was always intended to be changed as necessary during a transfer.

Previously, this was incremented or doubled after each correction node, so that corrections got further apart during a single orbit patch, to avoid trying to perform too many during a transfer. That functionality has been removed.

Currently, it is used to specify precise times for certain nodes e.g. to apply a correction in the best position to perform an inclination change.

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

The input `inclination` and `longitude_of_ascending_node` can be passed in as `-1` to tell the score function to ignore those orbital parameters.

The function `ADD`s the input `node` to the ship's flightpath, scores the orbit that results, then `REMOVE`s the `node` from the flightpath. To ensure that the `node`'s effect on the flightpath is definitely being calculated correctly, there is a `WAIT 0` after the addition. This means that the number of nodes that can be scored each second is limited by the number of physics ticks.

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

##### Notes

Previously, the scoring function used to score based on how close the predicted periapsis, inclination and LAN values were to the desired values. This suffered because it was hard to work out how to score differences in metres and degrees together. The new scoring based almost entirely on delta-v is much better in this regard, though it does have some interesting foibles:

* it can be cheaper in terms of delta-v (and therefore scores higher) to make no burn whatsoever and correct the difference in trajectory once arrived in orbit, than to make a correction burn 'now'. It was the realisation that this was actually a valid approach quite a lot of the time that led to the introduction of totalling all the delta-v requirements, then moderating them with bonus and penalty points under certain circumstances. The penalties are used to try to avoid trajectories that can't be corrected once arrived in orbit e.g. because you'll have crashed into the planet first. The bonuses are there to encourage accurate orbits when trying to re-enter.
  * the corollary of this is that whatever is calling the scoring function has to be able to take into account that the 'best' manoeuvre node may be zero or very close to zero. Where this occurs, the resultant trajectory will not match the desired one.
* missing the target altogether is still considered to be very bad. Because of this, the scoring function is still at the mercy of KSP's orbit transition detection.

Currently, the only safety considerations relate to how close the trajectory comes to the destination body and/or its atmosphere. The orbit ranges of satellites of the destination are not considered. So far that has not been needed, but it would be important to implement this for some inter-planetary transfers e.g. if transferring to Duna, we do not want to end up in an orbit that shares the same inclination and altitude as Ike.

#### `updateBest(score_function, new_node, best_node, best_score)`

This function is used during manoeuvre node improvement. The input `new_node` is scored by calling the input `score_function`, and this new score is compared to the input `best_score`. If the `new_node` scores higher, `nodeCopy()` is called to overwrite the details of `best_node` with those of `new_node`.

The new best score (which will be the same as the input `best_score` if the `new_node` did not score higher) is returned.

#### `newNodeByDiff(node, eta_diff, radialout_diff, normal_diff, prograde_diff)`

This function is used during manoeuvre node improvement. A new manoevure node is returned, one that is based on the details of the input `node` offset by the input differences.

e.g. calling `newNodeByDiff(some_node, -15, 0, 0, 100)` will return a new node that is identical to `some_node`, except that it occurs `15` seconds earlier and the prograde element of the node is `100`m/s greater.

#### `improveNode(node, score_function)`

This is the manoeuvre node improvement function. It uses a hill-climbing algorithm. It is generic in that it can be used for any kind of node (transfers, corrections, rendezvous etc.) as the logic of determining whether a change to the node is an improvement or not has been separated out into separate scoring functions. One scoring function must be passed in to the `score_function` input parameter.

Note - the function does not return a value. It works directly on the input `node`, manipulating it to match the details of the 'best' node found.

Note - the function does not change the timing of a manoeuvre node. In the past, this was done, but it was found to cause problems. This does potentially limit the kind of improvement that can be done to a node e.g. you can't start with a node at a random time and expect the improvement function to turn into an efficient transfer to Duna unless you happened to pick a good time. It is assumed that the `node` being passed in has been calculated to some extent, and that this function is for refining it.

The function follows a three-step process:

##### 1. Initialisation

    LOCAL ubn IS updateBest@:BIND(score_function).

This line sets up a delegate of the `updateBest()` function with the `score_function` bound (using what was passed into `improveNode()`). This can then be called repeatedly later on.

    LOCAL best_node IS newNodeByDiff(node,0,0,0,0).
    LOCAL best_score IS score_function(best_node,MIN_SCORE).
    LOCAL orig_score IS best_score.

These lines initialise `best_node` as a copy of the input `node` and assign it an initial score by calling `score_function()` on it. This score is saved in `orig_score` for later comparison.

##### 2. Set adjustments

The initial node improvements that are tried are a small set of adjustments, changing just one node element at a time. The ETA element is not changed, but the `RADIALOUT`, `NORMAL` and `PROGRADE` elements are altered in turn. The aim of this step is to get an idea of where a potential solution may lie.

The magnitude of the adjustments is in ascending powers of `2`, starting off small: `2^-2`(`0.25`)m/s and ending up fairly large `2^4`(`16`)m/s.

Note - the kOS `IN RANGE(-2,5,1)` command returns a list of the values `-2, -1, 0, 1, 2, 3, 4`. The end parameter value of `5` is not included. This is just the way it works (starts at the first parameter then stops at the value before the end parameter).

For each power of `2`, we make six adjustments. Three where the adjustment is a negative value and three where it is positive. This is the purpose of the `FOR mult IN LIST(-1,1)` line. Altogether, that means that 42 different manoeuvre nodes are created and scored. This step only occurs once, so the number of nodes considered could be increased without affecting the processing time too much.

    LOCAL dv_delta_power IS 4.
    FOR dv_power IN RANGE(-2,5,1) {
      FOR mult IN LIST(-1,1) {
        LOCAL curr_score IS best_score.
        LOCAL dv_delta IS mult * 2^dv_power.

        SET best_score TO ubn(newNodeByDiff(node,0,0,0,dv_delta), best_node, best_score).
        SET best_score TO ubn(newNodeByDiff(node,0,0,dv_delta,0), best_node, best_score).
        SET best_score TO ubn(newNodeByDiff(node,0,dv_delta,0,0), best_node, best_score).

        IF best_score > curr_score { SET dv_delta_power TO dv_power. }
      }
    }

    IF best_score > orig_score { nodeCopy(best_node, node). }
    LOCAL dv_delta IS 2^dv_delta_power.

If any of the nodes have improved the score, the `best_node` found is copied over the input `node`. The next step will use this as the basis for its iteration.

The power of `2` that results in the best score is used to initialise `dv_delta`. This will be used as a starting point for the magnitude of adjustments in the next step. If no improvement was found, the maximum of 16m/s is used.

##### 3. Iterative checking

Now the function will try adjusting all three delta-v elements of the manoeuvre node together. There are 27 nodes per loop, as each element is in turn decremented by `dv_delta`, left the same or incremented by `dv_delta`, meaning there are `3^3` combinations.

    LOCAL done IS FALSE.
    UNTIL done {
      LOCAL curr_score IS best_score.

      FOR p_loop IN RANGE(-1,2,1) { FOR n_loop IN RANGE(-1,2,1) { FOR r_loop IN RANGE(-1,2,1) {
        LOCAL p_diff IS dv_delta * p_loop.
        LOCAL n_diff IS dv_delta * n_loop.
        LOCAL r_diff IS dv_delta * r_loop.
        SET best_score TO ubn(newNodeByDiff(node,0,r_diff,n_diff,p_diff), best_node, best_score).
      } } }

      IF ROUND(best_score,3) > ROUND(curr_score,3) { nodeCopy(best_node, node). }
      ELSE IF dv_delta < 0.02 { SET done TO TRUE. }
      ELSE { SET dv_delta TO dv_delta / 2. }
    }

After each set of adjustments there are three outcomes:
* We found a node with a better score. In this case we copy the new `best_node` over the original `node` and repeat the loop.
* We did not find an improvement:
  * if `dv_delta` is less than `0.02`m/s, we break out of the loop. We have found our 'best' node. It is assumed that corrections smaller than this will not have enough of an effect on the trajectory to matter and that processing them would be a waste of time. This may not be true for trajectories where the end point is a long time in the future e.g. a transfer to Jool. There's no technical reason for breaking the loop at this particular value; it can be changed if necessary.
  * otherwise we halve the value of `dv_delta` and repeat the loop.

Note - to avoid infinite or apparently-infinite loops, we round the old and new best scores to three decimal places before comparing them.

Note - the elements are adjusted together in order to try to find solutions that might be missed if we can only change one element at a time. This does mean checking 27 nodes per loop instead of 6, however.

#### `nodeBodyToMoon(u_time, destination, periapsis, inclination, longitude_of_ascending_node)`

This function generates and returns a manoeuvre node that will transfer to the `destination` from its parent body, targeting an orbit that matches the input `periapsis`, `inclination` and `longitude_of_ascending_node` as best as possible.

This calls `nodeHohmann()` from `lib_hoh.ks` to calculate a node for the required transfer orbit, then passes the node into `improveNode()`. This is documented in the `lib_hoh_readme.md` file.

The `target_periapsis` (reminder from `lib_hoh.ks`: if `target_periapsis` is specified, the transfer orbit's apsis will be that many metres further out than the centre of the target) passed in to `nodeHohmann()` is calculated via this line:

    LOCAL target_periapsis IS (destination:RADIUS + periapsis) * COS(MIN(inclination,0)).
The `MIN(inclination,1)` is there because while the actual target inclination should be in the range `0`-`180`, it's possible to pass in `-1` if no preference is specified. In those cases, `0` (equatorial prograde orbit) will be used instead in this calculation.

#### `nodeMoonToBody(u_time, destination, periapsis, inclination, longitude_of_ascending_node)`

TBD

#### `taEccOk(orbit, true_anomaly)`

When dealing with a hyperbolic orbit, the `secondsToTA()` function performs `LN(x + SQRT(x^2 - 1))` where x is calculated as `(e+COS(ta)) / (1 + (e * COS(ta)))`. If we try to calculate the time until a true anomaly that does not exist, we can end up trying to calculate the natural log of a negative number. This is impossible and will crash the script. To protect against that, this function exists to check whether that would occur before making a call to `secondsToTA()`.

There may be a better way of working out the range of valid true anomaly values for a hyperbolic orbit.

#### `orbitNeedsCorrection(current_orbit, destination, periapsis, inclination, longitude_of_ascending_node)`

The purpose of this function is to determine whether the current orbit needs a correction burn to bring it in line with the desired orbital parameters at the destination.

It returns `TRUE` if a correction is needed and possible, `FALSE` otherwise.

Note that the part of `doTransfer()` that calls this can effectively disregard the result of this if the node improvement function returns a very small node (less than `0.2`m/s) when asked to generate a correction.

The processing has several considerations that it goes through in turn until it hits one that forces a return:
* if there is not enough time for a node prior to reaching a spehere of influence change or the periapsis at the `destination`, `FALSE` is returned immediately.
* if the current orbit does not reach the destination, `TRUE` is returned immediately.
* if the current orbit has a periapsis at the destination that is below the 'safe minimum' (`20`km above sea-level or `15`km above the atmosphere height, if there is one), but the desired periapsis is above that minimum, `TRUE` is returned immediately.
* the following table gives the maximum differences allowed between the target periapsis and the predicted periapsis. If the actual difference is greater than this, `TRUE` is returned immediately:

Table of maximum allowed differences between currently-predicted periapsis and the target `periapsis` (more orbit patches than shown are considered, with the allowed difference being multiplied by `10` for each extra patch):

    // -----------------------+------+-------+--------+
    // Number of orbit patches|  0   |   1   |    2   |
    // until destination      |      |       |        |
    // -----------------------+------+-------+--------|
    // -----------------------+------+-------+--------|
    // If periapsis below safe|  1km |  10km |  100km |
    // minimum                |      |       |        |
    // -----------------------+------+-------+--------|
    // If periapsis above safe| 10km | 100km | 1000km |
    // minimum but below twice|      |       |        |
    // safe minimum or 250km, |      |       |        |
    // whichever is larger    |      |       |        |
    // -----------------------+------+-------+--------|
    // If periapsis is above  | 25km | 250km | 2500km |
    // the above thresholds   |      |       |        |
    // -----------------------+------+-------+--------+

* if the input `inclination` is not negative (as `-1` indicates no preference), and the current orbit's central body is the `destination`, a node to correct the inclination may be considered: 
  * if the input `longitude_of_ascending_node` is negative (as `-1` indicates no preference), then if the predicted inclination is more than `0.05` degrees different to the target `inclination`, `TRUE` is returned immediately.
  * if the input `longitude_of_ascending_node` is not negative, then if the angle between the orbital plane defined by the input `inclination` and `longitude_of_ascending_node` is more than `0.05` degrees from the predicted plane, further checking is performed to see if a inclination change at the intersection of the two orbits is possible:
    * the true anomalies of the ascending and descending nodes are calculated by vector crossing the normal vectors of the two orbits. If the true anomalies are valid for the current orbit's eccentricity (checked by calling `taEccOk()`), each is considered in turn. If one of the nodes is more than `15` minutes in the future and more than `15` minutes prior to reaching periapsis, `TIME_TO_NODE` is set to the ETA to the node and `TRUE` is returned immediately.
* if we have reached this point, `FALSE` is returned to indicate that we don't need a correction.

#### `doTransfer(exit_mode, can_stage, periapsis, inclination, longitude_of_ascending_node)`

TBD

Geoff Banks / ElWanderer
