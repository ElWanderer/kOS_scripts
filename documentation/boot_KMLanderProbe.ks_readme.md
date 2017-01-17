# KMLanderProbe.ks

## Kerbin Moon Lander Probe boot script.

The purpose of this boot script is to launch an automated probe from Kerbin, land on the surface of Mun or Minmus, take science readings, then take-off and return to Kerbin, re-entering and landing under parachutes.

### Disk space requirement

95000 bytes (actual use is about 92k at the time of writing).

### Libraries used

* `lib_launch_geo.ks`
* `lib_launch_common.ks`
* `lib_launch_nocrew.ks`
* `lib_burn.ks`
* `lib_node.ks`
* `lib_dv.ks`
* `lib_steer.ks`
* `lib_runmode.ks`
* `lib_orbit.ks`
* `lib_orbit_change.ks`
* `lib_orbit_match.ks`
* `lib_orbit_phase.ks`
* `lib_parts.ks`
* `lib_ant.ks`
* `lib_chutes.ks`
* `lib_ca.ks`
* `lib_hoh.ks`
* `lib_reentry.ks`
* `lib_geo.ks`
* `lib_science.ks`
* `lib_skeep.ks`
* `lib_lander_geo.ks`
* `lib_lander_common.ks`
* `lib_lander_descent.ks`
* `lib_lander_ascent.ks`

### Script Parameters

The parameters of the mission can be specified by changing the global variables near the top of the file:

    // set these values ahead of launch
    GLOBAL SAT_NAME IS "Lander Test 1".
    GLOBAL CORE_HEIGHT IS 3.25. // metres

    GLOBAL LAND_BODY IS MUN.
    GLOBAL LAND_LAT IS 25.
    GLOBAL LAND_LNG IS 25.
    GLOBAL SAFETY_ALT IS 2000.

    GLOBAL PARK_ORBIT IS 60000.
    GLOBAL RETURN_ORBIT IS 60000.

#### `SAT_NAME`

On first boot, the ship will be renamed with this string.

#### `CORE_HEIGHT`

The height in metres that `ALT:RADAR` returns if the lander alone is sat on the ground with landing legs extended. This is used to account for the difference in radar altitude as measured from the root/controlling part and the distance between the landing legs and the ground. These can differ by several metres, which is very important during the final stages of a landing.

#### `LAND_LAT`

The target body to aim for. Should be `MINMUS` or `MUN`.

#### `LAND_LAT`

The target latitude to aim for when beginning a descent.

#### `LAND_LNG`

The target longitude to aim for when beginning a descent.

#### `SAFETY_ALT`

The altitude above terrain (in metres) that the periapsis will be placed when beginning a descent. Higher values are safer, but less efficient in terms of fuel usage.

#### `PARK_ORBIT`

The periapsis (in metres) to aim for during transfer to the target body.

#### `RETURN_ORBIT`

The apoapsis (in metres) to aim for during ascent from the target body.

### Script Steps

#### Init

All libraries are loaded onto the local hard drive(s).

The craft is renamed `SAT_NAME` and then logging enabled. Logging is not enabled earlier so that the log file name will be based around the new name rather than the old name.

The script will calculate when the orbit of the target body will pass over the launch site and the initial azimuth (compass bearing) that the craft should follow.

The Mun's equatorial orbit means that a launch can be initiated immediately (with a bearing of `90` degrees), but for Minmus there will be a wait of up to three hours before launch (with a bearing of `83.5` or `96.5` degrees). Launch clamps are recommended to maintain power to the craft if going to Minmus!

#### Launch

Launch is to a standard `85`km by `85`km Low Kerbin Orbit, with the inclination matching (as near as possible) that of the destination body.

#### Match orbit inclination

The script will plot and execute a burn to reduce the relative inclination between the current orbit and the target body to zero. If the launch azimuth and time were calculated correctly, this should be a very small burn. Matching inclination precisely may not be necessary, but during early testing it made the next step much easier.

#### Transfer

The script will calculate a Hohmann transfer to the target body. Chances are that when plotted as a manoeuvre node, this will not actually reach the target, but the node improvement code will take over and adjust the node until the predicted periapsis matches the target apoapsis as best as possible.

This node will then be executed, and followed up (if necessary) with correction burns until the craft's trajectory reaches the target body, with a periapsis within a reasonable distance of the target apoapsis. What is considered 'reasonable' varies depending on whether the target apoapsis is close to the surface or not.

The script will then time warp to the sphere of influence transition with the target body, with the aim of passing through the transition at 50x warp.

Once in the sphere of influence of the target body, further correction burns can be plotted and executed if they improve the final orbit towards the target parameters. Finally, a node will be plotted at the periapsis and executed to insert into orbit.

Note - the target inclination is taken into account during the node improvement process that is run on each manoeuvre node. Recent changes have improved the node improvement process, but there is still no guarantee that it will get close to the target value. The final inclination at the target is hard to adjust unless close to the plane of the equator of the body (which may not happen until close to the periapsis when trying to get to Minmus). As such, it's best to assume that the craft will need to perform an inclination burn from an equatorial orbit to the target incilnation and budget delta-v accordingly (worst cases are about 700m/s for a 90 degree change around the Mun, or 150m/s if around Minmus).

#### Match parking orbit inclination and shape

The script will plot and execute a burn to reduce the relative inclination between the current orbit and the initial target orbit to zero.

The script will then plot and execute burns to alter the periapsis and apoapsis so that the orbit is circular.

#### Landing preparation

The script is preloaded with the minimum delta-v requirements for landing and re-orbiting `MUN` and `MINMUS`. If the current stage does not have enough delta-v, the assumption is that we need to ditch our transfer stage. The craft will steer to prograde and stage until the current stage has enough delta-v.

Note - this step is particularly vulnerable to some of the changes in KSP v1.2, but this works perfectly in KSP v1.1.

#### Landing

The script will attempt to land near the target co-ordinates as defined in the boot script. This is done by setting up a phasing orbit so that the target will pass underneath, lowering the periapsis until it is `SAFETY_ALT` above the target point then burning at the periapsis to kill horizontal velocity then descend to a touchdown.

#### Landed

Once on the ground (or splashed down) the script will take a set of science readings and transmit the results from any science experiments that can be re-run. It will then take another set of readings. This should mean that every science experiment has a result; these will be returned to Kerbin for maximum science output.

The script will then evaluate whether it is safe to take-off. The requirement is that the `ELECTRICCHARGE` must be higher than `50` units. If the power is lower than that, the script will time warp an hour into the future and try again.

#### Launch

Once ready, the script will take-off automatically. Launch is to a circular `RETURN_ORBIT`m by `RETURN_ORBIT`m orbit.

The script will fly due East; it targets the lowest possible inclination to make return easier.

#### Return transfer

Once back in orbit, the script will calculate a Hohmann transfer back to Kerbin, targetting a periapsis of `30`km. The node improvement code will take over and adjust the node so that the periapsis is as close as possible to this value.

This node will then be executed, and followed up (if necessary) with correction burns until the craft's trajectory has a periapsis that is close to the target.

The script will then time warp to the sphere of influence transition back to Kerbin, with the aim of passing through the transition at 50x warp.

Once in the sphere of influence of the target body, further correction burns can be plotted and executed to try to get the periapsis as accurate as possible.

Once this has been achieved, the script will time warp until the craft is close to re-entry.

#### Re-entry and landing

The script is programmed to perform one staging action following the re-entry burn, to detach the service module (i.e. the fuel tank and engine). If any parts are tagged `FINAL`, further staging actions will take place until these have been detached. The craft will hold retrograde during initial re-entry, then disengage steering to conserve battery power. It is assumed that the re-entry craft will be aerodynamically stable and maintain a retrograde orientation naturally. The parachutes will be triggered once safe.

Note - with the changes expected in v1.2 (such as the changes to the atmosphere and the ability to stage parachutes with an automatic delay in opening them until they are safe) some of the re-entry procedure may want/need changing. 

#### Failure cases

If the script gets stuck, it may revert to an error state. Hitting `ABORT` will cause it to retry the last step that failed.

Geoff Banks / ElWanderer
