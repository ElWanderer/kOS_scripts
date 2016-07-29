@LAZYGLOBAL OFF.

pOut("lib_science.ks v1.0 20160714").

GLOBAL scienceList IS LIST().
GLOBAL POWER_REQ IS 250.

FUNCTION changePOWER_REQ
{
  PARAMETER p.
  SET POWER_REQ TO p.
}

FUNCTION listScienceModules

{
  SET scienceList TO SHIP:MODULESNAMED("ModuleScienceExperiment").
}

FUNCTION powerOkay
{
  LOCAL ec0 IS SHIP:ELECTRICCHARGE.
  WAIT 1.
  LOCAL ec1 IS SHIP:ELECTRICCHARGE.
  LOCAL pa IS ec1 + ((ec1-ec0) * 10).
  RETURN pa >= POWER_REQ.
}

FUNCTION resetMod
{
  PARAMETER m.
  m:RESET.
  WAIT UNTIL NOT m:DEPLOYED.
}

FUNCTION doMod
{
  PARAMETER m.
  m:DEPLOY.
  WAIT UNTIL m:HASDATA.
}

FUNCTION txMod
{
  PARAMETER m.
  WAIT UNTIL powerOkay().
  m:TRANSMIT.
  WAIT 10.
}

FUNCTION doScience
{
  PARAMETER one_use, overwrite.

  FOR m IN scienceList { IF NOT m:INOPERABLE AND (m:RERUNNABLE OR one_use) {
    IF m:DEPLOYED AND overwrite { resetMod(m). }
    IF NOT m:DEPLOYED { doMod(m). }
  }}
}

FUNCTION transmitScience
{
  PARAMETER one_use, wait_for_power.

  FOR m IN scienceList { IF m:HASDATA AND (m:RERUNNABLE OR one_use) {
    IF wait_for_power OR powerOkay() { txMod(m). }
  }}
}

FUNCTION resetScience
{
  FOR m IN scienceList { IF m:DEPLOYED AND NOT m:INOPERABLE { resetMod(m). } }
}

listScienceModules().