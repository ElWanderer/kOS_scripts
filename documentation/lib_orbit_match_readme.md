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

There are a couple of tricks to this, one of which I have struggled to understand myself.

Firstly, it is the calculation of the delta-v required to change inclination that I struggled with most of all. According to trigonometry (picture a triangle where two of the sides are the initial velocity vector and the final velocity vector, with an angle between them that matches the inclination change, then the third side is the delta-v vector required to change from one to the other), the delta-v *should* be given by applying the law of cosines:

    delta-v^2 = initial_velocity^2 + final_velocity^2 - (2 x initial_velocity x final_velocity x COS(angle))
    initial_velocity = final_velocity
    delta-v^2 = (2 x initial_velocity^2) - (2 x initial_velocity^2 x COS(angle))
    delta-v^2 = 2 x initial_velocity^2 x (1 - COS(angle))
    delta-v = SQRT(2 x initial_velocity^2 x (1 - COS(angle)))
    
But for some mysterious reason, I never seemed to get the right velocity from doing this. Instead, I came across code that did this:

    LOCAL ship_orbit_normal_vector IS craftNormal(SHIP,universal_timestamp_of_node).
    LOCAL new_orbit_normal_vector IS ship_orbit_normal_vector:MAG * orbit_normal_vector:NORMALIZED.
    LOCAL radius IS radiusAtTA(ORBITAT(SHIP,universal_timestamp), true_anomaly_of_node).
    LOCAL delta-v IS ABS((orbit_normal_vector - ship_orbit_normal_vector):MAG / radius).

This takes the input `orbit_normal_vector` and changes it to be the same magnitude as the active vessel's orbit normal vector. It then finds the magnitude of the vector difference between the two and divides it by the orbital radius at the point where we are placing the manoeuvre node. This is basically forming an isosceles triangle where we know the length of the two similar sides and the angle between them, and so calculate the third edge, except doing this by subtracting a vector representing one similar side from a vector representing the other similar side. The orbital radius is involved because the magnitude of the orbit normal is equal to the magnitude of the velocity vector multipled by the magnitude of the position vector (the orbital radius), and so we need to divide it out of the results to be left with the velocity. We could alternatively take the velocity vector, rotate it by the angle we are changing inclination and finding the magnitude of the difference between the two. The results should be the same.

Secondly, if you try to change inclination by burning in just the normal direction, you end up increasing the magnitude of your orbital velocity as well as changing the direction in which you are going. For very small angles, this is hard to notice, but it can become very important once the change is more than a few degrees. To effect a simple plane change, the final velocity must be the same velocity as the initial velocity. If we did this in two burns, the second burn would be entirely to retrograde, the slow the velocity back down to the original magnitude... but we can do this in a single, combined burn. So a typical plane change burn consists of a normal component and a retrograde component. They differ in magnitude depending on the angle of the plane change: at one extreme, a complete `180` degree change in velocity requires a wholly retrograde burn.

Having established the delta-v required and the angle of the plane change, these are split into normal and retrograde components as follows (note that if we are at the ascending node, we have to burn anti-normal instead of normal):

    LOCAL delta-v_prograde IS -1 * ABS(delta-v * SIN(angle / 2)).
    LOCAL delta-v_normal   IS delta-v * COS(angle / 2).
    IF at_ascending { SET delta-v_normal TO -1 * delta-v_normal. }

The two components can then be used when creating the manoeuvre node.

Comment - testing is in place to find out if a shorter, more easy to explain version will work, in which case all this extra wordage can be removed!

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
