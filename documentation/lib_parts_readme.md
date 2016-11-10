## lib_parts (part-handling library)

### Description

This is currently a short library with helper functions for checking and triggering event modules, and for decoupling parts.

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

#### `decouplePart(part)`

This function decouples the input `part`, if necessary by recursing upwards through the part tree until a decoupler (which could be a docking port) is found.

To save space, the logic has been compressed. Here's a slightly better-looking version:

    IF NOT (
        partEvent("decouple node","ModuleDockingNode",      part)
     OR partEvent("decouple",     "ModuleDecouple",         part)
     OR partEvent("decouple",     "ModuleAnchoredDecoupler",part)
    ) AND part:HASPARENT {
      decouplePart(part:PARENT).
    }

As kOS allows expression short-cutting, parts of the `IF` statement will stop being evaluated once the result is clear. We try each of the listed part events in turn and if one is found and triggered, `partEvent()` will return `TRUE`, so the first part of the expression will evaluate to `FALSE`, breaking out of the `IF` statement completely. If none of the listed part events are found, the first part of the expression will evaluate to `TRUE`. In that case, if the part has a parent we will call this function on that parent. This way, we recurse up through the parent of each parent until we find a part that is a decoupler, docking port etc.

The root part has no parent. If we cannot find a decoupler, the function will end up at the root part, find it can traverse no further and exit cleanly (but silently).

#### `decoupleByTag(tag)`

Loops through all the parts tagged `tag` and passes them into a call to `decouplePart()`.

Geoff Banks / ElWanderer
