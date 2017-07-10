## `lib_slope.ks` (slope calculation library)

### Description

This library provides functions for calculating the slope of the ground and for finding suitably flat spots e.g. for landing on.

The slope angle calculation is based on Kevin Gisi's (episode 42 of Kerbal Space Programming) - we take a spot on the ground and run short (a few metres) position vectors out to two nearby spots. Performing a vector cross of those two vectors will return a vector that is normal (at 90 degrees to) both of the position vectors. If the ground is flat, this normal vector will point directly upwards; the bigger the slope, the further over the normal vector will lean. The angle bewteen the normal and the local up vector will give us the angle of the ground's slope.

Note - this all relies on the terrainheights returned by the game being accurate. The game is not guaranteed to have loaded the terrain to the accuracy required if the active vessel is in a very high orbit.

### Requirements

* `lib_geo.ks`

### Function reference

#### `spotDetails(latitude, longitude)`

For the geographic location (of the current body) defined by the input `latitude` and `longitude`, this function returns a list consisting of:
  * [0]: the position vector (from the active vessel)
  * [1]: the up vector at that location
  * [2]: the terrainheight of the location

#### `slopeDetails(latitude, longitude, radius)`

For the geographic location (of the current body) defined by the input `latitude` and `longitude`, this function returns a list consisting of:
  * [0]: the position vector (from the active vessel)
  * [1]: the up vector at that location
  * [2]: the terrainheight of the location
  * [3]: a normalised vector, pointing normal to the apparent slope at the location
  * [4]: the angle between [3] and [1] (a.k.a. the slope angle)

The calculation of the slope uses the input `radius` (or `2`, if this has not been specified). This is in metres.

In the calculation, spots 1, 2 and 3 form an equilateral triangle, `radius` metres from the centre spot: 
  * spot 1 is `radius` metres North of the centre spot.
  * spots 2 and 3 are `0.5` (`sin(30)`) `radius` metres South of the centre spot.
  * spots 2 and 3 are `SQRT(3)/2` (`cos(30)`) `radius` metres East or West of the centre spot.

If the location is very close to the North Pole, we will use a South-facing vector instead of North. This will also result in the East vector pointing West.

As described in the file's description above, the slope calculation takes two vectors, from spot 1 to spot 2 and from spot 1 to spot 3, then crosses them. This produces a vector normal to both which can be used to do two things:
  * the angle between it and the local up vector gives the slope angle.
  * excluding the local up vector from it returns a horizontal vector pointing in the direction that would take us 'down' the slope.

#### `slopeAngle(latitude, longitude, radius)`

For the geographic location (of the current body) defined by the input `latitude` and `longitude`, this function returns the slope angle (where `0` is flat and `90` is a vertical face).

The calculation of the slope uses the input `radius` (or `2`, if this has not been specified). This is in metres.

This is a shortcut for calling `slopeDetails` and finding the 5th token of the returned list.

#### `downhillVector(slope_details_list)`

This function takes in a `slope_details_list` (as returned by calling `slopeDetails()`) and calculates the horizontal direction at the location that points down the slope.

#### `findLowSlope(max_slope_ang, latitude, longitude, radius)`

The purpose of this function is to identify a geographic spot that has a slope angle low enough e.g. to find a landing site. It returns a geographic location i.e. what would be returned by the function `LATLNG()`. The starting point is defined by the input `latitude` and `longitude` - if the slope at that point is lower than `max_slope_ang`, that spot will be returned immediately.

The basic format of this function is to keep moving downhill until we find flatter ground. If the slope at the initial site is greater than `max_slope_ang`, we will shift the site downhill (as defined by calling `downhillVector()` then test again. This loops until the slope is lower than the desired maximum.

For each shift, we go `radius * (slope_angle() / max_slope_ang)^2` metres down the slope (i.e. jump further if the slope is further from being acceptable).

We keep track of the last few points visited. If we find ourselves within `radius` meters of one of these recent points, we assume we have got stuck e.g. at the bottom of a steep-sided valley. To escape from this we make a large jump in a random direction. The length of this jump starts at `1` kilometre; it increases by `1` kilometre each time we have to make another jump. This should ensure that we eventually find a point that is flat enough for our purposes, unless the input parameters are particularly strict.

The function has defaults for all parameters, if they are not specified:
* the default `max_slope_ang` is `5` degrees
* the default `latitude` is the current latitude of the active vessel
* the default `longitude` is the current longitude of the active vessel
* the default `radius` is `2` metres

Geoff Banks / ElWanderer
