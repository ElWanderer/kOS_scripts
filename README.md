# kOS_scripts
kOS scripts and libraries

Written for kOS v1 (pre) and KSP v1.1.3.

Well, most of the code has been written in kOS v0.17-v0.19, but I've updated it for the pre-release version of kOS v1. In particular, the file-handling uses commands that didn't exist before, so it would need adjusting to work with earlier versions.

The current script file layout is as follows:

Boot directory - each file corresponds to one mission e.g. putting a satellite into a specific orbit of Kerbin.

Init files:

init.ks - single CPU initialisation. Basic file-handling copies everything to volume 1.
init_multi.ks - multi-CPU initilisation. File-handling will use any disk volume (with some exceptions)
init_common.ks - pulled in by init and init_multi. Common functions.

Libraries:

lib_xxx - library files, pulled in as needed.


ElWanderer / Geoff Banks
