# KSat.ks

## Kerbin Satellite boot script.

The purpose of this boot script is to launch a satellite into a specific orbit of Kerbin. Typically, this would be to fulfil a contract, though it could be used for launching a ScanSat, relay satellite etc.

### Script Parameters

The parameters of the target orbit can be specified by changing the global variables near the top of the file:

    // set these values ahead of launch
    GLOBAL SAT_NAME IS "MunSat 1".
    GLOBAL SAT_AP IS 75000.
    GLOBAL SAT_PE IS 50000.
    GLOBAL SAT_I IS 45.
    GLOBAL SAT_LAN IS 0.
    GLOBAL SAT_W IS 0.

#### SAT\_NAME

On first boot, the ship will be renamed with this string.

#### SAT\_AP, SAT\_PE and SAT\_W

The apoapsis, periapsis and argument of periapsis (a lower-case omega looks like a w) of the target orbit. The argument of periapsis indicates how far around the orbit from the ascending node (where the orbit crosses the equator South-to-North) the periapsis will be located.

These parameters determine the shape of the orbit.

#### SAT\_I and SAT\_LAN

The inclination and longitude of the ascending node of the target orbit. The longitude of the ascending node indicates how far around the body from the universal reference vector the ascending node (where the orbit crosses the equator South-to-North) will be located. Note that the reference vector is fixed and does not rotate with the orbit's body. 

These parameters determine the orientation/inclination of the target orbit.

### Script Steps

#### Init

The craft is renamed SAT\_NAME and then logging enabled. Logging is not enabled earlier so that the log file name will be based around the new name rather than the old name.

The script will calculate when the plane of the target orbit will pass over the launch site and the initial azimuth (compass bearing) that the craft should follow to launch into this plane.

For non-equatorial orbits, there will be a wait of up to three hours before launch. Launch clamps are recommended to ensure the craft has power while waiting!

#### Launch

Launch is to a standard 85km by 85km Low Kerbin Orbit, with the inclination matching (as near as possible) that of the target orbit.

#### Match orbit shape

The script will plot and execute burns to put the periapsis and apoapsis in the target locations and altitudes.

Note - in order to keep down the required disk space below 20000 bytes, this script does not have any way of matching inclination. The inclination is determined by the accuracy of the launch and can't be corrected later.

#### Sleep

The orbit should now be very close to that described by the parameters. The script will go into a form of sleep mode - it will point the craft at the sun (for maximum solar panel exposure, assuming you have folding panels on the sides, or a fixed panel on the top of the craft) and wait to be reawoken.

Currently, hitting ABORT will cause it to wake and jump back to the last step, where it will try to match the orbit shape again. This may be useful if the orbit ended up being too far from that desired.

In future, it is desired to expand this behaviour so that a sat can be woken up with new orders. This has not been implemented.

#### Failure cases

If the script gets stuck, it may revert to an error state. Hitting ABORT will cause it to retry the last step that failed. For example, if the satellite detaches from the launcher in Low Kerbin Orbit, the satellite's own propulsion needs to be enabled for it to execute the manoeuvre nodes calculated to match the target orbit's shape. If the staging set-up does not activate an engine, the craft will go into the error state. Staging or enabling the engine manually, then hitting ABORT should allow the script to carry on.

Geoff Banks / ElWanderer
