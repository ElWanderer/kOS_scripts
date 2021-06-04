## lib\_launch\_nocrew (no-abort launch library)

### Description

This library provides a single function for controlling a launch. Everything else is defined in the `lib_launch_common.ks` library.

The launch steps are very basic and do not support a launch abort. The alternative launch library `lib_launch_crew.ks` is larger, has more resilient logic and support for launch aborts.

### Requirements

 * `lib_launch_common.ks`

### Function reference

#### `doLaunch(exit_mode, apoapsis, azimuth, inclination, pitchover_altitude)`

All the input parameters (except `exit_mode`) are passed into `launchInit()` to set-up the variables that will be used to steer.

Then we have a run mode loop. In turn, this calls the `lib_launch_common.ks` functions `launchLocks()`, `launchLiftOff()`, `launchFlight()` and `launchCoast()`.

`launchFairing()` will jettison any fairings at the appropriate altitude (the default is 60% of the atmosphere height, `42`km on Kerbin). This occurs at the set altitude no matter what the run mode is.

If not specified, the default value for `azimuth` is `90` (degrees compass heading).

If not specified, the default value for `inclination` is the craft's current latitude.

If not specified, the default value for `pitchover_altitude` is `250`m.

Geoff Banks / ElWanderer
