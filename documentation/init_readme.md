## Init scripts/libraries

There are currently two initialisation scripts with a shared library and a selector file. Previously, all this code was in a single library, but I felt it was worth separating out the (chunky) code I added for coping with multiple disk volumes to keep the file size down for the simpler version that only uses the local volume.

All the boot scripts start out the first time by running the selector script from the archive. This copies over either `"0:/init.ks"` (single volume) or `"0:/init_multi.ks"` (multiple volumes) to `"1:/init.ks"`. This is expected to take place on the launchpad where we should be guaranteed a connection to the archive, so no check on the connection is made beforehand. The current method of selection is: we loop through all the other processors on the craft and count how many there are that meet the following conditions:
 * they are powered up
 * they do not have a boot file set
 * they are tagged appropriately (see below)

The tagging requirement has a few choices. If the current processor has a tag of `MULTI`, any other processors whose tag is blank will be included in the count. If the current processor has a tag other than `MULTI`, any other processors will be included if they have the same tag. If the current processor has a blank tag, any other processors will be included if they also have blank tags.

This means that if you have two kOS CPUs set to run different boot scripts, neither will try to overwrite each other's disks, they will both use the single volume version of init. There could be competition if you had a third, non-booting volume, though: both active CPUs would load the multiple volume version and try to use the third disk as well as their own. Part tags can be used to assign the third volume to either (or neither) CPU.

Finally, each boot script then runs `"1:/init.ks"`. So on each subsequent boot after the first, it will go straight to running whatever init script it has locally.

    @LAZYGLOBAL OFF.

    IF NOT EXISTS("1:/init.ks") { RUNPATH("0:/init_select.ks"). }
    RUNONCEPATH("1:/init.ks").

In turn, both of the init scripts will load and run the common library. There is a potential circular dependency here. `loadScript()` is a function in the `init.ks`/`init_multi.ks` file, but it in turn calls `pOut()`, a printing function in the `init_common.ks` library. We can't use `pOut()` until we've actually run the common library. To solve this we make use of an extra parameter in the `loadScript()` function, `loud_mode`. By passing in `FALSE`, we disable the usual printing and logging that the `loadScript()` function does. Not all printing is disabled: if there were an error, this is still printed. That happens on the grounds that we were going to crash anyway, if we couldn't load a file (e.g. due to lack of space).

The `init_common.ks` library triggers quite a few pieces of code as well as adding a suite of library functions. If timewarp was active when we booted up (which can happen if we run out of electrical power during time warp), this is disabled. We also wait for the ship to be unpacked by calling `killWarp()`:

    KUNIVERSE:TIMEWARP:CANCELWARP().
    WAIT UNTIL SHIP:UNPACKED.

We initialise the staging timer with the current time. This is often used for checks such as "has it been more than x seconds since we last staged" to guide whether it's okay to stage again and for certain actions e.g. we want to wait for about 5 seconds after triggering the launch escape system, then jettison it.

    setTime("STAGE").

We have the capability of running a ship-specific script. This uses the ship's name to determine which file to try loading, but note that it searches the craft sub-directory of `/Ships/scripts`. If this exists, it is copied to `"1:/craft.ks"` and run. On a subsequent boot, we check first to see if we already have a craft-specific file and if so go straight to running it:

    GLOBAL CRAFT_FILE IS "1:/craft.ks".
    IF NOT EXISTS (CRAFT_FILE) {
      LOCAL afp IS "0:/craft/" + padRep(0,"_",SHIP:NAME) + ".ks".
      IF EXISTS (afp) { COPYPATH(afp,CRAFT_FILE). }
    }
    IF EXISTS(CRAFT_FILE) { RUNONCEPATH(CRAFT_FILE). }

Then we open a terminal and clear its screen ready for output:

    CORE:DOEVENT("Open Terminal").
    CLEARSCREEN.

Lastly, we print out the filename and version. This is useful for checking what versions of files are actually running:

    pOut("init_common.ks v1.2.0 20160902").

Each init script, boot script and library file has a similar print statement.

### Global variable reference

#### `RESUME_FN`

The filename of the main resume file. The default filename is `resume.ks`.

This is used to store commands to be run to recover a previous state following a reboot. The reason for doing this is to store a function call and all its parameters, so that we can resume (fairly) seamlessly during complicated functions such as `doLaunch()`, `doReentry()` etc.

#### `VOLUME_NAMES (init_multi.ks only)`

A list of available volume names. By default this is an empty list, though this is quickly populated by running listVolumes(). Practically, the real default value is a list containing the local volume, which gets renamed `"Disk0"`.

This is used to store the names of all the disks we think we have access to. Various `init_multi.ks` functions rely on being able to loop through this list.

#### `TIMES`

Various scripts need to keep track of their own times (time since staging, time since changing runmode, time to warp to, etc.) and there exist common functions to allow this. The times are stored in this lexicon.

#### `LOG_FILE`

The path of the log file we will write to if `doLog()` gets called. If set to `""` (the initial value), no logging will take place.

#### `g0`

Standard gravity, `9.08665`m/s^2

#### `INIT_MET_TS` and `INIT_MET`

`INIT_MET_TS` stores the value of the Mission Elapsed Time when we last calculated the pretty-formatted version.
`INIT_MET` stores the last, calculated, pretty-formatted Mission Elapsed Time. 

The pretty-formatted Mission Elapsed Time need not be recalculated until the next second has passed, which helps if trying to print out a lot of messages in quick succession.

#### `stageTime()`

A function delegate. This returns the time elapsed since the "STAGE" time was updated, which should either be the time since boot or the time since the last staging event.

#### `CRAFT_SPECIFIC`

This is a lexicon. The idea is that craft-specific files can insert values (and even functions) into here for use elsewhere. Currently nothing has actually been implemented. There are some suggested uses in `issue #55`.

#### `CRAFT_FILE`

The path of the locally-stored craft-specific file, if one exists.

### Function reference

#### `cOk()`

This function is a shorthand for `HOMECONNECTION:ISCONNECTED`. It will return `TRUE` if we have a connection back to the Kerbal Space Center, `FALSE` otherwise. This can then be used as a check prior to trying to access the archive.

#### `loadScript(script_name, loud_mode)`

This tries to copy `script_name` from the archive to one of the disk volumes on the ship. `init.ks` uses the processor's local volume (`"1:/"`), but `init_multi.ks` will loop through the available volumes (starting with `"1:/"`) until it finds one that has enough space to store the script being copied. If the file already exists, it does not re-copy the file.

Before accessing the archive, the function waits for `cOk()` to return `TRUE`. This may mean a long pause in processing if there is no connection available, but without this check the script would crash.

This will crash kOS if the file needs to be copied over but there is not enough space to store the file (currently it is assumed that we want to stop and debug - if we are missing a library then chances are we will crash shortly anyway).

Returns the full file path for where the script is on a local volume. This is meant to be plugged into `RUNPATH` e.g. `RUNONCEPATH(loadScript(script_name)).`

Loud mode defaults to true, that is it will print out what it is doing. Passing in loud_mode as false will prevent it from printing.

#### `delScript(script_name)`

This tries to delete `script_name` from the local disk volume(s). 

It will only delete one copy - it is assumed that anything being deleted will have been added via the `loadScript()` function, which avoids duplicate copies. Similarly, it won't go hunting in sub-directories, as `loadScript()` does not create those.

If the file does not exist, nothing happens.

#### `delResume(file_name)`

Tries to delete `file_name` from the local volume(s).

The default `file_name` is `RESUME_FN`.

If the file does not exist, nothing happens.

#### `store(text, file_name, file_size_required)`

This logs text to `file_name` on a local file volume. The default `file_name` is `RESUME_FN`.

There is a difference in behaviour between `init.ks` and `init_multi.ks`. `init.ks` simply uses the local volume, but `init_multi.ks` will try to find a volume with enough free space: there must be `file_size_required` bytes available. The default `file_size_required` is `150` bytes.

Will crash kOS if it tries to write out too large a file to fit on the local volume.

#### `append(text, file_name)`

Tries to append text to `file_name`.

The default `file_name` is `RESUME_FN`.

Will crash kOS if `file_name` does not exist anywhere on the local volume.

#### `resume(file_name)`

Tries to run `file_name`.

The default `file_name` is `RESUME_FN`.

If `file_name` does not exist, nothing happens.

#### `setVolumeList(list_of_volume_names) (init_multi.ks only)`

Overwrites the `VOLUME_NAMES` global list with the passed-in list, then calls `pVolume()` to dump out the list of volumes.

This is intended for boot scripts/craft-specific scripts to set-up a specific list of volumes for a processor to use, rather than relying on the search done on initialisation, for cases where that search fails to pick up some drives, or finds too many.

#### `listVolumes() (init_multi.ks only)`

This function is run once on start-up. It will populate `VOLUME_NAMES` with a list of available volumes.

The function will start by renaming the local volume `"{CPU part tag}D0"` if it doesn't already have a name, then set `VOLUME_NAMES` to a list containing just the name of this local volume. As far as I can tell, volumes typically start off with no name at all.

Next, it loops through all the processors on the vessel, checking their volumes to see if they should be added to the list. Volumes are added if their processor meets the following conditions:
 * it is powered up
 * it does not have a boot file set
 * it is tagged appropriately (see below)

The tagging requirement has a few choices. If the processor on which this script is running has a tag of `MULTI`, any other processors whose tag is blank will be included in the count. If the current processor has a tag other than `MULTI`, any other processors will be included if they have the same tag. If the current processor has a blank tag, any other processors will be included if they also have blank tags.

These checks are designed to prevent the current volume from being added twice and from including any volumes that are in use by another processor. If you have a vessel with two CPUs it may be because you intend to divide it into two at some point, so giving each one a boot file or different part tags prevents each CPU from trying to use the other's disk.

Before being added to the list, each volume is renamed if it doesn't already have a name. Names are generated numerically: `"{CPU part tag}D1"`, `"{CPU part tag}D2"` etc. Note - this uses the part tag of the currently-running CPU (`CORE`), not the part on which the volume under consideration is located.

#### `pVolumes() (init_multi.ks only)`

Prints out all the volumes that have been named in `VOLUME_NAMES`, including how much free space each one has.

#### `findPath(file_name) (init_multi.ks only)`

Loops through the volumes names in `VOLUME_NAMES`, looking to see if `file_name` exists on the root directory of that volume.

Returns the filepath if it can find the file, `""` otherwise.

Note that currently this does not search sub-directories within volumes.

#### `findSpace(file_name, minimum_free_space) (init_multi.ks only)`

Loops through the volumes names in `VOLUME_NAMES`, looking to see if that volume has more bytes of free space available than the parameter `minimum_free_space`.

Returns the full filepath (including `file_name`) if it can find a volume with enough space. Otherwise it'll print out an error, call `pVolumes()` so you can see what space is avaible and return `""`.

#### `padRep(length, character, text)`

This will turn the input text into a string, pad the left-hand side with spaces if shorter than the input length then replace all spaces with the input character.

Note that the replace part of the function operates over the entire string, so it will replace any spaces within the input text with the input character.

`padRep` is short for pad-and-replace.

#### `formatTS(u_time1, u_time2)`

Calculates the difference between the two input universal timestamps and converts the result into a pretty string, of the format `"[T+00 000 00:00:00]"`. This is intended to be used for Mission Elapsed Time.

The default `u_time2` value is the current universal timestamp (i.e. `TIME:SECONDS`).

Note that kOS has an issue (logged as `#1800`) whereby Kerbin is assumed to have 365 (Kerbin) days a year. The actual value is 426. The number of years and days in the return string will not match KSP if the time difference is more than 365 days. We could calculate this ourselves, but then the function would be even longer and slower than it already is!

Note 2 - we used to format the time portion ourselves, by padding in extra zeroes and rounding the seconds. Since kOS v1.0.1 does that automatically, we can call just `timestamp:CLOCK`.

#### `formatMET()`

A wrapper around `formatTS()` that is used to produce Mission Elapsed Time in a pretty format suitable for displaying on the terminal and logging out. To avoid calling `formatTS()` too many times in quick succession, the MET string is kept and only recalculated once `MISSIONTIME` has ticked onto the next whole second.

#### `logOn(log_file_path)`

Enables logging to the input `log_file_path`. Can be used to disable logging if passed in an empty string as a parameter instead of a file path. When logging is successfully enabled, the current `SHIP:NAME` is logged out, along with a terminal message saying `"Log file: _log_file_path_"`. As vessels are often not uniquely-named (e.g. during testing you may launch a rocket with the same name multiple times), the logging out of the `SHIP:NAME` acts as a useful break in the logfile to indicate a new mission.

The default value for `log_file_path` is `"0:/log/_ship_name_.txt"` (with any spaces in `ship_name` converted to underscores).

#### `doLog(text)`

If logging is enabled (i.e. `LOG_FILE` does not contain an empty string) write the input text to the log file.

On the assumption that logging is to the archive, the function first calls `cOk()`. If this returns `FALSE` (indicating the archive is not accessible), no logging takes place.

#### `pOut(text, write_MET_timestamp)`

This is basically a wrapper around the `PRINT` command.

Prints out the input text to the terminal. If `write_MET_timestamp` is true, the text is prefixed with the Mission Elapsed Time as returned by `formatMET()`.

`pOut()` in turn calls `doLog(text)`, so that each piece of output to the terminal is logged.

The default value for `write_MET_timestamp` is `TRUE`.

#### `hudMsg(text, colour, size)`

This is a wrapper around the `HUDTEXT()` command.

Prints the input text to the (centre/top of the) screen, with a duration of three seconds.

`hudMsg()` in turn calls `pPout()`, though with the text prefixed `"HUD: "`. Hence such messages are printed to the terminal and can be logged to the log file.

The default colour is `yellow`.

The default size is `40`.

#### `setTime(name, u_time)`

Updates/sets the lexicon value `TIMES[name]` to contain the input universal timestamp. This is used to store timestamps of events such as the last staging event, the last time the `run_mode` changed or the time in the future we want to timewarp to.

If not specified, the value of `u_time` is defaulted to `TIME:SECONDS` i.e. "now".

#### `diffTime(name)`

Returns the time difference (in seconds) that `TIME:SECONDS` is ahead of the lexicon value `TIMES[name]`. This effectively returns the time that has elapsed since the timestamp stored when `setTime(name)` was last called. Note that the stored timestamp need not be the time of the `setTime()` call - it could contain a time in the future in which case `diffTime()` will return a negative value.

#### `doStage()`

A wrapper around the `STAGE` command.

This additionally calls `pOut()` to indicate that a staging event has been triggered, and calls `setTime("STAGE")` to reset `TIMES["STAGE"]` to be the current universal timestamp i.e. sets the "time of last staging event" to be "now".

#### `mAngle(angle)`

This takes the input angle and normalises it to be between `0` and `360` degrees. This is used widely enough in various libraries that it made sense to put it in the common library.

`mAngle` is short for "make angle".

#### `killWarp()`

This function does two things:
* It calls `KUNIVERSE:TIMEWARP:CANCELWARP()` to kill any time warping that is currently taking place.
* It waits until `SHIP:UNPACKED` returns `TRUE`. This is a safety step to ensure that the active vessel is fully loaded and unpacked before we try to do anything with it.

#### `doWarp(universal_timestamp, stop_function)`

This function is a wrapper around `WARPTO(universal_timestamp)`, with an optional check that will stop time warp early.

The input parameter `stop_function` is expected to be a function delegate that returns `TRUE` or `FALSE` when called. `stop_function` will be called each tick during the time warp, with a value of `TRUE` indicating that time warp should be stopped. A value of `FALSE` indicates that the time warp should continue.

Once either the current time passes the input `universal_timestamp` or `stop_function` returns TRUE, `killWarp()` will be called to stop the time warp and wait until the ship is unpacked and ready for further processing.

If not specified, the value of `stop_function` is defaulted to the anonymous function `{ RETURN FALSE. }`. This will not apply any checking during the time warp.

Geoff Banks / ElWanderer
