## node.ks & node\_rcs.ks (miscellaneous - node executor scripts)

These short, miscellaneous scripts will automatically burn the next manoeuvre node when called. This is useful for manually commanding a vessel but leaving the flying to the computer - you can set-up manoeuvre nodes yourself then run a script to execute them.

Similar to boot scripts, these will run the local `init.ks` script if one exists, otherwise they will create one by running `0:/init_select.ks` (note - they now wait for a connection back to the KSC before trying to access the archive). 

`node.ks`:
This script runs the `lib_burn.ks` library, which allows it to call `execNode()`. By default, staging is disallowed.

`node_rcs.ks`:
This script runs the `lib_rcs_burn.ks` library, which allows it to call `rcsExecNode()`.

Geoff Banks / ElWanderer
