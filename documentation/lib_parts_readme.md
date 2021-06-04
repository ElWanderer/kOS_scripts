## lib_parts (part-handling library)

### Description

This is currently a short library with helper functions for checking and triggering event modules, and for decoupling parts.

### Global variable reference

#### `PART_DECOUPLERS`

This is a lexicon that maps known decoupler modules to the event required to trigger them.

This is initialised as:
* "ModuleDockingNode" -> "decouple node"
* "ModuleDecouple" -> "decouple"
* "ModuleAnchoredDecoupler" -> "decouple"

### Function reference

#### `canEvent(event, part_module)`

A wrapper around the kOS `HASEVENT()` part module function.

Returns `TRUE` if `event` is a valid event for the input `part_module`, otherwise returns `FALSE`.

#### `modEvent(event, part_module)`

A wrapper around the kOS `DOEVENT()` part module function.

#### `partEvent(event, module_name, part)`

Checks to see if the input `part` has a module named `module_name` and if so whether that module has the input `event`.

If both these conditions are met, the `event` is triggered on the part module and the function returns `TRUE`. Otherwise the function takes no action and returns `FALSE`.

#### `modField(field_name, part_module)`

A wrapper around the kOS `GETFIELD()` part module function. This checks `HASFIELD()` first and will return `-` if the field does not exist.

#### `partModField(field_name, module_name, part)`

Checks to see if the input `part` has a module named `module_name` and if so calls `modField()`.

This function returns the contents of the module field if it exists, otherwise returns `-`.

#### `isDecoupler(part)`

This function loops through all the modules of the input `part` and checks if any of them match the decoupler modules stored in `PART_DECOUPLERS`. That includes decouplers and docking ports.

Returns `TRUE` if the part has a decoupler module, `FALSE` otherwise.

#### `decouplePart(part, towards_root)`

This function decouples the input `part`, if necessary by recursing upwards (and/or downwards) through the part tree until a decoupler is found.

If `part` is a decoupler (i.e. `isDecoupler(part)` returns `TRUE`), the appropriate decouple event (as stored in `PART_DECOUPLERS`) is fired and the function exits.

If `part` is not a decoupler, the function will continue to recurse through the parts tree:
* If `towards_root` is `TRUE`, the function will try to recurse upwards by calling `decoupleRoot()` on the `PARENT` of `part`. If `part` has no parent (i.e. it is the root part), then it will instead call itself with the same `part`, but setting `towards_root` to `FALSE`. This will cause the recursion to go down the parts tree.
* If `towards_root` is `FALSE`, the function will recurse downards by calling `decoupleRoot()` on each child part of `part`. This can potentially result in multiple decouplers being found and activated.

#### `decoupleByTag(tag)`

Loops through all the parts tagged `tag` and passes them into a call to `decouplePart()`.

Geoff Banks / ElWanderer
