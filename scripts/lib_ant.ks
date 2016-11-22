@LAZYGLOBAL OFF.
pOut("lib_ant.ks v1.0.0 20161110").

RUNONCEPATH(loadScript("lib_parts.ks")).

GLOBAL ANT_TX_MOD IS "ModuleDataTransmitter".
GLOBAL ANT_ANIM_MOD IS "ModuleAnimateGeneric".

GLOBAL antCommStatus IS partModField@:BIND("Comm",ANT_TX_MOD).
GLOBAL antAnimStatus IS partModField@:BIND("Status",ANT_ANIM_MOD).
GLOBAL antExtend IS partEvent@:BIND("Extend",ANT_ANIM_MOD).
GLOBAL antRetract IS partEvent@:BIND("Retract",ANT_ANIM_MOD).

FUNCTION waitUntilIdle {
  PARAMETER p.
  WAIT UNTIL antAnimStatus(p) <> "Moving..." AND antCommStatus(p) = "Idle".
}

FUNCTION antToggle {
  PARAMETER p.
  RETURN antExtend(p) OR antRetract(p).
}

FUNCTION doAllAnt {
  PARAMETER fl.
  FOR m IN SHIP:MODULESNAMED(ANT_TX_MOD) { FOR f IN fl { f(m:PART). } }
}

FUNCTION extendAllAntennae {
  doAllAnt(LIST(waitUntilIdle@,antExtend,waitUntilIdle@)).
}
