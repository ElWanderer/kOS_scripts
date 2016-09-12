# kOS_scripts documentation 

## Introduction

### Background

As with a lot of new kOS programmers, I started out by writing simple launch scripts. Once comfortable, I began developing a suite of libraries and boot scripts. There were two main drivers:
 * automating contracts such as tourist flights and satellite launches
 * learning and implementing interesting bits of orbital mechanics

There are many, many things that can be automated in Kerbal Space Program, so this is ongoing and probably never-ending work! I had always intended to make the scripts public once I got them to a high-enough standard. That isn't really the case at the time of writing, but the v1.0.0 pre-release of kOS prompted me to start putting the code online and documenting it properly. Being on Github, it means others could see and use the code, or even contribute to it.

The code is written to work with kOS v1 / KSP 1.1.3, but most of the development has taken place with earlier versions, particularly KSP v1.0.5.

### Core concepts

##### File handling

The scripts are written with the assumption that they will be copied onto a craft's local hard drive, rather than being run directly from the archive. 

Currently the script files are split into three different types, though two of these are almost identical:
 * boot scripts
 * init scripts
 * library scripts

Each boot script represents a mission or task, such as placing a satellite into orbit. Each one calls an init script (there are now two with a common library, but this is a very recent development) that sets up a common set of functions for loading libraries, plus some functions that are commonly-used. Boot scripts load and run libraries as needed. Many libraries are dependent on other libraries, so they call and run them in turn.

Init scripts and libraries are meant to be generic (though more on this later) and as such should not need editing. Boot scripts on the other hand are often intended to be customised. Taking the satellite launch script as an example, there are several global variables at the top of the script that need changing to input the desired orbit parameters.

This is a different approach to others that I've seen, such as having a single boot script that selectively loads scripts to run based on the craft's name. 

##### User input

The scripts were deliberately written to be useful early on in career game of KSP, when action groups are not available. Currently there are two main ways users can interact with a running script:
 * the ABORT button (usually backspace) is used to trigger a change in state. This is used for a launch abort, but also other occasions. For example, if you have rescued a Kerbal and still have empty seats in your vessel, hitting abort will initiate a return to home. 
   - An important thing to note here is that you shouldn't assign any part actions to the abort group, unless those parts have been jettisoned by the time you reach orbit. To be honest, this is an approach I had started to take myself prior to using kOS - jettisoning the rest of the ship from the command module is not something you want triggered midway through a Munar Orbit Insertion burn!
 * target selection. Some scripts will prompt the user to pick a target, chiefly those that require rendezvousing with another craft. If you have rescued a Kerbal and still have empty seats in your vessel, selecting a new target will initiate a new rescue mission. 

There is another form of interaction: kOS part tags. These are only available with the highest tier assembly building, but where used can help simplify some of the boot scripts. For example, the tag "LAUNCHER" is used by the launch script to tell if there are any stages to eject on reaching orbit.

PS. If you're wondering about my "if you have rescued a Kerbal and still have empty seats in your vessel" examples: the flipside is that if you have rescued a Kerbal and now have no seats available, the script will begin a return to Kerbin automatically. Some earlier versions of my scripts included a "hit abort now to remain in orbit" sequence, but I don't think that's available now.

##### Recovery

An important design concept is that every ship should be able to resume what it is currently doing should the processor reboot (following a power loss, change of active vessel, crash or frantic user interaction via the terminal). This is achieved by writing out small files to the local hard drive that contain code to put the craft back into the right state on booting up. In turn this means that anything that cannot easily be calculated and resumed right away must be written to the disk.

Rebooting can be very useful e.g. if a transient orbital prediction miscalculation\* has caused the program to crash, you may want to reboot right away. But if the problem is endemic, rebooting will cause the code to try to do the same bad things over and over. For some situations, the code will revert to a fail mode and require a hit of the ABORT button to go back to executing code, which gives the user time to try to fix whatever the problem was.

\* - This can happen if parts of the calculation get smeared over multiple physics ticks. There is one case where the script will spot that it's about to try to do something impossible (get the inverse COS of a number whose magnitude is greater than 1) and will reboot itself instead, but there may be other cases that aren't caught yet. I've found that some of the underlying KSP predictions seem to have changed behaviour since the upgrade to v1.1.

##### Script editing

Though the code can be rewritten as needed, the ideal is that customisations should be limited to the boot scripts (to tailor them to specific missions and/or craft) - this means that library scripts should be written with as few assumptions as possible. Anything that could vary should either be passed in as a function parameter from the boot script, or exist as a global variable that can be changed by the boot script. For clarity I prefer it if changes to global variables are done through set-up functions rather than altering the variables directly.

### Ship design

Naturally, there are some design assumptions in the code that result from the way I build craft. There are also some restrictions to keep the code relatively simple. Some adaptations are possible.

##### Engine starting / throttling

The scripts assume that all liquid fuel engines can be throttled, can always be restarted and throttle up to maximum thrust immediately. As such, the launch and lander scripts are very much intended for stock KSP and would need a rewrite to handle RO/RSS limitations such as engines that can only fire once and throttles that have limits.

##### Staging

Staging during launch is automatic: every time the thrust drops, a new stage is triggered until the thrust is non-zero. This will stage once to detach SRBs (thrust drops, but not to zero) or twice (or more) if needed to decouple the stage then fire a new set of engines (thrust drops to zero, stays at zero when the decoupler fires). This hasn't been optimised for RO/RSS requirements, but may be in future to handle more complicated staging sequences.

Staging on achieving orbit: I like to keep low orbit free of spent stages. Before action groups are available, this is achieved by building craft where the launcher alone isn't quite powerful enough to put the payload into orbit; the payload completes the circularisation burn while the spent launcher is detached to fall back into the atmosphere. With action groups available, the launcher can put itself and the payload into orbit, then stage to detach itself and fire sepratrons that will put it back onto a sub-orbital trajectory. To this end, once in orbit, the launch script will stage (and continue to stage) as long as any parts tagged "LAUNCHER" are still on the craft. The staging should be set-up so that the launcher is detached, any de-orbit SRBs are triggered and the payload's engines are activated in one go. The latter is required if the payload is intended to do any manouevring - without a working engine the node burning library tends to complain as by default it's not allowed to stage (see Staging during a burn below).

Staging during a burn is supported but optional. In general, it is enabled for launch circularisation but disabled at other times. Enabling staging for some other situations is possible by editing the boot script. Note - it's worth reading the section on burn length calculation below.

Staging during (or more accurately prior to) re-entry is another item that has a default value, but can be overridden by changing the boot script. The default behaviour is to stage once: the assumption being that you have a command module and service module that need separating. To perform the separation without adjusting the current orbit too much, the ship will orient to face normal before staging. If you have more or fewer stages to trigger, this can be changed by modifying the boot script. If action groups are available, the script will continue to stage after the set number of staging events if there are any parts tagged "FINAL" on the craft. Note: should any parachutes accidentally be primed during this process, they will be disarmed if possible.

Other situations: The probe moon lander script and lander ascent libraries are unusual in that they have been written to trigger a stage a few seconds after lifting off. This is very specific to my ship design (and so needs improving) - the staging event is to jettison some landing legs, with the delay existing to try to prevent the legs landing softly enough to leave debris.

##### Abort sequences

The ABORT button (usually backspace) is one of the few ways the script can get input from a user. Effectively, its normal use is overridden, but it can still be used for a launch abort sequence. Launch aborts fall into two main categories:
 * With custom action groups allowed, kOS scripts can (and will) trigger the launch escape system on an abort during launch. To offer a complete automated sequence, the decoupler that attaches the command module to the rest of the rocket should be tagged "FINAL". On hitting abort, kOS will trigger this decoupler and the launch escape system together (as well as killing the throttle), wait, detach the escape tower then deploy parachutes.
 * Without custom action groups, abort sequences such as the above must be triggered manually, aside for the parachutes. Although we could keep staging until only the pod is left, the typical staging sequence for launch will detach the launch escape system as/before it fires, making it useless for an abort.

Note that because of the way the abort button is used, you shouldn't assign any part actions to the abort group, unless those parts have been jettisoned by the time you reach orbit. To be honest, this is an approach I had started to take myself prior to using kOS - jettisoning the rest of the ship from the command module is not something you want triggered midway through a Munar Orbit Insertion burn!

##### Burn length calculation

The functions that calculate how long it will take to burn a manouevre node are able to take into account a single staging event mid-burn. The most likely place for this is during orbital insertion, for early-to-mid-VAB-tier spacecraft where the launcher doesn't have quite enough delta-v to reach orbit. The payload takes over to finalise the burn, while the launcher drops back into the atmosphere. This calculation code is simplified to keep it from growing too large, so there are restrictions.

It tries to find a single liquid-fuel engine that has a decoupler attached that will get rid of the current stage. This works for typical stock KSP rockets (as long as you don't have radial engines) but may not be appropriate for more unusual designs or multiple engines e.g if using something like Space-Y or RO/RSS. If an engine can't be found, a guess is made that the next (full) stage will take 2-3 times longer than the old (almost-empty) stage to provide the required delta-v.

Secondly, though the burn time may be calculated accurately, no attempt is currently made to account for wildly-different thrust levels. If a burn is expected to start off with a Swivel and end with an Ant, you may find that although the burn lasts the predicted length and provides the right amount of delta-v, most of that delta-v will have been produced early on in the burn. This can have undesired results such as pushing out the apoapsis too high then failing to bring the periapsis up out of the atmosphere.

## Boot scripts

TBD - should these be moved to a separate set of readme files, one per script file?

## Init scripts/libraries

TBD - should these be moved to a separate set of readme files, one per script file?

There are currently two initialisation scripts with a shared library and a selector file. Previously, all this code was in a single library, but I felt it was worth separating out the (chunky) code I added for coping with multiple disk volumes to keep the file size down for the simpler version that only uses the local volume.

All the boot scripts start out the first time by running the selector script from the archive. This copies over either "0:/init.ks" (single volume) or "0:/init\_multi.ks" (multiple volumes) to "1:/init.ks". The current method of selection is fairly simple: we loop through all the processors on the craft and count how many there are that
 * are powered up and
 * do not have a boot file set

This means that if you have two kOS CPUs set to run different boot scripts, neither will try to overwrite each other's disks, they will both use the single volume version of init. There would be competition if you had a third, non-booting volume, though: both active CPUs would load the multiple volume version and try to use the third disk as well as their own.

Finally, each boot script then runs "1:/init.ks". So on each subsequent boot after the first, it will go straight to running whatever init script it has locally.

    @LAZYGLOBAL OFF.

    IF NOT EXISTS("1:/init.ks") { RUNPATH("0:/init_select.ks"). }
    RUNONCEPATH("1:/init.ks").

In turn, both of the init scripts will load and run the common library. There is a potential circular dependency here. loadScript() is a function in the init.ks/init\_multi.ks file, but it in turn calls pOut(), a printing function in the init\_common.ks library. We can't use pOut() until we've actually run the common library. To solve this we make use of an extra parameter in the loadScript() function, loud_mode. By passing in false, we disable the usual printing and logging that the loadScript() function does. Not all printing is disabled: if there were an error, this is still printed. That happens on the grounds that we were going to crash anyway, if we couldn't load a file (e.g. due to lack of space).

The init\_common.ks library triggers quite a few pieces of code as well as adding a suite of library functions. If timewarp was active when we booted up (which can happen if we run out of electrical power during time warp), this is disabled. We also wait for the ship to be unpacked:

    IF WARP <> 0 { SET WARP TO 0. }
    WAIT UNTIL SHIP:UNPACKED.

We initialise the staging timer with the current time. This is often used for checks such as "has it been more than x seconds since we last staged" to guide whether it's okay to stage again and for certain actions e.g. we want to wait for about 5 seconds after triggering the launch escape system, then jettison it.

    setTime("STAGE").

We have the capability of running a ship-specific script. This uses the ship's name to determine which file to try loading, but note that it searches the craft sub-directory of /Ships/scripts. If this exists, it is copied to "1:/craft.ks" and run. On a subsequent boot, we check first to see if we already have a craft-specific file and if so go straight to running it:

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

#### RESUME\_FN

The filename of the main resume file. The default filename is resume.ks.

This is used to store commands to be run to recover a previous state following a reboot. The reason for doing this is to store a function call and all its parameters, so that we can resume (fairly) seamlessly during complicated functions such as doLaunch(), doReentry() etc.

#### VOLUME\_NAMES (init\_multi.ks only)

A list of available volume names. By default this is an empty list, though this is quickly populated by running listVolumes(). Practically, the real default value is a list containing the local volume, which gets renamed "Disk0".

This is used to store the names of all the disks we think we have access to. Various init\_multi.ks functions rely on being able to loop through this list.

#### pad2Z() and pad3Z()

Function delegates. These will turn the input value into a string, pad the left-hand side with spaces until the length is 2 or 3 characters then replace all spaces with zeroes. Used as part of the function that generates a pretty Mission Elapsed Time for printed and logged messages.

padRep is short for pad-and-replace.

#### TIMES

Various scripts need to keep track of their own times (time since staging, time since changing runmode, time to warp to, etc.) and there exist common functions to allow this. The times are stored in this lexicon.

#### LOG\_FILE

The path of the log file we will write to if doLog() gets called. If set to "" (the initial value), no logging will take place.

#### g0

Standard gravity, 9.08665m/s^2

#### INIT\_MET\_TS and INIT\_MET

INIT\_MET\_TS stores the value of the Mission Elapsed Time when we last calculated the pretty-formatted version.
INIT\_MET stores the last, calculated, pretty-formatted Mission Elapsed Time. 

The pretty-formatted Mission Elapsed Time need not be recalculated until the next second has passed, which helps if trying to print out a lot of messages in quick succession.

#### stageTime()

A function delegate. This returns the time elapsed since the "STAGE" time was updated, which should either be the time since boot or the time since the last staging event.

#### CRAFT\_SPECIFIC

This is a lexicon. The idea is that craft-specific files can insert values (and even functions) into here for use elsewhere. Currently nothing has actually been implemented. There are some suggested uses in issue #55.

#### CRAFT\_FILE

The path of the locally-stored craft-specific file, if one exists.

### Function reference

#### loadScript(script\_name, loud\_mode)

This tries to copy script\_name from the archive to one of the disk volumes on the ship. init.ks uses the processor's local volume ("1:/"), but init\_multi.ks will loop through the available volumes (starting with "1:/") until it finds one that has enough space to store the script being copied. If the file already exists, it does not re-copy the file.

This will crash kOS if the file needs to be copied over but there is not enough space to store the file (currently it is assumed that we want to stop and debug - if we are missing a library then chances are we will crash shortly anyway).

Returns the full file path for where the script is on a local volume. This is meant to be plugged into RUNPATH e.g.

    RUNONCEPATH(loadScript(script_name)).

Loud mode defaults to true, that is it will print out what it is doing. Passing in loud_mode as false will prevent it from printing.

#### delScript(script\_name)

This tries to delete script_name from the local disk volume(s). 

It will only delete one copy - it is assumed that anything being deleted will have been added via the loadScript() function, which avoids duplicate copies. Similarly, it won't go hunting in sub-directories, as loadScript() does not create those.

If the file does not exist, nothing happens.

#### delResume(file\_name)

Tries to delete file\_name from the local volume(s).

The default file\_name is RESUME_FN.

If the file does not exist, nothing happens.

#### store(text, file\_name, file\_size\_required)

This logs text to file\_name on the local volume. The default file\_name is RESUME_FN.

There is a difference in behaviour between init.ks and init\_multi.ks. init.ks simply uses the local volume, but init\_multi.ks will try to find a volume with enough free space: there must be file\_size\_required bytes available. The default file\_size\_required is 150 bytes.

Will crash kOS if it tries to write out too large a file to fit on the local volume.

#### append(text, file\_name)

Tries to append text to file\_name.

The default file\_name is RESUME_FN.

Will crash kOS if file\_name does not exist anywhere on the local volume.

#### resume(file\_name)

Tries to run file\_name.

The default file\_name is RESUME_FN.

If file\_name does not exist, nothing happens.

#### setVolumeList(list\_of\_volume\_names) (init\_multi.ks only)

Overwrites the VOLUME\_NAMES global list with the passed-in list, then calls pVolume() to dump out the list of volumes.

This is intended for boot scripts/craft-specific scripts to set-up a specific list of volumes for a processor to use, rather than relying on the search done on initialisation, for cases where that search fails to pick up some drives, or finds too many.

#### listVolumes() (init\_multi.ks only)

This function is run once on start-up. It will populate VOLUME\_NAMES with a list of available volumes.

The function will start by renaming the local volume "Disk0" if it doesn't already have a name, then set VOLUME\_NAMES to a list containing just the name of this local volume. As far as I can tell, volumes typically start off with no name at all.

Next, it loops through all the processors on the vessel, checking their volumes to see if they should be added to the list. Volumes are added if they:
 * are powered up and
 * do not have a boot file set
 * do not have a volume name that equals that of the local volume

These checks are designed to prevent the current volume from being added twice and from including any volumes that are in use by another processor. If you have a vessel with two CPUs it may be because you intend to divide it into two at some point, so giving each one a boot file prevents once CPU from trying to use the other's disk.

Before being added to the list, each volume is renamed if it doesn't already have a name. Names are generated numerically: "Disk1", "Disk2" etc.

#### pVolumes() (init\_multi.ks only)

Prints out all the volumes that have been named in VOLUME\_NAMES, including how much free space each one has.

#### findPath(file\_name) (init\_multi.ks only)

Loops through the volumes names in VOLUME\_NAMES, looking to see if file\_name exists on the root directory of that volume.

Returns the filepath if it can find the file, "" otherwise.

Note that currently this does not search sub-directories within volumes.

#### findSpace(file\_name, minimum\_free\_space) (init\_multi.ks only)

Loops through the volumes names in VOLUME\_NAMES, looking to see if that volume has more bytes of free space available than the parameter minimum\_free\_space.

Returns the full filepath (including file\_name) if it can find a volume with enough space. Otherwise it'll print out an error, call pVolumes() so you can see what space is avaible and return "".

#### TBD - add in the commands in init_common.ks.

## Libraries

TBD - should these be moved to a separate set of readme files, one per script file?

