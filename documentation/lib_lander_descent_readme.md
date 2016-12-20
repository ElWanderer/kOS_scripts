## lib\_lander\_descent (non-atmospheric landing library)

### Description

A library for landing on a non-atmospheric body.

In common with the other lander scripts, this is somewhat incomplete, though it is better than the ascent library. Landings are aimed at a set of co-ordinates, but no effort is made to perform a precision landing. There isn't any slope detection, so there's no guarantee that a lander won't fall over on touchdown. Lastly, though efforts are made to avoid flying into mountains, they're not perfect. All this means that the library is suitable for probes, but not crewed missions.

The landing code makes use of two different techniques:

* It begins with a modified constant altitude burn to kill the horizontal velocity. A traditional constant altitude burn involves controlling the pitch so that the vertical speed remains zero. The modification here is that the altitude is allowed to drop (though there is a maximum descent rate), as long as this does not endanger the craft. This usually avoids the major drawback to a constant altitude burn: coming to a stop several kilometres above the terrain, which is inefficient.

* Once the horizontal velocity is negligible, it switches to a suicide burn. This calculates the 'stopping distance' based on the current velocity and available acceleration, and begins the burn just before this distance grows larger than the radar altitude. Note - engines that are offset from the line of facing will mean that the calculated value of acceleration is larger than the reality, which can mean the suicide burn is begun too late.

### Requirements

 * `lib_steer.ks`
 * `lib_burn.ks`
 * `lib_runmode.ks`
 * `lib_orbit.ks`
 * `lib_geo.ks`
 * `lib_lander_common.ks`
 * `lib_lander_geo.ks`

### Global variable reference

#### `LND_THRUST_ACC`

This is used to store the current acceleration available due to engine thrust. It is locked to `SHIP:AVAILABLETHRUST / MASS` by `initDescentValues()`.

Note - engines that are offset from the line of facing will mean that the calculated value differs from reality.

Initialised as `0`.

#### `LND_RADAR_ADJUST`

Stores the offset to apply to the radar altitude. The radar altitude is determined based on the position of either the root part or the control-from part, not from the bottom of the landing legs. During final set-down this difference, which can be several metres, is quite important. 

This is set to an appropriate value by `initDescentValues()`, though in turn that requires a suitable value to be passed in as a parameter to `doLanding()`.

Initialised as `0`.

### Function reference

#### `initDescentValues(radar_adjust)`

This calls `landerSetMinVSpeed(0)` to set the initial minimum vertical speed to `0`m/s. It sets `LND_RADAR_ADJUST` to the input `radar_adjust`, and locks `LND_THRUST_ACC` to `SHIP:AVAILABLETHRUST / MASS`.

It then calls the common lander set-up function, `initLanderValues()`.

#### `stopDescentValues()`

This unlocks `LND_THRUST_ACC` and `THROTTLE`. It then calls the common lander function, `stopLanderValues()`.

#### `adjustedAltitude()`

This returns the adjusted radar altitude: `ALT:RADAR - LND_RADAR_ADJUST`. See the description of the `LND_RADAR_ADJUST` global variable for why this is done.

#### `cycleLandingGear()`

KSP usually starts craft with landing legs up, but the `GEAR` is `ON`. To get to a point where the legs are down, we have to call `GEAR OFF`, wait, then `GEAR ON`. This function follows those steps.

Note - a future version of this may make use of the kOS in-built `LEGS` action group.

#### `findHighestPointNear(latitude, longitude)`

This function does a very basic sampling of geographic points in the vicinity of the input `latitude` and `longitude`, then returns the highest `TERRAINHEIGHT` found.

This is to give a rough idea of how low we can make our landing approach, but the usual caveats about sampling apply - it is possible for the values we check to be unrepresentative.

The function checks up to `0.1` degrees away from the input `latitude`, and a similar distance from the input `longitude`. No checking is currently made to ensure that we don't call a value outside of valid latitude and longitude ranges. This is only really an issue if trying to land at either pole.

#### `addNodeLowerPeriapsisOverSpot(latitude, longitude, safety_factor, max_distance, days_limit)`

This function finds when the craft will next pass within `max_distance` metres of the input `latitude` and `longitude` and adds a manoeuvre node on the opposite side of the orbit to bring the periapsis down to a suitable height.

This uses the `lib_geo.ks` functions to calculate when the next near-pass occurs. It is recommended to run through the `lib_lander_geo.ks` function `nodeGeoPhasingOrbit()` first, to set-up a phasing orbit that should guarantee a close pass. Otherwise, the selected spot may not be flown over within `days_limit`, in which case no node is added.

The periapsis height chosen is based on the highest nearby terrain to the target spot (as returned by `findHighestPointNear()`) plus the `safety_factor` (entered in metres).

Note - by changing the size of the orbit, the orbital period will be changed, which in turn means that even if the node is burned perfectly, the geographic location under the periapsis when the ship arrives will be slightly different to that targetted.

The function returns `TRUE` if a node was successfully added, `FALSE` otherwise.

#### `checkPeriapsis(latitude, longitude, safety_factor)`

This function is expected to be used following the execution of a manoeuvre node added by `addNodeLowerPeriapsisOverSpot()`. As burns are never totally accurate, there is the possibility that the new periapsis will be dangerously low. If this is the case, the craft is steered to prograde and the throttle run at `10`% until the periapsis is suitably high.

The minimum periapsis allowed is based on the highest nearby terrain to the target spot (as returned by `findHighestPointNear()`) plus the `safety_factor` (entered in metres).

#### `warpToPeriapsis(safety_factor)`

This function engages time warp to a point `30` seconds before periapsis. 

There are two things to consider here:
* Below set heights for each body, rails time warping is disabled. Unless the periapsis is particularly high, this is likely to cause the time warp to end early. Where this happens, the `doWarp()` will continue to wait until either the target time is reached or the break-out condition is met.
* The warp monitors the radar altitude. If this drops below half the input `safety_factor` (in metres), the function will kill time warp and return early.

#### `constantAltitudeVec()`

This returns a vector to which the craft should steer to perform a modified constant altitude burn. The modification is that the altitude is allowed to change, as long as the rate of descent does not rise above a set speed and takes into account terrain in the flightpath.

This is a single expression, but it is quite complicated:

    RETURN ANGLEAXIS(landerPitch(),VCRS(VELOCITY:SURFACE,BODY:POSITION)) 
           * VXCL(UP:VECTOR,-VELOCITY:SURFACE).

Breaking this apart, we are performing a rotation of a vector. 

The vector is given by `VXCL(UP:VECTOR,-VELOCITY:SURFACE)` - this is the surface retrograde vector, with all the vertical component removed. Facing in this direction will point in the same compass bearing as retrograde, but aligned with the horizon.

The rotation is given by `ANGLEAXIS(landerPitch(),VCRS(VELOCITY:SURFACE,BODY:POSITION))` - this is a rotation of `landerPitch()` degrees around an axis defined by the vector cross of the surface velocity and body position vectors. The vector cross returns a vector that is perpendicular to both inputs i.e. it is at `90` degrees to the prograde vector and at `90` degrees to the vector from the craft to the centre of the body. This means that when used as an axis, the nose of the craft can be raised or lowered, without changing the compass bearing that the craft is following.

`landerPitch()` is defined in `lib_lander_common.ks`. It will return a suitable angle to control the rate of descent (or even ascent, if the lander needs to climb to avoid terrain).

#### `doConstantAltitudeBurn(safety_factor)`

This function has two halves. Firstly, it waits until a burn is required. Secondly, it burns at full throttle until the (horizontal) `GROUNDSPEED` is below a threshold.

Under ideal circumstances, the burn is held off until within a few seconds of the periapsis. However, the terrain ahead is scanned every second and the burn will begin early if the vertical speed is determined to be below that required to avoid terrain.

Once the throttle has been engaged, the terrain ahead is scanned every second to set the allowed vertical speed, which is used by `landerPitch()`. If there are no terrain dangers, the drop rate is allowed as high as `50`m/s. The burn ends (and the throttle is set to `0`) once the `GROUNDSPEED` drops below `4`m/s.

#### `stepTerrainImpact(start_time, look_ahead, step)`

This function calculates the altitude at which the active vessel's current flightpath will intersect the terrain. It is recursive and will run up to three times at higher resolutions.

It steps forwards `look_ahead` seconds from `start_time` at intervals of `step`. For each timestamp, the predicted altitude above sea level is calculated based on `POSITIONAT()`, and compared to the terrain height, as predicted by `terrainAltAtTime()`. Once the predicted altitude is less than the terrain height (plus a `5`m safety factor), the function returns either the predicted altitude or the result of calling itself with a smaller value of `step`.

The function will return `0` if it could not successfully calculate an impact.

#### `calculateImpact()`

This is a wrapper function - it simply calls `stepTerrainImpact(TIME:SECONDS,300,10)` and returns the result.

#### `suicideBurnThrot(impact_altitude, surface_g)`

This function is expected to be called every tick during the suicide burn. It returns an appropriate throttle value, handling both the initial decision of when to start burning (i.e. when to jump the throttle from `0` to `1`) and what value to hold the throttle at to ensure we do not zero out our vertical velocity too high up. This is a concern because most of the calculations assume constant acceleration, but the craft's acceleration will rise as fuel is burnt.

The function uses the concept of a 'stopping distance'. That is, if we are travelling at a velocity `v` in one direction and apply an acceleration `a` in the opposite direction until our velocity is `0`, how far would we travel? This can be calculated by rearranging the equations of motions (a.k.a. stuva, suvat and other variations).

    // s = ut + 0.5at^2 (distance as a function of initial velocity, acceleration and time)
    // a is deceleration so we should subtract 0.5at^2 instead of adding it
    // u is our current surface velocity (assuming no major horizontal component)
    // t = u / a (time taken to stop assuming constant deceleration)
    // s = (u^2 / a) - (0.5u^2 / a)
    // s = 0.5u^2 / a
    // s = u^2 / 2a

As such, our stopping distance is given by: `SHIP:VELOCITY:SURFACE:SQRMAGNITUDE / (2 * max_acc)`, where `max_acc` is the acceleration due to running the engines at full throttle, less the surface gravity: `LND_THRUST_ACC - surface_g`.

To avoid a burn that is fractionally too-late due to the nature of sampling every physics tick, an extra safety margin is added to the predicted stopping distance: `-SHIP:VERTICALSPEED / 10` (it is negated because `VERTICALSPEED` is measured upwards and we are going downwards).

As well as calculating the maximum stopping distance, we predicted how far below us the terrain is. This takes the minimum value of the current radar altitude and the predicted `impact_altitude` that was passed in, then subtracts the `LND_RADAR_ADJUST`. Two values are checked in case the terrain immediately below the craft is unrepresentative of where the craft will end up, either due to a slight horizontal component to the velocity or the rotation of the planet. Assuming the horizontal velocity was not perfectly zeroed-out, the actual touchdown spot is likely to be somewhere in between the two predictions.

If the maximum stopping distance (including the safety factor) is greater than the predicted distance to terrain, the throttle is set to `1`. Typically this should only happen once, to initiate the burn, but it's possible for it to happen again should higher terrain appear below the craft.

Once a burn is underway (the throttle is non-zero), we calculate a second stopping distance, that based on acceleration due to the current (rather than maximum) throttle setting. If this current stopping distance is less than the distance to terrain, the throttle is stepped up `5`%. Otherwise the throttle is stepped down `5`%. This can result in the throttle wobbling back and forth, but it should not veer wildly.

Note - we pass in `surface_g` rather than the current acceleration due to gravity. These will typically be so close as not to have any effect during a landing, but by chosing the surface value (which will always be the higher of the two unless landing below sea-level) we err on the side of caution and underestimate our stopping distance ever so slightly.

#### `doSuicideBurn()`

This function runs until the height above terrain is below `25`m (at which point it is expected to run `doSetDown()` instead. It calls `suicideBurnThrot()` every physics tick. Every second, it calls `calculateImpact()` to re-evaluate the predicted height of the terrain at impact.

#### `doSetDown()`

This function handles the final set-down. It is expected to be called once a craft is several metres above the terrain, descending vertically. Unlike `suicideBurnThrot()`, the throttle setting is calculated to provide a specific rate of descent. This is `5`m/s at first, dropping to `2`m/s once within `12` metres of the surface. Once the desired speed drops to `2`m/s, the steering is pointed straight upwards. Any horizontal components should have been zeroed-out by this point.

The throttle is determined by comparing the current downwards vertical speed to the desired descent rate (`aim_speed`), and working out what acceleration would be required to change to the desired speed in a second. If the speed precisely matches that desired, the acceleration due to thrust will be tuned to match the current acceleration due to gravity.

    LOCAL desired_acc IS -SHIP:VERTICALSPEED - aim_speed.
    LOCAL desired_throt IS (desired_acc + gravAcc()) / LND_THRUST_ACC.
    // make sure the throttle is not set outside of the range 0-1:
    SET LND_THROTTLE TO MIN(1,MAX(0,desired_throt)).

Whereas `suicideBurnThrot()` adds an element of realism by controlling the throttle in `5`% increments, this allows the throttle to be set with as much precision as kOS/KSP will allow.

Once within `1` metre of the ground, the throttle is cut and we wait for our status to indicate that we have `LANDED` or `SPLASHED`. Then the steering is damped.

To avoid damaging solar panels, they are retracted when this function is first called. Following touchdown, there is a `10` second wait then the panels are extended again.

#### `doLanding(latitude, longitude, radar_adjust, safety_factor, max_distance, days_limit, exit_mode)`

This is the main function to control a landing from orbit to touchdown.

`latitude`/`longitude` - the script will use this geographic location as an aiming point, but no attempt is made to perform a precision landing. In hilly terrain, the landing may end up taking place short of the target spot.

`radar_adjust` - pass in the distance in metres between the root/control part and the bottom of the landing legs. The best way to find the value to use is to put just the lander on the launch pad, open a kOS terminal and enter `PRINT ROUND(ALT:RADAR,2).` The radar altitude is determined based on the position of either the root part or the control-from part, not from the bottom of the landing legs. During final set-down this difference, which can be several metres, is quite important.

`safety_factor` - in metres. This is the height above the target point at which the periapsis will be placed. While heading to the periapsis, the descent burn will be iniated if the radar altitude drops below half this value. In hilly terrain, a higher value may be needed to avoid terrain.

`max_distance` - in metres. Used when trying to place the periapsis, this is the largest distance the orbit track is allowed to vary from the ideal track that would pass directly over the target point.

`days_limit` - this is the number of days allowed to elapse between the set-up and the landing. This is used by the node placement functions that try to set-up a phasing orbit to pass over the target point.

`exit_mode` - following a successful landing, the runmode will be set to this value before the function exits.

##### Steps

* Set-up (`initDescentValues()`).
* The landing gear is cycled to ensure it will be down.
* A phasing orbit is set-up that will pass over (or at least very close to) the target point.
* The periapsis of the orbit is lowered over the target point (to the highest nearby terrain height + `safety_factor`).
* The periapsis is checked and raised if it has dropped too low following the previous step's burn.
* The script time warps until either within a few seconds of periapsis, or because the radar altitude has dropped below half the `safety_factor`.
* The craft is steered to the vector returned by `constantAltitudeVec()` and the script begins checking to see when a constant altitude burn should be engaged. This occurs when the craft is within a few seconds of periapsis, or when the craft is predicted to impact with terrain.
* The craft is steered to surface retrograde and the script begins controlling the throttle to perform a suicide burn.
* Once close to the ground, the final set-down steps are performed, ideally touching down at `2`m/s.
* The script will then switch to run mode `exit_mode` and return.

Geoff Banks / ElWanderer
