@LAZYGLOBAL OFF.
pOut("lib_chutes.ks v1.2.3 20160831").

RUNONCEPATH(loadScript("lib_parts.ks")).

GLOBAL CHUTE_LIST IS LIST().

GLOBAL canDeploy IS canEvent@:BIND("Deploy Chute").
GLOBAL doDeploy IS modEvent@:BIND("Deploy Chute").
GLOBAL canDisarm IS canEvent@:BIND("Disarm").
GLOBAL doDisarm IS modEvent@:BIND("Disarm").

FUNCTION safeToDeploy
{
  PARAMETER m.
  RETURN m:GETFIELD("Safe To Deploy?")="Safe".
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
  pOut("Counting parachutes.").
  FOR m IN SHIP:MODULESNAMED("ModuleParachute") {
    pOut(" " + m:PART:TITLE + ". Deployable: " + canDeploy(m),FALSE).
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
  listChutes(TRUE).
  LOCAL act IS FALSE.
  FOR m IN CHUTE_LIST { IF canDisarm(m) { doDisarm(m). SET act TO TRUE. } }
  IF act { listChutes(). }
}

listChutes(TRUE).
