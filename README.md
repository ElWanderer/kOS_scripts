# kOS_scripts
kOS scripts and libraries

The current file layout is as follows:
Boot - each file corresponds to one mission e.g. putting a satellite into a specific orbit of Kerbin.
init.ks - single CPU initialisation. Basic file-handling copies everything to volume 1.
init-multi.ks - multi-CPU initilisation. File-handling will use any disk volume (with some excetions)
init_common.ks - pulled in by init and init_multi. Common functions.
lib_xxx - library files, pulled in as needed.


ElWanderer / Geoff Banks
