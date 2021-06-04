## lib\_dv.ks (delta-v calculation library)

### Description

This library has various functions for calculating the delta-v available to a craft and how long burns are predicted to take.

#### Delta-v calculation

These are relatively simplistic and only work for the current stage, assuming it is burning liquid fuel and/or oxidiser. No attempt is made to trawl through the entire vessel tree, calculating stage-by-stage. The main purpose is to be able to ask the question: "can we do this burn with this craft, without staging?"

#### Burn time calculation

The functions that calculate how long it will take to burn a manoeuvre node are able to take into account a single staging event mid-burn. The most likely place for this is during orbital insertion, for early-to-mid-VAB-tier spacecraft where the launcher doesn't have quite enough delta-v to reach orbit. The payload takes over to finalise the burn, while the launcher drops back into the atmosphere. This calculation code is simplified to keep it from growing too large, so there are restrictions.

It tries to find a single liquid-fuel engine that has a decoupler attached that will get rid of the current stage. This works for typical stock KSP rockets (as long as you don't have radial engines) but may not be appropriate for more unusual designs or multiple engines e.g if using something like Space-Y or RO/RSS. If an engine can't be found, a guess is made that the next (full) stage will take 2-3 times longer than the old (almost-empty) stage to provide the required delta-v.

Secondly, though the burn time may be calculated accurately, no attempt is currently made to account for wildly-different thrust levels. If a burn is expected to start off with a Swivel and end with an Ant, you may find that although the burn lasts the predicted length and provides the right amount of delta-v, most of that delta-v will have been produced early on in the burn. This can have undesired results such as pushing out the apoapsis too high then failing to bring the periapsis up out of the atmosphere.

### Requirements

 * `lib_parts.ks`

### Global variable reference

#### `DV_PL`

Holds a list of part IDs. Typically this is used to store which parts we have looked at to find fuel, so that we don't consider a part more than once.

#### `DV_FM`

Holds the fuel mass that was found. Typically this is calculated by one function, then used by others. 

#### `DV_ISP`

Holds the thrust-weighted average Isp (specific impulse) calculated by looping through all the currently-ignited engines. Typically this is calculated by one function, then used by others.

#### `DV_FR`

Holds the total fuel rate (in tonnes per second) of all the currently-ignited engines. Typically this is calculated by one function, then used by others.

#### `DV_FUELS`

Holds the default set of fuel resource names to look for when determining the fuel mass available. This is not expected to be changed, though potentially it could be overridden for other fuel types, particularly those added by other mods.

This is set to the list: `LiquidFuel` and `Oxidizer`.

### Function reference

#### `fuelRate(thrust, isp)`

Returns the fuel rate (in tonnes per second) for the input thrust and Isp. Returns `0` if the input Isp is `0`, to avoid a divide-by-zero error.

Fuel rate (the change in mass over time) can be calculated by dividing the total thrust by the effective exhuast velocty (`Ve`, given by `Isp * g0`).

#### `currentStageEngines()`

This returns a list of engines that are currently active. Engines are put into the return list if they are lit (`IGNITION` is `TRUE`) and have not flamed out (`FLAMEOUT` is `FALSE`).

#### `btCalc(delta-v, initial_mass, isp, fuel_rate)`

Calculates the burn length in seconds based on the input parameters. Returns `0` if the input Isp or fuel rate are `0`, to avoid a divide-by-zero error.

This is calculated by rearranging the Tsiolkovsky rocket equation. First we rearrange the equation to determine the final mass (m1) based on the initial mass (m0), delta-v and Isp:

    delta-v = Ve * ln(m0 / m1)
    delta-v / Ve = ln(m0 / m1)
    e^(delta-v / Ve) = m0 / m1
    m1 = m0 / e^(delta-v / Ve)
    
    Ve = g0 * Isp
    m1 = m0 / e^(delta-v / (g0 * Isp))

Then we know the change in mass, delta-m (`m0-m1`), needed to provide the required delta-v. This change in mass will take `delta-m / fuel-rate` seconds to achieve with the current fuel rate.

This is a more accurate calculation than dividing the total change in velocity required by the acceleration of the craft with its current mass, as the craft's acceleration will increase during the burn.

#### `partMass(part)`

Returns the mass of a part and all the parts below it in the parts tree. This function is recursive.

The purpose is that given a decoupler part, we can determine the mass that will be discarded if the decoupler fires (making the assumption that the child parts are those that will be ejected with the decoupler - this assumption can break if a craft is re-rooted).

#### `engCanFire(engine)`

A helper function that checks an engine is not already ignited, can be shutdown and can be restarted.

As part of the `nextStageBT()` calculation, we need to trigger the next engine to find its details. We only want to do that if we know that we can shutdown the engine immediately afterwards, and that it can then be started again when we need it for the burn.

#### `moreEngines()`

Loops through all the engines on the craft, calling `engCanFire()`. If `engCanFire()` returns `TRUE` for any engine, this function returns `TRUE`.

#### `nextStageBT(delta-v)`

The purpose of this function is to estimate the required burn time following a staging event.

Firstly, we loop through all the engines, looking for those that are inactive but could be staged, by calling `engCanFire()`. For each engine that could be fired, we calculate the total mass of all the parts in the parts tree below the engine. This assumes that the engine we want to fire next has a decoupler attached, to which is in turn attached the fuel tanks, engines etc. that make up the current stage.

We store the engine that has the smallest total child mass attached, as this is assumed to be the next engine (engines higher up the rocket would stage off more mass if their decoupler were activated). We also store the total child mass that would be jettisoned.

By subtracting the total child mass from the mass of the rocket, we calculate the wet mass (i.e. full mass) of the next stage. We then calculate the burn time by passing in this initial mass, the delta-v required and the thrust and Isp of the next engine. In order to get the thrust and Isp of an inactive engine, we have to activate it and wait until the next physics tick. Once we have the data, we then deactivate it. This is inherently risky, so we lock the throttle to 0 beforehand.

#### `setIspFuelRate(limiter)`

This function calculates the thrust-weighted average Isp (specific impulse) and total fuel rate (tonnes per second) of the current stage, then stores them in `DV_ISP` and `DV_FR`.

The default value for `limiter` is `1`. If provided, it should be a value greater than `0` (as `0` will cause a divide-by-zero error). It is used to calculate the fuel rate at a specific throttle setting (e.g. to calculate the fuel rate at 50% throttle, pass in a limiter value of `0.5`).

The total fuel rate is calculated calling `fuelRate(thrust,isp)` for each active engine and adding the result to the sum.

The thrust-weighted average Isp is more complicated. It is determined by dividing the total thrust of all active engines by the total `thrust over Isp` of all active engines: `Average Isp = Total(thrust) / Total(thrust/Isp)`

#### `fuelMass(resource_list, fuel_name_list)`

Given a `resource_list` (e.g. as returned by `STAGE:RESOURCES`, `SHIP:RESOURCES` or `specific_part:RESOURCES`), this function returns the total fuel mass of `fuel_name_list` contained within.

If not specified, the default value for `fuel_name_list` is `DV_FUELS`, which in turn has a default value of `LIST("LiquidFuel","Oxidizer")`.

#### `fuelMassChildren(part)`

This is part of the recursive part tree search for fuel. This function only recurses *down* the parts tree.

If the input `part` is a decoupler or its ID is already in the `DV_PL` list (indicating that the part has already been considered), no action is taken. Otherwise, there are three steps:
* the ID of the part (`part:UID`) is added to the `DV_PL` list of parts
* the fuel mass of the part (`fuelMass(part)`) is added to the `DV_FM` fuel mass tracker
* the `fuelMassChildren()` function is called again for each child part of `part`

#### `fuelMassFamily(part)`

This is part of the recursive part tree search for fuel. This function primarily recurses *up* the parts tree towards the root part, but for each new part is also calls `fuelMassChildren()` on the children of that new part. This ensures that we cover all parts.

If the input `part` is a decoupler or its ID is already in the `DV_PL` list (indicating that the part has already been considered), no further action is taken. Otherwise, there are three steps:
* the ID of the part (`part:UID`) is added to the `DV_PL` list of parts
* the fuel mass of the part (`fuelMass(part)`) is added to the `DV_FM` fuel mass tracker
* the `fuelMassFamily()` function is called again for the parent part of `part`, if there is one (the root part has no parent)

#### `stageDV()`

Calculates the remaining delta-v of the current stage.

This starts by calling `setIspFuelRate()` to determine the appropriate Isp for all the engines that are currently active, and by clearing/resetting the global variables `DV_PL` and `DV_FM`.

Next, we determine the fuel mass of the stage. This is done in multiple ways: 
 - 1) by getting all the currently-lit engines and passing them one-by-one into `fuelMassFamily()`. This does a walk of the parts tree to find fuel and puts the result into `DV_FM`. This doesn't follow fuel lines, so it will underestimate the fuel available if some fuel is beyond a decoupler but accessible via a pipe.
 - 2) by passing `STAGE:RESOURCES` into `fuelMass()`. This relies on KSP to identify the stage correctly so it often returns `0` when there is fuel available.
 - 3) by passing `SHIP:RESOURCES` into `fuelMass()`. If there are still stages to go, this will return too much fuel for the stage, so this is only done as a last resort if both steps 1 and 2 return `0`.

Steps 1 and 2 are evaluated first and the larger value is taken to be the fuel mass to use. If both return `0` and the ship's available thrust is non-zero, step 3 is evaluated and used instead.

This lets us calculate the delta-v via the Tsiolkovsky rocket equation: `delta-v = g0 * Isp * ln(m0 / m1)`, where `m1 = m0 - fuel mass`.

#### `pDV()`

Prints out the current stage delta-v. This calls `stageDV()`

#### `burnTime(delta-v, stage_delta-v, limiter)`

Calculates the length of time required to burn the input amount of delta-v.

The default for `stage_delta-v` is calculated by calling `stageDV()` if a value has not been provided.

The default value for `limiter` is `1`. If provided, it should be a value greater than `0` (as `0` will cause a divide-by-zero error). It is used to calculate the burn time at a specific throttle setting (e.g. to calculate the burn time at 50% throttle, pass in a limiter value of `0.5`).

The function starts by calling `setIspFuelRate()` then `btCalc()` to get the predicted burn length, `bt`, assuming the current stage has enough fuel for the entire burn.

If the delta-v required is greater than the stage delta-v:

* We calculate the time the current stage would take to burn until empty, `bt1`, and the remaining delta-v (`delta-v - stage_delta-v`) is passed into `nextStageBT()` to calculate how long the next stage would take to burn, `bt2`. 

* If `nextStageBT()` cannot determine how long the next stage would take, we take the length of time that the current stage would have required, if it had enough fuel: `bt2 = bt - bt1`. As the current stage would be empty at this point, and the next stage would start off full, this is likely to underestimate the time required for `bt2`. As such, we multiply `bt2` by `2.5`.

* The total burn time is given by summing `bt1` and `bt2`, plus an extra half second for the staging event.

Geoff Banks / ElWanderer
