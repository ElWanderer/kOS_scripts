## lib\_geo (geographic function library)

### Description

This library is concerned with calculating the ground track of an orbit and determining if/when a craft will pass over a specific point on the ground.

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

Returns `-1` if the true anomaly cannot be calculated e.g. if the input `orbit` does not pass over the input `latitude`.

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

Returns `-1` if the true anomaly cannot be calculated e.g. if the input `orbit` does not pass over the input `latitude`.

#### `spotAtTime(planet, craft, universal_timestamp)`

This returns a `GEOPOSITION` for the spot on the `planet` that the `craft` will be above at the input `universal_timestamp`.

Though a `GEOPOSITION` is easily found by calling `planet:GEOPOSITIONOF(POSITIONAT(craft,universal_timestamp))`, this function is required in order to take into account the rotation of the `planet`. Basically, though the position vector may have been calculated by passing in a future (or past) timestamp, `GEOPOSITIONOF` does not know this and simply returns the current latitude and longitude. The latitude is not affected by rotation, but the longitude changes at a constant rate.

The number of seconds `planet` takes to rotate is given by `planet:ROTATIONPERIOD`. As such, the angle by which the longitude will change is given by `360 * (universal_timestamp - TIME:SECONDS) / planet:ROTATIONPERIOD`. Note that this change in longitude needs to be treated as a negative; if a craft in a slow, polar orbit is above a ground longitude of `60` degrees and the planet rotates forward `10` degrees, the craft will now have a ground longitude of `50` degrees.

#### `greatCircleDistance(planet, spot1, spot2)`

This function returns the great circle distance between `spot1` and `spot2` on the surface of `planet`.

The great circle distance is the shortest distance between two points on the surface of a sphere, measured along the surface of the sphere (as opposed to a straight line through the sphere's interior).

This function uses the [Haversine formula](https://en.wikipedia.org/wiki/Haversine_formula):

    // hav(distance/body_radius) = hav(lat2-lat1) + (COS(lat1) x COS(lat2) x hav(lng2-lng1))
    // where hav(theta) = SIN(theta/2)^2
    
    // distance = body_radius x inverse_hav(h), where h = hav(distance/body_radius).
    // distance = 2 x body_radius x ARCSIN(SQRT(h))
    
    LOCAL h IS ((SIN(latD/2))^2) + (COS(spot1:LAT) * COS(spot2:LAT) * ((SIN(lngD/2))^2)).
    LOCAL distance IS (2 * planet:RADIUS * ARCSIN(SQRT(h)) * CONSTANT:DEGTORAD).
    
The function returns `-1` if the calculation throws an error. The intermediate value `h` must be between `0` and `1` inclusive but may go outside of those bounds due to floating point errors.

#### `distAtTime(craft, planet, spot, universal_timestamp)`

Returns the ground distance between the input `spot` on `planet` and where the `craft` will be at `universal_timestamp`.

This calls `spotAtTime()` to find out where the craft will be then passes that `GEOPOSITION` straight into `greatCircleDistance()`.

Will return `-1` if `greatCircleDistance()` returns `-1`.

#### `findNextPassCA(craft, planet, target_spot, universal_timestamp)`

This function returns the `universal_timestamp` at which `craft` will pass closest to `target_spot` on `planet`, near to the input `universal_timestamp`.

This function will step forwards (or backwards) at small time increments from the input `universal_timestamp` until the distance between the `target_spot` and the predicted position of the `craft` stops decreasing.

This function should only be used to refine the details of a close approach that has already been estimated (e.g. it is called from `findNextPass()`). The input `universal_timestamp` is expected to be a timestamp when the `craft` will be close to `target_spot`. If it is not, the function may take a long time to complete and/or return a timestamp when the `craft` is on the other side of the `planet` from the `target_spot`.

#### `findNextPass(craft, planet, target_spot, max_distance, days_limit)`

This function returns the first `universal_timestamp` at which `craft` will make a close approach within `max_distance` metres of `target_spot` on `planet`.

In order to prevent an infinite loop, only orbits that take place (wholly or partially) within the next `days_limit` days are considered.

How it works:
* If a `craft` has an orbit with a high enough inclination, it will pass over the latitude of the `target_spot` twice per orbit.
* For each pass, we can calculate when they occur, and thus predict the ground longitude that the `craft` will have.
* Assuming the orbit of the `craft` does not change, it will return to the same latitude every `ORBIT:PERIOD` seconds.
* Assuming the `craft` is not in a synchronous orbit, the longitude of each pass will be different.
* For each pass, we can compare its ground longitude to the longitude of the `target_spot`. If they are within a few degrees (the script uses `3` as a limit), we can call `findNextPassCA()` to get the timestamp of the closest approach and then `distAtTime()` to find out the actual ground distance.
* If we find a close approach that is within `max_distance`, the time from `findNextPassCA()` is returned.

If no close approach within the `max_distance` is found, the function returns `0` (which in terms of time is the epoch at which the game universe was initialised).

Note - `max_distance` is in metres. This is different to the parameter in `listContractWaypointsByETA()`.

Note - the function works best for high inclination orbits. This is because of the way it uses the difference in longitude where the latitudes *match* to determine whether it is worth looking for a close approach or not. This may not find a suitable close approach for low inclination orbits, where the longitude of the ground track changes rapidly compared to the latitude. For those orbits, something that looks for a small difference in latitude when the longitudes match may be more appropriate. This was a design choice because the original aim of the function was to assist in calculating overflights over science waypoints, which are generally scattered over a body at a variety of latitudes and a polar orbit is better for ensuring all points will be overflown.

Note - the time of the first approach within `max_distance` is returned when it is found. The function does not scan ahead to find out if a closer approach occurs later on.

#### `waypointsForBody(planet)`

This returns a `LIST` of all the waypoints for the input `planet`.

This function loops through `ALLWAYPOINTS()`, which is a list of all waypoints in the game universe, and adds those whose `BODY` matches the input `planet` to the return list.

Will return an empty `LIST` if no suitable waypoints were found.

#### `addWaypointToList(waypoint_details_list, eta_list)`

This function adds the `waypoint_details_list` to the `eta_list` such that `eta_list` remains in chronological order.

`waypont_details_list` should be a `LIST` with the format:
* waypoint closest approach ETA
* waypoint name
* waypoint closest approach distance
* waypoint `GEOPOSITION`

`eta_list` should be a `LIST` where each element is a `waypoint_details_list`. It may be an empty `LIST`.

The function loops through `eta_list`, comparing the ETA of each element to that of the `waypoint_details_list` being added. If the ETA of the `waypoint_details_list` is smaller than the `eta_list` entry, it is inserted at that index. If the `waypoint_details_list` ETA is higher than all `eta_list` entries, `waypoint_details_list` is appended to the end of `eta_list`.

#### `listContractWaypointsByETA(craft, max_distance, days_limit)`

This function is the one expected to be called by a script (although in practice, this is more likely to be called from inside another function e.g. in `lib_probe.ks`). It calls the above functions to find all the contract waypoints on the planet that `craft` is currently orbiting, then loops through them generating a `LIST` of close approach details (where a close approach within `max_distance` kilometres is found within `days_limit` days). This list is printed out in the terminal then returned.

The waypoints for the planet are obtained by calling `wayPointsForBody()`.

For each waypoint, with some exceptions, `findNextPass()` is called to find out the estimated time of the next pass within `max_distance`. If this is within `days_limit` days of the current time, the details are added to a list. The complete list is then printed on the terminal, with the estimated times of each pass shown in terms of Mission Elapsed Time. That's useful as the ability to timewarp is severely restricted at low altitudes, so you may wish to return to the tracking centre and warp forward there. Also printed are the waypoint's name and the expected closest approach distance. The list is then returned.

Note - not all waypoints are related to science contracts. Waypoints with a name that matches the vessel name or have the name "Site" are specifically excluded.

Note - `max_distance` is in kilometres. This is different to the parameter in `findNextPass()`.

Note - `days_limit` is used to restrict the number of orbits that will be checked. It is possible for a close approach to be found just past the time limit if the orbit began before the cut-off point.

Geoff Banks / ElWanderer
