@LAZYGLOBAL OFF.

IF NOT EXISTS("1:/init.ks") {
  WAIT UNTIL HOMECONNECTION:ISCONNECTED.
  RUNPATH("0:/init_select.ks").
}
RUNONCEPATH("1:/init.ks").

pOut("node.ks v1.0.2 20170106").

RUNONCEPATH(loadScript("lib_burn.ks")).
execNode(FALSE).
