#Scripts

The current script file layout is as follows:

### Boot directory
* each file corresponds to one mission e.g. putting a satellite into a specific orbit of Kerbin.

### Init files
* `init.ks` - single CPU initialisation. Basic file-handling copies everything to volume 1.
* `init_multi.ks` - multi-CPU initilisation. File-handling will use any disk volume (with some exceptions)
* `init_common.ks` - pulled in by init and init\_multi. Common functions.
* `init_select.ks` - run once on first boot to determine whether to load `init.ks` or `init_multi.ks`

### Libraries
* `lib_xxx.ks` - library files, pulled in as needed.

## Further reading
Most of the script files are deliberately light on comments (and descriptive variable names) to keep the file sizes low. Documentation is provided in the separate `../documentation` directory.

Geoff Banks / ElWanderer
