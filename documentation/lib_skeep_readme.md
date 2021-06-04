## lib\_skeep (station-keeping library)

### Description

Though named for the ability to hold a position close to another craft, so far the only functions that have been implement relate to the opposite course of action - getting away from another craft.

#### Separation

The purpose of the separation manoeuvre functions are to plot a small burn that will separate the active vessel from all nearby vessels, without getting too close (or burning the rocket exhaust too close) to any of them.

The size of the separation manoeuvre is (by default) based on the square root of the orbital velocity, divided by `5`. This gives the following delta-v table for some sample low orbits:

    Body     vel (m/s)  sep (m/s)
    -------------------------------
    Kerbin        2275       9.54
    Mun            500       4.47
    Minmus         150       2.45
    Earth         8000      17.89

The size of the separation manoeuvres can be altered by changing `SKEEP_FACTOR`.

### Global variable reference

#### `SKEEP_VESSELS`

This is used to store a list of nearby vessels (with `2.5`km).

#### `SKEEP_FACTOR`

This is used as a multiplication factor when calculating how large a burn to make to achieve separation.

The initial value is `1`.

### Function reference

#### `listNearbyVessels(universal_timestamp)`

This function clears out the current contents of `SKEEP_VESSELS` and replaces it with a list of all non-landed vessels within `2.5`km of the active vessel at the `universal_timestamp`.

The function returns the number of vessels found, i.e. `SKEEP_VESSELS:LENGTH`.

#### `sepTime()`

This steps forward in time through the active vessel's current orbit until either:
* there are no vessels predicted to be within `2.5`km i.e. `listNearbyVessels()` returns `0` or
* an entire orbit has been processed, if the orbit is elliptical or
* the time is now beyond the expected transition to the next sphere of influence, if the orbit is hyperbolic.

The steps are one minute in length.

If a universal timestamp was found when no vessels are predicted to be within physics range, that time is returned. Otherwise, the function will return `0`.

#### `minSepAngle(distance)`

This function returns the minimum angle between the position vector to each nearby vessel and the proposed burn vector, based on the `distance` between the vessels.

The angle is high for nearby vessels (`45` degrees for anything within `100`m) and steps down to `30` then `15` degrees as the `distance` increases.

#### `sepBurnOK(burn_vector, burn_delta-v, universal_timestamp)`

This function checks whether a proposed burn (of `burn_delta-v` in the direction given by `burn_vector`, at the `universal_timestamp`) would be within the minimum angle requirements or not.

This calls `minSepAngle` for each vessel in `SKEEP_VESSELS` and compares this to the calculated position angle. 

Note that the position angle is calculated using `VANG(burn_vector, position_vector_at_timestamp)`, which can only return an angle between `0` and `180`. Usually we would do further checking to see if the angle is over `180` degrees, but in this case that is not necessary. We want to keep the craft from accelerating towards another vessel, but we also want to avoid firing the engines towards them.

It returns `FALSE` if the calculated position angle is less than `minSepAngle()` for *any* vessel, otherwise returns `TRUE`.

#### `sepBurn()`

This function will try to peform a small separation burn.

It tries up to three different nodes if necessary, checking each with `sepBurnOK()` until it finds one that is angled away from nearby craft. The three burns are:
* pure normal burn. This should not have a noticeable effect on the orbital velocity.
* burn midway between prograde and normal. This will increase orbital velocity slightly.
* burn midway between prograde and anti-normal. This will also increase orbital velocity slightly.
We don't check pure anti-normal as the vector angle between it and the nearby vessels will be the same as for the pure normal burn (see the note about `VANG()` under `sepBurnOK()`). We don't try any retrograde or radial in/out burns as we are quite likely to be in a low orbit and do not want to lower the periapsis any further.

The function returns `TRUE` if it was able to plot and execute a burn, `FALSE` if the burn failed, or if a node could not be plotted.

#### `doSeparation()`

This is the main function. It checks whether the active vessel will end up out of physics range of all nearby vessels during its orbit, and if not tries to perform a small separation manoeuvre to make this happen. It will then timewarp until the point where no vessels are nearby.

First, it calls `sepTime()` to check if the vessel will eventually achieve separation during this orbit or not. This prevents a separation burn from taking place if it was not necessary. If the vessel's current orbit does not separate from other vessels, `sepBurn()` is called to try to force it to separate.

Secondly, if there is now a time when the vessel is out of physics range of all other vessels, the function will time warp forwards to that time.

The function will return `TRUE` if it successfully achieved separation, `FALSE` otherwise.

Geoff Banks / ElWanderer
