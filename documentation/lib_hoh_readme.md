## lib\_hoh (Hohmann transfer orbit library)

### Description

This library provides a single function for creating a manoeuvre node to perform a Hohmann transfer. This was separated from other libraries so it could be used by both `lib_transfer.ks` and `lib_rendezvous.ks`, though the latter's application of Hohmann transfers has not been implemented yet.

### Requirements

* `lib_orbit.ks`

### Function reference

#### `nodeHohmann(target, universal_timestamp, target_periapsis)`

This function returns a manoeuvre node that will transfer to the orbit of the `target`, timed such that the active vessel should meet the `target`. It assumes that the active vessel and `target` are in circular orbits.

`target` is expected to be a valid target. This function is intended to be used to transfer to another body or rendezvous with another craft. It cannot be used to transfer to arbitrary orbits.

If `target_periapsis` is specified, the orbit will be that many metres further out than the centre of the target. Note this requires the input to be an orbital radius, not an altitude.

If not specified, the default value for `target_periapsis` is `0`.

##### Calculation details

The initial change in velocity required for a Hohmann transfer from an orbit with radius r1 to an orbit with radius r2 is given by: `SQRT(planet_Mu/r1) * (SQRT((2*r2)/(r1+r2)) -1)`.

The transfer time for the Hohmann transfer orbit is given by `CONSTANT:PI * SQRT( ((r1+r2)^3) / (8 * planet_Mu) )`. This is half the resultant orbital period, as we do not expect to complete a full orbit.

During this time `target` will move around `360 * (transfer_time / target:ORBIT:PERIOD)` degrees. The active vessel will travel `180` degrees (half an orbit). The difference between the two gives the relative phase angle (phi). We want to place the manoeuvre node at the point where the angle between vessel and `target` is equal to phi: `180 - (360 * transfer_time / target:ORBIT:PERIOD)`.

The current phase angle can be calculated by taking the current position vectors for the active vessel and the `target`, then using `VANG()` to find the vector angle between them. `VANG()` will not return values higher than `180` degrees, so we must check which way a vector cross of the two position vectors is pointing to determine if the result should be subtracted from `360` or not.

Assuming the current and desired phase angles are different (I call the difference between the two delta-phi), and that the orbits are circular (or near enough), the speed at which the phase angle changes will let us calculate the time until the phase angle is exactly what we want. The relative phase angle velocity is given by by the difference in the orbital angular velocities: `(360 / orbit1:PERIOD) - (360 / orbit2:PERIOD)`.

Now we have the time and magnitude of the manoeuvre node, so we can create a node: `NODE(universal_timestamp + (delta-phi / relative_phase_angle_velocity), 0, 0, delta-v)`.

There is one last piece of the puzzle. We add this node to the flight-path and check if we get an unexpected transition to the sphere of influence to another in the first half of the orbit e.g. if a transfer to Minmus encounters Mun on the way out. In this situation, we advance an orbit at a time until the undesired encounters cease. We cannot add exactly one full orbital period of the active vessel, as the target will also be moving. Instead we must consider the relative phase angle velocity and from that determine how long it takes for the phase angle to become the desired value again: `ABS(360/relative_phase_angle_velocity)`

Geoff Banks / ElWanderer
