@LAZYGLOBAL OFF.


pOut("lib_chutes.ks v1.2.2 20160728").

GLOBAL CHUTE_LIST IS LIST().
GLOBAL CHUTE_ACT IS TRUE.

FUNCTION doDeploy
{
  PARAMETER m.
  pOut("Deploying: " + m:PART:TITLE).
  m:DOEVENT("Deploy Chute").
  SET CHUTE_ACT TO TRUE.
}

FUNCTION canDeploy
{
  PARAMETER m.
  RETURN m:HASEVENT("Deploy Chute").
}

FUNCTION safeToDeploy
{
  PARAMETER m.
  RETURN m:GETFIELD("Safe To Deploy?")="Safe".
}

FUNCTION doDisarm
{
  PARAMETER m.
  pOut("Disarming: " + m:PART:TITLE).
  m:DOEVENT("Disarm").
  SET CHUTE_ACT TO TRUE.
}

FUNCTION canDisarm
{
  PARAMETER m.
  RETURN m:HASEVENT("Disarm").
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
    pOut(" " + m:PART:TITLE + ". Deployable: " + canDeploy(m)).
    IF all OR canDeploy(m) { CHUTE_LIST:ADD(m). }
  }
  SET CHUTE_ACT TO FALSE.
}

FUNCTION deployChutes
{
  IF ALTITUDE < BODY:ATM:HEIGHT AND VERTICALSPEED < 0 {
    FOR m IN CHUTE_LIST { IF canDeploy(m) AND safeToDeploy(m) { doDeploy(m). } }
    IF CHUTE_ACT { listChutes(). }
  }
}

FUNCTION disarmChutes
{
  listChutes(TRUE).
  FOR m IN CHUTE_LIST { IF canDisarm(m) { doDisarm(m). } }
  IF CHUTE_ACT { listChutes(). }
}

listChutes(TRUE).