@LAZYGLOBAL OFF.

IF NOT EXISTS("1:/init.ks") {
  WAIT UNTIL HOMECONNECTION:ISCONNECTED.
  RUNPATH("0:/init_select.ks").
}
RUNONCEPATH("1:/init.ks").

pOut("rdz_nodock.ks v1.0.0 20210108").

FOR f IN LIST(
  "lib_runmode.ks",
  "lib_steer.ks",
  "lib_rendezvous.ks"
) { RUNONCEPATH(loadScript(f)). }

FUNCTION validTarget {
  RETURN HASTARGET AND TARGET:OBT:BODY = BODY.
}

IF NOT validTarget() {
  hudMsg("Please select a target").
  pOut("Waiting.").
  WAIT UNTIL validTarget().
}

LOCAL rm IS runMode().

IF (rm > 400 AND rm < 450) {
  resume().
} ELSE IF (TARGET:POSITION:MAG > 500) {

  store("changeRDZ_DIST(50).").
  append("doRendezvous(runMode(),VESSEL(" + CHAR(34) + TARGET:NAME + CHAR(34) + "),FALSE).").

  changeRDZ_DIST(50).
  doRendezvous(runMode(),TARGET,FALSE).

  delResume().
  steerNormal().
  pOut("Rendezvous complete.").
}