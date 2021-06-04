@LAZYGLOBAL OFF.

IF NOT EXISTS("1:/init.ks") {
  WAIT UNTIL HOMECONNECTION:ISCONNECTED.
  RUNPATH("0:/init_select.ks").
}
RUNONCEPATH("1:/init.ks").

pOut("dv.ks v1.0.0 20201030").

RUNONCEPATH(loadScript("lib_dv.ks")).
RUNONCEPATH(loadScript("lib_rcs_burn.ks")).

pDV().
rcsPDV().