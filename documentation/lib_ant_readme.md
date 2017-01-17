## lib\_ant (antennae library)

### Description

Functions for dealing with antennae.

There are currently two main functions intended to be called by boot/mission scripts: `extendAllAntennae()` and `retractAllAntennae()`.

### Requirements

* `lib_parts.ks`

### Global variable reference

#### `ANT_TX_MOD`

This stores the KSP module name for a transmitter: `ModuleDataTransmitter`.

#### `ANT_ANIM_MOD`

This stores the KSP module name (as of KSP v1.2) for a transmitter that can animate: `"ModuleDeployableAntenna"`.

In KSP 1.1.3, all antennae were animated and used a generic animation module.

#### `antCommStatus`

Function delegate. The `partModField(field,module,part)` function this is based on is defined in `lib_parts.ks`. 

This delegate returns the contents of the `ANT_TX_MOD` module field `Antenna State`, if this exists. Otherwise it will return `-`.

Note: in earlier versions of KSP, the module field was called `Comm`.

#### `antAnimStatus`

Function delegate. The `partModField(field,module,part)` function this is based on is defined in `lib_parts.ks`. 

This delegate returns the contents of the `ANT_ANIM_MOD` module field `Status`, if this exists. Otherwise it will return `-`.

#### `antExtend`

Function delegate. The `partEvent(event,module,part)` function this is based on is defined in `lib_parts.ks`.

This delegate will try to trigger the `Extend Antenna` event for the input `part`, returning `TRUE` if the event was fired and `FALSE` if it was not.

Note: in earlier versions of KSP, the event was called `Extend`.

#### `antRetract`

Function delegate. The `partEvent(event,module,part)` function this is based on is defined in `lib_parts.ks`.

This delegate will try to trigger the `Retract Antenna` event for the input `part`, returning `TRUE` if the event was fired and `FALSE` if it was not.

Note: in earlier versions of KSP, the event was called `Retract`.

### Function reference

#### `antIdle(part)`

This function waits until the input transmitter `part` is idle.

This is defined as the `Antenna State` field containing the string `Idle` and the `Status` field being either `Retracted` or `Extended`.

Note - this will loop indefinitely if the modules and their fields are different to expected.

#### `doAllAnt(function_list)`

This function takes a list of functions and applies each one in turn to each antenna part.

The function loops through all antennae, identified as parts containing the `ANT_TX_MOD` module.

#### `extendAllAntennae()`

This function extends all extendable antennae on the active vessel. It does this by constructing a list of functions and passing them into `doAllAnt()`.

For each antennae, the function list requires the antennae to be idle before extending and prior to returning. This is relatively slow, but ensures the antennae are ready prior to transmitting science (for example).

#### `retractAllAntennae()`

This function retracts all extendable antennae on the active vessel. It does this by constructing a list of functions and passing them into `doAllAnt()`.

For each antennae, the function list requires the antennae to be idle before retracting and prior to returning. This is relatively slow, but ensures all antennae will be retracted prior to doing something else.

Geoff Banks / ElWanderer
