## lib\_launch\_common (common launch library)

### Description

This library contains common functions used by the two launch libraries, `lib_launch_crew.ks` and `lib_launch_nocrew.ks`.

Text

### Requirements

 * `lib_burn.ks`
 * `lib_runmode.ks`

### Global variable reference

#### `LCH_MAX_THRUST`

Text

Initialised as `0`.

#### `LCH_ORBIT_VEL`

Text.

Initialised as `0`.

#### `LCH_VEC`

Text.

Initialised as `UP:VECTOR`.

#### `LCH_I`

Text.

Initialised as `0`.

#### `LCH_AN`

Text.

Initialised as `TRUE`.

#### `LCH_PITCH_ALT`

Text.

The default value is `250`.

#### `LCH_CURVE_ALT`

Text.

The default value is 90% of the atmosphere height (`63`km on Kerbin).

#### `LCH_FAIRING_ALT`

Text.

The default value is 60% of the atmosphere height (`42`km on Kerbin).

#### `LCH_HAS_LES`

Text.

Initialised as `FALSE`.

#### `LCH_HAS_FAIRING`

Text.

Initialised as `FALSE`.

### Function reference

#### `killThrot()`

Text

#### `mThrust(new_value)`

Text

#### `hasFairing()`

Returns the value of `LCH_HAS_FAIRING`.

#### `hasLES()`

Returns the value of `LCH_HAS_LES`.

#### `disableLES()`

Text

#### `checkFairing()`

Text

#### `checkLES()`

Text

#### `launchInit(exit_mode, ap, az, i, pitch_alt)`

Text

#### `launchStaging()`

Text

#### `launchFairing()`

Text

#### `sepLauncher()`

Text

#### `launchCirc()`

Text

#### `launchBearing()`

Text

#### `launchPitch()`

Text

#### `launchMaxSteer()`

Text

#### `launchSteerUpdate()`

Text

#### `steerLaunch()`

Locks the steering to the launch vector, by forming an anonymous function that returns `LCH_VEC` and passing this into `steerTo()`.

Geoff Banks / ElWanderer
