# KMScience.ks

## Kerbin Moon Science (Orbital) boot script.

The purpose of this boot script is to launch a crewed, science-gathering craft into a specific low orbit of Mun or Minmus, gather science from the space above each waypoint, then return to Kerbin. The script has been written for Apollo-style craft i.e. a command module with a heat shield (I tend to set the ablator to about 50%), plus a service module consisting of fuel tanks and engines. Unlike the Kerbin Tourist script, no effort is currently made to target a specific landing area on return to Kerbin.

### Disk space requirement

Unknown, but assumed to be moderately high (may fit inside `40000` bytes, but probably won't).

### Script Parameters

The parameters of the target orbit can be specified by changing the global variables near the top of the file:

    // set these values ahead of launch
    GLOBAL SAT_BODY IS MINMUS.
    GLOBAL SAT_NAME IS "Minmus Science Orbiter".
    
    GLOBAL SAT_AP IS 150000.
    GLOBAL SAT_PE IS 150000.
    GLOBAL SAT_I IS 85.
    GLOBAL SAT_LAN IS 0.
    GLOBAL SAT_W IS 0.
    
    GLOBAL FINAL_AP IS 8500.
    GLOBAL FINAL_PE IS 8500.
    GLOBAL FINAL_I IS 85.

#### `SAT_BODY`

The destination body. Should be `MUN` or `MINMUS`.

#### `SAT_NAME`

On first boot, the ship will be renamed with this string.

#### `SAT_AP`, `SAT_PE` and `SAT_W`

The apoapsis, periapsis and argument of periapsis (a lower-case omega looks like a w) of the initial target orbit. The argument of periapsis indicates how far around the orbit from the ascending node (where the orbit crosses the equator South-to-North) the periapsis will be located.

These parameters determine the shape of the initial target orbit.

#### `SAT_I` and `SAT_LAN`

The inclination and longitude of the ascending node of the initial target orbit. The longitude of the ascending node indicates how far around the body from the universal reference vector the ascending node (where the orbit crosses the equator South-to-North) will be located. Note that the reference vector is fixed and does not rotate with the orbit's body. 

These parameters determine the orientation/inclination of the initial target orbit.

#### `FINAL_AP`, `FINAL_PE` and `FINAL_I`

The apoapsis, periapsis and inclination of the "final" science-gathering orbit. This is often going to be fairly low in order to satisfy contract requirements, so it was felt safer to move to this orbit after establishing a stable orbit further out.

### Script Steps

#### Init

The craft is renamed `SAT_NAME` and then logging enabled. Logging is not enabled earlier so that the log file name will be based around the new name rather than the old name.

The script will calculate when the orbit of the target body will pass over the launch site and the initial azimuth (compass bearing) that the craft should follow.

The Mun's equatorial orbit means that a launch can be initiated immediately (with a bearing of 90 degrees), but for Minmus there will be a wait of up to three hours before launch (with a bearing of 83.5 or 96.5 degrees). Launch clamps are recommended to maintain power to the craft if going to Minmus!

#### Launch

Launch is to a standard 85km by 85km Low Kerbin Orbit, with the inclination matching (as near as possible) that of the destination body.

#### Match orbit inclination

The script will plot and execute a burn to reduce the relative inclination between the current orbit and the target body to zero. If the launch azimuth and time were calculated correctly, this should be a very small burn. Matching inclination precisely may not be necessary, but during early testing it made the next step much easier.

#### Transfer

The script will calculate a Hohmann transfer to the target body. Chances are that when plotted as a manoeuvre node, this will not actually reach the target, but the node improvement code will take over and adjust the node until the predicted periapsis matches the target apoapsis as best as possible.

This node will then be executed, and followed up (if necessary) with correction burns until the craft's trajectory reaches the target body, with a periapsis within a reasonable distance of the target apoapsis. What is considered 'reasonable' varies depending on whether the target apoapsis is close to the surface or not.

The script will then time warp to the sphere of influence transition with the target body, with the aim of passing through the transition at 50x warp.

Once in the sphere of influence of the target body, further correction burns can be plotted and executed if they improve the final orbit towards the target parameters. Finally, a node will be plotted at the periapsis and executed to insert into orbit.

Note - the target inclination and longitude of the ascending node are taken into account during the node improvement process that is run on each manoeuvre node. Recent changes have improved the node improvement process, but there is still no guarantee that it will get close to the target values. The final inclination at the target is hard to adjust unless close to the plane of the equator of the body (which may not happen until close to the periapsis when trying to get to Minmus) and the longtiude of the ascending node is largely determined by the launch time and travel time. As such, it's best to assume that the craft will need to perform an inclination burn from an equatorial orbit to the target incilnation and budget delta-v accordingly (worst cases are about 700m/s for a 90 degree change around the Mun, or 150m/s if around Minmus). Further changes are needed to be able to time a transfer to arrive (cheaply) aligned with the target inclination and longitude of the ascending node.

#### Match initial orbit inclination and shape

The script will plot and execute a burn to reduce the relative inclination between the current orbit and the initial target orbit to zero. This will place the ascending node in the right place.

The script will then plot and execute burns to put the periapsis and apoapsis in the initial locations and altitudes.

#### Match final orbit inclination and shape

The script will plot and execute a burn to reduce the relative inclination between the current orbit and the final target orbit to zero. The LAN is not changed - it is assumed you want a suitable polar orbit, rather than a specific value at this point.

The script will then plot and execute burns to put the periapsis and apoapsis in the final locations and altitudes.

#### Science!

The script will calculate which waypoints it will fly-over (with a tolerance of `7`km ground-track separation between estimated craft position and waypoint) during the next `15` days. It will then warp to each waypoint in turn and trigger science collection at closest approach. This should be enough to complete the contract requirement, assuming the altitude is within the range specified. The science is not kept - it is dumped after each waypoint to make room for the next set. The assumption is that you've already brought home the relevant science.

Once all waypoints have been visited once, the craft will automatically switch to a return transfer.

Note - at low altitudes, time warp is very limited and so the script may take a very long time to complete all the waypoints.

Note 2 - if you switch away from the craft and come back, kOS will reboot. The list of waypoint overpasses will be recalculated from scratch, using a new deadline of `15` days from the current time. This is one way to time warp faster (as long as you can remember when the next waypoint is), but it will also keep extending the flightplan to visit the waypoints again if they aren't being cleared (e.g. if a waypoint isn't for science, if it's for science that your vessel can't fulfil or if the altitude requirement isn't being met).

Note 3 - the limits are not controlled by `GLOBAL` settings at the moment, but can be changed by editing this line of code: `visitContractWaypoints(7,15).`

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

If the script gets stuck, it may revert to an error state. Hitting `ABORT` will cause it to retry the last step that failed. For example, if the craft detaches from the launcher in Low Kerbin Orbit, the craft's own propulsion needs to be enabled for the transfer to the target body. If the staging set-up does not activate an engine, the craft will go into the error state. Staging or enabling the engine manually, then hitting `ABORT` should allow the script to carry on.

Geoff Banks / ElWanderer
