@LAZYGLOBAL OFF.

IF NOT EXISTS("1:/init.ks") { RUNPATH("0:/init_select.ks"). }
RUNONCEPATH("1:/init.ks").

pOut("science.ks v1.0.0 20200909").
FOR f IN LIST(
  "lib_steer.ks",
  "lib_probe.ks"
) { RUNONCEPATH(loadScript(f)). }

visitContractWaypoints(7,15).
