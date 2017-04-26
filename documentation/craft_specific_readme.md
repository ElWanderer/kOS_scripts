## Craft-specific files

We have the capability of running a ship-specific script. This uses the ship's name to determine which file to try loading, but note that it looks for this in the `craft` sub-directory of `/Ships/scripts`. If this exists, it is copied to `"1:/craft.ks"` and run. On subsequent boots, we check first to see if we already have a craft-specific file and if so go straight to running it.

The craft file can be used to run any code during boot-up, but one thing that is explicitly supported is adding key/value pairs to the `CRAFT_SPECIFIC` lexicon that can be checked and evaluated later on. Supported key/value pairs for this lexicon are described below.

### `CRAFT_SPECIFIC` lexicon - supported keys and their values

#### `LCH_RCS_ON_ALT` - `altitude`

This should contain a numeric value, representing the altitude at which RCS will be enabled automatically during launch.

#### `LCH_RCS_OFF_ALT` - `altitude`

This should contain a numeric value, representing the altitude at which RCS will be disabled automatically during launch.

#### `LCH_RCS_OFF_IN_ORBIT` - `n/a`

If the key exists, the RCS will be turned off following a successful insertion into orbit (following the separation from the launcher). The actual value taken by this key is immaterial.

Geoff Banks / ElWanderer
