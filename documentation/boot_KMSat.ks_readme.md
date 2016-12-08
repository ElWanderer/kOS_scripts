# KMSat.ks

## Kerbin Moon Satellite boot script.

The purpose of this boot script is to launch a satellite into a specific orbit of Mun or Minmus. Typically, this would be to fulfil a contract, though it could be used for launching a ScanSat, relay satellite etc.

### Disk space requirement

This script and the libraries it calls are meant to remain with the `40000` byte limit of the large, inline kOS processor. As with `KSat.ks`, this is achieved by deleting some libraries once they are no longer needed e.g. the launch libraries are deleted once in orbit, and the transfer library is deleted once in orbit of the destination.

### Script Parameters

The parameters of the target orbit can be specified by changing the global variables near the top of the file:

    // set these values ahead of launch
    GLOBAL SAT_BODY IS MUN.
    GLOBAL SAT_NAME IS "MunSat 1".
    GLOBAL SAT_AP IS 75000.
    GLOBAL SAT_PE IS 50000.
    GLOBAL SAT_I IS 45.
    GLOBAL SAT_LAN IS 0.
    GLOBAL SAT_W IS 0.

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

Note - the target inclination and longitude of the ascending node are taken into account during the node improvement process that is run on each manoeuvre node. Recent changes have improved the node improvement process, but there is still no guarantee that it will get close to the target values. The final inclination at the target is hard to adjust unless close to the plane of the equator of the body (which may not happen until close to the periapsis when trying to get to Minmus) and the longtiude of the ascending node is largely determined by the launch time and travel time. As such, it's best to assume that the craft will need to perform an inclination burn from an equatorial orbit to the target incilnation and budget delta-v accordingly (worst cases are about 700m/s for a 90 degree change around the Mun, or 150m/s if around Minmus). Further changes are needed to be able to time a transfer to arrive (cheaply) aligned with the target inclination and longitude of the ascending node.

#### Match orbit inclination and shape

The script will plot and execute a burn to reduce the relative inclination between the current orbit and the target orbit to zero. This will place the ascending node in the right place.

Finally, the script will plot and execute burns to put the periapsis and apoapsis in the target locations and altitudes.

#### Sleep

The orbit should now be very close to that described by the parameters. The script will go into a form of sleep mode - it will point the craft at the sun (for maximum solar panel exposure, assuming you have folding panels on the sides, or a fixed panel on the top of the craft) and wait to be reawoken.

Currently, hitting `ABORT` will cause it to wake and jump back to the last step, where it will try to match the orbit inclination and then shape again. This may be useful if the orbit ended up being too far from that desired.

In future, it is desired to expand this behaviour so that a sat can be woken up with new orders. This has not been implemented.

#### Failure cases

If the script gets stuck, it may revert to an error state. Hitting `ABORT` will cause it to retry the last step that failed. For example, if the satellite detaches from the launcher in Low Kerbin Orbit, the satellite's own propulsion needs to be enabled for the transfer to the target body. If the staging set-up does not activate an engine, the craft will go into the error state. Staging or enabling the engine manually, then hitting `ABORT` should allow the script to carry on.

Geoff Banks / ElWanderer
