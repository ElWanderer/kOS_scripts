## lib\_lander\_common (common functions for non-atmospheric landings and ascents)

### Description

Text giving general, useful description

### Global variable reference

#### `LND_THROTTLE`

This is used to store the throttle value as calculated by the lander code. The `THROTTLE` is locked to this value during ascent and descent.

The initial value is `0`.

#### `LND_G_ACC`

This is used to store the current acceleration due to gravity.

The initial value is `0`, but this is locked to the calculation `BODY:MU / (BODY:RADIUS+ALTITUDE)^2` on calling `initLanderValues()`.

#### `LND_MIN_VS`

This is used to store the current minimum vertical speed that the lander must achieve in order to avoid nearby terrain, both during ascent and during descent.

The initial value is `0`, but this will be set to a new value on initiating a descent or an ascent, and is recalculated at regular intervals therafter.

#### `landerHeartBeat()`

A function delegate. This returns the time elapsed since `TIMES["LND"]`. To ensure this exists, `setTime("LND")` is called on initialising the library.

#### `landerResetTimer()`

A function delegate. This resets the `TIMES["LND"]` global variable to be the current time.

### Function reference

#### `landerSetMinVSpeed(vertical_speed)`

This function sets the value of `LND_MIN_VS` to be the input `vertical_speed`. If the value has changed, the new value is printed out to the terminal.

#### `landerMinVSpeed()`

Returns `LND_MIN_VS`.

#### `gravAcc()`

Returns `LND_G_ACC`.

#### `landerPitch()`

This function calculates and returns the pitch angle (where `90` is straight up and `0` is horizontal) that the lander should aim at in order to control the rate of ascent/descent.

First we must consider the centripetal (or is it centrifugal?!) acceleration, given by `v_x^2 / r`. This is an area where I'm not sure of the exact terminology to use. In a circular orbit (or at the apsis of a non-circular orbit), the vertical speed (the rate of change of the orbital radius) is zero. This is usually described in terms of "we are travelling sideways fast enough that the force of gravity curves our trajectory into a circle". Our trajectory is curving so our velocity is constantly changing, due to the acceleration down to gravity. But in this case it matches the centripetal acceleration, so there is no change in vertical speed.

If we burn retrograde, our orbital velocity will reduce and so the centripetal acceleration will not match the acceleration due to gravity. This will result in a downwards acceleration and our vertical speed will start to rise. Typically, we want to keep the vertical speed at a low value, so we must make up the difference between the centripetal acceleration and the acceleration due to gravity with a burn from our engine. To cut a long story short, we have to pitch up (burning partly towards the planet) to maintain our vertical speed.

    // Horizontal velocity (squared)
    LOCAL v_x2 IS VXCL(UP:VECTOR,VELOCITY:ORBIT):SQRMAGNITUDE.
    
    // Calculate 'centripetal acceleration' from v_x^2 / r
    LOCAL cent_acc IS v_x2 / (BODY:RADIUS + ALTITUDE).
    
    // We must accelerate upwards to make-up the difference in acceleration due to gravity
    // and `centripetal acceleration`. However, we must also consider the difference between
    // our current vertical speed and the minimum vertical speed (LND_MIN_VS).
    // This does confuse acceleration and speed in a single calculation, but this is not
    // normally a problem in practice.
    LOCAL ship_acc IS LND_G_ACC - cent_acc + (LND_MIN_VS - SHIP:VERTICALSPEED).
    
    // Calculate what proportion of the ship's available thrust needs to point downwards
    LOCAL acc_ratio IS ship_acc * MASS / SHIP:AVAILABLETHRUST.
    
    // If we are travelling upwards at a higher speed than the minimum, the calculation
    // will return a negative desired acceleration. Rather than waste thrust pointing
    // downwards, this caps the lowest pitch angle at `0`.
    IF acc_ratio < 0 { SET p_ang TO 0. }
    // 
    ELSE IF acc_ratio < 1 { SET p_ang TO ARCSIN(acc_ratio). }

The function returns `90` (straight up) in the event of being unable to perform the calculation e.g. because the available thrust is `0` or if the required upwards thrust is greater than the craft can provide.

#### `terrainAltAtTime(universal_timestamp)`

Description.

#### `stepTerrainVS(init_min_vs, start_time, look_ahead, step)`

Description.

#### `findMinVSpeed(init_min_vs, look_ahead, step)`

Description.

#### `initLanderValues()`

This function sets-up `LND_G_ACC`, by calling `LOCK LND_G_ACC TO BODY:MU / (BODY:RADIUS+ALTITUDE)^2`. It also calls `landerResetTimer()` to reset the timer.

`LND_G_ACC` is deliberately locked here and then unlocked in `stopLanderValues()` as it is only relevant during ascent and descent, and to avoid it being recalculated for other bodies. However, this may be an unecessary protection, as locked globals are only re-evaluated when they are used, not every tick (as is done for `STEERING` or `THROTTLE` locks).

#### `stopLanderValues()`

This function unlocks `LND_G_ACC`, so that it does not keep being recalculated. See the `initLanderValues()` comment above for why this may not actually be needed.

Geoff Banks / ElWanderer
