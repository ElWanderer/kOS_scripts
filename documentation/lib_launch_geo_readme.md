## lib\_launch\_geo.ks (launch direction/time calculation library)

### Description

This library contains functions used to calculate the initial launch heading (azimuth) and the time to launch into a given plane. These functions are only expected to be used on the ground.

The mathematics involved in determining the launch time are not particularly complicated, but it took me a while to find the right equations to use. In particular, we are interested in the location of the orbital plane, not the ground track of an object following that orbit. These are not the same thing and I kept finding the latter when I searched for the former!

The launch azimuth calculation is largely based on a really useful post about this on the Orbiter forum: http://www.orbiterwiki.org/wiki/Launch_Azimuth

A note on terminology regarding ascending and descending nodes: In general, these refer to the points where the orbit plane passes a reference plane going from South to North (ascending) or from North to South (descending). For the specific case of orbital elements (in particular the Longitude of the Ascending Node / LAN), the reference plane is the equator of the planet. Typically in this file, I'll be using the case of overpasses, where the reference plane is the latitude of our craft. Unless we happen to be on the equator (even the KSC launch site is slightly off to the South), these nodes occur at different times and places. Aside: there is also rendezvous (not covered here), for which the reference plane would be the orbit of our current craft.

### Global variable reference

#### `HALF_LAUNCH`

To launch into a particular inclined plane, we assume you need to launch a short time before the target orbital plane passes overhead, as it takes some time to get up to speed.

The initial value is `145` seconds, though this can be changed by calling `changeHALF_LAUNCH(new_value)`.

This value was arrived at by halving the time taken for a sample Kerbin launch (roughly five minutes) and deducting a few seconds for luck.

### Function reference

#### `changeHALF_LAUNCH(new_value)`

If passed in a non-zero value, sets `HALF_LAUNCH` to the parameter.

#### `latIncOk(latitude, inclination)`

This can be thought of as asking "is the input inclination achievable, given the craft's current latitude?" Perhaps a better description would be "could an orbit with this inclination pass over a spot with this latitude?" There is a similar function latOkForInc in `lib_geo.ks`, though the two are slightly different from each other. This was defined here to avoid needing the entire `lib_geo.ks` library just for the one function.

It is used widely to prevent various calculations throwing errors that would crash the script. If the inclination is lower (and bear in mind that a value of `179` degrees inclination is actually quite low, being a retrograde orbit inclined `1` degree from the equator) than the latitude, then an orbit with that inclination cannot pass over the given latitude and if we try to assume that it would we will run into lots of errors.

There is also a check that the latitude is not precisely `90` degrees (unlikely though this is), as inputting that into `TAN()` may cause a crash or push a huge number into a calculation.

#### `etaToOrbitPlane(ascending_node, target_orbit_LAN, target_orbit_inclination, current_latitude, current_longitude)`

Calculates the estimated time until the orbital plane described by the input `target_orbit_LAN` and `target_orbit_inclination` will pass over the point defined by the input `current_latitude` and `current_longitude`, going in the direction South to North if `ascending_node` is `TRUE`, North to South if it is `FALSE`.

This function is rather short, but concentrated. It is the result of much scribbling in my notebook, a few false starts, a lot of testing and a lot of printing of vectors, with all the supporting structure then removed. The key to solving it was finding the following formula for determining the *relative* longitude of each point in an orbit based on the latitude and inclination: `relative_longitude = ARCSIN(TAN(latitude)/TAN(inclination))`.

The relative longitude is the angle around the planet between the ascending node (where the orbit crosses the equator) and the point on the orbit we're interested in. Note this is an angle around the planet's axis of rotation, not the usual angle around an orbit, which would be expressed as anomaly (true anomaly, eccentric anomaly, mean anomaly...)

Note - this is not used if the `target_orbit_inclination` is `0` or `180` degrees. In such cases, the latitude does not vary, so you cannot use it to find the relative longitude.

Firstly we check if the latitude and inclination are okay:

    LOCAL eta IS -1.
    IF latIncOk(current_latitude,target_orbit_inclination) {
and if so we calculate the relative longitude:

      LOCAL rel_lng IS ARCSIN(TAN(current_latitude)/TAN(target_orbit_inclination)).

ARCSIN() will return values between `-90` and `90`. If we are interested in the descending node, subtract the relative longitude from `180` to get values in the range `90` to `270`:

      IF NOT is_AN { SET rel_lng TO 180 - rel_lng. }
Now the hard/clever bit. We want to convert from a longitude relative to the orbit's `LAN`, to a geographical longitude relative to the planet. In kOS, `BODY:ROTATIONANGLE` gives you the angle between the universal reference vector and the body's zero longitude. Subtracting `BODY:ROTATIONANGLE` from the orbit's `LAN` gives the current geographical longitude of the orbit's ascending node as it crosses the equator. Adding the calculated relative longitude for the point of the orbit that we're interested in to this gives the current geographical longitude of that point. As is standard, we call `mAngle()` to restrict the result to the range `0`-`360` degrees:

      LOCAL geo_lng IS mAngle(target_orbit_LAN + rel_lng - BODY:ROTATIONANGLE).
The rest is much easier. We have our current geographical longitude and the geographical longitude where the orbit plane meets our latitude. The angle between them will change predictably as the planet rotates. The time it will take for the planet to rotate us under the orbit plane is given by the difference in the longitudes, divided by `360`, multiplied by the planet's `ROTATIONPERIOD`:

      LOCAL node_angle IS mAngle(geo_lng - current_longitude).
      SET eta TO (node_angle / 360) * BODY:ROTATIONPERIOD.
    }
    RETURN eta.

Returns the estimated time to the orbit plane passing overhead, or `-1` if this could not be calculated.

#### `azimuth(inclination)`

This calculates the azimuth (compass heading) of the orbit with the input inclination as it passes over the craft. Note that this does not give you a launch heading - for that see `launchAzimuth()`.

Returns `-1` if the craft's current latitude is too high for the input inclination.

Otherwise returns `ARCSIN(COS(inclination) / COS(SHIP:LATITUDE))`. Note that there are two azimuth values, ascending and descending. The second value can be determined by subtracting the first from `180`.

#### `launchAzimuth(azimuth, apoapsis)`

This calculates the launch azimuth (compass heading) that you would want to point in at launch. If you could instantly accelerate to launch velocity, this is the direction you would want to face. In practice, of course, this is not possible and the launch scripts bend the trajectory slightly to account for the change in latitude during launch.

The input azimuth is the compass heading that the target orbit has as it passes over the craft. It is typically calculated by calling `azimuth(inclination)`.

This is effectively a piece of triangular maths using vectors. We have three vectors:
* a target orbit vector that points towards a heading of `azimuth` degrees, with a magnitude that is orbital velocity at the desired `apoapsis` (assuming a circular orbit), `SQRT(BODY:MU/(BODY:RADIUS + apoapsis))`.
* the current 'orbital' velocity our craft has as a result of the rotation of the planet. In KSP, this has a heading of 90 degrees and a magnitude given by `SHIP:GEOPOSITION:ALTITUDEVELOCITY(ALTITUDE):ORBIT:MAG`.
* the vector we need to burn to get into the target orbit, which is the orbit vector minus the planet rotation vector.

Rearranging this, we can calculate the delta-v required in the Easterly (x) and Northerly (y) axes, and from there determine the launch angle:

    v_launch_x = (v_orbit * SIN(azimuth)) - v_planet_rotation
    v_launch_y = v_orbit * COS(azimuth)
    launch_angle = ARCTAN2(v_launch_y, v_launch_x)

This is the angle *from* the equator we need to launch at. To convert this into a compass heading, we need to subtract it from `90`.

#### `noPassLaunchDetails(apoapsis, inclination, LAN)`

This calculates the launch details (azimuth and time) for the situation where the target orbit plane will not pass overhead.

The azimuth is set to `90` degrees for launches towards a prograde orbit, and to `270` degrees for launches towards a retrograde orbit.

If the target orbit is equatorial (inclination is exactly `0` or `180` degrees), it does not matter when we launch. So we skip the launch time calculation and return a timestamp of `0`, which will result in an immediate launch.

Otherwise, we calculate when the target orbit plane gets closest to the craft. This is done by pretending that our craft is at a latitude that matches the highest latitude of the orbit, taking into account whether we are above or below the equator. For example, if we are at a latlng of `(-15,0)` and trying to match orbit with Minmus (whose inclination is `6` degrees), we will calculate when Minmus's launch plane next passes over `(-6,0)`.

Returns a list containing the calculated launch azimuth and launch timestamp.

#### `launchDetails(apoapsis, inclination, LAN, azimuth)`

This calculates the launch details (azimuth and time) for the situation where the target orbit plane will pass over the craft. This potentially allows two launch windows per day, one where the plane is ascending, the other where the plane is descending. Note - where the target inclination perfectly matches the ship's latitude, these overpasses will be at the same place and time.

Firstly, the function calls the `launchAzimuth()` function to find the initial launch heading and calls `etaToOrbitPlane()` twice to get the estimated time to the ascending and descending nodes. We then try to pick the node that is coming up next, as long as it isn't too soon i.e. within `HALF_LAUNCH` seconds of now. If we pick the descending node, we change the returned azimuth to a Southernly course, by subtracting the original launch azimuth from `180`. If we can't pick a node at all, we fallback to calling `noPassLaunchDetails()`.

Returns a list containing the calculated launch azimuth and launch timestamp.

#### `calcLaunchDetails(apoapsis, inclination, LAN)`

This is the main function that is expected to be called by launch scripts.

Parameters:
* `apoapsis` - altitude in metres of a circular target orbit. Note this is metres and not kilometres, and that it is the altitude above sea level not the orbital radius.
* `inclination` - inclination of the target orbit, in degrees, from `0` (equatorial, prograde) to `180` (equatorial, retrograde).
* `LAN` - the longitude of the ascending node of the target orbit. This is the universal longitude (i.e. angle from the universal reference vector, not the geographic longitude on the planet's surface) where the target orbit crosses the planet's equator from South to North. Typically this is something a launch script will determine based on matching orbit with a target or launching into a specific orbit to match a contract. For pure equatorial orbits, the parameter has no meaning.

It calls `azimuth(inclination)` to see if the target orbit is achievable from the craft's latitude and depending on the result calls either `launchDetails()` or `noPassLaunchDetails()`.

Returns a list containing the calculated launch azimuth and launch timestamp.

#### `warpToLaunch(launch_time)`

A wrapper around `doWarp()` that warps time forward until the calculated `launch_time`.

Prior to calling `doWarp()`, the function triggers a slow warp and sets the warp mode to `RAILS`. It does this every `0.2` seconds until `WARPMODE = "RAILS"`. This is done to force rails warp instead of physics warp, which KSP prefers when a craft is first launched and the terminal has focus. The warp to `launch_time` could take a long time at 4x physics warp...

Geoff Banks / ElWanderer
