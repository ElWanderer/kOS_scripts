## lib\_lander\_ascent (non-atmospheric take-off library)

### Description

A library for taking off from a non-atmospheric body.

This is, naturally, not too different from the launch scripts. However, the lack of an atmosphere means our pitch angle can be determined based on terrain rather than height in the atmosphere.

In common with the other lander scripts, this is somewhat incomplete. In particular, there is an optional staging event a few seconds into the ascent that is highly craft-specific (specifically, a Mun/Minmus lander probe I came up with that jettisons its legs). That should be more generalised. Also, the launch steering code alters the compass heading during ascent, thereby better targeting a set inclination, but this holds a constant bearing.

### Requirements

 * `lib_steer.ks`
 * `lib_burn.ks`
 * `lib_runmode.ks`
 * `lib_orbit.ks`
 * `lib_lander_common.ks`

### Global variable reference

#### `LND_LAZ`

Stores the launch azimuth (compass bearing to follow).

Initialised as `0`.

#### `LND_LAP`

Store the target apoapsis.

Initialised as `0`.

### Function reference

#### `initAscentValues()`

This calls `landerSetMinVSpeed(20)` to set the initial minimum vertical speed to `20`m/s upwards. It then calls the common lander set-up function, `initLanderValues()`.

#### `stopAscentValues()`

This is wrapper around the common lander function, `stopLanderValues()`. Currently it does nothing else.

#### `steerAscent()`

This calls `steerTo()`, passing in the anonymous function `{ RETURN HEADING(LND_LAZ,landerPitch()):VECTOR. }`. That calculates the launch vector based on the launch azimuth/compass bearing and the pitch as determined by the common lander function, `landerPitch()`.

#### `ascentCirc()`

[This is a straight copy of the `launchCirc()` function from `lib_launch_common.ks`.](https://github.com/ElWanderer/kOS_scripts/blob/master/documentation/lib_launch_common_readme.md#launchcirc). Defining it here is a duplication, but this one function doesn't seem large enough to warrant adding the overhead of an extra common library. There is the potential for correcting this in the future.

#### `doLanderAscent(launch_apoapsis, launch_azimuth, stages_on_launch, exit_mode)`

This is the main function provided by the library. It controls a launch from a non-atmospheric body, before setting the runmode to `exit_mode` once in orbit. The target orbit is circular, with an altitude of `launch_apoapsis`. Rather than specifying an inclination and longitude of the ascending node, the `launch_azimuth` (compass bearing) is taken as a parameter.

On being called for the first time, the function will steer upwards, wait three seconds then set the throttle to `1`. During those three seconds, hitting abort will pause the launch sequence.

After lift-off, there is an optional staging event. If `stages_on_launch` is greater than `0`, it will wait `5` seconds, stage and decrement `stages_on_launch`. This will repeat until `stages_on_launch` is `0`. This is somewhat inefficient as the lander will be thrusting straight up during this time, rather than pitching over towards the horizon. The wait is quite long so that anything staged off should be destroyed on impact with the terrain, rather than persisting as debris.

`1` second later than either lift-off or the last staging event, the steering will switch to `steerAscent()`. This will encourage the lander to pitch over towards the horizon, but maintain at least `20`m/s (upwards) vertical speed. Every second that follows, `findMinVSpeed(20,600,10)` is called to re-scan the terrain ahead and determine what minimum speed is applicable.

Finally, once the apoapsis is above the `launch_apoapsis`, the throttle will be cut and a circularisation node plotted, then executed. Note - the timewarp to this node may not work if the craft is still low over a large body, due to KSP's restrictions on warp modes.

Geoff Banks / ElWanderer
