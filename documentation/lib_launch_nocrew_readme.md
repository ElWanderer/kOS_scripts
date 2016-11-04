## lib\_launch\_nocrew (no-abort launch library)

### Description

This library provides a single function for controlling a launch. Everything else is defined in the `lib_launch_common.ks` library.

The launch steps are very basic and do not support a launch abort. The alternative launch library `lib_launch_crew.ks` is larger, has more resilient logic and support for launch aborts.

### Requirements

 * `lib_launch_common.ks`

### Function reference

#### `doLaunch(exit_mode, apoapsis, azimuth, inclination, pitchover_altitude)`

All the input parameters (except `exit_mode`) are passed into `launchInit()` to set-up the variables that will be used to steer.

Then we have a run mode loop. Launch is achieved by setting the throttle to `1`, waiting `3` seconds then staging. During the main run mode (11) that follows, we run multiple commands once per tick, as well as checking the apoapsis:

* `launchSteerUpdate()` recalculates the pitch and heading:

  * Launch is vertical until the radar altitude is greater than the input `pitchover_altitude` (default is `250`m), after which the craft will follow a pitch program that flattens out the pitch angle to `0` at the default altitude of 90% of the atmosphere height (`63`km on Kerbin).

  * During ascent, the craft will steer to maintain the calculated bearing (which changes with latitude) to enter orbit with the input `inclination`.

* `launchStaging()` checks for thrust fluctuations that should trigger a staging event.

* Once the apoapsis is larger than the input `apoapsis`, the engines are cut, the steering is changed to follow surface prograde and the script jumps to the next run mode (12).

During run mode 12, the craft will coast until out of the atmosphere, when the apoapsis will no longer be changing due to atmospheric drag. Then a circularisation node will be plotted and executed. Following that burn, the launcher will be separated if any parts tagged `FINAL` are still on-board the craft. Once circularisation and separation is complete, the run mode will be set to the input `exit_mode`. This causes the function to exit, and means that control is passed back to whichever script called `doLaunch()`.

`launchFairing()` will jettison any fairings at the appropriate altitude (the default is 60% of the atmosphere height, `42`km on Kerbin). This occurs at the set altitude no matter what the run mode is.

If not specified, the default value for `azimuth` is `90` (degrees compass heading).

If not specified, the default value for `inclination` is the craft's current latitude.

If not specified, the default value for `pitchover_altitude` is `250`m.

Geoff Banks / ElWanderer
