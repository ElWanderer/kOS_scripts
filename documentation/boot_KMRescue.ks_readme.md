# KMRescue.ks

## Kerbin Moon Rescue boot script.

The purpose of this boot script is to launch a craft into Low Kerbin Orbit, transfer to either Mun or Minmus and once there rendezvous with and rescue Kerbals stuck in orbit. Then the craft will return to Kerbin, re-enter and land. The script has been written for Apollo-style craft i.e. a command module with a heat shield (I tend to set the ablator to about 50%), plus a service module consisting of fuel tanks and engines.

A multi-seat craft can be used to rescue multiple Kerbals from different targets around the same moon within a single mission.

### Disk space requirement

80000 bytes, though it is very close to requiring more (actual use is about 79k at the time of writing).

### Libraries used

* `lib_launch_geo.ks`
* `lib_launch_common.ks`
* `lib_launch_crew.ks`
* `lib_burn.ks`
* `lib_node.ks`
* `lib_dv.ks`
* `lib_steer.ks`
* `lib_runmode.ks`
* `lib_orbit.ks`
* `lib_orbit_change.ks`
* `lib_orbit_match.ks`
* `lib_orbit_phase.ks`
* `lib_parts.ks`
* `lib_chutes.ks`
* `lib_crew.ks`
* `lib_ca.ks`
* `lib_rendezvous.ks`
* `lib_transfer.ks`
* `lib_hoh.ks`
* `lib_reentry.ks`
* `lib_geo.ks`
* `lib_skeep.ks`

### Script Parameters

There are no adjustable parameters. Target selection is performed interactively in-game.

### Script Steps

#### Initialisation

All libraries are loaded onto the local hard drive(s).

On first boot, the script willl check that the craft actually has at least one spare seat. If all the seats are occupied, it'll throw an error then exit, with the expectation that you recover/revert and launch again with fewer/no crew members.

Assuming there are empty seats, the number of crew aboard is stored on disk so that this information will survive a reboot.

#### Wait for target selection

The craft will wait on the launch pad until a valid target has been selected. Valid in this case means it must be orbiting a body whose parent body is the same body as the craft is launching from (i.e. the target must be in orbit of Mun or Minmus) and must have a non-zero crew count.

#### Launch

Launch is to a standard `85`km by `85`km Low Kerbin Orbit, with the inclination matching (as near as possible) that of the destination body.

#### Match orbit inclination

The script will plot and execute a burn to reduce the relative inclination between the current orbit and the target body to zero. If the launch azimuth and time were calculated correctly, this should be a very small burn. Matching inclination precisely may not be necessary, but during early testing it made the next step much easier.

#### Transfer

The script will calculate a Hohmann transfer to the target body. Chances are that when plotted as a manoeuvre node, this will not actually reach the target, but the node improvement code will take over and adjust the node until the predicted periapsis matches the target's apoapsis as best as possible.

This node will then be executed, and followed up (if necessary) with correction burns until the craft's trajectory reaches the target body, with a periapsis within a reasonable distance of the target apoapsis. What is considered 'reasonable' varies depending on whether the target apoapsis is close to the surface or not.

The script will then time warp to the sphere of influence transition with the target body, with the aim of passing through the transition at 50x warp.

Once in the sphere of influence of the target body, further correction burns can be plotted and executed if they improve the final orbit towards the target parameters. Finally, a node will be plotted at the periapsis and executed to insert into orbit.

Note - the target inclination and longitude of the ascending node are taken into account during the node improvement process that is run on each manoeuvre node. Recent changes have improved the node improvement process, but there is still no guarantee that it will get close to the target values. The final inclination at the target is hard to adjust unless close to the plane of the equator of the body (which may not happen until close to the periapsis when trying to get to Minmus) and the longtiude of the ascending node is largely determined by the launch time and travel time. As such, it's best to assume that the craft will need to perform an inclination burn from an equatorial orbit to the target incilnation and budget delta-v accordingly (worst cases are about 700m/s for a 90 degree change around the Mun, or 150m/s if around Minmus). Further changes are needed to be able to time a transfer to arrive (cheaply) aligned with the target inclination and longitude of the ascending node.

#### Rendezvous

Once in orbit of the destination moon, the validity of the target will be rechecked. It is possible for the target selection to be changed during the launch and transfer steps.

If the target is no longer valid, the craft will wait in orbit until either:
 * a valid target is selected, in which case rendezvous will proceed
 * the `ABORT` button is pressed, in which case the script will jump ahead to a return transfer (followed by re-entry and landing).
 
Rendezvous currently takes place by a multiple-step process, starting with a plane change to match the target's inclination, a burn to ensure the orbits touch or cross if they don't already then a phasing burn at the intersection so that the two craft will be close together within a number of orbits.

As closest approach draws near, the script will try to keep the relative velocity pointing in the general direction of the target, decelerating as the separation distance comes down. The rendezvous library defaults to a target separation of 75m, but this script reduces that to `25`m (as rescues tend to involve small craft and EVAing Kerbals, rather than large craft/stations and docking). For safety, the aim point is always offset from the target. 

Once close to the aim point, the craft will try to reduce the relative velocity below `0.15`m/s. This currently assumes you don't have RCS (common for early-career rescues), which makes this part of the script fairly imprecise as:
 * firing the main engine in the opposite direction of the relative velocity vector requires rotating the craft, which can in turn affect the relative velocity. It is hoped that recent KSP improvements should mean this is less of an issue.
 * the script does not wait for the craft to be as well-aligned with the desired burn vector as it does for manoeuvre node burns, as the desired burn vector is expected to be moving around more.
 * even firing the main engine at 5% throttle for a single physics tick may produce too much thrust to change the velocity by the amount required.

This close approach has two outcomes:
 * On reducing the relative velocity with the target below `0.15`m/s, the script will jump to the next step, waiting to be boarded.
 * If there is not enough delta-v on the craft than the relative velocity with the target, it will cut the throttle and go into an error state.

#### Waiting to be boarded

The craft will steer to the Normal heading in the hope that this will make it easier for an EVAing Kerbal to reach the hatch.

It will wait for the number of crew aboard the craft to go above the stored value. The number must go up for the next step to activate - the aim is to avoid the craft trying to leave with crew still outside.

#### Boarding and separation

Once the rescued Kerbal is aboard, the script will store the new number of crew then plot and execute a small separation burn to move away from the target craft.

The script has two choices following this burn:
 * if the craft is full, the script will proceed automatically to a return transfer (followed by re-entry and landing).
 * if the craft has empty seats remaining, it will switch back to the rendezvous step. That is, it will wait for either a new, valid target to be selected (the old target should now be empty, making it invalid) or for the `ABORT` button to trigger a return.

#### Return transfer

The script will calculate a Hohmann transfer back to Kerbin, targetting a periapsis of `30`km. The node improvement code will take over and adjust the node so that the periapsis is as close as possible to this value.

This node will then be executed, and followed up (if necessary) with correction burns until the craft's trajectory has a periapsis that is close to the target.

The script will then time warp to the sphere of influence transition back to Kerbin, with the aim of passing through the transition at 50x warp.

Once in the sphere of influence of the target body, further correction burns can be plotted and executed to try to get the periapsis as accurate as possible.

Once this has been achieved, the script will time warp until the craft is close to re-entry.

#### Re-entry and landing

The script is programmed to perform one staging action following the re-entry burn, to detach the service module (i.e. the fuel tank and engine). If any parts are tagged `FINAL`, further staging actions will take place until these have been detached. The craft will hold retrograde during initial re-entry, then disengage steering to conserve battery power. It is assumed that the re-entry craft will be aerodynamically stable and maintain a retrograde orientation naturally. The parachutes will be triggered once safe.

Note - with the changes expected in v1.2 (such as the changes to the atmosphere and the ability to stage parachutes with an automatic delay in opening them until they are safe) some of the re-entry procedure may want/need changing. 

#### Failure cases

If the script gets stuck, it may revert to an error state. Hitting `ABORT` will cause it to retry the last step that failed. For example, if the craft detaches from the launcher in Low Kerbin Orbit, the craft's own propulsion needs to be enabled for the rendezvous manoeuvres. If the staging set-up does not activate an engine, the craft will go into the error state. Staging or enabling the engine manually, then hitting `ABORT` should allow the script to carry on.

Geoff Banks / ElWanderer
