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

This has its own function for changing the value: `changeRDZ_MAX_ORBITS()`. It is recommended that the value is set based on the individual reuirements of the mission, typically fuel versus time.

#### `RDZ_PHASE_PERIOD`

This is used to store the period of the phasing orbit that has been determined. It is one of three global variables that are stored and so recovered on a reboot, to avoid needing to recalculate it.

The initial value is `0`.

#### `RDZ_CA_DIST`

This is used to store the expected closest approach between the active vessel and the rendezvous target. It is one of three global variables that are stored and so recovered on a reboot, to avoid needing to recalculate it.

The initial value is `5000`m.

#### `RDZ_CA`

This is a string that is used as the key name in the `TIMES` lexicon. On initialisation, the current time is pushed into `TIMES[RDZ_CA]` by calling `setTime(RDZ_CA)`, but this is replaced with the expected *future* time of closest approach later on. This closest approach time is one of three global variables that are stored and so recovered on a reboot, to avoid needing to recalculate it.

The value is itself the string `RDZ_CA`. This is used in place of string literals because it makes the store command easier to write: `append("setTime(RDZ_CA," + TIMES[RDZ_CA] + ").", RDZ_FN).` instead of `append("setTime("+CHAR(34)+RDZ_CA+CHAR(34)+",TIMES["+CHAR(34)+"RDZ_CA"+CHAR(34)+"]).", RDZ_FN).` where `CHAR(34)` is the `"` character.

#### `RDZ_THROTTLE`

This is used during final approach to control the throttle. The main `THROTTLE` is locked to this value, which is then varied by the script as necessary.

The initial value is `0`.

*EVERYTHING BELOW THIS LINE IS A COPY OF THE lib_transfer README THAT HASN'T BEEN REPLACED YET!*

### Function reference

#### `bodyChange(prev_body)`

This returns `TRUE` if the current `BODY` is the same as the input `prev_body`, and `FALSE` if they are different.

#### `minAltForBody(body)`

This returns the 'minimum safe periapsis' for the input 'body'. Above this value, the node improvement algorithm prioritises delta-v economy over accuracy. Below this value, accuracy scores very highly.

The function returns `25`km or `25%` of the radius of `body`, whichever is higher.

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
* The trajectory is then scored, depending on whether the target periapsis is below the 'minimum altitude' (as returned by `minAltForBody()`). If the target periapsis is below the minimum, we prioritise high accuracy:
  * we add large bonus points if the predicted periapsis is within `2500`m of the target periapsis, with the bonus rising to a maximum of `500` if the two are aligned.
  * otherwise a penalty is subtracted from the score, based on the discrepancy between the two values.
  * In both cases, square root functions are used to try to smooth the points curves - in particular the penalty grows slowly as the discrepancy increases so that the overall score shouldn't become negative (and therefore should always score higher than a trajectory that misses the target altogether).
* If the target periapsis is above the minimum, the exact periapsis is not so important, compared to making sure that the trajectory is not sub-orbital and minimising delta-v expenditure:
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

#### `nodeBodyToMoon(universal_timestamp, destination, periapsis, inclination, longitude_of_ascending_node)`

This function generates and returns a manoeuvre node that will transfer to the `destination` from its parent body, targeting an orbit that matches the input `periapsis`, `inclination` and `longitude_of_ascending_node` as best as possible.

This calls `nodeHohmann()` from `lib_hoh.ks` to calculate a node for the required transfer orbit, then passes the node into `improveNode()`. This is documented in the `lib_hoh_readme.md` file.

The `target_periapsis` (reminder from `lib_hoh.ks`: if `target_periapsis` is specified, the transfer orbit's apsis will be that many metres further out than the centre of the target) passed in to `nodeHohmann()` is calculated via this line:

    LOCAL target_periapsis IS (destination:RADIUS + periapsis) * COS(MAX(inclination,0)).
The `MAX(inclination,0)` is there because while the actual target inclination should be in the range `0`-`180`, it's possible to pass in `-1` if no preference is specified. In those cases, `0` (equatorial prograde orbit) will be used instead in this calculation.

#### `nodeMoonToBody(universal_timestamp, moon, periapsis, inclination, longitude_of_ascending_node)`

This function generates and returns a manoeuvre node that will transfer from `moon` to its parent body, targeting an orbit that matches the input `periapsis`, `inclination` and `longitude_of_ascending_node` as best as possible.

This function uses a lot of complicated maths to calculate the size of the ejection burn and the angle at which this burn needs to take place. It then uses a dumb iteration to walk forwards in time at short intervals until it finds a position on the orbit where the ejection angle is correct. This last part could be improved by adding in more maths to calculate where the burn should take place.

It should be noted that the function works on the basis that orbits are circular or circular enough not to make any difference.

Firstly, the function sets up some useful values relating to the `moon` we're leaving and the destination we will be arriving around. Calculations need to take place within both spheres of influence.

    LOCAL dest IS moon:OBT:BODY.
    LOCAL mu IS moon:MU.
    LOCAL hoh_mu IS dest:MU.
    LOCAL r_soi IS moon:SOIRADIUS.
    LOCAL r_pe IS ORBITAT(SHIP,u_time):SEMIMAJORAXIS.

Secondly, the function calculates the velocity required in terms of the destination for a Hohmann transfer orbit from the radius of the `moon`'s orbit (assuming we have just left the sphere of influence of the `moon` at that radius) to the desired `periapsis`.

    LOCAL r1 IS ORBITAT(moon,u_time):SEMIMAJORAXIS.
    LOCAL r2 IS dest_pe + dest:RADIUS.
    LOCAL v_soi IS SQRT(hoh_mu/r1) * (SQRT((2*r2)/(r1+r2)) -1).

This velocity at the sphere of influence transition can be converted back to the velocity at the (new) periapsis of the ejection orbit around the `moon`:

    // hyperbolic excess velocity
    // v_inf = SQRT(v^2 - (2 * mu / r)), for any combination of v and r
    //
    // v1 is velocity at periapsis, r1 is radius at periapsis
    // v2 is velocity at sphere of influence boundary, r2 is radius of sphere of influence
    //
    // v_inf = SQRT(v1^2 - (2 * mu / r1)) = SQRT(v2^2 - (2 * mu / r2))
    // v1^2 - (2 * mu / r1) = v2^2 - (2 * mu / r2)
    // v1^2 = v2^2 - (2 * mu / r2) + (2 * mu / r1)
    // v1 = SQRT (v2^2 - (2 * mu / r2) + (2 * mu / r1))
    LOCAL v_pe IS SQRT(v_soi^2 + (2 * mu/r_pe) - (2 * mu/r_soi)).

Comparing this velocity to that we would have in a circular orbit gives us the (purely prograde) magnitude of the ejection burn:

    LOCAL v_orbit IS SQRT(mu/r_pe).
    LOCAL dv IS ABS(v_pe) - v_orbit.

A node of this magnitude is created at the `universal_timestamp`. This will be updated later to an appropriate timestamp if this can be calculated.

Thirdly, the function calculates the ejection angle, that is the angle around the orbit that the burn should be placed so that the hyperbolic escape orbit tends to being parallel with the orbit path of `moon`. This requires finding out the eccentricity, which in turns means calculating the specific orbital energy of the orbit.

    // ejection angle = ARCCOS(-1/e)
    // eccentricity e = SQRT(1 + (2 * E * h^2) / mu^2)
    // specific orbital energy E = (v^2/2) - (mu/r)
    // e = SQRT((v_inf^2 * h^2 / mu^2) + 1)
    // where h is the magnitude of the cross product of the position and velocity vectors (r x v)
    LOCAL a IS 1/((2/r_pe)-(v_pe^2 / mu)).
    LOCAL r_ap IS (2 * a) - r_pe.
    LOCAL energy IS (v_pe^2 / 2)-(mu / r_pe).
    LOCAL h IS r_pe * v_pe.

    // if energy is negative, we are in an elliptical orbit and so the eccentricity can be calculated
    // from periapsis and apoapsis instead
    LOCAL e IS 0.
    IF energy >= 0 { SET e TO SQRT(1 + (2 * energy * h^2 / mu^2)). }
    ELSE { SET e TO (r_ap - r_pe) / (r_ap + r_pe). }
    
    // We can only calculate the ejection angle if the orbit is a hyperbola, i.e. if it has an eccentricity
    // greater than 1. If the orbit is elliptical, then it is not  expected to escape the current body. 
    // Non-escape orbits can occur on valid transfer trajectories in KSP because some of the bodies
    // have much smaller spheres of influence than their mass would suggest.
    // In cases where we cannot calculate, we start with an estimate of 100 degrees.
    LOCAL theta_eject IS 100.
    IF e > 1 { SET theta_eject TO ARCCOS(-1/e). }
    ELSE { pOut("WARNING: Cannot calculate ejection angle as required orbit is not a hyperbola."). }

Lastly, having gone to the trouble of sifting through all these formula, we revert back to advancing the clock in `15` second intervals, each time checking to see if the ejection angle would be correct (within `0.5` degrees) if the burn took place there. 

Also considered is the effect of the inclination. If we are in a perfect, `90` degree inclination polar orbit, the plane of our orbit is only rarely aligned with the direction of travel of the `moon` we are orbiting. At a worst case, it will be at a `90` degree angle. Ejecting when that is the case will be possible, but more expensive. To save delta-v, the burn positions are rejected until the effective angle between the plane and the velocity of the `moon` is below `25` degrees. This value was selected somewhat arbitrarily.

Note - the "speed" at which the alignment between the orbit plane and the velocity of the `moon` depends on how quickly the `moon` goes around its parent body.

Once the angles are within the tolerances, the node that was plotted based on the details of the second step above is adjusted so that its time matches that found by the iteration. This is then fed into the node improvement function.

The node that has been generated is then returned.

#### `taEccOk(orbit, true_anomaly)`

When dealing with a hyperbolic orbit, the `secondsToTA()` function performs `LN(x + SQRT(x^2 - 1))` where x is calculated as `(e+COS(ta)) / (1 + (e * COS(ta)))`. If we try to calculate the time until a true anomaly that does not exist, we can end up trying to calculate the natural log of a negative number. This is impossible and will crash the script. To protect against that, this function exists to check whether that would occur before making a call to `secondsToTA()`.

This function uses `ARCCOS(-1/e))` as this gives the true anomaly at which the trajectory tends to infinity - anything beyond that is invalid and should not be used.

#### `orbitNeedsCorrection(current_orbit, destination, periapsis, inclination, longitude_of_ascending_node)`

The purpose of this function is to determine whether the current orbit needs a correction burn to bring it in line with the desired orbital parameters at the destination.

It returns `TRUE` if a correction is needed and possible, `FALSE` otherwise.

Note that the part of `doTransfer()` that calls this can effectively disregard the result of this if the node improvement function returns a very small node (less than `0.2`m/s) when asked to generate a correction.

The processing has several considerations that it goes through in turn until it hits one that forces a return:
* if there is not enough time for a node prior to reaching a spehere of influence change or the periapsis at the `destination`, `FALSE` is returned immediately.
* if the current orbit does not reach the destination, `TRUE` is returned immediately.
* if the current orbit has a periapsis at the destination that is below the 'safe minimum' (as returned by `minAltForBody()` multiplied by a factor of 0.8), but the desired periapsis is above that minimum, `TRUE` is returned immediately.
  * The factor of 0.8 in the 'safe minimum' check is there to avoid situations where the 'best' trajectory was just above the 'safe minimum' but the execution of the burn resulted in a periapsis just below it, thus requiring a correction. The correction function gives more leeway to account for the natural inaccuracy of burns. It should also be noted this was added because the node improvement function tended towards trajectories that used the minimum periapsis, perhaps because the Oberth effect made these the most efficient of all the options in terms of delta-v usage.
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

#### `doTransfer(exit_mode, can_stage, destination, periapsis, inclination, longitude_of_ascending_node)`

This function provides the main interface for controlling a craft during a transfer from one body to another.

`exit_mode`: This is the runmode that the script will switch back to following a successful transfer. The function itself has its own set of runmodes in the range `101`-`149`.

`can_stage`: `TRUE`/`FALSE`. This is passed into each call to `execNode()` (`lib_burn.ks`).

`destination`: The target body. Currently, transfers are supported between bodies that are above or below each other in the hierarchy i.e. a planet to its moon, or back from a moon to its parent planet. These should also allow transfers between Solar orbits and planets (and vice versa) though this has not been tested.

`periapsis`: Defines the desired target orbit altitude around the `destination`. 
  * If this altitude is above the atmosphere of the `destination`, the script will aim for a target orbit thas this altitude as both periapsis and apoapsis. The script does not guarantee that this orbit will be achieved perfectly, though it will try to minimise the cost to get into such an orbit. It is recommended to follow up with corrections if the target orbit needs to be accurate.
  * If this altitude is within the atmosphere of the `destination`, the script will try to hit the periapsis accurately (within `1`km) on the grounds that you are trying to re-enter.

`inclination`: Defines the desired inclination of the orbit around the `destination`. `-1` can be used to indicate no preference. The script does not guarantee that this will be the final inclination (see below).

`longitude_of_ascending_node`: Defines the desired LAN of the orbit around the `destination`. `-1` can be used to indicate no preference. Note that no attempt is (currently) made to time a transfer such that the `destination` will be optimally aligned. The script does not guarantee that this will be the final LAN (see below).

On orbital planes: the script cannot guarantee that a particular orbital plane (defined by `inclination` and `longitude_of_ascending_node`) will result after a transfer, especially as changing inclination may not be possible. A lot depends on whether the eventual transfer orbit has an ascending or descending node with the target orbit plane in the right place. It has to occur within the sphere of influence of the `destination`, before the periapsis has been reached. The node improvement functions will try to reduce the delta-v requirement to match the orbit after circularisation. It is recommended to follow up with corrections if the target orbit needs to be accurate.

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
