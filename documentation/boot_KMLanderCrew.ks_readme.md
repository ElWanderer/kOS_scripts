# KMLanderCrew.ks

## Kerbin Moon Crewed Lander boot script.

WARNING: This boot script is unlike all the others. The mission steps do not include launch from Kerbin. The mission steps that do exist are activated through hitting `ABORT` once the lander has been powered-up and undocked from the 'mothership'. Because of this, it is recommended to have the kOS processor(s) on the lander powered off initially.

WARNING: This has not been tested all the way through. From memory my one test flight saw the lander fall over after landing in a canyon.

The purpose of this boot script is to land a crewed craft on the surface of Mun or Minmus, then take-off, rendezvous and dock with a station or mothership.

The name is possibly mis-leading, as it could be used to land on any atmosphere-less body.

### Disk space requirement

Unknown.

### Script Parameters

The parameters of the target orbit can be specified by changing the global variables near the top of the file:

    // set these values ahead of launch
    GLOBAL NEW_NAME IS "Endeavour II".
    GLOBAL CORE_HEIGHT IS 2.3.

    GLOBAL LAND_LAT IS 0.
    GLOBAL LAND_LNG IS 20.
    GLOBAL SAFETY_ALT IS 2000.

    GLOBAL RETURN_ORBIT IS 30000.

#### `NEW_NAME`

On first boot, the ship will be renamed with this string.

#### `CORE_HEIGHT`

The height in metres that `ALT:RADAR` returns if the lander alone is sat on the ground with landing legs extended. This is used to account for the difference in radar altitude as measured from the root/controlling part and the distance between the landing legs and the ground. These can differ by several metres, which is very important during the final stages of a landing.

#### `LAND_LAT`

The target latitude to aim for when beginning a descent.

#### `LAND_LNG`

The target longitude to aim for when beginning a descent.

#### `SAFETY_ALT`

The altitude above terrain (in metres) that the periapsis will be placed when beginning a descent. Higher values are safer, but less efficient in terms of fuel usage.

#### `RETURN_ORBIT`

The apoapsis (in metres) to aim for during ascent from the target body.

### Script Steps

#### Init

The craft is renamed `NEW_NAME` and then logging enabled. Logging is not enabled earlier so that the log file name will be based around the new name rather than the old name.

The script will then wait until the `ABORT` button is pressed.

#### Landing

The script will attempt to land near the target co-ordinates as defined in the boot script. This is done by setting up a phasing orbit so that the target will pass underneath, lowering the periapsis until it is `SAFETY_ALT` above the target point then burning at the periapsis to kill horizontal velocity then descend to a touchdown.

#### Landed

Once on the ground (or splashed down) the script will wait until the `ABORT` button is pressed. It is assumed that the crew may want to spend some time walking around outside, collecting rocks and taking pictures, so the launch sequence requires this manual input.

#### Launch

Once a launch has been commanded, the script will check the validity of the target (if there is one). A craft or station in orbit of the current body must be selected before launch will continue. This is because the launch will be timed and aimed to end up in the orbital plane of the target, to reduce the fuel requirements of the rendezvous step that follows.

Launch is to a circular `RETURN_ORBIT`m by `RETURN_ORBIT`m orbit.

#### Rendezvous

Once in orbit again, the validity of the target will be rechecked. It is possible for the target selection to be changed during the launch step.

If the target is no longer valid, the craft will wait in orbit until a valid target is selected, in which case rendezvous will proceed.
 
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

#### Failure cases

If the script gets stuck, it may revert to an error state. Hitting `ABORT` will cause it to retry the last step that failed.

Geoff Banks / ElWanderer
