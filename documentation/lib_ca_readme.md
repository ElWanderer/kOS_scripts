## lib\_ca (close approach library)

### Description

A small library with common functions for looking for close approaches.

### Function reference

#### `targetDist(target, universal_timestamp)`

Calculates the predicted distances between the active vessel and `target` at the `universal_timestamp`.

Returns the magnitude of the difference in the position vectors to `target` and to the active vessel at the `universal_timestamp`.

#### `targetCA(target, start_timestamp, end_timestamp, minimum_step_size, number_of_slices)`

Finds the time of the closest approach between the active vessel and the `target` between `start_timestamp` and `end_timestamp`.

Note - this is not done by calculation, but by iterating with the orbit prediction functions. As such, it may not always find the closest approach.

##### Method

The length of time between `start_timestamp` and `end_timestamp` is divided by the input `number_of_slices` to get the 'step' size. As long as this is not below the `minimum_step_size`, the `targetDist()` is called for the `start_timestamp`. The time is then incremented by the 'step' size, and the distance re-checked until the time has gone beyond the `end_timestamp`. The reading where the lowest distance occurred is remembered.

The function is recursive; having found a lowest distance at a certain time `T` with a certain 'step' size, the function calls itself, this time with the time range restricted to `T-step` and `t+step` (though these are restricted so that they cannot go above or below the original start and end times). This continues until the step size falls below the `minimum_step_size`.

Once the step size is below `minimum_step_size`, the function returns the average of the last set of start and end timestamps. This should be the time of a close approach, though it may not be the closest overall approach.

Better accuracy can be achieved by reducing the `minimum_step_size`, at the cost of running through more iterations. Picking a very high `number_of_slices` will overcome some of the problems with sampling frequency, at the cost of running through many more orbit predictions.

If the rough details of a close approach are already known (e.g. where two orbits intersect), restricting the initial time period is likely to aid accuracy and avoid finding an approach elsewhere in the orbit.

If not specified, the default value for `minimum_step_size` is `1` second.

If not specified, the default value for `number_of_slices` is `20` slices per iteration.

Geoff Banks / ElWanderer
