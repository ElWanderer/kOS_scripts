## lib\_burn (manoeuvre node burn library)

### Description

This library contains code used to execute a manoeuvre node.

Effectively, the library provides a single function `execNode(staging_enabled)` that will perform all the necessary steps to burn the craft's next manoeuvre node.

#### Self-correcting manoeuvre node burns

Most manoeuvres are executed by keeping the craft aimed at the manoeuvre node for the majority of the burn. To prevent wild oscillations near the end of a burn, the steering switches to following a fixed vector for the last few m/s.

Most manoeuvre node burns are ended once the angle between the original node vector and the current node vector has grown too large. This angle naturally grows quickly as the remaining delta-v of the node approaches zero (as only lateral velocity remains unburnt), and becomes very large if we overburn such that the node is now pointed backwards.

Should the available thrust drop to 0, the behaviour depends on whether staging is allowed or not, and whether there is an engine we could enable:
* If staging is allowed and there is another engine, the throttle will be cut and staging will take place until a new engine is lit. Normal throttle control will then resume.
* If staging is disallowed or we cannot find another engine, the burn will end.

#### "Small" manoeuvre node burns

Orbits in KSP can be wobbly due to floating point calculation errors, and due to the rotation of the ship changing the location of the centre of mass. The vector of a manoeuvre node can be affected by rotating the ship too. These issues may have been improved in recent KSP releases, but experience has shown that for short duration burns, the usual burn procedure outlined above can be unsuitable. Trying to align to the manoeuvre node is hard if the node keeps moving as the ship rotates. Trying to end the burn based on the angle between original node and current node results in the burn ending immediately if the node is jittering back-and-forth.

Instead of trying to follow the node's vector, a "small" burn is executed by aligning with a fixed vector (the node's original burn vector) and burning for a fixed time period.

Staging is disabled for "small" burns. Should the available thrust drop to 0, the burn is ended immediately.

"Small" nodes are identified by burn length and/or the delta-v requirement.

### Requirements

 * `lib_dv.ks`
 * `lib_node.ks`
 * `lib_steer.ks`

### Global variable reference

#### `BURN_WARP_BUFF`

This defines the number of seconds prior to the burn start time (derived by taking the time of the node and subtracing half the the calculated time to burn the node's delta-v) that the script will warp to.

The default is `15`. This is quite short because the script aligns the craft with the manoeuvre node prior to engaging time warp. If necessary, it can be changed by calling `changeBURN_WARP_BUFF(new_value)`. For larger vessels, more time may be needed to re-align between coming out of time warp and ignition.

#### `BURN_MAX_THROT`

The function that sets `BURN_THROTTLE`, `burnThrottle(burn_time)`, will not set it higher than this value.

The default is `1` (100%).

There is currently no function to change this value.

#### `BURN_MIN_THROT`

The function that sets `BURN_THROTTLE`, `burnThrottle(burn_time)`, will not set it lower than this value.

The default is `0.1` (10%).

There is currently no function to change this value.

#### `BURN_SMALL_SECS`

The burn length (in seconds) threshold below which a burn is deemed to be "small".

The default is `1`s.

There is currently no function to change this value.

#### `BURN_SMALL_DV`

The delta-v (in m/s) threshold below which a burn is deemed to be "small". This is also used during the burn of a node that isn't "small" - it is the threshold of delta-v remaining where we switch from aligning the steering with the node to following a fixed steering vector.

The default is `5`m/s.

There is currently no function to change this value.

#### `BURN_THROTTLE`

During the script we lock the throttle to this global: `LOCK THROTTLE TO BURN_THROTTLE.`

`BURN_THROTTLE` can then be altered as needed to change the throttle.

#### `BURN_NODE_IS_SMALL`

A boolean to indicate whether the manoeuvre node burn is "small" or not. This is calculated during the burn set-up.

#### `BURN_SMALL_THROT`

When burning a "small" node, `BURN_THROTTLE` is set to this value following its calculation.

### Function reference

#### `changeBURN_WARP_BUFF(new_value)`

Sets the `BURN_WARP_BUFF` global to a new value, or 15 seconds if no new value has been provided.

#### `pointNode(node)`

Firstly, this calls the `lib_steer` function `steerTo(anonymous_function_delegate)` to align the steering with the node. The anonymous function passed in to `steerTo()` depends on whether the node has been determined to be "small" or not. For "small" nodes, a copy of the node's current burn vector is passed through - this is fixed. Otherwise, a reference to the node's current burn vector is passed through - this will change as the node changes.

Secondly, this calls the `lib_steer` function `WAIT UNTIL steerOk(0.4).` This will loop until the angle between the steering vector and the craft's fore vector is below 0.4 degrees, and the craft's angular velocity has dropped below a threshold. Or more simply, this waits until the craft is pointed at the manoeuvre node and barely rotating.

#### `checkNodeSize(node_burn_time, node_delta-v, stage_delta-v)`

This sets `BURN_NODE_IS_SMALL`.

A node is deemed to be "small" if either the node's delta-v is below `BURN_SMALL_DV` or the node's predicted burn time is less than `BURN_SMALL_SECS`.

`BURN_NODE_IS_SMALL` cannot be set to `TRUE` if the calculated current stage delta-v is not higher than the node's delta-v. The "small" node execution function does not stage, so the full execution logic would need to be used instead.

#### `burnThrottle(burn_time)`

Calculates and returns the throttle setting based on the input burn time. This drops the throttle proportionally if the burn time is below one second (i.e. if the burn time is half a second, the throttle will be set to 0.5), but with certain restrictions:
 * The throttle cannot be set to a value higher than `BURN_MAX_THROT` or a value lower than `BURN_MIN_THROT`.
 * For the purposes of realism, the throttle is set in 0.05 (5%) increments.

#### `burnSmallNode(node, burn_time)`

Burns at `BURN_SMALL_THROT` until either burn time seconds have elapsed, or the available thrust has dropped to 0.

#### `burnNode(node, burn_time, staging_allowed)`

The basis of this function is/was the example node burn script in the kOS documentation, but I've made quite a few changes.

The function starts by storing the current node vector (refered to below as the original node vector) so it can be checked later.

There is a small piece of Kerbal Alarm Clock integration. If KAC is available, any alarms for the craft that are due to pop up in the five minutes prior to the node are automatically deleted.

The function then waits until the ETA to the node is half the burn time. If the node is "small", it will call `burnSmallNode(node, burn_time)`. Otherwise it will execute the main node burn logic loop:

* Each tick, the available acceleration is checked. If the acceleration is non-zero:
  * The throttle is set by passing a rough calculation of the burn time (delta-v / current acceleration) in to `burnThrottle(burn_time)`
  * If the original and current node vectors are opposed (i.e. the angle between them is more than 90 degrees), the burn is ended
  * If we are still steering towards the node, we check if the remaining delta-v of the node has dropped below the `BURN_SMALL_DV` threshold. Once the remaining burn is "small", we:
    * replace the original node vector with a new copy of the current node vector
    * switch the steering to point at this copy of the node vector
* Otherwise, if the acceleration is zero, the throttle is set to zero and:
  * If staging is enabled and there are more engines to stage, we will try to stage every half a second until the acceleration is non-zero.
  * Otherwise, if staging is not enabled or we cannot find any engines to stage, we will abort the burn.

Once the burn has finished, the steering is damped and the throttle unlocked. The current orbit is printed out so that it can be compared to the target orbit, along with the remaining delta-v.

Returns `TRUE` or `FALSE` depending on whether the burn was successful or not.
Note - a burn is deemed unsuccessful if the node has 1m/s or greater remaining.

#### `warpCloseToNode(node, burn_time)`

IF the node is more than 15 minutes in the future (900 seconds) and the predicted burn time is not greater than 28 minutes (1680 seconds), steers towards the Sun and calls `doWarp()` to time warp until the burn is fifteen minutes away.

Note - the check on the burn time uses 28 minutes rather than 30 (you'd reasonably expect it to use twice the 15 minutes/900 seconds we want to be before the node) as an extra safety factor.

#### `warpToNode(node, burn_time)`

Calculates a burn start time based on the current time, the node's ETA, half the input burn time and `BURN_WARP_BUFF`. If this time is in the future, it calls `doWarp()` to time warp.

#### `execNode(staging_allowed)`

The main function. This calls the others in turn to execute the next manoeuvre node.

In turn, this function
* gets the next manoeuvre node or returns `FALSE` if there is no next node
* calculates whether the craft has enough delta-v to burn the node (using `lib_dv` functions) and will return `FALSE` unless there is enough delta-v or both staging is enabled and there are more engines to stage.
* checks whether the burn is "small" or not and calculates the predicted burn time - the latter of these uses the more accurate (but slower) `lib_dv` function `burnTime()`
* if the time to start the burn is more than about fifteen minutes away, points the craft towards the Sun and time warps to a time fifteen minutes prior to the burn start time
* aligns the craft with the node
* activates time warp to a time shortly before the burn is due to start
* burns the node
* removes the node if the burn was successful

Returns `TRUE` or `FALSE` depending on whether the burn was successful or not.
Note - a burn is deemed unsuccessful if the node has 1m/s or greater remaining. This will be left on the flight-plan so that you can see it and take corrective action.

Geoff Banks / ElWanderer
