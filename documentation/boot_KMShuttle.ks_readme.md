# KMShuttle.ks

## Kerbin Moon Crew Shuttle boot script.

The purpose of this boot script is to automate crew transfers between Kerbin and space stations in orbit of Kerbin's moons. It will launch a craft into Low Kerbin Orbit, transfer to either Mun or Minmus and once there rendezvous with and dock with another craft. Once undocked, the craft will return to Kerbin, re-enter and land. The script has been written for Apollo-style craft i.e. a command module with a heat shield (I tend to set the ablator to about 50%), plus a service module consisting of fuel tanks and engines.

Note - this script additionally requires a craft with RCS thrusters and a free docking port to function correctly.

Note 2 - unlike the `KMRescue.ks` script, this has not been programmed to allow multiple rendezvous per mission. It cannot be used to transfer crew between two different space stations. Issue `#67` exists to improve this.

### Disk space requirement

This needs confirming, but the requirement is quite high as this script requires the orbit matching, rendezvous and docking libraries.

### Script Parameters

There is one adjustable parameter, that can be changed by editing the file:

    GLOBAL NEW_NAME IS "Rendezvous Test Docker".

#### `NEW_NAME`

On first boot, the ship will be renamed with this string.

### Script Steps

#### Wait for target selection

The craft will wait on the launch pad until a valid target has been selected. Valid in this case means it must be orbiting a body whose parent body is the same body as the craft is launching from (i.e. the target must be in orbit of Mun or Minmus).

#### Launch

Launch is to a standard `85`km by `85`km Low Kerbin Orbit, with the inclination matching (as near as possible) that of the destination body.

#### Match orbit inclination

Once in orbit, the target is re-checked to ensure it is valid (i.e. in orbit of Mun or Minmus). If the target has been de-selected or changed to something invalid, the script will wait for a valid target to be selected again.

The script will plot and execute a burn to reduce the relative inclination between the current orbit and the target body to zero. If the launch azimuth and time were calculated correctly, this should be a very small burn. Matching inclination precisely may not be necessary, but during early testing it made the next step much easier.

#### Transfer

The target is checked again prior to transfer. If the target has been de-selected or changed to something invalid, the script will wait for a valid target to be selected again.

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

As closest approach draws near, the script will try to keep the relative velocity pointing in the general direction of the target, decelerating as the separation distance comes down. The rendezvous library defaults to a target separation of `75`m, but this script overwrites this with the same value (in case the library ever gets changed). For safety, the aim point is always offset from the target. 

Once close to the aim point, the craft will try to reduce the relative velocity below `0.15`m/s. This currently assumes you don't have RCS (common for early-career rescues), which makes this part of the script fairly imprecise as:
 * firing the main engine in the opposite direction of the relative velocity vector requires rotating the craft, which can in turn affect the relative velocity. It is hoped that recent KSP improvements should mean this is less of an issue.
 * the script does not wait for the craft to be as well-aligned with the desired burn vector as it does for manoeuvre node burns, as the desired burn vector is expected to be moving around more.
 * even firing the main engine at 5% throttle for a single physics tick may produce too much thrust to change the velocity by the amount required.

This close approach has two outcomes:
 * On reducing the relative velocity with the target below `0.15`m/s, the script will jump to the next step, docking.
 * If there is not enough delta-v on the craft than the relative velocity with the target, it will cut the throttle and go into an error state.

#### Docking

The docking library tries to pick an available docking port on the current craft and one on the target craft. The craft will align itself so that the docking port is pointing in the opposite direction to the target port.

Then RCS will be used to translate the craft, maintaining the orientation of the docking port. A flightplan of one, two or even three waypoints is created (if we include the target docking port as the last waypoint). The number depends on whether there are any obstructions to loop around. This is displayed on screen. The docking library has a set of default speeds that the craft will keep to when translating between waypoints. These are currently left unchanged as `1`m/s translation speed, dropping to `0.6`, `0.4` then `0.2`m/s in the final few metres leading up to a waypoint. The final leg is typically from a point `50`m directly in front of the target docking port, to the port itself. Following this should keep the two craft aligned as the docking ports get closer to each other.

When the docking ports acquire each other, there is a change of state when the magnets activate. This is detected and used as a signal to unlock the steering and exit from the docking routine. At this point the script will power down the running CPU. This is intentional, on the assumption that the craft you're docking with also has a kOS CPU running, to avoid the confusion (and possible breaking of kOS's steering manager) of having multiple CPUs trying to control the vessel at the same time.

#### Undocking and separation

Undocking is currently a manual process. As with the finale of docking, this is to avoid known kOS issues regarding multiple CPUs trying to control a single vessel and a craft splitting into two controlled halves during a program (though I am aware fixes have been made in this area recently).

Steps to undock:
* Right-click on the docking port and hit "undock".
* If necessary, switch vessels until you are controlling the right craft.
* Right-click on the kOS processor and toggle its power back on (or use the kOS mod menu).

When the kOS CPU boots up, the script will be in a runmode that does nothing but wait until the `ABORT` key is pressed.

Steps to separate:
* Optional: briefly engage the RCS system and use a few blasts to increase the separation speed away from the other craft.
* Hit `ABORT` to put the script into separation mode. It will try to plot a small burn that will avoid ramming other craft or hitting them with engine exhaust. This may not succeed if the craft are still very close together, in which case you may need to wait longer before hitting `ABORT`, or separate manually.

Following a successful separation manoeuvre, the script will switch to calculating a return transfer.

#### Return transfer

The script will calculate a Hohmann transfer back to Kerbin, targetting a periapsis of `30`km. The node improvement code will take over and adjust the node so that the periapsis is as close as possible to this value.

This node will then be executed, and followed up (if necessary) with correction burns until the craft's trajectory is close to the `30`km target.

The script will then time warp to the sphere of influence transition back to Kerbin, with the aim of passing through the transition at 50x warp.

Once in the sphere of influence of the target body, further correction burns can be plotted and executed to ensure that the periapsis is accurate.

Once this has been achieved, the script will time warp until the craft is close to re-entry.

#### Re-entry and landing

The script is programmed to perform one staging action following the re-entry burn, to detach the service module (i.e. the fuel tank and engine). If any parts are tagged `FINAL`, further staging actions will take place until these have been detached. The craft will hold retrograde during initial re-entry, then disengage steering to conserve battery power. It is assumed that the re-entry craft will be aerodynamically stable and maintain a retrograde orientation naturally. The parachutes will be triggered once safe.

Note - with the changes expected in v1.2 (such as the changes to the atmosphere and the ability to stage parachutes with an automatic delay in opening them until they are safe) some of the re-entry procedure may want/need changing. 

#### Failure cases

If the script gets stuck, it may revert to an error state. Hitting `ABORT` will cause it to retry the last step that failed. For example, if the craft detaches from the launcher in Low Kerbin Orbit, the craft's own propulsion needs to be enabled for the rendezvous manoeuvres. If the staging set-up does not activate an engine, the craft will go into the error state. Staging or enabling the engine manually, then hitting `ABORT` should allow the script to carry on.

Geoff Banks / ElWanderer
