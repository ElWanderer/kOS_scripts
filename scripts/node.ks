@LAZYGLOBAL OFF.

COPYPATH("0:/init.ks","1:/init.ks").
RUNONCEPATH("1:/init.ks").

pOut("node.ks v1.0 20160714").

RUNONCEPATH(loadScript("lib_burn.ks")).
ExecNode(FALSE).