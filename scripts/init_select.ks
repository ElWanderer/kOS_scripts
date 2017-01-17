@LAZYGLOBAL OFF.
//"init_select.ks v1.1.0 20170117"
// this lives on the archive, run it once on start-up to copy
// either "0:/init.ks" or "0/init_multi.ks" to "1:/init.ks"

copyOverInit().

FUNCTION countDisks
{
  LOCAL cp IS CORE:PART.
  LOCAL disk_count IS 1.
  LOCAL pl IS LIST().
  LIST PROCESSORS IN pl.
  FOR p IN pl {
    IF p:MODE = "READY" AND p:BOOTFILENAME = "None" AND p:UID <> cp:UID AND
       ((p:TAG = "" AND cp:TAG = "MULTI") OR (p:TAG = cp:TAG AND cp:TAG <> "MULTI")) {
      SET disk_count TO disk_count + 1.
    }
  }
  RETURN disk_count.
}

FUNCTION copyOverInit
{
  LOCAL cp IS CORE:PART.
  IF cp:TAG = "MULTI" OR (countDisks() > 1 AND cp:TAG <> "SINGLE") {
    HUDTEXT("Copying 0:/init_multi.ks.", 3, 2, 40, YELLOW, FALSE).
    COPYPATH("0:/init_multi.ks","1:/init.ks").
  } ELSE {
    HUDTEXT("Copying 0:/init.ks.", 3, 2, 40, YELLOW, FALSE).
    COPYPATH("0:/init.ks","1:/init.ks").
  }
}
