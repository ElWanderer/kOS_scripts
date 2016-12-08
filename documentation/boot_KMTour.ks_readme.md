# KMTour.ks

## Kerbin Moon Tourist boot script.

The purpose of this boot script is to launch a tourist craft into a specific orbit of Mun or Minmus, then return to Kerbin. The script has been written for Apollo-style craft i.e. a command module with a heat shield (I tend to set the ablator to about 50%), plus a service module consisting of fuel tanks and engines. Unlike the Kerbin Tourist script, no effort is currently made to target a specific landing area on return to Kerbin.

### Disk space requirement

This needs confirming. The requirements are similar to those for the KMSat.ks script, albeit with the extra overhead of re-entry, so it should fit within `40000` bytes.

### Script Parameters

The parameters of the target orbit can be specified by changing the global variables near the top of the file:

    // set these values ahead of launch
    GLOBAL SAT_BODY IS MINMUS.
    GLOBAL SAT_NAME IS "Minmus Tourbus".
    GLOBAL SAT_AP IS 50000.
    GLOBAL SAT_I IS 0.
    GLOBAL SAT_LAN IS 0.

#### `SAT_BODY`

The destination body. Should be `MUN` or `MINMUS`.

#### `SAT_NAME`

On first boot, the ship will be renamed with this string.

#### `SAT_AP`, `SAT_PE` and `SAT_W`

The apoapsis, periapsis and argument of periapsis (a lower-case omega looks like a w) of the target orbit. The argument of periapsis indicates how far around the orbit from the ascending node (where the orbit crosses the equator South-to-North) the periapsis will be located.

These parameters determine the shape of the orbit.

#### `SAT_I` and `SAT_LAN`

The inclination and longitude of the ascending node of the target orbit. The longitude of the ascending node indicates how far around the body from the universal reference vector the ascending node (where the orbit crosses the equator South-to-North) will be located. Note that the reference vector is fixed and does not rotate with the orbit's body. 

These parameters determine the orientation/inclination of the target orbit.

It should be noted that while these values are used to refine the transfer to the target body, the script will not match the parameters once in orbit of the destination.

### Script Steps

#### Init

The craft is renamed `SAT_NAME` and then logging enabled. Logging is not enabled earlier so that the log file name will be based around the new name rather than the old name.

The script will calculate when the orbit of the target body will pass over the launch site and the initial azimuth (compass bearing) that the craft should follow.

The Mun's equatorial orbit means that a launch can be initiated immediately (with a bearing of 90 degrees), but for Minmus there will be a wait of up to three hours before launch (with a bearing of 83.5 or 96.5 degrees). Launch clamps are recommended to maintain power to the craft if going to Minmus!

#### Launch

Launch is to a standard `85`km by `85`km Low Kerbin Orbit, with the inclination matching (as near as possible) that of the destination body.

#### Match orbit inclination

The script will plot and execute a burn to reduce the relative inclination between the current orbit and the target body to zero. If the launch azimuth and time were calculated correctly, this should be a very small burn. Matching inclination precisely may not be necessary, but during early testing it made the next step much easier.

#### Transfer

The script will calculate a Hohmann transfer to the target body. Chances are that when plotted as a manoeuvre node, this will not actually reach the target, but the node improvement code will take over and adjust the node until the predicted periapsis matches the target apoapsis as best as possible.

This node will then be executed, and followed up (if necessary) with correction burns until the craft's trajectory reaches the target body, with a periapsis within a reasonable distance of the target apoapsis. What is considered 'reasonable' varies depending on whether the target apoapsis is close to the surface or not.

The script will then time warp to the sphere of influence transition with the target body, with the aim of passing through the transition at 50x warp.

Once in the sphere of influence of the target body, further correction burns can be plotted and executed if they improve the final orbit towards the target parameters. Finally, a node will be plotted at the periapsis and executed to insert into orbit.

#### Tourism

Once in orbit of the target body, the script does not wait around to allow the tourists to take pictures, enjoy the view etc. Instead, it'll move on to plotting the return transfer.

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
