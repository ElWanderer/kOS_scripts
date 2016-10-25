## lib_crew (crew library)

### Description

Functions for counting and keeping track of crew onboard vessels.

This library makes use of the `store()` and `resume()` init functions to store and recover the crew count. `resume(CREW_FN)` is called each time the library is loaded, so that the stored crew size can be recovered. This is so that changes to the crew count (e.g. on rescuing a stranded Kerbal) can be detected and reacted to.

### Global variable reference

#### `CREW_SIZE`

This is used to store the last known crew count. It is not the current crew size, which can be found by calling `crewCount()` or `SHIP:CREW():LENGTH`, but the number of crew members the craft had at a certain time e.g. prior to rendezvousing with a stranded Kerbal. On a new Kerbal boarding the craft, `CREW_SIZE` will not change but `crewCount()` will return a different value, thereby allowing the boarding event to be detected.

The initial value is `0`, but this gets populated with the current crew size by calling storeLastCrewCount().

#### `CREW_FN`

The filename used for the crew count-specific `store()` and `resume()` calls. By default this is set to `cs.ks`.

### Function reference

#### `storeLastCrewCount()`

This function resets `CREW_SIZE` to the current value returned by `crewCount()` and stores a kOS command to set this again that will be run on a reboot: `SET CREW_SIZE TO {CREW_SIZE}.`

#### `lastCrewCount()`

Returns the current value of `CREW_SIZE`.

#### `crewCount(vessel)`

Returns the number of crew members currently aboard the craft `vessel`.

If not specified, `vessel` is set to `SHIP`, to return the details of the current craft.

#### `crewSpaces(vessel)`

Returns the number of empty seats currently aboard the craft `vessel`. This is determined by subtracting the current number of crew from the craft's `CREWCAPACITY`.

If not specified, `vessel` is set to `SHIP`, to return the details of the current craft.

#### `pCrew(vessel)`

Prints out the details of the current crew, including the type (Pilot, Scientist, Engineer, Tourist) and location (part name) of each crew member. 

If not specified, `vessel` is set to `SHIP`, to return the details of the current craft.

Geoff Banks / ElWanderer
