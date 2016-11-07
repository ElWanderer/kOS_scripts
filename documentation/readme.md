# kOS_scripts documentation 

## Introduction

### Background

As with a lot of new kOS programmers, I started out by writing simple launch scripts. Once comfortable, I began developing a suite of libraries and boot scripts. There were two main drivers:
 * automating contracts such as tourist flights and satellite launches
 * learning and implementing interesting bits of orbital mechanics

There are many, many things that can be automated in Kerbal Space Program, so this is ongoing and probably never-ending work! I had always intended to make the scripts public once I got them to a high-enough standard. That isn't really the case at the time of writing, but the v1.0.0 pre-release of kOS prompted me to start putting the code online and documenting it properly. Being on Github, it means others could see and use the code, or even contribute to it.

The code is written to work with kOS v1.0.1 / KSP 1.1.3.

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

The scripts were deliberately written to be useful early on in career game of KSP, when action groups are not available (though it seems the abort group may not be available so early once KSP reaches v1.2). Currently there are two main ways users can interact with a running script:
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

The ABORT button (usually backspace) is one of the few ways the script can get input from a user (it seems this may not be the case once KSP reaches v1.2). Effectively, its normal use is overridden, but it can still be used for a launch abort sequence. Launch aborts fall into two main categories:
 * With custom action groups allowed, kOS scripts can (and will) trigger the launch escape system on an abort during launch. To offer a complete automated sequence, the decoupler that attaches the command module to the rest of the rocket should be tagged "FINAL". On hitting abort, kOS will trigger this decoupler and the launch escape system together (as well as killing the throttle), wait, detach the escape tower then deploy parachutes.
 * Without custom action groups, abort sequences such as the above must be triggered manually, aside for the parachutes. Although we could keep staging until only the pod is left, the typical staging sequence for launch will detach the launch escape system as/before it fires, making it useless for an abort.

Note that because of the way the abort button is used, you shouldn't assign any part actions to the abort group, unless those parts have been jettisoned by the time you reach orbit. To be honest, this is an approach I had started to take myself prior to using kOS - jettisoning the rest of the ship from the command module is not something you want triggered midway through a Munar Orbit Insertion burn!

##### Burn length calculation

The functions that calculate how long it will take to burn a manouevre node are able to take into account a single staging event mid-burn. The most likely place for this is during orbital insertion, for early-to-mid-VAB-tier spacecraft where the launcher doesn't have quite enough delta-v to reach orbit. The payload takes over to finalise the burn, while the launcher drops back into the atmosphere. This calculation code is simplified to keep it from growing too large, so there are restrictions.

It tries to find a single liquid-fuel engine that has a decoupler attached that will get rid of the current stage. This works for typical stock KSP rockets (as long as you don't have radial engines) but may not be appropriate for more unusual designs or multiple engines e.g if using something like Space-Y or RO/RSS. If an engine can't be found, a guess is made that the next (full) stage will take 2-3 times longer than the old (almost-empty) stage to provide the required delta-v.

Secondly, though the burn time may be calculated accurately, no attempt is currently made to account for wildly-different thrust levels. If a burn is expected to start off with a Swivel and end with an Ant, you may find that although the burn lasts the predicted length and provides the right amount of delta-v, most of that delta-v will have been produced early on in the burn. This can have undesired results such as pushing out the apoapsis too high then failing to bring the periapsis up out of the atmosphere.

## Boot scripts

Being documented in separate files (`boot_FILE_NAME_readme.md`).

## Init scripts/libraries

[Documented together in a single file](https://github.com/ElWanderer/kOS_scripts/blob/master/documentation/init_readme.md)

## Libraries

Being documented in separate files (`lib_LIBNAME_readme.md`).

## Miscellaneous files

There is the occasional odd script file that is useful for manual control / testing. These are being documented in separate files (`FILE_NAME_readme.md`).

### "Comment": Issues found during documentation

The good thing about documenting code is that in trying to explain it, you often spot problems you hadn't noticed before. I'm spotting all kinds of issues of varying degrees that are being bundled together in [a single Github Issue](https://github.com/ElWanderer/kOS_scripts/issues/68). If you run across the phrase "Comment - " in a readme file, this should have a corresponding open entry in that issue. These comments should be removed as and when the issues are tackled.

Geoff Banks / ElWanderer
