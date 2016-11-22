## lib\_orbit\_match (orbit plane-changing library)

### Description

This library provides functions for changing the orientation of the plane (inclination and longitude of the ascending node) of an orbit, whether to meet an input set of orbital parameters, or to match inclination with a target.

Inclination matching is done by generating 'normal' vectors for the two orbits involved. A 'normal' vector is orthogonal (at 90 degrees) to both the position and velocity vectors of anything following that orbit.

Note that this is one of two similar libraries:
* `lib_orbit_change.ks` contains code for changing the shape of an orbit - periapsis, apoapsis and argument of periapsis.
* `lib_orbit_match.ks` contains code for changing the orientation of an orbit - inclination and longitutde of the ascending node.

### Requirements

* `lib_orbit.ks`
* `lib_burn.ks`

### Function reference

#### `orbitNormal(planet, inclination, longitude_of_ascending_node)`

This function returns a 'normal' vector that defines the plane of the orbit defined by the input orbital parameters.

The function constructs theoretical, normalised position and velocity vectors for the ascending node of the orbit.

The 'normal' vector is then determined by performing a vector cross of the position and velocity vectors, getting a resultant vector that is orthogonal (at 90 degrees) to them both.

Vector creation works as follows:

* The position vector is determined by rotating the solar prime vector around the Y axis (which in KSP is a universal 'up'). The angle of rotation is given by the `longitude_of_ascending_node`, though it must be negated as KSP uses left-hand rotation rather than right-hand: `R(0,-longitude_of_ascending_node,0) * SOLARPRIMEVECTOR`
* The velocity vector is calculated in two steps:
  * Firstly, we vector cross the axis of the `planet` (which I think points downwards rather than 'up') with the position vector we previously calculated.
  * Secondly, we rotate this vector up or down by the inclination, using the position vector as an axis

#### `craftNormal(craft, universal_timestamp)`

This function returns a 'normal' vector that defines the plane of the orbit of `craft` at `universal_timestamp`.

This is achieved by performing a vector cross of the craft's position and velocity vectors, to get a resultant vector that is orthogonal (at 90 degrees) to both of them.

#### `orbitRelInc(universal_timestamp, inclination, longitude_of_ascending_node)`

This function returns the relative inclination between the orbit of the active vessel at `universal_timestamp` and the orbit defined by the input orbital parameters.

#### `craftRelInc(target_craft, universal_timestamp)`

This function returns the angle of relative inclination between the orbits of the active vessel and the `target_craft` at `universal_timestamp`.

This is calculated by determining the 'normal' vectors for each orbit and finding the vector angle between them.

#### `taAN(universal_timestamp, orbit_normal_vector)`

This function calculates the true anomaly of the active vessel's orbit (as determined at `universal_timestamp`) where it will cross the plane of the orbit defined by the `orbit_normal_vector` in an ascending direction.

This function calculates the 'line of nodes' by taking a vector cross of the 'normal' vectors for the two orbits. This results in a line that passes through the central body and the two points on each orbit where the orbital planes intersect (the orbits themselves won't intersect here except in very rare circumstances). The angle around the active vessel's orbit from it's position vector at `universal_timestamp` to the line of nodes vector gives the relative true anomaly, which is added to the actual true anomaly at `universal_timestamp` to get the result.

Note - the vector angle calculation will always return a result that is `180` degrees or less; if the ascending node is actually `355` degrees around the orbit, `VANG()` will return `5`. In order to determine whether the result of `VANG()` is correct or needs subtracting from `360`, we take a vector cross of the position vector and line of nodes vector. The result of the cross will point up or down depending on which way around the two vectors are.

The description here could use some of the diagrams I drew in my notebook when I was trying to understand this!

#### `nodeFromVector(node_vector, n_time IS TIME:SECONDS)`

This function will generate a manoeuvre node to change the active vessel's velocity at `universal_timestamp` by the input `node_vector`. The vector is converted to prograde, radial-out and normal components, so that a node can be created.

If not specified, the default value for `universal_timestamp` is the current time, i.e. `TIME:SECONDS`.

#### `nodeToVector(final_vector, universal_timestamp)`

This function will generate a manoeuvre node to change the active vessel's velocity at `universal_timestamp` to match the input `final_vector`.

It is similar to `nodeFromVector()` (and ends up calling it) but the input vector is different. `final_vector` is the desired velocity vector following the burn.

If not specified, the default value for `universal_timestamp` is the current time, i.e. `TIME:SECONDS`.

#### `nodeMatchAtNode(universal_timestamp, orbit_normal_vector, at_ascending)`

This function generates a manoeuvre node to match inclination with the orbit plane defined by the input `orbit_normal_vector`, at either the ascending node or descending node depending on the value of `at_ascending`. If burnt, the node will effect a 'simple plane change', that is the magnitude of the orbital velocity after the burn should be (roughly) the same as it was before the burn: the only difference is the direction of that velocity.

This function has changed a great deal recently as I found that the original implementation was quite inaccurate for plane changes unless the orbit was nearly circular or the burn happened to be near an apside.

Based on the input `o_normal` (a normal vector representing the orbit we are aligning with), we call `taAN()` to find out what true anomaly of the ascending node, where the orbit of the active vessel crosses above the target orbit. Depending on `at_asecending`, we'll either use this true anomaly or the opposite side of the orbit.

Once we have a true anomaly, we can work out when our vessel will reach the node (by calling `secondsToTA()`). At that point, we find the predicted velocity and position vectors. The angle between these, once subtracted from 90, gives us the so-called fligh-path angle - this is the angle between the velocity vector and a vector at 90 degrees to the position and normal vectors. At an apside, or in a completely circular orbit, this angle is `0`. For an eccentric orbit, it will vary above and below zero as the craft ascends to the apoapsis then descends to the periapsis.

To effect the plane change, we want our velocity after the burn to have the same magnitude as beforehand and we want to maintain the same flight-path angle, as this will keep the shape of our orbit the same. Most importantly, we want it to be aligned in the new plane rather than the old one. To achieve this, we take a vector cross of the position vector and the new orbit normal - this gives us a vector in the new plane that will have a flight-path angle of `0`. To get the correct alignment we rotate this by the desired flight-path angle, using the new orbit normal as an axis. Finally, we normalise this vector (reduce it to a unit vector) and multiply it by the magnitude of the original velocity vector. Having constructed the desired final velocity vector, we pass this in to `nodeToVector()` and return the result.

#### `nodeIncMatch(universal_timestamp, orbit_normal_vector)`

This function is called to generate a manoeuvre node to match orbital inclination with the orbit defined by the input `orbit_normal_vector`. However, it does not calculate the node itself - it's effectively another wrapper function. 

The function calls `nodeMatchAtNode()` twice, to get two manoeuvre nodes: one at the ascending node and one at the descending node. It then selects the 'best' one to be returned as follows:
* If the 'eccentricity' of the delta-v of the two nodes (calculated by `2 * ABS(dv_AN-dv_DN) / (dv_AN + dv_DN)`) is greater than `0.2`, the node with the lower delta-v is selected. For example if the two nodes are `90`m/s and `110`m/s, this works out as `0.2` exactly.
* Otherwise, the node that will occur next (smallest `ETA`) is selected.

#### `nodeIncMatchTarget(target_craft, universal_timestamp)`

This function is a wrapper. It calls `craftNormal()` to get a normal vector for the orbit of `target_craft` at `universal_timestamp`, passes this into `nodeIncMatch()` and returns the result.

#### `nodeIncMatchOrbit(universal_timestamp, inclination, longitude_of_ascending_node)`

This function is a wrapper. It calls `orbitNormal()` to get a normal vector based on the input orbital parameters (and the body the active vessel will be around at `universal_timestamp`), passes this into `nodeIncMatch()` and returns the result.

#### `matchOrbitInc(staging_allowed, delta-v_limit, universal_timestamp, inclination, longitude_of_ascending_node)`

This function is only expected to be called from `doOrbitMatch()`. 

The function begins by calculating the relative inclination between the current orbit and that defined by the input parameters. If it is greater than `0.05`, a manoeuvre node will be plotted by calling `nodeIncMatchOrbit()`. Otherwise, the orbits are aligned close enough not to need a manoeuvre and the function will return `TRUE`.

If a manoeuvre node is plotted, the delta-v required for this is checked against the input `delta-v_limit`:
* If the delta-v required is less than the limit, `execNode()` will be called to execute the node. The function will then return `TRUE` or `FALSE` depending on whether the burn was successful or not.
* If the delta-v required is more than the limit, an error will be printed and the function will return FALSE.

#### `doOrbitMatch(staging_allowed, delta-v_limit, inclination, longitude_of_ascending_node)`

This is the 'public-facing' function. It will call `matchOrbitInc()` to plot a manoeuvre node to change the orbital parameters to those passed in. If this is successful and within the `delta-v_limit`, `matchOrbitInc()` will be called again, this time to execute the node.

If there is already a manoeuvre node on the flight-path when this function is called, it will be executed before doing anything else. This is to avoid recalculating the manoeuvre just because the player switched vessels.

`staging_allowed` is passed in to the call to `execNode()`.

If not specified, the default value for `longitude_of_ascending_node` is `-1`. This will maintain the orbit's existing value.

Geoff Banks / ElWanderer
