@LAZYGLOBAL OFF.
//"init_select.ks v1.0.0 20160902"
// this lives on the archive, run it once on start-up to copy
// either "0:/init.ks" or "0/init_multi.ks" to "1:/init.ks"

PRINT "Initialising.".
copyOverInit().

FUNCTION copyOverInit
{
  LOCAL disk_count IS 1.
  LOCAL pl IS LIST().
  LIST PROCESSORS IN pl.
  FOR p IN pl {
    IF p:MODE = "READY" AND p:BOOTFILENAME = "None" AND p:VOLUME:NAME <> CORE:CURRENTVOLUME:NAME {
      SET disk_count TO disk_count + 1.
    }
  }

  IF disk_count > 1 {
    PRINT "Copying 0:/init_multi.ks".
    COPYPATH("0:/init_multi.ks","1:/init.ks").
  } ELSE {
    PRINT "Copying 0:/init.ks".
    COPYPATH("0:/init.ks","1:/init.ks").
  }
}
