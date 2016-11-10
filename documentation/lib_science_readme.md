## lib\_science (science experiment library)

### Description

Functions for dealing with science parts - running science experiments, resetting experiments and transmitting science results.

There are three functions that are expected to be called from outside scripts: `doScience()`, `transmitScience()` and `resetScience()`.

### Requirements

* `lib_ant.ks`

### Global variable reference

#### `SCI_LIST`

This gets populated by a list of science experiment modules on running the library, so that we can cycle through them.

Note - we store modules rather than parts so that it is quicker to trigger the module's events.

#### `SCI_MIN_POW`

This value is used when determining whether we have enough power to transmit the results of a science experiment. It is s safety margin added on top of the power we calculate that the transmission will take.

The initial value is `10`ec.

#### `SCI_MIT_RATE`

This value is used when determining how long it will take to transmit science experiment results. This is used to space apart transmissions so that they occur one at a time.

The initial value is `3`MIT/s. This is based on the earliest transmitters available in career, which have a rate of `3.3`MIT/s.

#### `SCI_EC_PER_MIT`

This value is used when determining whether we have enough power to transmit the results of a science experiment, based on the size of the data to be transmitted.

The initial value is `6`ec/MIT. This is based on the earliest transmitters available in career.

### Function reference

#### `listScienceModules()`

This function populates `SCI_LIST` with science experiment modules.

#### `scienceData(module)`

This function sums the amount of data (in MITs) stored in a science experiment module.

For the input `module`, this loops through all the `DATA` items stored within it, adding its `DATAAMOUNT` to the total.

#### `powerReq(module)`

This function determines the power required to transmit the data stored in a science experiment module.

This calls `scienceData(module)` to get the amount of data in MITs, then multiplies the result by `SCI_EC_PER_MIT` to get the electric charge required for `module`'s data alone. The safety reserve, `SCI_MIN_POW`, is added to this and the total returned.

#### `timeReq(module)`

This function determines the time required to transmit the data stored in a science experiment module.

This calls `scienceData(module)` to get the amount of data in MITs, then divides the result by `SCI_MIT_RATE` to get the expected time in seconds required to transmit `module`'s data. This is returned without further alteration.

#### `powerOkay(module)`

This function determines whether the active vessel has enough electric charge to transmit the data stored in a science experiment module.

This calls `powerReq(module)` to get the electric charge required.

The function does not compare the required charge directly to `SHIP:ELECTRICCHARGE`. Instead, it takes two readings of the charge to predict the rate of change and multiplies that by how long the transmission is expected to take (given by `timeReq(module)`. That is added to the current level of charge.

Note - this prediction relies on changes to the value of `SHIP:ELECTRICCHARGE`. It does not (yet) account for situations where the vessel has a source of new charge (solar panels, RTG, etc.) but all the batteries are currently full. The main reason it exists is for the opposite situation, where something else is draining the power quickly and so transmitting would be risky.

Returns `TRUE` if the vessel has enough power, `FALSE` otherwise.

#### `resetMod(module)`

This function resets the science experiment in the given `module`. It will then wait until the experiment has no data and is considered undeployed. For parts with animations, this *may* halt processing until the animation has finished (though that depends on the KSP behaviour).

#### `doMod(module)`

This function triggers (a.k.a. deploys) the science experiment in the given `module`. It will then wait until the experiment has data. For parts with animations, this *may* halt processing until the animation has finished (though that depends on the KSP behaviour).

#### `txMod(module)`

This function transmits the data from the science experiment in the given `module`.

#### `doScience(one_use, overwrite)`

This function triggers the science experiments on the active vessel.

If `one_use` is set to `FALSE`, only those experiments that can be re-run are triggered i.e. one-shot experiments such as Goo Cannisters and the Science Junior will not be triggered. If `one_use` is set to `TRUE`, all experiments will be triggered if possible.

If `overwrite` is set to `FALSE`, experiments that have already been triggered are ignored. If `overwrite` is set to `TRUE`, experiments that have already been triggered will be reset (thus throwing away their data) then triggered.

If not specified the default value of `one_use` is `TRUE`.

If not specified the default value of `overwrite` is `FALSE`.

#### `transmitScience(one_use, wait_for_power, max_wait)`

This function transmits science from the science experiments on the active vessel. It will extend all extendable antennae on the active vessel prior to doing so. Note - it does not currently retract the antennae afterwards.

If `one_use` is set to `FALSE`, only those experiments that can be re-run have their data transmitted i.e. one-shot experiments such as Goo Cannisters and the Science Junior will be left alone. If `one_use` is set to `TRUE`, all experiments containing data will have that data transmitted if possible.

The power level is checked prior to transmitting each experiment's data. If there is not enough power for the transmission, the behaviour depends on the setting of `wait_for_power`. If `wait_for_power` is set to `FALSE`, the function will return `FALSE` immediately - no further experiments will be transmitted. If `wait_for_power` is set to `TRUE`, the function will loop until there is enough power. This loop is indefinite, but it can be broken if `max_wait` has been set to a positive number, once that number of seconds has elapsed since the function was first called. If the loop is broken due to `max_wait` being exceeded, the function will immediately return `FALSE` - no further experiments will be transmitted.

Prior to each transmission, the time when the transmission is expected to have completed is calculated based on `timeReq(module)` and stored under `TIMES["SCI_TX"]`. Following the call to `txMod(module)` to fire off the actual transmission, the function will then wait until the stored time is passed. This is because after calling the `TRANSMIT()` function inside `txMod(module)`, kOS continues executing code and there is no obvious way to query KSP as to the status of the transmission. 

The function returns `TRUE` if it did not encounter any problems.

If not specified the default value of `one_use` is `TRUE`.

If not specified the default value of `wait_for_power` is `TRUE`.

If not specified the default value of `max_wait` is `-1`.

#### `resetScience()`

This function resets all the science experiments on the active vessel. It loops through all the science experiment modules and calls `resetMod()` on those that can be reset.

Geoff Banks / ElWanderer
