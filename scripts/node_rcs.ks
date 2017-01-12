@LAZYGLOBAL OFF.

IF NOT EXISTS("1:/init.ks") {
  WAIT UNTIL HOMECONNECTION:ISCONNECTED.
  RUNPATH("0:/init_select.ks").
}
RUNONCEPATH("1:/init.ks").

pOut("rcs_node.ks v1.1.0 20170112").

RUNONCEPATH(loadScript("lib_rcs_burn.ks")).
rcsExecNode().
