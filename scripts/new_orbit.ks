@LAZYGLOBAL OFF.

IF NOT EXISTS("1:/init.ks") { RUNPATH("0:/init_select.ks"). }
RUNONCEPATH("1:/init.ks").

pOut("new_orbit.ks v1.0.0 20201110").

FOR f IN LIST(
  "lib_steer.ks",
  "lib_orbit_change.ks",
  "lib_orbit_match.ks"
) { RUNONCEPATH(loadScript(f)). }

GLOBAL SAT_AP IS 938667.
GLOBAL SAT_PE IS 529001.
GLOBAL SAT_I IS 167.
GLOBAL SAT_LAN IS 199.3.
GLOBAL SAT_W IS 98.6.

IF doOrbitChange(FALSE,stageDV(),SAT_AP,SAT_PE,SAT_W,SAT_LAN) {
  doOrbitMatch(FALSE,stageDV(),SAT_I,SAT_LAN).
}
