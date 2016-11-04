@LAZYGLOBAL OFF.

IF NOT EXISTS("1:/init.ks") { RUNPATH("0:/init_select.ks"). }
RUNONCEPATH("1:/init.ks").

pOut("node.ks v1.0.1 20161104").

RUNONCEPATH(loadScript("lib_burn.ks")).
ExecNode(FALSE).
