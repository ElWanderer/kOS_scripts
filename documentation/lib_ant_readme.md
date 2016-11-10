## lib\_ant (antennae library)

### Description

Functions for dealing with antennae.

There is currently one main function intended to be called by boot/mission scripts: `extendAllAntennae()`. This will extend all antennae. This may be extended in future, in particular when it comes to implementing CommNet in KSP v1.2.

### Requirements

* `lib_parts.ks`

### Global variable reference

#### `ANT_TX_MOD`

This stores the KSP module name for a transmitter: `ModuleDataTransmitter`.

#### `ANT_ANIM_MOD`

This stores the KSP module name for a part that can animate: `"ModuleAnimateGeneric"`.

In KSP 1.1.3, all antennae must extend in order to send science data, so all transmitters have this module. From KSP v1.2, there is at least one antennae that doesn't extend/retract, so it probably won't have this module.

#### `antCommStatus`

Function delegate. The `partModField(field,module,part)` function this is based on is defined in lib_parts.ks. 

This delegate returns the contents of the `ANT_TX_MOD` module field `Comm`, if this exists. Otherwise it will return `-`.

#### `antAnimStatus`

Function delegate. The `partModField(field,module,part)` function this is based on is defined in lib_parts.ks. 

This delegate returns the contents of the `ANT_ANIM_MOD` module field `Status`, if this exists. Otherwise it will return `-`.

#### `antExtend`

Function delegate. The `partEvent(event,module,part)` function this is based on is defined in lib_parts.ks.

This delegate will try to trigger the "Extend" event for the input `part`, returning `TRUE` if the event was fired and `FALSE` if it was not.

#### `antRetract`

Function delegate. The `partEvent(event,module,part)` function this is based on is defined in lib_parts.ks.

This delegate will try to trigger the "Retract" event for the input `part`, returning `TRUE` if the event was fired and `FALSE` if it was not.

### Function reference

#### `waitUntilIdle(part)`

This function waits until the input transmitter `part` is idle.

This is defined as the `Comm` field containing the string `Idle` and the `Status` field not containing the string `Moving...`.

Note - if the part does not have the `Comm` field, this will loop indefinitely.

#### `antToggle(part)`

This function will trigger either the `Extend` or `Retract` events on the input `part`. If neither event is available for `part`, nothing will happen.

Returns `TRUE` if either event was fired, `FALSE` otherwise.

#### `doAllAnt(function_list)`

This function takes a list of functions and applies each one in turn to each antenna part.

The function loops through all antennae, identified as parts containing the `ANT_TX_MOD` module.

#### `extendAllAntennae()`

This function extends all extendable antennae on the active vessel. It does this by constructing a list of functions and passing them into `doAllAnt()`.

For each antennae, the function list requires the antennae to be idle before extending and prior to returning.

Geoff Banks / ElWanderer
