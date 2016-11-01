## lib_chute (parachute library)

### Description

Functions for deploying parachutes safely and automatically. Parachutes are not triggered until safe to do so and there is a helper function for disarming parachutes that may have been triggered early e.g. through a staging mishap.

Note on terminology - KSP seems to mix up terms, using "deploy" and "disarm" to describe staging/triggering and untriggering a parachute. Really, this should be called "arm" and "disarm", so that the term "deploy" is reserved for what happens when an armed parachute meets the deployment conditions and pops out of its box!

### Requirements

* `lib_parts.ks`

### Global variable reference

#### `CHUTE_LIST`

This gets populated by a list of parachute modules on running the library, so that we can cycle through them. It should be regenerated following each parachute action.

Note - we store modules rather than parts so that it is quicker to trigger the module's events.

#### `canDeploy` and `canDisarm`

Function delegates. The `canEvent(event,module)` function these are based on is defined in `lib_parts.ks`, and checks whether a given event ("Deploy chute" or "Disarm") can be triggered for the input module.

#### `doDeploy` and `doDisarm`

Function delegates. The `modEvent(event,module)` function these are based on is defined in `lib_parts.ks`, and triggers the relevant event ("Deploy chute" or "Disarm") for the input module.

### Function reference

#### `safeToDeploy(parachute_module)`

This returns whether the "Safe To Deploy?" indicator is displaying "Safe" or not.

The "Safe To Deploy?" indicator is a field on the parachute module that appear's on the part's right-click menu. It will display "Unsafe" when the craft's velocity is too high for the given parachute and altitude, then change to "Risky" and finally "Safe" as speed comes down.

This allows `deployChutes()` to wait until each specific parachute is reporting that it is safe to open before triggering it. It seems that in v1.2 KSP, this is now the default behaviour for parachutes, so this may become surplus to requirements.

#### `hasChutes()`

Does the craft have parachutes that we know about?

Returns `TRUE` if `CHUTE_LIST` is non-empty, returns `FALSE` otherwise.

#### `listChutes(all)`

This function populates `CHUTE_LIST` with parachute modules. If a parachute can be deployed, it will always be added to the list. If a parachute cannot be deployed (e.g. because it has already been deployed) it will only be added to the list if the `all` parameter has been set to `TRUE`.

As we cycle through parachute modules, each will be printed out to the terminal, including an indicator as to whether they can be deployed or not.

If not specified, `all` is set to `FALSE`.

#### `deployChutes()`

This function is expected to be called from within a loop. It does not block processing, so it must be called repeatedly until all the parachutes have been deployed.

This function triggers any parachutes that can be safely deployed. This looks at each parachute in `CHUTE_LIST` individually, so if you have a mix of parachute types, only those parachutes that are currently safe will be deployed and the others will be left untouched. This allows a hands-on deployment of a set of drogues and main parachutes, for example.

If any parachutes are deployed by this function, the list of parachutes is rebuilt.

#### `disarmChutes()`

This function is expected to be called once.

This function is for checking that any parachutes haven't accidentally been triggered prematurely and disarming them if necessary i.e. this would be called when approaching re-entry.

`listChutes(TRUE)` is called because we need to list all the chutes, otherwise chutes that have accidentally been triggered won't appear.

Following the check, the list of parachutes is rebuilt to contain just those that can be deployed.

Geoff Banks / ElWanderer
