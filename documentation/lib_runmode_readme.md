## lib_runmode

### Description

This is a core library, containing functions for keeping track of the current run and abort modes.
* The run mode is the mode we are currently in.
* The abort mode is the abort mode we will switch to if the player hits the `ABORT` button.

This library makes use of the `store()`, `append()` and `resume()` init library functions to store and recover the mode values. This ensures that the run and abort modes will survive a reboot.

### Assigned run modes

Active run modes are greater than `0`. Certain ranges of values are used by certain scripts / functions, which are listed below:

    -1       uninitialised / not in use
    0        no mode set
    1-49     launch (including various abort stages)
    51-98    re-entry
    99       *end*
    101-149  transfer
    201-249  lander descent
    301-349  lander ascent
    401-449  rendezvous
    801-999  mission steps

The "mission steps" are run modes expected to be used by boot scripts for actions that aren't launch, re-entry, transfer etc.

### Global variable reference

#### `RM_FN`

The filename used for the runmode-specific `store()`, `append()` and `resume()` calls. By default this is set to `rm.ks`. This could be changed if desired.

#### `RM_RM`

The run mode we are currently in. This should not be altered directly. This is initialised as `-1`.

#### `RM_AM`

The abort mode we would switch to if the player hits `ABORT`. This should not be altered directly. This is initialised as `-1`.

#### `modeTime()`

A function delegate based on `difftime()`

Returns the time since `setTime("RM")` was last called. That occurs on each change of run mode and when the library is first run following a boot.

### Trigger reference

#### `ON ABORT`

On hitting the `ABORT` button, the run mode will switch to the abort mode, if one has been set i.e. if it has a value greater than `0`. Otherwise nothing will happen.

If the mode is changed as a result of this, the abort mode will be reset to be `0`.

To keep processing light, the printouts for this trigger are limited and done without adding the Mission Elapsed Time timestamp.

### Function reference

#### `pMode()`

Prints out the current run mode and (if it is greater than `0`) abort mode.

#### `logModes()`

This function uses the init library functions `store()` and `append()` to store a set of commands that will restore the run and abort modes to their previous states when the library is run i.e. following a reboot.

#### `runMode(new_run_mode, new_abort_mode, print_out)`

This function has two uses:

* If `new_run_mode` is not negative, the function will:
  * update the run mode with the value of `new_run_mode`
  * update the abort mode with the value of `new_abort_mode`, as long as this is not negative.
  * update the mode timer by calling `setTime("RM")`.
  * print out the new modes, as long as print_out is `TRUE`.

* If `new_run_mode` is negative, the function returns the current run mode, i.e. the existing value of `RM_RM`.

If not specified, `new_run_mode` is set to `-1`, so that the function returns the current run mode value rather than changing it.

If not specified, `new_abort_mode` is set to `-1`, so that the abort mode is not changed.

If not specified, print_out is set to `TRUE`.

#### `abortMode(new_mode)`

This function has two uses:

* If `new_mode` is not negative, it updates the abort runmode `RM_AM` to the input `new_mode`, calls `logModes()` to store the value for recovery, then returns the new value of `RM_AM` (which should match the input).

* If `new_mode` is negative, the function returns the current abort mode, i.e. the existing value of `RM_AM`.

If not specified, `new_mode` is set to `-1`, so that the function returns the current abort mode value rather than changing it.

Geoff Banks / ElWanderer
