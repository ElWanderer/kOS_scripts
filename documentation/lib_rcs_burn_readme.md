## lib\_rcs\_burn.ks (RCS node execution and delta-v calculation library)

### Description

This library is effectively a set of additions for `lib_dv.ks` and `lib_burn.ks` that allow RCS thrusters to be used to execute manoeuvre nodes.

This library contains code used to execute a manoeuvre node, various functions for calculating the delta-v available to a craft and how long burns are predicted to take.

### Requirements

 * `lib_rcs.ks`
 * `lib_burn.ks`

### Global variable reference

#### `RCS_BURN_FUELS`

This stores a list of fuels that can be used by RCS thrusters. The initial list has one value: `MonoPropellant`. Other fuels could be added as needed.

#### `RCS_BURN_ISP`

The `lib_dv.ks` equivalent of this holds the thrust-weighted average Isp (specific impulse) calculated by looping through all the currently-ignited engines. But we do not have the same information available for RCS thrusters (and they could be pointing in all different directions) so instead we just default a value of `240`s.

#### `RCS_BURN_T`

Holds the thrust available for RCS thrusters. This is initialised as `0` and set by `rcsSetThrust()`.

### Function reference

#### `rcsPartThrust(part)`

This function calculates how much thrust an RCS thruster can contribute to the craft. This is restricted to thrust aligned with the facing of the craft.

The thrust of an RCS part is not available, so we have to hard-code known thrust values. Also, we have to consider that the facing of the part varies depending on the type of thruster.

    // The 4-way thruster block has 4 1kN thrusters, aligned such that they fire
    // along the part's facing vector, top vector and their inverses.
    // This means the part's starboard vector is normal to plane of the thrusters.
    // If the starboard vector is aligned with the ship's facing vector, a VDOT()
    // of the two will return 1, but no useful thrust is produced. Hence we
    // calculate the thrust as 1 - the VDOT().
    IF part:NAME = "RCSBlock" {
      RETURN 1 - ABS(VDOT(part:FACING:STARVECTOR,FACING:VECTOR)).
    }

    // The linear thruster is more powerful than the individual 4-way thrusters: 2kN
    // This fires in-line with the part's facing vector, so a VDOT() of that and the
    // ship's inverse facing returns how much thrust points in the right direction.
    // We apply a MAX(0,) because we do not want to consider thrusters pointing
    // backwards!
    IF part:NAME = "linearRCS" {
      RETURN 2 * MAX(0,VDOT(part:FACING:VECTOR,-FACING:VECTOR)).
    }

If the part is not one of the known types, the thrust is returned as `0`.

#### `rcsSetThrust()`

This function sets `RCS_BURN_T`. It loops through all the parts that have the `ModuleRCSFX` module, passing them into `rcsPartThrust()` and totalling the results.

#### `rcsDV()`

Calculates the delta-v available if using RCS thrusters.

This starts by calculating the fuel mass, by passing `SHIP:RESOURCES` and `RCS_BURN_FUELS` into `fuelMass()`.

This lets us calculate the delta-v via the Tsiolkovsky rocket equation: `delta-v = g0 * Isp * ln(m0 / m0 - fuel_mass)`

#### `rcsPDV()`

Prints out the current RCS delta-v. This calls `rcsDV()`

#### `rcsBurnTime(delta-v)`

Calculates the length of time required to burn the input amount of `delta-v` with RCS.

The function calls `btCalc()` to get the predicted burn length, assuming the ship has enough fuel for the entire burn.

#### `rcsBurnNode(node, burn_time)`

This function is based on `burnNode()` in `lib_burn.ks`.

It starts by storing the current node vector (refered to below as the original node vector) so it can be checked later.

There is a small piece of Kerbal Alarm Clock integration. If KAC is available, any alarms for the craft that are due to pop up in the five minutes prior to the node are automatically deleted.

The function then waits until the ETA to the node is half the burn time. It then turns RCS on (if it wasn't alread) and uses the `lib_rcs.ks` function `doTranslation()` to translate in the direction of the manoeuvre node. This continues until either:
* the original and current node vectors are opposed (i.e. the angle between them is more than 90 degrees)
* the calculated RCS delta-v available is less than the size of the current node vector.

The RCS setting (on or off) is then returned to the value it had prior to the burn.

Returns `TRUE` or `FALSE` depending on whether the burn was successful or not.
Note - a burn is deemed unsuccessful if the node has 1m/s or greater remaining.

#### `rcsExecNode()`

The main function. This calls the others in turn to execute the next manoeuvre node with RCS thrusters. This is based on `execNode()` in `lib_burn.ks`.

In turn, this function:
* gets the next manoeuvre node or returns `FALSE` if there is no next node
* calculates whether the craft has enough delta-v to burn the node and will return `FALSE` unless there is enough delta-v.
* calculates the predicted burn time
* if the time to start the burn is more than about fifteen minutes away, points the craft towards the Sun and time warps to a time fifteen minutes prior to the burn start time
* aligns the craft with the node. Note the function sets `BURN_NODE_IS_SMALL` to `TRUE`, which means the craft will align with the original node vector then hold that heading. It will not turn to follow the node direction if it changes during the burn.
* activates time warp to a time shortly before the burn is due to start
* burns the node (calling `rcsBurnNode()`)
* removes the node if the burn was successful
* damps the steering

Returns `TRUE` or `FALSE` depending on whether the burn was successful or not.
Note - a burn is deemed unsuccessful if the node has 1m/s or greater remaining. This will be left on the flight-plan so that you can see it and take corrective action.

Geoff Banks / ElWanderer
