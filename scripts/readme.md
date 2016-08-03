The current script file layout is as follows:

Boot directory:
* each file corresponds to one mission e.g. putting a satellite into a specific orbit of Kerbin.

Init files:
* init.ks - single CPU initialisation. Basic file-handling copies everything to volume 1.
* init_multi.ks - multi-CPU initilisation. File-handling will use any disk volume (with some exceptions)
* init\_common.ks - pulled in by init and init\_multi. Common functions.

Libraries:
* lib_xxx - library files, pulled in as needed.


ElWanderer / Geoff Banks
