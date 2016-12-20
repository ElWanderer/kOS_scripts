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

TBD

#### `checkPeriapsis(latitude, longitude, safety_factor)`

TBD

#### `warpToPeriapsis(safety_factor)`

TBD

#### `constantAltitudeVec()`

TBD

#### `doConstantAltitudeBurn(safety_factor)`

TBD

#### `stepTerrainImpact(start_time, look_ahead, step)`

TBD

#### `calculateImpact()`

TBD

#### `suicideBurnThrot(impact_altitude, surface_g)`

TBD

#### `doSuicideBurn()`

TBD

#### `doSetDown()`

TBD

#### `doLanding(latitude, longitude, radar_adjust, safety_factor, max_distance, days_limit, exit_mode)`

TBD

Geoff Banks / ElWanderer
