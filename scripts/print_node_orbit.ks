@LAZYGLOBAL OFF.

IF NOT EXISTS("1:/init.ks") { RUNPATH("0:/init_select.ks"). }
RUNONCEPATH("1:/init.ks").

pOut("print_node_orbit.ks v1.0.0 20210108").

FOR f IN LIST(
  "lib_node.ks"
) { RUNONCEPATH(loadScript(f)). }

IF HASNODE {
  pOrbit(NEXTNODE:ORBIT).
} ELSE {
  pOrbit(SHIP:ORBIT).
}