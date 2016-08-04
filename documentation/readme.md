# kOS_scripts documentation 

## Introduction

### Background

As with a lot of new kOS programmers, I started out by writing simple launch scripts. Once comfortable, I began developing a suite of libraries and boot scripts. There were two main drivers:
 * automating contracts such as tourist flights and satellite launches
 * learning and implementing interesting bits of orbital mechanics

There are many, many things that can be automated in Kerbal Space Program, so this is ongoing and probably never-ending work! I had always intended to make the scripts public once I got them to a high-enough standard. That isn't really the case at the time of writing, but the v1.0.0 pre-release of kOS prompted me to start putting the code online and documenting it properly. Being on Github, it means others could see and use the code, or even contribute to it. 

### Core concepts

##### File handling

The scripts are written with the assumption that they will be copied onto a craft's local hard drive, rather than being run directly from the archive. 

Currently the script files are split into three different types, though two of these are almost identical:
 * boot scripts
 * init scripts
 * library scripts

Each boot script represents a mission, such as placing a satellite into orbit. Each one calls an init script (there are now two with a common library, but this is a very recent development) that sets up a common set of functions for loading libraries, plus some functions that are commonly-used. Boot scripts load and run libraries as needed. Many libraries are dependent on other libraries, so they call and run them in turn.

Init scripts and libraries are meant to be generic (though more on this later) and as such should not need editing. Boot scripts on the other hand are often intended to be customised. Taking the satellite launch script as an example, there are several global variables at the top of the script that need changing to input the desired orbit parameters.

This is a different approach to others that I've seen, such as having a single boot script that selectively loads scripts to run based on the craft's name. 

##### User input

The scripts were deliberately written to be useful early on in career game of KSP, when action groups are not available. Currently there are two main ways users can interact with a running script:
 * the ABORT button (usually backspace) is used to trigger a change in state. This is used for a launch abort, but also other occasions. For example, if you have rescued a Kerbal and still have empty seats in your vessel, hitting abort will initiate a return to home. An important thing to note here is that you shouldn't assign any part actions to the abort group, unless those parts have been jettisoned by the time you reach orbit.
 * target selection. Some scripts will prompt the user to pick a target, chiefly those for rescuing Kerbals. If you have rescued a Kerbal and still have empty seats in your vessel, selecting a new target will initiate a new rescue mission. 

There is another form of interaction: kOS part tags. These are only available with the highest tier assembly building, but where used can help simplify some of the boot scripts. For example, the tag "LAUNCHER" is used by the launch script to tell if there are any stages to eject on reaching orbit. 

##### Recovery

An important design concept is that every ship should be able to resume what it is currently doing should the processor reboot (following a power loss, change of active vessel, crash or frantic user interaction via the terminal). This is achieved by writing out small files to the local hard drive that contain code to put the craft into the right state. In turn this means that anything that cannot easily be calculated and resumed must be written to the disk.

