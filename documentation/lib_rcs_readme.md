## lib\_rcs (RCS library)

### Description

This library provides functions for translating via RCS, and for turning RCS on/off.

The main function is `doTranslation()`, which uses logic based on a [Cheers Kevin tutorial](https://github.com/gisikw/ksprogramming/tree/master/episodes/e022) to convert an input vector into individual fore/starboard/top translation controls.

### Global variable reference

#### `RCS_MAX_THROT`

This stores the maximum RCS 'throttle'. More accurately, it sets the maximum value that can be passed into the translation controls, such as `SHIP:CONTROL:FORE`. If a craft wobbles around too much when using the RCS thrusters, lowering this value may help.

It should be a value between `0` and `1`, and larger than `RCS_MIN_THROT`.

The initial value is `1`.

#### `RCS_MIN_THROT`

This stores the minimum RCS 'throttle'. More accurately, it sets the minimum value that can be passed into the translation controls, such as `SHIP:CONTROL:FORE`. If a craft is relatively heavy for the number of RCS thrusters provided, it may help to increase this number.

It should be a value between `0` and `1`, and smaller than `RCS_MAX_THROT`.

The initial value is `0`.

#### `RCS_DEADBAND`

This stores the minimum RCS vector magnitude. The desired translation/RCS vector must have a magnitude greater than this value or else no translation will occur. This can be used to prevent the RCS thrusters from firing continuously to correct very small velocity differences.

The initial value is `0`.

### Function reference

#### `changeRCSParams(max_throt, min_throt, deadband)`

This function can be used to change `RCS_MAX_THROT`, `RCS_MIN_THROT` and `RCS_DEADBAND`. See above for descriptions of these values.

If not specified, the default values are `1`, `0` and `0` respectively.

#### `stopTranslation()`

This function stops any current translation by setting all three translation controls (`SHIP:CONTROL:FORE`, `SHIP:CONTROL:STARBOARD` and `SHIP:CONTROL:TOP`) to `0`.

#### `toggleRCS(RCS_on)`

This function sets the value of `RCS` based on the input `RCS_on`. This can take the value `TRUE` or `FALSE`. If not specified, the default value of `RCS_on` is the inverse of the current value of `RCS`.

This means that:
* `toggleRCS(TRUE)` will turn the RCS on, similar in effect to `RCS ON`.
* `toggleRCS(FALSE)` will turn the RCS off, similar in effect to `RCS OFF`.
* `toggleRCS()` will toggle the RCS, turning it off if it is currently on, or turning it on if it is currently off.

The function also calls `stopTranslation()` to disable translation while the toggling is taking place.

#### `doTranslation(translation_vector, translation_magnitude)`

This function sets the translation controls according to the input `translation_vector` and `translation_magnitude`. Though the second of these inputs can be determined from the first, they are available as separate parameters so that direction and magnitude can be specified independently.

This part of the code is based heavily on [Cheers Kevin's Kerbal Space Programming episode 22](https://github.com/gisikw/ksprogramming/tree/master/episodes/e022):

    SET SHIP:CONTROL:FORE TO VDOT(translation_vector,FACING:FOREVECTOR).
    SET SHIP:CONTROL:STARBOARD TO VDOT(translation_vector,FACING:STARVECTOR).
    SET SHIP:CONTROL:TOP TO VDOT(translation_vector,FACING:TOPVECTOR).

By using `VDOT()` we can easily calculate how much of the desired RCS/translation vector is aligned forwards, starboard and upwards relative to the craft's facing. The results can be fed directly into the translation controls as long as we take care to output values within a valid range (`-1` to `1`). To achieve this, the inputs to `VDOT()` must be no greater than `1` in magnitude. The `FACING` vectors are of size `1` naturally, but we have to ensure that the translation vector is not too large. This is done by forcing the 'throttle' to be between `-1` and `1`, then setting mangitude of the translation vector to this value:

    LOCAL rcs_throt IS MIN(RCS_MAX_THROT,MAX(RCS_MIN_THROT,ABS(translation_magnitude))).
    IF translation_magnitude < 0 { SET rcs_throt TO -rcs_throt. }
    SET translation_vector TO translation_vector:NORMALIZED * rcs_throt.

If the magnitude of `translation_vector` is not greater than `RCS_DEADBAND` or if the input `translation_magnitude` is `0`, the desired translation is `0`. Rather than calculating this, `stopTranslation()` is called to zero the control inputs.

If not specified, the value of `translation_magnitude` is defaulted to the magnitude of the input `translation_vector` i.e. `translation_vector:MAG`.

Geoff Banks / ElWanderer
