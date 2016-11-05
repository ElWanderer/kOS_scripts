## node.ks (miscellaneous - node executor script)

This short, miscellaneous script will automatically burn the next manoeuvre node when called. This is useful for manually commanding a vessel but leaving the flying to the computer - you can set-up manoeuvre nodes yourself then run the script to execute them.

Similar to boot scripts, it will run the local `init.ks` script if one exists, otherwise it will create one by running `0:/init_select.ks`. It will then run the `lib_burn.ks` library. This allows it to call `execNode()`. By default, staging is disallowed.

Geoff Banks / ElWanderer
