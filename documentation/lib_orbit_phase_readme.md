## lib\_orbit\_phase (phasing orbit library)

### Description

This library provides a function for handling phasing orbits, that is orbits whose period is a set length, to aid in rendezvous or passing over a certain spot.

### Requirements

* `lib_orbit.ks`
* `lib_burn.ks`

### Function reference

#### `periodOk(current_period, desired_period, is_prograde)`

This function tests whether the `current_period` is okay or not. Primarily, this is checking whether it is within a set tolerance (`0.1` seconds) of the `desired_period`, but it will also take into account the direction in which we are burning.

Returns `TRUE` under the following conditions:
* The absolute difference between `current_period` and `desired_period` is less than `0.1` seconds.
* Burning in the current facing will push the `current_period` away from `desired_period`. This depends on the value of `is_prograde`:
  * `TRUE`: if the `current_period` is larger than the `desired_period` (as burning will only make it even larger)
  * `FALSE`: if the `current_period` is smaller than the `desired_period` (as burning will only make it even smaller) 

#### `tweakPeriod(desired_period)`

This function points to prograde or retrograde and sets the throttle to `10%` until the orbital period is close to the input `desired_period`. It was created because manoeuvre node burns were often producing an orbital period that was a few seconds out from that desired, which over the course of several phasing orbits could result in a closest approach being much further out than originally planned.

The function compares the current orbital period to the input `desired_period`:
* If the `desired_period` is larger, we need to burn prograde to increase the orbit.
* If the `desired_period` is smaller, we need to burn retrograde to decrease the orbit.

The active vessel will be steered to prograde or retrograde as necessary. Once facing the right way, the throttle is set to `10%` until periodOk returns `TRUE`. Then the throttle will be set back to `0`.

#### `orbitAltForPeriod(planet, orbit, true_anomaly, phase_period)`

This function calculates the altitude that would result on the opposite side of the orbit, were a manoeuvre node plotted and executed at the `true_anomaly` of the input `orbit` around `planet`, that produces a new orbit with a period that matches `phase_period`.

The orbital period of an orbit can be determined from the semimajoraxis (a) by: `2 * CONSTANT:PI() * SQRT(a^3 / planet_Mu)`. This function uses the inverse of that to calculate the semimajoraxis from the desired orbital period: `((planet_Mu * (phase_period^2))/(4*(CONSTANT:PI^2)))^(1/3)`. From this semimajoraxis, the altitude at the opposite side of the orbit can be calculated.

This function is typically used to calculate the opposite altitude that would then be passed in to the `lib_orbit.ks` function `nodeAlterOrbit()`.

#### `orbitPeriodForAlt(planet, orbit, true_anomaly, opposite_radius)`

This function calculates the orbital period that would result were a manoeuvre node plotted and executed at the `true_anomaly` of the input `orbit` around `planet`, that changes the orbital radius opposite the node to match `opposite_radius`.

The orbital period of an orbit can be determined from the semimajoraxis (a) by: `2 * CONSTANT:PI() * SQRT(a^3 / planet_Mu)`.

This function is typically used to create boundaries above/below which the phase period should not go e.g. because it would exit the current sphere of influence or drop too close to the parent body.

#### `orbitTAOffset(orbit1, orbit2)`

Returns the angle by which `orbit2` is offset from `orbit1`. This is expected to be used to convert the true anomaly of a position vector in one orbit to the true anomaly that position vector would have in the other orbit, where the two orbits are .

For example, consider two orbits that share the same orbital plane, so their longitudes of the ascending node are the same, but they have arguments of periapsis that are `100` and `110` degrees respectively. A position vector that passes through the periapsis (true anomaly is `0`) of the first orbit will pass through the second orbit `10` degrees before the periapsis. The true anomaly of a craft in this position of the second orbit would have a true anomaly of `350` degrees.

This function is typically used to compute the angular separation at an intersection between two craft in aligned orbits, so that the separation in time can be calculated, from where we can consider a phasing orbit to engineer a close approach.

Comment - this function also exists in `lib_rendezvous.ks`. I suspect it should only live in one or the other.

Geoff Banks / ElWanderer
