@LAZYGLOBAL OFF.

IF NOT EXISTS("1:/init.ks") { RUNPATH("0:/init_select.ks"). }
RUNONCEPATH("1:/init.ks").

pOut("reentry.ks v1.0.0 20200921").
FOR f IN LIST(
  "lib_burn.ks",
  "lib_reentry.ks"
) { RUNONCEPATH(loadScript(f)). }

IF (PERIAPSIS >= BODY:ATM:HEIGHT) {
  IF deorbitNode() { execNode(FALSE). }
}

IF (PERIAPSIS < BODY:ATM:HEIGHT) {
  doReentry(0,99).
} ELSE {
  pout("Cannot run re-entry. Periapsis is not below atmosphere height").
}

