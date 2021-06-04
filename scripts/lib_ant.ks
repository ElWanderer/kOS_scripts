@LAZYGLOBAL OFF.
pOut("lib_ant.ks v1.1.0 20170117").

RUNONCEPATH(loadScript("lib_parts.ks")).

GLOBAL ANT_TX_MOD IS "ModuleDataTransmitter".
GLOBAL ANT_ANIM_MOD IS "ModuleDeployableAntenna".

GLOBAL antCommStatus IS partModField@:BIND("Antenna State",ANT_TX_MOD).
GLOBAL antAnimStatus IS partModField@:BIND("Status",ANT_ANIM_MOD).
GLOBAL antExtend IS partEvent@:BIND("Extend Antenna",ANT_ANIM_MOD).
GLOBAL antRetract IS partEvent@:BIND("Retract Antenna",ANT_ANIM_MOD).

FUNCTION antIdle {
  PARAMETER p.
  WAIT UNTIL LIST("Extended","Retracted"):CONTAINS(antAnimStatus(p)) AND antCommStatus(p) = "Idle".
}

FUNCTION doAllAnt {
  PARAMETER fl.
  FOR m IN SHIP:MODULESNAMED(ANT_ANIM_MOD) { FOR f IN fl { f(m:PART). } }
}

FUNCTION extendAllAntennae {
  doAllAnt(LIST(antIdle@,antExtend,antIdle@)).
}

FUNCTION retractAllAntennae {
  doAllAnt(LIST(antIdle@,antRetract,antIdle@)).
}
