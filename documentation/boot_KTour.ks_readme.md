# KTour.ks

## Kerbin Tourist boot script.

The purpose of this boot script is to launch a tourist craft into Low Kerbin Orbit, then re-enter and land near the launch site. The script has been written for Apollo-style craft i.e. a command module with a heat shield (I tend to set the ablator to about 20%), plus a service module consisting of fuel tanks and engines.

### Disk space requirement

40000 bytes (actual use is about 36k at the time of writing).

### Libraries used

* `lib_launch_common.ks`
* `lib_launch_crew.ks`
* `lib_burn.ks`
* `lib_node.ks`
* `lib_dv.ks`
* `lib_steer.ks`
* `lib_runmode.ks`
* `lib_orbit.ks`
* `lib_parts.ks`
* `lib_chutes.ks`
* `lib_reentry.ks`

### Script Parameters

There are no adjustable parameters.

### Script Steps

#### Initialisation

All libraries are loaded onto the local hard drive(s).

#### Launch

Launch is to a standard, equatorial `85`km by `85`km Low Kerbin Orbit.

#### Re-entry and landing

A manoeuvre node is plotted and executed that will put the periapsis below 30km, to the East of the Kerbal Space Center. Some rough calculations plus some testing were enough to determine where to plot this burn for a typical command module & heat shield combination, such that the capsule will land in the sea to the East of the KSC.

The script is programmed to perform one staging action following the re-entry burn, to detach the service module (i.e. the fuel tank and engine). If any parts are tagged `FINAL`, further staging actions will take place until these have been detached. The craft will hold retrograde during initial re-entry, then disengage steering to conserve battery power. It is assumed that the re-entry craft will be aerodynamically stable and maintain a retrograde orientation naturally. The parachutes will be triggered once safe.

Note - with the changes expected in v1.2 (such as the changes to the atmosphere and the ability to stage parachutes with an automatic delay in opening them until they are safe) some of the re-entry procedure may want/need changing. 

Geoff Banks / ElWanderer
