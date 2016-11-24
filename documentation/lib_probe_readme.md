## lib\_probe (science probe function library)

### Description

This library is concerned with performing an automated orbital science sweep, visiting all the contract waypoints that specify something along the lines of "take a temperature reading above 11000m at Point XYZ".

Note - this library is currently a small extension of `lib_geo.ks`. Some functionality might be moved between the two libraries in the future.

### Requirements

* `lib_steer.ks`
* `lib_geo.ks`
* `lib_science.ks`

### Global variable reference

#### `WP_BUFFER`

The number of seconds to come out of timewarp prior to the predicted closest approach of the next waypoint. The aim of the buffer is to allow for small inaccuracies in the prediction of when the closest approach will occur.

This has a value of `30` seconds.

### Function reference

#### `pointAtSun()`

This function steers the active vessel to point at the sun, waits until the steering is settled then turns it off to save power and prevent the predicted orbit from being affected.

#### `visitContractWaypoints(max_distance, days_limit)`

This function is the one expected to be called by a boot script. It is intended for taking science readings above contract waypoints. It does not harvest science results for return/transmission.

It makes use of `listContractWaypointsByETA()` in `lib_geo.ks` to obtain a list of all the contract waypoints that the active vessel will pass within `max_distance` kilometres of during the `days_limit` days, assuming no changes are made to its orbit. Going through this list, it then time warps to each one in turn and triggers all the science experiements on the vessel at closest approach. To avoid power issues, the science is not transmitted anywhere; the experiments are reset after each waypoint.

Note - `max_distance` is in kilometres.

Note - `days_limit` provides a hard time limit in days from the time the function was called. The setting is not remembered, so if the function is called again with the same parameters, the new time limit will be further in the future than the old one.

Geoff Banks / ElWanderer
