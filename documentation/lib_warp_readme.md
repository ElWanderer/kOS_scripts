## lib\_warp (time warp library)

### IMPORTANT - DEPRECATION

*This library will be deprecated as of v1.0.0 / kOS v1.0.1 (KSP v1.1.3).*

The single reason for creating this library in the first place was to be able to interrupt time warp, as it was not possible to kill `WARPTO()` except by the player hitting escape. Now that kOS has added a function that ties into KSP's kill warp functionality, this reason no longer exists. We can go back to using `WARPTO()`.

### Description

This library contains code used to control time warping.

The main function provided is `doWarp()`, which can be used as a straight replacement for `WARPTO()`. There is also an optional second parameter for providing much functionality than `WARPTO()`.

### Global variable reference

#### `WARP_MIN_ALTS`

A lexicon that stores the minimum rails warp altitude for each body. This was populated manually by reading the values from the KSP wiki, which may not be accurate.

`initWarpLex()` is called when the library is run, to raise each value up to the atmosphere height for that body if necessary.

#### `WARP_MAX_PHYSICS`

An integer that holds the maximum level of physics warp `doWarp()` can use. This should be a value in the range `0`-`3`. The default value is `3`.

#### `WARP_MAX_RAILS`

An integer that holds the maximum level of physics warp `doWarp()` can use. This should be a value in the range `0`-`7`. The default value is `7`.

#### `WARP_RAILS_BUFF`

A list of time intervals below which the rails warp factor is limited.

The default list is `LIST(3, 15, 30, 225, 675, 10000, 150000)`. These values were arrived at by multiplying the warp rate by `3, 3, 3, 4.5, 6.75, 10, 15` - from `50x` warp onwards, each multiplication factor is roughly `50%` higher than the previous factor. These values have been tested and although they result in a warp that is not quite as fast as the built-in KSP version, overshooting is avoided.

There are seven values, one each for warp factor from `0` to `6`. If the time left to warp is less than one of these values, the warp factor is limited to the index of the value (e.g. if there are `200s` to go, we are limited to `50x` rails warp). If the time left to warp is greater than the last value, the highest rails warp factor can be used.

### Function reference

#### `initWarpLex()`

This function goes through each body in the system and checks if each one:
* is listed in `WARP_MIN_ALTS`,
* has an atmosphere. 
If all conditions are met, the `WARP_MIN_ALTS` entry for this body is change to be whichever value is higher: the atmosphere height or the current value of the `WARP_MIN_ALTS` entry.

This is to avoid trying to trigger rails time warp while in the atmosphere, if the atmosphere height has changed since the wiki entries were written.

#### `warpTime()`

Returns how far in the future the time we're warping to is.

#### `setMaxWarp(max_physics, max_rail)`

This function sets `WARP_MAX_PHYSICS` and `WARP_MAX_RAILS` to the input parameters. The expected useage is to restrict physics warp for a craft that is too wobbly to run at `4x` warp.

If not specified, the default values for `max_physics` and `max_rail` are `3` and `7` respectively.

#### `pickWarpMode()`

This function returns a string that is either `PHYSICS` or `RAILS`, to indicate which warp type is appropriate (with rails warp being used in preference).

If the vessel is below the `WARP_MIN_ALTS` height for the current body, `RAILS` warp must be used unless the vessel is landed.

#### `pickWarp()`

This function returns the warp factor we want to be using. This takes into account the current warp type (i.e. rails versus physics, which is assumed to have been set by calling `pickWarpMode()`) and how long is left to warp. It does not know about the various altitudes around each body at which the maximum warp rates are limited, or when we are close to a sphere of influence transition.

For physics warp, the function returns `WARP_MAX_PHYSICS`.

For rails warp, the function steps through `WARP_RAILS_BUFF` until the number of seconds left to warp is less than the list value or we hit `WARP_MAX_RAILS`. This ensures that as we get closer to the time we are warping too, the warp rate will step down, and do so quickly enough that we don't overshoot.

#### `doWarp(universal_timestamp, stop_function)`

This function is used to warp forward to the input `universal_timestamp`, with an optional check that will stop time warp early.

The input parameter `stop_function` is expected to be a function delegate that returns `TRUE` or `FALSE` when called. `stop_function` will be called each tick during the time warp, with a value of `TRUE` indicating that time warp should be stopped. A value of `FALSE` indicates that the time warp should continue. 

An example of a useful `stop_function` is in the following code that warp to the next sphere of influence transition. It will exit out of time warp if the sphere of influence changes earlier than expected (which can be quite common when KSP orbits wobble or change as the game switches between 'live' and 'on-rails'):

    GLOBAL CURRENT_BODY IS BODY.

    FUNCTION bodyChange
    {
      PARAMETER cb.
      RETURN BODY <> cb.
    }

    LOCAL on_body_change IS bodyChange@:BIND(CURRENT_BODY).

    LOCAL warp_time IS TIME:SECONDS + ETA:TRANSITION.
    doWarp(warp_time, on_body_change).

Assuming that `stop_function` does not return `TRUE` and that the time we're warping to is still in the future, we do the following:
* call `pickWarpMode()` and compare the result to the current warp mode
  * if the values are different we set the warp factor to `0` and switch warp mode
  * if the values are the same, we call `pickWarp()` and compare the result to the current warp factor
    * if the values are different, we set the warp factor to the result of `pickWarp()`

Most of the time, this results in time warp ramping quickly to the maximum, then stepping down slowly as we approach our target time. Sometimes, there are oddities. In particular, when approaching a body KSP will limit the warp factor so the function will keep trying to change it back to a higher value. This will result in KSP displaying a warning in the main screen about the warp rate being limited.

If not specified, the value of stop_function is defaulted to the anonymous function `{ RETURN FALSE. }`. This will not apply any checking during the time warp.

Geoff Banks / ElWanderer
