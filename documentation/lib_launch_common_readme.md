## lib\_launch\_common (common launch library)

### Description

This library contains common functions used by the two launch libraries, `lib_launch_crew.ks` and `lib_launch_nocrew.ks`.

The functions provided by this library allow for:
* automatic staging when the thrust drops due to an engine flaming out. Note that this assumes rocket engines (whether liquid- or solid-fueled) rather than jet engines or any modded engines whose thrust curve changes during a burn. It's also possible that it will react oddly to separation motors if they remain on the active craft.
* automatic jettisoning of fairings and Launch Escape Systems (LES) once no longer necessary.
* following the right heading (which can change during ascent) to end up in the right inclination.
* avoiding sharp turns while low in the atmosphere.
* following a fixed, curved pitch program.
  * As the curve is fixed, there are combinations of Thrust-to-Weight Ratios (TWR) that are preferable. I would usually go for a TWR off the pad of 1.3-1.5, dropping to about 1 for the next stage. I've been experimenting with upper stages whose TWR is much lower than 1 as these seem to be quite accurate at getting into the target orbit, if you are prepared to wait longer!
  * There is an exception that allows an emergency pitch-up if a rocket is in danger of passing apoapsis too soon.
* staging off the launcher once in stable orbit

There are always improvements that can be made, some of which are listed under [Issue #46](https://github.com/ElWanderer/kOS_scripts/issues/46):
* the pitch curve could change based on the TWR of the craft, rather than being fixed.
* the launch trajectory could be improved to try to get into orbit on a single, continuous burn rather than the coast and circularise approach the launch libraries take.
* handling for RSS/RO vessels could be added, allowing much longer between staging events so that engines have time to spool up, so that separation motors are not counted towards the "has our max thrust dropped?" check and so that we hold on the launch clamps until our thrust has built-up enough.

### Requirements

 * `lib_burn.ks`
 * `lib_runmode.ks`

### Global variable reference

#### `LCH_MAX_THRUST`

The last known maximum vacuum thrust.

Initialised as `0`.

#### `LCH_ORBIT_VEL`

The orbital velocity we will need at apoapsis to enter a circular orbit.

Set by `launchInit()`.

Initialised as `0`.

#### `LCH_VEC`

The launch vector that the steering will try to steer to.

Initialised as `UP:VECTOR` (i.e. pointing straight up).

#### `LCH_I`

The inclination of the target orbit.

Set by `launchInit()`.

Initialised as `0`.

#### `LCH_AN`

Whether we need to steer Northwards (Ascending Node) or Southwards (Descending Node) to get into the target orbit.

Set by `launchInit()`.

Initialised as `TRUE` (= at ascending node, so travel Northwards).

#### `LCH_PITCH_ALT`

The radar altitude above which the launch steering will switch from pointing straight up to following a pitch program i.e. the altitude at which we will pitch-over.

Set by `launchInit()`.

Initialised as `250`.

#### `LCH_CURVE_ALT`

The pitch program follows a square-root-based curve that has a maximum altitude at which the target pitch is `0` (horizontal). This value indicates what the value of this maximum altitude is.

The default value is 90% of the atmosphere height (`63`km on Kerbin).

Originally, the default value was the same as the atmosphere height, but a slightly lower value is now used to steepen the turn on ascent a little.

Unlike most of the global variables in this library, this value could be changed by modifying the script if so desired.

#### `LCH_FAIRING_ALT`

The altitude at which any fairings will be deployed.

The default value is 60% of the atmosphere height (`42`km on Kerbin).

Unlike most of the global variables in this library, this value could be changed by modifying the script if so desired.

#### `LCH_HAS_LES`

Whether we have a Launch Escape System (LES) and the ability to use it, or not.

Initialised as `FALSE`.

#### `LCH_HAS_FAIRING`

Whether we have any deployable fairings or not.

Initialised as `FALSE`.

### Function reference

#### `killThrot()`

Kills the throttle, by setting both the kOS `THROTTLE` and the player-controlled `SHIP:CONTROL:PILOTMAINTHROTTLE` to `0`.

This is called a few times during launch, partly because KSP likes to reset the current throttle setting to `0.5` while you're on the launchpad (and does this each time you come out of timewarp on the pad).

#### `mThrust(new_value)`

This function has two modes:
* If `new_value` is not negative, `LCH_MAX_THRUST` is set to its value.
* If `new_value` is negative, the value of `LCH_MAX_THRUST` is not changed
In both cases, `LCH_MAX_THRUST` is returned.

If `new_value` is not specified, it is defaulted to `-1`.

Therefore `mThrust()` can be used to find out the value of `LCH_MAX_THRUST` and `mThrust({some_value})` would be used to set the value of `LCH_MAX_THRUST`.

#### `hasFairing()`

Returns the value of `LCH_HAS_FAIRING`.

#### `hasLES()`

Returns the value of `LCH_HAS_LES`.

#### `disableLES()`

Sets `LCH_HAS_LES` to `FALSE`. This is typically called when activating the LES, so that we won't try to activate it again.

#### `checkFairing()`

Sets `LCH_HAS_FAIRING` according to whether we have any deployable fairings.

`LCH_HAS_FAIRING` is set to `TRUE` if there are any parts with the module `ModuleProceduralFairing` that can be deployed. Otherwise it is set to `FALSE`.

#### `checkLES()`

Sets `LCH_HAS_LES` according to whether we have a Launch Escape System (LES) or not, and if we are actually able to activate it.

`LCH_HAS_LES` is set to `TRUE` if we have any parts named `LaunchEscapeSystem` and if `CAREER():CANDOACTIONS` returns `TRUE`. Otherwise it is set to `FALSE`.

The reliance on the ability to do actions (3rd level Vehicle Assembly Building or SpacePlane Hanger) comes about because activating the LES is an Action rather than an Event. We cannot activate the LES via staging as the normal staging sequence of a rocket will not fire the LES except when jettisoning it.

#### `launchInit(apoapsis, azimuth, inclination, pitchover_alt)`

This function is called once when initiating a launch. It initialises quite a few launch settings:

* `LCH_ORBIT_VEL` is set to the orbital velcoity need for a circular orbit at an altitude matching the input `apoapsis`.
* `LCH_I` is set to the input `inclination`
* `LCH_AN` is set to `TRUE` or `FALSE` depend on whether the input `azimuth` is a Northwards or Southwards compass bearing. Bearings of `90` and `270` are treated as Northwards if the active vessel's latitude is negative (below the Equator) and Southwards otherwise.
* `LCH_PITCH_ALT` is set to the input `pitchover_alt`
* `checkFairing()` and `checkLES()` are called to set `LCH_HAS_FAIRING` and `LCH_HAS_LES` appropriately
* the maximum thrust is initialised as being `0` by calling `mThrust(0)`

If the run mode has not been initialised yet (i.e. it is less than `0`), a HUD Message is displayed that we are about to laucnh, and the run mode set to `1` by calling `runMode(1)`.

#### `launchStaging()`

This function handles staging during ascent. It is expected to be called repeatedly i.e. once per physics tick during launch.

The function has two modes:
* If the maximum thrust is currently `0`, or lower than the previous maximum thrust, we need to stage:
  * If the next stage is ready and it has been at least `0.5` seconds since the last staging event, we set the previous maximum thrust to `0` and stage (by calling the init library function `doStage()`).
  * Otherwise we do nothing.
* If the maximum thrust is currently greater than `0` and the previous maximum thrust is `0` and the time since the last staging event is greater than `0.1` seconds, we have recently staged and need to update the previous maximum thrust value:
  * We calculate and print out the current thrust-to-weight ratio (TWR). Note that this uses g0 rather than using the actual local gravity to calculate the weight
  * We set the previous maximum thrust to the current maximum thrust
  * If we have a fairing we call checkFairing() in case the fairing has been staged away.
  * If we have a Launch Escape System (LES), we call checkLES() in case the LES has been staged away.

By keeping track of the current maximum vacuum thrust and the last known maximum vacuum thrust, we can detect when any engine has flamed out, and thereby initiate a staging event. We will then stage until we have a non-zero maximum thrust. This ensures we only stage once if we only need to drop some spent boosters, but if the thrust drops to zero we will keep staging as necessary until we have activated at least one engine.

Note - this may have some interesting side-effects if separation motors are used to pull stages apart. I usually put the sepratrons on the stage being ejected, but I've not played RSS/RO yet, where I'm aware that separation motors are more useful on the new stage for stabilising the fuel prior to ignition.

#### `launchFairing()`

This function will deploy the fairing if the deployment conditions are met. It is expected to be called repeatedly i.e. once per physics tick during launch until the fairing has been deployed.

This function will not do anything until the `ALTITUDE` is above `LCH_FAIRING_ALT`. Then it will deploy any fairings that can be activated and set `LCH_HAS_FAIRING` to `FALSE`. The launch functions that call `launchFairing()` will only call it if `LCH_HAS_FAIRING` is `TRUE`.

#### `sepLauncher()`

This function is expected to be called once per launch, following circularisation. It exists to eject stages that were part of the launcher and so no longer required. This is done by staging rather than activating decouplers as my own designs include sepratrons to put the ejected stages back onto sub-orbital trajectories, thereby keeping Low Kerbin Orbit debris-free.

It only acts if there are any parts left on the craft that are tagged `LAUNCHER`. It will steer to prograde and stage until there are no longer any parts tagged `LAUNCHER`.

#### `launchCirc()`

This function is expected to be called once per launch once out of the atmosphere. It does a simple comparison of velocities to set a manoeuvre node at apoapsis that will result in a circular orbit. If a node already exists, it assumes we have rebooted, that the plotted node is correct and so executes the existing node. Otherwise, a new node is plotted then executed.

The velocity required to be in a circular orbit is given by `SQRT(BODY:MU/(BODY:RADIUS + APOAPSIS))`.

We predict what our velocity will be at apoapsis by `VELOCITYAT(SHIP,m_time):ORBIT:MAG`.

The difference between these values is the prograde delta-v required to circularise.

#### `launchBearing()`

This function determines the compass heading the craft should be following. It is a reworking of the `launchAzimuth()` function from `lib_launch_geo.ks` ([script](https://github.com/ElWanderer/kOS_scripts/blob/master/scripts/lib_launch_geo.ks)/[readme](https://github.com/ElWanderer/kOS_scripts/blob/master/documentation/lib_launch_geo_readme.md#launchazimuthplanet-azimuth-apoapsis)) that calculates the initial launch azimuth.

As our latitude changes, so does the azimuth required to enter the right orbit. By recalculating the azimuth in-flight and changing the desired bearing to follow it, we minimise the difference between our final inclination and the value we were targetting.

#### `launchPitch()`

Returns the pitch angle for ascent.

Until the radar altitude has gone above `LCH_PITCH_ALT` metres (the default is `250`m) the pitch is restricted to 90 degrees i.e. straight up. Note that this interferes with launchers that are mounted on the launch pad at an angle, as such rockets will try to steer up immediately on launch.

Once above the pitch-over altitude, the pitch follows a square-root-based pitch program that compares the craft's altitude to the `LCH_CURVE_ALT` (default is 90% of the atmosphere height, or `63`km on Kerbin): `90 * (1 - SQRT(ALTITUDE/LCH_CURVE_ALT))`

The pitch is limited to being no lower than `0` degrees and no higher than `90` degrees.

There is also an emergency pitch-up check. If the craft's `VERTICALSPEED` drops below `30`m/s, the minimum pitch angle will be `30-VERTICALSPEED` instead of `0`. This ensures that rockets with weak sustainer stages do not pass apoapsis and start coming back down during the ascent, unless their engines are *really* weak!

#### `launchMaxSteer()`

Returns the maximum angle between the current heading (surface velocity vector) and the desired launch vector (`LCH_VEC`).

This maximum angle is `15` degrees if the surface velocity magnitude is less than `99`m/s, to allow an initial pitch-over.
Thereafter, it is kept very low, to `5` degrees for the majority of the initial ascent.
Once above half the fairing deployment altitude (`LCH_FAIRING_ALT / 2`, or `21`km using the standard settings on Kerbin), the maximum angle raises back to `15` degrees again.
Once above the fairing deployment altitude (`LCH_FAIRING_ALT`, or `42`km using the standard settings on Kerbin), the maximum angle rises further, to `45` degrees. This allows fairly sharp steering if necessary, in case a pitch-up manoeuvre is required to maintain the ascent.

#### `launchSteerUpdate()`

This function updates the launch vector, `LCH_VEC`. It is expected to be called repeatedly i.e. once per physics tick during launch.

Initially, this did not have to do a lot as the bearing was fixed and the pitch would slowly alter with altitude. Changes to how the desired bearing and pitch are calculated have had knock-on effects on this function, as the desired vector may change more sharply than desired.

The logic is now:

* The function gets a desired vector from: `HEADING(launchBearing(),launchPitch()):VECTOR`.
* `launchMaxSteer()` is called to set a maximum angle between the launch vector and the current heading (surface velocity vector).
* If the angle between the current surface velocity vector and the desired vector is greater than the maximum angle, the desired vector is limited to that maximum angle. We do that by crossing the current and desired vectors to get a vector that is at 90 degrees to both, then use this as an axis to rotate the current velocity around: `SET new_v TO ANGLEAXIS(max_ang,VCRS(cur_v,new_v)) * cur_v.`
* `LCH_VEC` is set to the desired vector.

#### `steerLaunch()`

This function is expected to be called once during launch.

Locks the steering to the launch vector, by forming an anonymous function that returns `LCH_VEC` and passing this into `steerTo()`.

Geoff Banks / ElWanderer
