## lib\_reentry (re-entry library)

### Description

This library contains assorted functions related to re-entry, both for plotting a burn to return from Low Kerbin Orbit and the step-by-step process of transitioning from space through the atmosphere to the ground.

Parts of this library are much larger than they need to be, as they add a lot of printing of information. This has the purpose of collecting data on re-entries to allow accurate returns to be plotted from a wider range of orbits than the standard (for my scripts) `85`km by `85`km Low Kerbin Orbit.

### Requirements

* `lib_chutes.ks`
* `lib_parts.ks`
* `lib_runmode.ks`
* `lib_node.ks`
* `lib_steer.ks`
* `lib_orbit.ks`

### Function reference

#### `pReentry()`

This function calculates and prints out a set of orbit details and longitudes, for the purposes of working out how close to the periapsis we land for a given orbit.

This determines the longitude of the periapsis as if there were no atmosphere. Depending on the re-entry profile, we may end up landing several degrees short of this longitude (e.g. when coming down from Low Kerbin Orbit) or several degrees long (e.g. when returning from the Mun).

#### `deorbitNode()`

This function plots a manoeuvre node that will cause a typical, capsule-based spacecraft to re-enter and land close to the Kerbal Space Center (KSC). This currently assumes that the orbit the craft is in currently is the standard, prograde `85`km by `85`km Low Kerbin Orbit.

The node is plotted for when the craft's orbit path is above a longitude of `170` degrees, and reduces the periapsis on the other side of the planet to `29`km. These values were originally arrived at by trial-and-error following an educated guess, and have been adjusted since to account for changes to KSP's atmospheric model. Different craft designs and changes to the atmosphere may effect how accurate the landing is. The rough aim point is in the sea to the East of the KSC.

To do this we calculate the difference between the craft's current longitude and a longitude of `150` degrees. Then we determine the rate of change of longitude, given by `(360/OBT:PERIOD) - (360/BODY:ROTATIONPERIOD)`, assuming a prograde, equatorial orbit. Knowing the longitude difference and the rate of change, we can calculate when to place the node.

#### `firstTAAtRadius(orbit, radius)`

This function and the associated `secondTAAtRadius()` function used to live in the `lib_orbit.ks` library, but they were only used for re-entry, so they were moved here.

The function finds the true anomaly in the first half of the orbit (ascending between periapsis and apoapsis) when the orbital radius is equal to the input `radius`.

This is done by calling `calcTa()` - it is effectively a wrapper around the function with some added checks on the eccentricity of the input `orbit` and the input `radius`. 

#### `secondTAAtRadius(orbit, radius)`

This function and the associated `firstTAAtRadius()` function used to live in the `lib_orbit.ks` library, but they were only used for re-entry, so they were moved here.

The function finds the true anomaly in the second half of the orbit (descending between apoapsis and periapsis) when the orbital radius is equal to the input `radius`.

This is done by calling `firstTAAtRadius()` and subtracting the result from `360` degrees.

#### `secondsToAlt(craft, universal_timestamp, target_altitude, ascending)`

This function returns the number of seconds after `universal_timestamp` that `craft` will next reach `target_altitude` whilst either ascending or descending according to the input value of `ascending`.

This is used by the main re-entry function to find out how long it will take to reach certain heights (e.g. when a craft will descend to the height of the top of the atmosphere) so that time warp can be engaged to jump forward to that point.

The `target_altitude` must be specified in metres. Note that it is an altitude above sea-level, not an orbital radius.

The value of `ascending` should be `TRUE` to find the time the craft will next ascend to the given altitude, or `FALSE` to find the time it will next descent to the given altitude. Typically, for re-entry we are only interested in descents, but this distinction is made for cases where we have risen back out of the atmosphere and want to find out when we will next descend back into it.

#### `reentryExtend()`

This function is only called if we skip back out of the atmosphere during re-entry. It extends the solar panels and antennae to provide power.

#### `reentryRetract()`

This function is only called prior to entering the atmosphere. It retracts the solar panels and antennae to prevent them from being damaged during descent.

#### `doReentry(stages, exit_mode)`

This function is for controlling a craft during the process of re-entry, descent and landing. 

Important notes:
* This has only been designed for and tested above Kerbin.
* It is designed for the typical combination of a command module with capsule, heat shield and parachutes, plus an optional service module with tanks and engines.
* It will stage just prior to reaching the atmosphere if the input `stages` value is non-zero or if any parts tagged `FINAL` are present on the craft. This is expected to be used to jettison a service module or anything else that would prevent the command module from safely reaching the ground.
* Landing is unguided, using parachutes.
* If any parachutes are accidentally armed prior to, or by, the staging event, they will be disarmed to prevent them from deploying too early (KSP v1.2 allows parachutes to be staged in such a way as they won't deploy until it is safe, which renders this protection unnecessary).
* It is meant to be called once your craft is in the sphere of influence of Kerbin and has a periapsis that is below the height of the atmosphere.
* It does not use any engines itself. It is expected that you have already plotted and executed a de-orbit burn or transferred back to Kerbin from another body with the periapsis below the top of the atmosphere.
* The descent through the atmosphere is done at maximum physics warp to save time. This should be safe for the vast majority of craft.

On being called, the function will calculate and print out four altitudes. These vary depending on the height of the atmosphere and the eccentricity of the orbit your craft is on. These correspond to events that will happen during descent. Prior to reaching the first altitude, the craft will orient towards the Sun for maximum solar panel coverge, then engage time warp.
* 1. Staging: the altitude below which the craft will orient to normal and stage `stages` times. This step is skipped if `stages` is set to `0`. For return from Low Kerbin Orbit (LKO), this is typically `85`km. For returns from Mun/Minmus, where the eccentricity of the orbit is almost `1`, the staging altitude is almost `220`km.
  * The orientation to normal is deliberate so that it does not have a large effect on the craft's periapsis. It is also felt to be the safest way to avoid colliding with the jettisoned stages on the way down!
  * following staging, the craft will disarm any parachutes that have been triggered prematurely and then engage time warp to the next altitude.
* 2. Atmospheric interface: the altitude below which the craft will steer to retrograde, close any open solar panels and retract any antennae. Typically this altitude is `71.5`km for LKO descents and almost `85km` for returns from Mun/Minmus.
* 2a. Inside the atmosphere: once below 99% of the atmosphere height, maximum physics time warp is engaged until either the craft goes back above the height of the atmosphere, or the radar altitude drops below `1`km.
* 3. Steering off: the altitude below which the craft will disengage the steering to save electricity, assuming that the craft should now be in a stable descent, guided by air-flow. For Kerbin, this altitude is `50`km.
* 4. Chutes on: the altitude below which the craft will start checking the parachutes each tick to see if they can be deployed. For Kerbin this altitude is `20`km. It is assumed that a craft reaching this altitude will definitely re-enter.

Should a craft leave the atmosphere prior to reaching the fourth altitude (chutes on), it will steer towards the Sun and open the solar panels (and extend any antennae) again. It will also recalculate the second altitude (atmospheric interface) as the eccentricity is likely to have reduced following a trip through the atmosphere and either warp to this altitude or steer retrograde if we're already below it and descending. This is to handle shallow trajectories that skip in and out of the atmosphere before committing to re-entry.

Following touchdown, the function will disengage steering if it is active, and change the run mode to `exit_mode`.

Geoff Banks / ElWanderer
