@LAZYGLOBAL OFF.

IF NOT EXISTS("1:/init.ks") { RUNPATH("0:/init_select.ks"). }
RUNONCEPATH("1:/init.ks").

pOut("reentry.ks v1.0.0 20200921").
FOR f IN LIST(
  "lib_lander_descent.ks"
) { RUNONCEPATH(loadScript(f)). }

SAS OFF.

initDescentValues(0,0,0).

steerTo(retrogradeVec@).

doSuicideBurn().
doSetDown().