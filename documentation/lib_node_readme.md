## lib\_node (basic manoeuvre node handling library)

### Description

Text giving general, useful description

### Global variable reference

#### `NODE_BUFF`

This is typically used as a minimum time in the future that a manoeuvre node can be created.

Has an initial value of `60` seconds, though this can be changed by calling `nodeBuffer(new_value)`.

### Function reference

#### `nodeBuffer(new_value)`

If the new value is greater than 0, it is used to set `NODE_BUFF`.

Returns the value of `NODE_BUFF`.

#### `bufferTime(universal_timestamp)`

This function is used to generate a new timestamp from the input `universal_timestamp`, by adding a buffer period.

If not provided, the default value for `universal_timestamp` is `TIME:SECONDS` i.e. the current time.

Returns the sum of the `universal_timestamp` and `NODE_BUFF`.

#### `removeAllNodes()`

Removes all nodes from the flightpath.

#### `nodeDV(node)`

Returns the delta-v requirement for the input `node`. 

Note - you can only call `:DELTAV:MAG` on a node that is on flightpath. Instead, this function calculates it (via Pythagoras) based on the three directions (`RADIALOUT`, `NORMAL` and `PROGRADE`).

#### `pOrbit(orbit)`

Prints out the details of an orbit patch.

The function is recursive - if the orbit patch leads to another (i.e. there is a predicted change of sphere of influence), this is passed into another call to `pOrbit()`.

Note - the number of patches displayed depends on the behaviour of kOS and KSP. There may be further patches that are not shown because the in-game draw limit is set to three patches, for example.

#### `addNode(node)`

Adds the input `node` to the flightpath.

The function then prints out the details of the node, and calls `pOrbit()`, passing in the orbit patch that would result from executing the node perfectly.

Geoff Banks / ElWanderer
