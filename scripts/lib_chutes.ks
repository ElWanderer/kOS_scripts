@LAZYGLOBAL OFF.
pOut("lib_chutes.ks v1.4.0 20171212").

RUNONCEPATH(loadScript("lib_parts.ks")).

GLOBAL CHUTE_LIST IS LIST().

GLOBAL canDeploy IS canEvent@:BIND("Deploy Chute").
GLOBAL doDeploy IS modEvent@:BIND("Deploy Chute").
GLOBAL canDisarm IS canEvent@:BIND("Disarm").
GLOBAL doDisarm IS modEvent@:BIND("Disarm").

FUNCTION safeToDeploy
{
  PARAMETER m.
  RETURN modField("Safe To Deploy?",m)="Safe".
}

FUNCTION hasChutes
{
  RETURN CHUTE_LIST:LENGTH > 0.
}

FUNCTION listChutes
{
  PARAMETER all IS FALSE.
  WAIT 0.
  CHUTE_LIST:CLEAR.
  pOut("Counting parachutes:").
  FOR m IN SHIP:MODULESNAMED("ModuleParachute") {
    pOut(m:PART:TITLE + ". Deployable: " + canDeploy(m) + ". Disarmable: " + canDisarm(m),FALSE).
    IF all OR canDeploy(m) { CHUTE_LIST:ADD(m). }
  }
}

FUNCTION deployChutes
{
  LOCAL act IS FALSE.
  IF ALTITUDE < BODY:ATM:HEIGHT AND VERTICALSPEED < 0 { FOR m IN CHUTE_LIST {
    IF canDeploy(m) AND safeToDeploy(m) { doDeploy(m). SET act TO TRUE. }
  } }
  IF act { listChutes(). }
}

FUNCTION disarmChutes
{
  PARAMETER do_all IS TRUE.
  listChutes(TRUE).
  FOR m IN CHUTE_LIST { IF canDisarm(m) AND (do_all OR modField("Deploy Mode", m) <> "0") { doDisarm(m). } }
  listChutes().
}

listChutes(TRUE).
