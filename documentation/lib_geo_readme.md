## lib\_geo (geographic function library)

### Description

Text

Note that this library does a lot of calulating of angles, as such the `mAngle()` function from the `init_common.ks` library is used several times. A reminder that this converts the input angle to be within `0` to `360` degrees.

### Requirements

* `lib_orbit.ks`

### Global variable reference

#### `ONE_DAY`

The number of seconds in a game day. This uses the `KUNIVERSE:HOURSPERDAY` setting to determine whether to use `6`-hour Kerbin days or `24`-hour Earth days.

### Function reference

#### `latOkForInc(latitude, inclination)`

This can be thought of as asking "could an orbit with this inclination pass over a spot with this latitude?" There is a similar function latIncOk in `lib_launch_geo.ks`, though the two are slightly different from each other. That was defined separately to avoid `lib_launch_geo.ks` needing this entire library just for the one function.

It is used widely to prevent various calculations throwing errors that would crash the script. If the inclination is lower (and bear in mind that a value of `179` degrees inclination is actually quite low, being a retrograde orbit inclined `1` degree from the equator) than the latitude, then an orbit with that inclination cannot pass over the given latitude and if we try to assume that it would we will run into lots of errors. It also checks that the inclination is not `0`, to avoid a divide by zero error.

#### `latAtTA(orbit, true_anomaly)`

Returns the latitude that a craft will have if it is `true_anomaly` degrees around the input `orbit`.

This can be calculated as `ARCSIN(SIN(inclination_of_orbit) * SIN(angle_around_orbit))`, though it should be noted that the `angle_around_orbit` is the angle from the Ascending Node (i.e. where this angle is `0`, we are crossing the equator so the latitude is `0` too), not from the periapsis. We can determine that by adding the orbit's `argument_of_periapsis` to the `true_anomaly`.

#### `firstTAAtLat(orbit, latitude)`

Returns the first true anomaly where a craft in the input `orbit` will be over the input `latitude`.

This is determined by inverting the calculation in `latAtTA()`, giving `ARCSIN(SIN(latitude)/SIN(inclination_of_orbit))`. That returns the angle around the `orbit` that the `latitude` is reached, from the Ascending Node. To get the true anomaly, we subtract the `argument_of_periapsis` from the result.

Returns -1 if the true anomaly cannot be calculated e.g. if the input `orbit` does not pass over the input `latitude`.

#### `secondTAAtLat(orbit, latitude)`

Returns the second true anomaly where a craft in the input `orbit` will be over the input `latitude`.

Bearing in mind that orbits are symmetrical, the second true anomaly is related to the first true anomaly, as returned by `firstTAAtLat()`. Let us consider first just the `angle_around_orbit` from the Ascending Node: 
* where this angle is `0` degrees, the latitude is also `0` degrees (as the Ascending Node is at the equator, by definition)
* where this angle is `90` degrees, the latitude is at its highest point and so will match the `inclination` of the `orbit`.
* where this angle is `180` degrees, the latitude is `0` degrees again (as the Descending Node is also at the equator, by definition)
* where this angle is `270` degrees, the latitude is at its lowest point and so will match the negative of the `inclination` of the `orbit`.

The latitude rises and falls in a symmetrical pattern either side of the extreme latitudes. The point we are interested in is where the extreme latitude occurs in the hemisphere of the input `latitude`: `90` degrees around the orbit if the input `latitude` is positive or `270` degrees if `latitude` is negative. The target `latitude` will be reached either side of that extreme point, with the angles between them being the same.

We want to work with true anomaly, which is related to the `angle_around_orbit` by the `argument_of_periapsis`. Once we have the true anomaly where the extreme latitude occurs, and the true anomaly where the `latitude` is reached for the first time (as returned by `firstTAAtLat()`, we can calculate the true anomaly where the `latitude` is reached for the second time:

    // Due to symmetry, the angle between true_anomaly_max_latitude and true_anomaly_1 is equal to
    // the angle between true_anomaly_max_latitude and true_anomaly_2.
    true_anomaly_2 - true_anomaly_max_latitude = true_anomaly_max_latitude - true_anomaly_1
    true_anomaly_2 = true_anomaly_max_latitude + (true_anomaly_max_latitude - true_anomaly_1)
    true_anomaly_2 = (2 x true_anomaly_max_latitude) - true_anomaly_1

Returns -1 if the true anomaly cannot be calculated e.g. if the input `orbit` does not pass over the input `latitude`.

#### `spotAtTime(planet, craft, universal_timestamp)`

This returns a `GEOPOSITION` for the spot on the `planet` that the `craft` will be above at the input `universal_timestamp`.

Though a `GEOPOSITION` is easily found by calling `planet:GEOPOSITIONOF(POSITIONAT(craft,universal_timestamp))`, this function is required in order to take into account the rotation of the `planet`. Basically, though the position vector may have been calculated by passing in a future (or past) timestamp, `GEOPOSITIONOF` does not know this and simply returns the current latitude and longitude. The latitude is not affected by rotation, but the longitude changes at a constant rate.

The number of seconds `planet` takes to rotate is given by `planet:ROTATIONPERIOD`. As such, the angle by which the longitude will change is given by `360 * (universal_timestamp - TIME:SECONDS) / planet:ROTATIONPERIOD`. Note that this change in longitude needs to be treated as a negative; if a craft in a slow, polar orbit is above a ground longitude of `60` degrees and the planet rotates forward `10` degrees, the craft will now have a ground longitude of `50` degrees.

#### `greatCircleDistance(planet, spot1, spot2)`

Text.

#### `distAtTime(craft, planet, spot, universal_timestamp)`

Text.

#### `findNextPassCA(craft, planet, target_spot, universal_timestamp)`

Text.

#### `findNextPass(craft, planet, target_spot, max_distance, days_limit)`

Text.

#### `waypointsForBody(planet)`

Text.

#### `addWaypointToList(waypoint_details_list, eta_list)`

Text.

#### `listContractWaypointsByETA(craft, max_distance, days_limit)`

Text.

Geoff Banks / ElWanderer
