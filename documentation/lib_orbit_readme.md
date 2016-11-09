## lib\_orbit (general orbit mechanics calaculation library)

### Description

Functions that assist in calculating where craft will be, how long they will take to travel between points on their orbits and for calculating a manoeuvre node to set an orbit to a specific pair of altitudes.

It's worth checking out OhioBob's [Basics of Space Flight: Orbital Mechanics page](http://www.braeunig.us/space/orbmech.htm) for some of the mathematics underpinning these functions.

### Requirements

 * `lib_node.ks`

### Function reference

#### `calcTa(semimajoraxis a, eccentricity e, radius r)`

Calculates and returns the true anomaly (the angle between the periapsis and the point we're interested in) for the given input parameters. There are technically two solutions for each radius; this function will always return a value between `0` and `180` degrees.

Orbital radius can be calculated from `true_anomaly` by `a * (1 - e^2))/ (1 + (e * COS(true_anomaly))`, where a is the semimajoraxis of the `orbit` and e is the eccentricity of the `orbit`.

Rearranging this, true anomaly can be calculated by `ARCCOS( ((a * (1 - e^2)) - r)/ (e * r) )`.

There is a potential problem with this calculation. `ARCCOS()` will throw an error that crashes the script if it is passed in a value whose absolute value is greater than `1`. This should not happen under normal circumstances, but I've run into it enough times to add special handling for this situation. The root cause of any problem seems to be that if we are performing a large calculation, some of function calls may occur in a different physics tick, where the values will be different. Effectively, we pass an impossible combination of `semimajoraxis`, `eccentricity` and `radius` into the function. This may also be exacerbated by wobbly KSP orbits that are bouncing back and forth (hopefully less of a problem in newer versions of KSP). If this occurs, the script will log that it has hit this error and reboot to prevent a crash. The hope is that following a reboot, it will get a sensible set of numbers to calculate the true anomaly, but this may not always happen, in which case it'll reboot repeatedly...

#### `velAt(craft, universal_timestamp)`

A wrapper around the kOS `VELOCITYAT` prediction function that returns the orbital velocity vector for the input `craft` at the input `universal_timestamp`.

#### `posAt(craft, universal_timestamp)`

A wrapper around the kOS `POSITIONAT` prediction function. This returns the relative position between the input `craft` and its sphere of influence body at the input `universal_timestamp`, in effect giving the orbital radius (altitude + the radius of the body) at that point.

This function is useful for plotting nodes in other spheres of influence. As with `velAt()` this has been tested by plotting a circularisation node around the Mun while still in orbit of Kerbin.

#### `taAt(craft, universal_timestamp)`

Calculates the true anomaly for the given `craft` at the given `universal_timestamp`.

It does this by calling the prediction functions to determine the orbit and orbital radius (altitude + body radius) of the `craft` at that time, then passes those details into `calcTa()`.

As `calcTa()` will always return values in the range `0`-`180` degrees i.e. the first half of the orbit, we check if the altitude is going up or down at the predicted point. If it is going down, we are in the second half of the orbit, so we subtract the result from `360` to get the true anomaly.

#### `maFromTa(true_anomaly, eccentricity e)`

Calculates the mean anomaly from the `true_anomaly`. The mean anomaly is an imaginary angle that changes at a constant rate during an orbit, making it very helpful for some calculations.

Two different calculations can be done to determine the mean anomaly, depending on whether the orbit is elliptical (`eccentricity` is less than `1`) or if it it hyperbolic (`eccentricity` is greater than `1`). Note that parabolic orbits with an `eccentricity` of exactly `1` are not handled. I'd imagine they're almost impossible to achieve in KSP, too.

For elliptical orbits:
* the eccentric anomaly must first be calculated, by `ARCCOS( (e + COS(true_anomaly)) / (1 + (e * COS(true_anomaly))) )`. Due to the `ARCCOS()`, the result will always be in the range `0`-`180` degrees (or `0`-`pi` radians) but we can tell if we're in the first or second half of the orbit by the `true_anomaly`. If the `true_anomaly` is greater than `180`, then we subtract the calculated eccentric anomaly from `360`.
* the mean anomaly can be calculated from the eccentric anomaly by `eccentric anomaly - (eccentricity * SIN(eccentric anomaly))`, where the eccentric anomaly is expressed in radians. In kOS, that results in the following: `(CONSTANT:DEGTORAD * ea) - (e * SIN(ea))`.

For hyperbolic orbits:
* the hyperbolic eccentric anomaly, F, must first be calculated. This is a frankly horrible calculation, usually split into two steps whereby F is given by `LN(x + SQRT(x^2 - 1))`, where x is `(e+COS(true_anomaly)) / (1 + (e * COS(true_anomaly)))`.
* the mean anomaly is then given by `(e * SINH(F)) - F`.
  * If the `true_anomaly` is less than `180` degrees, we have gone past periapsis, so the mean anomaly is returned as calculated
  * If the `true_anomaly` is greater than `180` degrees, we have not yet reached periapsis. As such, the mean anomaly is negated (subtracted from `0`) before being returned.

Note that for a closed orbit, the mean anomaly returned will be in the range `0`-`360` degrees. In an escape (hyperbolic) orbit, the mean anomaly returned be will in the range `-180` to `180` degrees.

#### `secondsToTa(craft, universal_timestamp, true_anomaly)`

This function calculates the number of seconds that will elapse between the `universal_timestamp` and the `craft` reaching the input `true_anomaly`.

This is determined by finding the mean anomaly of the `craft` at the `universal_timestamp` and at the given `true_anomaly`. The progression around an orbit is given by `SQRT(semimajoraxis^3 / body_Mu) * delta-mean anomaly`.

If the `craft` has already passed the target `true_anomaly`, the time taken will be negative. For hyperbolic (escape) orbits, this is returned as-is, but for elliptical (closed) orbits where we can expect to come back around to the desired `true_anomaly`, the time taken is incremented by one orbital period. 

#### `radiusAtTa(orbit, true_anomaly)`

This calculates what the orbital radius (altitude + body radius) will be at a given `true_anomaly` for the input `orbit`.

Orbital radius can be calculated from `true_anomaly` by `a * (1 - e^2))/ (1 + (e * COS(true_anomaly))`, where a is the semimajoraxis of the `orbit` and e is the eccentricity of the `orbit`.

The value returned will be in metres.

#### `nodeAlterOrbit(universal_timestamp, opposite_altitude)`

This function plots a manoeuvre node at the `universal_timestamp` that will make the altitude on the opposite side of the orbit equal to `opposite_altitude`.

Things to note:
* the calculations use the orbital radius, but for useability, the input parameter `opposite_altitude` is an altitude above sea-level
* the input parameter `opposite_altitude` is in metres
* the orbit is altered so that the position of the manoeuvre node becomes either the periapsis or apoapsis. This is because the calculation uses the vis-viva equation `v = SQRT(body_Mu * ((2/r)-(1/a)))` to determine the desired velocity at the node, where the semimajoraxis a is the average of the orbital radius at the node (r) and the `opposite_altitude` + body radius.
  * This means that the burn may be quite inefficient if the initial flight angle at the node is quite far away from `90` degrees. If an orbit is highly eccentric and the desired node is far from both the periapsis and apoapsis, much of the burn will be radial rather than prograde/retrograde.
* though the calculation of the node is mathematically precise, KSP orbits tend to wobble slightly and burning the node is unlikely to be as accurate, so there will be minor variations in the result.

Geoff Banks / ElWanderer
