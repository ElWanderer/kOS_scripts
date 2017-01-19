## lib\_launch\_crew (crewed launch library)

### Description

This library provides a single function for controlling a launch, plus some helper functions related to the use of a Launch Escape System (LES). Everything else is defined in the `lib_launch_common.ks` library.

The alternative launch library `lib_launch_crew.ks` is smaller but does not have the LES functions.

Note that for the LES to be used successfully, there are some requirements:
* Activating the LES automatically requires custom action groups to be available. In a career game, that typically means a level 3 Vehicle Assembly Building or SpacePlane Hanger. Alternatively, there is a game setting that enables action groups straight away.
* Detaching the crew capsule from the rest of the craft during an abort requires that the decoupler (or a child part underneath it) is labelled `FINAL`. 
  * Note - the crew capsule is often the root part and if the scripts go searching for child decouplers to activate, they're likely to detach the LES as well as the rest of the rocket, so tagging the capsule `FINAL` is likely to be counter-productive.
  * Note 2 - care must be taken if a heat shield has a jettison option that appears as a normal `decouple` event.
* The LES must still be attached at the time of the abort. If action groups are available, the LES is jettisoned above a certain altitude (the default is 62% of atmosphere height, `43.4`km on Kerbin).

### Requirements

 * `lib_launch_common.ks`
 * `lib_chutes.ks`
 * `lib_parts.ks`

### Global value reference

#### `LCH_LES_ALT`

The altitude at which the Launch Escape System (LES) will be jettisoned, if present.

The default value is 62% of the atmosphere height, or `43.4`km on Kerbin.

#### `LCH_CHUTE_ALT`

The altitude below which to consider triggering parachutes during a launch abort. This does not mean the parachutes will open at this altitude, just that we will not bother the run the parachute deployment code (which waits until the deployment would be safe) above a certain altitude.

The default value is 30% of the atmosphere height, or `21`km on Kerbin.

### Function reference

#### `fireLES()`

This function will loop through any/all parts named `LaunchEscapeSystem` and activate their engine via the part action menu. In a career game, this requires that custom action groups are available.

#### `jettisonLES()`

This function will loop through any/all parts named `LaunchEscapeSystem` and decouples them. It then calls `disableLES()` to indicate that the LES logic should not be called any further.

#### `launchLES()`

This function will jettison the LES if/when the jettison conditions are met. It is expected to be called repeatedly i.e. once per physics tick during launch until the LES has been jettisoned. This function should not be called during a launch abort!

This function will not do anything until the `ALTITUDE` is above `LCH_LES_ALT`. Then it will simultaneously fire and decouple the LES, by calling `fireLES()` and `jettisonLES()`.

#### `doLaunch(exit_mode, apoapsis, azimuth, inclination, pitchover_altitude)`

All the input parameters (except `exit_mode`) are passed into `launchInit()` to set-up the variables that will be used to steer.

Then we have a run mode loop. In turn, this calls the `lib_launch_common.ks` functions `launchLocks()`, `launchLiftOff()`, `launchFlight()` and `launchCoast()`.

`launchFairing()` will jettison any fairings at the appropriate altitude (the default is 60% of the atmosphere height, `42`km on Kerbin). This occurs at the set altitude no matter what the run mode is.

`launchLES()` will jettison any Launch Escape Systems present at the appropriate altitude (the default is 62% of the atmosphere height, `43.4`km on Kerbin - this is deliberately slightly higher than the fairing deployment altitude so that fairings deploy first), as long as the run mode is not part of the abort sequence.

If the player hits the `ABORT` key, launch switches to the abort run mode sequence. Please see the file description above for notes concerning the use of a Launch Escape System and part tagging. The abort sequence is:

* The throttle is killed.
* The words `LAUNCH ABORT!` will be printed on the screen in large, red letters.
* If the craft has a Launch Escape System (LES) present and it is possible to use it (requires custom action groups to be available), the LES is fired. To assist the LES in pulling the capsule away and to the side, the steering is disengaged.
* If the craft does not have an LES, the steering is set to surface prograde.
* Any parts labelled `FINAL` (requires custom action groups to be available) are decoupled from the craft. In my craft, the decoupler immediately below the capsule's heat shield is labelled this way. If no parts are labelled, the script does not know how to detach the capsule from the rest of the rocket and the player will have to activate the parts manually.
* `6` seconds after the abort, the LES is jettisoned if present.
* `7` seconds after the abort, the craft steers to surface retrograde.
* `13` seconds after the abort, the script will disengage the steering if below `LCH_CHUTE_ALT`. If above `LCH_CHUTE_ALT`, the script will wait until the altitude drops before continuing.
* Once below `LCH_CHUTE_ALT`, the parachutes will open automatically once safe to do so.
* The kOS CPU will power down on touch down to stop it from trying to run any post-launch code.

If not specified, the default value for `azimuth` is `90` (degrees compass heading).

If not specified, the default value for `inclination` is the craft's current latitude.

If not specified, the default value for `pitchover_altitude` is `250`m.

Geoff Banks / ElWanderer
