#Scripts

The current script file layout is as follows:

### Boot directory
* each file corresponds to one mission e.g. putting a satellite into a specific orbit of Kerbin.

### Init files
* init.ks - single CPU initialisation. Basic file-handling copies everything to volume 1.
* init\_multi.ks - multi-CPU initilisation. File-handling will use any disk volume (with some exceptions)
* init\_common.ks - pulled in by init and init\_multi. Common functions.
* init\_select.ks - run once on first boot to determine whether to load init.ks or init\_multi.ks

### Libraries
* lib_xxx - library files, pulled in as needed.

## Further reading
Most of the script files are deliberately light on comments (and descriptive variable names) to keep the file sizes low. Documentation will be provided in the separate ../documentation directory. At the time of writing, this is partially incomplete - issue #24 exists for completing this.

Geoff Banks / ElWanderer
