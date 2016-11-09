@LAZYGLOBAL OFF.
pOut("lib_science.ks v1.1.0 20161109").

GLOBAL SCI_LIST IS LIST().
GLOBAL SCI_MIN_POW IS 10.
GLOBAL SCI_MIT_RATE IS 3.
GLOBAL SCI_EC_PER_MIT IS 6.

listScienceModules().

FUNCTION listScienceModules
{
  SET SCI_LIST TO SHIP:MODULESNAMED("ModuleScienceExperiment").
}

FUNCTION scienceData
{
  PARAMETER m.
  LOCAL td IS 0.
  FOR d IN m:DATA { SET td TO td + d:DATAAMOUNT. }
  RETURN td.
}

FUNCTION powerReq
{
  PARAMETER m.
  RETURN SCI_MIN_POW + (scienceData(m) * SCI_EC_PER_MIT).
}

FUNCTION timeReq
{
  PARAMETER m.
  RETURN scienceData(m) / SCI_MIT_RATE.
}

FUNCTION powerOkay
{
  PARAMETER m.
  LOCAL LOCK ec TO SHIP:ELECTRICCHARGE.
  setTime("SCI_EC").
  LOCAL ec0 IS ec.
  WAIT 0.2.
  LOCAL p_rate IS (ec - ec0) / diffTime("SCI_EC").
  LOCAL p_req IS powerReq(m).
  LOCAL p_avail IS ec + (p_rate * timeReq(m)).
  pOut("Power required: " + ROUND(p_req,2) + " / Power available: " + ROUND(p_avail,2)).
  RETURN p_avail >= p_req.
}

FUNCTION resetMod
{
  PARAMETER m.
  pOut("Reseting science in " + m:PART:TITLE).
  m:RESET().
  WAIT UNTIL NOT (m:DEPLOYED OR m:HASDATA).
}

FUNCTION doMod
{
  PARAMETER m.
  pOut("Collecting science from " + m:PART:TITLE).
  m:DEPLOY().
  WAIT UNTIL m:HASDATA.
}

FUNCTION txMod
{
  PARAMETER m.
  pOut("Transmitting data from " + m:PART:TITLE).
  m:TRANSMIT().
}

FUNCTION doScience
{
  PARAMETER one_use IS TRUE, overwrite IS FALSE.

  FOR m IN SCI_LIST { IF NOT m:INOPERABLE AND (m:RERUNNABLE OR one_use) {
    IF m:DEPLOYED AND overwrite { resetMod(m). }
    IF NOT m:DEPLOYED { doMod(m). }
  }}
}

FUNCTION transmitScience
{
  PARAMETER one_use IS TRUE, wait_for_power IS TRUE, max_wait IS -1.
  setTime("SCI_START_TX").

  FOR m IN SCI_LIST { IF m:HASDATA AND (m:RERUNNABLE OR one_use) {
    UNTIL powerOkay(m) {
      IF NOT wait_for_power {
        pOut("ERROR: Power too low to transmit science.").
        RETURN FALSE.
      }
      IF max_wait > 0 AND diffTime("SCI_START_TX") > max_wait {
        pOut("ERROR: Science transmission timed out.").
        RETURN FALSE.
      }
    }
    setTime("SCI_TX", TIME:SECONDS + timeReq(m)).
    txMod(m).
    WAIT UNTIL diffTime("SCI_TX") > 0.
  }}

  RETURN TRUE.
}

FUNCTION resetScience
{
  FOR m IN SCI_LIST { IF m:DEPLOYED AND NOT m:INOPERABLE { resetMod(m). } }
}
